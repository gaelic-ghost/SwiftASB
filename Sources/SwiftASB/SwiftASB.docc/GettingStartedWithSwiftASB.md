# Getting Started With SwiftASB

Start a local Codex app-server, initialize the protocol session, and run one text turn.

## Overview

Every SwiftASB client starts with ``CodexAppServer``. The app-server actor owns the local `codex app-server` subprocess and is the only object that sends JSON-RPC requests directly. After startup, initialize the session with client metadata, create a ``CodexThread``, and start a turn from that thread.

```swift
import SwiftASB

func runOneTurn() async throws {
    let appServer = CodexAppServer()
    defer {
        Task { await appServer.stop() }
    }

    let session = try await appServer.start(
        .init(
            clientInfo: .init(
                name: "ExampleClient",
                title: "Example Client",
                version: "1.0.0"
            )
        )
    )
    print("Started Codex:", session.cliExecutableDiagnostics.versionString)

    let thread = try await appServer.startThread(
        .init(
            currentDirectoryPath: "/Users/example/project",
            model: "gpt-5.4"
        )
    )

    let turn = try await thread.startTextTurn(
        "Summarize the package's public API in three bullets."
    )

    for try await event in turn.events {
        if case let .completed(completion) = event {
            print("Turn finished with status:", completion.turn.status)
            break
        }
    }
}

```

## Startup Order

For most clients, call ``CodexAppServer/start(_:)`` with a ``CodexAppServer/StartupRequest``. That launches the local Codex app-server subprocess, checks the selected Codex CLI against SwiftASB's reviewed compatibility window, sends `initialize`, sends the required `initialized` notification, and returns a ``CodexAppServer/StartupSession``.

If startup fails before the session is ready, SwiftASB throws ``CodexAppServerStartupError`` with a typed reason such as a missing Codex CLI executable, an incompatible CLI version, an unparseable CLI version string, a launch failure, or an initialize failure.

Call ``CodexAppServer/start()`` and then ``CodexAppServer/initialize(_:)`` only when the client intentionally owns each startup step. For a custom compatibility policy that still fits one-call startup, configure the ``CodexAppServer/StartupRequest`` passed to ``CodexAppServer/start(_:)``. Use the lower-level path for diagnostics-only startup screens or tests that need to inspect the selected binary before deciding whether to call ``CodexAppServer/initialize(_:)``.

``CodexAppServer/cliExecutableDiagnostics()`` is available after startup and before initialization. Use it when a UI or command-line client needs to show which `codex` executable was launched and whether it is inside SwiftASB's reviewed compatibility window.

## Thread Ownership

``CodexAppServer/startThread(_:)`` creates the thread and returns a ``CodexThread`` handle. Use the thread handle for conversation-scoped work such as starting turns, responding to requests, reading local history, naming the thread, compacting context, and building observable companions.

## Topics

### Startup

- ``CodexAppServer/start()``
- ``CodexAppServer/start(_:)``
- ``CodexAppServer/stop()``
- ``CodexAppServer/initialize(_:)``
- ``CodexAppServer/StartupRequest``
- ``CodexAppServer/StartupSession``
- ``CodexAppServerStartupError``
- ``CodexAppServer/cliExecutableDiagnostics()``

### First Thread And Turn

- ``CodexAppServer/startThread(_:)``
- ``CodexThread``
- ``CodexThread/startTextTurn(_:approvalPolicy:approvalsReviewer:currentDirectoryPath:effort:model:outputSchema:permissions:personality:serviceTier:summary:)``
- ``CodexTurnHandle``
