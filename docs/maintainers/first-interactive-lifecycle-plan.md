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
- Responses should be sent through explicit public methods on the owning
  surface, routed by `CodexAppServer` and exposed ergonomically from
  `CodexTurnHandle`.
- Callback-first handling is out of scope for this pass.

### 4. Make item activity stream-first

- `ThreadItem`-level activity belongs primarily in typed public event streams.
- Observable companions may mirror selected latest-state summaries when useful
  for UI consumers.
- The package should avoid an observable-first item model.

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
- answering those requests happens through explicit methods on the owning
  surface, likely routed through `CodexAppServer` and exposed ergonomically from
  `CodexTurnHandle`
- `Minimap` may mirror only the latest approval or elicitation state if that
  turns out to be useful for UI consumers

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
- keep naming explicit and lifecycle-oriented

Decision:

Use the public stream as the source of truth and let observable companions lag
slightly behind as current-state mirrors.

That keeps one canonical lifecycle path:

- protocol event
- public typed event
- optional observable mirror update

instead of creating two equivalent public control systems.

## Phase 6: Tests Before Sugar

Objective:

Prove the interactive lifecycle works through the public API before adding
convenience wrappers.

Required tests:

- fake-transport tests for approval request delivery
- fake-transport tests for elicitation request delivery
- fake-transport tests for answering those requests through the chosen public
  surface
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
