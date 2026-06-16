import Foundation
@testable import SwiftASB
import Testing

extension CodexAppServerTests {
    @Test("interrupts a turn through CodexTurnHandle")
    func interruptsTurnThroughHandle() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()
        _ = try await client.initialize(
            .init(
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        let thread = try await client.startThread(
            .init(
                currentDirectoryPath: "/tmp/project",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )
        let turnHandle = try await thread.startTextTurn("Please stop when asked.")

        try await turnHandle.interrupt()

        let recordedMethods = await transport.recordedMethods
        #expect(
            recordedMethods == [
                "initialize",
                "initialized",
                "thread/start",
                "turn/start",
                "turn/interrupt",
            ]
        )

        let interruptRequest = try #require(await transport.recordedRequestPayload(for: "turn/interrupt"))
        let requestObject = try #require(
            try JSONSerialization.jsonObject(with: interruptRequest) as? [String: Any]
        )
        let params = try #require(requestObject["params"] as? [String: Any])
        #expect(params["threadId"] as? String == thread.id)
        #expect(params["turnId"] as? String == turnHandle.turn.id)

        await client.stop()
    }

    @Test("steers a turn through CodexTurnHandle")
    func steersTurnThroughHandle() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()
        _ = try await client.initialize(
            .init(
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        let thread = try await client.startThread(
            .init(
                currentDirectoryPath: "/tmp/project",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )
        let turnHandle = try await thread.startTextTurn("Please draft an answer.")

        try await turnHandle.steerText("Please make it shorter and more direct.")

        let recordedMethods = await transport.recordedMethods
        #expect(
            recordedMethods == [
                "initialize",
                "initialized",
                "thread/start",
                "turn/start",
                "turn/steer",
            ]
        )

        let steerRequest = try #require(await transport.recordedRequestPayload(for: "turn/steer"))
        let requestObject = try #require(
            try JSONSerialization.jsonObject(with: steerRequest) as? [String: Any]
        )
        let params = try #require(requestObject["params"] as? [String: Any])
        #expect(params["threadId"] as? String == thread.id)
        #expect(params["expectedTurnId"] as? String == turnHandle.turn.id)

        let input = try #require(params["input"] as? [[String: Any]])
        #expect(input.count == 1)
        #expect(input.first?["type"] as? String == "text")
        #expect(input.first?["text"] as? String == "Please make it shorter and more direct.")

        await client.stop()
    }

    @Test("compacts thread context through CodexThread")
    func compactsThreadContextThroughThreadHandle() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()
        _ = try await client.initialize(
            .init(
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        let thread = try await client.startThread(
            .init(
                currentDirectoryPath: "/tmp/project",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )

        try await thread.compactContext()

        let recordedMethods = await transport.recordedMethods
        #expect(recordedMethods == ["initialize", "initialized", "thread/start", "thread/compact/start"])

        let compactRequest = try #require(await transport.recordedRequestPayload(for: "thread/compact/start"))
        let requestObject = try #require(
            try JSONSerialization.jsonObject(with: compactRequest) as? [String: Any]
        )
        let params = try #require(requestObject["params"] as? [String: Any])
        #expect(params["threadId"] as? String == thread.id)

        await client.stop()
    }

    @Test("rejects overlapping same-thread turn starts until the active turn completes")
    func rejectsOverlappingSameThreadTurns() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        do {
            try await client.start()
            _ = try await client.initialize(
                .init(
                    clientInfo: .init(
                        name: "SwiftASBTests",
                        title: "SwiftASB Tests",
                        version: "0.1.0"
                    )
                )
            )

            let thread = try await client.startThread(
                .init(
                    currentDirectoryPath: "/tmp/project",
                    model: "gpt-5.4",
                    modelProvider: "openai"
                )
            )

            let firstTurn = try await thread.startTextTurn("First live turn")
            #expect(firstTurn.turn.id == "turn-123")

            do {
                _ = try await thread.startTextTurn("Second overlapping live turn")
                Issue.record("Expected overlapping same-thread turn start to be rejected.")
            } catch let error as CodexAppServerError {
                switch error {
                    case let .invalidState(reason):
                        #expect(reason.contains("overlapping same-thread turns") || reason.contains("already has an active turn"))
                    default:
                        Issue.record("Expected overlapping same-thread turn start to throw an invalidState error.")
                }
            }

            let recordedMethodsBeforeCompletion = await transport.recordedMethods
            #expect(recordedMethodsBeforeCompletion == ["initialize", "initialized", "thread/start", "turn/start"])

            let completionTask = Task {
                for try await event in firstTurn.events {
                    if case let .completed(completion) = event {
                        return completion
                    }
                }

                Issue.record("Expected the first turn event stream to finish with a completed event.")
                throw CancellationError()
            }

            await transport.emitTurnCompleted(
                threadID: thread.id,
                turnID: firstTurn.turn.id
            )
            let completion = try await completionTask.value
            #expect(completion.turn.id == firstTurn.turn.id)
            #expect(completion.threadID == thread.id)

            let secondTurn = try await thread.startTextTurn("Second live turn after completion")
            #expect(secondTurn.turn.id == "turn-123")

            let recordedMethodsAfterCompletion = await transport.recordedMethods
            #expect(recordedMethodsAfterCompletion == ["initialize", "initialized", "thread/start", "turn/start", "turn/start"])

            await client.stop()
        } catch {
            await client.stop()
            throw error
        }
    }

    @Test("buffers early interactive turn events and answers command approvals through CodexTurnHandle")
    func buffersInteractiveTurnEventsAndAnswersApproval() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()
        _ = try await client.initialize(
            .init(
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        let thread = try await client.startThread(
            .init(
                currentDirectoryPath: "/tmp/project",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )

        let turnHandle = try await thread.startTextTurn("Review the patch.")
        var iterator = turnHandle.events.makeAsyncIterator()
        await transport.emitCommandExecutionApprovalRequest(
            requestID: .string("approval-1"),
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-command-1"
        )

        let firstEvent = try await iterator.next()
        guard case let .approvalRequested(approvalRequest)? = firstEvent else {
            Issue.record("Expected the first buffered turn event to be .approvalRequested.")
            await client.stop()
            return
        }
        guard case let .commandExecution(commandRequest) = approvalRequest else {
            Issue.record("Expected the buffered approval request to be a command execution approval.")
            await client.stop()
            return
        }

        #expect(commandRequest.threadID == thread.id)
        #expect(commandRequest.turnID == turnHandle.turn.id)
        #expect(commandRequest.itemID == "item-command-1")
        #expect(commandRequest.command == "git status")
        #expect(commandRequest.reason == "Needs approval to read repository state.")

        try await turnHandle.respond(
            to: approvalRequest,
            with: .commandExecution(.acceptWithExecPolicyAmendment(["workspace-write"]))
        )

        await transport.emitServerRequestResolved(
            threadID: thread.id,
            requestID: .string("approval-1")
        )

        let secondEvent = try await iterator.next()
        guard case let .serverRequestResolved(resolution)? = secondEvent else {
            Issue.record("Expected the follow-up turn event to be .serverRequestResolved.")
            await client.stop()
            return
        }

        #expect(resolution.threadID == thread.id)
        #expect(resolution.turnID == turnHandle.turn.id)
        #expect(resolution.kind == .commandExecutionApproval)

        let recordedResponses = await transport.recordedResponses
        #expect(recordedResponses.count == 1)
        #expect(recordedResponses.first?.requestID == .string("approval-1"))
        let responseObject = try #require(
            try JSONSerialization.jsonObject(with: recordedResponses[0].payload) as? [String: Any]
        )
        #expect(responseObject["id"] as? String == "approval-1")
        let responseResult = try #require(responseObject["result"] as? [String: Any])
        let decision = try #require(responseResult["decision"] as? [String: Any])
        let amendment = try #require(decision["acceptWithExecpolicyAmendment"] as? [String: Any])
        #expect(amendment["execpolicy_amendment"] as? [String] == ["workspace-write"])

        await client.stop()
    }

    @Test("surfaces denied guardian auto-review as an approval request")
    func surfacesDeniedGuardianAutoReviewAsApprovalRequest() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()
        _ = try await client.initialize(
            .init(
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        let thread = try await client.startThread(
            .init(
                currentDirectoryPath: "/tmp/project",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )

        let turnHandle = try await thread.startTextTurn("Fetch the protected endpoint.")
        var iterator = turnHandle.events.makeAsyncIterator()
        await transport.emitGuardianAutoReviewCompleted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            reviewID: "review-guardian-1",
            status: "denied",
            targetItemID: nil
        )

        let firstEvent = try await iterator.next()
        guard case let .approvalRequested(approvalRequest)? = firstEvent else {
            Issue.record("Expected denied guardian auto-review to surface as .approvalRequested.")
            await client.stop()
            return
        }
        guard case let .guardianDeniedAction(guardianRequest) = approvalRequest else {
            Issue.record("Expected a guardian denied-action approval request.")
            await client.stop()
            return
        }

        #expect(guardianRequest.threadID == thread.id)
        #expect(guardianRequest.turnID == turnHandle.turn.id)
        #expect(guardianRequest.reviewID == "review-guardian-1")
        #expect(guardianRequest.review.status == .denied)
        #expect(guardianRequest.review.riskLevel == .medium)
        #expect(guardianRequest.action.type == .networkAccess)
        #expect(guardianRequest.action.host == "api.example.com")
        #expect(guardianRequest.action.networkProtocol == .https)

        try await turnHandle.respond(
            to: approvalRequest,
            with: .guardianDeniedAction(.approve)
        )

        let secondEvent = try await iterator.next()
        guard case let .serverRequestResolved(resolution)? = secondEvent else {
            Issue.record("Expected approving a guardian denied action to resolve the approval request.")
            await client.stop()
            return
        }

        #expect(resolution.threadID == thread.id)
        #expect(resolution.turnID == turnHandle.turn.id)
        #expect(resolution.kind == .guardianDeniedActionApproval)

        let requestPayloads = await transport.requestPayloads(for: "thread/approveGuardianDeniedAction")
        #expect(requestPayloads.count == 1)
        let requestObject = try #require(
            try JSONSerialization.jsonObject(with: requestPayloads[0]) as? [String: Any]
        )
        #expect(requestObject["method"] as? String == "thread/approveGuardianDeniedAction")
        let params = try #require(requestObject["params"] as? [String: Any])
        #expect(params["threadId"] as? String == thread.id)
        let event = try #require(params["event"] as? [String: Any])
        #expect(event["reviewId"] as? String == "review-guardian-1")
        let review = try #require(event["review"] as? [String: Any])
        #expect(review["status"] as? String == "denied")

        await client.stop()
    }

    @Test("rejects interactive approval responses sent through the wrong surface")
    func rejectsApprovalResponsesSentThroughWrongSurface() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()
        _ = try await client.initialize(
            .init(
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        let thread = try await client.startThread(
            .init(
                currentDirectoryPath: "/tmp/project",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )

        let turnHandle = try await thread.startTextTurn("Review the patch.")
        await transport.emitCommandExecutionApprovalRequest(
            requestID: .string("approval-1"),
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-command-1"
        )

        guard case let .approvalRequested(approvalRequest)? = try await turnHandle.events.first(where: { _ in true }) else {
            Issue.record("Expected a turn-scoped approval request.")
            await client.stop()
            return
        }

        do {
            try await thread.respond(
                to: approvalRequest,
                with: .commandExecution(.accept)
            )
            Issue.record("Expected a turn-scoped approval response sent through CodexThread to fail.")
        } catch let error as CodexAppServerError {
            guard case let .invalidState(reason) = error else {
                Issue.record("Expected an invalidState error for the wrong response surface.")
                await client.stop()
                return
            }

            #expect(reason.contains("belongs to a specific turn"))
            #expect(reason.contains("CodexTurnHandle"))
        }

        #expect(await transport.recordedResponses.isEmpty)

        await client.stop()
    }

    @Test("rejects mismatched and already resolved approval responses")
    func rejectsMismatchedAndResolvedApprovalResponses() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()
        _ = try await client.initialize(
            .init(
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        let thread = try await client.startThread(
            .init(
                currentDirectoryPath: "/tmp/project",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )

        let turnHandle = try await thread.startTextTurn("Review the patch.")
        var iterator = turnHandle.events.makeAsyncIterator()
        await transport.emitCommandExecutionApprovalRequest(
            requestID: .string("approval-1"),
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-command-1"
        )

        guard case let .approvalRequested(approvalRequest)? = try await iterator.next() else {
            Issue.record("Expected a command approval request.")
            await client.stop()
            return
        }

        do {
            try await turnHandle.respond(
                to: approvalRequest,
                with: .fileChange(.accept)
            )
            Issue.record("Expected a mismatched approval response kind to fail.")
        } catch let error as CodexAppServerError {
            guard case let .invalidState(reason) = error else {
                Issue.record("Expected an invalidState error for a mismatched approval response kind.")
                await client.stop()
                return
            }

            #expect(reason.contains("response kind did not match"))
        }

        #expect(await transport.recordedResponses.isEmpty)

        try await turnHandle.respond(
            to: approvalRequest,
            with: .commandExecution(.accept)
        )
        await transport.emitServerRequestResolved(
            threadID: thread.id,
            requestID: .string("approval-1")
        )

        guard case .serverRequestResolved? = try await iterator.next() else {
            Issue.record("Expected the command approval request to resolve.")
            await client.stop()
            return
        }

        do {
            try await turnHandle.respond(
                to: approvalRequest,
                with: .commandExecution(.accept)
            )
            Issue.record("Expected responding to an already resolved approval request to fail.")
        } catch let error as CodexAppServerError {
            guard case let .invalidState(reason) = error else {
                Issue.record("Expected an invalidState error for an already resolved approval response.")
                await client.stop()
                return
            }

            #expect(reason.contains("No outstanding interactive server request"))
        }

        #expect(await transport.recordedResponses.count == 1)

        await client.stop()
    }

    @Test("rejects interactive approval responses through the wrong thread route")
    func rejectsApprovalResponsesThroughWrongThreadRoute() async throws {
        let transport = FakeCodexAppServerTransport(
            threadStartIDQueue: ["thread-route-a", "thread-route-b"]
        )
        let client = CodexAppServer(transport: transport)

        try await client.start()
        _ = try await client.initialize(
            .init(
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        let firstThread = try await client.startThread(
            .init(
                currentDirectoryPath: "/tmp/project-a",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )
        let firstTurn = try await firstThread.startTextTurn("Review the first patch.")
        await transport.emitCommandExecutionApprovalRequest(
            requestID: .string("approval-1"),
            threadID: firstThread.id,
            turnID: firstTurn.turn.id,
            itemID: "item-command-1"
        )

        guard case let .approvalRequested(approvalRequest)? = try await firstTurn.events.first(where: { _ in true }) else {
            Issue.record("Expected a turn-scoped approval request on the first thread.")
            await client.stop()
            return
        }

        let secondThread = try await client.startThread(
            .init(
                currentDirectoryPath: "/tmp/project-b",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )
        let secondTurn = try await secondThread.startTextTurn("Review the second patch.")

        do {
            try await secondTurn.respond(
                to: approvalRequest,
                with: .commandExecution(.accept)
            )
            Issue.record("Expected a response through a different active turn route to fail.")
        } catch let error as CodexAppServerError {
            guard case let .invalidState(reason) = error else {
                Issue.record("Expected an invalidState error for a mismatched active thread route.")
                await client.stop()
                return
            }

            #expect(reason.contains("belongs to thread \(firstThread.id)"))
            #expect(reason.contains("not thread \(secondThread.id)"))
        }

        #expect(await transport.recordedResponses.isEmpty)

        await client.stop()
    }

    @Test("routes unroutable MCP elicitation requests through CodexThread and answers them there")
    func routesUnroutableMcpElicitationsThroughThread() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()
        _ = try await client.initialize(
            .init(
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        let thread = try await client.startThread(
            .init(
                currentDirectoryPath: "/tmp/project",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )

        var iterator = thread.events.makeAsyncIterator()

        await transport.emitMcpServerElicitationRequest(
            requestID: .string("mcp-1"),
            threadID: thread.id,
            turnID: nil
        )

        let firstEvent = try await iterator.next()
        guard case let .elicitationRequested(request)? = firstEvent else {
            Issue.record("Expected the first thread event to be .elicitationRequested.")
            await client.stop()
            return
        }
        guard case let .mcpServer(mcpRequest) = request else {
            Issue.record("Expected the thread elicitation event to contain an MCP server request.")
            await client.stop()
            return
        }

        #expect(mcpRequest.threadID == thread.id)
        #expect(mcpRequest.turnID == nil)
        #expect(mcpRequest.serverName == "calendar")

        try await thread.respond(
            to: request,
            with: .mcpServer(.init(action: .decline))
        )

        await transport.emitServerRequestResolved(
            threadID: thread.id,
            requestID: .string("mcp-1")
        )

        let secondEvent = try await iterator.next()
        guard case let .serverRequestResolved(resolution)? = secondEvent else {
            Issue.record("Expected the follow-up thread event to be .serverRequestResolved.")
            await client.stop()
            return
        }

        #expect(resolution.threadID == thread.id)
        #expect(resolution.turnID == nil)
        #expect(resolution.kind == .mcpServerElicitation)

        let recordedResponses = await transport.recordedResponses
        #expect(recordedResponses.count == 1)
        #expect(recordedResponses.first?.requestID == .string("mcp-1"))
        let responseObject = try #require(
            try JSONSerialization.jsonObject(with: recordedResponses[0].payload) as? [String: Any]
        )
        let responseResult = try #require(responseObject["result"] as? [String: Any])
        #expect(responseResult["action"] as? String == "decline")

        await client.stop()
    }

    @Test("answers tool user input requests through CodexTurnHandle")
    func answersToolUserInputRequests() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()
        _ = try await client.initialize(
            .init(
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        let thread = try await client.startThread(
            .init(
                currentDirectoryPath: "/tmp/project",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )

        let turnHandle = try await thread.startTextTurn("Ask the user a question.")
        let eventTask = Task {
            try await turnEvents(from: turnHandle.events, count: 1)
        }

        await transport.emitToolUserInputRequest(
            requestID: .string("input-1"),
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-input-1"
        )

        let receivedEvents = try await eventTask.value
        guard case let .elicitationRequested(request) = receivedEvents[0] else {
            Issue.record("Expected the turn event to be .elicitationRequested.")
            await client.stop()
            return
        }
        guard case let .toolUserInput(inputRequest) = request else {
            Issue.record("Expected the elicitation event to contain a tool user input request.")
            await client.stop()
            return
        }

        #expect(inputRequest.questions.count == 1)
        #expect(inputRequest.questions[0].header == "Goal")
        #expect(inputRequest.questions[0].options?.count == 2)

        try await turnHandle.respond(
            to: request,
            with: .toolUserInput(
                .init(
                    answers: [
                        "goal": .init(answers: ["Ship it"]),
                    ]
                )
            )
        )

        let recordedResponses = await transport.recordedResponses
        #expect(recordedResponses.count == 1)
        #expect(recordedResponses.first?.requestID == .string("input-1"))
        let responseObject = try #require(
            try JSONSerialization.jsonObject(with: recordedResponses[0].payload) as? [String: Any]
        )
        let responseResult = try #require(responseObject["result"] as? [String: Any])
        let answers = try #require(responseResult["answers"] as? [String: Any])
        let goalAnswer = try #require(answers["goal"] as? [String: Any])
        #expect(goalAnswer["answers"] as? [String] == ["Ship it"])

        await client.stop()
    }
}
