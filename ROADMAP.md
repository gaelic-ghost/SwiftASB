# Project Roadmap

## Vision

- Make `SwiftASB` a small, dependable Swift package for talking to the local Codex app-server with a public API that feels native to Swift rather than like a thin JSON-RPC dump.

## Product Principles

- Keep the public API compact and easy to reason about.
- Keep generated wire models internal unless a public exposure case is clearly earned.
- Prefer explicit data models, actor ownership, and typed async streams over stringly fallback surfaces.
- Grow the package from real lifecycle use cases instead of speculative abstraction.
- Keep tests, maintainer notes, and roadmap status aligned with the actual shipped surface.

## Current Feature Matrix

| Area | Current Status | Notes |
| --- | --- | --- |
| Bundled schema-driven wire generation | `Shipped internally` | `scripts/generate-wire-types.sh` derives from the bundled v2 schema, patches dynamic JSON to `CodexWireJSONValue`, and validates the staged Swift output. |
| Promoted generated v2 wire snapshot | `Shipped internally` | `Sources/SwiftASB/Generated/CodexWire/Latest/` now contains a wider lifecycle batch covering bootstrap plus many thread, turn, item, reasoning, and tool-progress notifications, alongside the hand-owned `CodexWireInitializeResponse` shim. |
| Stdio subprocess transport | `Shipped internally` | The transport launches `codex app-server --listen stdio://`, frames newline-delimited JSON, correlates request IDs, and captures stderr for diagnostics. |
| Raw server-event fanout | `Shipped internally` | Transport can stream raw JSON-RPC notifications and server requests to higher layers. |
| Typed protocol request encoding | `Shipped internally` | `initialize`, `initialized`, `thread/start`, and `turn/start` are encoded through the protocol layer. |
| Typed protocol response decoding | `Shipped internally` | `initialize`, `thread/start`, and `turn/start` responses are decoded and validated against request IDs. |
| Typed protocol notification decoding | `Partially shipped` | The protocol layer now maps a broader batch of thread, turn, item, and reasoning notifications that feed both public event streams and live observable companions. |
| Public owning client actor | `Shipped` | `CodexAppServer` owns transport plus protocol and exposes startup, shutdown, initialize, thread start, and turn start. |
| Public value-typed request and result models | `Shipped` | Public API uses hand-owned Swift value types rather than exposing `CodexWire...` directly. |
| Initialize handshake | `Shipped` | `initialize(...)` automatically sends the follow-up `initialized` notification. |
| Thread start flow | `Shipped` | `startThread(...)` returns `CodexThread`, which carries thread metadata plus a back-reference to the shared app-server owner. |
| Typed async thread event stream | `Partially shipped` | `CodexThread.events` now streams `thread/started`, `thread/status/changed`, `thread/archived`, `thread/unarchived`, `thread/name/updated`, `thread/tokenUsage/updated`, and `thread/closed`, but broader thread lifecycle coverage is still pending. |
| Turn start flow | `Shipped` | `startTurn(...)` returns `CodexTurnHandle`. |
| Typed async turn event stream | `Partially shipped` | `CodexTurnHandle.events` now streams `turn/started`, `turn/plan/updated`, `turn/diff/updated`, item lifecycle updates, message deltas, reasoning deltas, and `turn/completed`, but broader item and thread events still remain internal. |
| Multiple active threads per app-server | `Shipped` | One `CodexAppServer` now supports many concurrently held `CodexThread` handles, and the package tests plus live probes treat cross-thread concurrency as a supported model. |
| Multiple simultaneous turns on one thread | `Resolved for now` | Live probing showed that same-thread overlap is not independently routable at the app-server layer today, so `SwiftASB` rejects overlapping same-thread turns client-side with `CodexAppServerError.invalidState`. |
| `CodexThread` convenience wrapper | `Partially shipped` | `CodexThread` exists, owns thread-scoped turn creation, includes a `startTextTurn(...)` happy-path helper, exposes a typed thread event stream, and can now vend a live `Dashboard` observable mirror via `makeDashboard()`. |
| `CodexTurnHandle` live observable companion | `Partially shipped` | `CodexTurnHandle` can now vend a live `Minimap` observable mirror via `makeMinimap()`, seeded from the initial turn snapshot and updated from the turn event stream. |
| Additional turn event mapping | `Partially started` | The generated wire layer now includes many relevant notification types, but most are not yet promoted into protocol/public event enums. |
| Server request / approval handling | `Partially shipped` | Typed approval and elicitation request models now surface on thread and turn event streams, explicit response APIs exist on `CodexThread` and `CodexTurnHandle`, and request resolution is tracked by JSON-RPC request id, but broader live coverage and more server-request families are still open. |
| Convenience run API | `Not started` | No `run(...)` or one-shot text convenience layer yet. |
| Binary discovery and compatibility policy | `Partial` | Explicit binary override exists, but version compatibility policy and richer discovery diagnostics are still open. |
| README-level consumer docs | `Partially shipped` | The README now covers installation, runtime assumptions, a minimal usage example, and the current concurrency contract, but richer examples plus compatibility guidance are still open. |
| End-to-end subprocess integration tests | `Partially shipped` | The package includes opt-in live Codex CLI integration tests with temp workspaces and time limits, including same-thread concurrency probing and a live approval-path behavior probe, while the default test suite still relies on a deterministic fake transport seam. |
| Apache 2.0 licensing | `Shipped` | The repo now carries an Apache 2.0 `LICENSE` file and README references the live license surface. |

## Milestone Progress

- [x] Milestone 0: Package and repo baseline
- [x] Milestone 1: Wire model and codegen foundation
- [x] Milestone 2: Stdio transport and typed protocol slice
- [x] Milestone 3: Public client actor and first lifecycle API
- [ ] Milestone 4: Event streams and ergonomic handles
- [ ] Milestone 5: Approvals, richer notifications, and broader protocol coverage
- [ ] Milestone 6: Public docs, examples, and release readiness

## Current Maintainer Priority

The next meaningful package step is not "more API surface."

The next meaningful step is to finish the first real interactive lifecycle so the
public API can represent what the live app-server actually does once a turn is
running and the server starts talking back.

That means the current priority order is:

1. Finish the Milestone 5 lifecycle gaps.
2. Lock the public shape for event streams, approval handling, and item-level activity.
3. Write consumer-facing examples and release-boundary docs for the now-stable shape.
4. Re-evaluate whether a convenience `run(...)` API is still earned after the lower-level lifecycle feels complete.

## Proposed Next Release Slice

Treat the next release candidate as a "first interactive lifecycle" release, not
as a convenience-API release.

### Must ship in the next slice

- Typed public handling for server-originated approval and elicitation requests.
- Enough notification coverage that a consumer can build a multi-turn interactive flow without dropping to raw payloads.
- A deliberate public story for `ThreadItem`-level activity, whether that is stream-first, observable-first, or explicitly split between the two.
- A written release boundary that says what is public, what stays internal scaffolding, and what is intentionally unsupported.
- Consumer-facing examples that exercise the supported lifecycle shape rather than only the minimal bootstrap path.

### Explicitly defer unless one of the above forces it

- A one-shot `run(...)` convenience API.
- Broader sugar beyond `startTextTurn(...)`.
- Public exposure of generated wire models.
- Expanding the public API just because the generated schema contains more message types.

### Exit signal for this slice

This slice is done when a Swift consumer can:

- start the app-server
- initialize a session
- start a thread
- start a turn
- observe meaningful thread and turn progress
- respond to approval or elicitation requests
- understand, from the docs alone, which lifecycle surfaces are supported today

without needing raw JSON-RPC access or generated wire types.

## Decisions Made For The First Interactive Lifecycle

- Keep the current ownership model:
  - `CodexAppServer` owns transport, protocol, fanout, and server-request routing.
  - `CodexThread` remains the ergonomic thread handle.
  - `CodexTurnHandle` remains the ergonomic turn handle.
- Keep typed async streams as the canonical lifecycle surface.
- Keep `Dashboard` and `Minimap` as current-state mirrors of typed public events, not as a second control path.
- Use a stream-first model for approval and elicitation requests.
- Keep `ThreadItem` activity stream-first, with observable companions mirroring only selected latest-state summaries when useful.
- Promote additional notification families by supported-release intent, not by schema breadth alone.
- Keep public lifecycle failures unified under `CodexAppServerError`.
- Defer a one-shot `run(...)` API until the lower-level interactive lifecycle is complete enough to hide honestly.

## Milestone 0: Package And Repo Baseline

Scope:

- [x] Create the SwiftPM library package scaffold.
- [x] Enable Swift 6 language mode.
- [x] Add repo-local guidance for package work.
- [x] Add a minimal public namespace and smoke-test coverage.
- [x] Add root `ROADMAP.md` so project planning has a durable home.

Exit criteria:

- [x] `swift build` passes.
- [x] `swift test` passes.

## Milestone 1: Wire Model And Codegen Foundation

Scope:

- [x] Decide that the bundled Codex app-server v2 schema is the primary generated-wire source of truth.
- [x] Build a repeatable derivation flow that turns the bundled schema into a quicktype-friendly root.
- [x] Patch dynamic JSON holes to `CodexWireJSONValue`.
- [x] Promote the generated v2 lifecycle batch into `Sources/SwiftASB/Generated/CodexWire/Latest/`.
- [x] Expand the generated v2 lifecycle batch to include a broader notification/event family rather than only the minimal bootstrap slice.
- [x] Keep `CodexWireInitializeResponse` hand-owned until the upstream v2 schema exposes it directly.

Exit criteria:

- [x] `scripts/generate-wire-types.sh` regenerates the staged wire layer successfully.
- [x] The promoted generated v2 batch compiles cleanly with the package.
- [x] The v1 generated batch is no longer required as a promoted compiled artifact.

## Milestone 2: Stdio Transport And Typed Protocol Slice

Scope:

- [x] Implement an internal stdio transport around `codex app-server --listen stdio://`.
- [x] Correlate JSON-RPC responses by request ID.
- [x] Fan out non-response inbound messages as raw server events.
- [x] Build typed protocol helpers for `initialize`, `initialized`, `thread/start`, and `turn/start`.
- [x] Add focused tests that prove envelope classification and protocol encode/decode behavior.

Exit criteria:

- [x] Transport and protocol layers are buildable and covered by Swift Testing suites.
- [x] Protocol errors are descriptive and carry method-specific context.
- [x] The package has a stable internal seam between transport and protocol responsibilities.

## Milestone 3: Public Client Actor And First Lifecycle API

Scope:

- [x] Implement a public `CodexAppServer` actor that owns transport plus protocol.
- [x] Keep the public request and response models hand-owned and Swift-shaped.
- [x] Expose `start()`, `stop()`, `initialize(...)`, `startThread(...)`, and `startTurn(...)`.
- [x] Enforce initialize-before-thread and initialize-before-turn lifecycle guards.
- [x] Map internal transport and protocol failures into public-facing `CodexAppServerError`.
- [x] Add deterministic public-client tests using an internal fake transport seam.

Exit criteria:

- [x] The public client can complete initialize, thread start, and turn start in tests.
- [x] The initialize handshake sends `initialized` automatically.
- [x] The public API does not expose generated `CodexWire...` types.

## Milestone 4: Event Streams And Ergonomic Handles

Scope:

- [x] Return `CodexTurnHandle` from `startTurn(...)`.
- [x] Expose a real `AsyncThrowingStream` for turn events.
- [x] Decode `turn/completed` into a typed public turn event.
- [x] Keep per-turn stream fanout owned by the public client actor.
- [x] Treat one `CodexAppServer` as the shared owner for many logical threads.
- [x] Add a lightweight `CodexThread` wrapper around the shared owning app-server.
- [x] Make multiple active threads a first-class supported consumer model once `CodexThread` exists.
- [x] Verify real app-server behavior for multiple simultaneous turns on the same thread.
- [x] Decide whether same-thread concurrent turns should be allowed, queued, or rejected in the public API.
- [x] Add a thread-scoped turn start API so normal consumers do not carry raw thread IDs around.
- [x] Add a simple text-only turn convenience on `CodexThread` for the common case.
- [x] Add live observable thread state via `CodexThread.Dashboard` and `makeDashboard()`.
- [x] Add live observable turn state via `CodexTurnHandle.Minimap` and `makeMinimap()`.
- [x] Decide whether additional convenience APIs belong as observable companions, async helpers, or neither.
  Decision: defer new convenience APIs for now; keep the current handle model and revisit helpers only after the interactive lifecycle is complete enough to hide honestly.
- [x] Decide how much terminal-event buffering should remain implicit versus explicit in the public API.
  Decision: typed public streams remain the canonical lifecycle surface, while `Dashboard` and `Minimap` keep only current-state mirror buffering rather than becoming a second event system.
- [x] Decide whether Milestone 4 is complete enough to freeze the current handle model before adding approval-driven surfaces above it.
  Decision: yes for ownership. `CodexAppServer`, `CodexThread`, `CodexTurnHandle`, `Dashboard`, and `Minimap` are the model Milestone 5 should build on.

Exit criteria:

- [x] A started turn can emit at least one typed async event through a handle-owned stream.
- [x] `CodexThread` exists as a public ergonomic wrapper with a clear ownership model.
- [x] The documented concurrency model is explicit for both cross-thread and same-thread turn starts.
- [x] The remaining open questions for Milestone 4 are narrow enough that Milestone 5 can build on the current handles without likely reshaping them again.
- [ ] Thread and turn handles plus their observable companions feel like the real public surface rather than transitional wrappers.

## Milestone 5: Approvals, Richer Notifications, And Broader Protocol Coverage

Scope:

- [x] Add typed protocol mapping for an initial batch of generated thread, turn, item, and reasoning notifications beyond `turn/completed`.
- [ ] Audit the generated lifecycle batch and explicitly mark which notification families matter for the first interactive public lifecycle.
- [ ] Expand typed protocol mapping to the remaining generated notifications that matter for the first public interactive lifecycle.
- [x] Decide how to surface `ThreadItem`-level activity in the public API.
  Decision: stream-first, with observable companions limited to selected latest-state mirrors for UI-oriented summaries.
- [x] Add a public model for server-originated approval and elicitation requests.
- [x] Decide whether approval handling should be callback-based, stream-based, or both.
  Decision: stream-first. Approval and elicitation requests should arrive as typed public events, with answers sent through explicit public methods on the owning surface.
- [x] Add fake-transport tests that prove approval and elicitation messages can be observed and answered through the chosen public shape.
- [ ] Add opt-in live coverage for at least one approval or server-request path if the local Codex runtime exposes a stable repro.
- [ ] Add cancellation, interruption, or steering flows if they are part of the intended first public lifecycle.
- [ ] Revisit whether more of the generated wire graph needs to be promoted into internal compiled sources.

Exit criteria:

- [x] The repo has a deliberate answer for where approval requests, elicitation requests, and item-level activity belong in the public model.
- [x] The public API can represent the most important server-driven lifecycle events without dropping back to raw payloads.
- [x] Approval and user-input request handling has a deliberate public model.
- [ ] The package covers a meaningful multi-turn interactive lifecycle rather than only the happy-path bootstrap.

## Milestone 6: Public Docs, Examples, And Release Readiness

Scope:

- [x] Expand `README.md` with installation, runtime assumptions, and a minimal working example.
- [x] Document the local Codex CLI dependency and explicit binary override path clearly.
- [ ] Add consumer-facing examples for initialize, thread start, turn start, event streaming, and approval handling.
- [ ] Decide on the first release boundary and what remains intentionally internal.
- [ ] Add an explicit "Supported Today" section to `README.md` that mirrors the real public lifecycle and concurrency contract.
- [ ] Add a maintainer-facing note that clarifies which generated notification families intentionally remain internal for now.
- [ ] Add version-compatibility policy notes for the local Codex binary.
- [x] Decide whether real subprocess integration tests are required before the first release.
  Decision: yes, but as opt-in suites rather than as part of the default `swift test` path while the live Codex runtime remains an external local dependency.
- [x] Add an explicit open-source license for the package.

Exit criteria:

- [x] A new consumer can understand what `SwiftASB` is, what it depends on, and how to use the first supported lifecycle slice.
- [ ] The release boundary between public API, internal wire scaffolding, and unsupported protocol surfaces is explicit.
- [ ] A new consumer can discover the supported interactive lifecycle, including approval handling if shipped, from docs and examples without reading tests or maintainer notes.
- [x] The roadmap can identify a credible `v0.x` release candidate instead of only an exploration phase.

## Open Tickets

- [x] Freeze the Milestone 4 handle model enough that Milestone 5 does not reopen the ownership story for `CodexAppServer`, `CodexThread`, `CodexTurnHandle`, `Dashboard`, and `Minimap`.
- [ ] Audit the generated lifecycle graph and classify events as public now, observable-only for now, or internal-only for now.
- [x] Add `CodexThread` as a first-class public wrapper and move turn creation onto it.
- [x] Document and enforce the intended behavior for multiple active threads on one `CodexAppServer`.
- [x] Investigate same-thread concurrent turn behavior against the real app-server and codify the result.
  Result: cross-thread concurrent turns complete successfully through the live client, but same-thread overlap is not independently routable at the live app-server layer today. `SwiftASB` now rejects overlapping same-thread `startTurn(...)` calls client-side with a descriptive `CodexAppServerError.invalidState` until the upstream lifecycle semantics become reliable.
- [x] Map an initial progress-oriented notification batch into `CodexTurnEvent` so the stream covers more than completion.
- [x] Decide whether additional item lifecycle and thread-scoped notifications should join the public stream surface or instead only feed observable companions like `Dashboard` and `Minimap`.
  Decision: default to the public stream; use observable companions only for selected current-state mirrors.
- [x] Decide whether the public stream should surface protocol failures directly or always wrap them as `CodexAppServerError`.
  Decision: keep public lifecycle failures unified under `CodexAppServerError`, with internal causes preserved only as supporting detail.
- [x] Add a typed surface for approval requests and other server-originated request messages.
- [x] Add tests that prove approval and elicitation handling through the public surface before adding more convenience APIs.
- [ ] Add a one-shot `run(...)` convenience API once the handle model feels stable.
- [ ] Add consumer-facing examples for the supported interactive lifecycle before broadening the public API further.
- [x] Add a real subprocess-backed integration test harness once the supported event set is less volatile.
  Current shape: the repo now has an opt-in live harness for raw transport/protocol checks plus public-client turn and concurrency probes; broader always-on subprocess coverage is still intentionally deferred.
- [x] Expand `README.md` with first-use examples and runtime expectations.
