from __future__ import annotations

import json
import shutil

from agentsb.main import main
from agentsb.thread_index import inspect_thread_index


def test_thread_index_inspection_redacts_private_text(fake_thread_index):
    inventory = inspect_thread_index(fake_thread_index, cwd="/repo", archive_filter="all")

    assert inventory["schema_status"]["compatible"] is True
    assert inventory["counts"] == {"total": 2, "archived": 1, "unarchived": 1}
    assert inventory["rows"][0]["id"] == "thread-active"
    assert inventory["rows"][0]["title"] is None
    assert inventory["rows"][0]["title_length"] == len("Active title")
    assert inventory["rows"][0]["first_user_message"] is None
    assert inventory["rows"][0]["first_user_message_length"] == len("private first message")
    assert inventory["rows"][0]["preview"] is None
    assert inventory["rows"][0]["preview_length"] == len("private preview")


def test_thread_index_inspection_can_include_private_text(fake_thread_index):
    inventory = inspect_thread_index(fake_thread_index, include_private_text=True)

    assert inventory["privacy"]["private_text_redacted"] is False
    assert inventory["rows"][0]["title"] == "Active title"
    assert inventory["rows"][0]["first_user_message"] == "private first message"
    assert inventory["rows"][0]["preview"] == "private preview"


def test_thread_index_inspection_filters_archived(fake_thread_index):
    inventory = inspect_thread_index(fake_thread_index, archive_filter="archived")

    assert [row["id"] for row in inventory["rows"]] == ["thread-archived"]


def test_thread_index_inspection_handles_uri_special_characters(tmp_path, fake_thread_index):
    special_database = tmp_path / "codex state #5.sqlite"
    shutil.copyfile(fake_thread_index, special_database)

    inventory = inspect_thread_index(special_database, archive_filter="unarchived")

    assert inventory["schema_status"]["compatible"] is True
    assert [row["id"] for row in inventory["rows"]] == ["thread-active"]
    assert "future SwiftASB direct-storage feature" in inventory["warning"]


def test_cli_threads_inspect_index_outputs_json(fake_thread_index, capsys):
    exit_code = main(["threads", "inspect-index", "--database", str(fake_thread_index), "--cwd", "/repo", "--unarchived"])
    captured = capsys.readouterr()

    assert exit_code == 0
    inventory = json.loads(captured.out)
    assert inventory["filters"]["archive"] == "unarchived"
    assert [row["id"] for row in inventory["rows"]] == ["thread-active"]
