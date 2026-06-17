import Foundation
@testable import SwiftASB
import Testing

extension CodexAppServerTests {
    @Test("selected recent files keep full payload while older unselected files slim first")
    func selectedRecentFilesStayHydratedDuringPayloadTrim() async throws {
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
                                "id": "item-2-file",
                                "path": "/tmp/project/Sources/App.swift",
                                "status": "completed",
                                "text": String(repeating: "+print(\"newer\")\n", count: 40),
                                "type": "fileChange",
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
                                "id": "item-1-file",
                                "path": "/tmp/project/README.md",
                                "status": "completed",
                                "text": String(repeating: "+Older line\n", count: 40),
                                "type": "fileChange",
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
                        "completedAt": 1_713_350_200,
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
                                "id": "item-1-file",
                                "path": "/tmp/project/README.md",
                                "status": "completed",
                                "text": String(repeating: "+Older line\n", count: 40),
                                "type": "fileChange",
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
                        "completedAt": 1_713_350_200,
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
                                "id": "item-1-file",
                                "path": "/tmp/project/README.md",
                                "status": "completed",
                                "text": "tiny tweak",
                                "type": "fileChange",
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
                            "completedAt": 1_713_350_400,
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
                            "startedAt": 1_713_350_300,
                            "status": "completed",
                        ],
                        [
                            "completedAt": 1_713_349_400,
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
                            "startedAt": 1_713_349_300,
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
                            "completedAt": 1_713_350_300,
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
                            "startedAt": 1_713_350_250,
                            "status": "completed",
                        ],
                    ],
                    "nextCursor": "cursor-older-1",
                ],
                [
                    "backwardsCursor": "cursor-newer-2",
                    "data": [
                        [
                            "completedAt": 1_713_350_005,
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
                            "startedAt": 1_713_350_000,
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
                        completedAt: 1_713_350_300,
                        durationMS: 2500,
                        errorMessage: nil,
                        id: "turn-3",
                        startedAt: 1_713_350_250,
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
                        completedAt: 1_713_350_200,
                        durationMS: 2500,
                        errorMessage: nil,
                        id: "turn-2",
                        startedAt: 1_713_350_150,
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
                        completedAt: 1_713_350_100,
                        durationMS: 2500,
                        errorMessage: nil,
                        id: "turn-1",
                        startedAt: 1_713_350_050,
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
}
