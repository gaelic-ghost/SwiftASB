import Foundation
import Testing
@testable import SwiftASB

extension CodexAppServerTests {
    @Test("builds a recent-turns observable from the local history store")
    func buildsRecentTurnsObservable() async throws {
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

        let recentTurns = try await thread.makeRecentTurns(limit: 4)
        let recentSnapshots = await MainActor.run { recentTurns.turns }

        #expect(recentSnapshots.count == 1)
        #expect(recentSnapshots[0].id == turn.turn.id)
        #expect(recentSnapshots[0].status == "completed")
        #expect(recentSnapshots[0].items.count == 1)
        #expect(recentSnapshots[0].items[0].text == "Done.")

        await client.stop()
    }

    @Test("reads non-UI recent and directional local turn history windows through CodexThread")
    func readsNonUIThreadHistory() async throws {
        let transport = FakeCodexAppServerTransport(
            threadTurnsListResult: [
                "backwardsCursor": NSNull(),
                "data": [],
                "nextCursor": NSNull(),
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

        try await historyStore.hydrateHistoricalTurns(
            threadID: thread.id,
            turns: [
                ThreadHistoryStore.HydratedTurn(
                    turn: CodexAppServer.TurnInfo(
                        completedAt: 1713350005,
                        durationMS: 2500,
                        errorMessage: nil,
                        id: "turn-older",
                        startedAt: 1713350000,
                        status: .completed
                    ),
                    items: [
                        .init(
                            id: "item-older",
                            kind: .agentMessage,
                            command: nil,
                            path: nil,
                            serverName: nil,
                            text: "Older turn",
                            status: "completed",
                            toolName: nil
                        ),
                    ]
                ),
                ThreadHistoryStore.HydratedTurn(
                    turn: CodexAppServer.TurnInfo(
                        completedAt: 1713350105,
                        durationMS: 2500,
                        errorMessage: nil,
                        id: "turn-middle",
                        startedAt: 1713350100,
                        status: .completed
                    ),
                    items: [
                        .init(
                            id: "item-middle",
                            kind: .agentMessage,
                            command: nil,
                            path: nil,
                            serverName: nil,
                            text: "Middle turn",
                            status: "completed",
                            toolName: nil
                        ),
                    ]
                ),
                ThreadHistoryStore.HydratedTurn(
                    turn: CodexAppServer.TurnInfo(
                        completedAt: 1713350255,
                        durationMS: 2500,
                        errorMessage: nil,
                        id: "turn-newest",
                        startedAt: 1713350250,
                        status: .completed
                    ),
                    items: [
                        .init(
                            id: "item-newest",
                            kind: .agentMessage,
                            command: nil,
                            path: nil,
                            serverName: nil,
                            text: "Newest turn",
                            status: "completed",
                            toolName: nil
                        ),
                    ]
                ),
                ThreadHistoryStore.HydratedTurn(
                    turn: CodexAppServer.TurnInfo(
                        completedAt: 1713350205,
                        durationMS: 2500,
                        errorMessage: nil,
                        id: "turn-newer",
                        startedAt: 1713350200,
                        status: .completed
                    ),
                    items: [
                        .init(
                            id: "item-newer",
                            kind: .agentMessage,
                            command: nil,
                            path: nil,
                            serverName: nil,
                            text: "Newer turn",
                            status: "completed",
                            toolName: nil
                        ),
                    ]
                ),
            ]
        )

        let recentWindow = try await thread.readRecentTurnHistoryWindow(limit: 2)
        #expect(recentWindow.turns.map(\.id) == ["turn-newest", "turn-newer"])
        #expect(recentWindow.newestTurnID == "turn-newest")
        #expect(recentWindow.oldestTurnID == "turn-newer")
        #expect(recentWindow.hasNewerTurns == false)
        #expect(recentWindow.hasOlderTurns)

        let recentTurns = try await thread.readRecentTurnHistory(limit: 2)
        #expect(recentTurns.map(\.id) == ["turn-newest", "turn-newer"])

        let readTurn = try await thread.readTurnHistory(turnID: "turn-middle")
        #expect(readTurn?.id == "turn-middle")
        #expect(readTurn?.items.first?.text == "Middle turn")

        let olderWindow = try await thread.readOlderTurnHistoryWindow(olderThan: "turn-middle", limit: 2)
        #expect(olderWindow.turns.map(\.id) == ["turn-older"])
        #expect(olderWindow.hasNewerTurns)
        #expect(olderWindow.hasOlderTurns == false)

        let olderTurns = try await thread.readOlderTurnHistory(olderThan: "turn-middle", limit: 2)
        #expect(olderTurns.map(\.id) == ["turn-older"])

        let newerWindow = try await thread.readNewerTurnHistoryWindow(newerThan: "turn-middle", limit: 1)
        #expect(newerWindow.turns.map(\.id) == ["turn-newer"])
        #expect(newerWindow.hasOlderTurns)
        #expect(newerWindow.hasNewerTurns)

        let newerTurns = try await thread.readNewerTurnHistory(newerThan: "turn-middle", limit: 1)
        #expect(newerTurns.map(\.id) == ["turn-newer"])

        let turnCenteredWindow = try await thread.windowAroundTurn("turn-middle", limit: 3)
        #expect(turnCenteredWindow.turns.map(\.id) == ["turn-newer", "turn-middle", "turn-older"])
        #expect(turnCenteredWindow.hasNewerTurns)
        #expect(turnCenteredWindow.hasOlderTurns == false)

        let itemCenteredWindow = try await thread.windowAroundItem("item-middle", limit: 2)
        #expect(itemCenteredWindow.turns.map(\.id) == ["turn-middle", "turn-older"])
        #expect(itemCenteredWindow.hasNewerTurns)
        #expect(itemCenteredWindow.hasOlderTurns == false)

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @Test("directional non-UI turn history requires a known local boundary turn")
    func nonUIThreadHistoryRequiresKnownBoundaryTurn() async throws {
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

        await #expect(throws: CodexAppServerError.self) {
            try await thread.readOlderTurnHistory(olderThan: "missing-turn", limit: 1)
        }
        await #expect(throws: CodexAppServerError.self) {
            try await thread.windowAroundTurn("missing-turn", limit: 1)
        }
        await #expect(throws: CodexAppServerError.self) {
            try await thread.windowAroundItem("missing-item", limit: 1)
        }

        await client.stop()
    }

}
