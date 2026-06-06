from __future__ import annotations

from datetime import date

import pytest

from agentsb.reports import REPORT_SECTIONS, ensure_report_path, render_schema_review_report, report_path
from agentsb.tools import AgentSBError


def test_report_path_stays_under_docs_agents_reports(repo_root):
    path = report_path(repo_root, "schema-review", today=date(2026, 6, 1))

    assert path == repo_root / "docs" / "agents" / "reports" / "2026-06-01-agentsb-schema-review.md"


def test_report_path_rejects_outside_repo(repo_root, tmp_path):
    with pytest.raises(AgentSBError):
        ensure_report_path(repo_root, tmp_path / "outside.md")


def test_schema_review_report_contains_required_sections(sample_facts):
    rendered = render_schema_review_report(sample_facts)

    for section in REPORT_SECTIONS:
        assert f"## {section}" in rendered
    assert "CodexLifecycleV2Batch+JSONValue.swift" in rendered
    assert "0.135.x" in rendered


def test_schema_review_report_records_ai_model(sample_facts):
    rendered = render_schema_review_report(sample_facts, ai_notes="review notes", ai_model="gpt-5.5")

    assert "## Agent Notes" in rendered
    assert "- AI model: `gpt-5.5`." in rendered
