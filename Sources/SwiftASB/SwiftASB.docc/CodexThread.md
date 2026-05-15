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

Use ``readGoal()``, ``setGoal(_:)``, and ``clearGoal()`` for the app-server goal attached to this thread.

Use ``sendShellCommand(_:)`` only when a host app intentionally wants to send a literal user-level shell command to the thread shell. This is not the same operation as SwiftASB's internal `command/exec` helper path. `command/exec` sends argv-shaped helper commands through the app-server command runner for SwiftASB-owned intents such as Git fact refreshes or extension maintenance. `thread/shellCommand` preserves shell syntax such as pipes, redirects, and quoting, and the upstream schema documents that it runs unsandboxed with the user's full shell access instead of inheriting the thread sandbox policy.

Because `sendShellCommand(_:)` is high-impact command execution, SwiftASB gates it behind the disabled-by-default ``SwiftASBFeatureCategory/ID/shellCommandExecution`` category. Consuming apps should present that category as explicit user-level shell access, not as a sandboxed command helper.

## History Access

Use the non-UI history helpers when a caller needs completed turn snapshots without binding to an observable:

- ``readRecentTurnHistoryWindow(limit:)`` reads the newest local completed turns.
- ``readOlderTurnHistoryWindow(olderThan:limit:)`` and ``readNewerTurnHistoryWindow(newerThan:limit:)`` page from a known boundary.
- ``windowAroundTurn(_:limit:)`` and ``windowAroundItem(_:limit:)`` return centered local windows for inspectors.

## Observable Companions

Use ``makeDashboard()`` for thread-level current state, ``makeRecentTurns(limit:cachePolicy:)`` for a turn-centric view, ``makeRecentFiles(limit:cachePolicy:)`` or ``makeRecentFiles(_:)`` for a file-change view, and ``makeRecentCommands(limit:cachePolicy:)`` or ``makeRecentCommands(_:)`` for a command-output view.

These companions are separate on purpose. `RecentTurns`, `RecentFiles`, and `RecentCommands` preserve domain-specific behavior that a mixed activity feed would flatten too early.

Recent observable startup can begin as an empty local-only view when the live app-server has no remote turn page to provide yet. That includes ephemeral threads and non-ephemeral threads before stored history materializes. Direct ``CodexAppServer/listThreadTurns(_:)`` calls still surface the app-server error for callers that need explicit remote paging behavior.

## Topics

### Walkthroughs

- <doc:HandlingTurnProgressAndApprovals>
- <doc:ReadingDiagnosticsAndHistory>
- <doc:SwiftUIObservableCompanions>

### Identity And Defaults

- ``id``
- ``info``
- ``approvalPolicy``
- ``approvalsReviewer``
- ``currentDirectoryPath``
- ``instructionSources``
- ``model``
- ``modelProvider``
- ``projectInfo``
- ``info/source``
- ``activePermissionProfile``
- ``permissionProfile``
- ``reasoningEffort``
- ``sandboxPolicy``
- ``serviceTier``
- ``workspace``
- ``events``

### Turns

- ``startTurn(_:)``
- ``startTextTurn(_:approvalPolicy:approvalsReviewer:currentDirectoryPath:effort:model:outputSchema:permissions:personality:serviceTier:summary:)``
- ``TurnStartRequest``

### Thread Actions

- ``compactContext()``
- ``sendShellCommand(_:)``
- ``rollbackLastTurns(_:)``
- ``setName(_:)``
- ``updateMetadata(gitInfo:)``
- ``readGoal()``
- ``setGoal(_:)``
- ``clearGoal()``
- ``Goal``
- ``GoalSetRequest``

### Local History

- ``HistoryWindow``
- ``HistoryWindowQD``
- ``RecentFilesQD``
- ``RecentCommandsQD``
- ``readTurnHistory(turnID:)``
- ``readHistoryWindow(_:)``
- ``readRecentTurnHistoryWindow(limit:)``
- ``readRecentTurnHistory(limit:)``
- ``readOlderTurnHistoryWindow(olderThan:limit:)``
- ``readOlderTurnHistory(olderThan:limit:)``
- ``readNewerTurnHistoryWindow(newerThan:limit:)``
- ``readNewerTurnHistory(newerThan:limit:)``
- ``windowAroundTurn(_:limit:)``
- ``windowAroundItem(_:limit:)``

### Observable Companions

- ``makeDashboard()``
- ``Dashboard``
- ``makeRecentTurns(limit:cachePolicy:)``
- ``RecentTurns``
- ``makeRecentFiles(limit:cachePolicy:)``
- ``makeRecentFiles(_:)``
- ``RecentFiles``
- ``makeRecentCommands(limit:cachePolicy:)``
- ``makeRecentCommands(_:)``
- ``RecentCommands``

### Interactive Requests

- ``respond(to:with:)-(CodexApprovalRequest,_)``
- ``respond(to:with:)-(CodexElicitationRequest,_)``
