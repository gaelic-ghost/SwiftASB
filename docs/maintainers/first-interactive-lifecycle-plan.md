# First Interactive Lifecycle Plan

## Goal

Finish the first real interactive `SwiftASB` lifecycle before adding more
convenience API surface.

The package already covers the happy path well:

- start the app-server
- initialize
- start a thread
- start a turn
- observe a meaningful batch of thread and turn progress

The next gap is what happens after the server begins driving the interaction
instead of only responding to the original client requests.

That means this pass is about:

- approval requests
- elicitation or user-input requests
- deliberate `ThreadItem`-level public modeling
- enough notification coverage to support a real multi-turn interactive flow

It is not about adding sugar just because the current surface can already start
turns.

## Why This Comes Before `run(...)`

A one-shot `run(...)` API only helps if the package already has a clear answer
for the lower-level lifecycle it is hiding.

Right now the lower-level lifecycle is still settling in three places:

1. where server-originated requests live in the public model
2. how much item activity belongs in streams versus observable companions
3. which generated notification families are actually part of the supported
   public lifecycle

If we add `run(...)` first, we risk baking in assumptions that get invalidated
as soon as approval or elicitation handling lands.

## Concrete Outcome For This Pass

This pass is complete when a Swift consumer can:

- start the app-server
- initialize a session
- start a thread
- start a turn
- observe meaningful thread and turn progress
- receive approval or elicitation requests from the server
- answer those requests through a deliberate public API
- keep building on typed Swift models without touching raw JSON-RPC payloads

## Ordered Work Plan

## Decisions Made

These choices are now considered decided for the first interactive lifecycle
pass unless a concrete protocol constraint forces a revisit.

### 1. Keep the current ownership model

- `CodexAppServer` remains the owner of transport, protocol, fanout, and
  server-request routing.
- `CodexThread` remains the ergonomic thread-scoped handle.
- `CodexTurnHandle` remains the ergonomic turn-scoped handle.
- No new wrapper tier should be introduced for approval or elicitation work.

### 2. Make streams the source of truth

- Typed async streams remain the canonical lifecycle surface.
- `Dashboard` and `Minimap` remain current-state mirrors fed from typed public
  events.
- Observable companions must not become a second independent control path.

### 3. Use a stream-first model for approval and elicitation

- Approval and elicitation requests should appear as typed turn-scoped public
  events.
- If a server-originated interactive request cannot be confidently routed to a
  `CodexTurnHandle`, it should fall back to a deliberate thread-scoped public
  event rather than being forced into an incorrect turn association.
- Responses should be sent through explicit public methods on the owning
  surface, routed by `CodexAppServer` and exposed ergonomically from
  `CodexTurnHandle`.
- Callback-first handling is out of scope for this pass.

### 4. Make item activity stream-first

- `ThreadItem`-level activity belongs primarily in typed public event streams.
- Observable companions may mirror selected latest-state summaries when useful
  for UI consumers.
- The package should avoid an observable-first item model for canonical
  lifecycle history, but carefully chosen observable-only current-state
  summaries are acceptable when they are more ergonomic than raw event replay.

### 5. Promote protocol coverage by release intent, not schema breadth

- The generated lifecycle graph must be classified deliberately.
- Only notification families required for the first supported interactive
  lifecycle should become public in this pass.
- Schema completeness alone is not a reason to widen the public API.

### 6. Keep public errors unified

- Public lifecycle failures should continue to surface as
  `CodexAppServerError`.
- Internal protocol and transport details may be preserved as underlying causes,
  but the stable public contract should not expose raw protocol-layer error
  types directly.

### 7. Defer `run(...)` until after the interactive lifecycle is real

- Do not design or ship a one-shot `run(...)` API during this pass unless the
  approval and elicitation work somehow forces it.
- The lower-level interactive lifecycle must be coherent before a convenience
  API is allowed to hide it.

### 8. Buffer early interactive turn events

- `startTurn(...)` returning a `CodexTurnHandle` must not force consumers to
  race the server just to observe the first interactive lifecycle request.
- Turn buffering for this pass should widen beyond terminal-only buffering to
  cover the early approval, elicitation, and closely related resolution events
  needed for a sane first consumer experience.
- Buffering should stay lifecycle-oriented and deliberate rather than becoming
  an unbounded hidden event log.
- Approval requests are usually one-at-a-time per thread, so thread-level
  mirrors may preserve the current pending approval briefly if that proves
  useful for UI consumers, but this is optional rather than required for the
  first pass.

### 9. Keep turn-handle answers ergonomic

- The public answer path for approval and elicitation requests should live on
  `CodexTurnHandle`.
- `CodexAppServer` remains the underlying transport and request-routing owner.
- The package should avoid splitting the public control path across multiple
  top-level surfaces when the interaction clearly belongs to one turn.

### 10. Treat server request IDs as the internal resolution key

- Approval requests have enough turn-scoped context to surface naturally on
  `CodexTurnHandle`, but their cleanup path still needs explicit internal
  correlation.
- Command approvals carry `itemId`, `threadId`, `turnId`, and may also carry an
  optional `approvalId` for subcommand callback disambiguation.
- File-change approvals carry `itemId`, `threadId`, and `turnId`.
- MCP elicitation requests carry `threadId` and a best-effort nullable `turnId`,
  so turn routing is a correlation convenience rather than the protocol’s
  canonical identity.
- `serverRequest/resolved` carries `threadId` plus `requestId`, so internal
  outstanding-request tracking must key off the JSON-RPC server request id even
  when the public API presents a turn-scoped model.

### 11. Keep "session" out of this layer

- Do not introduce a `CodexSession` type for the current public lifecycle.
- In this package, "session" is too ambiguous because it could mean the
  initialized transport connection, a thread-scoped conversation, or a bundle
  of reusable execution defaults.
- `CodexAppServer` already owns the connection-level lifecycle, and
  `CodexThread` already owns the conversation-level lifecycle, so adding
  `CodexSession` here would blur responsibilities rather than clarify them.

### 12. Treat reusable execution knobs as thread defaults, not as a new owner

- If the package later needs a shared value type for reusable execution knobs,
  prefer a narrow shape such as `CodexThreadDefaults` rather than a new
  top-level owner like `CodexAgent` or a vague catch-all like `CodexConfig`.
- The intended model is:
  - app-level defaults apply when starting a new thread unless the caller
    overrides them before `thread/start`
  - after a thread exists, user changes should become thread-scoped persisted
    overrides that affect future turns for that thread only
  - changes made in one thread must not silently affect unrelated threads
- This keeps the ownership model stable:
  - `CodexAppServer` owns connection and process concerns
  - `CodexThread` owns conversation-scoped defaults and turn creation
  - `CodexTurnHandle` owns active-turn control
- A broader name such as `CodexExecutionContext` may still make sense later for
  side-channel or operator-triggered surfaces that are not cleanly modeled as
  thread defaults, but that is a later design pass rather than part of the
  first interactive lifecycle release boundary.

## Phase 1: Lock The Public Ownership Model

Objective:

Make sure Milestone 5 can build on the current ownership story without forcing
another structural rewrite.

Desired output:

- a short written decision in this doc or the roadmap
- no new wrappers unless a real ownership gap is found

Decision:

Keep the current top-level ownership model. If future work needs more
ergonomic forwarding, add it on the existing handles rather than introducing a
new ownership layer.

## Phase 2: Audit The Generated Lifecycle Graph

Objective:

Turn the current "the generated layer has many more notifications" fact into a
deliberate public-support map.

Work:

- inspect the promoted generated v2 lifecycle batch
- list the notification families relevant to the first public interactive
  lifecycle
- classify each family as:
  - public now
  - observable-only for now
  - internal-only for now

Minimum families to classify:

- thread lifecycle
- turn lifecycle
- item lifecycle
- reasoning deltas
- tool-progress and command-output deltas
- approval-related item notifications
- server-request resolution notifications
- error notifications

Desired output:

- one maintainer-facing classification table
- roadmap entries that match that table

## Phase 3: Design The Approval And Elicitation Surface

Objective:

Choose one deliberate public model for server-originated requests before wiring
more protocol types upward.

Decision:

Use a stream-first model anchored in the existing typed async lifecycle.

Chosen shape:

- `CodexTurnEvent` gains typed server-request cases for approval and elicitation
- approval and elicitation cases should carry dedicated public value types
  rather than generic catch-all payload shapes
- the public model should be broad enough to grow into additional interactive
  server-request families over time, even if the first shipped slice only maps
  a narrower subset concretely
- answering those requests happens through explicit methods on the owning
  surface, likely routed through `CodexAppServer` and exposed ergonomically from
  `CodexTurnHandle`
- if a request cannot be confidently routed to a turn, it should surface on a
  thread-scoped event path instead of being misclassified as a turn event
- `Minimap` may mirror only the latest approval or elicitation state if that
  turns out to be useful for UI consumers, but approval mirroring is optional
  rather than mandatory for the first pass
- `Minimap` may mirror richer in-flight work state for UI consumers, such as a
  stable array of tool, MCP, or file-edit call snapshots with display name
  plus a small lifecycle enum like `inProgress`, `completed`, or `error` when
  that provides a clearer "calls made during this turn" surface than raw event
  playback
- turn-scoped streams should buffer the early interactive request and
  resolution events that can arrive before a consumer starts iterating the
  handle-owned stream returned by `startTurn(...)`
- server-request resolution support is part of the first pass rather than a
  follow-up cleanup slice

Non-goals:

- do not expose raw generated request payloads directly just to get coverage
  quickly
- do not add callback-first handling in this pass

## Phase 4: Promote The Minimal Additional Protocol Coverage

Objective:

Add only the protocol mapping needed for the first public interactive lifecycle.

Work:

- map the selected approval and elicitation request types
- map any server-request resolution or related lifecycle types needed to keep
  public state coherent
- add any missing item or tool-progress notifications that are necessary for
  real interaction, not just completeness

Guardrail:

Do not promote every generated notification family just because it exists. Add
only what supports the public lifecycle we are intentionally shipping.

## Phase 5: Public API Wiring

Objective:

Expose the newly chosen interactive lifecycle shape without weakening the
existing public model.

Work:

- add typed public value models for approval and elicitation requests
- expose typed answering APIs on the owning public surface
- keep `ThreadItem` activity stream-first, with observable mirrors only where a
  UI-facing current-state summary is genuinely useful
- allow companion-only summaries for selected operational state when the public
  consumer need is "what is happening right now" rather than "replay the exact
  event history"
- keep naming explicit and lifecycle-oriented
- make the internal routing model strong enough to resolve requests by
  JSON-RPC request id while still exposing turn-oriented public handles when the
  request is correlated to a turn

Decision:

Use the public stream as the source of truth and let observable companions lag
slightly behind as current-state mirrors.

That keeps one canonical lifecycle path:

- streams answer "what happened, in order"
- observable companions answer "what is the latest useful state for UI right
  now"

Observable summaries now shipped from that plan:

- `CodexTurnHandle.Minimap.callSnapshots` for a stable per-turn list of tool,
  MCP, and file-edit activity summaries
- `CodexThread.Dashboard.isCompactingThreadContext` when context compaction is
  actively blocking normal forward progress
- aggregate thread-level tool-calling and MCP-calling status through
  `CodexThread.Dashboard`

Near-term adjacent public surfaces worth planning now:

- `thread/list` so consumers can enumerate conversations without dropping to
  raw JSON-RPC
- `thread/resume` so consumers can continue a conversation through the package
- `thread/fork` so consumers can branch an existing conversation without
  rebuilding history manually
- `thread/read` so consumers can deliberately fetch thread and turn history,
  especially for completed-turn inspection and richer item detail lookup

Open design question worth deciding before that thread-management pass lands:

- should `SwiftASB` cache completed turn results received through
  `turn/completed` as a convenience for consumers, or should completed-turn
  retention remain explicitly consumer-owned until `thread/read` exists as the
  authoritative fetch path?

Status update after the current observable pass:

- this repo now ships the core version of that design
- `CodexTurnHandle.Minimap` is attached when the handle is created
- the shipped minimap now exposes `callSnapshots` for command, file-edit,
  dynamic-tool, collab-tool, and MCP activity
- `CodexThread.Dashboard` now exposes aggregate tool and MCP activity plus
  `isCompactingThreadContext`
- the remaining design gap is no longer "should we have current-state mirrors
  at all?" but "how much richer progress detail should escape the current
  summary mirrors?"

## Draft Unified Observable Model

This section began as a draft for the next observable-shaping pass. Its core
shape is now shipped, so the notes below should be read as a record of the
intended model plus the remaining open refinement questions.

### Minimap draft

`CodexTurnHandle.Minimap` should expose a single unified collection for
in-flight and completed turn activity that a UI can render as a "calls made
during this turn" list without having to interpret raw deltas.

Review-driven ownership correction:

- `Minimap` should be created and attached when `startTurn(...)` creates the
  `CodexTurnHandle`, not later on demand.
- the public handle should expose a stored `turn.minimap` reference instead of
  depending on a late `makeMinimap()` subscription for correctness.
- this avoids losing early item activity that starts before a consumer asks for
  a minimap and makes `callSnapshots` an honest per-turn current-state mirror.

Shipped shape:

- `callSnapshots: [CallSnapshot]`

Current `CallSnapshot` fields:

- `id: String`
- `kind: CallKind`
- `displayName: String`
- `status: CallStatus`
- `latestStatusText: String?`
- `filePath: String?`
- `toolName: String?`
- `serverName: String?`

Still-open field question:

- whether we need a stronger public blocked-progress flag or richer progress
  payload rather than the current summary-oriented shape

Current `CallKind` cases:

- `command`
- `mcp`
- `dynamicTool`
- `collabTool`
- `fileEdit`

Current `CallStatus` cases:

- `inProgress`
- `completed`
- `errored`

Mapping intent:

- `item/started` for `commandExecution`, `mcpToolCall`, `dynamicToolCall`,
  `collabAgentToolCall`, and `fileChange` should create or update the matching
  snapshot
- `item/completed` should mark the snapshot `completed` or `errored`
- command, file-change, and MCP progress notifications may later enrich the
  current snapshot instead of forcing new top-level public event cases

Attachment rule:

- `CodexTurnHandle` owns exactly one minimap for its turn
- value copies of the handle should continue to reference the same minimap
- compatibility helpers may remain temporarily, but they should forward to the
  already-attached minimap rather than creating a second subscription path

### Dashboard draft

`CodexThread.Dashboard` should expose current thread-level system state that
helps a consumer answer "what is blocking or occupying this thread right now?"

Review-driven correction:

- `Dashboard` should stay opt-in for now rather than being attached eagerly to
  every thread.
- because it remains optional, `CodexAppServer` must not accumulate an
  unbounded thread-scoped backlog of turn events just in case a dashboard might
  appear later.
- thread-level aggregate status should describe what is happening right now, so
  active in-flight work should win over stale error residue when both are
  present.

Current fields:

- `isCompactingThreadContext: Bool`
- `toolCallingStatus: ActivityStatus`
- `mcpCallingStatus: ActivityStatus`

Proposed `ActivityStatus` cases:

- `idle`
- `inProgress`
- `errored`

Design note:

- avoid a thread-level `completed` state unless a concrete UI need proves that
  it carries better meaning than immediately falling back to `idle`
- if one tool or MCP call has errored but another is still running, aggregate
  status should remain `inProgress` until no relevant work is active

Status update:

- the shipped dashboard now follows that rule
- remaining work is about whether we need richer compaction detail or more
  specific blocked-state explanations beyond the current aggregate statuses

### Reroute handling draft

Model-rerouted notifications should currently stay internal.

Current reasoning:

- the generated wire family appears to communicate an operational model switch,
  not a consumer action surface
- the currently generated reroute reason set is narrow and not consumer-owned
- internal logging is useful, but public API exposure is not yet earned

## Phase 6: Tests Before Sugar

Objective:

Prove the interactive lifecycle works through the public API before adding
convenience wrappers.

Required tests:

- fake-transport tests for approval request delivery
- fake-transport tests for elicitation request delivery
- fake-transport tests for answering those requests through the chosen public
  surface
- fake-transport tests for buffered delivery of early approval or elicitation
  events on a newly returned `CodexTurnHandle`
- fake-transport tests for request-resolution delivery and cleanup keyed from
  the original JSON-RPC server request id
- regression coverage that proves the existing turn and thread event flows still
  behave correctly

Preferred live coverage:

- one opt-in live integration test that exercises at least one stable
  server-originated request path if the local Codex runtime exposes a reliable
  repro

## Phase 7: Consumer Docs And Release Boundary

Objective:

Document the supported lifecycle once the shape is stable.

Required docs work:

- add a `Supported Today` section to `README.md`
- add at least one consumer-facing example for the interactive lifecycle
- document the current concurrency contract next to the example surfaces
- document what remains intentionally internal

The release-boundary text should answer:

- which public types are stable enough for consumers
- which generated-wire surfaces remain internal scaffolding
- which protocol families are intentionally not surfaced yet

## What To Defer During This Pass

Unless one of the steps above forces it, defer:

- `run(...)`
- broader convenience wrappers
- public generated-wire exposure
- full-schema parity for its own sake
- architecture changes that introduce a second ownership tree

## Recommended Immediate Next Task

If work starts from code instead of more planning, the best next concrete task
is:

1. audit the generated lifecycle batch
2. write down the public-now versus internal-for-now classification
3. choose the approval and elicitation public model from that audit

That sequence will reduce the chance of implementing the wrong public API just
because the schema contains more events than the first release actually wants to
support.
