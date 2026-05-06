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
- use an in-memory cache policy with:
  - a maximum number of resident turns
  - a minimum number of resident turns
  - a weighted resident item budget rather than a raw item-count limit
- resident item pressure should be reduced in two stages:
  - first slim low-value item payloads out of older, non-visible, non-protected
    completed turns while keeping the turn shell resident
  - then evict older, non-visible, non-protected completed turns only if the
    weighted resident item budget is still exceeded
- "slimming" is a deliberate shell-retention step:
  - keep turn identity, order, status, timestamps, token usage, and other
    turn-header metadata resident
  - keep high-value items such as user messages, agent messages, plans, and
    reasoning longer than lower-value tool and operational items
  - fetch the full item payload back from local history when a slimmed turn
    becomes important again
- protected turns are not candidates for slimming or eviction; protection
  explicitly includes:
  - the current in-progress turn
  - the most recently completed turn
  - an explicit recent-terminal-turn protection band used as the package's
    deterministic answer to "likely to receive late reconciliation enrichment"
  - the current scroll anchor turn
  - visible turns and their protected buffer
  - turns with unresolved interactive requests
- archived threads are treated as dormant until explicitly unarchived; no
  separate aggressive hot-cache behavior is needed while the thread remains
  archived

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
  - `maximumResidentItemCost`
- budget enforcement should happen on initial recent-window construction and
  after later merges, loads, or turn completions
- once above `maximumResidentItemCost`, the observable should:
  - slim low-value item payloads from the oldest eligible completed turns first
  - then evict the oldest eligible completed turns only if the weighted budget
    is still exceeded
- eviction should stop when:
  - resident item cost is back under the limit, or
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

Recommended first UI-facing shape:

- keep `CodexTurnHandle.Minimap` as the live current-state companion for one
  active turn
- add a second thread-scoped `@Observable` recent-turns companion that owns the
  bounded hot in-memory window for:
  - active turn builders
  - recently sealed completed turns
  - recent-turn paging state and faulted-in older windows
- let that recent-turns companion hydrate from:
  - live item-stream assembly
  - local Core Data history once a thread has local completeness worth trusting
  - upstream `thread/read` or `thread/turns/list` when local paging needs a
    turn window that is not resident yet

Recommended completed-turn handoff shape:

- add `CodexTurnHandle.complete(...)`
- `complete(...)` should:
  - return a value-typed sealed final turn representation
  - unregister the handle's live stream bookkeeping from the owning app-server
  - detach the handle from future observation updates
- this should be an explicit lifecycle method, not `deinit`-driven behavior,
  because turn-handle storage and observation lifetimes should stay deterministic
- the returned sealed value should be discardable so consumers that only want
  cleanup can ignore the result

The recent-turns companion should be the package's intentional answer to
"recent completed turns for UI binding", rather than leaving that behavior as an
accidental side effect of per-handle current-state mirrors.

Once the local database has reached `serverParity` or `richerThanServer` for a
thread, the public history surface should prefer local reads and searches by
default.

Recommended next public history helpers:

- a deliberate non-UI local-history surface that can read recent turns without
  requiring a live `RecentTurns` observable
- directional whole-turn paging helpers that mirror the current observable
  paging model but return plain values instead of resident observable state
- a public cursor contract only after we decide how much cursor lifetime and
  stability we really want to promise outside the current thread-scoped cache

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
- `thread/read`, `thread/resume`, `thread/fork`, and `thread/turns/list` are
  now wrapped
- both paths now hydrate the internal Core Data store
- `thread/list` now reconciles explicit archived and unarchived list results back
  into the local thread records so metadata and archive state can drift-correct
  without forcing a full thread read
- `thread/resume` now restores thread defaults, clears stale archived state for
  the reopened thread, and hydrates returned persisted turns back into the same
  local store without resetting completeness to a fresh thread state
- `thread/fork` now persists explicit fork lineage through `forkedFromThreadID`
  plus the last shared `forkedFromTurnID`
- persisted turn and item identity is now thread-scoped so a source thread and
  its fork can both own copied history with the same upstream raw ids
- `thread/turns/list` can now seed local history even when the thread has not
  been materialized locally yet
- overlapping hydration now preserves richer locally assembled item detail when
  stored history is thinner, while still accepting canonical upstream turn
  ordering and terminal status
- thread completeness now promotes to `serverParity` after clean stored-history
  hydration and to `richerThanServer` when local assembly preserved detail that
  the server read did not include
- remaining work in this phase is no longer basic merge and dedup wiring, but
  deeper archive-state drift handling plus the future public history-reading
  surface over the now-widened local model

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

Recommended first implementation inside this phase:

- add a thread-scoped recent-turns observable companion
- back that companion with the bounded hot-cache policy already chosen above
- let recent-turn loading and scroll-driven expansion page by whole-turn windows
- let older windows fault back in from Core Data first and app-server second
- give the companion explicit directional expansion APIs rather than implicit
  unbounded growth:
  - `loadOlderTurns(limit:)`
  - `loadNewerTurns(limit:)`
- keep one resident ordered window in memory and merge newly loaded turns into
  that window by turn id
- preserve sort order by turn recency while still using canonical upstream page
  direction and cursor semantics when app-server fallback is needed
- add `CodexTurnHandle.complete(...)` as the explicit boundary from live handle to
  sealed completed-turn value
- keep `Dashboard` and `Minimap` as current-state summaries, not transcript
  owners

Current status:

- started
- `CodexThread.makeRecentTurns(limit:)` now exists as the first thread-scoped
  recent-turn observable
- the first load path prefers the local history store and falls back to
  `thread/turns/list` when local recent turns are not resident yet
- `CodexTurnHandle.complete()` now exists as the explicit handoff from a completed
  live handle to a caller-owned sealed turn value
- explicit older/newer scroll-window expansion over whole-turn pages now
  exists, still preferring local Core Data windows before falling back to
  upstream cursors
- initial recent-turn window construction now also seeds upstream paging
  cursors even when the visible recent window came from local history first,
  so remote fallback can continue cleanly after multiple local-only expansions
- `RecentTurns` now owns a first-pass cache policy:
  - named presets for chat UIs, full transcript or inspector UIs, and compact
    history rails
  - a bounded resident turn cap
  - a minimum resident-turn floor
  - a resident item count and weighted resident item cost
  - low-value payload slimming for older non-visible completed turns before
    whole-turn eviction
  - oldest-completed-turn eviction when the weighted item budget is still
    exceeded after slimming
  - automatic rehydration of slimmed turns when they become visible or
    otherwise protected again
  - scroll-position-driven focus
  - visible-turn, scroll-anchor, unresolved-interactive, current-in-progress,
    and recent-completed protection for eviction
  - load-state flags and surfaced load errors
  - automatic earlier edge prefetch when the consumer binds scroll position,
    visibility information, and scroll activity into the observable
- richer policy tuning and deeper weighting heuristics are still open

Recommended next steps:

- keep `RecentFiles` as a dedicated thread-scoped observable companion:
  - one resident file-entry window per thread
  - one entry per file-change item in the first pass, not path-level
    coalescing
  - seed from the same local history store snapshots that already retain
    file-change items and their accumulated streamed text
  - enrich live resident entries from file-change output deltas while the item
    is active
  - keep lightweight file-entry shells resident longer than heavier payload
    text, and rehydrate payload when an entry becomes visible or selected again
  - keep a later mixed `RecentActivity` timeline separate from the file-centric
    model instead of making `RecentFiles` a subtype of a generalized activity
    feed
- current status for that file companion:
  - selection-aware first pass shipped
  - `CodexThread.makeRecentFiles(limit:)` now exists
  - initial file-entry hydration now comes from the same local history store
    snapshots that already retain file-change items and accumulated streamed
    text
  - live file entries now enrich themselves from
    `item/fileChange/outputDelta` notifications without promoting those raw
    notifications into new public event-enum cases
  - older file loading now checks the same persisted turn first for older file
    items before moving on to older turns
  - `RecentFiles` now owns a file-specific cache policy with selection and
    visibility protection, lightweight shell retention, payload-cost trimming,
    and on-demand payload rehydration from the persisted turn snapshot when a
    protected file becomes visible or selected again
  - file shells now keep stable identity, path, status, ordering, and concise
    status summary even after the heavier payload text has been slimmed away
  - file payload weighting now uses diff structure and line volume rather than
    raw character count alone, and sealed completed payloads now prefer edit
    summaries such as additions, deletions, and hunk counts over a bare
    terminal `completed` shell label
- keep tuning `RecentTurns` policy now that the first end-to-end resident cache
  behavior is real:
  - calibrate the weighted residency cost rules against real transcript shapes
  - decide whether some item kinds should be stickier than the current
    low-value-item slimming rules
  - decide whether very thin turn shells should remain resident longer than
    heavier turns under the same weighted budget
- keep `RecentCommands` as a dedicated thread-scoped observable companion:
  - one resident command-entry window per thread
  - one entry per `commandExecution` item in the first pass
  - seed from the same local history store snapshots that already retain
    command items and their accumulated streamed output
  - enrich live resident entries from command-output deltas while the item is
    active
  - keep lightweight command shells resident longer than heavier output text,
    and rehydrate output when an entry becomes visible or selected again
  - keep a later mixed `RecentActivity` timeline separate from the
    command-centric model instead of making `RecentCommands` a subtype of a
    generalized activity feed
- current status for that command companion:
  - selection-aware first pass shipped
  - `CodexThread.makeRecentCommands(limit:)` now exists
  - initial command-entry hydration now comes from the same local history
    store snapshots that already retain command items and accumulated streamed
    output
  - live command entries now enrich themselves from
    `item/commandExecution/outputDelta` notifications without promoting those
    raw notifications into new public event-enum cases
  - older command loading now checks the same persisted turn first for older
    command items before moving on to older turns
  - `RecentCommands` now owns a command-specific cache policy with selection
    and visibility protection, lightweight shell retention, output-cost
    trimming, and on-demand output rehydration from the persisted turn
    snapshot when a protected command becomes visible or selected again
  - command shells now keep stable identity, command string, status, ordering,
    and concise status summary even after the heavier output text has been
    slimmed away
  - command output weighting now uses output size and line structure rather
    than raw character count alone, and sealed completed output now prefers
    concise output summaries over a bare terminal `completed` shell label
- add the first deliberate public history-reading helpers outside the
  observable surface
- flesh out archive-aware retention and eviction after the non-archived hot
  cache feels stable

Current status for that non-UI history surface:

- first pass shipped
- `CodexThread.readTurnHistory(turnID:)` now reads one sealed local turn by id
- `CodexThread.HistoryWindow` now gives that surface a lightweight page type
  with sealed `ClosedTurn` values plus `hasOlderTurns` and `hasNewerTurns`
- `CodexThread.readRecentTurnHistoryWindow(limit:)` now reads a recent local
  window of sealed turns without requiring `RecentTurns`
- `CodexThread.readOlderTurnHistoryWindow(olderThan:limit:)` and
  `readNewerTurnHistoryWindow(newerThan:limit:)` now page local sealed turns
  around a known boundary turn id without introducing a broader public cursor
  type yet
- the older and newer array-returning helpers now remain convenience wrappers
  over those windows instead of being separate behavior paths
- the first non-UI surface intentionally reuses `CodexTurnHandle.ClosedTurn`
  instead of introducing a second public transcript value type
- directional non-UI paging currently requires the boundary turn to already be
  present in the local history store for that thread
- the next intended thread-scoped additions are `windowAroundTurn(...)` and
  `windowAroundItem(...)` before any broader public cursor contract or search
  surface is introduced
- broader cursor semantics, transcript search, and richer non-UI history query
  helpers still remain open follow-on work

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

## App-Wide Library Hydration Plan

This section records the first `CodexAppServer.Library` direction.

The library is the app-wide observable companion for GUI and CLI consumers that
need thread lists before they choose a thread. It should stay value-snapshot
based and should not expose Core Data managed objects, SwiftData models, raw
`FetchRequest`, or SwiftData `Query` values.

### First public shape

- `CodexAppServer.makeLibrary(configuration:)`
- `CodexAppServer.Library`
- `CodexAppServer.Library.SortedBy`
- `CodexAppServer.Library.GroupedBy`
- `CodexAppServer.ThreadListQD`

`ThreadListQD` means "thread list query descriptor." It is the SwiftASB-owned
description of caller intent: archive scope, current-directory filter, search
term, page size, and sort preference. The package can compile that descriptor
into local Core Data reads, app-server `thread/list` requests, or observable
refresh behavior without making the persistence store part of the public API.

### Startup behavior

`makeLibrary()` should be opt-in. Do not make ordinary `CodexAppServer.start()`
pay the cost of app-wide thread list hydration.

When a library is created:

- read the local Core Data thread snapshot first
- publish unarchived and archived arrays immediately when local data exists
- group threads according to `Library.GroupedBy`
- keep selected-thread state local to the library
- expose refresh actions for all, unarchived-only, and archived-only scopes
- publish app-wide model, MCP, and hook diagnostics snapshots through a
  separate snapshot refresh action
- reconcile app-server data in the background
- page unarchived threads before archived threads
- ask app-server for most-recent threads first by using `updatedAt`
  descending sort when the selected sort can be represented by app-server
- process small page batches and yield between archive scopes so live turn
  handling has priority
- avoid assuming app-server cannot run concurrent sessions; only throttle harder
  if the runtime reports backpressure or the package observes meaningful local
  performance cost

### Reconciliation policy

Each app-server `thread/list` page should continue to flow through
`ThreadHistoryStore.reconcileThreadListPage(...)`. That keeps Core Data and the
published library snapshots aligned through the same metadata path used by
manual `listThreads(...)` calls.

The library should refresh its public arrays from local Core Data after each
successful archive-scope reconciliation. This keeps the observable sourced from
the same local value snapshots that future query descriptors will use, while
still allowing app-server to correct stale local metadata.

### Event-driven updates

`Library` listens to an internal app-wide event stream from `CodexAppServer`.
The stream is emitted after the app-server event handler has already recorded
the matching Core Data change, so the observable can reload local value
snapshots without re-paging app-server on every notification.

The first event-driven refresh triggers are:

- thread start, resume, fork, rollback, metadata, and name changes initiated
  through SwiftASB public methods
- app-server `thread/started`, `thread/status/changed`, `thread/archived`,
  `thread/unarchived`, `thread/closed`, `thread/name/updated`, and
  `thread/tokenUsage/updated` notifications
- `turn/started` and `turn/completed` notifications, so UI sorting can react to
  active work and most-recently-finished-turn ordering

The app-wide stream is intentionally internal. Public consumers observe the
library's value snapshots and phase/error fields rather than replaying app-wide
transport events themselves.

### Selection policy

Selection belongs to `Library`, not Core Data and not app-server metadata.
Consumers can bind a sidebar or launcher to `selectedThreadID`, call
`selectThread(...)`, and sort by `selectedNewestFirst`.

The selection clock is intentionally library-local. That matches ordinary app
window or scene state: a single-window client can retain one library, while a
multi-window client can keep separate library instances when windows need
independent selection.

Selection changes must not call app-server and must not write to the thread
history store. They are UI state over the existing thread value snapshots.

### App snapshot policy

`Library` can publish app-wide read snapshots for UI that needs connection
state next to stored threads:

- model capabilities from `CodexAppServer.readModelCapabilities()`
- MCP server status from `CodexAppServer.listMcpServerStatuses(...)`
- hook diagnostics from `CodexAppServer.listHooks(...)`

These snapshots are read-through app-server state. They do not go through Core
Data, and they are not reconciled with thread history. The library owns a
separate snapshot phase, timestamp, and error field so thread-list
reconciliation and app-wide capability reads can fail or refresh independently.

Hook diagnostics are cwd-sensitive. Unless a library configuration provides
explicit hook current-directory paths, the library derives hook `cwds` from its
stored thread snapshots. That keeps launcher and sidebar diagnostics aligned
with the projects the library is already showing.

### CWD policy

SwiftASB treats `cwd` as the stored thread project directory for now. The
current app-server wire shape exposes `cwd` as required `ThreadInfo` metadata,
and `thread/metadata/update` only patches Git metadata. There is no stored
thread `cwd` mutation endpoint in the generated v2 snapshot, so `GroupedBy.cwd`
is the honest grouping surface until repository-root detection is designed.

### Follow-on work

- Add project-root detection when SwiftASB has a deliberate repo-root model.
  Until then, `GroupedBy.cwd` is the only project-style grouping case.
- Expand `ThreadListQD` into the shared descriptor used by library snapshots,
  non-UI list reads, and later search-hit hydration.
