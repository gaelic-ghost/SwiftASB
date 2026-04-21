# Thread History Storage Plan

## Purpose

This note records the intended `SwiftASB` design for full thread-history
ownership once the package starts wrapping `thread/read`, `thread/fork`,
`thread/resume`, and related history-facing app-server APIs.

The goal is to give Swift consumers an honest conversation-history surface
without forcing every client to reconstruct turns manually from raw event
streams, while also avoiding a second long-term archive that fights the Codex
CLI's own transcript store.

This note now records made decisions, not just possible directions.

## Upstream Constraints

The current Codex app-server behavior matters here more than our preferences,
so this design starts from the documented upstream rules:

- `thread/read` can return a stored thread without resuming it, and
  `includeTurns: true` requests the full stored turn history in
  `thread.turns`.
- `thread/turns/list` can page a stored thread's turn history without loading
  the whole thread at once.
- `thread/resume` reopens an existing thread by id for future `turn/start`
  calls.
- `thread/fork` creates a new thread id with copied history from an existing
  thread.
- `thread/start`, `thread/resume`, and `thread/fork` support
  `persistExtendedHistory: true` so later `thread/read`, `thread/resume`, and
  `thread/fork` can preserve a richer subset of `ThreadItem`s.
- `turn/started` and `turn/completed` currently carry empty `items` arrays even
  when item events were streamed. Upstream explicitly says clients should rely
  on `item/*` notifications for the canonical item list until this is fixed.
- `thread/archive` and `thread/unarchive` move the persisted rollout between
  active and archived storage. The app-server also emits `thread/archived` and
  `thread/unarchived` notifications.
- `thread/compact/start` emits a `contextCompaction` item and progress through
  standard `turn/*` and `item/*` notifications, but the docs do not say that
  compaction deletes or truncates persisted transcript history.

Authoritative upstream reference:

- [codex-rs/app-server/README.md](https://github.com/openai/codex/blob/main/codex-rs/app-server/README.md)

## Chosen Direction

Use a split model:

- a live in-memory history builder for active threads
- a local persisted cache only for non-archived threads
- upstream Codex transcript storage as the source of truth for long-term
  thread retention

In plain language:

- `SwiftASB` should build and expose real thread history for consumers
- `SwiftASB` should not pretend `turn/completed` is enough to reconstruct that
  history
- `SwiftASB` should not keep its own permanent archive of threads that Codex
  has already archived

## Decisions Made

The following decisions are now considered settled unless a later maintainer
note explicitly supersedes them.

### Delivery shape before v1

- this work should land in two implementation passes before `v1`
- the first pass should prove honest transcript ownership plus Core Data
  persistence
- the second pass should add upstream history hydration, merge and
  reconciliation, archive-aware retention, and public history-reading helpers
- both passes are part of the intended pre-`v1` history-store direction, not a
  retreat from Core Data persistence

### Persistence detail level

- local persistence should stay full-detail
- `SwiftASB` should expose richer local history than upstream app-server reads
  when the local store has captured more detail
- once a thread's local history is known to be complete or better than the
  current upstream stored history, consumer history fetches and searches should
  prefer the local database

### Storage engine

- use Core Data as the local persistent store
- use Core Data's SQLite-backed store as the durable local history database
- use Core Data persistent history tracking and query-generation capabilities
  where they help with change processing, snapshots, and stable reads

Relevant Apple references:

- [Core Data](https://developer.apple.com/documentation/coredata)
- [NSPersistentHistoryChangeRequest](https://developer.apple.com/documentation/coredata/nspersistenthistorychangerequest)
- [Consuming relevant store changes](https://developer.apple.com/documentation/coredata/consuming-relevant-store-changes)

Persistent history tracking itself is intentionally deferred from the first
implementation pass. The package should start with ordinary Core Data
persistence and only add persistent-history-token machinery later if the real
reconciliation model proves that it is needed.

### Persistence defaults

- persistence is automatically on for non-ephemeral threads
- threads started as `.ephemeral` are never persisted to disk and remain
  in-memory only for the lifetime of the consumer's usage
- `persistExtendedHistory` should default to on for future `thread/start`,
  `thread/resume`, and `thread/fork` wrappers
- that default should remain overrideable by the consumer

### Startup sync policy

- on package startup, `SwiftASB` should query `thread/loaded/list` and eagerly
  hydrate the most recent loaded threads
- `SwiftASB` should also query non-archived unloaded threads from `thread/list`
  and eagerly hydrate the most recent unloaded threads
- the eager hydration count should be package-configurable and default to `4`
  for loaded threads and `4` for unloaded threads
- remaining non-archived threads should be reconciled in the background
- background sync should yield aggressively to live turn traffic

### Completeness modeling

- the local database must explicitly model completeness state
- the first required states are:
  - `partial`
  - `serverParity`
  - `richerThanServer`
- history fetches should prefer the local database once a thread reaches
  `serverParity` or `richerThanServer`
- the first implementation pass may store completeness conservatively at the
  thread level
- once paged hydration and partial reconciliation land, the model should be
  allowed to grow toward per-turn or per-range completeness instead of being
  locked permanently to one thread-wide flag

### Archive retention policy

- archived threads should remain locally retained for a configurable grace
  window instead of immediate deletion
- the default retention window is `30` days
- that retention window is package-wide configuration, not a per-thread
  override
- ephemeral threads are excluded because they are never persisted
- the countdown is based on the latest observed archive event for the thread
- unarchive should cancel the current countdown and reset the thread to normal
  non-archived retention behavior

### Fork lineage

- a fork should create a second thread entity immediately
- the thread model should record fork origin lineage
- the preferred first shape is a thread-level origin property rather than a
  separate join entity unless implementation pressure proves that insufficient
- fork lineage should be able to point to the source thread and the last common
  ancestor turn

### Hot-cache policy

- use per-turn persisted segments as the cold-storage unit
- use an in-memory cache policy with both:
  - a minimum number of turns to keep resident
  - a maximum number of item records to keep resident
- after a completed turn, if the in-memory item count is above the configured
  maximum and the thread is above the minimum in-memory turn count, evict the
  oldest resident completed turns until the item count is back under the limit
  or the minimum resident-turn floor is reached

### Read preference policy

- once a thread has been started or resumed or forked, and the necessary merge
  with Core Data has completed, history reads should prefer Core Data over
  repeated app-server history reads whenever the local completeness state says
  that is safe
- older turns evicted from memory should be faulted back in from Core Data
  rather than re-reading them from app-server under normal operation

### Paging shape

- the canonical paging unit is the turn, not the item and not arbitrary text
  fragments
- the internal paging model should be cursor-based
- public APIs may layer eager convenience helpers on top of that internal
  cursor model
- whole-turn paging should ship before any within-turn paging shape is
  considered

Preferred internal page shape:

- `threadID`
- `pageDirection`
- `turns: [TurnHistory]`
- `nextOlderCursor`
- `nextNewerCursor`
- `source`
- `completenessAtRead`

Preferred public shape:

- a simple recent-history convenience API
- directional paging APIs for older and newer turn windows
- later search-hit hydration that can resolve a search result into a
  surrounding turn window

### Search strategy

- Core Data remains the source of truth for transcript storage, relationships,
  completeness, archive retention, and structured fetches
- SearchKit should be integrated later as a derived full-text index over the
  Core Data-backed transcript store
- SearchKit should not block the first history-store implementation
- once integrated, SearchKit should power fast transcript search, ranked
  results, phrase and prefix matching, and snippet or summary generation while
  Core Data continues to own canonical transcript persistence

Relevant Apple reference:

- [Search Kit](https://developer.apple.com/documentation/coreservices/search_kit)

## Core Design Rule

Treat `SwiftASB` history persistence as a working cache, not as the canonical
archive.

That means:

- active and non-archived threads may be cached locally by `SwiftASB`
- archived threads may remain cached locally only until their archive-retention
  deadline expires
- unarchived threads become eligible for local caching again and should have
  any archive-retention deletion timer cleared
- upstream `thread/read` and `thread/turns/list` remain the recovery and
  reconciliation path for older history

## Why A History Store Is Necessary

The current public model only keeps:

- `ThreadInfo`
- `TurnInfo`
- typed event streams
- current-state observable companions such as `Dashboard` and `Minimap`

That is not enough for full transcript ownership.

Because `turn/completed` still carries an empty `items` array upstream,
`SwiftASB` must assemble real turns incrementally from:

- `turn/started`
- `item/started`
- item-specific deltas
- `item/completed`
- `turn/completed`

If we skip that assembly layer, consumers who want real thread history will be
forced back down to raw event replay and custom bookkeeping.

## Proposed Internal Model

This section records the intended first Core Data model shape.

### Thread history

Introduce an internal thread-history owner that keeps:

- thread metadata
- archive state
- loaded turn index
- active turn builders
- sealed completed turns
- cold-storage metadata for older persisted segments

Suggested shape:

- `ThreadHistoryStore` actor owned by `CodexAppServer`
- one `ThreadHistory` record per known thread id
- one `TurnHistoryBuilder` per active turn
- one sealed `TurnHistory` value per completed turn

### Core Data entities

The first persistent model should include:

- `Thread`
- `ThreadDefaults`
- `ThreadState`
- `Turn`
- one generic `Item` entity for the first implementation pass

Entity intent:

- `Thread`
  - stable thread identity
  - created and updated timestamps
  - archive state and lineage metadata
  - relationship to turns
  - relationship to defaults and state
- `ThreadDefaults`
  - the thread's persisted default execution knobs
  - initially created when the thread is created
  - updated when the consumer changes thread-level overrides
- `ThreadState`
  - mutable local bookkeeping such as completeness state, last sync markers,
    archive-retention deadlines, and startup-reconciliation metadata
- `Turn`
  - one persisted turn record per turn
  - relationship back to thread
  - turn ordering and terminal status
  - turn-level summary fields and local cache metadata
- `Item`
  - one persisted item record per canonical thread item
  - each item belongs to exactly one turn
  - the first schema should prefer one stable item table over early subtype
    splitting
  - if later query or storage pressure proves that some item kinds need their
    own entities, that should be a deliberate later migration instead of a
    first-pass assumption

### Core Data change tracking

The intended write model is:

- create a `Thread` plus `ThreadDefaults` when the thread starts or is first
  loaded into local history ownership
- update `ThreadDefaults` when thread-level defaults or overrides change
- create a `Turn` when a turn starts
- create the appropriate item entity when an item starts
- update that item entity for each delta
- finalize the item on completion
- finalize the turn on `turn/completed`

This design intentionally leans on Core Data's native change tracking and
ordinary persistence model instead of inventing a second local delta log.
Persistent history tracking is a possible later enhancement, not part of the
initial requirement.

### Turn history

A completed turn record should be richer than current `TurnInfo`.

At minimum it should retain:

- turn identity and terminal status
- the ordered canonical item list
- stable per-item final state
- reconstructed text or reasoning content from streamed deltas when needed
- turn-level diff snapshot if present
- token usage if available through thread notifications

### Item history

The canonical item list should come from item lifecycle events, not from
`turn/completed`.

For each item, the history store should be able to capture:

- item identity
- item kind
- final terminal state
- important accumulated content or output needed for future transcript reads
- the relationship between streamed deltas and the final item snapshot

## Hydration Paths

Support two complementary ways to populate history.

### Incremental live assembly

Use this for threads we are actively subscribed to.

Behavior:

- create a turn builder when `turn/started` arrives
- create or update items on `item/started`
- append streamed content on delta notifications
- seal item state on `item/completed`
- freeze the turn record on `turn/completed`

This is the only honest way to build full turn history while a turn is running
under the current upstream contract.

### Whole-thread or paged hydration

Use this for existing threads, resumed threads, forked threads, or cold-start
rehydration after app restart.

Primary upstream sources:

- `thread/read(includeTurns: true)` for an eager full-thread load
- `thread/turns/list` for page-based incremental history loading

Preferred policy:

- use `thread/read(includeTurns: true)` for small or medium threads
- use `thread/turns/list` when the thread is large or when we only need a
  history window

Paging rule:

- hydrate and evict in whole-turn units
- page cursors should describe turn windows, not item offsets
- if later giant items need their own progressive loading model, that should be
  a second API rather than widening the first turn-history paging contract

Startup hydration policy:

- eagerly hydrate the latest configured count of loaded threads first
- eagerly hydrate the latest configured count of non-archived unloaded threads
  next
- if `thread/list` exposes recency ordering fields such as `updatedAt`, prefer
  those fields when choosing eager candidates
- schedule all remaining non-archived threads for background hydration
- let live traffic preempt that background work aggressively

## Merge And Reconciliation Rules

The history store must support merging live-built state with later upstream
reads.

Needed cases:

- a live thread receives new turns, then a consumer later asks for older turns
- a thread is resumed and the server returns persisted history that overlaps
  with what `SwiftASB` already observed live
- a thread is forked and the new thread inherits older turns already known from
  the source thread

The merge rule should prefer:

- canonical ids and ordering from upstream stored history
- richer locally assembled item detail when upstream persisted history is
  lossy
- replacing provisional live turn state with a more authoritative later stored
  snapshot only when the replacement is not less informative

## Archive And Unarchive Policy

This is the key ownership rule for disk persistence.

### When a thread is archived

On `thread/archived`, `SwiftASB` should:

- mark the thread history record as archived
- stop treating the thread as an active non-archived cache target
- record the latest observed archive timestamp
- compute and persist a scheduled deletion timestamp based on the package-wide
  retention window
- keep any live in-memory object only as a hot session object if a consumer is
  actively holding it

Rationale:

- Codex CLI already persists archived transcripts
- local persistence is still a cache, but archived-thread retention is now an
  intentional product feature
- keeping a grace-period local archive avoids a bad user experience if another
  client archives a thread while a consumer still has a long history view open

### When a thread is unarchived

On `thread/unarchived`, `SwiftASB` should:

- mark the thread eligible for local persistence again
- clear any scheduled archive deletion timestamp
- increment unarchive bookkeeping in local state
- rehydrate from upstream on demand through `thread/read` or `thread/turns/list`
- resume local persistence only after fresh history has been loaded or new live
  activity begins

### Reconciliation support

Notifications should be the primary path, but the history store should also be
able to reconcile archive state through `thread/list`:

- normal listing for active threads
- `archived: true` listing for archived threads

That covers missed notifications or archive state changes caused by another
client.

The local thread-state bookkeeping should retain both:

- notification-derived archive and unarchive observations
- reconciliation-derived archive and unarchive observations inferred from
  listing differences

At minimum, track:

- whether the thread is currently archived
- whether the thread is currently loaded
- archive event count
- unarchive event count
- latest observed archive timestamp
- latest observed unarchive timestamp
- scheduled local deletion timestamp

## Compaction Policy

Do not treat compaction as transcript deletion.

Current documented behavior only guarantees:

- compaction can be started manually
- it emits a `contextCompaction` item through normal lifecycle notifications
- the thread is effectively busy while compaction is running

The docs do not say that compaction removes old turns from `thread/read`, nor
that it shrinks stored transcript history.

Therefore:

- compaction should update live current-state summaries such as
  `Dashboard.isCompactingThreadContext`
- compaction may trigger a later reconciliation read if needed
- compaction should not cause `SwiftASB` to delete older persisted history on
  its own

If upstream later documents that compaction rewrites persisted thread history,
this policy can be revisited explicitly.

## Memory Pressure And Cold Storage

Large threads still need a bounded-memory strategy.

Preferred approach:

- keep a hot in-memory window for recent turns and active builders
- spill older sealed turns into a local disk cache while the thread remains
  non-archived
- keep enough index metadata in memory to fault older turns back in

Concrete eviction policy:

- each thread cache policy should define:
  - `minimumResidentTurns`
  - `maximumResidentItems`
- eviction should happen only after a completed turn boundary
- once above `maximumResidentItems`, evict the oldest resident completed turns
  until:
  - resident item count is back under the limit, or
  - resident turn count has reached `minimumResidentTurns`

The disk cache should be organized as per-turn disposable segments, not as a
second source of truth.

That means:

- disk segments may be safely deleted when archive arrives
- disk segments may be discarded and rebuilt later from upstream reads
- consumers should never depend on the local disk copy existing forever

## Public API Implication

This design points toward a future public history surface that is separate from
current-state companions.

Current-state companions answer:

- what is happening right now

History surfaces should answer:

- what has already happened in this thread

That means `Dashboard` and `Minimap` should remain summary companions, while a
future history API should expose:

- full thread transcript reads
- paged turn history
- completed turn inspection
- optional prewarmed local history snapshots for UI consumers

Once the local database has reached `serverParity` or `richerThanServer` for a
thread, the public history surface should prefer local reads and searches by
default.

Recommended first public history helpers:

- `loadRecentTurns(limit:)`
- `loadTurns(before:limit:)`
- `loadTurns(after:limit:)`

Recommended later public search helpers:

- `searchHistory(query:limit:)`
- a lightweight hit shape that can later hydrate into the surrounding turn
  window

## Recommended Implementation Order

### Phase 1: Internal history builder

- add internal `ThreadHistoryStore`
- assemble completed turns from live item events
- prove that sealed turn history survives beyond `Minimap` current-state
  summaries
- introduce the first Core Data model with `Thread`, `ThreadDefaults`,
  `ThreadState`, `Turn`, and one generic `Item` entity
- persist and read back locally assembled thread history without relying on
  Core Data persistent history tracking

Current status:

- shipped internally
- the current store persists live-built thread, turn, and item history
- `thread/closed` and thread-name clearing now persist correctly too

### Phase 2: History hydration

- wrap `thread/read`
- wrap `thread/turns/list`
- add merge and deduplication between live-built and server-read turns
- add startup eager hydration for latest loaded and latest unloaded threads
- add background hydration for the rest with aggressive yielding
- revisit whether Core Data persistent history tracking is actually needed once
  the first real reconciliation flow exists

Current status:

- started and partially shipped
- `thread/list` is now wrapped for typed stored-thread paging
- `thread/read`, `thread/resume`, and `thread/turns/list` are now wrapped
- both paths now hydrate the internal Core Data store
- `thread/list` now reconciles explicit archived and unarchived list results back
  into the local thread records so metadata and archive state can drift-correct
  without forcing a full thread read
- `thread/resume` now restores thread defaults, clears stale archived state for
  the reopened thread, and hydrates returned persisted turns back into the same
  local store without resetting completeness to a fresh thread state
- `thread/turns/list` can now seed local history even when the thread has not
  been materialized locally yet
- overlapping hydration now preserves richer locally assembled item detail when
  stored history is thinner, while still accepting canonical upstream turn
  ordering and terminal status
- thread completeness now promotes to `serverParity` after clean stored-history
  hydration and to `richerThanServer` when local assembly preserved detail that
  the server read did not include
- remaining work in this phase is no longer basic merge and dedup wiring, but
  the next reconciliation tier around `thread/fork` and deeper archive-state
  drift handling

### Phase 3: Archive-aware cache eviction

- react to `thread/archived` and `thread/unarchived`
- retain archived threads locally until their scheduled deletion deadline
- delete local persisted cache only when that deadline is reached
- add list-based reconciliation for archive state drift

Current status:

- not started as a retention policy
- the first list-driven archive drift correction now exists through
  `thread/list` reconciliation, but retention windows and eviction are still
  open

### Phase 4: Public consumer surface

- expose a deliberate history-reading API
- expose eager convenience helpers over the cursor-based paging model
- add search integration after the transcript model is stable enough to index

## Remaining Open Questions

- How much streamed command output or reasoning detail should be retained in
  sealed local turns when upstream persisted history may be thinner?
- What is the exact public cursor type and lifetime contract we want to
  promise to consumers?

## Current Recommendation

Proceed with a real thread-history store.

But keep its persistence policy narrow:

- build full history live from item events
- ship the first persistence pass with a single generic `Item` entity
- hydrate older history from upstream reads
- treat local persistence as the default read path once local completeness is
  good enough
- use archived-thread retention with a package-wide configurable grace period
  instead of immediate archive deletion
- page history in whole-turn windows
- add Core Data persistent history tracking only if the real multi-context or
  reconciliation behavior proves that it is needed
- adopt SearchKit later as the derived search layer on top of Core Data
