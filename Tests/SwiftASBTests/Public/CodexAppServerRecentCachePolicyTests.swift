import Foundation
@testable import SwiftASB
import Testing

extension CodexAppServerTests {
    @Test("recent-turn cache policy presets scale by UI density")
    func recentTurnCachePolicyPresetsScaleByUIDensity() {
        let chat = CodexThread.RecentTurns.CachePolicy.chatUI(pageSize: 12)
        let inspector = CodexThread.RecentTurns.CachePolicy.inspector(pageSize: 12)
        let historyRail = CodexThread.RecentTurns.CachePolicy.historyRail(pageSize: 12)

        #expect(CodexThread.RecentTurns.CachePolicy.automatic(pageSize: 12) == chat)
        #expect(inspector.maxResidentTurns > chat.maxResidentTurns)
        #expect(chat.maxResidentTurns > historyRail.maxResidentTurns)
        #expect(inspector.maximumResidentItemCost ?? 0 > chat.maximumResidentItemCost ?? 0)
        #expect(chat.maximumResidentItemCost ?? 0 > historyRail.maximumResidentItemCost ?? 0)
        #expect(inspector.maxPrefetchPagesPerPass > historyRail.maxPrefetchPagesPerPass)
    }

    @Test("recent companion cache policies normalize unsafe numeric inputs")
    func recentCompanionCachePoliciesNormalizeUnsafeNumericInputs() {
        let turns = CodexThread.RecentTurns.CachePolicy(
            maxResidentTurns: 0,
            minimumResidentTurns: 10,
            maximumResidentItemCost: 0,
            protectedTurnBuffer: -1,
            protectedRecentCompletedTurns: 10,
            edgePrefetchThreshold: -1,
            jitterScrollVelocityThreshold: -1,
            fastScrollVelocityThreshold: -1,
            veryFastScrollVelocityThreshold: -2,
            maxPrefetchPagesPerPass: 0
        )
        #expect(turns.maxResidentTurns == 1)
        #expect(turns.minimumResidentTurns == 1)
        #expect(turns.maximumResidentItemCost == 1)
        #expect(turns.protectedTurnBuffer == 0)
        #expect(turns.protectedRecentCompletedTurns == 1)
        #expect(turns.edgePrefetchThreshold == 0)
        #expect(turns.jitterScrollVelocityThreshold == 0)
        #expect(turns.fastScrollVelocityThreshold == 0)
        #expect(turns.veryFastScrollVelocityThreshold == 0)
        #expect(turns.maxPrefetchPagesPerPass == 1)

        let files = CodexThread.RecentFiles.CachePolicy(
            maxResidentFiles: 0,
            minimumResidentFiles: 10,
            maximumResidentPayloadCost: 0,
            protectedFileBuffer: -1,
            protectedRecentCompletedFiles: -1
        )
        #expect(files.maxResidentFiles == 1)
        #expect(files.minimumResidentFiles == 1)
        #expect(files.maximumResidentPayloadCost == 1)
        #expect(files.protectedFileBuffer == 0)
        #expect(files.protectedRecentCompletedFiles == 0)

        let commands = CodexThread.RecentCommands.CachePolicy(
            maxResidentCommands: 0,
            minimumResidentCommands: 10,
            maximumResidentOutputCost: 0,
            protectedCommandBuffer: -1,
            protectedRecentCompletedCommands: -1
        )
        #expect(commands.maxResidentCommands == 1)
        #expect(commands.minimumResidentCommands == 1)
        #expect(commands.maximumResidentOutputCost == 1)
        #expect(commands.protectedCommandBuffer == 0)
        #expect(commands.protectedRecentCompletedCommands == 0)
    }

    @Test("item-cost eviction removes the oldest completed turns once the resident item budget is exceeded")
    func itemCostEvictionRemovesOldestCompletedTurns() async throws {
        let transport = FakeCodexAppServerTransport(
            threadTurnsListResult: [
                "backwardsCursor": "cursor-newer-1",
                "data": [
                    [
                        "completedAt": 1_713_350_300,
                        "durationMs": 2500,
                        "error": NSNull(),
                        "id": "turn-3",
                        "items": [
                            [
                                "id": "item-3a",
                                "status": "completed",
                                "text": "Newest item A",
                                "type": "agentMessage",
                            ],
                            [
                                "id": "item-3b",
                                "status": "completed",
                                "text": "Newest item B",
                                "type": "agentMessage",
                            ],
                        ],
                        "startedAt": 1_713_350_250,
                        "status": "completed",
                    ],
                    [
                        "completedAt": 1_713_350_200,
                        "durationMs": 2500,
                        "error": NSNull(),
                        "id": "turn-2",
                        "items": [
                            [
                                "id": "item-2a",
                                "status": "completed",
                                "text": "Middle item A",
                                "type": "agentMessage",
                            ],
                            [
                                "id": "item-2b",
                                "status": "completed",
                                "text": "Middle item B",
                                "type": "agentMessage",
                            ],
                        ],
                        "startedAt": 1_713_350_150,
                        "status": "completed",
                    ],
                    [
                        "completedAt": 1_713_350_100,
                        "durationMs": 2500,
                        "error": NSNull(),
                        "id": "turn-1",
                        "items": [
                            [
                                "id": "item-1a",
                                "status": "completed",
                                "text": "Oldest item A",
                                "type": "agentMessage",
                            ],
                            [
                                "id": "item-1b",
                                "status": "completed",
                                "text": "Oldest item B",
                                "type": "agentMessage",
                            ],
                        ],
                        "startedAt": 1_713_350_050,
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

        _ = try await client.listThreadTurns(
            .init(
                threadID: thread.id,
                limit: 3,
                sortDirection: .desc
            )
        )

        let recentTurns = try await thread.makeRecentTurns(
            limit: 3,
            cachePolicy: .init(
                maxResidentTurns: 5,
                minimumResidentTurns: 2,
                maximumResidentItemCost: 4,
                protectedTurnBuffer: 0,
                edgePrefetchThreshold: 0
            )
        )

        let residentIDs = await MainActor.run { recentTurns.turns.map(\.id) }
        let residentItemCost = await MainActor.run { recentTurns.residentItemCost }
        #expect(residentIDs == ["turn-3", "turn-2"])
        #expect(residentItemCost == 12)

        await client.stop()
    }

    @Test("item-cost eviction respects the minimum resident-turn floor")
    func itemCostEvictionRespectsMinimumResidentTurnFloor() async throws {
        let transport = FakeCodexAppServerTransport(
            threadTurnsListResult: [
                "backwardsCursor": "cursor-newer-1",
                "data": [
                    [
                        "completedAt": 1_713_350_200,
                        "durationMs": 2500,
                        "error": NSNull(),
                        "id": "turn-2",
                        "items": [
                            [
                                "id": "item-2a",
                                "status": "completed",
                                "text": "Newest item A",
                                "type": "agentMessage",
                            ],
                            [
                                "id": "item-2b",
                                "status": "completed",
                                "text": "Newest item B",
                                "type": "agentMessage",
                            ],
                        ],
                        "startedAt": 1_713_350_150,
                        "status": "completed",
                    ],
                    [
                        "completedAt": 1_713_350_100,
                        "durationMs": 2500,
                        "error": NSNull(),
                        "id": "turn-1",
                        "items": [
                            [
                                "id": "item-1a",
                                "status": "completed",
                                "text": "Oldest item A",
                                "type": "agentMessage",
                            ],
                            [
                                "id": "item-1b",
                                "status": "completed",
                                "text": "Oldest item B",
                                "type": "agentMessage",
                            ],
                        ],
                        "startedAt": 1_713_350_050,
                        "status": "completed",
                    ],
                ],
                "nextCursor": "cursor-older-1",
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

        _ = try await client.listThreadTurns(
            .init(
                threadID: thread.id,
                limit: 2,
                sortDirection: .desc
            )
        )

        let recentTurns = try await thread.makeRecentTurns(
            limit: 2,
            cachePolicy: .init(
                maxResidentTurns: 4,
                minimumResidentTurns: 2,
                maximumResidentItemCost: 1,
                protectedTurnBuffer: 0,
                edgePrefetchThreshold: 0
            )
        )

        let residentIDs = await MainActor.run { recentTurns.turns.map(\.id) }
        let residentItemCost = await MainActor.run { recentTurns.residentItemCost }
        #expect(residentIDs == ["turn-2", "turn-1"])
        #expect(residentItemCost == 12)

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @Test("low-value items are slimmed before completed turns are evicted")
    func lowValueItemsAreSlimmedBeforeTurnEviction() async throws {
        let transport = FakeCodexAppServerTransport(
            threadTurnsListResult: [
                "backwardsCursor": "cursor-newer-1",
                "data": [
                    [
                        "completedAt": 1_713_350_200,
                        "durationMs": 2500,
                        "error": NSNull(),
                        "id": "turn-2",
                        "items": [
                            [
                                "id": "item-2-user",
                                "text": "Newest user message",
                                "type": "userMessage",
                            ],
                            [
                                "id": "item-2-command",
                                "status": "completed",
                                "text": "ls Sources",
                                "type": "commandExecution",
                            ],
                        ],
                        "startedAt": 1_713_350_150,
                        "status": "completed",
                    ],
                    [
                        "completedAt": 1_713_350_100,
                        "durationMs": 2500,
                        "error": NSNull(),
                        "id": "turn-1",
                        "items": [
                            [
                                "id": "item-1-user",
                                "text": "Older user message",
                                "type": "userMessage",
                            ],
                            [
                                "id": "item-1-mcp",
                                "status": "completed",
                                "text": "calendar.list_events",
                                "type": "mcpToolCall",
                            ],
                        ],
                        "startedAt": 1_713_350_050,
                        "status": "completed",
                    ],
                ],
                "nextCursor": "cursor-older-1",
            ]
        )
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

        _ = try await client.listThreadTurns(
            .init(
                threadID: thread.id,
                limit: 2,
                sortDirection: .desc
            )
        )

        let recentTurns = try await thread.makeRecentTurns(
            limit: 2,
            cachePolicy: .init(
                maxResidentTurns: 4,
                minimumResidentTurns: 2,
                maximumResidentItemCost: 6,
                protectedTurnBuffer: 0,
                protectedRecentCompletedTurns: 1,
                edgePrefetchThreshold: 0
            )
        )

        let residentIDs = await MainActor.run { recentTurns.turns.map(\.id) }
        let turnOne = await MainActor.run { recentTurns.turns.first(where: { $0.id == "turn-1" }) }
        let turnTwo = await MainActor.run { recentTurns.turns.first(where: { $0.id == "turn-2" }) }
        let residentItemCost = await MainActor.run { recentTurns.residentItemCost }

        #expect(residentIDs == ["turn-2", "turn-1"])
        #expect(try #require(turnTwo).isItemPayloadComplete == true)
        #expect(try #require(turnOne).isItemPayloadComplete == false)
        #expect(try #require(turnOne).omittedItemCount == 1)
        #expect(try #require(turnOne).items.map(\.kind) == ["userMessage"])
        #expect(residentItemCost == 7)

        await client.stop()
    }

    @Test("a slimmed turn rehydrates its full items when it becomes visible")
    func slimmedTurnRehydratesWhenVisible() async throws {
        let transport = FakeCodexAppServerTransport(
            threadTurnsListResult: [
                "backwardsCursor": "cursor-newer-1",
                "data": [
                    [
                        "completedAt": 1_713_350_200,
                        "durationMs": 2500,
                        "error": NSNull(),
                        "id": "turn-2",
                        "items": [
                            [
                                "id": "item-2-user",
                                "text": "Newest user message",
                                "type": "userMessage",
                            ],
                            [
                                "id": "item-2-command",
                                "status": "completed",
                                "text": "ls Sources",
                                "type": "commandExecution",
                            ],
                        ],
                        "startedAt": 1_713_350_150,
                        "status": "completed",
                    ],
                    [
                        "completedAt": 1_713_350_100,
                        "durationMs": 2500,
                        "error": NSNull(),
                        "id": "turn-1",
                        "items": [
                            [
                                "id": "item-1-user",
                                "text": "Older user message",
                                "type": "userMessage",
                            ],
                            [
                                "id": "item-1-mcp",
                                "status": "completed",
                                "text": "calendar.list_events",
                                "type": "mcpToolCall",
                            ],
                        ],
                        "startedAt": 1_713_350_050,
                        "status": "completed",
                    ],
                ],
                "nextCursor": "cursor-older-1",
            ]
        )
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

        _ = try await client.listThreadTurns(
            .init(
                threadID: thread.id,
                limit: 2,
                sortDirection: .desc
            )
        )

        let recentTurns = try await thread.makeRecentTurns(
            limit: 2,
            cachePolicy: .init(
                maxResidentTurns: 4,
                minimumResidentTurns: 2,
                maximumResidentItemCost: 6,
                protectedTurnBuffer: 0,
                protectedRecentCompletedTurns: 1,
                edgePrefetchThreshold: 0
            )
        )

        let initialTurnOne = await MainActor.run { recentTurns.turns.first(where: { $0.id == "turn-1" }) }
        #expect(try #require(initialTurnOne).isItemPayloadComplete == false)

        await MainActor.run {
            recentTurns.updateVisibleTurnIDs(["turn-1"])
        }

        await waitForObservableState {
            recentTurns.turns.first(where: { $0.id == "turn-1" })?.isItemPayloadComplete == true
        }

        let hydratedTurnOne = await MainActor.run { recentTurns.turns.first(where: { $0.id == "turn-1" }) }
        #expect(try #require(hydratedTurnOne).omittedItemCount == 0)
        #expect(try #require(hydratedTurnOne).items.count == 2)

        await client.stop()
    }
}
