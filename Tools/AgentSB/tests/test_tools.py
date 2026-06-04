from __future__ import annotations

from agentsb.tools import inspect_repo


def test_inspect_repo_reads_swiftasb_facts(repo_root):
    facts = inspect_repo(repo_root)

    assert facts["reviewed_codex_cli_window"]["window"] == "0.135.x"
    assert any(
        item["name"] == "CodexLifecycleV2Batch+JSONValue.swift"
        for item in facts["promoted_wire_files"]
    )
    assert any(item["path"] == "ROADMAP.md" and item["exists"] for item in facts["docs"]["named_docs"])


def test_inspect_repo_reads_schema_dumps_from_fixture(fake_repo):
    facts = inspect_repo(fake_repo)

    assert any(item["name"] == "v0.135.0" for item in facts["schema_dumps"])
