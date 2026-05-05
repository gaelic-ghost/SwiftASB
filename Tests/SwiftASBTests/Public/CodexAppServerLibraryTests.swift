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
        #expect(library.archivedThreads.map(\.id) == ["thread-archived"])
        #expect(library.groups.map(\.id) == ["/tmp/project", "/tmp/project-a"])
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
            .limited(to: 10)

        #expect(projectQuery.archived == false)
        #expect(projectQuery.currentDirectoryPath == "/tmp/project-a")
        #expect(projectQuery.limit == 10)
        #expect(projectQuery.sortedBy == .createdNewestFirst)

        let archivedSearch = CodexAppServer.ThreadListQD.search("release", archived: true)
        #expect(archivedSearch.archived == true)
        #expect(archivedSearch.searchTerm == "release")
    }
}

private func storedThread(
    id: String,
    cwd: String,
    name: String,
    preview: String,
    statusType: String,
    updatedAt: Int
) -> [String: Any] {
    [
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
