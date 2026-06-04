from __future__ import annotations

import argparse
import asyncio
import json
import sys
from pathlib import Path

from .coordinator import run_ai_notes
from .evals import run_ai_evals, run_local_evals
from .reports import write_report
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
            ai_notes = asyncio.run(run_ai_notes(facts)) if args.ai else None
            path = write_report(args.repo, "schema-review", facts, ai_notes=ai_notes)
            print(f"Wrote AgentSB schema-review report: {path}")
            return 0

        if args.command == "eval" and args.eval_command == "local":
            return run_local_evals()

        if args.command == "eval" and args.eval_command == "ai":
            return run_ai_evals()

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

    eval_parser = subcommands.add_parser("eval", help="Run AgentSB eval suites.")
    eval_subcommands = eval_parser.add_subparsers(dest="eval_command")
    eval_subcommands.add_parser("local", help="Run deterministic local evals without OPENAI_API_KEY.")
    eval_subcommands.add_parser("ai", help="Run planned AI-assisted evals. Requires OPENAI_API_KEY.")

    return parser


if __name__ == "__main__":
    raise SystemExit(main())
