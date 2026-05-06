# SwiftUI Observable Companions

Use dashboard, minimap, recent-file, and recent-command companions as current-state UI models.

## Overview

SwiftASB's observable companions are ready-made `@Observable` state objects for SwiftUI surfaces. They are current-state mirrors over live streams and local history; they are not replayable protocol logs.

Use ``CodexAppServer/makeLibrary(configuration:)`` for app-wide stored-thread lists, ``CodexThread/makeDashboard()`` for thread-level state, ``CodexTurnHandle/minimap`` for one active turn, and the recent companions for completed turn, file, and command views.

```swift
import Observation
import SwiftASB

@MainActor
@Observable
final class ThreadInspectorModel {
    private let appServer: CodexAppServer
    private let thread: CodexThread

    var library: CodexAppServer.Library?
    var dashboard: CodexThread.Dashboard?
    var recentFiles: CodexThread.RecentFiles?
    var recentCommands: CodexThread.RecentCommands?
    var currentMinimap: CodexTurnHandle.Minimap?
    var errorMessage: String?

    init(appServer: CodexAppServer, thread: CodexThread) {
        self.appServer = appServer
        self.thread = thread
    }

    func start() async {
        do {
            library = try await appServer.makeLibrary(
                configuration: .init(
                    sortedBy: .turnFinishedNewestFirst,
                    groupedBy: .cwd,
                    query: .unarchived(limit: 30),
                    mcpServerStatusRequest: .init(detail: .toolsAndAuthOnly)
                )
            )
            library?.sortedBy = .selectedNewestFirst
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

    func refreshArchive() async {
        await library?.refreshArchived()
    }

    func refreshAppSnapshots() async {
        await library?.refreshAppSnapshots()
    }

    func selectThread(_ threadID: String?) {
        library?.selectThread(threadID)
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

`CodexAppServer.Library` is the app-wide companion for launchers, sidebars, and project browsers. It publishes value snapshots for unarchived threads, archived threads, and cwd groups; it also reloads from local persistence after app-wide thread and turn events such as archive, unarchive, name changes, status changes, and completed turns.

Use ``CodexAppServer/Library/selectedThreadID`` and ``CodexAppServer/Library/selectThread(_:)-(String?)`` for library-local selection. The selection timestamp stays inside the library and can drive ``CodexAppServer/Library/SortedBy/selectedNewestFirst`` without writing UI preference state into Codex's stored thread metadata.

Use ``CodexAppServer/Library/refreshAppSnapshots()`` when the same app-wide UI needs model capabilities, MCP server status, and hook diagnostics. Library derives hook `cwd` requests from its stored thread snapshots unless configuration provides explicit hook current-directory paths.

Recent companions keep caller-owned UI inputs mutable. For example, views can update selected file or command identifiers and visible item identifiers. SwiftASB uses that information to protect visible or selected payloads while slimming older low-value entries when the resident cache exceeds its budget.

Start with automatic cache policies unless the UI has known density requirements. Use the named presets for ``CodexThread/RecentTurns`` and automatic policies for file and command companions when the initial page size is enough guidance.

## What To Store

Store the companion object itself in your view model. Do not copy its arrays into a second state store unless your UI needs a separate projection. The companion already listens to SwiftASB streams and publishes state changes through Swift Observation.

## Topics

### Thread-Level State

- ``CodexAppServer/makeLibrary(configuration:)``
- ``CodexAppServer/Library``
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
