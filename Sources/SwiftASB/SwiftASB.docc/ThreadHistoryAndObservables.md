# Thread History And Observables

Read completed local history and observe current thread activity without replaying raw protocol deltas.

## Overview

SwiftASB stores thread and turn history locally as it observes live turns and as it reads stored history from the app-server. Public callers can use that store through thread-scoped helpers and observable companions.

There are three public shapes:

- ``CodexAppServer/Library`` publishes app-wide stored-thread lists for launchers, sidebars, and project browsers.
- `HistoryWindow` helpers return sealed completed-turn snapshots for non-UI callers and inspectors.
- Observable companions stay attached to live streams and update UI-facing state over time.

## App-Wide Library

Use ``CodexAppServer/makeLibrary(configuration:)`` when a client needs stored-thread lists before choosing a thread. The library publishes unarchived threads, archived threads, and grouped unarchived threads. It reads local snapshots first so UI can show a sidebar quickly, then reconciles app-server `thread/list` pages in the background.

`Library.SortedBy` and `Library.GroupedBy` are UI-facing policies. `Library.GroupedBy.cwd` is the current project-style grouping surface while repository-root detection remains a later design decision. `CodexAppServer.ThreadListQD` is the package-owned query descriptor for repeatable thread-list intent.

Use ``CodexAppServer/Library/refreshAll()``, ``CodexAppServer/Library/refreshUnarchived()``, and ``CodexAppServer/Library/refreshArchived()`` for explicit reconciliation actions. The library also reloads local value snapshots after app-wide thread and turn events, including archive, unarchive, name changes, status changes, and completed turns.

Use ``CodexAppServer/Library/selectedThreadID`` and ``CodexAppServer/Library/selectThread(_:)-(String?)`` for caller-owned selection. Selection is library-local state, so apps can keep one library per window or scene without changing the app-server's stored thread metadata. ``CodexAppServer/Library/SortedBy/selectedNewestFirst`` promotes recently selected threads before falling back to newest updated threads.

`cwd` is the stored thread directory that app-server returns on `ThreadInfo`. SwiftASB currently treats it as the thread's project directory because the schema exposes it as required thread metadata and `thread/metadata/update` only patches Git metadata, not stored `cwd`.

The library can also publish app-wide read snapshots through ``CodexAppServer/Library/refreshAppSnapshots()``. Those snapshots reuse ``CodexAppServer/readModelCapabilities()``, ``CodexAppServer/listMcpServerStatuses(_:)``, and ``CodexAppServer/listHooks(_:)`` so model feature gates, MCP surfaces, and hook diagnostics are observable next to the stored-thread lists without becoming Core Data state.

## Local History Windows

Use ``CodexThread/readRecentTurnHistoryWindow(limit:)`` for the newest known completed turns. Use older and newer window helpers when the caller already has a boundary turn. Use centered helpers when an inspector needs context around one turn or one item.

```swift
let window = try await thread.windowAroundTurn(
    selectedTurnID,
    before: 3,
    after: 3
)
```

The history helpers are intentionally local-history reads. They expose what SwiftASB has persisted and reconciled so far without promising a full transcript-search or remote cursor contract.

## App-Server History Boundaries

Recent observable startup is designed for UI surfaces that can render an initially empty history rail while live events arrive. If the live app-server reports that `thread/turns/list` is unavailable because a thread is ephemeral, or because a non-ephemeral thread has not materialized its first stored user turn yet, ``CodexThread/makeRecentTurns(limit:cachePolicy:)``, ``CodexThread/makeRecentFiles(limit:cachePolicy:)``, and ``CodexThread/makeRecentCommands(limit:cachePolicy:)`` start with an empty local-only view.

That degraded startup path is limited to the known history-unavailable responses. Direct remote paging through ``CodexAppServer/listThreadTurns(_:)`` still reports the app-server error, and unexpected `thread/turns/list` failures still remain failures when creating recent observables.

## Recent Turns

``CodexThread/RecentTurns`` is a turn-centric observable for chat UIs, inspectors, and history rails. It prewarms from local history, expands older or newer whole-turn windows, tracks visible turn IDs and scroll signals, and slims older low-value payloads when the cache needs room.

Use the named cache-policy presets first:

- ``CodexThread/RecentTurns/CachePolicy/chatUI(pageSize:)`` for ordinary chat surfaces
- ``CodexThread/RecentTurns/CachePolicy/inspector(pageSize:)`` for detail-heavy views
- ``CodexThread/RecentTurns/CachePolicy/historyRail(pageSize:)`` for compact rails

## Recent Files And Commands

``CodexThread/RecentFiles`` and ``CodexThread/RecentCommands`` are dedicated companions because file changes and command output have different display, selection, and cache behavior.

`RecentFiles` keeps file-change entries enriched from file-change output deltas. `RecentCommands` keeps command entries enriched from command-output deltas. Both can keep lightweight shell summaries resident while rehydrating selected payloads when the caller needs detail.

## Dashboard And Minimap

``CodexThread/Dashboard`` summarizes thread-level current state such as active tool, MCP, hook, and compaction activity. ``CodexTurnHandle/Minimap`` summarizes one active turn's command, file-edit, MCP, dynamic-tool, and collab-tool activity.

Use these for "what is happening now" UI. Use history windows or closed turns for completed transcript data.

These companions are not alternate event logs. `Dashboard` starts from the current thread snapshot and aggregate activity state, then mirrors later thread and activity updates. `Minimap`, `RecentTurns`, `RecentFiles`, and `RecentCommands` listen to live feeds after they are created; command-output and file-output deltas that arrive before a recent companion exists are not replayed as delta events, though completed history can still be rehydrated from the local history store.

## Topics

### Walkthroughs

- <doc:ReadingDiagnosticsAndHistory>
- <doc:SwiftUIObservableCompanions>

### History Reads

- ``CodexThread/HistoryWindow``
- ``CodexThread/readTurnHistory(turnID:)``
- ``CodexThread/readRecentTurnHistoryWindow(limit:)``
- ``CodexThread/readOlderTurnHistoryWindow(olderThan:limit:)``
- ``CodexThread/readNewerTurnHistoryWindow(newerThan:limit:)``
- ``CodexThread/windowAroundTurn(_:limit:)``
- ``CodexThread/windowAroundItem(_:limit:)``

### Observable Companions

- ``CodexAppServer/Library``
- ``CodexThread/Dashboard``
- ``CodexThread/RecentTurns``
- ``CodexThread/RecentFiles``
- ``CodexThread/RecentCommands``
- ``CodexTurnHandle/Minimap``
