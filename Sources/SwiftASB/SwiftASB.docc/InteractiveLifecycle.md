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
    case let .diagnostic(diagnostic):
        renderDiagnostic(diagnostic)
    case let .approvalRequested(request):
        try await turn.respond(to: request, with: .commandExecution(.decline))
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

Diagnostics are passive runtime signals. They explain warnings, guardian warnings, model reroutes, and model verification results, but they are not requests that the app can answer. Observe app-wide diagnostics through ``CodexAppServer/diagnosticEvents()``, or handle targeted diagnostics from ``CodexThreadEvent/diagnostic(_:)`` and ``CodexTurnEvent/diagnostic(_:)``.

## Stream Semantics

Thread and turn streams are the canonical lifecycle surface. Observable companions are current-state mirrors built from those streams and from selected internal delta feeds.

``CodexThread/events`` buffers thread events until the handle stream is observed. If a terminal thread event arrives before observation, SwiftASB yields that terminal event and then finishes the stream. ``CodexTurnHandle/events`` buffers the earliest active-turn events that can arrive before callers start iterating, yields terminal completion before finishing, and otherwise behaves as a live stream.

``CodexAppServer/diagnosticEvents()`` buffers app-wide diagnostics until the first subscriber. Diagnostics are passive: they can be logged, rendered, or correlated with thread and turn identifiers, but they are not approval or elicitation requests.

Streams finish normally when SwiftASB stops the app-server through ``CodexAppServer/stop()``. If the app-server event feed fails unexpectedly, the public throwing streams finish by throwing a ``CodexAppServerError`` that describes the broken feed. Live-only observable companion inputs, such as command-output and file-output delta feeds, are not replayed if they arrive before the companion exists.

## Steering And Interruption

Use ``CodexTurnHandle/steerText(_:)`` when the user adds instructions to the active turn. Use ``CodexTurnHandle/interrupt()`` when the user intentionally stops it.

```swift
try await turn.steerText("Focus on public API changes.")
try await turn.interrupt()
```

SwiftASB rejects overlapping same-thread turns before they reach the app-server because live same-thread routing is not independently reliable today. Start another turn on the same thread only after the active handle completes, fails, or is interrupted.

## Completing The Handle

Use ``CodexTurnHandle/complete()`` when a caller wants a completed-turn value that no longer depends on the live handle. Use thread history helpers when the caller wants older completed turns from local storage.

## Topics

### Walkthroughs

- <doc:GettingStartedWithSwiftASB>
- <doc:HandlingTurnProgressAndApprovals>
- <doc:ReadingDiagnosticsAndHistory>
- <doc:SwiftUIObservableCompanions>

### Handles

- ``CodexAppServer``
- ``CodexThread``
- ``CodexTurnHandle``

### Events

- ``CodexThreadEvent``
- ``CodexTurnEvent``
- ``CodexDiagnosticEvent``

### Requests And Responses

- ``CodexApprovalRequest``
- ``CodexApprovalResponse``
- ``CodexElicitationRequest``
- ``CodexElicitationResponse``
