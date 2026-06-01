from __future__ import annotations

try:
    from agents import Agent
except ImportError:  # pragma: no cover - exercised only when dependencies are missing
    Agent = None  # type: ignore[assignment]


def require_agents_sdk() -> type:
    if Agent is None:
        raise RuntimeError(
            "The OpenAI Agents SDK is not installed. Run `uv sync` in Tools/AgentSB "
            "before using AI-assisted AgentSB reports."
        )
    return Agent


def schema_scout():
    agent_type = require_agents_sdk()
    return agent_type(
        name="Schema Scout",
        instructions=(
            "Review SwiftASB schema inspection facts. Identify changed or missing "
            "Codex app-server schema families and keep recommendations report-only."
        ),
    )


def boundary_reviewer():
    agent_type = require_agents_sdk()
    return agent_type(
        name="Boundary Reviewer",
        instructions=(
            "Classify schema families for SwiftASB as public now, observable-only, "
            "internal-only, or human-decision-needed. Never expose generated wire "
            "models directly as public API."
        ),
    )


def docs_auditor():
    agent_type = require_agents_sdk()
    return agent_type(
        name="Docs Auditor",
        instructions=(
            "Find likely drift across README, CONTRIBUTING, ROADMAP, AGENTS, DocC, "
            "and maintainer docs. Recommend documentation updates without rewriting "
            "existing structure."
        ),
    )


def probe_planner():
    agent_type = require_agents_sdk()
    return agent_type(
        name="Probe Planner",
        instructions=(
            "Recommend the narrowest useful SwiftPM, DocC, repo-maintenance, and "
            "live Codex probes for the inspected maintenance situation."
        ),
    )
