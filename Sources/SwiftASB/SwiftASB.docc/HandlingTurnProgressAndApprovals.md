# Handling Turn Progress And Approvals

Render streamed turn events and answer server-originated requests from the owning turn handle.

## Overview

A ``CodexTurnHandle`` is the active-turn owner. Its ``CodexTurnHandle/events`` stream reports model progress, tool and file activity, diagnostics, approval requests, elicitation requests, request resolutions, and terminal completion.

When an event asks for approval or user input, respond through the same handle when the request belongs to that active turn. SwiftASB validates the thread and turn identifiers before sending the answer back to the app-server.

```swift
func runWritableTurn(thread: CodexThread) async throws {
    let turn = try await thread.startTextTurn(
        "Create a short NOTES.md file with the current project summary.",
        approvalPolicy: .onRequest,
        approvalsReviewer: .user
    )

    for try await event in turn.events {
        switch event {
        case let .planUpdated(update):
            renderPlan(update.plan.map(\.step))

        case let .diffUpdated(update):
            renderDiff(update.diff)

        case let .approvalRequested(request):
            try await answerApproval(request, through: turn)

        case let .elicitationRequested(request):
            try await answerElicitation(request, through: turn)

        case let .serverRequestResolved(resolution):
            markRequestResolved(resolution.kind)

        case let .diagnostic(diagnostic):
            renderDiagnostic(diagnostic)

        case let .completed(completion):
            renderStatus(completion.turn.status)
            return

        default:
            continue
        }
    }
}

func answerApproval(
    _ request: CodexApprovalRequest,
    through turn: CodexTurnHandle
) async throws {
    switch request {
    case .commandExecution:
        try await turn.respond(to: request, with: .commandExecution(.decline))

    case .fileChange:
        try await turn.respond(to: request, with: .fileChange(.accept))

    case .guardianDeniedAction:
        try await turn.respond(to: request, with: .guardianDeniedAction(.approve))

    case let .permissions(permissions):
        try await turn.respond(
            to: request,
            with: .permissions(.init(permissions: permissions.permissions))
        )
    }
}

func answerElicitation(
    _ request: CodexElicitationRequest,
    through turn: CodexTurnHandle
) async throws {
    switch request {
    case let .toolUserInput(input):
        let answers = Dictionary(
            uniqueKeysWithValues: input.questions.map { question in
                (question.id, CodexToolUserInputResponse.Answer(answers: []))
            }
        )
        try await turn.respond(
            to: request,
            with: .toolUserInput(.init(answers: answers))
        )

    case .mcpServer:
        try await turn.respond(
            to: request,
            with: .mcpServer(.init(action: .cancel))
        )
    }
}
```

## Thread-Routed Requests

Some requests are thread-scoped rather than active-turn scoped. Use ``CodexThread/respond(to:with:)-(CodexApprovalRequest,_)`` or ``CodexThread/respond(to:with:)-(CodexElicitationRequest,_)`` for those requests. SwiftASB rejects responses sent through the wrong owner so consumers do not accidentally resolve a request from the wrong thread or turn.

## Completion Handoff

Use ``CodexTurnHandle/complete()`` after the live turn has reached terminal state when the caller wants a sealed ``CodexTurnHandle/ClosedTurn`` snapshot. Use ``CodexThread`` history helpers for older completed turns.

## Topics

### Event Stream

- ``CodexTurnHandle/events``
- ``CodexTurnEvent``
- ``CodexTurnCompletion``

### Requests

- ``CodexApprovalRequest``
- ``CodexApprovalResponse``
- ``CodexElicitationRequest``
- ``CodexElicitationResponse``
- ``CodexInteractiveRequestResolved``

### Responses

- ``CodexTurnHandle/respond(to:with:)-(CodexApprovalRequest,_)``
- ``CodexTurnHandle/respond(to:with:)-(CodexElicitationRequest,_)``
- ``CodexThread/respond(to:with:)-(CodexApprovalRequest,_)``
- ``CodexThread/respond(to:with:)-(CodexElicitationRequest,_)``
