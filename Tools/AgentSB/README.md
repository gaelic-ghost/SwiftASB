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

Compare two dumped Codex CLI schema versions:

```bash
uv run agentsb schema diff --repo ../.. --base v0.133.0 --target v0.135.0
```

Inspect the private local Codex thread index in read-only mode:

```bash
uv run agentsb threads inspect-index --cwd /Users/galew/Workspace/gaelic-ghost/SwiftASB --unarchived
```

Private prompt and preview text is redacted by default. Pass
`--include-private-text` only for local maintainer investigations that need it.
This command is a prototype and reporting aid for the future SwiftASB
direct-thread-storage feature; it is not the final package API.

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

Run the deterministic eval suite:

```bash
uv run agentsb eval local
```

The current eval suite checks report rendering and the first safety
classification rules for future auto-apply behavior. Results are written to
`evals/results/latest.json`.

Run AI-assisted evals only when credentials are available:

```bash
OPENAI_API_KEY=... uv run agentsb eval ai
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
