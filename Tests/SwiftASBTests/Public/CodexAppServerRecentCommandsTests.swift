import Foundation
import Testing
@testable import SwiftASB

extension CodexAppServerTests {
    @Test("recent-command descriptors normalize companion intent")
    func recentCommandDescriptorsNormalizeCompanionIntent() {
        let cachePolicy = CodexThread.RecentCommands.CachePolicy(
            maxResidentCommands: 4,
            minimumResidentCommands: 2,
            maximumResidentOutputCost: 10
        )
        let descriptor = CodexThread.RecentCommandsQD
            .recent(limit: 0)
            .cached(by: cachePolicy)
            .limited(to: 3)

        #expect(descriptor.limit == 3)
        #expect(descriptor.cachePolicy == cachePolicy)
    }

    @Test("builds a recent-commands observable from the local history store")
    func buildsRecentCommandsObservable() async throws {
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

        let turn = try await thread.startTextTurn("Run git status.")
        let eventTask = Task {
            try await turnEvents(from: turn.events, count: 4)
        }

        await transport.emitTurnStarted(threadID: thread.id, turnID: turn.turn.id)
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-command-1",
            item: [
                "command": "git status",
                "id": "item-command-1",
                "type": "commandExecution",
            ]
        )
        await transport.emitCommandExecutionOutputDelta(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-command-1",
            delta: "On branch main\nnothing to commit, working tree clean\n"
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-command-1",
            item: [
                "command": "git status",
                "id": "item-command-1",
                "status": "completed",
                "type": "commandExecution",
            ]
        )
        await transport.emitTurnCompleted(threadID: thread.id, turnID: turn.turn.id)
        _ = try await eventTask.value

        let recentCommands = try await thread.makeRecentCommands(limit: 4)
        let commandSnapshots = await MainActor.run { recentCommands.commands }

        #expect(commandSnapshots.count == 1)
        #expect(commandSnapshots[0].turnID == turn.turn.id)
        #expect(commandSnapshots[0].command == "git status")
        #expect(commandSnapshots[0].status == .completed)
        #expect(commandSnapshots[0].latestStatusText == "2 output lines")
        #expect(commandSnapshots[0].outputText?.contains("working tree clean") == true)

        await client.stop()
    }

    @MainActor
    @Test("keeps a recent-commands observable live with command output deltas")
    func recentCommandsObservableStaysLive() async throws {
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

        let turn = try await thread.startTextTurn("Run swift test.")
        let recentCommands = try await thread.makeRecentCommands(limit: 3)

        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-command-1",
            item: [
                "command": "swift test",
                "id": "item-command-1",
                "type": "commandExecution",
            ]
        )

        await waitForObservableState {
            recentCommands.commands.count == 1
                && recentCommands.commands[0].status == .inProgress
                && recentCommands.commands[0].command == "swift test"
        }

        await transport.emitCommandExecutionOutputDelta(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-command-1",
            delta: "Building for debugging...\n"
        )
        await transport.emitCommandExecutionOutputDelta(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-command-1",
            delta: "Build complete!\n"
        )

        await waitForObservableState {
            recentCommands.commands[0].outputText?.contains("Build complete!") == true
        }

        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-command-1",
            item: [
                "command": "swift test",
                "id": "item-command-1",
                "status": "completed",
                "type": "commandExecution",
            ]
        )

        await waitForObservableState {
            recentCommands.commands[0].status == .completed
        }

        #expect(recentCommands.commands.count == 1)
        #expect(recentCommands.commands[0].displayName == "swift test")
        #expect(recentCommands.commands[0].status == .completed)
        #expect(
            recentCommands.commands[0].outputText?.isEmpty == false
                || recentCommands.commands[0].latestStatusText?.isEmpty == false
        )

        await client.stop()
    }

    @Test("loads older recent commands from the same turn before older turns")
    func loadsOlderRecentCommandsFromSameTurnFirst() async throws {
        let transport = FakeCodexAppServerTransport(
            threadTurnsListResultQueue: [
                [
                    "backwardsCursor": "cursor-newer-0",
                    "data": [],
                    "nextCursor": "cursor-newer-1",
                ],
                [
                    "backwardsCursor": "cursor-newer-1",
                    "data": [
                        [
                            "completedAt": 1713350100,
                            "durationMs": 2500,
                            "error": NSNull(),
                            "id": "turn-older",
                            "items": [
                                [
                                    "command": "git diff",
                                    "id": "item-command-older-turn",
                                    "status": "completed",
                                    "text": "diff --git a/README.md b/README.md",
                                    "type": "commandExecution",
                                ],
                            ],
                            "startedAt": 1713350050,
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
                        completedAt: 1713350200,
                        durationMS: 2500,
                        errorMessage: nil,
                        id: "turn-newer",
                        startedAt: 1713350150,
                        status: .completed
                    ),
                    items: [
                        .init(
                            id: "item-command-1",
                            kind: .commandExecution,
                            command: "swift build",
                            path: nil,
                            serverName: nil,
                            text: "Compiling SwiftASB",
                            status: "completed",
                            toolName: nil
                        ),
                        .init(
                            id: "item-command-2",
                            kind: .commandExecution,
                            command: "swift test",
                            path: nil,
                            serverName: nil,
                            text: "Build complete!",
                            status: "completed",
                            toolName: nil
                        ),
                    ]
                ),
            ]
        )

        do {
            let recentCommands = try await thread.makeRecentCommands(limit: 1)
            let initialCommands = await MainActor.run { recentCommands.commands }
            #expect(initialCommands.count == 1)
            #expect(initialCommands[0].command == "swift test")

            try await recentCommands.loadOlderCommands(limit: 2)
            let expandedCommands = await MainActor.run { recentCommands.commands }

            #expect(expandedCommands.count == 3)
            #expect(expandedCommands[0].command == "swift test")
            #expect(expandedCommands[1].command == "swift build")
            #expect(expandedCommands[2].command == "git diff")
        }

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @Test("seeds remote older cursors for recent commands even when the initial window is local")
    func seedsRemoteOlderCursorsForLocalRecentCommandWindow() async throws {
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
                            "items": [
                                [
                                    "command": "git status",
                                    "id": "item-command-3",
                                    "status": "completed",
                                    "text": "On branch main",
                                    "type": "commandExecution",
                                ],
                            ],
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
                            "items": [
                                [
                                    "command": "git diff",
                                    "id": "item-command-0",
                                    "status": "completed",
                                    "text": "diff --git",
                                    "type": "commandExecution",
                                ],
                            ],
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
                    items: [
                        .init(
                            id: "item-command-3",
                            kind: .commandExecution,
                            command: "git status",
                            path: nil,
                            serverName: nil,
                            text: "On branch main",
                            status: "completed",
                            toolName: nil
                        ),
                    ]
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
                    items: [
                        .init(
                            id: "item-command-2",
                            kind: .commandExecution,
                            command: "swift build",
                            path: nil,
                            serverName: nil,
                            text: "Compiling",
                            status: "completed",
                            toolName: nil
                        ),
                    ]
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
                    items: [
                        .init(
                            id: "item-command-1",
                            kind: .commandExecution,
                            command: "swift test",
                            path: nil,
                            serverName: nil,
                            text: "Build complete",
                            status: "completed",
                            toolName: nil
                        ),
                    ]
                ),
            ]
        )

        do {
            let recentCommands = try await thread.makeRecentCommands(limit: 1)
            let methodsAfterInitialLoad = await transport.recordedMethods
            #expect(methodsAfterInitialLoad == ["initialize", "initialized", "thread/start", "thread/turns/list"])

            let initialCommands = await MainActor.run { recentCommands.commands }
            #expect(initialCommands.count == 1)
            #expect(initialCommands[0].command == "git status")

            try await recentCommands.loadOlderCommands(limit: 1)
            try await recentCommands.loadOlderCommands(limit: 1)
            let methodsBeforeRemoteFallback = await transport.recordedMethods
            #expect(methodsBeforeRemoteFallback == methodsAfterInitialLoad)

            try await recentCommands.loadOlderCommands(limit: 1)
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

            let expandedCommands = await MainActor.run { recentCommands.commands }
            #expect(expandedCommands.map(\.command) == ["git status", "swift build", "swift test", "git diff"])
            #expect(await MainActor.run { recentCommands.nextOlderCursor } == nil)
        }

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @MainActor
    @Test("command output deltas trigger recent-command cache maintenance")
    func commandOutputDeltasTriggerRecentCommandCacheMaintenance() async throws {
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
                            id: "item-command-older",
                            kind: .commandExecution,
                            command: "git status",
                            path: nil,
                            serverName: nil,
                            text: "done\n",
                            status: "completed",
                            toolName: nil
                        ),
                    ]
                ),
            ]
        )

        let recentCommands = try await thread.makeRecentCommands(
            limit: 2,
            cachePolicy: .init(
                maxResidentCommands: 4,
                minimumResidentCommands: 2,
                maximumResidentOutputCost: 6,
                protectedCommandBuffer: 0,
                protectedRecentCompletedCommands: 0
            )
        )
        let turn = try await thread.startTextTurn("Run swift test.")

        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-command-live",
            item: [
                "command": "swift test",
                "id": "item-command-live",
                "type": "commandExecution",
            ]
        )

        await waitForObservableState {
            recentCommands.commands.count == 2
                && recentCommands.commands[0].status == .inProgress
        }

        await transport.emitCommandExecutionOutputDelta(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-command-live",
            delta: String(repeating: "line\n", count: 40)
        )

        await waitForObservableState {
            guard let olderCommand = recentCommands.commands.first(where: { $0.id == "turn-older:item-command-older" }) else {
                return false
            }
            return olderCommand.isOutputComplete == false && olderCommand.outputText == nil
        }

        let liveCommand = try #require(recentCommands.commands.first(where: { $0.id == "\(turn.turn.id):item-command-live" }))
        let olderCommand = try #require(recentCommands.commands.first(where: { $0.id == "turn-older:item-command-older" }))

        #expect(liveCommand.status == .inProgress)
        #expect(liveCommand.outputText?.contains("line") == true)
        #expect(olderCommand.isOutputComplete == false)
        #expect(olderCommand.outputText == nil)

        await client.stop()
    }

}
