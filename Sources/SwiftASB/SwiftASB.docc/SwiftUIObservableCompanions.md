# SwiftUI Observable Companions

Use dashboard, minimap, recent-file, and recent-command companions as current-state UI models.

## Overview

SwiftASB's observable companions are ready-made `@Observable` state objects for SwiftUI surfaces. They are current-state mirrors over live streams and local history; they are not replayable protocol logs.

Use ``CodexAppServer/makeInventory(configuration:)`` for app-wide capability and extension inventory, ``CodexAppServer/makeLibrary(configuration:)`` for app-wide stored-thread lists, ``CodexThread/makeDashboard()`` for thread-level state, ``CodexTurnHandle/minimap`` for one active turn, and the recent companions for completed turn, file, and command views.

```swift
import Observation
import SwiftASB

@MainActor
@Observable
final class ThreadInspectorModel {
    private let appServer: CodexAppServer
    private let thread: CodexThread

    var inventory: CodexAppServer.Inventory?
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
            inventory = try await appServer.makeInventory()
            library = try await appServer.makeLibrary(
                configuration: .init(
                    sortedBy: .turnFinishedNewestFirst,
                    groupedBy: .cwd,
                    query: .unarchived(limit: 30)
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

`CodexAppServer.Library` is the app-wide companion for launchers, sidebars, and project browsers. It publishes value snapshots for unarchived threads, archived threads, cwd groups, stable worktree groups, ``CodexWorkspace/ProjectInfo`` values for thread and repository-group identity, ``CodexWorkspace/WorktreeSnapshot`` values for Codex-reported cwd plus optional Git facts, and ``CodexAppServer/ThreadSource`` values for source badges; it also reloads from local persistence after app-wide thread and turn events such as archive, unarchive, name changes, status changes, and completed turns.

Use ``CodexAppServer/Library/selectedThreadID`` and ``CodexAppServer/Library/selectThread(_:)-(String?)`` for library-local selection. The selection timestamp stays inside the library and can drive ``CodexAppServer/Library/SortedBy/selectedNewestFirst`` without writing UI preference state into Codex's stored thread metadata.

Use ``CodexAppServer/Library/worktreeGroups`` when a sidebar needs repository/workspace sections independent of the current visible grouping mode. Use ``CodexAppServer/Library/threads(inWorktreeID:includeArchived:)`` or ``CodexAppServer/Library/threads(inRepositoryOriginURL:includeArchived:)`` when a project browser needs the sorted threads for one Codex-reported worktree or Git origin without reading local disk.

When `gitObservability` is enabled in ``SwiftASBFeaturePolicy``, selecting a library thread refreshes ``CodexAppServer/Library/selectedGitStatus`` for that worktree. The status snapshot combines Codex-reported branch, SHA, and origin metadata with sandboxed app-server `command/exec` facts for repository root, remotes, ahead/behind, and dirty/untracked counts.

Use ``CodexAppServer/Inventory`` when an app-wide UI needs model capabilities, MCP server summaries, hook diagnostics, apps, skills, plugins, and collaboration modes without also needing stored-thread lists. Use ``CodexAppServer/Library/refreshAppSnapshots()`` when model, MCP, and hook snapshots should sit beside the thread library. SwiftASB owns MCP status refresh and keeps summary lists current from startup and app-server status-change notifications.

Recent companions keep caller-owned UI inputs mutable. For example, views can update selected file or command identifiers and visible item identifiers. SwiftASB uses that information to protect visible or selected payloads while slimming older low-value entries when the resident cache exceeds its budget.

Start with automatic cache policies unless the UI has known density requirements. Use the named presets for ``CodexThread/RecentTurns`` and automatic policies for file and command companions when the initial page size is enough guidance.

## What To Store

Store the companion object itself in your view model. Do not copy its arrays into a second state store unless your UI needs a separate projection. The companion already listens to SwiftASB streams and publishes state changes through Swift Observation.

## Topics

### Thread-Level State

- ``CodexAppServer/makeLibrary(configuration:)``
- ``CodexAppServer/Library``
- ``CodexAppServer/makeInventory(configuration:)``
- ``CodexAppServer/Inventory``
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
