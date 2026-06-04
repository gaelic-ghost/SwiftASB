from __future__ import annotations

import json

from agentsb.main import main
from agentsb.schema_diff import diff_schema_dumps


def test_schema_diff_detects_added_removed_and_changed_files(fake_repo):
    diff = diff_schema_dumps(fake_repo, "v0.135.0", "v0.136.0")

    assert diff["summary"] == {
        "added": 1,
        "removed": 1,
        "changed": 1,
        "unchanged": 1,
    }
    assert diff["added"] == ["added.json"]
    assert diff["removed"] == ["removed.json"]
    assert diff["changed"] == ["changed.json"]


def test_cli_schema_diff_outputs_json(fake_repo, capsys):
    exit_code = main(["schema", "diff", "--repo", str(fake_repo), "--base", "v0.135.0", "--target", "v0.136.0"])
    captured = capsys.readouterr()

    assert exit_code == 0
    diff = json.loads(captured.out)
    assert diff["summary"]["added"] == 1
    assert diff["summary"]["removed"] == 1
    assert diff["summary"]["changed"] == 1
