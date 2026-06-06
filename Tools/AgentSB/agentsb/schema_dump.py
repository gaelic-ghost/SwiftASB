from __future__ import annotations

import json
import subprocess
from pathlib import Path
from typing import Any

from .tools import AgentSBError, resolve_repo_root


def run_schema_dump_script(
    repo: str | Path,
    mode: str,
    *,
    brew_check: bool = False,
    brew_upgrade: bool = False,
    stable: bool = False,
    force: bool = False,
) -> dict[str, Any]:
    root = resolve_repo_root(repo)
    script = root / "scripts" / "dump-codex-schemas.sh"
    if not script.exists():
        raise AgentSBError(f"SwiftASB schema dump script does not exist: {script}")

    args = [str(script)]
    if mode == "check":
        args.append("--check")
    elif mode == "dump-if-newer":
        args.append("--dump-if-newer")
    elif mode == "brew-upgrade-and-dump":
        args.extend(["--brew-upgrade-codex", "--dump-after-upgrade"])
    else:
        raise AgentSBError(f"Unknown schema dump script mode: {mode}")

    if brew_check:
        args.append("--brew-check")
    if stable:
        args.append("--stable")
    if force:
        args.append("--force")
    args.append("--json")

    result = subprocess.run(
        args,
        cwd=root,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "no diagnostic output"
        raise AgentSBError(f"Schema dump script failed in {root}: {detail}")
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise AgentSBError(f"Schema dump script returned invalid JSON: {error}: {result.stdout}") from error
