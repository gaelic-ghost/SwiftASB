# ``SwiftASB``

Build Swift clients for the local Codex app-server without exposing generated JSON-RPC wire models as your application API.

## Overview

SwiftASB is a Swift Package Manager library for talking to `codex app-server --listen stdio://`.
It owns the subprocess transport, the JSON-RPC protocol boundary, typed request and response decoding, local thread-history reconciliation, and a small public API shaped around the work a consumer is trying to do.

The public surface has three main handles:

- ``CodexAppServer`` owns the app-server process, initialization, app-wide observable inventory, capability snapshots, and stored-thread operations.
- ``CodexFS`` owns app-server-routed filesystem reads for sandboxed clients.
- ``CodexWorkspace`` owns app-server-routed workspace permission selections and runtime permission facts.
- ``CodexConfig`` owns app-server-routed configuration reads for sandboxed clients.
- ``CodexMCP`` owns opinionated MCP server installation through app-server configuration writes.
- ``CodexAppServer/CodexExtensions`` owns app, skill, plugin, and collaboration-mode inventory.
- ``SwiftASBFeaturePolicy`` owns SwiftASB convenience-feature categories, defaults, and host-access declarations.
- ``SwiftASBFeatureOperationEvent`` reports SwiftASB-owned mutation operations in human-readable form.
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
- <doc:FeaturePermissionPolicy>
- <doc:ThreadManagement>
- <doc:ThreadHistoryAndObservables>
- <doc:GeneratedWireBoundary>

### Primary Handles

- ``CodexAppServer``
- ``CodexAppServer/Inventory``
- ``CodexFS``
- ``CodexWorkspace``
- ``CodexConfig``
- ``CodexMCP``
- ``CodexAppServer/CodexExtensions``
- ``SwiftASBFeaturePolicy``
- ``SwiftASBFeatureCategory``
- ``SwiftASBFeatureOperationEvent``
- ``CodexThread``
- ``CodexTurnHandle``

### Thread And Turn Events

- ``CodexThreadEvent``
- ``CodexTurnEvent``
- ``CodexThreadStarted``
- ``CodexThreadStatusChanged``
- ``CodexThreadNameUpdated``
- ``CodexThreadTokenUsageUpdated``
- ``CodexThreadGoalUpdated``
- ``CodexThreadGoalCleared``
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
