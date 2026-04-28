# Project Roadmap

## Table of Contents

- [Vision](#vision)
- [Product Principles](#product-principles)
- [Current Feature Matrix](#current-feature-matrix)
- [Milestone Progress](#milestone-progress)
- [Current Maintainer Priority](#current-maintainer-priority)
- [Live App-Server Findings](#live-app-server-findings)
- [Proposed Next Release Slice](#proposed-next-release-slice)
- [Decisions Made For The First Interactive Lifecycle](#decisions-made-for-the-first-interactive-lifecycle)
- [Milestone 0: Package And Repo Baseline](#milestone-0-package-and-repo-baseline)
- [Milestone 1: Wire Model And Codegen Foundation](#milestone-1-wire-model-and-codegen-foundation)
- [Milestone 2: Stdio Transport And Typed Protocol Slice](#milestone-2-stdio-transport-and-typed-protocol-slice)
- [Milestone 3: Public Client Actor And First Lifecycle API](#milestone-3-public-client-actor-and-first-lifecycle-api)
- [Milestone 4: Event Streams And Ergonomic Handles](#milestone-4-event-streams-and-ergonomic-handles)
- [Milestone 5: Approvals, Richer Notifications, And Broader Protocol Coverage](#milestone-5-approvals-richer-notifications-and-broader-protocol-coverage)
- [Milestone 6: Public Docs, Examples, And Release Readiness](#milestone-6-public-docs-examples-and-release-readiness)
- [Open Tickets](#open-tickets)
- [Backlog Candidates](#backlog-candidates)
- [History](#history)

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
| Codex CLI `v0.125.0` schema review | `In progress` | The local `codex-schemas/v0.125.0/` dump has been compared against `v0.124.0`, the default staging codegen path now targets `v0.125.0`, and the public compatibility window now spans `0.123.x` through `0.125.x`. `thread/resume` and `thread/fork` now expose the additive `excludeTurns` request knob. The stricter v0.125 `permissionProfile` wire shape is covered by an explicit compatibility shim instead of a blind generated snapshot swap. |
| Stdio subprocess transport | `Shipped internally` | The transport launches `codex app-server --listen stdio://`, frames newline-delimited JSON, correlates request IDs, and captures stderr for diagnostics. |
| Raw server-event fanout | `Shipped internally` | Transport can stream raw JSON-RPC notifications and server requests to higher layers. |
| Typed protocol request encoding | `Shipped internally` | `initialize`, `initialized`, `thread/start`, `thread/list`, `thread/read`, `thread/resume`, `thread/fork`, `thread/compact/start`, `thread/rollback`, `thread/name/set`, `thread/metadata/update`, `thread/turns/list`, `model/list`, `mcpServerStatus/list`, and `turn/start` are encoded through the protocol layer. |
| Typed protocol response decoding | `Shipped internally` | `initialize`, `thread/start`, `thread/list`, `thread/read`, `thread/resume`, `thread/fork`, `thread/compact/start`, `thread/rollback`, `thread/name/set`, `thread/metadata/update`, `thread/turns/list`, `model/list`, `mcpServerStatus/list`, and `turn/start` responses are decoded and validated against request IDs. |
| Typed protocol notification decoding | `Partially shipped` | The protocol layer now maps a broader batch of thread, turn, item, reasoning, hook, and reroute notifications, plus the item lifecycle needed to drive the current observable tool, MCP, file-edit, hook, and compaction summaries. |
| Public owning client actor | `Shipped` | `CodexAppServer` owns transport plus protocol and exposes startup, shutdown, initialize, thread start, and turn start. |
| Public value-typed request and result models | `Shipped` | Public API uses hand-owned Swift value types rather than exposing `CodexWire...` directly. |
| App-wide capability surfaces | `Partially shipped` | `CodexAppServer.listModels(...)` and `CodexAppServer.listMcpServerStatuses(...)` now wrap `model/list` and `mcpServerStatus/list` with hand-owned Swift models. These are connection-wide capability snapshots rather than thread-owned lifecycle actions. Broader app-wide settings and actions still need deliberate public models before promotion. |
| Initialize handshake | `Shipped` | `initialize(...)` automatically sends the follow-up `initialized` notification. |
| Thread start flow | `Shipped` | `startThread(...)` returns `CodexThread`, which carries thread metadata plus a back-reference to the shared app-server owner. |
| Stored thread list flow | `Shipped` | `listThreads(...)` wraps `thread/list`, returns typed stored-thread pages, and now reconciles local thread metadata plus explicit archived or unarchived list results back into the internal history store. |
| Stored thread read flow | `Shipped` | `readThread(...)` wraps `thread/read`, returns typed thread and turn values, and hydrates the internal history store when turns are requested. |
| Stored thread resume flow | `Shipped` | `resumeThread(...)` wraps `thread/resume`, returns a normal `CodexThread`, restores thread defaults, clears stale archived state for the reopened thread, and hydrates any resumed persisted turns into the same local history store without resetting completeness to a fresh-thread state. Callers can set `excludeTurns` when they plan to page history separately through `thread/turns/list`. |
| Stored thread fork flow | `Shipped` | `forkThread(...)` wraps `thread/fork`, returns a normal `CodexThread`, persists copied fork history into thread-scoped local turn rows, and records explicit fork lineage through the source thread id plus the last shared turn id. Callers can set `excludeTurns` when they want the fork metadata first and copied turn history through paged reads afterward. |
| Thread management actions | `Partially shipped` | `CodexThread.setName(...)` wraps `thread/name/set`, `CodexThread.updateMetadata(...)` wraps `thread/metadata/update`, and `CodexThread.rollbackLastTurns(...)` wraps `thread/rollback`. Metadata patches use an explicit replace/clear/unchanged field model so callers can express upstream null-vs-omitted semantics. Rollback reconciles visible local history to the app-server response, records a rollback marker, and now has opt-in live coverage against a disposable non-ephemeral thread, but it does not preserve full removed turn payloads as forensic archive data yet. |
| Paged turn-history flow | `Shipped` | `listThreadTurns(...)` wraps `thread/turns/list`, returns typed paged turn values, and can now seed the local history cache even before that thread has been loaded locally. |
| Typed async thread event stream | `Partially shipped` | `CodexThread.events` now streams `thread/started`, `thread/status/changed`, `thread/archived`, `thread/unarchived`, `thread/name/updated`, `thread/tokenUsage/updated`, and `thread/closed`, but broader thread lifecycle coverage is still pending. |
| Turn start flow | `Shipped` | `startTurn(...)` returns `CodexTurnHandle`. |
| Typed async turn event stream | `Partially shipped` | `CodexTurnHandle.events` now streams `turn/started`, `turn/plan/updated`, `turn/diff/updated`, item lifecycle updates, message deltas, reasoning deltas, and `turn/completed`, but broader item and thread events still remain internal. |
| Multiple active threads per app-server | `Shipped` | One `CodexAppServer` now supports many concurrently held `CodexThread` handles, and the package tests plus live probes treat cross-thread concurrency as a supported model. |
| Multiple simultaneous turns on one thread | `Resolved for now` | Live probing showed that same-thread overlap is not independently routable at the app-server layer today, so `SwiftASB` rejects overlapping same-thread turns client-side with `CodexAppServerError.invalidState`. |
| `CodexThread` convenience wrapper | `Partially shipped` | `CodexThread` exists, owns thread-scoped turn creation, includes a `startTextTurn(...)` happy-path helper, exposes a typed thread event stream, wraps `compactContext()`, and can now vend a live `Dashboard` observable mirror with aggregate tool-calling, MCP-calling, hook-run, and thread-compaction state. |
| Thread-scoped recent-turn observable | `Partially shipped` | `CodexThread.makeRecentTurns(limit:)` now vends a bounded recent-turn observable that prewarms from the local history store, supports explicit older/newer whole-turn window expansion, seeds upstream paging cursors even when the visible initial window came from local history, and falls back to `thread/turns/list` when needed. Live probing showed that upstream turn paging is available only after a non-ephemeral thread has materialized at least one user turn, so recent observable startup now degrades to an empty local-only view for the known ephemeral and pre-materialized live runtime responses instead of surfacing raw protocol text. `RecentTurns` now ships named cache-policy presets for chat UIs, full inspectors, and compact history rails; tracks both resident item counts and weighted resident item cost; slims low-value payloads out of older non-visible completed turns before evicting whole turns; rehydrates slimmed turns when they become visible again; and uses scroll-position, visibility, phase, and velocity signals to drive protected residency plus earlier prefetch. Richer weighting heuristics and deeper policy tuning are still open. |
| Thread-scoped recent-file observable | `Partially shipped` | `CodexThread.makeRecentFiles(limit:)` now vends a file-centric recent-files observable that hydrates from persisted file-change items, keeps one resident entry per file-change item, enriches live entries from `item/fileChange/outputDelta`, can load older file entries from the same turn before stepping farther back through older turns, and now supports selection-aware shell-versus-payload slimming with automatic payload rehydration for protected files. Live probing exercises a real create/edit/delete scenario, and recent-file startup now inherits the same empty local-only degradation as recent-turns for the known live history-unavailable responses. The current weighting now accounts for diff structure and line volume, and shell summaries prefer concise edit summaries over raw terminal status when sealed payload is available. The remaining open work is better payload-cost calibration at the margins and deciding whether `FileChangePatchUpdatedNotification` should enrich the observable with structured patch previews. |
| Thread-scoped recent-command observable | `Partially shipped` | `CodexThread.makeRecentCommands(limit:)` now vends a command-centric recent-commands observable that hydrates from persisted `commandExecution` items, keeps one resident entry per command item, enriches live entries from `item/commandExecution/outputDelta`, can load older command entries from the same turn before stepping farther back through older turns, and now supports selection-aware shell-versus-output slimming with automatic output rehydration for protected commands. Recent-command startup now inherits the same empty local-only degradation as recent-turns for the known live history-unavailable responses. Current output weighting accounts for output size and line structure, and shell summaries prefer concise command and output summaries over raw transport detail. The remaining open work is better output-cost calibration and sharper shell-summary heuristics. |
| Non-UI local history-reading helpers | `Partially shipped` | `CodexThread` now exposes a lightweight `HistoryWindow` page shape for recent local history, older or newer local windows around a known boundary turn id, centered `windowAroundTurn(...)` reads, centered `windowAroundItem(...)` reads, direct `ClosedTurn` reads for one turn, and convenience array helpers over those same windows. This gives non-UI callers an intentional path into the local history store without binding a UI-oriented observable, while still deferring a broader public cursor model, transcript search surface, and richer history-query helpers. |
| Public API curation | `Partially shipped` | The first source-organization pass has split app-wide model, MCP, and thread-management value types into dedicated `CodexAppServer+...` files while preserving `CodexAppServer` as the single connection-wide owner. The first DocC catalog now maps the main handles and lifecycle concepts, but more source splitting, name review, default-argument review, and source-level symbol documentation remain before v1. |
| DocC documentation | `Partially shipped` | `Sources/SwiftASB/SwiftASB.docc/` now contains a package landing page, public-handle extension pages, conceptual articles for app-wide capabilities, interactive lifecycle, thread management, history/observable companions, and generated-wire boundary notes. The catalog is validated through Xcode `docbuild`; deeper symbol comments and more examples still remain before v1. |
| Swift Package Index readiness | `Partially shipped` | `.spi.yml` declares `SwiftASB` as the documentation target so Swift Package Index can build the intended DocC catalog. The actual listing still needs confirmation after the package is publicly indexed and tagged for the release slice. |
| Contributor documentation split | `Shipped` | `README.md` is now focused on Swift and SwiftUI package users, while `CONTRIBUTING.md` owns contributor setup, validation, DocC, live-test flags, generated-wire refresh, and PR expectations. |
| `CodexTurnHandle` live observable companion | `Partially shipped` | `CodexTurnHandle` owns a live `Minimap` companion that is attached when the handle is created and maintains current-state call snapshots for command, file-edit, dynamic-tool, collab-tool, and MCP item activity. It also now mirrors whether thread context compaction is active for the turn and supports explicit `close()` handoff into a caller-owned sealed turn snapshot. |
| Additional turn event mapping | `Partially shipped` | The public event layer covers the current interactive lifecycle plus the item-start and item-complete events needed for observable call-state mirrors. Raw command-output and file-change-output deltas now stay internal as transport detail but drive the shipped `RecentCommands` and `RecentFiles` companions, and streamed payloads are preserved when later completed snapshots are thinner. Richer MCP-progress detail still remains internal, and model reroutes plus v0.124 warning and model-verification notifications are still logged or retained internally rather than exposed. |
| Server request / approval handling | `Partially shipped` | Typed approval and elicitation request models now surface on thread and turn event streams, explicit response APIs exist on `CodexThread` and `CodexTurnHandle`, and request resolution is tracked by JSON-RPC request id, but broader live coverage and more server-request families are still open. |
| Internal thread history persistence | `Partially shipped` | The package now has a Core Data-backed `ThreadHistoryStore` that persists live-built thread and turn history, hydrates stored turns from `thread/read`, `thread/resume`, `thread/fork`, and `thread/turns/list`, seeds previously unknown local threads from paged history, widens persisted turn identity to stay thread-scoped across forks, and records explicit fork lineage while preserving conservative reconciliation that keeps richer local detail when upstream stored history is thinner. Public history paging/search helpers and archive-retention policy are still open. |
| Convenience run API | `Not started` | No `run(...)` or one-shot text convenience layer yet. |
| Binary discovery and compatibility policy | `Partially shipped` | Explicit binary override exists, the docs now define a rolling support window of the latest public Codex CLI release plus the prior two minor versions, transport startup checks PATH, common Homebrew paths, and the npm global prefix on macOS, and `cliExecutableDiagnostics()` now exposes the resolved binary, version string, and documented support-window assessment. Any further diagnostics work is now expansion rather than a missing baseline surface. |
| README-level consumer docs | `Partially shipped` | The README now covers installation, runtime assumptions, a minimal usage example, an explicit `Supported Today` section, an interactive lifecycle example covering stream handling plus steering and interruption, and the current rolling Codex CLI compatibility window, but richer examples are still open. |
| End-to-end subprocess integration tests | `Partially shipped` | The package includes opt-in live Codex CLI integration tests with temp workspaces and time limits, including app-wide capability snapshots, a thread-name smoke path, same-thread concurrency probing, a best-effort live approval-path probe, approval/server-request candidate probing, a disposable live rollback scenario, and a multi-turn file-mutation scenario that creates, edits, and deletes files through the real CLI. The approval/server-request probe, file scenario, and rollback scenario can be run directly through `scripts/run-live-codex-approval-probe.sh`, `scripts/run-live-codex-file-scenario.sh`, and `scripts/run-live-codex-rollback-scenario.sh`; the first two write JSON diagnostic reports under `tmp/live-codex-reports/`. The default test suite still relies on a deterministic fake transport seam because the current runtime does not reliably force an approval request on demand. |
| FSL-1.1-ALv2 licensing | `Shipped` | The repo now carries the `FSL-1.1-ALv2` license text, README references the live license surface, and each released version converts to Apache 2.0 two years after it is first made available. |

## Milestone Progress

- Milestone 0: Package And Repo Baseline - Completed
- Milestone 1: Wire Model And Codegen Foundation - Completed
- Milestone 2: Stdio Transport And Typed Protocol Slice - Completed
- Milestone 3: Public Client Actor And First Lifecycle API - Completed
- Milestone 4: Event Streams And Ergonomic Handles - In Progress
- Milestone 5: Approvals, Richer Notifications, And Broader Protocol Coverage - In Progress
- Milestone 6: Public Docs, Examples, And Release Readiness - In Progress

## Current Maintainer Priority

The next meaningful package step is no longer proving that history hydration is
possible. That slice now exists.

The next meaningful work is no longer basic hydration or first-pass
reconciliation. That slice now exists.

The next meaningful work is to extend reconciliation into the remaining thread
management flows and then expose a deliberate public history-reading surface
without making the stored-history contract sound richer than it really is.

The package can now:

- start turns through `CodexThread`
- stream typed thread and turn progress
- answer approval and elicitation requests through typed public models
- steer an active turn
- interrupt an active turn
- mirror per-turn command, file-edit, and MCP activity through `CodexTurnHandle.Minimap.callSnapshots`
- mirror thread-level tool, MCP, hook, and compaction status through `CodexThread.Dashboard`
- read a stored thread through `thread/read`
- list stored threads through `thread/list`
- page stored turn history through `thread/turns/list`
- hydrate the internal history store from both live item streams and upstream stored-history reads
- read centered local history windows around a known turn or item through
  `windowAroundTurn(...)` and `windowAroundItem(...)`
- set thread names, patch stored Git metadata, and roll back trailing turns
  through `CodexThread`
- list app-wide model and MCP-server capability snapshots through
  `CodexAppServer`
- document the supported lifecycle in the README without sending consumers into
  the tests

That means the current priority order is:

1. Keep tuning `RecentTurns` now that the first resident-window, scroll-aware cache policy, named presets, weighted item-cost budgeting, payload-slimming path, and centered non-UI history windows are shipped. The remaining work there is better weight calibration, smarter shell-vs-payload heuristics, and deciding whether some item kinds deserve stickier retention than the current first-pass rules.
2. Keep tuning `RecentFiles` now that the first selection-aware shell-versus-payload slimming pass is shipped. The remaining work there is better payload-cost calibration at the margins and deciding whether `FileChangePatchUpdatedNotification` should enrich the observable with structured patch previews. `RecentFiles` remains a dedicated file-centric companion rather than feeding a near-term mixed activity type.
3. Keep tuning `RecentCommands` now that the first command-side shell-versus-output slimming pass is shipped. The remaining work there is better output-cost calibration and sharper shell-summary heuristics. `RecentCommands` remains a dedicated command-centric companion rather than feeding a near-term mixed activity type.
4. Keep the v0.125 additions classified before public promotion: `excludeTurns` is public on resume/fork request models because it directly supports the existing paged history model, `marketplace/upgrade` and the `amazonBedrock` account variant remain internal because SwiftASB does not yet own marketplace or account-management APIs, and the stricter tagged `permissionProfile` shape is handled by a temporary compatibility shim until the older loose shape leaves the rolling support window. The v0.124 classifications still stand: `autoReview` is public as an approval reviewer option, `model/list` and `mcpServerStatus/list` are public app-wide capability snapshots on `CodexAppServer`, `thread/name/set`, `thread/metadata/update`, and `thread/rollback` are public on `CodexThread`, hook `permissionRequest` is available for dashboard/minimap naming, and warning/model-verification/guardian action families stay internal until their consumer job is clear.
5. Do not add `RecentActivity` for v1. The separate `RecentTurns`, `RecentFiles`, and `RecentCommands` types are the clearer consumer surface, and a mixed feed would add more confusion than value right now.
6. Flesh out archive-aware retention and eviction beyond the current list-driven archive-state drift correction.
7. Add any sharper binary-discovery diagnostics we want alongside the rolling compatibility window before a first broader release.
8. Continue public API curation before v1: the first model/MCP/thread-management source split is done and the first DocC public-surface map now exists, but the package still needs more source splitting where it reduces file sprawl, tighter names and defaults, deeper source-level symbol documentation, and a final pass to make the first-class package surface feel intentionally designed rather than merely accumulated.
9. Expand DocC before v1: keep the first `SwiftASB.docc` catalog current, add deeper symbol comments where the generated documentation is too terse, add more copy-pasteable walkthroughs, and keep the Xcode `docbuild` validation path clean.
10. Re-evaluate whether the remaining Milestone 5 gaps are small enough to call this a credible first interactive lifecycle release candidate.
11. Revisit whether a convenience `run(...)` API is earned only after the lower-level lifecycle and release boundary both feel complete.

## Live App-Server Findings

The current live Codex CLI probes have found real app-server behavior that should
shape `SwiftASB` rather than stay as one-off test knowledge.

- `thread/turns/list` rejects ephemeral threads. Recent observable startup now
  treats that known response as an empty local-only initial view instead of
  surfacing raw protocol text.
- `thread/turns/list` also rejects a non-ephemeral thread before the first user
  message materializes stored thread history. Recent-turn, recent-file, and
  recent-command observable startup now treats that known response as an empty
  local-only initial view. Unexpected `thread/turns/list` failures still remain
  failures.
- Approval prompts remain nondeterministic for prompt-driven live tests. Live
  scenarios should accept approval requests when they surface, but durable
  assertions should focus on terminal turn status, observable call snapshots, and
  filesystem or history outcomes.
- Upstream Codex app-server coverage proves the JSON-RPC server-request path is
  deterministic when the model stream is controlled. Their v2 app-server tests
  trigger `CommandExecutionRequestApproval`, `FileChangeRequestApproval`,
  `PermissionsRequestApproval`, and MCP elicitation requests with a mock
  Responses provider and then answer the JSON-RPC request before waiting for
  `serverRequest/resolved`. SwiftASB should mirror that shape with a local mock
  Responses server instead of treating prompt-driven live approval behavior as
  the only possible real-CLI test path.
- For ordinary command and file-change approvals, upstream uses mocked Responses
  tool-call events such as shell command and apply-patch calls under
  `approval_policy = "untrusted"` and `sandbox_mode = "read-only"` to force
  app-server request emission. For request-permissions coverage, upstream enables
  `[features] request_permissions_tool = true` and emits a `request_permissions`
  tool call. That gives SwiftASB a reproducible protocol path while still
  launching the real installed `codex app-server`.
- SwiftASB now has opt-in real-app-server coverage for the deterministic setup
  path: an isolated `CODEX_HOME`, local mock Responses provider, command item,
  and `waitingOnApproval` thread state. The remaining gap is live delivery and
  response handling for the raw approval JSON-RPC request through SwiftASB's
  transport/public-client stack; protocol tests now require JSON-RPC response
  envelopes to include `jsonrpc = "2.0"` so the response shape is ready once the
  live delivery issue is isolated.
- `approvalPolicy: .onRequest` plus `approvalsReviewer: .user` does not force
  approval requests for workspace-write command, file-create, or file-edit
  turns in the current live runtime. The approval/server-request probe records
  those turns as completed command calls with no accepted approval kinds.
- Setting the isolated live-test Codex config and request payloads to
  `approval_policy = "untrusted"`, `approvals_reviewer = "user"`, and
  `sandbox_mode = "workspace-write"` does change behavior, but not into a clean
  typed approval flow. The command starts, no approval request is surfaced, the
  turn times out, and the app-server transport is no longer usable for follow-up
  `thread/start` calls.
- A read-only sandbox write request currently attempts the command, leaves the
  target file absent, and times out without surfacing a typed approval request or
  completion when run after the workspace-write `.onRequest` candidates. Under
  the stricter `.untrusted` probe, the app-server transport stops before the
  read-only candidate can start. Keep both as live findings while we decide
  whether SwiftASB needs a stronger timeout, blocked-call, or server-request
  validation surface for this app-server behavior.
- `scripts/run-live-codex-approval-probe.sh` is the preferred exploratory
  validation for approval/server-request candidates. It opts into the live probe
  and writes `live-approval-server-request-probe.json` under
  `tmp/live-codex-reports/` so maintainers can inspect attempted Codex config,
  observed call kinds, approval kinds, terminal text, file outcomes, and probe
  errors after a real CLI run.
- `scripts/run-live-codex-file-scenario.sh` is the preferred validation for the
  create/edit/delete path. It opts into the live file scenario and writes a JSON
  diagnostic report under `tmp/live-codex-reports/` so maintainers can inspect
  observed call kinds, approval kinds, recent-file snapshots, and recent-command
  snapshots after a real CLI run.

## Proposed Next Release Slice

Treat the next release candidate as a "first interactive lifecycle" release, not
as a convenience-API release.

### Must ship in the next slice

- Enough notification coverage that a consumer can build a multi-turn interactive flow without dropping to raw payloads.
- A unified observable current-state model for in-flight call activity and blocked thread state so UI consumers can show "what is happening right now" without replaying raw deltas themselves.
- A written release boundary that says what is public, what stays internal scaffolding, and what is intentionally unsupported.
- A maintainer-facing classification of generated notification families as public now, observable-only for now, or internal-only for now.
- The first deliberate public thread-management expansion beyond `thread/start`, with `thread/list`, `thread/read`, `thread/resume`, `thread/fork`, and `thread/turns/list` now landed.
- Version-compatibility guidance and any remaining discovery diagnostics for the local Codex CLI runtime.
- Any remaining protocol/event promotion work that is actually required to support the release boundary we claim, especially deciding how much richer tool, file-edit, and MCP detail should escape the current summary mirrors or instead feed future companion observables.
- A written and implemented boundary for recent completed turns: thread-scoped recent-turn observables for UI, plus explicit `CodexTurnHandle.close(...)` for caller-owned sealed turn values.
- Centered local history reads through `windowAroundTurn(...)` and
  `windowAroundItem(...)` before any broader cursor or transcript-search
  contract.
- A `v0.125.0` schema compatibility pass has refreshed the staging generator,
  updated the rolling compatibility window, exposed additive history-friendly
  resume/fork request flags, and covered the stricter `permissionProfile`
  generation with an explicit temporary compatibility shim.
- API curation and DocC docs good enough that a Swift consumer can understand
  the supported package surface without reading maintainer notes.

### Explicitly defer unless one of the above forces it

- A one-shot `run(...)` convenience API.
- Broader sugar beyond `startTextTurn(...)`.
- Public exposure of generated wire models.
- Expanding the public API just because the generated schema contains more message types.
- A mixed `RecentActivity` feed; keep `RecentTurns`, `RecentFiles`, and
  `RecentCommands` as separate first-class surfaces for v1.
- Treating the live approval-path probe as a deterministic release gate while the runtime repro remains non-deterministic.

### Exit signal for this slice

This slice is done when a Swift consumer can:

- start the app-server
- initialize a session
- start a thread
- start a turn
- observe meaningful thread and turn progress
- respond to approval or elicitation requests
- steer or interrupt an active turn through the public handle API
- understand, from the docs alone, which lifecycle surfaces are supported today
- understand which generated or protocol surfaces are intentionally not public yet

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
- Keep `RecentTurns`, `RecentFiles`, and `RecentCommands` as separate public
  companions. Do not add a mixed `RecentActivity` surface for v1 because it
  would blur three already-clear consumer jobs.
- Promote additional notification families by supported-release intent, not by schema breadth alone.
- Keep public lifecycle failures unified under `CodexAppServerError`.
- Defer a one-shot `run(...)` API until the lower-level interactive lifecycle is complete enough to hide honestly.
- Do not add a `CodexSession` type at this layer; the package should keep connection ownership on `CodexAppServer` and conversation ownership on `CodexThread`.
- Keep app-wide configuration, settings, and actions on `CodexAppServer` when
  they describe the shared app-server connection rather than one thread or one
  turn. `CodexAppServer.Configuration` remains local process-launch
  configuration, not a remote settings model.
- Do not add a new top-level `CodexApp`, `CodexSettings`, or app-wide session
  owner for v1. Split `CodexAppServer` source files by responsibility during
  API curation if the file size gets in the way, but preserve one
  connection-wide public owner.
- If reusable execution knobs need a shared public value type later, prefer a narrow thread-scoped shape such as `CodexThreadDefaults` instead of a new top-level owner or a vague global config wrapper.
- Treat app-level defaults as inputs to new thread creation, and treat later user changes as persisted thread-scoped overrides so one thread's settings do not silently affect another.

## Milestone 0: Package And Repo Baseline

### Status

Completed

### Scope

- [x] Establish the initial SwiftPM package, baseline guidance, and first smoke-testable public namespace.

### Tickets

- [x] Create the SwiftPM library package scaffold.
- [x] Enable Swift 6 language mode.
- [x] Add repo-local guidance for package work.
- [x] Add a minimal public namespace and smoke-test coverage.
- [x] Add root `ROADMAP.md` so project planning has a durable home.

### Exit Criteria

- [x] `swift build` passes.
- [x] `swift test` passes.

## Milestone 1: Wire Model And Codegen Foundation

### Status

Completed

### Scope

- [x] Make the bundled Codex app-server v2 schema the repeatable generated-wire source of truth while keeping generated models internal.

### Tickets

- [x] Decide that the bundled Codex app-server v2 schema is the primary generated-wire source of truth.
- [x] Build a repeatable derivation flow that turns the bundled schema into a quicktype-friendly root.
- [x] Patch dynamic JSON holes to `CodexWireJSONValue`.
- [x] Promote the generated v2 lifecycle batch into `Sources/SwiftASB/Generated/CodexWire/Latest/`.
- [x] Expand the generated v2 lifecycle batch to include a broader notification/event family rather than only the minimal bootstrap slice.
- [x] Keep `CodexWireInitializeResponse` hand-owned until the upstream v2 schema exposes it directly.

### Exit Criteria

- [x] `scripts/generate-wire-types.sh` regenerates the staged wire layer successfully.
- [x] The promoted generated v2 batch compiles cleanly with the package.
- [x] The v1 generated batch is no longer required as a promoted compiled artifact.

## Milestone 2: Stdio Transport And Typed Protocol Slice

### Status

Completed

### Scope

- [x] Build the internal subprocess transport and typed protocol helpers needed for the first initialize, thread, and turn lifecycle.

### Tickets

- [x] Implement an internal stdio transport around `codex app-server --listen stdio://`.
- [x] Correlate JSON-RPC responses by request ID.
- [x] Fan out non-response inbound messages as raw server events.
- [x] Build typed protocol helpers for `initialize`, `initialized`, `thread/start`, and `turn/start`.
- [x] Add focused tests that prove envelope classification and protocol encode/decode behavior.

### Exit Criteria

- [x] Transport and protocol layers are buildable and covered by Swift Testing suites.
- [x] Protocol errors are descriptive and carry method-specific context.
- [x] The package has a stable internal seam between transport and protocol responsibilities.

## Milestone 3: Public Client Actor And First Lifecycle API

### Status

Completed

### Scope

- [x] Expose the first hand-owned public Swift API around startup, initialize, thread start, and turn start.

### Tickets

- [x] Implement a public `CodexAppServer` actor that owns transport plus protocol.
- [x] Keep the public request and response models hand-owned and Swift-shaped.
- [x] Expose `start()`, `stop()`, `initialize(...)`, `startThread(...)`, and `startTurn(...)`.
- [x] Enforce initialize-before-thread and initialize-before-turn lifecycle guards.
- [x] Map internal transport and protocol failures into public-facing `CodexAppServerError`.
- [x] Add deterministic public-client tests using an internal fake transport seam.

### Exit Criteria

- [x] The public client can complete initialize, thread start, and turn start in tests.
- [x] The initialize handshake sends `initialized` automatically.
- [x] The public API does not expose generated `CodexWire...` types.

## Milestone 4: Event Streams And Ergonomic Handles

### Status

In Progress

### Scope

- [ ] Shape the ergonomic thread and turn handles, event streams, and observable companions that make the package usable for interactive Swift clients.

### Tickets

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

### Exit Criteria

- [x] A started turn can emit at least one typed async event through a handle-owned stream.
- [x] `CodexThread` exists as a public ergonomic wrapper with a clear ownership model.
- [x] The documented concurrency model is explicit for both cross-thread and same-thread turn starts.
- [x] The remaining open questions for Milestone 4 are narrow enough that Milestone 5 can build on the current handles without likely reshaping them again.
- [x] Thread and turn handles plus their observable companions feel like the real public surface rather than transitional wrappers.

## Milestone 5: Approvals, Richer Notifications, And Broader Protocol Coverage

### Status

In Progress

### Scope

- [ ] Promote the interactive request, richer notification, and live subprocess coverage needed for a credible first interactive lifecycle release.

### Tickets

- [x] Add typed protocol mapping for an initial batch of generated thread, turn, item, and reasoning notifications beyond `turn/completed`.
- [x] Audit the generated lifecycle batch and explicitly mark which notification families matter for the first interactive public lifecycle.
- [ ] Expand typed protocol mapping to the remaining generated notifications that matter for the first public interactive lifecycle, or deliberately classify them as companion-only or internal-only.
- [x] Decide how to surface `ThreadItem`-level activity in the public API.
  Decision: stream-first, with observable companions limited to selected latest-state mirrors for UI-oriented summaries.
- [x] Add a public model for server-originated approval and elicitation requests.
- [x] Decide whether approval handling should be callback-based, stream-based, or both.
  Decision: stream-first. Approval and elicitation requests should arrive as typed public events, with answers sent through explicit public methods on the owning surface.
- [x] Add fake-transport tests that prove approval and elicitation messages can be observed and answered through the chosen public shape.
- [x] Add opt-in live coverage for app-wide capability snapshots and a straightforward thread-management smoke path.
- [x] Add opt-in live coverage for a multi-turn file mutation scenario against the real CLI, with deterministic filesystem assertions and optional diagnostic report output.
- [x] Add opt-in live rollback coverage using a disposable thread with isolated harmless turns and explicit local rollback-marker assertions.
- [x] Add opt-in real-app-server coverage for deterministic approval setup using an isolated `CODEX_HOME`, a local mock Responses provider, and a real command item reaching `waitingOnApproval`.
- [ ] Extend deterministic approval coverage through raw request delivery, SwiftASB response handling, and the upstream-tested `serverRequest/resolved` flow.
- [x] Tighten recent-history helper behavior around live `thread/turns/list` boundaries for ephemeral and pre-materialized threads.
- [x] Add cancellation or interruption flows that are part of the intended first public lifecycle.
- [x] Revisit whether more of the generated wire graph needs to be promoted into internal compiled sources, starting with the `v0.124.0` schema additions and their public/observable/internal classification.

### Exit Criteria

- [x] The repo has a deliberate answer for where approval requests, elicitation requests, and item-level activity belong in the public model.
- [x] The public API can represent the most important server-driven lifecycle events without dropping back to raw payloads.
- [x] Approval and user-input request handling has a deliberate public model.
- [ ] The package covers a meaningful multi-turn interactive lifecycle rather than only the happy-path bootstrap, including the remaining thread-management and richer-progress gaps beyond the current observable summaries.

## Milestone 6: Public Docs, Examples, And Release Readiness

### Status

In Progress

### Scope

- [ ] Make the package understandable, verifiable, and releasable for early Swift consumers without requiring them to read generated wire code or maintainer chat history.

### Tickets

- [x] Expand `README.md` with installation, runtime assumptions, and a minimal working example.
- [x] Document the local Codex CLI dependency and explicit binary override path clearly.
- [x] Add at least one consumer-facing example for initialize, thread start, turn start, event streaming, and approval handling.
- [x] Decide on the first release boundary and what remains intentionally internal.
- [x] Add an explicit "Supported Today" section to `README.md` that mirrors the real public lifecycle and concurrency contract.
- [x] Add a maintainer-facing note that clarifies which generated notification families intentionally remain internal for now.
- [x] Add version-compatibility policy notes for the local Codex binary.
- [x] Refresh the compatibility window and promoted generated snapshot against the current `v0.124.0` schema dump once the added endpoint, notification, and field families have been classified.
- [ ] Curate the public API before v1 by splitting large source files along existing responsibility boundaries, tightening public names/defaults, and adding source-level symbol documentation for the supported lifecycle.
- [x] Add the first DocC documentation catalog before v1, including a package landing page, public-handle topic groups, and conceptual articles for the interactive lifecycle, history companions, and generated-wire boundary.
- [x] Validate the DocC catalog through Xcode `docbuild` and document the maintainer command.
- [x] Add Swift Package Index metadata that declares `SwiftASB` as the documentation target.
- [x] Split package-user documentation from contributor workflow by keeping `README.md` product-focused and adding `CONTRIBUTING.md` for package development.
- [ ] Expand DocC with deeper source-level symbol comments and more examples before a v1 tag.
- [ ] Confirm the Swift Package Index listing after the package is publicly indexed and tagged.
- [x] Decide whether real subprocess integration tests are required before the first release.
  Decision: yes, but as opt-in suites rather than as part of the default `swift test` path while the live Codex runtime remains an external local dependency.
- [x] Add an explicit source-available license for the package.

### Exit Criteria

- [x] A new consumer can understand what `SwiftASB` is, what it depends on, and how to use the first supported lifecycle slice.
- [x] The release boundary between public API, internal wire scaffolding, and unsupported protocol surfaces is explicit.
- [x] A new consumer can discover the supported interactive lifecycle, including approval handling if shipped, from docs and examples without reading tests or maintainer notes.
- [x] The roadmap can identify a credible `v0.x` release candidate instead of only an exploration phase.

## Open Tickets

- [x] Freeze the Milestone 4 handle model enough that Milestone 5 does not reopen the ownership story for `CodexAppServer`, `CodexThread`, `CodexTurnHandle`, `Dashboard`, and `Minimap`.
- [x] Audit the generated lifecycle graph and classify events as public now, observable-only for now, or internal-only for now.
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
- [x] Add centered non-UI history windows with `windowAroundTurn(...)` and `windowAroundItem(...)`.
- [x] Decide whether to add a mixed `RecentActivity` companion.
  Decision: no for v1. Keep `RecentTurns`, `RecentFiles`, and `RecentCommands` as separate, clearer public surfaces.
- [x] Classify and promote the `v0.124.0` schema changes deliberately instead of treating every additive generated type as public API.
- [x] Add API curation and DocC documentation as explicit v1-readiness work.
- [ ] Add a one-shot `run(...)` convenience API once the handle model feels stable.
- [x] Add consumer-facing examples for the supported interactive lifecycle before broadening the public API further.
- [x] Add a real subprocess-backed integration test harness once the supported event set is less volatile.
  Current shape: the repo now has an opt-in live harness for raw transport/protocol checks, public-client turn and concurrency probes, and a multi-turn real-CLI file mutation scenario with JSON report output; broader always-on subprocess coverage is still intentionally deferred.
- [x] Expand `README.md` with first-use examples and runtime expectations.
- [x] Make recent-history observables fit live app-server history availability more explicitly instead of surfacing raw `thread/turns/list` protocol errors for ephemeral or pre-materialized threads.

## Backlog Candidates

- [ ] Add a one-shot `run(...)` convenience API once the lower-level handle model is stable enough to hide honestly.
- [ ] Add a broader public history cursor or transcript search surface after the local history contract is clearer.
- [ ] Add richer MCP progress detail either as public event cases or as deeper observable companion state.
- [x] Add live rollback coverage once the disposable-thread path is reliable enough to assert explicit local rollback markers.
- [x] Add a local-only startup mode for recent history observables when live upstream paging is unavailable because the thread is ephemeral or not yet materialized.
- [ ] Confirm the Swift Package Index listing after the package is publicly indexed and tagged.

## History

- 2026-04-25: Added Xcode `docbuild` DocC validation, Swift Package Index metadata, and warning-clean DocC links.
- 2026-04-25: Split README package-user guidance from contributor workflow in `CONTRIBUTING.md`.
