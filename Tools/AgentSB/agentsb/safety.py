from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Literal

SafetyDecision = Literal["auto-apply", "draft-only", "report-only"]


@dataclass(frozen=True)
class SafetyClassification:
    decision: SafetyDecision
    reasons: list[str] = field(default_factory=list)
    required_checks: list[str] = field(default_factory=list)

    def as_dict(self) -> dict[str, Any]:
        return {
            "decision": self.decision,
            "reasons": self.reasons,
            "required_checks": self.required_checks,
        }


def classify_candidate(candidate: dict[str, Any]) -> SafetyClassification:
    paths = [str(path) for path in candidate.get("paths", [])]
    change_kind = str(candidate.get("change_kind", "unknown"))
    ambiguity = bool(candidate.get("ambiguous", False))
    behavioral = bool(candidate.get("behavioral", False))
    public_api = bool(candidate.get("public_api", False))

    if not paths:
        return SafetyClassification(
            "report-only",
            ["candidate has no paths, so AgentSB cannot prove the affected surface"],
        )

    forbidden_reason = _forbidden_reason(paths, change_kind, behavioral, public_api)
    if forbidden_reason:
        return SafetyClassification("report-only", [forbidden_reason])

    if ambiguity:
        return SafetyClassification(
            "draft-only",
            ["candidate has unresolved ambiguity and needs maintainer review before application"],
            ["review drafted diff"],
        )

    if _is_agentsb_owned_report_change(paths, change_kind):
        return SafetyClassification(
            "auto-apply",
            ["candidate is limited to AgentSB-owned report formatting or report creation"],
            ["uv run pytest"],
        )

    if _is_agent_docs_change(paths, change_kind):
        return SafetyClassification(
            "draft-only",
            ["AgentSB docs changes can affect maintainer workflow meaning"],
            ["git diff --check"],
        )

    return SafetyClassification(
        "draft-only",
        ["candidate is not on a known auto-apply-safe surface"],
        ["review drafted diff"],
    )


def _forbidden_reason(paths: list[str], change_kind: str, behavioral: bool, public_api: bool) -> str | None:
    if behavioral:
        return "candidate may change runtime behavior"
    if public_api:
        return "candidate may change public API"
    if any(path.startswith("Sources/SwiftASB/Generated/CodexWire/Latest/") for path in paths):
        return "generated wire snapshots require maintainer-controlled promotion"
    if any(path.startswith("Sources/SwiftASB/Public/") for path in paths):
        return "public Swift API surfaces require maintainer review"
    if any(path.startswith("scripts/repo-maintenance/release") or path == "scripts/repo-maintenance/release.sh" for path in paths):
        return "release automation changes require maintainer review"
    if change_kind in {"package-manager-upgrade", "codex-cli-upgrade", "homebrew-upgrade"}:
        return "package manager upgrades require explicit maintainer approval"
    if change_kind == "schema-family-promotion":
        return "schema-family promotion requires explicit boundary classification"
    return None


def _is_agentsb_owned_report_change(paths: list[str], change_kind: str) -> bool:
    return change_kind in {"report-create", "report-format"} and all(
        path.startswith("docs/agents/reports/") for path in paths
    )


def _is_agent_docs_change(paths: list[str], change_kind: str) -> bool:
    return change_kind in {"docs-update", "roadmap-update"} and all(
        path.startswith("docs/agents/") or path.startswith("Tools/AgentSB/") for path in paths
    )
