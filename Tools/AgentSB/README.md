# AgentSB

AgentSB is a repo-local Python maintainer app for SwiftASB. It produces durable
maintenance reports under `docs/agents/reports/` and keeps version one
report-first: it does not promote generated wire code, change Swift public API,
or run release automation.

## Commands

Inspect deterministic repo facts:

```bash
uv run agentsb inspect --repo ../..
```

Write a schema-review report:

```bash
uv run agentsb report schema-review --repo ../..
```

The default report path is `docs/agents/reports/YYYY-MM-DD-agentsb-schema-review.md`.
If that file already exists, AgentSB appends a numeric suffix.

## OpenAI Agents SDK

AgentSB defines an OpenAI Agents SDK coordinator and specialist agents for schema
review, boundary review, docs drift, and probe planning. The default report
skeleton uses deterministic local inspection so tests and basic reports do not
require `OPENAI_API_KEY`.

Use AI-assisted report notes only when credentials are available:

```bash
OPENAI_API_KEY=... uv run agentsb report schema-review --repo ../.. --ai
```

## Roadmap

AgentSB is intended to grow into a review-first maintenance loop:

1. report deterministic repo facts;
2. run local and AI-assisted evals;
3. compare Codex CLI schema dumps;
4. classify candidates as `auto-apply`, `draft-only`, or `report-only`;
5. draft reviewable patches for unsafe or meaning-changing work;
6. opt into auto-applying only changes proven non-behavioral and non-public-API.

The durable roadmap lives at `docs/agents/agentsb-roadmap.md`.
