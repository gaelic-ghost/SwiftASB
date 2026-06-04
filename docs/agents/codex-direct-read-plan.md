# AgentSB Direct Read Prototype Plan

AgentSB may use direct local Codex reads as an experimental maintainer lane for
faster reports and for prototyping the future SwiftASB direct-thread-storage
feature. This lane is private, read-only by default, and version-gated. The
destination feature is tracked in
[`../maintainers/codex-direct-thread-storage-plan.md`](../maintainers/codex-direct-thread-storage-plan.md).

## Goal

Use local Codex storage to help design and validate a faster SwiftASB thread
inventory path without clogging the CLI/app-server JSONL pipe. The first AgentSB
target is thread inventory: read SQLite metadata first, then lazily read
referenced JSONL only when deeper turn evidence is needed.

## Supported Storage Contract

The first experimental contract targets the local Codex storage shape observed
on 2026-06-04:

- `~/.codex/state_5.sqlite`
- table: `threads`
- rollout JSONL paths under `~/.codex/sessions/` and
  `~/.codex/archived_sessions/`
- active and archived JSONL using the same broad envelope families:
  `session_meta`, `turn_context`, `event_msg`, and `response_item`

AgentSB must treat this as a prototype compatibility window, not a
forever-stable schema. If the table, required columns, or path conventions
drift, AgentSB should report the mismatch and stop before reading deeper
content.

## Direct Read Principles

- Open SQLite databases read-only.
- Never mutate Codex state, archive flags, JSONL files, logs, goals, or app
  support files.
- Prefer metadata summaries over prompt/tool-content ingestion.
- Redact private text by default, including first user messages and previews.
- Require an explicit flag before including private prompt or preview text.
- Read JSONL lazily and only for selected rows.
- Keep direct-read outputs labeled as private local Codex storage observations.
- Keep app-server surfaces authoritative for product behavior, archive actions,
  live state, and compatibility claims while SwiftASB's direct-read design is
  still experimental.

## First Implementation Slice

Add:

```bash
uv run agentsb threads inspect-index
```

The command should:

- default to `~/.codex/state_5.sqlite`;
- accept `--database` for fixture or alternate local stores;
- accept `--cwd` to focus on a repository;
- accept `--archived`, `--unarchived`, and `--all`;
- accept `--limit`;
- open the database in SQLite read-only mode;
- validate that required columns exist;
- print JSON with schema status, counts, and recent rows;
- redact private text unless `--include-private-text` is passed.

## Future Implementation Slices

1. Add JSONL evidence sampling.
   Use `threads.rollout_path` to read only selected JSONL files. Extract event
   envelope counts, first/last turn ids, and tool-call summaries without loading
   whole transcripts by default.

2. Add report generation.
   Write durable reports under `docs/agents/reports/` that summarize index
   state, archived/current split, cwd grouping, and candidate threads for deeper
   review.

3. Add version gates.
   Record observed Codex CLI version, GUI storage version if detectable, SQLite
   table hash, and required-column compatibility in every direct-read report so
   SwiftASB can decide which storage windows to support.

4. Add evals.
   Fixture SQLite databases should cover active threads, archived threads,
   missing columns, unknown extra columns, redacted text, and private-text opt-in.

5. Add safety classification.
   Direct-read code changes should default to `draft-only` unless they are
   fixture-only or AgentSB-owned report formatting. Direct-read source changes
   should not auto-apply until compatibility evals are stable.

## Risks

- Local Codex storage is private implementation detail.
- Active JSONL files may be mid-write.
- SQLite rows and app-server semantics may disagree during migrations or live
  updates.
- Local files can contain sensitive user prompts, tool outputs, paths, and
  credentials.
- Archive state may be represented by both SQLite metadata and file placement.
- Supported Codex CLI and GUI versions may need explicit locks for any direct
  read behavior used beyond local experiments.

## Decision

Proceed with AgentSB direct reads as prototype and reporting tooling only. The
actual direct-read capability should be designed and reviewed as a SwiftASB
feature with explicit version support, privacy defaults, and caller-facing
ownership.
