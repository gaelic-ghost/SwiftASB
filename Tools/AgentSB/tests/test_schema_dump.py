from __future__ import annotations

from agentsb.schema_dump import run_schema_dump_script
from agentsb.tools import AgentSBError

import pytest


def test_schema_dump_script_check_reports_drift(fake_repo):
    summary = run_schema_dump_script(fake_repo, "check", brew_check=True)

    assert summary["installed_codex_cli"] == "0.136.0"
    assert summary["installed_newer_than_local"] is True
    assert summary["brew"]["status"] == "checked"


def test_schema_dump_script_brew_upgrade_mode_is_explicit(fake_repo):
    summary = run_schema_dump_script(fake_repo, "brew-upgrade-and-dump")

    assert summary["dumped"] is True
    assert summary["brew"]["status"] == "checked"


def test_schema_dump_script_rejects_unknown_mode(fake_repo):
    with pytest.raises(AgentSBError, match="Unknown schema dump script mode"):
        run_schema_dump_script(fake_repo, "upgrade-everything")


def test_schema_dump_script_reports_missing_script(fake_repo):
    (fake_repo / "scripts" / "dump-codex-schemas.sh").unlink()

    with pytest.raises(AgentSBError, match="does not exist"):
        run_schema_dump_script(fake_repo, "check")


def test_schema_dump_script_reports_failed_script(fake_repo):
    script = fake_repo / "scripts" / "dump-codex-schemas.sh"
    script.write_text("#!/bin/sh\nprintf 'boom\\n' >&2\nexit 7\n", encoding="utf-8")

    with pytest.raises(AgentSBError, match="boom"):
        run_schema_dump_script(fake_repo, "check")


def test_schema_dump_script_reports_invalid_json(fake_repo):
    script = fake_repo / "scripts" / "dump-codex-schemas.sh"
    script.write_text("#!/bin/sh\nprintf 'not-json\\n'\n", encoding="utf-8")

    with pytest.raises(AgentSBError, match="invalid JSON"):
        run_schema_dump_script(fake_repo, "check")
