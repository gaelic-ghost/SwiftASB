# AgentSB Codex Thread Ingest Research

## Summary

SwiftASB should treat direct Codex thread ingest as a future read-only local
storage capability with explicit version support. AgentSB can prototype and
report on the storage shape, but the destination is SwiftASB itself.

The promising fast path is:

1. Read `~/.codex/state_5.sqlite` for thread inventory and metadata.
2. Use the `threads.rollout_path` field to lazily read JSONL only when a report
   needs deeper turn evidence.
3. Keep app-server and SwiftASB public surfaces as the source of truth for
   user-facing behavior, archive actions, live thread state, and compatibility
   guarantees.

This could reduce pressure on the CLI/app-server JSONL pipe because SwiftASB
could inventory many threads from SQLite without paging every stored thread
through `thread/read`.

## Observed Local Storage

Local Codex storage currently includes:

- `~/.codex/sessions/YYYY/MM/DD/` for active/current session JSONL files.
- `~/.codex/archived_sessions/` for archived session JSONL files.
- `~/.codex/state_5.sqlite`, with a `threads` table containing thread inventory
  and metadata.
- `~/.codex/logs_2.sqlite`, `~/.codex/goals_1.sqlite`, and other local Codex
  stores that may be useful for future specialized reports.
- ChatGPT app support files under
  `~/Library/Application Support/com.openai.chat/`, including task item files
  with active and archived naming.

The sampled active and archived JSONL files used the same event-envelope
families: `session_meta`, `turn_context`, `event_msg`, and `response_item`.
Archived status appeared in index metadata and file placement rather than in a
special archived-only JSONL schema.

## SQLite Thread Metadata

The `threads` table in `~/.codex/state_5.sqlite` includes:

- thread id
- `rollout_path`
- created and updated timestamps, including millisecond columns
- source and thread source
- model provider, model, and reasoning effort
- cwd
- title, preview, and first user message
- sandbox and approval mode
- token count and user-event flag
- archived flag and archived timestamp
- git SHA, branch, and origin URL
- CLI version
- agent nickname, role, path, and memory mode

Verified counts on 2026-06-04:

| Query | Count |
| --- | ---: |
| Total `threads` rows | 851 |
| Archived rows | 513 |
| Unarchived rows | 338 |
| SwiftASB cwd archived rows | 48 |
| SwiftASB cwd unarchived rows | 2 |

## Difference From SwiftASB/App-Server Surfaces

SwiftASB and the app-server expose a deliberate public/session-oriented view:

- stored thread list and read surfaces
- archive and unarchive actions
- paged turns and items
- loaded thread ids
- live events
- goals
- SwiftASB-owned hydrated history cache

The local SQLite index is richer for inventory work. It includes
exact rollout paths, archive timestamps, cwd grouping, first-message and preview
fields, Git metadata, CLI version, source/subagent metadata, model fields, and
token totals. Those fields are useful for AgentSB reports and could support a
future SwiftASB direct-read feature, but they should not be treated as stable
public API until SwiftASB defines a versioned compatibility window.

## Recommended SwiftASB Ingest Shape

Use AgentSB's prototype `threads inspect-index` command to validate a future
SwiftASB direct-read design that:

1. Opens `~/.codex/state_5.sqlite` read-only.
2. Queries `threads` by cwd, archived state, updated timestamp, and source.
3. Emits a thread inventory with rollout paths, titles, previews, archive state,
   Git facts, model facts, and token totals.
4. Reads JSONL lazily only for selected rows when a report needs turn-level
   evidence.
5. Labels every direct-ingest field as private/local Codex storage until
   SwiftASB defines the caller-facing model.

The SwiftASB feature should be opt-in and read-only by default. AgentSB should
remain the maintainer-side experiment/report harness.

## Risks

- `state_5.sqlite` and JSONL envelopes are private Codex implementation details
  and may drift without a compatibility promise.
- Active JSONL files may be mid-write.
- Direct reads can disagree with app-server semantics around loaded state,
  archive actions, or future migrations.
- Local stores may include sensitive prompts, tool outputs, paths, and
  credentials accidentally captured in logs.
- Archive state currently spans SQLite metadata plus file placement, so a reader
  must not infer too much from JSONL shape alone.

## Evidence

Read-only verification commands:

```bash
sqlite3 /Users/galew/.codex/state_5.sqlite '.schema threads'
sqlite3 /Users/galew/.codex/state_5.sqlite "select count(*) as total, sum(case when archived then 1 else 0 end) as archived, sum(case when not archived then 1 else 0 end) as unarchived from threads;"
sqlite3 /Users/galew/.codex/state_5.sqlite "select archived, count(*) from threads where cwd = '/Users/galew/Workspace/gaelic-ghost/SwiftASB' group by archived order by archived;"
```

Subagent read-only research also inspected:

- `Sources/SwiftASB/Public/CodexAppServer+ThreadLifecycle.swift`
- `Sources/SwiftASB/Public/CodexAppServer+LoadedThreads.swift`
- `Sources/SwiftASB/History/ThreadHistoryStore.swift`
- `Sources/SwiftASB/SwiftASB.docc/ThreadManagement.md`
- `Sources/SwiftASB/SwiftASB.docc/ReadingDiagnosticsAndHistory.md`
