from __future__ import annotations

from pathlib import Path
import subprocess

import pytest


@pytest.fixture
def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


@pytest.fixture
def sample_facts(repo_root):
    return {
        "repo_root": str(repo_root),
        "git": {
            "branch": "agents/agentsb-maintenance",
            "upstream": None,
            "dirty": True,
            "status": [],
        },
        "reviewed_codex_cli_window": {
            "window": "0.135.x",
            "source": "ROADMAP.md",
        },
        "schema_dumps": [
            {"name": "v0.135.0", "variant": "experimental", "json_files": 2},
        ],
        "promoted_wire_files": [
            {
                "path": "Sources/SwiftASB/Generated/CodexWire/Latest/CodexLifecycleV2Batch+JSONValue.swift",
                "name": "CodexLifecycleV2Batch+JSONValue.swift",
                "bytes": 123,
            },
        ],
        "docs": {
            "named_docs": [
                {"path": "ROADMAP.md", "exists": True, "bytes": 100},
            ],
            "maintainer_docs": ["docs/maintainers/example.md"],
        },
    }


@pytest.fixture
def fake_repo(tmp_path) -> Path:
    root = tmp_path / "SwiftASB"
    (root / "Sources" / "SwiftASB" / "Generated" / "CodexWire" / "Latest").mkdir(parents=True)
    (root / "codex-schemas" / "v0.135.0").mkdir(parents=True)
    (root / "codex-schemas" / "v0.136.0").mkdir(parents=True)
    (root / "docs" / "maintainers").mkdir(parents=True)
    (root / "docs" / "agents" / "reports").mkdir(parents=True)
    (root / "Package.swift").write_text("// swift-tools-version: 6.0\n", encoding="utf-8")
    (root / "ROADMAP.md").write_text(
        "The current reviewed compatibility window is `codex-cli 0.135.x`.\n",
        encoding="utf-8",
    )
    (root / "AGENTS.md").write_text("# AGENTS\n", encoding="utf-8")
    (root / "README.md").write_text("# README\n", encoding="utf-8")
    (root / "CONTRIBUTING.md").write_text("# CONTRIBUTING\n", encoding="utf-8")
    (root / "docs" / "maintainers" / "example.md").write_text("# Example\n", encoding="utf-8")
    (root / "codex-schemas" / "v0.135.0" / "schema.json").write_text("{}", encoding="utf-8")
    (root / "codex-schemas" / "v0.135.0" / "removed.json").write_text('{"old":true}', encoding="utf-8")
    (root / "codex-schemas" / "v0.135.0" / "changed.json").write_text('{"value":1}', encoding="utf-8")
    (root / "codex-schemas" / "v0.136.0" / "schema.json").write_text("{}", encoding="utf-8")
    (root / "codex-schemas" / "v0.136.0" / "added.json").write_text('{"new":true}', encoding="utf-8")
    (root / "codex-schemas" / "v0.136.0" / "changed.json").write_text('{"value":2}', encoding="utf-8")
    (
        root / "Sources" / "SwiftASB" / "Generated" / "CodexWire" / "Latest" / "CodexLifecycleV2Batch+JSONValue.swift"
    ).write_text("struct CodexLifecycleV2Batch {}\n", encoding="utf-8")
    subprocess.run(["git", "init"], cwd=root, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return root
