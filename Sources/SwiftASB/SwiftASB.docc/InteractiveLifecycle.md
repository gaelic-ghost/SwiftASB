# Interactive Lifecycle

Start the app-server, create or resume a thread, start a turn, handle streamed events, and answer server-originated requests.

## Overview

The interactive path starts with ``CodexAppServer`` and narrows as the work becomes more specific. The app-server actor owns the subprocess and protocol. A ``CodexThread`` owns one conversation. A ``CodexTurnHandle`` owns one active response from the model and tools.

```swift
let appServer = CodexAppServer()
try await appServer.start()

defer {
    Task { await appServer.stop() }
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

let thread = try await appServer.startThread()
let turn = try await thread.startTextTurn("Explain the current repository state.")
```

## Event Handling

Turn events are delivered through ``CodexTurnHandle/events``. Consumers can render streamed updates directly, feed their own state model, or use ``CodexTurnHandle/Minimap`` for a ready-made observable current-state mirror.

```swift
for try await event in turn.events {
    switch event {
    case let .planUpdated(update):
        renderPlan(update.plan)
    case let .diffUpdated(update):
        renderDiff(update.diff)
    case let .approvalRequested(request):
        try await turn.respond(to: request, with: .commandExecution(.deny))
    case let .elicitationRequested(request):
        try await turn.respond(to: request, with: .toolUserInput(.init(answers: [:])))
    case let .completed(completion):
        renderStatus(completion.turn.status)
        return
    default:
        continue
    }
}
```

## Steering And Interruption

Use ``CodexTurnHandle/steerText(_:)`` when the user adds instructions to the active turn. Use ``CodexTurnHandle/interrupt()`` when the user intentionally stops it.

```swift
try await turn.steerText("Focus on public API changes.")
try await turn.interrupt()
```

SwiftASB rejects overlapping same-thread turns before they reach the app-server because live same-thread routing is not independently reliable today. Start another turn on the same thread only after the active handle completes, fails, is interrupted, or is closed.

## Closing The Handle

Use ``CodexTurnHandle/close()`` when a caller wants a completed-turn value that no longer depends on the live handle. Use thread history helpers when the caller wants older completed turns from local storage.

## Topics

### Handles

- ``CodexAppServer``
- ``CodexThread``
- ``CodexTurnHandle``

### Events

- ``CodexThreadEvent``
- ``CodexTurnEvent``

### Requests And Responses

- ``CodexApprovalRequest``
- ``CodexApprovalResponse``
- ``CodexElicitationRequest``
- ``CodexElicitationResponse``
