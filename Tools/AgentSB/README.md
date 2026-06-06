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

Schema-review reports include the latest available schema dump diff evidence
when at least two local dumps exist under `codex-schemas/`.

Use AI-assisted report notes with an explicit model:

```bash
uv run agentsb report schema-review --repo ../.. --ai --model gpt-5.5
```

If `--model` is omitted, AgentSB uses `AGENTSB_OPENAI_MODEL`,
`OPENAI_DEFAULT_MODEL`, or `gpt-5.4-mini`, in that order. AI-generated reports
record the chosen model in the `Agent Notes` section.

Check installed Codex CLI drift against local schema dumps:

```bash
uv run agentsb schema check --repo ../..
```

Dump schemas only when the installed Codex CLI is newer than the latest local
dump:

```bash
uv run agentsb schema dump-if-newer --repo ../..
```

Include Homebrew outdated status in the check:

```bash
uv run agentsb schema check --repo ../.. --brew-check
```

Explicitly upgrade the Codex Homebrew package and dump schemas afterward:

```bash
uv run agentsb schema brew-upgrade-and-dump --repo ../..
```

This command is intentionally separate from ordinary report generation because
it changes the local Codex installation.

Compare two dumped Codex CLI schema versions:

```bash
uv run agentsb schema diff --repo ../.. --base v0.133.0 --target v0.135.0
```

Write a reviewable maintenance draft without applying proposed source changes:

```bash
uv run agentsb maintain --repo ../.. --draft
```

Maintenance drafts include predictable Codex CLI compatibility follow-up patches
when AgentSB sees a newer schema dump than SwiftASB's reviewed window. Those
drafts can cover version-window docs, `scripts/generate-wire-types.sh`, the
internal CLI compatibility gate, and AgentSB's own current-window assertions.
Generated wire snapshots and unclassified schema-family promotion remain
report-only.

Apply only classifier-approved safe AgentSB-owned changes and report every
refusal:

```bash
uv run agentsb maintain --repo ../.. --auto-apply-safe
```

The current safe auto-apply surface is intentionally narrow: AgentSB can create
AgentSB-owned reports under `docs/agents/reports/`. It refuses generated wire,
Swift public API, release automation, behavior-changing candidates, and
meaning-changing docs updates that need maintainer review.

Inspect the private local Codex thread index in read-only mode:

```bash
uv run agentsb threads inspect-index --cwd /Users/galew/Workspace/gaelic-ghost/SwiftASB --unarchived
```

Private title, prompt, and preview text is redacted by default. Pass
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

Hosted Agents SDK tracing is disabled by default for AgentSB CLI runs so report
generation does not wait on trace export at process shutdown. Set
`AGENTSB_ENABLE_TRACING=1` to opt back into hosted tracing for a run.

Run the deterministic eval suite:

```bash
uv run agentsb eval local
```

The current eval suite checks report rendering and the first safety
classification rules for future auto-apply behavior. Results are written to
`evals/results/latest.json`.

Run AI-assisted evals only when credentials are available:

```bash
OPENAI_API_KEY=... uv run agentsb eval ai --model gpt-5.5
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
