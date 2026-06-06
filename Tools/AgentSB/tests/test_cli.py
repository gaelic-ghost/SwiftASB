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
    assert facts["reviewed_codex_cli_window"]["window"] == "0.137.x"


def test_cli_schema_review_writes_report(fake_repo, capsys):
    exit_code = main(["report", "schema-review", "--repo", str(fake_repo)])
    captured = capsys.readouterr()

    assert exit_code == 0
    assert "Wrote AgentSB schema-review report" in captured.out
    reports = list((fake_repo / "docs" / "agents" / "reports").glob("*-agentsb-schema-review.md"))
    assert len(reports) == 1
    rendered = reports[0].read_text(encoding="utf-8")
    assert "## Human Decisions" in rendered
    assert "## Schema Diff Evidence" in rendered
    assert "Compared `v0.135.0` to `v0.136.0`" in rendered


def test_cli_schema_check_uses_dump_script(fake_repo, capsys):
    exit_code = main(["schema", "check", "--repo", str(fake_repo), "--brew-check"])
    captured = capsys.readouterr()

    assert exit_code == 0
    summary = json.loads(captured.out)
    assert summary["installed_codex_cli"] == "0.136.0"
    assert summary["installed_newer_than_local"] is True
    assert summary["brew"]["status"] == "checked"


def test_cli_schema_dump_if_newer_uses_dump_script(fake_repo, capsys):
    exit_code = main(["schema", "dump-if-newer", "--repo", str(fake_repo)])
    captured = capsys.readouterr()

    assert exit_code == 0
    summary = json.loads(captured.out)
    assert summary["dumped"] is True


def test_cli_maintain_draft_writes_reviewable_report(fake_repo, capsys):
    exit_code = main(["maintain", "--repo", str(fake_repo), "--draft"])
    captured = capsys.readouterr()

    assert exit_code == 0
    assert "Wrote AgentSB maintenance draft" in captured.out
    reports = list((fake_repo / "docs" / "agents" / "reports").glob("*-agentsb-maintenance-draft.md"))
    assert len(reports) == 1
    rendered = reports[0].read_text(encoding="utf-8")
    assert "Proposed patch:" in rendered
    assert "Decision: `report-only`" in rendered
    assert "Decision: `draft-only`" in rendered


def test_cli_maintain_auto_apply_refuses_unsafe_candidates(fake_repo, monkeypatch, capsys):
    def passing_checks(_root, commands):
        return [{"command": command, "returncode": 0, "summary": "passed in test"} for command in commands]

    monkeypatch.setattr("agentsb.maintain.run_required_checks", passing_checks)

    exit_code = main(["maintain", "--repo", str(fake_repo), "--auto-apply-safe"])
    captured = capsys.readouterr()

    assert exit_code == 0
    assert "Wrote AgentSB auto-apply-safe report" in captured.out
    reports = list((fake_repo / "docs" / "agents" / "reports").glob("*-agentsb-maintenance-auto-apply-safe.md"))
    assert len(reports) == 1
    rendered = reports[0].read_text(encoding="utf-8")
    assert "generated wire snapshots require maintainer-controlled promotion" in rendered
    assert "Wrote AgentSB-owned schema-review report" in rendered
    assert (fake_repo / "Sources" / "SwiftASB" / "Generated" / "CodexWire" / "Latest" / "CodexLifecycleV2Batch+JSONValue.swift").read_text(
        encoding="utf-8"
    ) == "struct CodexLifecycleV2Batch {}\n"


def test_cli_maintain_requires_one_mode(fake_repo, capsys):
    exit_code = main(["maintain", "--repo", str(fake_repo)])
    captured = capsys.readouterr()

    assert exit_code == 2
    assert "choose exactly one" in captured.err


def test_cli_local_eval_runs(capsys):
    exit_code = main(["eval", "local"])
    captured = capsys.readouterr()

    assert exit_code == 0
    assert "PASS report_contains_required_sections" in captured.out


def test_cli_ai_eval_requires_api_key(monkeypatch, capsys):
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)

    exit_code = main(["eval", "ai", "--model", "gpt-5.5"])
    captured = capsys.readouterr()

    assert exit_code == 1
    assert "OPENAI_API_KEY is required" in captured.err
