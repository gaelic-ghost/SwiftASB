# SwiftUI Observable Companions

Use dashboard, minimap, recent-file, and recent-command companions as current-state UI models.

## Overview

SwiftASB's observable companions are ready-made `@Observable` state objects for SwiftUI surfaces. They are current-state mirrors over live streams and local history; they are not replayable protocol logs.

Use ``CodexThread/makeDashboard()`` for thread-level state, ``CodexTurnHandle/minimap`` for one active turn, and the recent companions for completed turn, file, and command views.

```swift
import Observation
import SwiftASB

@MainActor
@Observable
final class ThreadInspectorModel {
    private let thread: CodexThread

    var dashboard: CodexThread.Dashboard?
    var recentFiles: CodexThread.RecentFiles?
    var recentCommands: CodexThread.RecentCommands?
    var currentMinimap: CodexTurnHandle.Minimap?
    var errorMessage: String?

    init(thread: CodexThread) {
        self.thread = thread
    }

    func start() async {
        do {
            dashboard = await thread.makeDashboard()
            recentFiles = try await thread.makeRecentFiles(
                limit: 20,
                cachePolicy: .automatic(pageSize: 20)
            )
            recentCommands = try await thread.makeRecentCommands(
                limit: 20,
                cachePolicy: .automatic(pageSize: 20)
            )
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func run(_ prompt: String) async {
        do {
            let turn = try await thread.startTextTurn(prompt)
            currentMinimap = turn.minimap

            for try await event in turn.events {
                if case .completed = event {
                    _ = try await turn.complete()
                    return
                }
            }
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
```

## Selection And Cache Behavior

Recent companions keep caller-owned UI inputs mutable. For example, views can update selected file or command identifiers and visible item identifiers. SwiftASB uses that information to protect visible or selected payloads while slimming older low-value entries when the resident cache exceeds its budget.

Start with automatic cache policies unless the UI has known density requirements. Use the named presets for ``CodexThread/RecentTurns`` and automatic policies for file and command companions when the initial page size is enough guidance.

## What To Store

Store the companion object itself in your view model. Do not copy its arrays into a second state store unless your UI needs a separate projection. The companion already listens to SwiftASB streams and publishes state changes through Swift Observation.

## Topics

### Thread-Level State

- ``CodexThread/makeDashboard()``
- ``CodexThread/Dashboard``

### Active Turn State

- ``CodexTurnHandle/minimap``
- ``CodexTurnHandle/Minimap``

### Recent Companions

- ``CodexThread/makeRecentTurns(limit:cachePolicy:)``
- ``CodexThread/makeRecentFiles(limit:cachePolicy:)``
- ``CodexThread/makeRecentCommands(limit:cachePolicy:)``
- ``CodexThread/RecentTurns``
- ``CodexThread/RecentFiles``
- ``CodexThread/RecentCommands``
