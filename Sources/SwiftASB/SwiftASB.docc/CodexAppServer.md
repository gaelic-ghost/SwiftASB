# ``CodexAppServer``

Own the local Codex app-server process and expose connection-wide operations.

## Overview

`CodexAppServer` is the root object for a SwiftASB client. It starts and stops the local Codex subprocess, performs the `initialize` handshake, sends typed protocol requests, decodes typed responses, fans out typed notifications, and reconciles stored thread data into the package's local history store.

Create one app-server actor for a client process or window group that should share the same Codex subprocess. Hold onto the actor while any ``CodexThread`` or ``CodexTurnHandle`` values derived from it are still active.

```swift
let appServer = CodexAppServer()
try await appServer.start()

let session = try await appServer.initialize(
    .init(
        clientInfo: .init(
            name: "ExampleClient",
            title: "Example Client",
            version: "1.0.0"
        )
    )
)

let thread = try await appServer.startThread()
```

Always call ``stop()`` when the owner is done with the subprocess.

## Connection Lifecycle

Call ``start()`` before sending protocol requests. Call ``initialize(_:)`` once the transport is running; SwiftASB sends the required `initialized` notification after a successful response.

Use ``cliExecutableDiagnostics()`` when a UI or command-line tool needs to explain which `codex` executable was found and whether its version is inside the documented compatibility window.

Use ``diagnosticEvents()`` to observe passive runtime diagnostics that are not control requests. These events let clients show or log warnings, guardian warnings, model reroutes, and model verification results without exposing generated wire payloads.

## App-Wide Capabilities

Use ``listModels(_:)``, ``listMcpServerStatuses(_:)``, and ``listHooks(_:)`` for connection-wide snapshots. They do not belong to a single thread because they describe the app-server's current model catalog, MCP server surface, and configured hook diagnostics.

Use ``makeLibrary(configuration:)`` when a GUI or CLI client needs an app-wide observable over stored threads. The library loads local Core Data-backed snapshots first, then reconciles unarchived app-server pages before archived pages. It publishes SwiftASB value snapshots, not Core Data objects.

`Library` also reloads local snapshots after app-wide thread and turn events, so archive, unarchive, name, status, and completed-turn changes can update sidebars without each consumer wiring per-thread event streams.

Library selection is caller-owned state. Use it for sidebar and launcher selection, including recently selected ordering, without writing window or scene preferences into Codex's stored thread metadata.

## Stored Threads

Use ``startThread(_:)`` for a new thread, ``resumeThread(_:)`` for an existing stored thread, ``forkThread(_:)`` for a copy of existing history, ``listThreads(_:)`` for thread pages, ``readThread(_:)`` for a stored snapshot, and ``listThreadTurns(_:)`` for paged turn history.

Thread-scoped convenience methods live on ``CodexThread`` when the caller already has a thread handle.

Set ``ThreadResumeRequest/excludeTurns`` or ``ThreadForkRequest/excludeTurns`` when the caller wants the thread metadata first and plans to page stored turns separately through ``listThreadTurns(_:)`` or read local history through ``CodexThread``. Leaving the field nil lets Codex include its normal response payload for the operation.

## Topics

### Walkthroughs

- <doc:GettingStartedWithSwiftASB>
- <doc:ReadingDiagnosticsAndHistory>

### Configuration

- ``Configuration``
- ``CLIExecutableDiagnostics``
- ``diagnosticEvents()``
- ``CodexDiagnosticEvent``

### Startup

- ``start()``
- ``stop()``
- ``initialize(_:)``
- ``InitializeRequest``
- ``InitializeCapabilities``
- ``ClientInfo``
- ``InitializeSession``

### App-Wide Capability Snapshots

- ``makeLibrary(configuration:)``
- ``Library``
- ``ThreadListQD``
- ``listModels(_:)``
- ``ModelListRequest``
- ``ModelListPage``
- ``Model``
- ``listHooks(_:)``
- ``HookListRequest``
- ``HookListSnapshot``
- ``HookListEntry``
- ``HookDiagnostic``
- ``HookError``
- ``HookMetadata``
- ``listMcpServerStatuses(_:)``
- ``McpServerStatusListRequest``
- ``McpServerStatusPage``
- ``McpServerStatus``

### Thread Operations

- ``startThread(_:)``
- ``resumeThread(_:)``
- ``forkThread(_:)``
- ``compactThread(_:)``
- ``rollbackThread(_:)``
- ``setThreadName(_:)``
- ``updateThreadMetadata(_:)``
- ``listThreads(_:)``
- ``readThread(_:)``
- ``listThreadTurns(_:)``
- ``startTurn(_:)``

### Thread Models

- ``ThreadStartRequest``
- ``ThreadResumeRequest``
- ``ThreadForkRequest``
- ``ThreadCompactRequest``
- ``ThreadRollbackRequest``
- ``ThreadSetNameRequest``
- ``ThreadMetadataUpdateRequest``
- ``ThreadMetadataGitInfoUpdate``
- ``ThreadMetadataFieldUpdate``
- ``ThreadSession``
- ``ThreadInfo``
- ``ThreadReadRequest``
- ``ThreadReadResult``
- ``ThreadListRequest``
- ``ThreadListPage``
- ``ThreadTurnsListRequest``
- ``ThreadTurnsPage``
- ``GitInfo``

### Turn Models

- ``TurnStartRequest``
- ``TurnSession``
- ``TurnInfo``
- ``TurnInput``

### Runtime Options

- ``ApprovalPolicy``
- ``ApprovalsReviewer``
- ``GranularApprovalPolicy``
- ``SandboxPolicy``
- ``SandboxMode``
- ``ReasoningEffort``
- ``ReasoningSummary``
- ``ServiceTier``
- ``SessionStartSource``
- ``Personality``
- ``JSONValue``
