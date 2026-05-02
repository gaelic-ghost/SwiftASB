# ``SwiftASB``

Build Swift clients for the local Codex app-server without exposing generated JSON-RPC wire models as your application API.

## Overview

SwiftASB is a Swift Package Manager library for talking to `codex app-server --listen stdio://`.
It owns the subprocess transport, the JSON-RPC protocol boundary, typed request and response decoding, local thread-history reconciliation, and a small public API shaped around the work a consumer is trying to do.

The public surface has three main handles:

- ``CodexAppServer`` owns the app-server process, initialization, app-wide capability snapshots, and stored-thread operations.
- ``CodexThread`` owns a single conversation thread, including new turns, thread-management actions, thread event streams, local history windows, and thread-scoped observable companions.
- ``CodexTurnHandle`` owns one active turn, including turn events, steering, interruption, server-request responses, and an observable current-state minimap.

Generated Codex wire types remain internal scaffolding. Public callers should use the hand-owned Swift request, result, event, and observable types documented here.

## Topics

### Start Here

- <doc:GettingStartedWithSwiftASB>
- <doc:InteractiveLifecycle>
- <doc:HandlingTurnProgressAndApprovals>
- <doc:ReadingDiagnosticsAndHistory>
- <doc:SwiftUIObservableCompanions>
- <doc:AppWideCapabilities>
- <doc:ThreadManagement>
- <doc:ThreadHistoryAndObservables>
- <doc:GeneratedWireBoundary>

### Primary Handles

- ``CodexAppServer``
- ``CodexThread``
- ``CodexTurnHandle``

### Thread And Turn Events

- ``CodexThreadEvent``
- ``CodexTurnEvent``
- ``CodexThreadStarted``
- ``CodexThreadStatusChanged``
- ``CodexThreadNameUpdated``
- ``CodexThreadTokenUsageUpdated``
- ``CodexTurnStarted``
- ``CodexTurnCompletion``

### Interactive Requests

- ``CodexApprovalRequest``
- ``CodexElicitationRequest``
- ``CodexApprovalResponse``
- ``CodexElicitationResponse``
- ``CodexInteractiveRequestResolved``

### Diagnostics

- ``CodexAppServerError``
