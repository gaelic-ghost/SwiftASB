# Codex Direct Thread Storage Plan

This note captures the intended SwiftASB direction for direct local Codex thread
reads. AgentSB can prototype the discovery and reporting mechanics, but the
destination is a SwiftASB package feature with a deliberate public or
semi-public boundary.

## Goal

Add a faster SwiftASB-owned path for thread inventory and selected history
ingest that does not require paging every stored thread through the
`codex app-server` JSONL pipe.

The motivating use case is UI and maintainer workflows that need broad thread
inventory quickly: cwd grouping, archived/current splits, titles, previews,
timestamps, Git facts, CLI versions, token totals, and rollout paths. Direct
reads can fetch this metadata from local Codex indexes much faster than
round-tripping every thread through app-server methods.

## Proposed Ownership Boundary

This should be a SwiftASB feature, not only AgentSB tooling.

- `CodexAppServer` and app-server routes remain the source of truth for live
  behavior, archive/unarchive actions, turns that are actively being produced,
  goals, loaded state, and compatibility promises made by Codex.
- A future SwiftASB direct-storage reader should be a read-only local storage
  capability for discovered thread metadata and selected persisted history.
- AgentSB should remain the prototyping, reporting, and eval harness for this
  work. Its current `threads inspect-index` command is useful evidence for the
  SwiftASB design, not the final product boundary.

## Compatibility Window

Direct reads must be version-gated.

The first experimental compatibility target is the local Codex storage shape
observed on 2026-06-04:

- `~/.codex/state_5.sqlite`
- table: `threads`
- session JSONL under `~/.codex/sessions/YYYY/MM/DD/`
- archived JSONL under `~/.codex/archived_sessions/`
- broad JSONL envelope families: `session_meta`, `turn_context`, `event_msg`,
  and `response_item`

Before SwiftASB exposes any caller-facing direct-read capability, it should
record a supported Codex CLI and GUI storage window. If the SQLite table,
required columns, file locations, or JSONL envelope families drift outside that
window, SwiftASB should fail closed with a descriptive diagnostic.

## Initial SwiftASB Shape

The first durable building-block change should be a read-only storage index
reader with hand-owned Swift values. It should not expose raw SQLite rows or raw
JSONL envelopes.

Likely internal components:

- `CodexLocalThreadIndexReader`: opens the recognized SQLite index read-only,
  validates required columns, and returns thread metadata pages.
- `CodexLocalThreadRecord`: hand-owned metadata value for id, rollout path,
  archived state, timestamps, cwd, title, preview policy, Git facts, model
  facts, CLI version, token totals, source fields, and compatibility evidence.
- `CodexLocalStorageCompatibility`: describes the detected local storage shape,
  required-column status, extra columns, Codex CLI version when available, and
  whether direct reads are allowed.
- Optional later `CodexLocalRolloutReader`: lazily scans selected JSONL files
  for envelope counts, turn ids, item ids, and selected non-sensitive summaries.

Likely caller-facing owner:

- A future `CodexAppServer.Library` or adjacent history/library surface should
  be the caller entry point if this becomes consumer-facing.
- Keep direct storage under an explicit opt-in configuration or feature policy
  because it reads private local files outside the app-server route.

## Privacy And Safety Rules

- Open SQLite databases read-only.
- Never mutate Codex state, archive flags, JSONL files, logs, goals, or app
  support files.
- Redact private prompt and preview text by default.
- Require an explicit opt-in before returning first user messages, previews,
  raw transcript text, tool output, command output, or file-change payloads.
- Prefer metadata summaries over transcript ingestion.
- Read JSONL lazily and only for selected rows.
- Label all direct-read data as local persisted storage observations.
- Preserve app-server semantics as authoritative when app-server and direct
  storage disagree.

## Suggested Rollout

1. Keep AgentSB `threads inspect-index` as the Python prototype and eval source.
2. Add fixture SQLite and JSONL samples to SwiftASB tests that avoid private
   local user data.
3. Implement a Swift internal reader over fixture databases.
4. Add compatibility diagnostics for missing columns, unknown storage version,
   unreadable databases, and mid-write JSONL tolerance.
5. Decide the caller-facing entry point: `CodexAppServer.Library` enrichment,
   a separate local-storage namespace, or a maintainer-only SPI surface.
6. Expose only metadata first.
7. Add lazy JSONL summary reads after metadata paging is stable.
8. Add richer history ingest only if the performance win justifies the storage
   compatibility burden.

## Open Decisions

- Whether this becomes public API, package-internal support, or an SPI-style
  expert surface.
- Which exact Codex CLI and GUI storage versions SwiftASB should support.
- Whether direct-read access belongs under `CodexAppServer.Library` or a
  separate local-storage namespace.
- How callers opt into private-text reads.
- How direct local records reconcile with SwiftASB's Core Data-backed
  `ThreadHistoryStore`.
- Whether archived thread JSONL should ever be read automatically, or only
  after an explicit caller request.

## Non-Goals

- Do not replace app-server live event streams.
- Do not mutate local Codex state directly.
- Do not expose raw SQLite rows as public API.
- Do not expose raw JSONL envelopes as public API.
- Do not support unbounded transcript ingestion by default.
