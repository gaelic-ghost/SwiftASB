from __future__ import annotations

import os
from typing import Any

from .specialists import boundary_reviewer, docs_auditor, probe_planner, require_agents_sdk, schema_scout

DEFAULT_OPENAI_MODEL = "gpt-5.4-mini"


def default_openai_model() -> str:
    return os.environ.get("AGENTSB_OPENAI_MODEL") or os.environ.get("OPENAI_DEFAULT_MODEL") or DEFAULT_OPENAI_MODEL


def hosted_tracing_enabled() -> bool:
    return os.environ.get("AGENTSB_ENABLE_TRACING", "").lower() in {"1", "true", "yes", "on"}


def build_run_config(*, workflow_name: str):
    from agents import RunConfig

    return RunConfig(
        tracing_disabled=not hosted_tracing_enabled(),
        workflow_name=workflow_name,
    )


def build_coordinator(model: str | None = None):
    agent_type = require_agents_sdk()
    specialists = [
        schema_scout().as_tool(
            tool_name="schema_scout",
            tool_description="Review Codex CLI schema inspection facts for SwiftASB.",
        ),
        boundary_reviewer().as_tool(
            tool_name="boundary_reviewer",
            tool_description="Classify schema families against SwiftASB public API boundaries.",
        ),
        docs_auditor().as_tool(
            tool_name="docs_auditor",
            tool_description="Review SwiftASB maintainer and product docs for likely drift.",
        ),
        probe_planner().as_tool(
            tool_name="probe_planner",
            tool_description="Recommend focused SwiftASB validation and live Codex probes.",
        ),
    ]
    return agent_type(
        name="AgentSB Coordinator",
        instructions=(
            "You are AgentSB, the SwiftASB repo maintenance coordinator. Produce "
            "short maintainer notes only. Do not claim that generated schemas should "
            "be promoted without an explicit boundary classification. Do not ask to "
            "mutate source files, releases, tags, or generated wire snapshots. "
            "When classifying a maintenance candidate, generated wire snapshot "
            "changes and unclassified schema-family promotions are report-only, "
            "not draft-only or auto-apply."
        ),
        model=model or default_openai_model(),
        tools=specialists,
    )


async def run_ai_notes(facts: dict[str, Any], *, model: str | None = None) -> str:
    if not os.environ.get("OPENAI_API_KEY"):
        raise RuntimeError(
            "OPENAI_API_KEY is required for `--ai` reports. Run without `--ai` "
            "to create a deterministic report skeleton."
        )

    from agents import Runner

    prompt = (
        "Create concise AgentSB maintainer notes from these deterministic "
        f"SwiftASB inspection facts:\n{facts!r}"
    )
    result = await Runner.run(
        build_coordinator(model),
        prompt,
        run_config=build_run_config(workflow_name="AgentSB schema review"),
    )
    return str(result.final_output)
