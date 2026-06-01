from __future__ import annotations

import re
import subprocess
from pathlib import Path
from typing import Any


class AgentSBError(RuntimeError):
    """Raised when AgentSB cannot inspect the requested repository."""


def resolve_repo_root(repo: str | Path) -> Path:
    root = Path(repo).expanduser().resolve()
    if not root.exists():
        raise AgentSBError(f"Repository path does not exist: {root}")
    if not root.is_dir():
        raise AgentSBError(f"Repository path is not a directory: {root}")
    if not (root / "Package.swift").exists():
        raise AgentSBError(f"Expected SwiftASB Package.swift at repository root: {root}")
    return root


def inspect_repo(repo: str | Path) -> dict[str, Any]:
    root = resolve_repo_root(repo)
    return {
        "repo_root": str(root),
        "git": inspect_git(root),
        "reviewed_codex_cli_window": reviewed_codex_cli_window(root),
        "schema_dumps": schema_dumps(root),
        "promoted_wire_files": promoted_wire_files(root),
        "docs": docs_inventory(root),
    }


def inspect_git(root: Path) -> dict[str, Any]:
    branch = _git(root, ["branch", "--show-current"]) or "(detached)"
    status_lines = [line for line in _git(root, ["status", "--short"]).splitlines() if line]
    upstream = _git(root, ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"], check=False)
    return {
        "branch": branch,
        "upstream": upstream or None,
        "dirty": bool(status_lines),
        "status": status_lines,
    }


def reviewed_codex_cli_window(root: Path) -> dict[str, str | None]:
    roadmap = root / "ROADMAP.md"
    if not roadmap.exists():
        return {"window": None, "source": None}

    text = roadmap.read_text(encoding="utf-8")
    patterns = [
        r"current reviewed compatibility window is `codex-cli ([^`]+)`",
        r"current-reviewed Codex CLI support window of `([^`]+)`",
        r"current Codex CLI compatibility window.*?`([^`]+)`",
    ]
    for pattern in patterns:
        match = re.search(pattern, text, flags=re.IGNORECASE | re.DOTALL)
        if match:
            return {"window": match.group(1), "source": "ROADMAP.md"}
    return {"window": None, "source": "ROADMAP.md"}


def schema_dumps(root: Path) -> list[dict[str, Any]]:
    schema_root = root / "codex-schemas"
    if not schema_root.exists():
        return []

    dumps: list[dict[str, Any]] = []
    for path in sorted(schema_root.iterdir(), key=lambda item: item.name):
        if not path.is_dir():
            continue
        dumps.append(
            {
                "name": path.name,
                "variant": "stable" if path.name.endswith("-stable") else "experimental",
                "json_files": len(list(path.rglob("*.json"))),
            }
        )
    return dumps


def promoted_wire_files(root: Path) -> list[dict[str, Any]]:
    latest = root / "Sources" / "SwiftASB" / "Generated" / "CodexWire" / "Latest"
    if not latest.exists():
        return []

    files: list[dict[str, Any]] = []
    for path in sorted(latest.glob("*.swift"), key=lambda item: item.name):
        files.append(
            {
                "path": str(path.relative_to(root)),
                "name": path.name,
                "bytes": path.stat().st_size,
            }
        )
    return files


def docs_inventory(root: Path) -> dict[str, Any]:
    named_docs = ["AGENTS.md", "README.md", "CONTRIBUTING.md", "ROADMAP.md"]
    maintainer_dir = root / "docs" / "maintainers"
    maintainer_docs = sorted(
        str(path.relative_to(root))
        for path in maintainer_dir.glob("*.md")
        if path.is_file()
    ) if maintainer_dir.exists() else []

    return {
        "named_docs": [
            {
                "path": name,
                "exists": (root / name).exists(),
                "bytes": (root / name).stat().st_size if (root / name).exists() else 0,
            }
            for name in named_docs
        ],
        "maintainer_docs": maintainer_docs,
    }


def _git(root: Path, args: list[str], *, check: bool = True) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=root,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        if check:
            detail = result.stderr.strip() or result.stdout.strip() or "no diagnostic output"
            raise AgentSBError(f"git {' '.join(args)} failed in {root}: {detail}")
        return ""
    return result.stdout.strip()
