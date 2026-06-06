from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

from .tools import AgentSBError, resolve_repo_root


def diff_schema_dumps(repo: str | Path, base: str, target: str) -> dict[str, Any]:
    root = resolve_repo_root(repo)
    base_dir = _schema_dir(root, base)
    target_dir = _schema_dir(root, target)
    base_files = _schema_file_digests(base_dir)
    target_files = _schema_file_digests(target_dir)
    base_paths = set(base_files)
    target_paths = set(target_files)
    shared_paths = base_paths & target_paths
    changed = sorted(path for path in shared_paths if base_files[path] != target_files[path])
    added = sorted(target_paths - base_paths)
    removed = sorted(base_paths - target_paths)
    return {
        "base": base,
        "target": target,
        "base_path": str(base_dir.relative_to(root)),
        "target_path": str(target_dir.relative_to(root)),
        "added": added,
        "removed": removed,
        "changed": changed,
        "unchanged_count": len(shared_paths) - len(changed),
        "summary": {
            "added": len(added),
            "removed": len(removed),
            "changed": len(changed),
            "unchanged": len(shared_paths) - len(changed),
        },
    }


def latest_schema_diff(repo: str | Path, schema_dumps: list[dict[str, Any]]) -> dict[str, Any] | None:
    if len(schema_dumps) < 2:
        return None
    ordered = sorted(schema_dumps, key=lambda item: item["name"])
    base = ordered[-2]["name"]
    target = ordered[-1]["name"]
    return diff_schema_dumps(repo, base, target)


def _schema_dir(root: Path, version: str) -> Path:
    schema_dir = root / "codex-schemas" / version
    if not schema_dir.exists():
        raise AgentSBError(f"Schema dump does not exist: {schema_dir}")
    if not schema_dir.is_dir():
        raise AgentSBError(f"Schema dump path is not a directory: {schema_dir}")
    return schema_dir


def _schema_file_digests(schema_dir: Path) -> dict[str, str]:
    digests: dict[str, str] = {}
    for path in sorted(schema_dir.rglob("*.json")):
        relative = str(path.relative_to(schema_dir))
        digests[relative] = _canonical_digest(path)
    return digests


def _canonical_digest(path: Path) -> str:
    data = path.read_bytes()
    try:
        decoded = json.loads(data)
    except json.JSONDecodeError:
        canonical = data
    else:
        canonical = json.dumps(decoded, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(canonical).hexdigest()
