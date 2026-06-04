from __future__ import annotations

import sqlite3
from pathlib import Path
from typing import Any, Literal

from .tools import AgentSBError

ArchiveFilter = Literal["all", "archived", "unarchived"]

REQUIRED_THREAD_COLUMNS = {
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
}

OPTIONAL_THREAD_COLUMNS = {
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
}


def default_database_path() -> Path:
    return Path.home() / ".codex" / "state_5.sqlite"


def inspect_thread_index(
    database: str | Path | None = None,
    *,
    cwd: str | None = None,
    archive_filter: ArchiveFilter = "all",
    limit: int = 20,
    include_private_text: bool = False,
) -> dict[str, Any]:
    if limit < 1:
        raise AgentSBError("Thread index limit must be at least 1.")
    database_path = Path(database).expanduser().resolve() if database else default_database_path()
    if not database_path.exists():
        raise AgentSBError(f"Codex thread index database does not exist: {database_path}")

    with _connect_read_only(database_path) as connection:
        columns = _thread_columns(connection)
        missing = sorted(REQUIRED_THREAD_COLUMNS - columns)
        extra = sorted(columns - REQUIRED_THREAD_COLUMNS - OPTIONAL_THREAD_COLUMNS)
        if missing:
            return {
                "database": str(database_path),
                "schema_status": {
                    "compatible": False,
                    "missing_required_columns": missing,
                    "extra_columns": extra,
                },
                "counts": {},
                "rows": [],
            }

        counts = _counts(connection, cwd=cwd)
        rows = _rows(
            connection,
            columns=columns,
            cwd=cwd,
            archive_filter=archive_filter,
            limit=limit,
            include_private_text=include_private_text,
        )
    return {
        "database": str(database_path),
        "schema_status": {
            "compatible": True,
            "missing_required_columns": [],
            "extra_columns": extra,
        },
        "filters": {
            "cwd": cwd,
            "archive": archive_filter,
            "limit": limit,
            "include_private_text": include_private_text,
        },
        "counts": counts,
        "rows": rows,
        "privacy": {
            "private_text_redacted": not include_private_text,
            "private_text_fields": ["first_user_message", "preview"],
        },
        "warning": (
            "Direct thread index reads use private local Codex storage and are "
            "intended for AgentSB maintainer reports, not SwiftASB public API."
        ),
    }


def _connect_read_only(path: Path) -> sqlite3.Connection:
    uri = f"file:{path}?mode=ro"
    try:
        connection = sqlite3.connect(uri, uri=True)
    except sqlite3.Error as error:
        raise AgentSBError(f"Could not open Codex thread index read-only: {path}: {error}") from error
    connection.row_factory = sqlite3.Row
    return connection


def _thread_columns(connection: sqlite3.Connection) -> set[str]:
    try:
        rows = connection.execute("pragma table_info(threads)").fetchall()
    except sqlite3.Error as error:
        raise AgentSBError(f"Could not inspect threads table columns: {error}") from error
    if not rows:
        raise AgentSBError("Codex thread index database does not contain a threads table.")
    return {str(row["name"]) for row in rows}


def _counts(connection: sqlite3.Connection, *, cwd: str | None) -> dict[str, int]:
    where, params = _where(cwd=cwd, archive_filter="all")
    row = connection.execute(
        "select count(*) as total, "
        "sum(case when archived then 1 else 0 end) as archived, "
        "sum(case when not archived then 1 else 0 end) as unarchived "
        f"from threads {where}",
        params,
    ).fetchone()
    return {
        "total": int(row["total"] or 0),
        "archived": int(row["archived"] or 0),
        "unarchived": int(row["unarchived"] or 0),
    }


def _rows(
    connection: sqlite3.Connection,
    *,
    columns: set[str],
    cwd: str | None,
    archive_filter: ArchiveFilter,
    limit: int,
    include_private_text: bool,
) -> list[dict[str, Any]]:
    selected_columns = [
        "id",
        "rollout_path",
        "created_at",
        "updated_at",
        "cwd",
        "title",
        "source",
        "model_provider",
        "sandbox_policy",
        "approval_mode",
        "tokens_used",
        "archived",
        "archived_at",
    ]
    for optional in [
        "created_at_ms",
        "updated_at_ms",
        "cli_version",
        "git_sha",
        "git_branch",
        "git_origin_url",
        "model",
        "reasoning_effort",
        "agent_nickname",
        "agent_role",
        "agent_path",
        "memory_mode",
        "thread_source",
        "first_user_message",
        "preview",
    ]:
        if optional in columns:
            selected_columns.append(optional)

    where, params = _where(cwd=cwd, archive_filter=archive_filter)
    order_column = "updated_at_ms" if "updated_at_ms" in columns else "updated_at"
    query = (
        f"select {', '.join(selected_columns)} from threads {where} "
        f"order by {order_column} desc, id desc limit ?"
    )
    rows = connection.execute(query, [*params, limit]).fetchall()
    return [_normalize_row(row, include_private_text=include_private_text) for row in rows]


def _where(*, cwd: str | None, archive_filter: ArchiveFilter) -> tuple[str, list[Any]]:
    clauses: list[str] = []
    params: list[Any] = []
    if cwd:
        clauses.append("cwd = ?")
        params.append(cwd)
    if archive_filter == "archived":
        clauses.append("archived = 1")
    elif archive_filter == "unarchived":
        clauses.append("archived = 0")
    elif archive_filter != "all":
        raise AgentSBError(f"Unknown archive filter: {archive_filter}")
    if not clauses:
        return "", params
    return "where " + " and ".join(clauses), params


def _normalize_row(row: sqlite3.Row, *, include_private_text: bool) -> dict[str, Any]:
    result = dict(row)
    result["archived"] = bool(result.get("archived"))
    for field in ["first_user_message", "preview"]:
        if field not in result:
            continue
        value = result.get(field) or ""
        result[f"{field}_length"] = len(value)
        if not include_private_text:
            result[field] = None
    return result
