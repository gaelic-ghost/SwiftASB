import Foundation
import Testing
@testable import SwiftASB

extension CodexAppServerTests {
    @Test("selected recent files keep full payload while older unselected files slim first")
    func selectedRecentFilesStayHydratedDuringPayloadTrim() async throws {
        let transport = FakeCodexAppServerTransport(
            threadTurnsListResult: [
                "backwardsCursor": "cursor-newer-1",
                "data": [
                    [
                        "completedAt": 1713350200,
                        "durationMs": 2500,
                        "error": NSNull(),
                        "id": "turn-2",
                        "items": [
                            [
                                "id": "item-2-file",
                                "path": "/tmp/project/Sources/App.swift",
                                "status": "completed",
                                "text": String(repeating: "+print(\"newer\")\n", count: 40),
                                "type": "fileChange",
                            ],
                        ],
                        "startedAt": 1713350150,
                        "status": "completed",
                    ],
                    [
                        "completedAt": 1713350100,
                        "durationMs": 2500,
                        "error": NSNull(),
                        "id": "turn-1",
                        "items": [
                            [
                                "id": "item-1-file",
                                "path": "/tmp/project/README.md",
                                "status": "completed",
                                "text": String(repeating: "+Older line\n", count: 40),
                                "type": "fileChange",
                            ],
                        ],
                        "startedAt": 1713350050,
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

        let recentFiles = try await thread.makeRecentFiles(
            limit: 2,
            cachePolicy: .init(
                maxResidentFiles: 4,
                minimumResidentFiles: 2,
                maximumResidentPayloadCost: 6,
                protectedFileBuffer: 0,
                protectedRecentCompletedFiles: 0
            )
        )

        await MainActor.run {
            recentFiles.selectedFileID = "turn-1:item-1-file"
        }

        await waitForObservableState {
            guard recentFiles.files.count == 2 else { return false }
            let selected = recentFiles.files.first(where: { $0.id == "turn-1:item-1-file" })
            let newest = recentFiles.files.first(where: { $0.id == "turn-2:item-2-file" })
            return selected?.isPayloadComplete == true && newest?.isPayloadComplete == false
        }

        let selectedFile = await MainActor.run { recentFiles.files.first(where: { $0.id == "turn-1:item-1-file" }) }
        let newestFile = await MainActor.run { recentFiles.files.first(where: { $0.id == "turn-2:item-2-file" }) }
        let residentPayloadCost = await MainActor.run { recentFiles.residentPayloadCost }

        #expect(try #require(selectedFile).isPayloadComplete == true)
        #expect(try #require(selectedFile).omittedPayloadCharacterCount == 0)
        #expect(try #require(newestFile).isPayloadComplete == false)
        #expect(try #require(newestFile).omittedPayloadCharacterCount > 0)
        #expect(residentPayloadCost < 30)

        await client.stop()
    }

    @Test("a slimmed recent file rehydrates when it becomes selected")
    func slimmedRecentFileRehydratesWhenSelected() async throws {
        let transport = FakeCodexAppServerTransport(
            threadTurnsListResult: [
                "backwardsCursor": "cursor-newer-1",
                "data": [
                    [
                        "completedAt": 1713350200,
                        "durationMs": 2500,
                        "error": NSNull(),
                        "id": "turn-2",
                        "items": [
                            [
                                "id": "item-2-file",
                                "path": "/tmp/project/Sources/App.swift",
                                "status": "completed",
                                "text": String(repeating: "+print(\"newer\")\n", count: 40),
                                "type": "fileChange",
                            ],
                        ],
                        "startedAt": 1713350150,
                        "status": "completed",
                    ],
                    [
                        "completedAt": 1713350100,
                        "durationMs": 2500,
                        "error": NSNull(),
                        "id": "turn-1",
                        "items": [
                            [
                                "id": "item-1-file",
                                "path": "/tmp/project/README.md",
                                "status": "completed",
                                "text": String(repeating: "+Older line\n", count: 40),
                                "type": "fileChange",
                            ],
                        ],
                        "startedAt": 1713350050,
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

        let recentFiles = try await thread.makeRecentFiles(
            limit: 2,
            cachePolicy: .init(
                maxResidentFiles: 4,
                minimumResidentFiles: 2,
                maximumResidentPayloadCost: 6,
                protectedFileBuffer: 0,
                protectedRecentCompletedFiles: 1
            )
        )

        let initialOlderFile = await MainActor.run { recentFiles.files.first(where: { $0.id == "turn-1:item-1-file" }) }
        #expect(try #require(initialOlderFile).isPayloadComplete == false)
        #expect(try #require(initialOlderFile).payloadText == nil)

        await MainActor.run {
            recentFiles.selectedFileID = "turn-1:item-1-file"
        }

        await waitForObservableState {
            recentFiles.files.first(where: { $0.id == "turn-1:item-1-file" })?.isPayloadComplete == true
        }

        let hydratedOlderFile = await MainActor.run { recentFiles.files.first(where: { $0.id == "turn-1:item-1-file" }) }
        #expect(try #require(hydratedOlderFile).omittedPayloadCharacterCount == 0)
        #expect(try #require(hydratedOlderFile).payloadText?.contains("Older line") == true)

        await client.stop()
    }

    @Test("recent-file payload cost scales with diff structure instead of only raw bytes")
    func recentFilePayloadCostTracksDiffStructure() async throws {
        let transport = FakeCodexAppServerTransport(
            threadTurnsListResult: [
                "backwardsCursor": "cursor-newer-1",
                "data": [
                    [
                        "completedAt": 1713350200,
                        "durationMs": 2500,
                        "error": NSNull(),
                        "id": "turn-2",
                        "items": [
                            [
                                "id": "item-2-file",
                                "path": "/tmp/project/Sources/App.swift",
                                "status": "completed",
                                "text": """
                                @@ -1,2 +1,3 @@
                                -old one
                                +new one
                                @@ -10,2 +10,4 @@
                                -old two
                                +new two
                                +new three
                                """,
                                "type": "fileChange",
                            ],
                        ],
                        "startedAt": 1713350150,
                        "status": "completed",
                    ],
                    [
                        "completedAt": 1713350100,
                        "durationMs": 2500,
                        "error": NSNull(),
                        "id": "turn-1",
                        "items": [
                            [
                                "id": "item-1-file",
                                "path": "/tmp/project/README.md",
                                "status": "completed",
                                "text": "tiny tweak",
                                "type": "fileChange",
                            ],
                        ],
                        "startedAt": 1713350050,
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

        let recentFiles = try await thread.makeRecentFiles(limit: 2)
        let files = await MainActor.run { recentFiles.files }
        let structuredDiffFile = try #require(files.first(where: { $0.id == "turn-2:item-2-file" }))
        let smallEditFile = try #require(files.first(where: { $0.id == "turn-1:item-1-file" }))

        #expect(structuredDiffFile.latestStatusText == "3 additions, 2 deletions, 2 hunks")
        #expect(smallEditFile.latestStatusText == "tiny tweak")
        #expect(await MainActor.run { recentFiles.residentPayloadCost } > 2)

        await client.stop()
    }

    @Test("loads older recent files from the same turn before older turns")
    func loadsOlderRecentFilesFromSameTurnFirst() async throws {
        let transport = FakeCodexAppServerTransport(
            threadTurnsListResultQueue: [
                [
                    "backwardsCursor": "cursor-newer-0",
                    "data": [],
                    "nextCursor": "cursor-older-1",
                ],
                [
                    "backwardsCursor": NSNull(),
                    "data": [
                        [
                            "completedAt": 1713350400,
                            "durationMs": 500,
                            "error": NSNull(),
                            "id": "turn-newer",
                            "items": [
                                [
                                    "id": "item-file-newer-1",
                                    "path": "/tmp/project/Package.swift",
                                    "status": "completed",
                                    "type": "fileChange",
                                ],
                                [
                                    "id": "item-file-newer-2",
                                    "path": "/tmp/project/Sources/App.swift",
                                    "status": "completed",
                                    "type": "fileChange",
                                ],
                            ],
                            "startedAt": 1713350300,
                            "status": "completed",
                        ],
                        [
                            "completedAt": 1713349400,
                            "durationMs": 500,
                            "error": NSNull(),
                            "id": "turn-older",
                            "items": [
                                [
                                    "id": "item-file-older",
                                    "path": "/tmp/project/README.md",
                                    "status": "completed",
                                    "type": "fileChange",
                                ],
                            ],
                            "startedAt": 1713349300,
                            "status": "completed",
                        ],
                    ],
                    "nextCursor": NSNull(),
                ]
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

        do {
            let recentFiles = try await thread.makeRecentFiles(limit: 1)
            let initialFiles = await MainActor.run { recentFiles.files }
            #expect(initialFiles.count == 1)
            #expect(initialFiles[0].path == "/tmp/project/Sources/App.swift")

            try await recentFiles.loadOlderFiles(limit: 2)
            let expandedFiles = await MainActor.run { recentFiles.files }

            #expect(expandedFiles.count == 3)
            #expect(expandedFiles[0].path == "/tmp/project/Sources/App.swift")
            #expect(expandedFiles[1].path == "/tmp/project/Package.swift")
            #expect(expandedFiles[2].path == "/tmp/project/README.md")
        }

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @Test("seeds remote older cursors for recent files even when the initial window is local")
    func seedsRemoteOlderCursorsForLocalRecentFileWindow() async throws {
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
                                    "id": "item-file-3",
                                    "path": "/tmp/project/Package.swift",
                                    "status": "completed",
                                    "type": "fileChange",
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
                                    "id": "item-file-0",
                                    "path": "/tmp/project/Docs/Guide.md",
                                    "status": "completed",
                                    "type": "fileChange",
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
                            id: "item-file-3",
                            kind: .fileChange,
                            command: nil,
                            path: "/tmp/project/Package.swift",
                            serverName: nil,
                            text: nil,
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
                            id: "item-file-2",
                            kind: .fileChange,
                            command: nil,
                            path: "/tmp/project/Sources/App.swift",
                            serverName: nil,
                            text: nil,
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
                            id: "item-file-1",
                            kind: .fileChange,
                            command: nil,
                            path: "/tmp/project/README.md",
                            serverName: nil,
                            text: nil,
                            status: "completed",
                            toolName: nil
                        ),
                    ]
                ),
            ]
        )

        do {
            let recentFiles = try await thread.makeRecentFiles(limit: 1)
            let methodsAfterInitialLoad = await transport.recordedMethods
            #expect(methodsAfterInitialLoad == ["initialize", "initialized", "thread/start", "thread/turns/list"])

            let initialFiles = await MainActor.run { recentFiles.files }
            #expect(initialFiles.count == 1)
            #expect(initialFiles[0].path == "/tmp/project/Package.swift")

            try await recentFiles.loadOlderFiles(limit: 1)
            try await recentFiles.loadOlderFiles(limit: 1)
            let methodsBeforeRemoteFallback = await transport.recordedMethods
            #expect(methodsBeforeRemoteFallback == methodsAfterInitialLoad)

            try await recentFiles.loadOlderFiles(limit: 1)
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

            let expandedFiles = await MainActor.run { recentFiles.files }
            #expect(expandedFiles.map(\.path) == [
                "/tmp/project/Package.swift",
                "/tmp/project/Sources/App.swift",
                "/tmp/project/README.md",
                "/tmp/project/Docs/Guide.md",
            ])
            #expect(await MainActor.run { recentFiles.nextOlderCursor } == nil)
        }

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

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
            recordedMethods == [
                "initialize",
                "initialized",
                "thread/start",
                "thread/turns/list",
                "thread/turns/list",
            ]
        )

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
                        "completedAt": 1713350300,
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
                        "startedAt": 1713350250,
                        "status": "completed",
                    ],
                    [
                        "completedAt": 1713350200,
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
                        "startedAt": 1713350150,
                        "status": "completed",
                    ],
                    [
                        "completedAt": 1713350100,
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
                        "completedAt": 1713350200,
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
                        "startedAt": 1713350150,
                        "status": "completed",
                    ],
                    [
                        "completedAt": 1713350100,
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
                        "startedAt": 1713350050,
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
                        "completedAt": 1713350200,
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
                        "startedAt": 1713350150,
                        "status": "completed",
                    ],
                    [
                        "completedAt": 1713350100,
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
                        "startedAt": 1713350050,
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
                        "completedAt": 1713350200,
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
                        "startedAt": 1713350150,
                        "status": "completed",
                    ],
                    [
                        "completedAt": 1713350100,
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
                        "startedAt": 1713350050,
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
