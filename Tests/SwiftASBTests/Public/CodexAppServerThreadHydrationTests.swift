import Foundation
@testable import SwiftASB
import Testing

extension CodexAppServerTests {
    @Test("reads a stored thread and hydrates returned turns into the local history store")
    func readsStoredThreadAndHydratesHistory() async throws {
        let transport = FakeCodexAppServerTransport()
        let (historyStore, temporaryDirectory) = try temporarySQLiteHistoryStore()
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

        _ = try await client.startThread(
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

        let result = try await client.readThread(
            .init(
                threadID: "thread-123",
                includeTurns: true
            )
        )

        #expect(result.thread.id == "thread-123")
        #expect(result.thread.status.type == .notLoaded)
        #expect(result.turns.count == 1)
        #expect(result.turns[0].status == .completed)

        let snapshot = try await client.debugThreadHistorySnapshot(threadID: "thread-123")
        let threadSnapshot = try #require(snapshot)
        #expect(threadSnapshot.turns.count == 1)
        #expect(threadSnapshot.turns[0].items.count == 2)
        #expect(threadSnapshot.turns[0].items[0].kind == "userMessage")
        #expect(threadSnapshot.turns[0].items[1].kind == "agentMessage")
        #expect(threadSnapshot.turns[0].items[1].text == "Hydrated reply from thread/read.")
        #expect(threadSnapshot.state.completeness == "serverParity")

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @Test("preserves richer local item detail when thread/read returns a thinner overlapping turn")
    func preservesRicherLocalItemDetailDuringHydration() async throws {
        let transport = FakeCodexAppServerTransport(
            threadReadResult: [
                "thread": [
                    "cliVersion": "0.128.0",
                    "createdAt": 1_713_350_000,
                    "cwd": "/tmp/project",
                    "ephemeral": false,
                    "id": "thread-123",
                    "modelProvider": "openai",
                    "preview": "Hydrated overlap preview",
                    "source": "cli",
                    "status": ["type": "notLoaded"],
                    "turns": [
                        [
                            "completedAt": 1_713_350_005,
                            "durationMs": 3000,
                            "error": NSNull(),
                            "id": "turn-123",
                            "items": [
                                [
                                    "id": "item-agent-1",
                                    "status": "completed",
                                    "type": "agentMessage",
                                ],
                            ],
                            "startedAt": 1_713_350_002,
                            "status": "completed",
                        ],
                    ],
                    "updatedAt": 1_713_350_005,
                ],
            ]
        )
        let (historyStore, temporaryDirectory) = try temporarySQLiteHistoryStore()
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
        let turn = try await thread.startTextTurn("Summarize the project state.")
        let eventTask = Task {
            try await turnEvents(from: turn.events, count: 4)
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
            itemID: "item-agent-1",
            item: [
                "id": "item-agent-1",
                "status": "completed",
                "type": "agentMessage",
            ]
        )
        await transport.emitTurnCompleted(threadID: thread.id, turnID: turn.turn.id)
        _ = try await eventTask.value

        _ = try await client.readThread(
            .init(
                threadID: thread.id,
                includeTurns: true
            )
        )

        let snapshot = try await client.debugThreadHistorySnapshot(threadID: thread.id)
        let threadSnapshot = try #require(snapshot)
        let overlappingTurn = try #require(threadSnapshot.turns.first { $0.id == "turn-123" })
        let overlappingItem = try #require(overlappingTurn.items.first { $0.id == "item-agent-1" })
        #expect(overlappingItem.streamedText == "Working on it")
        #expect(overlappingItem.status == "completed")
        #expect(threadSnapshot.state.completeness == "richerThanServer")

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @Test("promotes overlapping item status to terminal server state without dropping richer local detail")
    func promotesOverlappingItemStatusToTerminalServerState() async throws {
        let transport = FakeCodexAppServerTransport(
            threadReadResult: [
                "thread": [
                    "cliVersion": "0.128.0",
                    "createdAt": 1_713_350_000,
                    "cwd": "/tmp/project",
                    "ephemeral": false,
                    "id": "thread-123",
                    "modelProvider": "openai",
                    "preview": "Hydrated overlap preview",
                    "source": "cli",
                    "status": ["type": "notLoaded"],
                    "turns": [
                        [
                            "completedAt": 1_713_350_005,
                            "durationMs": 3000,
                            "error": NSNull(),
                            "id": "turn-123",
                            "items": [
                                [
                                    "id": "item-command-1",
                                    "status": "completed",
                                    "type": "commandExecution",
                                ],
                            ],
                            "startedAt": 1_713_350_002,
                            "status": "completed",
                        ],
                    ],
                    "updatedAt": 1_713_350_005,
                ],
            ]
        )
        let (historyStore, temporaryDirectory) = try temporarySQLiteHistoryStore()
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
        let turn = try await thread.startTextTurn("Run the diagnostics command.")
        let eventTask = Task {
            try await turnEvents(from: turn.events, count: 4)
        }

        await transport.emitTurnStarted(threadID: thread.id, turnID: turn.turn.id)
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-command-1",
            item: [
                "id": "item-command-1",
                "command": "swift test",
                "status": "in_progress",
                "type": "commandExecution",
            ]
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-command-1",
            item: [
                "id": "item-command-1",
                "command": "swift test",
                "status": "in_progress",
                "type": "commandExecution",
            ]
        )
        await transport.emitTurnCompleted(threadID: thread.id, turnID: turn.turn.id)
        _ = try await eventTask.value

        _ = try await client.readThread(
            .init(
                threadID: thread.id,
                includeTurns: true
            )
        )

        let snapshot = try await client.debugThreadHistorySnapshot(threadID: thread.id)
        let threadSnapshot = try #require(snapshot)
        let overlappingTurn = try #require(threadSnapshot.turns.first { $0.id == "turn-123" })
        let overlappingItem = try #require(overlappingTurn.items.first { $0.id == "item-command-1" })
        #expect(overlappingItem.command == "swift test")
        #expect(overlappingItem.status == "completed")
        #expect(threadSnapshot.state.completeness == "richerThanServer")

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @Test("lists stored thread turns and hydrates paged history into the local history store")
    func listsStoredThreadTurnsAndHydratesHistory() async throws {
        let transport = FakeCodexAppServerTransport()
        let (historyStore, temporaryDirectory) = try temporarySQLiteHistoryStore()
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

        _ = try await client.startThread(
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

        let page = try await client.listThreadTurns(
            .init(
                threadID: "thread-123",
                limit: 2,
                sortDirection: .desc
            )
        )

        #expect(page.turns.count == 2)
        #expect(page.nextCursor == "cursor-older")
        #expect(page.backwardsCursor == "cursor-newer")

        let snapshot = try await client.debugThreadHistorySnapshot(threadID: "thread-123")
        let threadSnapshot = try #require(snapshot)
        #expect(threadSnapshot.turns.count == 2)
        #expect(threadSnapshot.turns[0].id == "turn-older")
        #expect(threadSnapshot.turns[1].id == "turn-newer")

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @Test("lists stored thread turns for a thread that has not been hydrated locally yet")
    func listsStoredThreadTurnsForUnknownLocalThread() async throws {
        let transport = FakeCodexAppServerTransport()
        let (historyStore, temporaryDirectory) = try temporarySQLiteHistoryStore()
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

        let page = try await client.listThreadTurns(
            .init(
                threadID: "thread-123",
                limit: 2,
                sortDirection: .desc
            )
        )

        #expect(page.turns.count == 2)

        let snapshot = try await client.debugThreadHistorySnapshot(threadID: "thread-123")
        let threadSnapshot = try #require(snapshot)
        #expect(threadSnapshot.id == "thread-123")
        #expect(threadSnapshot.statusType == "notLoaded")
        #expect(threadSnapshot.turns.count == 2)

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @Test("lists stored turn items without requiring a local turn snapshot")
    func listsStoredTurnItems() async throws {
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

        let page = try await client.listThreadTurnItems(
            .init(
                threadID: "thread-123",
                turnID: "turn-older",
                limit: 2,
                sortDirection: .asc
            )
        )

        #expect(page.backwardsCursor == "cursor-newer-items")
        #expect(page.nextCursor == "cursor-older-items")
        #expect(page.items.map(\.id) == ["item-command-1", "item-agent-1"])
        #expect(page.items.first?.kind == .commandExecution)
        #expect(page.items.first?.command == "swift test")

        let payloads = await transport.requestPayloads(for: "thread/turns/items/list")
        let payload = try #require(payloads.first)
        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        let params = try #require(object["params"] as? [String: Any])
        #expect(params["threadId"] as? String == "thread-123")
        #expect(params["turnId"] as? String == "turn-older")
        #expect(params["limit"] as? Int == 2)
        #expect(params["sortDirection"] as? String == "asc")

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

        for _ in 0..<5 {
            await Task.yield()
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
        guard receivedEvents.count == 7 else {
            await client.stop()
            return
        }

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
                #expect(update.modelContextWindow == 200_000)
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
}
