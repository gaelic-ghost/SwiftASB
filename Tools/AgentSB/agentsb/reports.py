from __future__ import annotations

from datetime import date
from pathlib import Path
from typing import Any

from .tools import AgentSBError, resolve_repo_root

REPORT_SECTIONS = [
    "Summary",
    "Codex CLI Schema State",
    "Schema Diff Evidence",
    "Boundary Review",
    "Documentation Drift",
    "Recommended Probes",
    "Human Decisions",
    "Evidence",
]


def report_directory(repo: str | Path) -> Path:
    root = resolve_repo_root(repo)
    return root / "docs" / "agents" / "reports"


def report_path(repo: str | Path, topic: str, *, today: date | None = None) -> Path:
    root = resolve_repo_root(repo)
    reports = report_directory(root)
    candidate = reports / f"{(today or date.today()).isoformat()}-agentsb-{_slug(topic)}.md"
    return ensure_report_path(root, candidate)


def ensure_report_path(repo: str | Path, path: str | Path) -> Path:
    root = resolve_repo_root(repo)
    reports = report_directory(root).resolve()
    resolved = Path(path).expanduser().resolve()
    try:
        resolved.relative_to(reports)
    except ValueError as error:
        raise AgentSBError(f"Report path must stay inside {reports}: {resolved}") from error
    return _next_available_path(resolved)


def write_report(
    repo: str | Path,
    topic: str,
    facts: dict[str, Any],
    *,
    ai_notes: str | None = None,
    schema_diff: dict[str, Any] | None = None,
) -> Path:
    path = report_path(repo, topic)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(render_schema_review_report(facts, ai_notes=ai_notes, schema_diff=schema_diff), encoding="utf-8")
    return path


def render_schema_review_report(
    facts: dict[str, Any],
    *,
    ai_notes: str | None = None,
    schema_diff: dict[str, Any] | None = None,
) -> str:
    git = facts["git"]
    reviewed_window = facts["reviewed_codex_cli_window"]["window"] or "unknown"
    schema_dumps = facts["schema_dumps"]
    promoted_files = facts["promoted_wire_files"]
    docs = facts["docs"]
    latest_dump = schema_dumps[-1]["name"] if schema_dumps else "none"

    lines = [
        "# AgentSB Schema Review",
        "",
        "## Summary",
        "",
        f"- Reviewed Codex CLI compatibility window: `{reviewed_window}`.",
        f"- Latest discovered schema dump: `{latest_dump}`.",
        f"- Promoted generated wire files: {len(promoted_files)}.",
        f"- Git branch at inspection time: `{git['branch']}`.",
        "",
        "## Codex CLI Schema State",
        "",
        _schema_dump_table(schema_dumps),
        "",
        "## Schema Diff Evidence",
        "",
        _schema_diff_section(schema_diff),
        "",
        "## Boundary Review",
        "",
        "- Report skeleton only: classify any new schema families as `public now`, `observable-only`, or `internal-only` before promotion.",
        "- Do not expose generated `CodexWire...` models as public Swift API without a hand-owned SwiftASB boundary.",
        "",
        "## Documentation Drift",
        "",
        _docs_table(docs),
        "",
        "## Recommended Probes",
        "",
        "- Run `swift build` and `swift test` after package behavior changes.",
        "- Run `scripts/run-live-codex-integration-tests.sh smoke` for runtime confidence after schema-boundary changes.",
        "- Run `xcodebuild docbuild -scheme SwiftASB -destination generic/platform=macOS -derivedDataPath tmp/xcode-docc/DerivedData` after DocC changes.",
        "",
        "## Human Decisions",
        "",
        "- Decide whether any newly dumped schema family deserves public API, observable-only support, or internal-only coverage.",
        "- Decide whether README, CONTRIBUTING, ROADMAP, or DocC need compatibility-window updates.",
        "",
        "## Evidence",
        "",
        f"- Repository root: `{facts['repo_root']}`.",
        f"- Git dirty state: `{git['dirty']}`.",
        f"- Git upstream: `{git['upstream'] or 'none'}`.",
        f"- Reviewed window source: `{facts['reviewed_codex_cli_window']['source'] or 'not found'}`.",
        "- Promoted wire files:",
        *[f"  - `{item['path']}` ({item['bytes']} bytes)" for item in promoted_files],
    ]

    if ai_notes:
        lines.extend(["", "## Agent Notes", "", ai_notes.strip()])

    return "\n".join(lines).rstrip() + "\n"


def render_maintenance_report(
    *,
    title: str,
    facts: dict[str, Any],
    schema_diff: dict[str, Any] | None,
    candidates: list[dict[str, Any]],
    mode: str,
    applied: list[dict[str, Any]] | None = None,
    checks: list[dict[str, Any]] | None = None,
) -> str:
    git = facts["git"]
    applied = applied or []
    checks = checks or []
    lines = [
        f"# {title}",
        "",
        "## Summary",
        "",
        f"- Mode: `{mode}`.",
        f"- Git branch at inspection time: `{git['branch']}`.",
        f"- Git dirty state at inspection time: `{git['dirty']}`.",
        f"- Candidates reviewed: {len(candidates)}.",
        f"- Safe changes applied: {len(applied)}.",
        "",
        "## Schema Diff Evidence",
        "",
        _schema_diff_section(schema_diff),
        "",
        "## Candidate Decisions",
        "",
        _candidate_decision_sections(candidates),
        "",
        "## Applied Changes",
        "",
        _applied_changes_section(applied),
        "",
        "## Required Checks",
        "",
        _checks_section(checks),
        "",
        "## Evidence",
        "",
        f"- Repository root: `{facts['repo_root']}`.",
        f"- Reviewed window source: `{facts['reviewed_codex_cli_window']['source'] or 'not found'}`.",
        f"- Git upstream: `{git['upstream'] or 'none'}`.",
    ]
    return "\n".join(lines).rstrip() + "\n"


def _schema_dump_table(schema_dumps: list[dict[str, Any]]) -> str:
    if not schema_dumps:
        return "No schema dumps were found under `codex-schemas/`."

    rows = ["| Dump | Variant | JSON files |", "| --- | --- | --- |"]
    rows.extend(
        f"| `{item['name']}` | {item['variant']} | {item['json_files']} |"
        for item in schema_dumps
    )
    return "\n".join(rows)


def _schema_diff_section(schema_diff: dict[str, Any] | None) -> str:
    if not schema_diff:
        return "No schema dump diff was available for this report."

    summary = schema_diff["summary"]
    lines = [
        f"- Compared `{schema_diff['base']}` to `{schema_diff['target']}`.",
        f"- Added JSON files: {summary['added']}.",
        f"- Removed JSON files: {summary['removed']}.",
        f"- Changed JSON files: {summary['changed']}.",
        f"- Unchanged JSON files: {summary['unchanged']}.",
    ]
    for label, key in [("Added", "added"), ("Removed", "removed"), ("Changed", "changed")]:
        values = schema_diff.get(key, [])
        if values:
            lines.append(f"- {label}: {_preview_values(values)}.")
    return "\n".join(lines)


def _candidate_decision_sections(candidates: list[dict[str, Any]]) -> str:
    if not candidates:
        return "No maintenance candidates were discovered."

    sections: list[str] = []
    for index, candidate in enumerate(candidates, start=1):
        classification = candidate["classification"]
        sections.extend(
            [
                f"### {index}. {candidate['title']}",
                "",
                f"- Decision: `{classification['decision']}`.",
                f"- Change kind: `{candidate['change_kind']}`.",
                f"- Paths: {_preview_values(candidate['paths'])}.",
                f"- Summary: {candidate['summary']}",
                f"- Reasons: {_preview_values(classification['reasons'])}.",
            ]
        )
        required_checks = classification.get("required_checks", [])
        if required_checks:
            sections.append(f"- Required checks: {_preview_values(required_checks)}.")
        draft = candidate.get("draft")
        if draft:
            sections.extend(["", "Proposed patch:", "", "```diff", draft.rstrip(), "```"])
        sections.append("")
    return "\n".join(sections).rstrip()


def _applied_changes_section(applied: list[dict[str, Any]]) -> str:
    if not applied:
        return "No safe changes were applied."
    return "\n".join(f"- `{item['path']}`: {item['summary']}" for item in applied)


def _checks_section(checks: list[dict[str, Any]]) -> str:
    if not checks:
        return "No checks were run."
    return "\n".join(
        f"- `{item['command']}` exited {item['returncode']}: {item['summary']}"
        for item in checks
    )


def _preview_values(values: list[Any], *, limit: int = 8) -> str:
    if not values:
        return "none"
    rendered = [f"`{value}`" for value in values[:limit]]
    if len(values) > limit:
        rendered.append(f"... {len(values) - limit} more")
    return ", ".join(rendered)


def _docs_table(docs: dict[str, Any]) -> str:
    rows = ["| Document | Present | Bytes |", "| --- | --- | --- |"]
    rows.extend(
        f"| `{item['path']}` | {str(item['exists']).lower()} | {item['bytes']} |"
        for item in docs["named_docs"]
    )
    rows.append(f"| `docs/maintainers/*.md` | true | {len(docs['maintainer_docs'])} files |")
    return "\n".join(rows)


def _next_available_path(path: Path) -> Path:
    if not path.exists():
        return path
    stem = path.stem
    suffix = path.suffix
    parent = path.parent
    index = 2
    while True:
        candidate = parent / f"{stem}-{index}{suffix}"
        if not candidate.exists():
            return candidate
        index += 1


def _slug(value: str) -> str:
    slug = "".join(char.lower() if char.isalnum() else "-" for char in value)
    slug = "-".join(part for part in slug.split("-") if part)
    if not slug:
        raise AgentSBError("Report topic must contain at least one letter or number.")
    return slug
