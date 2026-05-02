# Getting Started With SwiftASB

Start a local Codex app-server, initialize the protocol session, and run one text turn.

## Overview

Every SwiftASB client starts with ``CodexAppServer``. The app-server actor owns the local `codex app-server` subprocess and is the only object that sends JSON-RPC requests directly. After startup, initialize the session with client metadata, create a ``CodexThread``, and start a turn from that thread.

```swift
import SwiftASB

func runOneTurn() async throws {
    let appServer = CodexAppServer()
    try await appServer.start()
    defer {
        Task { await appServer.stop() }
    }

    let diagnostics = try await appServer.cliExecutableDiagnostics()
    guard case .supported = diagnostics.compatibility else {
        throw RuntimeError("Unsupported Codex CLI: \(diagnostics.versionString)")
    }

    try await appServer.initialize(
        .init(
            clientInfo: .init(
                name: "ExampleClient",
                title: "Example Client",
                version: "1.0.0"
            )
        )
    )

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

struct RuntimeError: Error, CustomStringConvertible {
    var description: String

    init(_ description: String) {
        self.description = description
    }
}
```

## Startup Order

Call ``CodexAppServer/start()`` before every other protocol operation. Then call ``CodexAppServer/initialize(_:)`` once. SwiftASB sends the required `initialized` notification after the initialize response succeeds.

``CodexAppServer/cliExecutableDiagnostics()`` is available after startup and before initialization. Use it when a UI or command-line client needs to show which `codex` executable was launched and whether it is inside SwiftASB's reviewed compatibility window.

## Thread Ownership

``CodexAppServer/startThread(_:)`` creates the thread and returns a ``CodexThread`` handle. Use the thread handle for conversation-scoped work such as starting turns, responding to requests, reading local history, naming the thread, compacting context, and building observable companions.

## Topics

### Startup

- ``CodexAppServer/start()``
- ``CodexAppServer/stop()``
- ``CodexAppServer/initialize(_:)``
- ``CodexAppServer/cliExecutableDiagnostics()``

### First Thread And Turn

- ``CodexAppServer/startThread(_:)``
- ``CodexThread``
- ``CodexThread/startTextTurn(_:approvalPolicy:approvalsReviewer:currentDirectoryPath:effort:model:outputSchema:personality:serviceTier:summary:)``
- ``CodexTurnHandle``
