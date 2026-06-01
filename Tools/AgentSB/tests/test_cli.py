from __future__ import annotations

import json

from agentsb.main import main


def test_cli_help(capsys):
    exit_code = main(["--help"])
    captured = capsys.readouterr()

    assert exit_code == 0
    assert "docs/agents/reports" in captured.out


def test_cli_inspect_outputs_json(repo_root, capsys):
    exit_code = main(["inspect", "--repo", str(repo_root)])
    captured = capsys.readouterr()

    assert exit_code == 0
    facts = json.loads(captured.out)
    assert facts["reviewed_codex_cli_window"]["window"] == "0.135.x"


def test_cli_schema_review_writes_report(fake_repo, capsys):
    exit_code = main(["report", "schema-review", "--repo", str(fake_repo)])
    captured = capsys.readouterr()

    assert exit_code == 0
    assert "Wrote AgentSB schema-review report" in captured.out
    reports = list((fake_repo / "docs" / "agents" / "reports").glob("*-agentsb-schema-review.md"))
    assert len(reports) == 1
    assert "## Human Decisions" in reports[0].read_text(encoding="utf-8")
