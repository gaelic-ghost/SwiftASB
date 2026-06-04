# AgentSB Roadmap

AgentSB is the repo-local maintenance agent app for SwiftASB. Its job is to
help maintainers keep Codex CLI schema review, SwiftASB public API boundaries,
docs, probes, and routine repo upkeep moving without turning uncertain upstream
changes into silent source edits.

## Operating Model

AgentSB classifies each maintenance opportunity into one of three outcomes.

| Outcome | Meaning | Default action |
| --- | --- | --- |
| `auto-apply` | The candidate change is proven non-behavioral, does not affect public API, and is covered by deterministic checks. | Apply only when the maintainer opts into safe auto-apply. |
| `draft-only` | The candidate change is useful but needs review because it changes meaning, docs promises, validation expectations, or non-public implementation details. | Write a proposed patch and report, but do not apply it automatically. |
| `report-only` | The candidate needs human classification or is too risky to draft confidently. | Write a durable report with evidence and decisions needed. |

AgentSB should default to `report-only` whenever safety is uncertain.

## Planned Workflow

1. Inspect deterministic repo facts.
   AgentSB reads the current branch, dirty state, reviewed Codex CLI window,
   schema dump directories, promoted wire files, maintainer docs, and package
   metadata without calling the OpenAI API.

2. Produce a durable report.
   AgentSB writes tracked reports under `docs/agents/reports/` so maintenance
   history survives local cleanup tools and can be reviewed like normal docs.

3. Run evals.
   Local evals verify deterministic behavior without credentials. AI-assisted
   evals verify coordinator and specialist behavior when `OPENAI_API_KEY` is
   available.

4. Compare schema families.
   AgentSB compares schema dumps across Codex CLI versions, identifies added,
   removed, and changed families, and records which SwiftASB surfaces may need
   review.

5. Prototype private local Codex storage inspection when explicitly requested.
   AgentSB may use read-only direct ingest for maintainer reports and SwiftASB
   design evidence when the storage version is recognized and private text
   stays redacted by default. The destination capability belongs in SwiftASB.

6. Classify maintenance work.
   The safety classifier assigns each candidate to `auto-apply`, `draft-only`,
   or `report-only`. The classifier must explain the evidence behind each
   decision.

7. Draft changes.
   The patch drafter prepares reviewable diffs for `draft-only` work without
   applying them. Drafts should preserve existing document structure and avoid
   broad rewrites.

8. Auto-apply safe changes.
   The auto-apply runner applies only `auto-apply` candidates, runs the required
   checks, and writes a report describing what changed, why it was safe, and
   what it refused to touch.

## Auto-Apply Safety Rules

AgentSB may classify a candidate as `auto-apply` only when every rule below is
true:

- The candidate is mechanical, local, and reversible.
- The candidate does not change Swift behavior.
- The candidate does not change public API symbols, public DocC promises,
  package products, package dependencies, generated wire snapshots, release
  automation, or live probe expectations.
- The candidate has a deterministic before-and-after check.
- The candidate has no unresolved ambiguity in repo facts, schema facts, docs
  ownership, or maintainer intent.

If any rule cannot be proven, the candidate must become `draft-only` or
`report-only`.

## Auto-Apply Eligible Examples

- Creating a new AgentSB report under `docs/agents/reports/`.
- Updating an AgentSB-owned report index from existing tracked reports.
- Normalizing AgentSB-owned Markdown report formatting.
- Refreshing a compatibility-window mention only when deterministic inspection
  proves the exact old and new values and the owning document is AgentSB-owned.

## Auto-Apply Forbidden Examples

- Promoting generated schema output under
  `Sources/SwiftASB/Generated/CodexWire/Latest/`.
- Changing Swift public API, symbol names, package products, or dependencies.
- Changing live Codex probe expectations.
- Editing release automation, tags, GitHub release notes, or branch-protection
  settings.
- Rewriting README or DocC claims about supported runtime behavior.
- Applying any schema-family promotion before a maintainer classifies that
  family as public, observable-only, or internal-only.

## Draft-Only Examples

- Updating README, CONTRIBUTING, ROADMAP, or DocC wording when the text changes
  the maintainer or user-facing meaning.
- Drafting schema-family classifications from a new Codex CLI dump.
- Drafting probe expectation changes after live runtime behavior shifts.
- Drafting package code changes that do not expose public API but may affect
  runtime behavior.

## Report-Only Examples

- Brand-new Codex app-server schema families.
- Behavior-changing Codex CLI runtime observations.
- Public API ownership questions.
- Missing schema dumps or missing evidence.
- Any candidate whose safe classification depends on human judgment.

## Evals Plan

AgentSB should keep evals close to the real CLI and report path.

Local evals should run without `OPENAI_API_KEY` and cover:

- `inspect` returns the expected deterministic repo facts.
- `report schema-review` writes only under `docs/agents/reports/`.
- Reports include required sections and human-decision prompts.
- Generated wire changes are never classified as `auto-apply`.
- Public API changes are never classified as `auto-apply`.
- Release automation changes are never classified as `auto-apply`.
- AgentSB-owned report formatting can be classified as `auto-apply`.
- Ambiguous docs changes become `draft-only`.
- Brand-new schema families become `report-only`.

AI-assisted evals should require `OPENAI_API_KEY` and cover:

- The coordinator keeps ownership of the final answer when using specialists as
  tools.
- The coordinator refuses to recommend public API promotion without explicit
  boundary evidence.
- The boundary reviewer uses `public now`, `observable-only`, `internal-only`,
  or `human-decision-needed`.
- The docs auditor preserves document structure and avoids broad rewrites.
- The probe planner recommends narrow validation first and live probes only when
  runtime evidence matters.

## Command Shape

Planned commands:

```bash
uv run agentsb eval local
uv run agentsb eval ai
uv run agentsb threads inspect-index
uv run agentsb maintain --repo ../.. --draft
uv run agentsb maintain --repo ../.. --auto-apply-safe
```

`maintain --auto-apply-safe` must never bypass the safety classifier. It should
apply only candidates classified as `auto-apply`, run the required checks, and
write a durable report for both applied and refused work.

## Rollout Order

1. Report skeleton with deterministic inspection.
2. Local eval harness.
3. AI-assisted eval harness.
4. Schema dump diffing and family inventory.
5. Read-only Codex thread index inspection.
6. Safety classifier with report-only, draft-only, and auto-apply decisions.
7. Patch drafter for `draft-only` changes.
8. Opt-in auto-apply runner for proven-safe changes.
9. Optional repo-maintenance validation integration after the eval suite is
   stable.
