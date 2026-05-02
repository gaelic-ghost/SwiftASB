# ``CodexTurnHandle``

Observe and control one active Codex turn.

## Overview

`CodexTurnHandle` is returned when a thread starts a turn. It carries the initial turn metadata, a typed event stream, and the methods that can affect that in-flight turn.

Use the handle for work that only makes sense while the turn is active:

- observe streamed turn events through ``events``
- answer approval requests with ``respond(to:with:)-(CodexApprovalRequest,_)`` or elicitation requests with ``respond(to:with:)-(CodexElicitationRequest,_)``
- send steering input with ``steer(_:)`` or ``steerText(_:)``
- interrupt the turn with ``interrupt()``
- read the live current-state mirror with ``minimap``
- complete the live handle into a caller-owned completed snapshot with ``complete()``

```swift
let turn = try await thread.startTextTurn("List the public API surfaces.")

for try await event in turn.events {
    switch event {
    case let .approvalRequested(request):
        try await turn.respond(to: request, with: .commandExecution(.decline))
    case let .completed(completion):
        print("Finished:", completion.turn.status)
        return
    default:
        continue
    }
}
```

## Minimap

``Minimap`` is an observable current-state companion for a single turn. It tracks active and completed command, file-edit, MCP, dynamic-tool, and collab-tool calls, plus latest plan, diff, message, reasoning, approval, elicitation, request-resolution, and completion events.

The minimap is intentionally a live mirror, not a transcript. Use ``complete()`` or ``CodexThread`` history helpers when a consumer needs sealed completed-turn data.

## Topics

### Walkthroughs

- <doc:HandlingTurnProgressAndApprovals>
- <doc:SwiftUIObservableCompanions>

### Identity And Events

- ``threadID``
- ``turn``
- ``events``

### Live Observation

- ``minimap``
- ``Minimap``

### Active-Turn Control

- ``respond(to:with:)-(CodexApprovalRequest,_)``
- ``respond(to:with:)-(CodexElicitationRequest,_)``
- ``steer(_:)``
- ``steerText(_:)``
- ``interrupt()``
- ``complete()``

### Completed Snapshot

- ``ClosedTurn``

### Turn Events

- ``CodexTurnEvent``
- ``CodexTurnStarted``
- ``CodexTurnPlanUpdate``
- ``CodexTurnPlanDelta``
- ``CodexTurnDiffUpdate``
- ``CodexTurnItem``
- ``CodexTurnItemStarted``
- ``CodexTurnItemCompleted``
- ``CodexTurnAgentMessageDelta``
- ``CodexTurnReasoningSummaryPartAdded``
- ``CodexTurnReasoningSummaryTextDelta``
- ``CodexTurnReasoningTextDelta``
- ``CodexTurnCompletion``
