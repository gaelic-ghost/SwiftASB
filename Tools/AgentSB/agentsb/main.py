from __future__ import annotations

import argparse
import asyncio
import json
import sys
from pathlib import Path

from .coordinator import default_openai_model, run_ai_notes
from .evals import run_ai_evals, run_local_evals
from .maintain import auto_apply_safe, write_maintenance_draft
from .reports import write_report
from .schema_dump import run_schema_dump_script
from .schema_diff import diff_schema_dumps, latest_schema_diff
from .thread_index import default_database_path, inspect_thread_index
from .tools import AgentSBError, inspect_repo


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_error:
        return int(exit_error.code or 0)

    try:
        if args.command == "inspect":
            facts = inspect_repo(args.repo)
            print(json.dumps(facts, indent=2, sort_keys=True))
            return 0

        if args.command == "report" and args.report_command == "schema-review":
            facts = inspect_repo(args.repo)
            schema_diff = latest_schema_diff(args.repo, facts["schema_dumps"])
            ai_model = args.model or default_openai_model()
            ai_notes = asyncio.run(run_ai_notes(facts, model=ai_model)) if args.ai else None
            path = write_report(
                args.repo,
                "schema-review",
                facts,
                ai_notes=ai_notes,
                ai_model=ai_model if args.ai else None,
                schema_diff=schema_diff,
            )
            print(f"Wrote AgentSB schema-review report: {path}")
            return 0

        if args.command == "maintain":
            if args.draft == args.auto_apply_safe:
                print("AgentSB error: choose exactly one of --draft or --auto-apply-safe", file=sys.stderr)
                return 2
            if args.draft:
                path = write_maintenance_draft(args.repo)
                print(f"Wrote AgentSB maintenance draft: {path}")
                return 0
            path = auto_apply_safe(args.repo)
            print(f"Wrote AgentSB auto-apply-safe report: {path}")
            return 0

        if args.command == "eval" and args.eval_command == "local":
            return run_local_evals()

        if args.command == "eval" and args.eval_command == "ai":
            return run_ai_evals(model=args.model)

        if args.command == "schema" and args.schema_command == "diff":
            diff = diff_schema_dumps(args.repo, args.base, args.target)
            print(json.dumps(diff, indent=2, sort_keys=True))
            return 0

        if args.command == "schema" and args.schema_command in {"check", "dump-if-newer", "brew-upgrade-and-dump"}:
            summary = run_schema_dump_script(
                args.repo,
                args.schema_command,
                brew_check=args.brew_check,
                stable=args.stable,
                force=args.force,
            )
            print(json.dumps(summary, indent=2, sort_keys=True))
            return 0

        if args.command == "threads" and args.threads_command == "inspect-index":
            archive_filter = _archive_filter(args)
            inventory = inspect_thread_index(
                args.database,
                cwd=args.cwd,
                archive_filter=archive_filter,
                limit=args.limit,
                include_private_text=args.include_private_text,
            )
            print(json.dumps(inventory, indent=2, sort_keys=True))
            return 0

        parser.print_help()
        return 2
    except (AgentSBError, RuntimeError) as error:
        print(f"AgentSB error: {error}", file=sys.stderr)
        return 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="agentsb",
        description=(
            "AgentSB writes durable SwiftASB maintenance reports under "
            "docs/agents/reports. Default commands do not call the OpenAI API."
        ),
    )
    subcommands = parser.add_subparsers(dest="command")

    inspect = subcommands.add_parser("inspect", help="Print deterministic SwiftASB repo facts as JSON.")
    inspect.add_argument("--repo", type=Path, default=Path.cwd(), help="SwiftASB repository root.")

    report = subcommands.add_parser("report", help="Write a durable AgentSB report.")
    report_subcommands = report.add_subparsers(dest="report_command")
    schema_review = report_subcommands.add_parser(
        "schema-review",
        help="Write a Codex CLI schema-review maintenance report.",
    )
    schema_review.add_argument("--repo", type=Path, default=Path.cwd(), help="SwiftASB repository root.")
    schema_review.add_argument(
        "--ai",
        action="store_true",
        help="Use OpenAI Agents SDK notes. Requires OPENAI_API_KEY.",
    )
    schema_review.add_argument(
        "--model",
        default=None,
        help=f"OpenAI model for --ai notes. Defaults to AGENTSB_OPENAI_MODEL, OPENAI_DEFAULT_MODEL, or {default_openai_model()}.",
    )

    maintain = subcommands.add_parser("maintain", help="Draft or safely apply AgentSB maintenance work.")
    maintain.add_argument("--repo", type=Path, default=Path.cwd(), help="SwiftASB repository root.")
    maintain_mode = maintain.add_mutually_exclusive_group()
    maintain_mode.add_argument(
        "--draft",
        action="store_true",
        help="Write a reviewable maintenance draft without applying proposed source changes.",
    )
    maintain_mode.add_argument(
        "--auto-apply-safe",
        action="store_true",
        help="Apply only classifier-approved safe AgentSB-owned changes and report refusals.",
    )

    eval_parser = subcommands.add_parser("eval", help="Run AgentSB eval suites.")
    eval_subcommands = eval_parser.add_subparsers(dest="eval_command")
    eval_subcommands.add_parser("local", help="Run deterministic local evals without OPENAI_API_KEY.")
    ai_eval = eval_subcommands.add_parser("ai", help="Run planned AI-assisted evals. Requires OPENAI_API_KEY.")
    ai_eval.add_argument(
        "--model",
        default=None,
        help=f"OpenAI model for AI evals. Defaults to AGENTSB_OPENAI_MODEL, OPENAI_DEFAULT_MODEL, or {default_openai_model()}.",
    )

    schema_parser = subcommands.add_parser("schema", help="Inspect dumped Codex CLI schemas.")
    schema_subcommands = schema_parser.add_subparsers(dest="schema_command")
    schema_check = schema_subcommands.add_parser("check", help="Check installed Codex CLI and local schema dump drift.")
    _add_schema_script_arguments(schema_check)
    schema_dump = schema_subcommands.add_parser(
        "dump-if-newer",
        help="Call the SwiftASB schema dump script only when installed Codex is newer than local dumps.",
    )
    _add_schema_script_arguments(schema_dump)
    schema_upgrade = schema_subcommands.add_parser(
        "brew-upgrade-and-dump",
        help="Explicitly upgrade the Codex Homebrew package, then dump schemas if the CLI is newer.",
    )
    _add_schema_script_arguments(schema_upgrade)
    schema_diff = schema_subcommands.add_parser("diff", help="Compare two dumped Codex CLI schema versions.")
    schema_diff.add_argument("--repo", type=Path, default=Path.cwd(), help="SwiftASB repository root.")
    schema_diff.add_argument("--base", required=True, help="Base schema dump name, such as v0.133.0.")
    schema_diff.add_argument("--target", required=True, help="Target schema dump name, such as v0.135.0.")

    threads_parser = subcommands.add_parser("threads", help="Inspect private local Codex thread storage.")
    threads_subcommands = threads_parser.add_subparsers(dest="threads_command")
    inspect_index = threads_subcommands.add_parser(
        "inspect-index",
        help="Read the Codex thread SQLite index in read-only mode.",
    )
    inspect_index.add_argument(
        "--database",
        type=Path,
        default=default_database_path(),
        help="Codex state SQLite path. Defaults to ~/.codex/state_5.sqlite.",
    )
    inspect_index.add_argument("--cwd", help="Filter threads to a repository cwd.")
    archive_group = inspect_index.add_mutually_exclusive_group()
    archive_group.add_argument("--archived", action="store_true", help="Only include archived threads.")
    archive_group.add_argument("--unarchived", action="store_true", help="Only include unarchived threads.")
    archive_group.add_argument("--all", action="store_true", help="Include archived and unarchived threads.")
    inspect_index.add_argument("--limit", type=int, default=20, help="Maximum rows to return.")
    inspect_index.add_argument(
        "--include-private-text",
        action="store_true",
        help="Include first user message and preview text. Redacted by default.",
    )

    return parser


def _add_schema_script_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--repo", type=Path, default=Path.cwd(), help="SwiftASB repository root.")
    parser.add_argument("--brew-check", action="store_true", help="Include `brew outdated` status in the schema check.")
    parser.add_argument("--stable", action="store_true", help="Use stable schema dumps instead of experimental dumps.")
    parser.add_argument("--force", action="store_true", help="Replace an existing schema dump for the detected version.")


def _archive_filter(args: argparse.Namespace) -> str:
    if getattr(args, "archived", False):
        return "archived"
    if getattr(args, "unarchived", False):
        return "unarchived"
    return "all"


if __name__ == "__main__":
    raise SystemExit(main())
