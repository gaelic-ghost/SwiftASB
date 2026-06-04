from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Any, Callable

from .reports import render_maintenance_report, report_path, write_report
from .safety import classify_candidate
from .schema_diff import latest_schema_diff
from .tools import AgentSBError, inspect_repo, resolve_repo_root

CheckRunner = Callable[[Path, list[str]], list[dict[str, Any]]]


def write_maintenance_draft(repo: str | Path) -> Path:
    root = resolve_repo_root(repo)
    facts = inspect_repo(root)
    schema_diff = latest_schema_diff(root, facts["schema_dumps"])
    candidates = classify_maintenance_candidates(build_maintenance_candidates(root, facts, schema_diff))
    path = report_path(root, "maintenance-draft")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        render_maintenance_report(
            title="AgentSB Maintenance Draft",
            facts=facts,
            schema_diff=schema_diff,
            candidates=candidates,
            mode="draft",
        ),
        encoding="utf-8",
    )
    return path


def auto_apply_safe(repo: str | Path, *, check_runner: CheckRunner | None = None) -> Path:
    root = resolve_repo_root(repo)
    facts = inspect_repo(root)
    schema_diff = latest_schema_diff(root, facts["schema_dumps"])
    candidates = classify_maintenance_candidates(build_maintenance_candidates(root, facts, schema_diff))
    applied: list[dict[str, Any]] = []
    required_checks: list[str] = []

    for candidate in candidates:
        classification = candidate["classification"]
        if classification["decision"] != "auto-apply":
            continue
        applied.append(_apply_candidate(root, candidate, facts, schema_diff))
        required_checks.extend(classification.get("required_checks", []))

    checks = (check_runner or run_required_checks)(root, _unique(required_checks)) if required_checks else []
    path = report_path(root, "maintenance-auto-apply-safe")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        render_maintenance_report(
            title="AgentSB Auto-Apply Safe Maintenance Run",
            facts=facts,
            schema_diff=schema_diff,
            candidates=candidates,
            mode="auto-apply-safe",
            applied=applied,
            checks=checks,
        ),
        encoding="utf-8",
    )
    failed_checks = [check for check in checks if check["returncode"] != 0]
    if failed_checks:
        failed = ", ".join(check["command"] for check in failed_checks)
        raise AgentSBError(f"Required checks failed after safe auto-apply: {failed}")
    return path


def build_maintenance_candidates(
    root: Path,
    facts: dict[str, Any],
    schema_diff: dict[str, Any] | None,
) -> list[dict[str, Any]]:
    schema_report = report_path(root, "schema-review")
    candidates = [
        {
            "title": "Write schema-review evidence report",
            "change_kind": "report-create",
            "paths": [str(schema_report.relative_to(root))],
            "summary": "Create an AgentSB-owned schema-review report with deterministic repo facts and schema diff evidence.",
            "behavioral": False,
            "public_api": False,
            "ambiguous": False,
            "action": "write_schema_review_report",
        }
    ]

    if schema_diff and _diff_has_review_work(schema_diff):
        candidates.append(
            {
                "title": "Classify schema family changes before generated-wire promotion",
                "change_kind": "schema-family-promotion",
                "paths": ["Sources/SwiftASB/Generated/CodexWire/Latest/CodexLifecycleV2Batch+JSONValue.swift"],
                "summary": (
                    f"Schema dumps `{schema_diff['base']}` and `{schema_diff['target']}` differ; "
                    "maintainers need to classify added or changed families before promotion."
                ),
                "behavioral": False,
                "public_api": False,
                "ambiguous": True,
                "action": "refuse",
            }
        )
        candidates.append(
            {
                "title": "Draft AgentSB roadmap evidence note",
                "change_kind": "docs-update",
                "paths": ["docs/agents/agentsb-roadmap.md"],
                "summary": "Propose a roadmap note that records the latest local schema diff evidence without changing the source document.",
                "behavioral": False,
                "public_api": False,
                "ambiguous": True,
                "action": "draft_only",
                "draft": _roadmap_evidence_patch(schema_diff),
            }
        )

    return candidates


def classify_maintenance_candidates(candidates: list[dict[str, Any]]) -> list[dict[str, Any]]:
    classified: list[dict[str, Any]] = []
    for candidate in candidates:
        classification = classify_candidate(candidate).as_dict()
        classified.append({**candidate, "classification": classification})
    return classified


def run_required_checks(root: Path, commands: list[str]) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    for command in commands:
        if command == "uv run pytest":
            result = subprocess.run(
                ["uv", "run", "pytest"],
                cwd=root / "Tools" / "AgentSB",
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
        else:
            results.append(
                {
                    "command": command,
                    "returncode": 1,
                    "summary": "AgentSB does not know how to run this required check.",
                }
            )
            continue
        detail = result.stderr.strip() or result.stdout.strip() or "no diagnostic output"
        results.append(
            {
                "command": command,
                "returncode": result.returncode,
                "summary": detail.splitlines()[-1],
            }
        )
    return results


def _apply_candidate(
    root: Path,
    candidate: dict[str, Any],
    facts: dict[str, Any],
    schema_diff: dict[str, Any] | None,
) -> dict[str, Any]:
    if candidate["action"] == "write_schema_review_report":
        path = write_report(root, "schema-review", facts, schema_diff=schema_diff)
        return {
            "path": str(path.relative_to(root)),
            "summary": "Wrote AgentSB-owned schema-review report.",
        }
    raise AgentSBError(f"AgentSB has no safe auto-apply action for candidate: {candidate['title']}")


def _diff_has_review_work(schema_diff: dict[str, Any]) -> bool:
    summary = schema_diff["summary"]
    return bool(summary["added"] or summary["removed"] or summary["changed"])


def _roadmap_evidence_patch(schema_diff: dict[str, Any]) -> str:
    summary = schema_diff["summary"]
    return "\n".join(
        [
            "diff --git a/docs/agents/agentsb-roadmap.md b/docs/agents/agentsb-roadmap.md",
            "--- a/docs/agents/agentsb-roadmap.md",
            "+++ b/docs/agents/agentsb-roadmap.md",
            "@@",
            "+- Latest local schema diff evidence: AgentSB compared "
            f"`{schema_diff['base']}` to `{schema_diff['target']}` and found "
            f"{summary['added']} added, {summary['removed']} removed, and {summary['changed']} changed JSON files. "
            "Do not update public support claims or generated wire output until maintainers classify each changed family.",
        ]
    )


def _unique(values: list[str]) -> list[str]:
    result: list[str] = []
    for value in values:
        if value not in result:
            result.append(value)
    return result
