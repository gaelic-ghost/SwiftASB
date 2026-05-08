import Foundation
import Testing
@testable import SwiftASB

extension CodexAppServerTests {
    @MainActor
    @Test("library publishes local threads first and refresh reconciles app-server pages")
    func libraryPublishesLocalThreadsThenRefreshReconcilesAppServerPages() async throws {
        let transport = FakeCodexAppServerTransport(
            threadListResultQueue: [
                [
                    "data": [
                        storedThread(
                            id: "thread-new",
                            cwd: "/tmp/project-a",
                            gitBranch: "feature/library",
                            name: "Newest active",
                            preview: "Fresh unarchived thread",
                            statusType: "notLoaded",
                            updatedAt: 1713350030
                        ),
                    ],
                    "nextCursor": NSNull(),
                ],
                [
                    "data": [
                        storedThread(
                            id: "thread-archived",
                            cwd: "/tmp/project-b",
                            name: "Archived work",
                            preview: "Stored archived thread",
                            statusType: "notLoaded",
                            updatedAt: 1713350010
                        ),
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

        _ = try await client.startThread(
            .init(
                currentDirectoryPath: "/tmp/project-a",
                ephemeral: false
            )
        )

        let library = try await client.makeLibrary(
            configuration: .init(
                pageSize: 20,
                groupedBy: .cwd,
                reconcilesOnCreation: false
            )
        )

        #expect(library.unarchivedThreads.map(\.id) == ["thread-123"])
        #expect(library.archivedThreads.isEmpty)

        await library.refresh()

        #expect(library.unarchivedThreads.map(\.id) == ["thread-new", "thread-123"])
        #expect(library.unarchivedThreads.first?.projectInfo.repository?.branch == "feature/library")
        #expect(library.archivedThreads.map(\.id) == ["thread-archived"])
        #expect(library.groups.map(\.id) == ["/tmp/project", "/tmp/project-a"])
        #expect(library.groups.first(where: { $0.id == "/tmp/project-a" })?.projectInfo?.identitySource == .currentDirectory)
        #expect(library.groups.first(where: { $0.id == "/tmp/project-a" })?.threads.map(\.id) == ["thread-new"])
        #expect(library.lastReconciledAt != nil)
        #expect(library.latestErrorDescription == nil)

        let archivedSnapshot = try await client.debugThreadHistorySnapshot(threadID: "thread-archived")
        #expect(archivedSnapshot?.isArchived == true)

        let requestPayloads = await transport.requestPayloads(for: "thread/list")
        #expect(requestPayloads.count == 2)
        let firstRequest = try decodedJSONObject(from: requestPayloads[0])
        let secondRequest = try decodedJSONObject(from: requestPayloads[1])
        #expect(value(at: ["params", "archived"], in: firstRequest) as? Bool == false)
        #expect(value(at: ["params", "sortKey"], in: firstRequest) as? String == "updated_at")
        #expect(value(at: ["params", "sortDirection"], in: firstRequest) as? String == "desc")
        #expect(value(at: ["params", "archived"], in: secondRequest) as? Bool == true)

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @MainActor
    @Test("library can group thread snapshots by app-server Git origin")
    func libraryGroupsThreadSnapshotsByRepositoryOrigin() async throws {
        let transport = FakeCodexAppServerTransport(
            threadListResult: [
                "data": [
                    storedThread(
                        id: "thread-package-a",
                        cwd: "/tmp/package-a",
                        gitBranch: "main",
                        gitOriginURL: "https://github.com/gaelic-ghost/SwiftASB.git",
                        gitSHA: "abcdef1234567890",
                        name: "Package A",
                        preview: "First repo thread",
                        statusType: "notLoaded",
                        updatedAt: 1713350030
                    ),
                    storedThread(
                        id: "thread-package-b",
                        cwd: "/tmp/package-b",
                        gitBranch: "feature/project-info",
                        gitOriginURL: "https://github.com/gaelic-ghost/SwiftASB.git",
                        name: "Package B",
                        preview: "Second repo thread",
                        statusType: "notLoaded",
                        updatedAt: 1713350020
                    ),
                    storedThread(
                        id: "thread-standalone",
                        cwd: "/tmp/standalone",
                        name: "Standalone",
                        preview: "No Git origin",
                        statusType: "notLoaded",
                        updatedAt: 1713350010
                    ),
                ],
                "nextCursor": NSNull(),
            ]
        )
        let (historyStore, temporaryDirectory) = try temporarySQLiteHistoryStore()
        let client = CodexAppServer(transport: transport, historyStore: historyStore)

        try await client.start()
        _ = try await client.initialize(
            .init(clientInfo: .init(name: "SwiftASBTests", title: "SwiftASB Tests", version: "0.1.0"))
        )

        let library = try await client.makeLibrary(
            configuration: .init(
                pageSize: 10,
                groupedBy: .repository,
                reconcilesOnCreation: false,
                loadsAppSnapshotsOnCreation: false
            )
        )

        await library.refreshUnarchived()

        #expect(library.groups.map(\.id) == [
            "/tmp/standalone",
            "https://github.com/gaelic-ghost/SwiftASB.git",
        ])
        let repositoryGroup = try #require(
            library.groups.first { $0.id == "https://github.com/gaelic-ghost/SwiftASB.git" }
        )
        #expect(repositoryGroup.title == "SwiftASB (github.com)")
        #expect(repositoryGroup.projectInfo?.identitySource == .gitOrigin)
        #expect(repositoryGroup.projectInfo?.repository?.originURL == "https://github.com/gaelic-ghost/SwiftASB.git")
        #expect(repositoryGroup.projectInfo?.repository?.branch == nil)
        #expect(repositoryGroup.projectInfo?.worktree.id == "https://github.com/gaelic-ghost/SwiftASB.git")
        #expect(repositoryGroup.projectInfo?.worktree.identitySource == .gitOrigin)
        #expect(repositoryGroup.projectInfo?.worktree.hasRepositoryFacts == true)
        #expect(repositoryGroup.threads.map(\.id) == ["thread-package-a", "thread-package-b"])
        #expect(repositoryGroup.threads.first?.worktree.id == "https://github.com/gaelic-ghost/SwiftASB.git")
        #expect(repositoryGroup.threads.first?.worktree.repository?.shortSHA == "abcdef123456")
        #expect(repositoryGroup.threads.first?.projectInfo.repository?.originURL == "https://github.com/gaelic-ghost/SwiftASB.git")
        #expect(repositoryGroup.threads.first?.projectInfo.repository?.branch == "main")
        #expect(repositoryGroup.threads.first?.source == .cli)

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @MainActor
    @Test("library can sort local snapshots by name without changing persistence")
    func librarySortsLocalSnapshotsByName() async throws {
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

        _ = try await client.listThreads(
            .init(archived: false)
        )
        await transport.setThreadListResult([
            "data": [
                storedThread(
                    id: "thread-alpha",
                    cwd: "/tmp/project-a",
                    name: "Alpha",
                    preview: "Alpha preview",
                    statusType: "idle",
                    updatedAt: 1713350002
                ),
            ],
            "nextCursor": NSNull(),
        ])
        _ = try await client.listThreads(
            .init(archived: false)
        )

        let library = try await client.makeLibrary(
            configuration: .init(
                sortedBy: .nameAscending,
                groupedBy: .none,
                reconcilesOnCreation: false
            )
        )

        #expect(library.unarchivedThreads.map(\.name) == ["Alpha", "Hydrated Thread"])
        library.sortedBy = .nameDescending
        #expect(library.unarchivedThreads.map(\.name) == ["Hydrated Thread", "Alpha"])
        #expect(library.groups.isEmpty)

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @MainActor
    @Test("library reloads local snapshots after app-wide thread events")
    func libraryReloadsLocalSnapshotsAfterAppWideThreadEvents() async throws {
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

        let thread = try await client.startThread()
        let library = try await client.makeLibrary(
            configuration: .init(
                groupedBy: .cwd,
                reconcilesOnCreation: false
            )
        )

        #expect(library.unarchivedThreads.map(\.id) == [thread.id])
        #expect(library.archivedThreads.isEmpty)

        await transport.emitThreadArchived(threadID: thread.id)
        await waitForObservableState {
            library.archivedThreads.map(\.id) == [thread.id]
        }
        #expect(library.unarchivedThreads.isEmpty)

        await transport.emitThreadUnarchived(threadID: thread.id)
        await waitForObservableState {
            library.unarchivedThreads.map(\.id) == [thread.id]
        }
        #expect(library.archivedThreads.isEmpty)

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @MainActor
    @Test("library can sort by most recently completed turn")
    func libraryCanSortByMostRecentlyCompletedTurn() async throws {
        let transport = FakeCodexAppServerTransport(
            threadStartIDQueue: ["thread-alpha", "thread-beta"],
            turnStartIDQueue: ["turn-alpha", "turn-beta"]
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
        let alpha = try await client.startThread()
        let beta = try await client.startThread()
        _ = try await alpha.startTextTurn("First prompt")
        await transport.emitTurnCompleted(
            threadID: alpha.id,
            turnID: "turn-alpha",
            completedAt: 1713350005
        )
        _ = try await beta.startTextTurn("Second prompt")
        await transport.emitTurnCompleted(
            threadID: beta.id,
            turnID: "turn-beta",
            completedAt: 1713350010
        )
        try await waitForCondition {
            let snapshot = try await client.debugThreadHistorySnapshot(threadID: beta.id)
            return snapshot?.turns.contains { $0.id == "turn-beta" && $0.completedAt == 1713350010 } == true
        }

        let library = try await client.makeLibrary(
            configuration: .init(
                sortedBy: .turnFinishedNewestFirst,
                groupedBy: .none,
                reconcilesOnCreation: false
            )
        )

        #expect(library.unarchivedThreads.first?.id == beta.id)

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @MainActor
    @Test("library selection is local state and can drive sorting")
    func librarySelectionIsLocalStateAndCanDriveSorting() async throws {
        let transport = FakeCodexAppServerTransport(
            threadListResult: [
                "data": [
                    storedThread(
                        id: "thread-alpha",
                        cwd: "/tmp/project-a",
                        name: "Alpha",
                        preview: "Alpha preview",
                        statusType: "notLoaded",
                        updatedAt: 1713350001
                    ),
                    storedThread(
                        id: "thread-beta",
                        cwd: "/tmp/project-b",
                        name: "Beta",
                        preview: "Beta preview",
                        statusType: "notLoaded",
                        updatedAt: 1713350002
                    ),
                ],
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
        _ = try await client.listThreads()

        let library = try await client.makeLibrary(
            configuration: .init(
                sortedBy: .selectedNewestFirst,
                groupedBy: .none,
                reconcilesOnCreation: false
            )
        )

        #expect(library.unarchivedThreads.map(\.id) == ["thread-beta", "thread-alpha"])
        #expect(library.selectedThreadID == nil)
        #expect(library.selectedThread == nil)

        library.selectThread("thread-alpha")
        #expect(library.selectedThreadID == "thread-alpha")
        #expect(library.selectedThread?.id == "thread-alpha")
        #expect(library.unarchivedThreads.map(\.id) == ["thread-alpha", "thread-beta"])

        library.selectThread("thread-beta")
        #expect(library.selectedThreadID == "thread-beta")
        #expect(library.unarchivedThreads.map(\.id) == ["thread-beta", "thread-alpha"])

        library.clearSelection()
        #expect(library.selectedThreadID == nil)
        #expect(library.selectedThread == nil)
        #expect(library.unarchivedThreads.map(\.id) == ["thread-beta", "thread-alpha"])

        let requestPayloads = await transport.requestPayloads(for: "thread/list")
        #expect(requestPayloads.count == 1)

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @MainActor
    @Test("library refreshes app-wide snapshots for UI consumers")
    func libraryRefreshesAppWideSnapshotsForUIConsumers() async throws {
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
        _ = try await client.listThreads(.init(archived: false))

        let library = try await client.makeLibrary(
            configuration: .init(
                groupedBy: .none,
                reconcilesOnCreation: false,
                loadsAppSnapshotsOnCreation: false,
                mcpServerStatusRequest: .init(limit: 5, detail: .toolsAndAuthOnly)
            )
        )

        #expect(library.modelCapabilities == nil)
        #expect(library.mcpServers.isEmpty)
        #expect(library.hookListSnapshot == nil)
        #expect(library.snapshotPhase == .idle)

        await library.refreshAppSnapshots()

        #expect(library.modelCapabilities?.webSearch == true)
        #expect(library.modelCapabilities?.imageGeneration == true)
        #expect(library.modelCapabilities?.namespaceTools == false)
        #expect(library.mcpServers.map(\.name) == ["calendar"])
        #expect(library.mcpServerNextCursor == nil)
        #expect(library.hookListSnapshot?.entry(forCurrentDirectoryPath: "/tmp/project")?.hasDiagnostics == true)
        #expect(library.snapshotCurrentDirectoryPaths == ["/tmp/project"])
        #expect(library.lastSnapshotsReadAt != nil)
        #expect(library.latestSnapshotErrorDescription == nil)
        #expect(library.snapshotPhase == .idle)

        let capabilitiesPayload = try #require(
            await transport.recordedRequestPayload(for: "modelProvider/capabilities/read")
        )
        let capabilitiesRequest = try decodedJSONObject(from: capabilitiesPayload)
        #expect(capabilitiesRequest["method"] as? String == "modelProvider/capabilities/read")

        let mcpPayload = try #require(await transport.recordedRequestPayload(for: "mcpServerStatus/list"))
        let mcpRequest = try decodedJSONObject(from: mcpPayload)
        #expect(value(at: ["params", "limit"], in: mcpRequest) as? Int == 5)
        #expect(value(at: ["params", "detail"], in: mcpRequest) as? String == "toolsAndAuthOnly")

        let hooksPayload = try #require(await transport.recordedRequestPayload(for: "hooks/list"))
        let hooksRequest = try decodedJSONObject(from: hooksPayload)
        #expect(value(at: ["params", "cwds"], in: hooksRequest) as? [String] == ["/tmp/project"])

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @MainActor
    @Test("library queues app snapshot refresh events during active loads")
    func libraryQueuesAppSnapshotRefreshEventsDuringActiveLoads() async throws {
        let transport = FakeCodexAppServerTransport()
        await transport.setAppSnapshotResponseDelay(nanoseconds: 50_000_000)
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
        _ = try await client.listThreads(.init(archived: false))

        let library = try await client.makeLibrary(
            configuration: .init(
                groupedBy: .none,
                reconcilesOnCreation: false,
                loadsAppSnapshotsOnCreation: false
            )
        )

        let refreshTask = Task { await library.refreshAppSnapshots() }
        await waitForObservableState {
            library.snapshotPhase == .loading
        }

        await transport.emitAppListUpdated()
        await refreshTask.value

        let capabilityRequests = await transport.requestPayloads(for: "modelProvider/capabilities/read")
        let mcpRequests = await transport.requestPayloads(for: "mcpServerStatus/list")
        let hooksRequests = await transport.requestPayloads(for: "hooks/list")

        #expect(capabilityRequests.count == 2)
        #expect(mcpRequests.count == 2)
        #expect(hooksRequests.count == 2)
        #expect(library.snapshotPhase == .idle)

        await client.stop()
    }

    @Test("thread list query descriptors provide common list shapes")
    func threadListQueryDescriptorsProvideCommonListShapes() {
        let projectQuery = CodexAppServer.ThreadListQD
            .cwd(
                "/tmp/project-a",
                archived: false,
                limit: 25,
                sortedBy: .nameAscending
            )
            .sorted(by: .createdNewestFirst)
            .filteringModelProviders(["openai"])
            .limited(to: 10)

        #expect(projectQuery.archived == false)
        #expect(projectQuery.currentDirectoryPath == "/tmp/project-a")
        #expect(projectQuery.limit == 10)
        #expect(projectQuery.modelProviders == ["openai"])
        #expect(projectQuery.sortedBy == .createdNewestFirst)

        let archivedSearch = CodexAppServer.ThreadListQD
            .search(" release ", archived: true)
            .filteringCurrentDirectoryPath("/tmp/releases")
        #expect(archivedSearch.archived == true)
        #expect(archivedSearch.searchTerm == "release")
        #expect(archivedSearch.currentDirectoryPath == "/tmp/releases")

        let normalized = archivedSearch.limited(to: 0).searching("   ")
        #expect(normalized.limit == 1)
        #expect(normalized.searchTerm == nil)
    }

    @Test("thread list query descriptors compile into app-server requests")
    func threadListQueryDescriptorsCompileIntoAppServerRequests() async throws {
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

        _ = try await client.listThreads(
            .cwd(
                "/tmp/project-a",
                archived: false,
                limit: 25,
                sortedBy: .createdOldestFirst
            )
            .filteringModelProviders(["openai"])
            .searching("planning"),
            cursor: "cursor-1"
        )

        let requestPayload = try #require(await transport.recordedRequestPayload(for: "thread/list"))
        let request = try decodedJSONObject(from: requestPayload)
        #expect(value(at: ["params", "archived"], in: request) as? Bool == false)
        #expect(value(at: ["params", "cursor"], in: request) as? String == "cursor-1")
        #expect(value(at: ["params", "cwd"], in: request) as? String == "/tmp/project-a")
        #expect(value(at: ["params", "limit"], in: request) as? Int == 25)
        #expect(value(at: ["params", "modelProviders"], in: request) as? [String] == ["openai"])
        #expect(value(at: ["params", "searchTerm"], in: request) as? String == "planning")
        #expect(value(at: ["params", "sortKey"], in: request) as? String == "created_at")
        #expect(value(at: ["params", "sortDirection"], in: request) as? String == "asc")

        await client.stop()
    }
}

private func storedThread(
    id: String,
    cwd: String,
    gitBranch: String? = nil,
    gitOriginURL: String? = nil,
    gitSHA: String? = nil,
    name: String,
    preview: String,
    statusType: String,
    updatedAt: Int
) -> [String: Any] {
    var thread: [String: Any] = [
        "cliVersion": "0.128.0",
        "createdAt": 1713350000,
        "cwd": cwd,
        "ephemeral": false,
        "id": id,
        "modelProvider": "openai",
        "name": name,
        "preview": preview,
        "source": "cli",
        "status": ["type": statusType],
        "turns": [],
        "updatedAt": updatedAt,
    ]
    if let gitBranch {
        thread["gitInfo"] = [
            "branch": gitBranch,
            "originUrl": gitOriginURL as Any? ?? NSNull(),
            "sha": gitSHA as Any? ?? NSNull(),
        ]
    } else if gitOriginURL != nil || gitSHA != nil {
        thread["gitInfo"] = [
            "branch": NSNull(),
            "originUrl": gitOriginURL as Any? ?? NSNull(),
            "sha": gitSHA as Any? ?? NSNull(),
        ]
    }
    return thread
}

private func decodedJSONObject(from data: Data) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func value(
    at path: [String],
    in object: [String: Any]
) -> Any? {
    var current: Any = object
    for component in path {
        guard let dictionary = current as? [String: Any],
              let next = dictionary[component] else {
            return nil
        }
        current = next
    }
    return current
}
