# V1 Public API Audit

This document is the working checklist for the `SwiftASB` v1 public API
curation pass. The goal is to freeze a compact, Swift-native surface for the
supported app-server lifecycle before `v1.0.3`, not to expose every generated
wire family.

## Current Public Source Inventory

The source inventory below tracks the files that own hand-shaped public API.
The generated symbol ledger for this pass lives in
[`v1-public-api-symbol-inventory.md`](./v1-public-api-symbol-inventory.md).
That ledger was generated from SwiftPM's public symbol graph after the v0.128
generated-wire promotion and final pre-v1 public-surface tightening. It
currently records 1,107 public/open symbols: 169 types, 71 initializers, 60
methods or type methods, 224 enum cases, and 583 properties.

| File | Lines | Audit focus |
| --- | ---: | --- |
| `Sources/SwiftASB/Public/CodexAppServer.swift` | 4062 | Root actor runtime, transport lifecycle, event fanout, local history reconciliation, stream registration, and protocol conversion internals. |
| `Sources/SwiftASB/Public/CodexThread+RecentTurns.swift` | 749 | Recent-turn observable companion and turn-snapshot conversion helpers. |
| `Sources/SwiftASB/Public/CodexThread+RecentFiles.swift` | 718 | Recent-file observable companion and file-snapshot conversion helpers. |
| `Sources/SwiftASB/Public/CodexThread+RecentCommands.swift` | 683 | Recent-command observable companion and command-snapshot conversion helpers. |
| `Sources/SwiftASB/Public/CodexTurnHandle.swift` | 704 | Review turn-event naming, minimap shape, completion snapshot surface, steering/interrupt names, and public event payload values. |
| `Sources/SwiftASB/Public/CodexInteractiveRequests.swift` | 526 | Review approval and elicitation naming, request/response ownership, unknown action surfaces, permission-profile naming, and response defaults. |
| `Sources/SwiftASB/Public/CodexThread.swift` | 543 | Thread handle, history-window type, turn-start request, thread-scoped actions, and public thread event payloads. |
| `Sources/SwiftASB/Public/CodexAppServer+ThreadLifecycle.swift` | 334 | Thread start/resume/fork/list/read/turn-page request and result values. |
| `Sources/SwiftASB/Public/CodexThread+Dashboard.swift` | 224 | Thread-level SwiftUI dashboard companion. |
| `Sources/SwiftASB/Public/CodexDiagnostics.swift` | 156 | Review diagnostic event naming, model reroute/verification vocabulary, and future-proofing for unknown wire values. |
| `Sources/SwiftASB/Public/CodexAppServer+MCP.swift` | 162 | Review app-wide MCP capability snapshot names and `JSONValue` exposure in MCP metadata/schema fields. |
| `Sources/SwiftASB/Public/CodexAppServer+Models.swift` | 125 | Review model-list names, pagination naming, and whether account/marketplace-adjacent fields stay intentionally absent. |
| `Sources/SwiftASB/Public/CodexAppServer+Compatibility.swift` | 117 | Compatibility enums, sandbox/approval/reasoning vocabulary, and public `JSONValue`. |
| `Sources/SwiftASB/Public/CodexAppServer+ThreadManagement.swift` | 111 | Review thread set-name, metadata update, rollback request/result names, and null/omitted field terminology. |
| `Sources/SwiftASB/Public/CodexAppServer+Bootstrap.swift` | 116 | CLI diagnostics, launch configuration, initialization request/session values. |
| `Sources/SwiftASB/Public/CodexAppServer+TurnLifecycle.swift` | 100 | Turn start request/session/info/input values. |
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
  and completing an active turn into a sealed local-history snapshot.
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
- Connected owner review: keep the v1 surface centered on three owners.
  `CodexAppServer` owns subprocess lifetime, initialization, app-wide
  capability reads, and lower-level stored-thread operations. `CodexThread`
  owns conversation-scoped work: starting turns, thread management, request
  routing, local history, and thread-scoped observable companions.
  `CodexTurnHandle` owns active-turn control, live turn events, minimap state,
  and explicit completion into a sealed local-history snapshot.

### Move Or Split Before V1

- `CodexAppServer.swift` has been split by consumer-facing responsibility
  without changing ownership or behavior. Startup/bootstrap values,
  thread-lifecycle values, turn-lifecycle values, and compatibility values now
  live in focused sibling files; the root actor file keeps runtime behavior,
  event fanout, local history reconciliation, stream registration, and private
  protocol conversion internals.
- `CodexThread.swift` has been split by consumer-facing responsibility without
  changing ownership or behavior. The root file keeps the thread handle,
  history-window type, thread-scoped actions, and thread event payloads, while
  dashboard, recent turns, recent files, and recent commands live in focused
  sibling files.
- Keep `CodexInteractiveRequests.swift` as one public conceptual area for now,
  but split it only if symbol comments and examples still leave it hard to
  scan. The approval/elicitation model is a single consumer job: inspect the
  request, choose a typed answer, and send it through the thread or turn handle.

### Rename Or Clarify Before V1

- `CodexAppServer.diagnostics()` has been renamed to
  `CodexAppServer.diagnosticEvents()` so consumers can see that they are
  subscribing to future events rather than reading a snapshot.
- `CodexModelVerificationEvent` has been renamed to
  `CodexModelVerificationDiagnostic` because it is a payload nested inside
  `CodexDiagnosticEvent.modelVerification`, where the `Event` suffix reads
  redundant at the call site.
- `CodexThread.TurnStartRequest` is the thread-scoped turn-start value so it
  matches the app-root turn-start job name.
- Keep `CodexThread.compactContext()` and `CodexAppServer.compactThread(_:)` as
  the likely final pair: the thread handle uses the user-facing job name, while
  the app-server root keeps the protocol-shaped lower-level action name.
- `CodexTurnHandle.complete()` reads the completed turn into a local
  `ClosedTurn` snapshot; it does not send a server-side command to terminate a
  running turn.
- `CodexTurnHandle.minimap` is the single public minimap surface. The
  removed method spelling is intentionally absent before v1 so consumers do not
  need to choose between two spellings for the same live companion.

### API Honesty Fixes Before V1

- Remove stale public placeholders that are not part of the supported consumer
  lifecycle. The package-template `SwiftASB` namespace enum is no longer public;
  consumers should depend on the concrete owners `CodexAppServer`,
  `CodexThread`, and `CodexTurnHandle` instead.
- Keep app-server-authored interactive request payload values readable without
  making every nested payload constructible. Command-action payloads,
  tool-user-input question payloads, and MCP elicitation prompt payloads are
  now internally constructed from app-server requests; response values remain
  public-initializable where consumers need to answer.
- Keep passive diagnostic payloads readable through `CodexDiagnosticEvent`
  without giving them public constructors. This matches the broader event model:
  SwiftASB creates app-server-originated events, while consumers inspect them.
- Keep model-list public fields scoped to picker and capability needs.
  Marketplace-adjacent model upgrade fields are decoded by the internal wire
  layer but are no longer copied into the public `CodexAppServer.Model` shape
  for v1.
- The unreachable public diagnostic `unknown(String)` cases have been removed
  from `CodexModelReroute.Reason` and `CodexModelVerification`. Strict
  generated-wire enum decoding cannot reach them today, so keeping them would
  overstate the package's forward-compatibility behavior.
- `CodexCommandExecutionApprovalRequest.proposedExecpolicyAmendment` has been
  corrected to `proposedExecPolicyAmendment` on the public API surface while
  still mapping from the current generated-wire spelling internally.
- `CodexCommandExecutionApprovalResponse.acceptWithExecpolicyAmendment(_:)`
  has been corrected to `acceptWithExecPolicyAmendment(_:)` on the public API
  surface for the same reason. The private protocol decision type still uses
  the app-server's `acceptWithExecpolicyAmendment` wire spelling and
  `execpolicy_amendment` payload key so existing Codex app-server builds keep
  accepting the response.
- Compact one-line public declarations such as
  `CodexPermissionsApprovalResponse.Scope` should remain expanded for generated
  docs readability.
- Review every public `JSONValue` exposure and keep it only where the upstream
  app-server payload is genuinely dynamic, such as output schemas, MCP metadata,
  MCP elicitation content, and unknown structured context.

### Field, Default, And Enum Vocabulary Review

- Field names should stay Swift-native where SwiftASB owns the public shape and
  preserve app-server terms only when the consumer is choosing a real Codex
  option. Identifier fields such as `threadID`, `turnID`, `itemID`, and
  `requestID` are stable; route and filesystem fields such as
  `currentDirectoryPath` are stable because they describe the caller input
  rather than the wire spelling.
- Compatibility fields that mirror upstream behavior should keep the Codex
  vocabulary but use normal Swift casing. The execution-policy approval pair is
  the current example: public request/response values use
  `proposedExecPolicyAmendment` and `acceptWithExecPolicyAmendment(_:)`, while
  private conversion code preserves the upstream wire spelling.
- Default arguments should be treated as compatibility promises. Current
  defaults are mostly nil/pass-through values, local cache policies, pagination
  limits, binary discovery behavior, and
  `CodexPermissionsApprovalResponse.scope = .turn`; the v1 source-comment pass
  now documents whether SwiftASB or the Codex app-server owns those defaults.
  The first default-argument documentation pass covers the main public defaults:
  process launch configuration, initialization capabilities, thread and turn
  request omissions, model/MCP/thread pagination requests, metadata field
  updates, permission responses, local history page sizes, and recent observable
  companion cache policies.
- Enum vocabulary should favor stable SwiftASB jobs over generated-wire terms.
  Keep public app-server option names such as `dangerFullAccess`, `xhigh`,
  `oAuth`, and `nux` only where the value is an upstream option a caller may
  already recognize from Codex configuration or CLI output.
- Public dynamic JSON fields remain acceptable only for genuinely open
  app-server payloads: MCP metadata, output schemas, elicitation content, and
  unknown structured context. They should not become a shortcut around typed
  public modeling for the supported lifecycle.

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
  Decision: stable ownership. Startup order is covered by README and DocC
  walkthroughs; thrown lifecycle failures stay under `CodexAppServerError`.
- [x] Review app-wide stream semantics for `diagnosticEvents()`.
  Decision: the stream is stable and now uses the stream-shaped
  `diagnosticEvents()` name.
- [x] Review `listModels(_:)` and `listMcpServerStatuses(_:)` as app-wide
  capability surfaces.
  Decision: keep app-wide, snapshot-style capability reads public.
- [x] Review whether `CodexAppServer.swift` should keep all nested app-server
  request/result/domain values, or split more values into dedicated files.
  Decision: split by responsibility before v1; no new owners were introduced.

### Thread Lifecycle And Management

- [x] Review `ThreadStartRequest`, `ThreadResumeRequest`, and
  `ThreadForkRequest` field names, defaults, and `excludeTurns` documentation.
  Decision: keep the request families public. `excludeTurns` is documented as a
  metadata-first option for callers that plan to page or read history
  separately.
- [x] Review `ThreadInfo`, `ThreadSession`, thread status types, and active flag
  vocabulary.
  Decision: stable enough for the v1 lifecycle; remaining documentation work is
  a targeted symbol-comment skim, not an ownership or naming blocker.
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
- [x] Review metadata field-update naming for replace/clear/unchanged semantics.
  Decision: keep the explicit replace/clear/unchanged names for v1 because they
  describe the upstream null-versus-omitted semantics clearly at the call site.

### Turn Lifecycle

- [x] Review `TurnStartRequest`, `TurnInput`, `TurnInfo`, `TurnSession`, and
  turn status vocabulary.
  Decision: stable as the app-root turn entrypoint.
- [x] Review `CodexThread.TurnStartRequest` versus
  `CodexAppServer.TurnStartRequest`; decide whether both names are clear enough.
  Decision: rename the thread-scoped request to `TurnStartRequest`.
- [x] Review `CodexThread.startTurn(_:)` and `startTextTurn(...)` defaults.
  Decision: stable consumer-facing conveniences.
- [x] Review `CodexTurnHandle.steer(_:)`, `steerText(_:)`, `interrupt()`, and
  `complete()` naming.
  Decision: keep steering and interruption names; use `complete()` for the
  completed-snapshot handoff before freeze.
- [x] Review `CodexTurnHandle.ClosedTurn` and `ClosedTurn.Item` as the sealed
  turn snapshot shape for v1.
  Decision: stable as the local-history shape.

### Streams And Events

- [x] Review `CodexThreadEvent` case names and payload names.
  Decision: stable vocabulary for v1.
- [x] Review `CodexTurnEvent` case names and payload names.
  Decision: stable vocabulary for v1.
- [x] Confirm thread and turn streams document buffering, terminal events,
  thrown errors, and shutdown behavior consistently.
  Decision: documented. Thread streams buffer unobserved thread events and yield
  terminal events before finishing. Turn streams buffer only the early
  active-turn events SwiftASB marks for pre-observation delivery plus terminal
  completion. Diagnostic streams buffer until the first subscriber. Observable
  companions are current-state mirrors; internal activity and delta feeds are
  live-only rather than replayable event logs.
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
  Decision: mostly stable; `proposedExecPolicyAmendment` now uses the corrected
  public spelling.
- [x] Review `CodexApprovalResponse` and `CodexElicitationResponse` response
  shapes and whether the owning answer methods are discoverable.
  Decision: stable paired request/response model; examples should teach
  `thread.respond(...)` and `turn.respond(...)`. The command execution response
  case now uses the corrected public spelling
  `acceptWithExecPolicyAmendment(_:)`; private protocol conversion keeps the
  current app-server wire spelling.
- [x] Review `CodexPermissionProfile` and sandbox/network terminology against
  the public compatibility promise.
  Decision: stable enough for v1. Source comments now define omitted values
  versus denied access where those distinctions are part of the public
  compatibility promise.
- [x] Confirm guardian denied-action approval stays internal and post-v1.
  Decision: keep it out of v1 until a real answerable guardian-control flow is
  designed.

### Diagnostics

- [x] Review `CodexDiagnosticEvent` case names.
  Decision: stable passive event family.
- [x] Review `CodexRuntimeWarning`, `CodexGuardianWarning`,
  `CodexModelReroute`, and `CodexModelVerificationDiagnostic` naming.
  Decision: warning/reroute names are stable; model verification now uses the
  `CodexModelVerificationDiagnostic` payload name.
- [x] Decide whether the public diagnostic enums should keep `unknown(String)`
  cases when current strict generated-wire decoding cannot reach them.
  Decision: do not keep unreachable public unknown cases. They have been
  removed until wire decoding can preserve unknown raw values.
- [x] Document diagnostics as passive signals, not answerable requests.
  Decision: passive-only stays part of the v1 promise. README and DocC now
  teach diagnostics as observable signals rather than control requests.

### Observable Companions And History

- [x] Review `CodexThread.Dashboard` as the thread-level current-state mirror.
  Decision: stable SwiftUI companion.
- [x] Review `CodexTurnHandle.Minimap` as the active-turn current-state mirror.
  Decision: stable SwiftUI companion; keep the `minimap` property as the single
  construction and observation surface.
- [x] Review `RecentTurns`, `RecentFiles`, and `RecentCommands` names, cache
  policies, selection behavior, slimming behavior, and rehydration semantics.
  Decision: stable for v1. Keep the three separate companion families, keep
  `RecentTurns` presets plus automatic page-size-derived file/command policies,
  keep caller-owned selection and visible-ID hints as the public UI input
  surface, and keep slimming/rehydration as cache-residency behavior. Unsafe
  numeric cache-policy inputs are normalized consistently across all three
  companion families.
- [x] Review `HistoryWindow` naming and local-history window helper names.
  Decision: stable enough for v1; examples should show ordinary recent/older/
  newer reads.
- [x] Confirm mixed `RecentActivity`, broader cursors, transcript search, and
  richer query helpers stay post-v1.
  Decision: post-v1.
- [x] Confirm archive-aware retention and rollback forensic archival stay
  post-v1.
  Decision: post-v1.

### Access Control Tightening

- [x] Remove stale public placeholder namespaces.
  Decision: the template-era `SwiftASB` enum is not a consumer API and is no
  longer public.
- [x] Review public observable companion state for accidental construction or
  mutation surfaces.
  Decision: `Dashboard.ActivityState` and companion initializers are internal.
  Dashboard, minimap, recent-turn, recent-file, and recent-command presentation
  properties remain public read-only or `public private(set)` as appropriate for
  SwiftUI observation. The remaining mutable public companion fields are
  caller-owned UI inputs such as selection, scroll position, visible IDs, and
  scroll activity.
- [x] Review request and response values for public constructor needs.
  Decision: caller-authored request, configuration, and response values keep
  public initializers. App-server-authored pages, snapshots, request roots,
  command actions, tool-user-input questions, MCP elicitation prompt payloads,
  diagnostics, model-list upgrade details, and observable companion snapshots
  stay readable without public construction unless examples or tests later prove
  that ability is necessary.
- [x] Review passive diagnostic payload construction.
  Decision: diagnostic payload structs stay public and readable, but their
  constructors are internal because consumers observe diagnostics rather than
  emitting them through SwiftASB.
- [x] Review marketplace-adjacent model-list fields.
  Decision: `Model.upgrade`, `Model.upgradeInfo`, and `ModelUpgradeInfo` are
  not part of the v1 model-picker promise. Keep the generated wire fields
  internal until SwiftASB owns a public marketplace or upgrade workflow.
- [x] Regenerate the symbol inventory after this access-control tightening pass.
  Decision: the ledger now records 1,107 exported public/open symbols after the
  placeholder, request-payload constructor, diagnostic-constructor,
  marketplace-adjacent model-field narrowing, and v0.128 sandbox-field cleanup.
  The post-v1 model-capabilities addition updates that same ledger to 1,112
  exported public/open symbols while preserving the v1 ownership boundary.

### Documentation Requirements

- [x] Add symbol comments for every stable v1 public type and method that is not
  self-explanatory from its declaration.
  Decision: complete for the `v1.0.3` release boundary. Default-bearing public
  initializers and methods now document whether omission delegates to Codex,
  chooses a SwiftASB local-history/UI default, or applies an explicit safety
  default such as `.turn` or `.unchanged`. The source-level pass also covers the
  supported lifecycle entrypoints on `CodexAppServer`, `CodexThread`, and
  `CodexTurnHandle`, plus the stable public value types for model, MCP,
  thread-management, approval, elicitation, diagnostics, compatibility, and
  app-server bootstrap surfaces. Future symbol-comment work is ordinary ongoing
  docs refinement as the public API grows, not unfinished pre-v1 release work.
- [x] Record the first post-v1 query descriptor addition.
  Decision: `CodexAppServer.ThreadListQD` is the public thread-list descriptor
  for direct app-server reads and app-wide library loading. `CodexThread.HistoryWindowQD`
  is the public local completed-turn window descriptor for recent, older, newer,
  turn-centered, and item-centered reads. Both keep descriptor intent in
  SwiftASB-owned values instead of exposing Core Data fetch requests, SwiftData
  queries, or generated wire models.
- [x] Record the first post-v1 app-server filesystem promotion.
  Decision: `CodexFS` is the public namespace for read-only filesystem facts
  routed through the app-server. It currently owns metadata, directory listing,
  and file-byte reads. Filesystem mutation, watches, and fuzzy file search stay
  unpromoted until their user workflow and permission model are clearer.
- [x] Add DocC examples for app-server startup, thread/turn start, progress
  observation, approval response, diagnostics, recent history, and SwiftUI
  observable companions.
  Decision: covered by the startup, progress/approval, diagnostics/history, and
  SwiftUI observable companion walkthroughs in `Sources/SwiftASB/SwiftASB.docc/`.
- [x] Update stale README release references before the next release.
  Decision: README now names `v1.0.3` as the current released baseline.
- [x] Confirm README, DocC, and this audit use the same v1 release boundary.
  Decision: README, DocC, and this audit now describe the same narrow v1
  promise: app-server lifecycle, app-wide capability reads, stored-thread
  operations, turn control, approval/elicitation handling, diagnostics, local
  history, observable companions, and selected thread-management actions, while
  generated wire models and broader app-server feature families stay internal
  or post-v1.

## Initial Risk Notes

- `CodexAppServer.swift` remains the highest navigation risk because it still
  owns root actor behavior, event fanout, history reconciliation, and private
  conversion helpers. The public request/result/domain values have been split
  into focused sibling files.
- `CodexThread.swift` now keeps the thread handle, history-window type,
  thread-scoped actions, and thread event payloads. Dashboard and recent
  observable companions have been split into focused sibling files.
- `CodexInteractiveRequests.swift` should get a careful naming pass because
  approval and elicitation APIs are part of the v1 promise and will be expensive
  to rename after the v1 tag.
- `CodexDiagnostics.swift` intentionally exposes passive signals. It should not
  grow answerable guardian-control APIs without a separate post-v1 design pass.
- The generated-wire boundary is already clear in principle, but every public
  API example should be checked so it never teaches consumers to depend on
  `CodexWire...` types.
- The final v1 public-symbol pass found no generated `CodexWire...` names in
  the exported `SwiftASB` symbol graph. `validate-all` now checks that generated
  sources stay internal and public declarations avoid `CodexWire...` names, so
  future generated-wire promotions fail maintainer validation if they leak
  through the public product.
