# V1 Public API Audit

This document is the working checklist for the `SwiftASB` v1 public API
curation pass. The goal is to freeze a compact, Swift-native surface for the
supported app-server lifecycle before `v1.0.0`, not to expose every generated
wire family.

## Current Public Source Inventory

| File | Lines | Audit focus |
| --- | ---: | --- |
| `Sources/SwiftASB/Public/CodexAppServer.swift` | 4616 | Largest public file. Split remaining request/result/domain values where that clarifies ownership; review names/defaults on app-wide, thread, turn, compatibility, and launch surfaces. |
| `Sources/SwiftASB/Public/CodexThread.swift` | 2787 | Review thread handle methods, dashboard, recent observables, history-window APIs, response routing, and whether nested observable companion types remain navigable enough for v1. |
| `Sources/SwiftASB/Public/CodexTurnHandle.swift` | 695 | Review turn-event naming, minimap shape, close-to-snapshot surface, steering/interrupt names, and public event payload values. |
| `Sources/SwiftASB/Public/CodexInteractiveRequests.swift` | 501 | Review approval and elicitation naming, request/response ownership, unknown action surfaces, permission-profile naming, and response defaults. |
| `Sources/SwiftASB/Public/CodexDiagnostics.swift` | 158 | Review diagnostic event naming, model reroute/verification vocabulary, and future-proofing for unknown wire values. |
| `Sources/SwiftASB/Public/CodexAppServer+MCP.swift` | 157 | Review app-wide MCP capability snapshot names and `JSONValue` exposure in MCP metadata/schema fields. |
| `Sources/SwiftASB/Public/CodexAppServer+Models.swift` | 120 | Review model-list names, pagination naming, and whether account/marketplace-adjacent fields stay intentionally absent. |
| `Sources/SwiftASB/Public/CodexAppServer+ThreadManagement.swift` | 104 | Review thread set-name, metadata update, rollback request/result names, and null/omitted field terminology. |
| `Sources/SwiftASB/Public/CodexErrors.swift` | 45 | Review public error cases, wording, and whether stream failures consistently wrap transport/protocol causes. |

## V1 Surface Promise

The v1 public promise is the supported interactive lifecycle:

- process launch, initialization, and CLI executable diagnostics through
  `CodexAppServer`
- app-wide model and MCP capability snapshots
- stored thread list/read/resume/fork plus paged turn history
- thread start, turn start, turn steering, interruption, completion handoff, and
  same-thread overlap rejection
- typed thread and turn event streams
- approval and elicitation request handling through typed request and response
  values
- passive runtime diagnostics through hand-owned public diagnostic types
- local history hydration plus recent-turn, recent-file, and recent-command
  observable companions
- selected thread management actions: compact, set name, metadata update, and
  rollback

Generated wire models remain internal scaffolding. App-server feature families
that do not support the v1 lifecycle stay post-v1 unless a concrete consumer
workflow reclassifies them before the v1 API freeze.

## Audit Classifications

Use these decisions for every public symbol:

- `Stable for v1`: name, owner, default behavior, and docs can be frozen.
- `Rename before v1`: behavior is right, but the spelling or labels are not.
- `Move or split before v1`: behavior is right, but the current file or owner
  makes the API hard to navigate.
- `Make internal before v1`: symbol is not part of the v1 promise.
- `Docs required before v1`: symbol can remain public, but needs symbol
  comments or an example before the release.
- `Post-v1`: useful, but deliberately outside the v1 promise.

## First-Pass Decisions

### Stable For V1

- Keep `CodexAppServer` as the root owner for process launch, initialization,
  app-wide capability reads, stored thread access, and low-level thread/turn
  entrypoints. Consumers need one object that owns the local app-server process
  and translates app-server protocol events into Swift values.
- Keep `CodexThread` as the thread-scoped handle. It should remain the consumer
  surface for starting turns, responding to interactive requests, reading local
  turn history, compacting context, rolling back recent turns, naming the
  thread, updating metadata, and creating SwiftUI-friendly observable
  companions.
- Keep `CodexTurnHandle` as the active-turn handle. It should remain the
  consumer surface for turn events, steering, interruption, request responses,
  and closing an active turn into a sealed local-history snapshot.
- Keep approval and elicitation as typed public request/response values. The
  generated JSON-RPC request identifier stays internal; consumers answer by
  passing the request object back with the typed response.
- Keep diagnostics as passive public signals. `warning`, `guardianWarning`,
  `modelRerouted`, and `modelVerification` are observable events, not
  answerable control requests.
- Keep generated `CodexWire...` models out of the public API promise. Public
  examples and DocC should show only hand-owned SwiftASB values.
- Keep richer activity, file-diff, MCP-progress, account-management,
  marketplace, transcript-search, and external-agent configuration surfaces
  post-v1.

### Move Or Split Before V1

- Split `CodexAppServer.swift` by consumer-facing responsibility without
  changing ownership or behavior. This is file organization only, not a new
  abstraction. The target split should make startup, thread lifecycle, turn
  lifecycle, compatibility/configuration values, JSON support, and private
  protocol conversions easier to review independently.
- Split `CodexThread.swift` by consumer-facing responsibility without changing
  ownership or behavior. Keep the handle and action methods in the root file,
  then move dashboard, recent turns, recent files, recent commands, history
  windows, and thread event payloads into focused sibling files.
- Keep `CodexInteractiveRequests.swift` as one public conceptual area for now,
  but split it only if symbol comments and examples still leave it hard to
  scan. The approval/elicitation model is a single consumer job: inspect the
  request, choose a typed answer, and send it through the thread or turn handle.

### Rename Or Clarify Before V1

- Rename or alias `CodexAppServer.diagnostics()` before v1. It returns an
  `AsyncThrowingStream<CodexDiagnosticEvent, Error>`, so `diagnosticEvents()`
  or `diagnosticsStream()` would better communicate that consumers are
  subscribing to future events rather than reading a snapshot.
- Decide whether `CodexModelVerificationEvent` should become
  `CodexModelVerificationDiagnostic`. The current name is technically true,
  but it is a payload nested inside `CodexDiagnosticEvent.modelVerification`,
  which makes `Event` read redundant at the call site.
- Keep `CodexThread.TurnRequest` only if the scoped call
  `thread.startTurn(.init(...))` remains clear in examples. If examples need to
  mention both `CodexThread.TurnRequest` and `CodexAppServer.TurnStartRequest`,
  rename the thread-scoped value before v1.
- Keep `CodexThread.compactContext()` and `CodexAppServer.compactThread(_:)` as
  the likely final pair: the thread handle uses the user-facing job name, while
  the app-server root keeps the protocol-shaped lower-level action name.
- Document `CodexTurnHandle.close()` precisely. It reads the completed turn into
  a local `ClosedTurn` snapshot; it does not send a server-side "close this
  running turn" command.
- Decide whether `CodexTurnHandle.minimap` and `makeMinimap()` should both stay.
  If both remain, docs should explain that the property creates a live companion
  from the current handle state, while the async method gives symmetry with
  `CodexThread.makeDashboard()`.

### API Honesty Fixes Before V1

- Remove or make reachable the public diagnostic `unknown(String)` cases in
  `CodexModelReroute.Reason` and `CodexModelVerification`. They currently imply
  forward-compatible decoding, but strict generated-wire enum decoding cannot
  reach them. Either the generated-wire mapping must preserve unknown raw
  values, or the public cases should be removed until that behavior exists.
- Fix spelling before v1 in
  `CodexCommandExecutionApprovalRequest.proposedExecpolicyAmendment`; if the
  public API keeps that field, use `proposedExecPolicyAmendment` or a clearer
  domain name.
- Format and review compact one-line public declarations such as
  `CodexPermissionsApprovalResponse.Scope`. V1 public declarations should be
  easy to read in generated docs.
- Review every public `JSONValue` exposure and keep it only where the upstream
  app-server payload is genuinely dynamic, such as output schemas, MCP metadata,
  MCP elicitation content, and unknown structured context.

### Docs Required Before Freeze

- Document stream behavior for thread events, turn events, diagnostics, recent
  observable companions, buffering, terminal events, thrown errors, and shutdown.
- Document `excludeTurns` on resume/fork in consumer terms: which previous
  turns are hidden from the resumed or forked context and what that means for
  local history reads.
- Document recent observable companion cache policies, selection behavior,
  slimming behavior, and rehydration. Consumers should understand when a value
  is a resident snapshot versus a history read.
- Document rollback as app-server state change only; forensic removed-turn
  archival remains post-v1.
- Document the compatibility-shim policy in the v1 docs: every temporary shim
  needs an owning upstream behavior, a support-window reason, a removal trigger,
  and a cleanup issue or roadmap entry.

## Review Checklist

### App Server Root

- [x] Review `CodexAppServer.Configuration` defaults and naming.
  Decision: stable conceptually for v1; keep final naming review with symbol
  comments and startup examples.
- [x] Review `CLIExecutableDiagnostics` source and compatibility vocabulary.
  Decision: stable as a diagnostic support surface; keep it app-root owned.
- [x] Review `start()`, `stop()`, `initialize(_:)`, and lifecycle guard errors.
  Decision: stable ownership; docs still need to explain the expected startup
  order and thrown lifecycle failures.
- [x] Review app-wide stream semantics for `diagnostics()`.
  Decision: the stream is stable, but the method name should change or gain an
  explicitly stream-shaped alias before v1.
- [x] Review `listModels(_:)` and `listMcpServerStatuses(_:)` as app-wide
  capability surfaces.
  Decision: keep app-wide, snapshot-style capability reads public.
- [x] Review whether `CodexAppServer.swift` should keep all nested app-server
  request/result/domain values, or split more values into dedicated files.
  Decision: split by responsibility before v1; do not introduce new owners.

### Thread Lifecycle And Management

- [x] Review `ThreadStartRequest`, `ThreadResumeRequest`, and
  `ThreadForkRequest` field names, defaults, and `excludeTurns` documentation.
  Decision: keep the request families public; `excludeTurns` needs docs before
  freeze.
- [x] Review `ThreadInfo`, `ThreadSession`, thread status types, and active flag
  vocabulary.
  Decision: stable enough for the v1 lifecycle; complete symbol comments before
  freeze.
- [x] Review `listThreads(_:)`, `readThread(_:)`, `resumeThread(_:)`,
  `forkThread(_:)`, and `listThreadTurns(_:)` naming and result page shapes.
  Decision: stable app-root low-level actions.
- [x] Review `CodexThread` as the owner for thread-scoped turn start, compact,
  rollback, set-name, metadata update, history reads, recent observables, and
  response routing.
  Decision: keep `CodexThread` as the high-level consumer handle.
- [x] Review whether `compactThread(_:)` and `CodexThread.compactContext()`
  should share clearer naming before v1.
  Decision: keep this pair unless examples prove confusing; app-root protocol
  naming and thread-handle user wording can differ.
- [x] Review rollback naming and document that forensic removed-turn archival is
  post-v1.
  Decision: rollback stays public; forensic archival stays post-v1 and must be
  documented.
- [ ] Review metadata field-update naming for replace/clear/unchanged semantics.

### Turn Lifecycle

- [x] Review `TurnStartRequest`, `TurnInput`, `TurnInfo`, `TurnSession`, and
  turn status vocabulary.
  Decision: stable as the app-root turn entrypoint.
- [x] Review `CodexThread.TurnRequest` versus
  `CodexAppServer.TurnStartRequest`; decide whether both names are clear enough.
  Decision: conditional; keep only if examples remain clear without extra
  explanation.
- [x] Review `CodexThread.startTurn(_:)` and `startTextTurn(...)` defaults.
  Decision: stable consumer-facing conveniences.
- [x] Review `CodexTurnHandle.steer(_:)`, `steerText(_:)`, `interrupt()`, and
  `close()` naming.
  Decision: keep steering and interruption names; document `close()` snapshot
  semantics before freeze.
- [x] Review `CodexTurnHandle.ClosedTurn` and `ClosedTurn.Item` as the sealed
  turn snapshot shape for v1.
  Decision: stable as the local-history shape.

### Streams And Events

- [x] Review `CodexThreadEvent` case names and payload names.
  Decision: stable vocabulary for v1.
- [x] Review `CodexTurnEvent` case names and payload names.
  Decision: stable vocabulary for v1.
- [ ] Confirm thread and turn streams document buffering, terminal events,
  thrown errors, and shutdown behavior consistently.
- [x] Confirm event payload structs carry the minimal identifiers consumers need
  without requiring raw wire access.
  Decision: current payloads carry thread/turn/item identifiers where consumers
  need to route updates.
- [x] Review whether event names use one vocabulary for `started`, `updated`,
  `delta`, `completed`, `resolved`, and `diagnostic`.
  Decision: keep current event vocabulary; docs should describe stream roles,
  not rename the event families.

### Interactive Requests

- [x] Review `CodexApprovalRequest` and `CodexElicitationRequest` enum cases.
  Decision: stable split; approval changes execution permissions, elicitation
  gathers user/MCP input.
- [x] Review command, file-change, permissions, tool-user-input, and MCP
  elicitation request field names.
  Decision: mostly stable, with `proposedExecpolicyAmendment` requiring a
  spelling/naming fix before v1.
- [x] Review `CodexApprovalResponse` and `CodexElicitationResponse` response
  shapes and whether the owning answer methods are discoverable.
  Decision: stable paired request/response model; examples should teach
  `thread.respond(...)` and `turn.respond(...)`.
- [x] Review `CodexPermissionProfile` and sandbox/network terminology against
  the public compatibility promise.
  Decision: stable enough for v1, but symbol comments should define omitted
  values versus denied access.
- [x] Confirm guardian denied-action approval stays internal and post-v1.
  Decision: keep it out of v1 until a real answerable guardian-control flow is
  designed.

### Diagnostics

- [x] Review `CodexDiagnosticEvent` case names.
  Decision: stable passive event family.
- [x] Review `CodexRuntimeWarning`, `CodexGuardianWarning`,
  `CodexModelReroute`, and `CodexModelVerificationEvent` naming.
  Decision: warning/reroute names are stable; decide whether to rename
  `CodexModelVerificationEvent` before v1.
- [x] Decide whether the public diagnostic enums should keep `unknown(String)`
  cases when current strict generated-wire decoding cannot reach them.
  Decision: do not keep unreachable public unknown cases. Either wire decoding
  must preserve unknown values, or the cases should be removed before v1.
- [x] Document diagnostics as passive signals, not answerable requests.
  Decision: passive-only stays part of the v1 promise; detailed user docs still
  need to be written.

### Observable Companions And History

- [x] Review `CodexThread.Dashboard` as the thread-level current-state mirror.
  Decision: stable SwiftUI companion.
- [x] Review `CodexTurnHandle.Minimap` as the active-turn current-state mirror.
  Decision: stable SwiftUI companion; review duplicate construction surface.
- [x] Review `RecentTurns`, `RecentFiles`, and `RecentCommands` names, cache
  policies, selection behavior, slimming behavior, and rehydration semantics.
  Decision: stable concepts; docs required for cache and rehydration behavior.
- [x] Review `HistoryWindow` naming and local-history window helper names.
  Decision: stable enough for v1; examples should show ordinary recent/older/
  newer reads.
- [x] Confirm mixed `RecentActivity`, broader cursors, transcript search, and
  richer query helpers stay post-v1.
  Decision: post-v1.
- [x] Confirm archive-aware retention and rollback forensic archival stay
  post-v1.
  Decision: post-v1.

### Documentation Requirements

- [ ] Add symbol comments for every stable v1 public type and method that is not
  self-explanatory from its declaration.
- [ ] Add DocC examples for app-server startup, thread/turn start, progress
  observation, approval response, diagnostics, recent history, and SwiftUI
  observable companions.
- [ ] Update stale README release references before the next release.
- [ ] Confirm README, DocC, and this audit use the same v1 release boundary.

## Initial Risk Notes

- `CodexAppServer.swift` is the highest navigation risk because it still mixes
  root actor behavior, many nested public request/result models, compatibility
  enums, internal fanout, history reconciliation, and private conversion
  helpers in one file.
- `CodexThread.swift` is the second-highest navigation risk because it owns
  thread actions, dashboard, recent-turn/file/command observables, history
  window helpers, and many thread event payloads.
- `CodexInteractiveRequests.swift` should get a careful naming pass because
  approval and elicitation APIs are part of the v1 promise and will be expensive
  to rename after the v1 tag.
- `CodexDiagnostics.swift` intentionally exposes passive signals. It should not
  grow answerable guardian-control APIs without a separate post-v1 design pass.
- The generated-wire boundary is already clear in principle, but every public
  API example should be checked so it never teaches consumers to depend on
  `CodexWire...` types.
