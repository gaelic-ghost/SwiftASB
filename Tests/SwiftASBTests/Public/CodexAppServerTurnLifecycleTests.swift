import Foundation
@testable import SwiftASB
import Testing

extension CodexAppServerTests {
    @Test("runs initialize, thread/start, and turn/start through the public client")
    func runsInitializeAndFirstLifecycleRequests() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()

        let initializeSession = try await client.initialize(
            .init(
                capabilities: .init(
                    experimentalAPI: true,
                    optOutNotificationMethods: ["turn/completed"]
                ),
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        #expect(initializeSession.codexHome == "/Users/galew/.codex")
        #expect(initializeSession.platformFamily == "unix")
        #expect(initializeSession.platformOS == "macos")
        #expect(initializeSession.userAgent == "codex-cli/0.128.0")

        let thread = try await client.startThread(
            .init(
                approvalPolicy: .onRequest,
                currentDirectoryPath: "/tmp/project",
                ephemeral: false,
                model: "gpt-5.4",
                modelProvider: "openai",
                sandboxMode: .workspaceWrite,
                serviceTier: .fast,
                sessionStartSource: .clear
            )
        )

        #expect(thread.model == "gpt-5.4")
        #expect(thread.modelProvider == "openai")
        #expect(thread.currentDirectoryPath == "/tmp/project")
        #expect(thread.serviceTier == .fast)
        #expect(thread.id == "thread-123")
        #expect(thread.info.status.type == .active)
        #expect(thread.info.preview == "Hello from the fake app-server")

        let turnHandle = try await thread.startTextTurn(
            "Hello from SwiftASB",
            effort: .medium,
            model: "gpt-5.4",
            permissions: .workspace,
            summary: .concise
        )

        #expect(turnHandle.threadID == thread.id)
        #expect(turnHandle.turn.id == "turn-123")
        #expect(turnHandle.turn.status == .inProgress)
        #expect(turnHandle.turn.startedAt == 1_713_350_002)

        let firstEventTask = Task {
            try await turnEvents(from: turnHandle.events, count: 9)
        }

        await transport.emitTurnStarted(
            threadID: thread.id,
            turnID: turnHandle.turn.id
        )
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-plan-1"
        )
        await transport.emitTurnPlanUpdated(
            threadID: thread.id,
            turnID: turnHandle.turn.id
        )
        await transport.emitPlanDelta(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-plan-1"
        )
        await transport.emitAgentMessageDelta(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-agent-1"
        )
        await transport.emitReasoningTextDelta(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-reasoning-1"
        )
        await transport.emitReasoningSummaryTextDelta(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-reasoning-1"
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-agent-1"
        )
        await transport.emitTurnCompleted(
            threadID: thread.id,
            turnID: turnHandle.turn.id
        )

        let receivedEvents = try await firstEventTask.value
        #expect(receivedEvents.count == 9)

        switch receivedEvents[0] {
            case let .started(started):
                #expect(started.threadID == thread.id)
                #expect(started.turn.id == turnHandle.turn.id)
                #expect(started.turn.status == .inProgress)
            default:
                Issue.record("Expected the first streamed event to be .started.")
        }

        switch receivedEvents[1] {
            case let .itemStarted(itemStarted):
                #expect(itemStarted.threadID == thread.id)
                #expect(itemStarted.turnID == turnHandle.turn.id)
                #expect(itemStarted.item.id == "item-plan-1")
                #expect(itemStarted.item.kind == .plan)
                #expect(itemStarted.item.text == nil)
            default:
                Issue.record("Expected the second streamed event to be .itemStarted.")
        }

        switch receivedEvents[2] {
            case let .planUpdated(update):
                #expect(update.threadID == thread.id)
                #expect(update.turnID == turnHandle.turn.id)
                #expect(update.explanation == "Map richer progress notifications.")
                #expect(update.plan.count == 2)
                #expect(update.plan.first?.status == .inProgress)
                #expect(update.plan.last?.status == .pending)
            default:
                Issue.record("Expected the third streamed event to be .planUpdated.")
        }

        switch receivedEvents[3] {
            case let .planDelta(delta):
                #expect(delta.threadID == thread.id)
                #expect(delta.turnID == turnHandle.turn.id)
                #expect(delta.itemID == "item-plan-1")
                #expect(delta.delta == "Stream partial plan text")
            default:
                Issue.record("Expected the fourth streamed event to be .planDelta.")
        }

        switch receivedEvents[4] {
            case let .agentMessageDelta(delta):
                #expect(delta.threadID == thread.id)
                #expect(delta.turnID == turnHandle.turn.id)
                #expect(delta.itemID == "item-agent-1")
                #expect(delta.delta == "Working on it")
            default:
                Issue.record("Expected the fifth streamed event to be .agentMessageDelta.")
        }

        switch receivedEvents[5] {
            case let .reasoningTextDelta(delta):
                #expect(delta.threadID == thread.id)
                #expect(delta.turnID == turnHandle.turn.id)
                #expect(delta.itemID == "item-reasoning-1")
                #expect(delta.contentIndex == 0)
                #expect(delta.delta == "thinking...")
            default:
                Issue.record("Expected the sixth streamed event to be .reasoningTextDelta.")
        }

        switch receivedEvents[6] {
            case let .reasoningSummaryTextDelta(delta):
                #expect(delta.threadID == thread.id)
                #expect(delta.turnID == turnHandle.turn.id)
                #expect(delta.itemID == "item-reasoning-1")
                #expect(delta.summaryIndex == 0)
                #expect(delta.delta == "Summarizing the approach.")
            default:
                Issue.record("Expected the seventh streamed event to be .reasoningSummaryTextDelta.")
        }

        switch receivedEvents[7] {
            case let .itemCompleted(itemCompleted):
                #expect(itemCompleted.threadID == thread.id)
                #expect(itemCompleted.turnID == turnHandle.turn.id)
                #expect(itemCompleted.item.id == "item-agent-1")
                #expect(itemCompleted.item.kind == .agentMessage)
                #expect(itemCompleted.item.text == "Done.")
                #expect(itemCompleted.item.status == "completed")
            default:
                Issue.record("Expected the eighth streamed event to be .itemCompleted.")
        }

        switch receivedEvents[8] {
            case let .completed(completion):
                #expect(completion.threadID == thread.id)
                #expect(completion.turn.id == turnHandle.turn.id)
                #expect(completion.turn.status == CodexAppServer.TurnStatus.completed)
                #expect(completion.turn.completedAt == 1_713_350_005)
            default:
                Issue.record("Expected the ninth streamed event to be .completed.")
        }

        let recordedMethods = await transport.recordedMethods
        #expect(recordedMethods == ["initialize", "initialized", "thread/start", "turn/start"])

        let turnStartPayload = try #require(await transport.recordedRequestPayload(for: "turn/start"))
        let turnStartRequest = try #require(try JSONSerialization.jsonObject(with: turnStartPayload) as? [String: Any])
        let turnStartParams = try #require(turnStartRequest["params"] as? [String: Any])
        #expect(turnStartParams["permissions"] as? String == ":workspace")

        await client.stop()
    }

    @Test("starts planning turns through collaboration mode")
    func startsPlanningTurnsThroughCollaborationMode() async throws {
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

        _ = try await thread.startPlanningTurn(
            "Map this before editing.",
            effort: .high
        )

        let turnStartPayload = try #require(await transport.recordedRequestPayload(for: "turn/start"))
        let turnStartRequest = try #require(try JSONSerialization.jsonObject(with: turnStartPayload) as? [String: Any])
        let turnStartParams = try #require(turnStartRequest["params"] as? [String: Any])
        let collaborationMode = try #require(turnStartParams["collaborationMode"] as? [String: Any])
        #expect(collaborationMode["mode"] as? String == "plan")
        let settings = try #require(collaborationMode["settings"] as? [String: Any])
        #expect(settings["model"] as? String == "gpt-5.4")
        #expect(settings["reasoning_effort"] as? String == "high")

        let input = try #require(turnStartParams["input"] as? [[String: Any]])
        #expect(input.first?["text"] as? String == "Map this before editing.")

        await client.stop()
    }

    @Test("persists sealed turn history in the internal thread history store")
    func persistsSealedTurnHistory() async throws {
        let transport = FakeCodexAppServerTransport()
        let historyStore = try ThreadHistoryStore(configuration: .inMemory())
        let client = CodexAppServer(
            transport: transport,
            historyStore: historyStore
        )

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
                approvalPolicy: .onRequest,
                currentDirectoryPath: "/tmp/project",
                ephemeral: false,
                model: "gpt-5.4",
                modelProvider: "openai",
                sandboxMode: .workspaceWrite,
                serviceTier: .fast
            )
        )

        let turn = try await thread.startTextTurn(
            "Summarize the project state.",
            approvalPolicy: .onRequest,
            summary: .concise
        )

        let eventTask = Task {
            try await turnEvents(from: turn.events, count: 7)
        }

        await transport.emitTurnStarted(threadID: thread.id, turnID: turn.turn.id)
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-plan-1"
        )
        await transport.emitPlanDelta(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-plan-1"
        )
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-agent-1",
            item: [
                "id": "item-agent-1",
                "type": "agentMessage",
            ]
        )
        await transport.emitAgentMessageDelta(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-agent-1"
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-agent-1"
        )
        await transport.emitThreadTokenUsageUpdated(
            threadID: thread.id,
            turnID: turn.turn.id
        )
        await transport.emitTurnCompleted(threadID: thread.id, turnID: turn.turn.id)
        _ = try await eventTask.value
        await transport.emitThreadNameUpdated(threadID: thread.id, threadName: nil)
        await transport.emitThreadClosed(threadID: thread.id)

        try await waitForCondition {
            let snapshot = try await client.debugThreadHistorySnapshot(threadID: thread.id)
            return snapshot?.isClosed == true && snapshot?.name == nil
        }

        let snapshot = try await client.debugThreadHistorySnapshot(threadID: thread.id)
        let threadSnapshot = try #require(snapshot)
        #expect(threadSnapshot.defaults.approvalPolicy == "onRequest")
        #expect(threadSnapshot.defaults.currentDirectoryPath == "/tmp/project")
        #expect(threadSnapshot.defaults.model == "gpt-5.4")
        #expect(threadSnapshot.defaults.serviceTier == "fast")
        #expect(threadSnapshot.state.completeness == "partial")
        #expect(threadSnapshot.isClosed == true)
        #expect(threadSnapshot.name == nil)
        #expect(threadSnapshot.turns.count == 1)
        #expect(threadSnapshot.turns[0].status == "completed")
        #expect(threadSnapshot.turns[0].items.count == 2)
        #expect(threadSnapshot.turns[0].items[0].kind == "plan")
        #expect(threadSnapshot.turns[0].items[0].streamedText == "Stream partial plan text")
        #expect(threadSnapshot.turns[0].items[1].kind == "agentMessage")
        #expect(threadSnapshot.turns[0].items[1].streamedText == "Working on it")
        #expect(threadSnapshot.turns[0].tokenUsage?.totalTokens == 65)

        await client.stop()
    }

    @Test("completes a turn handle into a final sealed turn snapshot")
    func completesTurnHandle() async throws {
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
                approvalPolicy: .onRequest,
                currentDirectoryPath: "/tmp/project",
                ephemeral: false,
                model: "gpt-5.4",
                modelProvider: "openai",
                sandboxMode: .workspaceWrite,
                serviceTier: .fast
            )
        )

        let turn = try await thread.startTextTurn("Summarize the project state.")
        let eventTask = Task {
            try await turnEvents(from: turn.events, count: 5)
        }

        await transport.emitTurnStarted(threadID: thread.id, turnID: turn.turn.id)
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-agent-1",
            item: [
                "id": "item-agent-1",
                "type": "agentMessage",
            ]
        )
        await transport.emitAgentMessageDelta(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-agent-1"
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-agent-1"
        )
        await transport.emitTurnCompleted(threadID: thread.id, turnID: turn.turn.id)
        _ = try await eventTask.value

        let closedTurn = try await turn.complete()
        #expect(closedTurn.id == turn.turn.id)
        #expect(closedTurn.threadID == thread.id)
        #expect(closedTurn.status == "completed")
        #expect(closedTurn.items.count == 1)
        #expect(closedTurn.items[0].text == "Done.")

        await client.stop()
    }

    @Test("completing a turn finishes its live turn stream")
    func completingTurnFinishesTurnStream() async throws {
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
                approvalPolicy: .onRequest,
                currentDirectoryPath: "/tmp/project",
                ephemeral: false,
                model: "gpt-5.4",
                modelProvider: "openai",
                sandboxMode: .workspaceWrite,
                serviceTier: .fast
            )
        )

        let turn = try await thread.startTextTurn("Summarize the project state.")
        let eventTask = Task {
            try await turnEvents(from: turn.events, count: 5)
        }

        await transport.emitTurnStarted(threadID: thread.id, turnID: turn.turn.id)
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-agent-1",
            item: [
                "id": "item-agent-1",
                "type": "agentMessage",
            ]
        )
        await transport.emitAgentMessageDelta(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-agent-1"
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-agent-1"
        )
        await transport.emitTurnCompleted(threadID: thread.id, turnID: turn.turn.id)
        _ = try await eventTask.value

        _ = try await turn.complete()
        let nextEvent = try await nextTurnEventOrEnd(from: turn.events)
        #expect(nextEvent == nil)

        await client.stop()
    }
}
