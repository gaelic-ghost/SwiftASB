from __future__ import annotations

from pathlib import Path
import subprocess
import sqlite3

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


@pytest.fixture
def fake_thread_index(tmp_path) -> Path:
    database = tmp_path / "state_5.sqlite"
    connection = sqlite3.connect(database)
    connection.execute(
        """
        create table threads (
            id text primary key,
            rollout_path text not null,
            created_at integer not null,
            updated_at integer not null,
            source text not null,
            model_provider text not null,
            cwd text not null,
            title text not null,
            sandbox_policy text not null,
            approval_mode text not null,
            tokens_used integer not null default 0,
            archived integer not null default 0,
            archived_at integer,
            git_sha text,
            git_branch text,
            git_origin_url text,
            cli_version text not null default '',
            first_user_message text not null default '',
            agent_nickname text,
            agent_role text,
            memory_mode text not null default 'enabled',
            model text,
            reasoning_effort text,
            agent_path text,
            created_at_ms integer,
            updated_at_ms integer,
            thread_source text,
            preview text not null default ''
        )
        """
    )
    rows = [
        (
            "thread-active",
            "/Users/galew/.codex/sessions/2026/06/04/rollout-active.jsonl",
            100,
            200,
            "codex",
            "openai",
            "/repo",
            "Active title",
            "workspace-write",
            "on-request",
            10,
            0,
            None,
            "abc",
            "main",
            "https://github.com/gaelic-ghost/SwiftASB.git",
            "0.135.0",
            "private first message",
            "Ari",
            "default",
            "enabled",
            "gpt-5",
            "medium",
            None,
            100000,
            200000,
            "local",
            "private preview",
        ),
        (
            "thread-archived",
            "/Users/galew/.codex/archived_sessions/rollout-archived.jsonl",
            90,
            150,
            "codex",
            "openai",
            "/repo",
            "Archived title",
            "workspace-write",
            "on-request",
            20,
            1,
            175000,
            None,
            None,
            None,
            "0.135.0",
            "archived private first message",
            None,
            None,
            "enabled",
            "gpt-5",
            "medium",
            None,
            90000,
            150000,
            "local",
            "archived private preview",
        ),
    ]
    thread_columns = [
        "id",
        "rollout_path",
        "created_at",
        "updated_at",
        "source",
        "model_provider",
        "cwd",
        "title",
        "sandbox_policy",
        "approval_mode",
        "tokens_used",
        "archived",
        "archived_at",
        "git_sha",
        "git_branch",
        "git_origin_url",
        "cli_version",
        "first_user_message",
        "agent_nickname",
        "agent_role",
        "memory_mode",
        "model",
        "reasoning_effort",
        "agent_path",
        "created_at_ms",
        "updated_at_ms",
        "thread_source",
        "preview",
    ]
    placeholders = ",".join("?" for _ in thread_columns)
    connection.executemany(
        f"insert into threads ({','.join(thread_columns)}) values ({placeholders})",
        rows,
    )
    connection.commit()
    connection.close()
    return database
