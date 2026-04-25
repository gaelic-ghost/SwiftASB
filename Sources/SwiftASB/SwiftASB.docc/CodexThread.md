# ``CodexThread``

Work with one Codex conversation thread.

## Overview

`CodexThread` is returned by ``CodexAppServer/startThread(_:)``, ``CodexAppServer/resumeThread(_:)``, and ``CodexAppServer/forkThread(_:)``. It carries the thread's current metadata, default turn settings, and typed thread event stream while delegating protocol work back to the owning ``CodexAppServer`` actor.

Use a thread handle when the operation is naturally scoped to one conversation: starting a turn, compacting context, setting the visible thread name, updating stored Git metadata, rolling back trailing turns, reading local history windows, or building observable companions for UI state.

```swift
let turn = try await thread.startTextTurn("Summarize the recent changes.")

for try await event in turn.events {
    if case let .completed(completion) = event {
        print(completion.turn.status)
        break
    }
}
```

## Thread Management

Use ``setName(_:)`` for a human-readable title, ``updateMetadata(gitInfo:)`` for explicit Git metadata patches, and ``rollbackLastTurns(_:)`` to ask the app-server to remove trailing turns from the stored thread.

Rollback returns a refreshed thread handle. SwiftASB records a local rollback marker and trims visible local history to match the app-server response. It does not preserve the full removed-turn payload archive yet.

## History Access

Use the non-UI history helpers when a caller needs completed turn snapshots without binding to an observable:

- ``readRecentTurnHistoryWindow(limit:)`` reads the newest local completed turns.
- ``readOlderTurnHistoryWindow(beforeTurnID:limit:)`` and ``readNewerTurnHistoryWindow(afterTurnID:limit:)`` page from a known boundary.
- ``windowAroundTurn(_:before:after:)`` and ``windowAroundItem(_:before:after:)`` return centered local windows for inspectors.

## Observable Companions

Use ``makeDashboard()`` for thread-level current state, ``makeRecentTurns(limit:cachePolicy:)`` for a turn-centric view, ``makeRecentFiles(limit:)`` for a file-change view, and ``makeRecentCommands(limit:)`` for a command-output view.

These companions are separate on purpose. `RecentTurns`, `RecentFiles`, and `RecentCommands` preserve domain-specific behavior that a mixed activity feed would flatten too early.

## Topics

### Identity And Defaults

- ``id``
- ``info``
- ``approvalPolicy``
- ``approvalsReviewer``
- ``currentDirectoryPath``
- ``instructionSources``
- ``model``
- ``modelProvider``
- ``reasoningEffort``
- ``sandboxPolicy``
- ``serviceTier``
- ``events``

### Turns

- ``startTurn(_:)``
- ``startTextTurn(_:approvalPolicy:approvalsReviewer:sandboxPolicy:model:reasoningEffort:reasoningSummary:additionalWritableRoots:)``
- ``TurnRequest``

### Thread Actions

- ``compactContext()``
- ``rollbackLastTurns(_:)``
- ``setName(_:)``
- ``updateMetadata(gitInfo:)``

### Local History

- ``HistoryWindow``
- ``readTurnHistory(turnID:)``
- ``readRecentTurnHistoryWindow(limit:)``
- ``readRecentTurnHistory(limit:)``
- ``readOlderTurnHistoryWindow(beforeTurnID:limit:)``
- ``readOlderTurnHistory(beforeTurnID:limit:)``
- ``readNewerTurnHistoryWindow(afterTurnID:limit:)``
- ``readNewerTurnHistory(afterTurnID:limit:)``
- ``windowAroundTurn(_:before:after:)``
- ``windowAroundItem(_:before:after:)``

### Observable Companions

- ``makeDashboard()``
- ``Dashboard``
- ``makeRecentTurns(limit:cachePolicy:)``
- ``RecentTurns``
- ``makeRecentFiles(limit:)``
- ``RecentFiles``
- ``makeRecentCommands(limit:)``
- ``RecentCommands``

### Interactive Requests

- ``respond(to:with:)``
