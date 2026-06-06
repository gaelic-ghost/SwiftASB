from __future__ import annotations

from agentsb.safety import classify_candidate


def test_generated_wire_candidate_is_report_only():
    classification = classify_candidate(
        {
            "change_kind": "schema-family-promotion",
            "paths": ["Sources/SwiftASB/Generated/CodexWire/Latest/CodexLifecycleV2Batch+JSONValue.swift"],
        }
    )

    assert classification.decision == "report-only"


def test_agentsb_report_format_candidate_can_auto_apply():
    classification = classify_candidate(
        {
            "change_kind": "report-format",
            "paths": ["docs/agents/reports/2026-06-04-agentsb-schema-review.md"],
        }
    )

    assert classification.decision == "auto-apply"


def test_release_automation_candidate_is_report_only():
    classification = classify_candidate(
        {
            "change_kind": "release-automation",
            "paths": ["scripts/repo-maintenance/release.sh"],
        }
    )

    assert classification.decision == "report-only"
    assert "release automation" in " ".join(classification.reasons)


def test_package_manager_upgrade_candidate_is_report_only():
    classification = classify_candidate(
        {
            "change_kind": "codex-cli-upgrade",
            "paths": ["codex-schemas/v0.137.0"],
        }
    )

    assert classification.decision == "report-only"
    assert "package manager upgrades" in " ".join(classification.reasons)


def test_compatibility_alignment_candidate_is_draft_only():
    classification = classify_candidate(
        {
            "change_kind": "compatibility-alignment",
            "paths": ["README.md", "scripts/generate-wire-types.sh"],
        }
    )

    assert classification.decision == "draft-only"
    assert "compatibility alignment" in " ".join(classification.reasons)
