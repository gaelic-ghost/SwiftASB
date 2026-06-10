import Foundation
import Testing
@testable import SwiftASB

extension CodexAppServerTests {
    @Test("loads older recent turns from the local history store before app-server fallback")
    func loadsOlderRecentTurnsLocallyFirst() async throws {
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

        _ = try await client.listThreadTurns(
            .init(
                threadID: thread.id,
                limit: 2,
                sortDirection: .desc
            )
        )

        do {
            let recentTurns = try await thread.makeRecentTurns(limit: 1)
            let initialSnapshots = await MainActor.run { recentTurns.turns }
            #expect(initialSnapshots.count == 1)
            #expect(initialSnapshots[0].id == "turn-newer")

            let methodsBeforeOlderLoad = await transport.recordedMethods
            try await recentTurns.loadOlderTurns(limit: 1)
            let methodsAfterOlderLoad = await transport.recordedMethods

            let expandedSnapshots = await MainActor.run { recentTurns.turns }
            #expect(expandedSnapshots.count == 2)
            #expect(expandedSnapshots[0].id == "turn-newer")
            #expect(expandedSnapshots[1].id == "turn-older")
            #expect(methodsBeforeOlderLoad == methodsAfterOlderLoad)
        }

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @Test("seeds remote older cursors for recent turns even when the initial window is local")
    func seedsRemoteOlderCursorsForLocalRecentWindow() async throws {
        let transport = FakeCodexAppServerTransport(
            threadTurnsListResultQueue: [
                [
                    "backwardsCursor": "cursor-newer-1",
                    "data": [
                        [
                            "completedAt": 1713350300,
                            "durationMs": 2500,
                            "error": NSNull(),
                            "id": "turn-3",
                            "items": [],
                            "startedAt": 1713350250,
                            "status": "completed",
                        ],
                    ],
                    "nextCursor": "cursor-older-1",
                ],
                [
                    "backwardsCursor": "cursor-newer-2",
                    "data": [
                        [
                            "completedAt": 1713350005,
                            "durationMs": 2500,
                            "error": NSNull(),
                            "id": "turn-0",
                            "items": [],
                            "startedAt": 1713350000,
                            "status": "completed",
                        ],
                    ],
                    "nextCursor": NSNull(),
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

        try await historyStore.hydrateHistoricalTurns(
            threadID: thread.id,
            turns: [
                ThreadHistoryStore.HydratedTurn(
                    turn: CodexAppServer.TurnInfo(
                        completedAt: 1713350300,
                        durationMS: 2500,
                        errorMessage: nil,
                        id: "turn-3",
                        startedAt: 1713350250,
                        status: .completed
                    ),
                    items: []
                ),
                ThreadHistoryStore.HydratedTurn(
                    turn: CodexAppServer.TurnInfo(
                        completedAt: 1713350200,
                        durationMS: 2500,
                        errorMessage: nil,
                        id: "turn-2",
                        startedAt: 1713350150,
                        status: .completed
                    ),
                    items: []
                ),
                ThreadHistoryStore.HydratedTurn(
                    turn: CodexAppServer.TurnInfo(
                        completedAt: 1713350100,
                        durationMS: 2500,
                        errorMessage: nil,
                        id: "turn-1",
                        startedAt: 1713350050,
                        status: .completed
                    ),
                    items: []
                ),
            ]
        )

        do {
            let recentTurns = try await thread.makeRecentTurns(limit: 1)
            let methodsAfterInitialLoad = await transport.recordedMethods
            #expect(methodsAfterInitialLoad == ["initialize", "initialized", "thread/start", "thread/turns/list"])

            let initialSnapshots = await MainActor.run { recentTurns.turns }
            #expect(initialSnapshots.count == 1)
            #expect(initialSnapshots[0].id == "turn-3")

            try await recentTurns.loadOlderTurns(limit: 1)
            try await recentTurns.loadOlderTurns(limit: 1)
            let methodsBeforeRemoteFallback = await transport.recordedMethods
            #expect(methodsBeforeRemoteFallback == methodsAfterInitialLoad)

            try await recentTurns.loadOlderTurns(limit: 1)
            let methodsAfterRemoteFallback = await transport.recordedMethods
            #expect(
                methodsAfterRemoteFallback == [
                    "initialize",
                    "initialized",
                    "thread/start",
                    "thread/turns/list",
                    "thread/turns/list",
                ]
            )

            let expandedSnapshots = await MainActor.run { recentTurns.turns }
            #expect(expandedSnapshots.map { $0.id } == ["turn-3", "turn-2", "turn-1", "turn-0"])
            #expect(await MainActor.run { recentTurns.nextOlderCursor } == nil)
        }

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @Test("bound scroll position triggers automatic older-turn prefetch near the resident edge")
    func scrollPositionBindingTriggersOlderPrefetch() async throws {
        let transport = FakeCodexAppServerTransport(
            threadTurnsListResultQueue: [
                [
                    "backwardsCursor": "cursor-newer-1",
                    "data": [
                        [
                            "completedAt": 1713350300,
                            "durationMs": 2500,
                            "error": NSNull(),
                            "id": "turn-3",
                            "items": [],
                            "startedAt": 1713350250,
                            "status": "completed",
                        ],
                    ],
                    "nextCursor": "cursor-older-1",
                ],
                [
                    "backwardsCursor": "cursor-newer-2",
                    "data": [
                        [
                            "completedAt": 1713350005,
                            "durationMs": 2500,
                            "error": NSNull(),
                            "id": "turn-0",
                            "items": [],
                            "startedAt": 1713350000,
                            "status": "completed",
                        ],
                    ],
                    "nextCursor": NSNull(),
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

        try await historyStore.hydrateHistoricalTurns(
            threadID: thread.id,
            turns: [
                ThreadHistoryStore.HydratedTurn(
                    turn: CodexAppServer.TurnInfo(
                        completedAt: 1713350300,
                        durationMS: 2500,
                        errorMessage: nil,
                        id: "turn-3",
                        startedAt: 1713350250,
                        status: .completed
                    ),
                    items: []
                ),
                ThreadHistoryStore.HydratedTurn(
                    turn: CodexAppServer.TurnInfo(
                        completedAt: 1713350200,
                        durationMS: 2500,
                        errorMessage: nil,
                        id: "turn-2",
                        startedAt: 1713350150,
                        status: .completed
                    ),
                    items: []
                ),
                ThreadHistoryStore.HydratedTurn(
                    turn: CodexAppServer.TurnInfo(
                        completedAt: 1713350100,
                        durationMS: 2500,
                        errorMessage: nil,
                        id: "turn-1",
                        startedAt: 1713350050,
                        status: .completed
                    ),
                    items: []
                ),
            ]
        )

        var recentTurns: CodexThread.RecentTurns? = try await thread.makeRecentTurns(
            limit: 1,
            cachePolicy: .init(
                maxResidentTurns: 4,
                protectedTurnBuffer: 0,
                edgePrefetchThreshold: 1
            )
        )

        try await recentTurns?.loadOlderTurns(limit: 1)
        try await recentTurns?.loadOlderTurns(limit: 1)
        await MainActor.run {
            recentTurns?.scrollPositionTurnID = "turn-1"
        }

        await waitForObservableState {
            recentTurns?.turns.map(\.id) == ["turn-3", "turn-2", "turn-1", "turn-0"]
        }

        let recordedMethods = await transport.recordedMethods
        #expect(
            Array(recordedMethods.prefix(5)) == [
                "initialize",
                "initialized",
                "thread/start",
                "thread/turns/list",
                "thread/turns/list",
            ]
        )
        #expect(recordedMethods.filter { $0 == "thread/turns/list" }.count >= 2)

        recentTurns = nil
        await settleObservableTeardown()

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @Test("visible turn updates protect the visible resident turn during cache trimming")
    func visibleTurnUpdatesProtectResidentTurnDuringTrim() async throws {
        let transport = FakeCodexAppServerTransport(
            threadTurnsListResult: [
                "backwardsCursor": "cursor-newer-1",
                "data": [
                    [
                        "completedAt": 1713350300,
                        "durationMs": 2500,
                        "error": NSNull(),
                        "id": "turn-3",
                        "items": [],
                        "startedAt": 1713350250,
                        "status": "completed",
                    ],
                    [
                        "completedAt": 1713350200,
                        "durationMs": 2500,
                        "error": NSNull(),
                        "id": "turn-2",
                        "items": [],
                        "startedAt": 1713350150,
                        "status": "completed",
                    ],
                    [
                        "completedAt": 1713350100,
                        "durationMs": 2500,
                        "error": NSNull(),
                        "id": "turn-1",
                        "items": [],
                        "startedAt": 1713350050,
                        "status": "completed",
                    ],
                ],
                "nextCursor": "cursor-older-1",
            ]
        )
        let historyStore = try ThreadHistoryStore(
            configuration: .inMemory()
        )
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
                        completedAt: 1713350300,
                        durationMS: 2500,
                        errorMessage: nil,
                        id: "turn-3",
                        startedAt: 1713350250,
                        status: .completed
                    ),
                    items: []
                ),
                ThreadHistoryStore.HydratedTurn(
                    turn: CodexAppServer.TurnInfo(
                        completedAt: 1713350200,
                        durationMS: 2500,
                        errorMessage: nil,
                        id: "turn-2",
                        startedAt: 1713350150,
                        status: .completed
                    ),
                    items: []
                ),
                ThreadHistoryStore.HydratedTurn(
                    turn: CodexAppServer.TurnInfo(
                        completedAt: 1713350100,
                        durationMS: 2500,
                        errorMessage: nil,
                        id: "turn-1",
                        startedAt: 1713350050,
                        status: .completed
                    ),
                    items: []
                ),
            ]
        )

        let recentTurns = try await thread.makeRecentTurns(
            limit: 2,
            cachePolicy: .init(
                maxResidentTurns: 2,
                minimumResidentTurns: 1,
                protectedTurnBuffer: 0,
                edgePrefetchThreshold: 0
            )
        )

        await MainActor.run {
            recentTurns.updateVisibleTurnIDs(["turn-2"])
        }

        let liveTurn = try await thread.startTextTurn("Add one more turn.")
        await transport.emitTurnStarted(threadID: thread.id, turnID: liveTurn.turn.id)
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: liveTurn.turn.id,
            itemID: "item-agent-new",
            item: [
                "id": "item-agent-new",
                "type": "agentMessage",
            ]
        )
        await transport.emitAgentMessageDelta(
            threadID: thread.id,
            turnID: liveTurn.turn.id,
            itemID: "item-agent-new"
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: liveTurn.turn.id,
            itemID: "item-agent-new"
        )
        await transport.emitTurnCompleted(threadID: thread.id, turnID: liveTurn.turn.id)

        await waitForObservableState {
            recentTurns.turns.count == 2 && recentTurns.turns.contains { $0.id == "turn-2" }
        }

        let residentIDs = await MainActor.run {
            recentTurns.turns.map(\.id)
        }
        #expect(residentIDs.contains("turn-2"))
        #expect(residentIDs.count == 2)

        await client.stop()
    }

}
