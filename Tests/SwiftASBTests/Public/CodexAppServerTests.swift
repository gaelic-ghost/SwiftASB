import Foundation
import Testing
@testable import SwiftASB

@Suite("CodexAppServer")
struct CodexAppServerTests {
    @Test("requires initialize before starting a thread")
    func requiresInitializeBeforeStartingThread() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()

        await #expect(throws: CodexAppServerError.self) {
            try await client.startThread()
        }

        await client.stop()
    }

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
        #expect(initializeSession.userAgent == "codex-cli/0.121.0")

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
            summary: .concise
        )

        #expect(turnHandle.threadID == thread.id)
        #expect(turnHandle.turn.id == "turn-123")
        #expect(turnHandle.turn.status == .inProgress)
        #expect(turnHandle.turn.startedAt == 1713350002)

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
            #expect(completion.turn.completedAt == 1713350005)
        default:
            Issue.record("Expected the ninth streamed event to be .completed.")
        }

        let recordedMethods = await transport.recordedMethods
        #expect(recordedMethods == ["initialize", "initialized", "thread/start", "turn/start"])

        await client.stop()
    }

    @Test("streams thread lifecycle notifications through CodexThread.events")
    func streamsThreadLifecycleNotifications() async throws {
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

        let threadEventsTask = Task {
            try await threadEvents(from: thread.events, count: 7)
        }

        await transport.emitThreadStarted(threadID: thread.id)
        await transport.emitThreadStatusChanged(threadID: thread.id)
        await transport.emitThreadArchived(threadID: thread.id)
        await transport.emitThreadUnarchived(threadID: thread.id)
        await transport.emitThreadNameUpdated(threadID: thread.id)
        await transport.emitThreadTokenUsageUpdated(threadID: thread.id, turnID: "turn-123")
        await transport.emitThreadClosed(threadID: thread.id)

        let receivedEvents = try await threadEventsTask.value
        #expect(receivedEvents.count == 7)

        switch receivedEvents[0] {
        case let .started(started):
            #expect(started.thread.id == thread.id)
            #expect(started.thread.preview == "Hello from thread/started")
        default:
            Issue.record("Expected the first thread event to be .started.")
        }

        switch receivedEvents[1] {
        case let .statusChanged(change):
            #expect(change.threadID == thread.id)
            #expect(change.status.type == .active)
            #expect(change.status.activeFlags == [.waitingOnApproval])
        default:
            Issue.record("Expected the second thread event to be .statusChanged.")
        }

        switch receivedEvents[2] {
        case let .archived(event):
            #expect(event.threadID == thread.id)
        default:
            Issue.record("Expected the third thread event to be .archived.")
        }

        switch receivedEvents[3] {
        case let .unarchived(event):
            #expect(event.threadID == thread.id)
        default:
            Issue.record("Expected the fourth thread event to be .unarchived.")
        }

        switch receivedEvents[4] {
        case let .nameUpdated(update):
            #expect(update.threadID == thread.id)
            #expect(update.threadName == "Planning Thread")
        default:
            Issue.record("Expected the fifth thread event to be .nameUpdated.")
        }

        switch receivedEvents[5] {
        case let .tokenUsageUpdated(update):
            #expect(update.threadID == thread.id)
            #expect(update.turnID == "turn-123")
            #expect(update.last.totalTokens == 65)
            #expect(update.total.totalTokens == 650)
            #expect(update.modelContextWindow == 200000)
        default:
            Issue.record("Expected the sixth thread event to be .tokenUsageUpdated.")
        }

        switch receivedEvents[6] {
        case let .closed(event):
            #expect(event.threadID == thread.id)
        default:
            Issue.record("Expected the seventh thread event to be .closed.")
        }

        await client.stop()
    }

    @MainActor
    @Test("builds a dashboard that stays live with thread events")
    func buildsThreadDashboard() async throws {
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

        let dashboard = await thread.makeDashboard()

        #expect(dashboard.threadID == thread.id)
        #expect(dashboard.name == nil)
        #expect(dashboard.preview == "Hello from the fake app-server")
        #expect(dashboard.status.type == .active)
        #expect(dashboard.isArchived == false)
        #expect(dashboard.isClosed == false)
        #expect(dashboard.latestTokenUsage == nil)

        await transport.emitThreadStarted(threadID: thread.id)
        await transport.emitThreadStatusChanged(threadID: thread.id)
        await transport.emitThreadNameUpdated(threadID: thread.id)
        await transport.emitThreadArchived(threadID: thread.id)
        await transport.emitThreadTokenUsageUpdated(threadID: thread.id, turnID: "turn-123")
        await transport.emitThreadClosed(threadID: thread.id)

        for _ in 0..<20 {
            if dashboard.name == "Planning Thread",
               dashboard.isArchived,
               dashboard.isClosed,
               dashboard.latestTokenUsage?.turnID == "turn-123" {
                break
            }
            await Task.yield()
        }

        #expect(dashboard.name == "Planning Thread")
        #expect(dashboard.preview == "Hello from thread/started")
        #expect(dashboard.status.type == .active)
        #expect(dashboard.status.activeFlags == [.waitingOnApproval])
        #expect(dashboard.isArchived == true)
        #expect(dashboard.isClosed == true)
        #expect(dashboard.latestTokenUsage?.turnID == "turn-123")
        #expect(dashboard.latestTokenUsage?.total.totalTokens == 650)

        await client.stop()
    }

    @MainActor
    @Test("builds a minimap that stays live with turn events")
    func buildsTurnMinimap() async throws {
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

        let turnHandle = try await thread.startTextTurn("Hello from SwiftASB")
        let minimap = await turnHandle.makeMinimap()

        #expect(minimap.threadID == thread.id)
        #expect(minimap.turnID == turnHandle.turn.id)
        #expect(minimap.currentTurn.id == turnHandle.turn.id)
        #expect(minimap.currentTurn.status == .inProgress)
        #expect(minimap.latestPlanUpdate == nil)
        #expect(minimap.latestAgentMessageDelta == nil)
        #expect(minimap.latestCompletion == nil)

        await transport.emitTurnStarted(
            threadID: thread.id,
            turnID: turnHandle.turn.id
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
        await transport.emitTurnCompleted(
            threadID: thread.id,
            turnID: turnHandle.turn.id
        )

        for _ in 0..<20 {
            if minimap.latestPlanUpdate != nil,
               minimap.latestAgentMessageDelta != nil,
               minimap.latestReasoningTextDelta != nil,
               minimap.latestCompletion != nil {
                break
            }
            await Task.yield()
        }

        #expect(minimap.latestStartedTurn?.turn.id == turnHandle.turn.id)
        #expect(minimap.latestPlanUpdate?.turnID == turnHandle.turn.id)
        #expect(minimap.latestPlanDelta?.itemID == "item-plan-1")
        #expect(minimap.latestAgentMessageDelta?.itemID == "item-agent-1")
        #expect(minimap.latestReasoningTextDelta?.itemID == "item-reasoning-1")
        #expect(minimap.latestCompletion?.turn.id == turnHandle.turn.id)
        #expect(minimap.currentTurn.status == .completed)

        await client.stop()
    }

}

private actor FakeCodexAppServerTransport: CodexAppServerTransporting {
    private(set) var recordedMethods: [String] = []
    private var started = false
    private var initializedSeen = false
    private var serverEventContinuation: AsyncStream<CodexRPCServerEvent>.Continuation?

    func start() throws {
        started = true
        initializedSeen = false
    }

    func stop() {
        started = false
        serverEventContinuation?.finish()
        serverEventContinuation = nil
    }

    func send(_ requestPayload: Data, id: CodexRPCRequestID) async throws -> Data {
        guard started else {
            throw CodexTransportError.notStarted
        }

        let method = try requestMethod(from: requestPayload)
        recordedMethods.append(method)

        switch method {
        case "initialize":
            return responsePayload(
                id: id,
                result: [
                    "codexHome": "/Users/galew/.codex",
                    "platformFamily": "unix",
                    "platformOs": "macos",
                    "userAgent": "codex-cli/0.121.0",
                ]
            )
        case "thread/start":
            if !initializedSeen {
                return errorPayload(
                    id: id,
                    code: -32000,
                    message: "initialized notification missing"
                )
            }

            return responsePayload(
                id: id,
                result: [
                    "approvalPolicy": "on-request",
                    "approvalsReviewer": "user",
                    "cwd": "/tmp/project",
                    "instructionSources": ["AGENTS.md"],
                    "model": "gpt-5.4",
                    "modelProvider": "openai",
                    "reasoningEffort": "medium",
                    "sandbox": [
                        "type": "workspaceWrite",
                        "networkAccess": "enabled",
                        "writableRoots": ["/tmp/project"],
                    ],
                    "serviceTier": "fast",
                    "thread": [
                        "cliVersion": "0.121.0",
                        "createdAt": 1713350000,
                        "cwd": "/tmp/project",
                        "ephemeral": false,
                        "id": "thread-123",
                        "modelProvider": "openai",
                        "preview": "Hello from the fake app-server",
                        "source": "cli",
                        "status": ["type": "active"],
                        "turns": [],
                        "updatedAt": 1713350001,
                    ],
                ]
            )
        case "turn/start":
            return responsePayload(
                id: id,
                result: [
                    "turn": [
                        "completedAt": NSNull(),
                        "durationMs": NSNull(),
                        "error": NSNull(),
                        "id": "turn-123",
                        "items": [],
                        "startedAt": 1713350002,
                        "status": "inProgress",
                    ],
                ]
            )
        default:
            return errorPayload(
                id: id,
                code: -32601,
                message: "unsupported method in fake transport"
            )
        }
    }

    func sendNotification(_ notificationPayload: Data, method: String) throws {
        guard started else {
            throw CodexTransportError.notStarted
        }

        recordedMethods.append(method)

        if method == "initialized" {
            initializedSeen = true
        }
    }

    func serverEvents() -> AsyncStream<CodexRPCServerEvent> {
        AsyncStream { continuation in
            serverEventContinuation = continuation
            continuation.onTermination = { _ in
                Task {
                    await self.clearServerEventContinuation()
                }
            }
        }
    }

    func emitTurnCompleted(threadID: String, turnID: String) {
        let payload = payloadObject([
            "threadId": threadID,
            "turn": [
                "completedAt": 1713350005,
                "durationMs": 3000,
                "error": NSNull(),
                "id": turnID,
                "items": [],
                "startedAt": 1713350002,
                "status": "completed",
            ],
        ])

        serverEventContinuation?.yield(
            .notification(method: "turn/completed", payload: payload)
        )
    }

    func emitThreadStarted(threadID: String) {
        let payload = payloadObject([
            "thread": [
                "cliVersion": "0.121.0",
                "createdAt": 1713350000,
                "cwd": "/tmp/project",
                "ephemeral": false,
                "id": threadID,
                "modelProvider": "openai",
                "preview": "Hello from thread/started",
                "source": "cli",
                "status": ["type": "active"],
                "turns": [],
                "updatedAt": 1713350001,
            ],
        ])

        serverEventContinuation?.yield(
            .notification(method: "thread/started", payload: payload)
        )
    }

    func emitThreadStatusChanged(threadID: String) {
        let payload = payloadObject([
            "threadId": threadID,
            "status": [
                "type": "active",
                "activeFlags": ["waitingOnApproval"],
            ],
        ])

        serverEventContinuation?.yield(
            .notification(method: "thread/status/changed", payload: payload)
        )
    }

    func emitThreadNameUpdated(threadID: String) {
        let payload = payloadObject([
            "threadId": threadID,
            "threadName": "Planning Thread",
        ])

        serverEventContinuation?.yield(
            .notification(method: "thread/name/updated", payload: payload)
        )
    }

    func emitThreadArchived(threadID: String) {
        let payload = payloadObject([
            "threadId": threadID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "thread/archived", payload: payload)
        )
    }

    func emitThreadUnarchived(threadID: String) {
        let payload = payloadObject([
            "threadId": threadID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "thread/unarchived", payload: payload)
        )
    }

    func emitThreadTokenUsageUpdated(threadID: String, turnID: String) {
        let payload = payloadObject([
            "threadId": threadID,
            "turnId": turnID,
            "tokenUsage": [
                "last": [
                    "cachedInputTokens": 10,
                    "inputTokens": 20,
                    "outputTokens": 30,
                    "reasoningOutputTokens": 5,
                    "totalTokens": 65,
                ],
                "modelContextWindow": 200000,
                "total": [
                    "cachedInputTokens": 100,
                    "inputTokens": 200,
                    "outputTokens": 300,
                    "reasoningOutputTokens": 50,
                    "totalTokens": 650,
                ],
            ],
        ])

        serverEventContinuation?.yield(
            .notification(method: "thread/tokenUsage/updated", payload: payload)
        )
    }

    func emitThreadClosed(threadID: String) {
        let payload = payloadObject([
            "threadId": threadID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "thread/closed", payload: payload)
        )
    }

    func emitTurnStarted(threadID: String, turnID: String) {
        let payload = payloadObject([
            "threadId": threadID,
            "turn": [
                "completedAt": NSNull(),
                "durationMs": NSNull(),
                "error": NSNull(),
                "id": turnID,
                "items": [],
                "startedAt": 1713350002,
                "status": "inProgress",
            ],
        ])

        serverEventContinuation?.yield(
            .notification(method: "turn/started", payload: payload)
        )
    }

    func emitTurnPlanUpdated(threadID: String, turnID: String) {
        let payload = payloadObject([
            "explanation": "Map richer progress notifications.",
            "plan": [
                [
                    "status": "inProgress",
                    "step": "Promote protocol events into CodexTurnEvent",
                ],
                [
                    "status": "pending",
                    "step": "Add consumer-facing stream tests",
                ],
            ],
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "turn/plan/updated", payload: payload)
        )
    }

    func emitItemStarted(threadID: String, turnID: String, itemID: String) {
        let payload = payloadObject([
            "item": [
                "id": itemID,
                "type": "plan",
            ],
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "item/started", payload: payload)
        )
    }

    func emitAgentMessageDelta(threadID: String, turnID: String, itemID: String) {
        let payload = payloadObject([
            "delta": "Working on it",
            "itemId": itemID,
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "item/agentMessage/delta", payload: payload)
        )
    }

    func emitPlanDelta(threadID: String, turnID: String, itemID: String) {
        let payload = payloadObject([
            "delta": "Stream partial plan text",
            "itemId": itemID,
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "item/plan/delta", payload: payload)
        )
    }

    func emitReasoningTextDelta(threadID: String, turnID: String, itemID: String) {
        let payload = payloadObject([
            "contentIndex": 0,
            "delta": "thinking...",
            "itemId": itemID,
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "item/reasoning/textDelta", payload: payload)
        )
    }

    func emitReasoningSummaryTextDelta(threadID: String, turnID: String, itemID: String) {
        let payload = payloadObject([
            "delta": "Summarizing the approach.",
            "itemId": itemID,
            "summaryIndex": 0,
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "item/reasoning/summaryTextDelta", payload: payload)
        )
    }

    func emitItemCompleted(threadID: String, turnID: String, itemID: String) {
        let payload = payloadObject([
            "item": [
                "id": itemID,
                "status": "completed",
                "text": "Done.",
                "type": "agentMessage",
            ],
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "item/completed", payload: payload)
        )
    }

    private func requestMethod(from payload: Data) throws -> String {
        let object = try #require(
            try JSONSerialization.jsonObject(with: payload) as? [String: Any]
        )
        return try #require(object["method"] as? String)
    }

    private func responsePayload(id: CodexRPCRequestID, result: [String: Any]) -> Data {
        payloadObject([
            "id": id.jsonObjectValue,
            "result": result,
        ])
    }

    private func errorPayload(id: CodexRPCRequestID, code: Int, message: String) -> Data {
        payloadObject([
            "id": id.jsonObjectValue,
            "error": [
                "code": code,
                "message": message,
            ],
        ])
    }

    private func payloadObject(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }

    private func clearServerEventContinuation() {
        serverEventContinuation = nil
    }
}

private func turnEvents(
    from stream: AsyncThrowingStream<CodexTurnEvent, Error>,
    count: Int
) async throws -> [CodexTurnEvent] {
    var iterator = stream.makeAsyncIterator()
    var events: [CodexTurnEvent] = []

    while events.count < count, let event = try await iterator.next() {
        events.append(event)
    }

    return events
}

private func threadEvents(
    from stream: AsyncThrowingStream<CodexThreadEvent, Error>,
    count: Int
) async throws -> [CodexThreadEvent] {
    var iterator = stream.makeAsyncIterator()
    var events: [CodexThreadEvent] = []

    while events.count < count, let event = try await iterator.next() {
        events.append(event)
    }

    return events
}

private extension CodexRPCRequestID {
    var jsonObjectValue: Any {
        switch self {
        case let .string(value):
            value
        case let .int(value):
            value
        }
    }
}
