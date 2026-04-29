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

## Review Checklist

### App Server Root

- [ ] Review `CodexAppServer.Configuration` defaults and naming.
- [ ] Review `CLIExecutableDiagnostics` source and compatibility vocabulary.
- [ ] Review `start()`, `stop()`, `initialize(_:)`, and lifecycle guard errors.
- [ ] Review app-wide stream semantics for `diagnostics()`.
- [ ] Review `listModels(_:)` and `listMcpServerStatuses(_:)` as app-wide
  capability surfaces.
- [ ] Review whether `CodexAppServer.swift` should keep all nested app-server
  request/result/domain values, or split more values into dedicated files.

### Thread Lifecycle And Management

- [ ] Review `ThreadStartRequest`, `ThreadResumeRequest`, and
  `ThreadForkRequest` field names, defaults, and `excludeTurns` documentation.
- [ ] Review `ThreadInfo`, `ThreadSession`, thread status types, and active flag
  vocabulary.
- [ ] Review `listThreads(_:)`, `readThread(_:)`, `resumeThread(_:)`,
  `forkThread(_:)`, and `listThreadTurns(_:)` naming and result page shapes.
- [ ] Review `CodexThread` as the owner for thread-scoped turn start, compact,
  rollback, set-name, metadata update, history reads, recent observables, and
  response routing.
- [ ] Review whether `compactThread(_:)` and `CodexThread.compactContext()`
  should share clearer naming before v1.
- [ ] Review rollback naming and document that forensic removed-turn archival is
  post-v1.
- [ ] Review metadata field-update naming for replace/clear/unchanged semantics.

### Turn Lifecycle

- [ ] Review `TurnStartRequest`, `TurnInput`, `TurnInfo`, `TurnSession`, and
  turn status vocabulary.
- [ ] Review `CodexThread.TurnRequest` versus
  `CodexAppServer.TurnStartRequest`; decide whether both names are clear enough.
- [ ] Review `CodexThread.startTurn(_:)` and `startTextTurn(...)` defaults.
- [ ] Review `CodexTurnHandle.steer(_:)`, `steerText(_:)`, `interrupt()`, and
  `close()` naming.
- [ ] Review `CodexTurnHandle.ClosedTurn` and `ClosedTurn.Item` as the sealed
  turn snapshot shape for v1.

### Streams And Events

- [ ] Review `CodexThreadEvent` case names and payload names.
- [ ] Review `CodexTurnEvent` case names and payload names.
- [ ] Confirm thread and turn streams document buffering, terminal events,
  thrown errors, and shutdown behavior consistently.
- [ ] Confirm event payload structs carry the minimal identifiers consumers need
  without requiring raw wire access.
- [ ] Review whether event names use one vocabulary for `started`, `updated`,
  `delta`, `completed`, `resolved`, and `diagnostic`.

### Interactive Requests

- [ ] Review `CodexApprovalRequest` and `CodexElicitationRequest` enum cases.
- [ ] Review command, file-change, permissions, tool-user-input, and MCP
  elicitation request field names.
- [ ] Review `CodexApprovalResponse` and `CodexElicitationResponse` response
  shapes and whether the owning answer methods are discoverable.
- [ ] Review `CodexPermissionProfile` and sandbox/network terminology against
  the public compatibility promise.
- [ ] Confirm guardian denied-action approval stays internal and post-v1.

### Diagnostics

- [ ] Review `CodexDiagnosticEvent` case names.
- [ ] Review `CodexRuntimeWarning`, `CodexGuardianWarning`,
  `CodexModelReroute`, and `CodexModelVerificationEvent` naming.
- [ ] Decide whether the public diagnostic enums should keep `unknown(String)`
  cases when current strict generated-wire decoding cannot reach them.
- [ ] Document diagnostics as passive signals, not answerable requests.

### Observable Companions And History

- [ ] Review `CodexThread.Dashboard` as the thread-level current-state mirror.
- [ ] Review `CodexTurnHandle.Minimap` as the active-turn current-state mirror.
- [ ] Review `RecentTurns`, `RecentFiles`, and `RecentCommands` names, cache
  policies, selection behavior, slimming behavior, and rehydration semantics.
- [ ] Review `HistoryWindow` naming and local-history window helper names.
- [ ] Confirm mixed `RecentActivity`, broader cursors, transcript search, and
  richer query helpers stay post-v1.
- [ ] Confirm archive-aware retention and rollback forensic archival stay
  post-v1.

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
