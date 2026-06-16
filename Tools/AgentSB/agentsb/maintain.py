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
        compatibility_patch = _compatibility_alignment_patch(facts, schema_diff)
        if compatibility_patch:
            candidates.append(
                {
                    "title": "Draft Codex CLI compatibility alignment patch",
                    "change_kind": "compatibility-alignment",
                    "paths": [
                        "README.md",
                        "ROADMAP.md",
                        "docs/maintainers/interactive-lifecycle-release-boundary.md",
                        "scripts/generate-wire-types.sh",
                        "Sources/SwiftASB/Transport/CodexCLIExecutableResolver.swift",
                        "Tools/AgentSB/tests/test_cli.py",
                        "Tools/AgentSB/tests/test_tools.py",
                    ],
                    "summary": (
                        "Draft the predictable version-window updates needed after maintainers "
                        f"classify `{schema_diff['target']}` as the reviewed Codex CLI schema."
                    ),
                    "behavioral": False,
                    "public_api": False,
                    "ambiguous": False,
                    "action": "draft_only",
                    "draft": compatibility_patch,
                }
            )
        generator_patch = _schema_generator_membership_patch(root, schema_diff)
        if generator_patch:
            candidates.append(
                {
                    "title": "Draft generated-wire schema membership patch",
                    "change_kind": "schema-generator-membership",
                    "paths": ["scripts/generate-wire-types.sh"],
                    "summary": (
                        "Draft the generator-script additions for new schema files so maintainers "
                        "can promote the classified wire batch through the normal script."
                    ),
                    "behavioral": False,
                    "public_api": False,
                    "ambiguous": False,
                    "action": "draft_only",
                    "draft": generator_patch,
                }
            )
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


def _compatibility_alignment_patch(facts: dict[str, Any], schema_diff: dict[str, Any]) -> str | None:
    current_window = facts["reviewed_codex_cli_window"].get("window")
    target_window = _schema_version_to_window(schema_diff["target"])
    target_minor = _schema_version_minor(schema_diff["target"])
    if not current_window or not target_window or target_window == current_window or target_minor is None:
        return None

    prior_window = f"0.{target_minor - 1}.x" if target_minor > 0 else "none"

    return "\n".join(
        [
            "diff --git a/scripts/generate-wire-types.sh b/scripts/generate-wire-types.sh",
            "--- a/scripts/generate-wire-types.sh",
            "+++ b/scripts/generate-wire-types.sh",
            "@@",
            f"-SCHEMA_VERSION=${{SCHEMA_VERSION:-{schema_diff['base']}}}",
            f"+SCHEMA_VERSION=${{SCHEMA_VERSION:-{schema_diff['target']}}}",
            "diff --git a/Sources/SwiftASB/Transport/CodexCLIExecutableResolver.swift b/Sources/SwiftASB/Transport/CodexCLIExecutableResolver.swift",
            "--- a/Sources/SwiftASB/Transport/CodexCLIExecutableResolver.swift",
            "+++ b/Sources/SwiftASB/Transport/CodexCLIExecutableResolver.swift",
            "@@",
            "-        internal static let latestSupportedPublicRelease = Version(major: 0, minor: <old-minor>, patch: 0)",
            f"+        internal static let latestSupportedPublicRelease = Version(major: 0, minor: {target_minor}, patch: 0)",
            "diff --git a/README.md b/README.md",
            "--- a/README.md",
            "+++ b/README.md",
            "@@",
            f"-*Note: SwiftASB currently supports the reviewed current Codex CLI minor release, `{current_window}`.*",
            f"+*Note: SwiftASB currently supports the reviewed current Codex CLI minor release, `{target_window}`, and the latest prior minor, `{prior_window}`, when that prior runtime remains compatible.*",
            "diff --git a/ROADMAP.md b/ROADMAP.md",
            "--- a/ROADMAP.md",
            "+++ b/ROADMAP.md",
            "@@",
            f"-The current reviewed compatibility window is `codex-cli {current_window}`",
            f"+The current reviewed compatibility window is `codex-cli {target_window}`",
            "@@",
            f"+- [ ] Classify the Codex CLI `{schema_diff['target']}` schema diff before promotion.",
            f"+  Decision: update the reviewed CLI window to `{target_window}` only after",
            "+  generated-wire and public API boundary review is complete.",
            "diff --git a/docs/maintainers/interactive-lifecycle-release-boundary.md b/docs/maintainers/interactive-lifecycle-release-boundary.md",
            "--- a/docs/maintainers/interactive-lifecycle-release-boundary.md",
            "+++ b/docs/maintainers/interactive-lifecycle-release-boundary.md",
            "@@",
            f"-- current reviewed minor release: `{current_window}`",
            f"+- current reviewed minor release: `{target_window}`",
            f"+- latest prior minor supported when feasible: `{prior_window}`",
            "diff --git a/Tools/AgentSB/tests/test_cli.py b/Tools/AgentSB/tests/test_cli.py",
            "--- a/Tools/AgentSB/tests/test_cli.py",
            "+++ b/Tools/AgentSB/tests/test_cli.py",
            "@@",
            f'-    assert facts["reviewed_codex_cli_window"]["window"] == "{current_window}"',
            f'+    assert facts["reviewed_codex_cli_window"]["window"] == "{target_window}"',
            "diff --git a/Tools/AgentSB/tests/test_tools.py b/Tools/AgentSB/tests/test_tools.py",
            "--- a/Tools/AgentSB/tests/test_tools.py",
            "+++ b/Tools/AgentSB/tests/test_tools.py",
            "@@",
            f'-    assert facts["reviewed_codex_cli_window"]["window"] == "{current_window}"',
            f'+    assert facts["reviewed_codex_cli_window"]["window"] == "{target_window}"',
        ]
    )


def _schema_generator_membership_patch(root: Path, schema_diff: dict[str, Any]) -> str | None:
    added_types = _missing_generator_types(root, _added_v2_schema_types(schema_diff))
    if not added_types:
        return None

    additions = "\n".join(f"+  {type_name} \\" for type_name in added_types)
    return "\n".join(
        [
            "diff --git a/scripts/generate-wire-types.sh b/scripts/generate-wire-types.sh",
            "--- a/scripts/generate-wire-types.sh",
            "+++ b/scripts/generate-wire-types.sh",
            "@@",
            "   # Add classified schema families to the consolidated v2 batch.",
            additions,
        ]
    )


def _added_v2_schema_types(schema_diff: dict[str, Any]) -> list[str]:
    type_names: list[str] = []
    for path in schema_diff.get("added", []):
        if not path.startswith("v2/") or not path.endswith(".json"):
            continue
        type_names.append(Path(path).stem)
    return type_names


def _missing_generator_types(root: Path, type_names: list[str]) -> list[str]:
    script = root / "scripts" / "generate-wire-types.sh"
    if not script.exists():
        return type_names

    contents = script.read_text(encoding="utf-8")
    return [type_name for type_name in type_names if type_name not in contents]


def _schema_version_to_window(version: str) -> str | None:
    parts = _schema_version_parts(version)
    if not parts:
        return None
    major, minor, _patch = parts
    return f"{major}.{minor}.x"


def _schema_version_minor(version: str) -> int | None:
    parts = _schema_version_parts(version)
    if not parts:
        return None
    _major, minor, _patch = parts
    return minor


def _schema_version_parts(version: str) -> tuple[int, int, int] | None:
    normalized = version.removeprefix("v")
    pieces = normalized.split(".")
    if len(pieces) != 3:
        return None
    try:
        major, minor, patch = (int(piece) for piece in pieces)
    except ValueError:
        return None
    return major, minor, patch


def _unique(values: list[str]) -> list[str]:
    result: list[str] = []
    for value in values:
        if value not in result:
            result.append(value)
    return result
