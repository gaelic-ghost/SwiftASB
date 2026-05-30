import Foundation
import Testing
@testable import SwiftASB

extension CodexAppServerTests {
    @MainActor
    @Test("hydrates thread MCP status when starting a thread")
    func hydratesThreadMcpStatusWhenStartingThread() async throws {
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

        let thread = try await client.startThread()
        let dashboard = await thread.makeDashboard()

        #expect(thread.mcpServers.map(\.name) == ["calendar", "thread_notes"])
        #expect(thread.mcpServers.map(\.scope) == [.global, .thread])
        #expect(thread.mcpServers.map(\.resourceCount) == [1, 0])
        #expect(thread.mcpServers.map(\.resourceTemplateCount) == [1, 0])
        #expect(thread.mcpServers.map(\.toolCount) == [1, 1])
        #expect(dashboard.mcpServers.map(\.name) == ["calendar", "thread_notes"])
        #expect(dashboard.mcpServers.map(\.scope) == [.global, .thread])

        let requests = await transport.requestPayloads(for: "mcpServerStatus/list")
        let lastPayload = try #require(requests.last)
        let lastRequest = try #require(try JSONSerialization.jsonObject(with: lastPayload) as? [String: Any])
        let lastParams = try #require(lastRequest["params"] as? [String: Any])
        #expect(lastParams["threadId"] as? String == thread.id)

        await client.stop()
    }

    @MainActor
    @Test("starts recent observables locally when live turn history is unavailable before first user message")
    func startsRecentObservablesLocallyBeforeLiveHistoryMaterializes() async throws {
        let transport = FakeCodexAppServerTransport(
            threadTurnsListErrorMessage: """
            thread 019dd4eb-fc9d-7361-9e7d-e7c472c333b8 is not materialized yet; thread/turns/list is unavailable before first user message
            """
        )
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
        let thread = try await client.startThread()

        let recentTurns = try await thread.makeRecentTurns(limit: 4)
        let recentFiles = try await thread.makeRecentFiles(limit: 4)
        let recentCommands = try await thread.makeRecentCommands(limit: 4)

        #expect(recentTurns.turns.isEmpty)
        #expect(recentTurns.nextOlderCursor == nil)
        #expect(recentTurns.nextNewerCursor == nil)
        #expect(recentFiles.files.isEmpty)
        #expect(recentFiles.nextOlderCursor == nil)
        #expect(recentCommands.commands.isEmpty)
        #expect(recentCommands.nextOlderCursor == nil)

        await client.stop()
    }

    @MainActor
    @Test("starts recent observables locally for ephemeral threads without server-paged turn history")
    func startsRecentObservablesLocallyForEphemeralThreads() async throws {
        let transport = FakeCodexAppServerTransport(
            threadTurnsListErrorMessage: "ephemeral threads do not support thread/turns/list"
        )
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
        let thread = try await client.startThread(.init(ephemeral: true))

        let recentTurns = try await thread.makeRecentTurns(limit: 4)
        let recentFiles = try await thread.makeRecentFiles(limit: 4)
        let recentCommands = try await thread.makeRecentCommands(limit: 4)

        #expect(recentTurns.turns.isEmpty)
        #expect(recentFiles.files.isEmpty)
        #expect(recentCommands.commands.isEmpty)

        await client.stop()
    }

    @MainActor
    @Test("preserves unexpected thread turn list failures for recent observable startup")
    func preservesUnexpectedRecentObservableStartupFailures() async throws {
        let transport = FakeCodexAppServerTransport(
            threadTurnsListErrorMessage: "database unavailable while reading turn history"
        )
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
        let thread = try await client.startThread()

        await #expect(throws: CodexAppServerError.self) {
            try await thread.makeRecentTurns(limit: 4)
        }

        await client.stop()
    }

    @Test("sets thread names through the public thread handle")
    func setsThreadNameThroughPublicHandle() async throws {
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
        let thread = try await client.startThread()

        try await thread.setName("Planning Thread")

        let requestPayload = try #require(await transport.recordedRequestPayload(for: "thread/name/set"))
        let request = try #require(try JSONSerialization.jsonObject(with: requestPayload) as? [String: Any])
        let params = try #require(request["params"] as? [String: Any])
        #expect(params["threadId"] as? String == thread.id)
        #expect(params["name"] as? String == "Planning Thread")

        await client.stop()
    }

    @Test("archives and unarchives threads through the public thread handle")
    func archivesAndUnarchivesThroughPublicHandle() async throws {
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
        let thread = try await client.startThread()

        try await thread.archive()
        let unarchived = try await thread.unarchive()

        #expect(unarchived.id == thread.id)

        let archivePayload = try #require(await transport.recordedRequestPayload(for: "thread/archive"))
        let archiveRequest = try #require(try JSONSerialization.jsonObject(with: archivePayload) as? [String: Any])
        let archiveParams = try #require(archiveRequest["params"] as? [String: Any])
        #expect(archiveParams["threadId"] as? String == thread.id)

        let unarchivePayload = try #require(await transport.recordedRequestPayload(for: "thread/unarchive"))
        let unarchiveRequest = try #require(try JSONSerialization.jsonObject(with: unarchivePayload) as? [String: Any])
        let unarchiveParams = try #require(unarchiveRequest["params"] as? [String: Any])
        #expect(unarchiveParams["threadId"] as? String == thread.id)

        await client.stop()
    }

    @Test("updates thread Git metadata through the public thread handle")
    func updatesThreadMetadataThroughPublicHandle() async throws {
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
        let thread = try await client.startThread()

        let updatedThread = try await thread.updateMetadata(
            gitInfo: .init(
                branch: .replace("main"),
                originURL: .clear,
                sha: .replace("abc123")
            )
        )

        #expect(updatedThread.id == thread.id)
        #expect(updatedThread.projectInfo.repository?.branch == "main")
        #expect(updatedThread.projectInfo.repository?.originURL == nil)
        #expect(updatedThread.projectInfo.repository?.sha == "abc123")

        let requestPayload = try #require(await transport.recordedRequestPayload(for: "thread/metadata/update"))
        let request = try #require(try JSONSerialization.jsonObject(with: requestPayload) as? [String: Any])
        let params = try #require(request["params"] as? [String: Any])
        #expect(params["threadId"] as? String == thread.id)

        let gitInfo = try #require(params["gitInfo"] as? [String: Any])
        #expect(gitInfo["branch"] as? String == "main")
        #expect(gitInfo["originUrl"] is NSNull)
        #expect(gitInfo["sha"] as? String == "abc123")

        await client.stop()
    }

    @Test("promotes workspace permission facts and request selections")
    func promotesWorkspacePermissionFactsAndSelections() async throws {
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
                permissions: .init(
                    id: ":workspace",
                    modifications: [
                        .init(additionalWritableRoot: "/tmp/project-fixtures"),
                    ]
                )
            )
        )

        #expect(thread.activePermissionProfile?.id == ":workspace")
        #expect(thread.activePermissionProfile?.modifications.isEmpty == true)
        #expect(thread.permissionProfile == nil)
        #expect(thread.workspace.currentDirectoryPath == "/tmp/project")
        #expect(thread.workspace.projectInfo == thread.info.projectInfo)
        #expect(thread.workspace.projectInfo.currentDirectoryPath == "/tmp/project")
        #expect(thread.info.source == .cli)

        let requestPayload = try #require(await transport.recordedRequestPayload(for: "thread/start"))
        let request = try #require(try JSONSerialization.jsonObject(with: requestPayload) as? [String: Any])
        let params = try #require(request["params"] as? [String: Any])
        #expect(params["permissions"] as? String == ":workspace")

        await client.stop()
    }

    @Test("rolls back thread history and records the rollback marker")
    func rollsBackThreadHistoryAndRecordsMarker() async throws {
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
        _ = try await client.listThreadTurns(
            .init(
                threadID: thread.id,
                limit: 2,
                sortDirection: .desc
            )
        )

        let beforeRollback = try #require(await client.debugThreadHistorySnapshot(threadID: thread.id))
        #expect(beforeRollback.turns.map(\.id) == ["turn-older", "turn-newer"])

        let rolledBackThread = try await thread.rollbackLastTurns(1)

        #expect(rolledBackThread.id == thread.id)
        #expect(rolledBackThread.info.updatedAt == 1713350010)

        let requestPayload = try #require(await transport.recordedRequestPayload(for: "thread/rollback"))
        let request = try #require(try JSONSerialization.jsonObject(with: requestPayload) as? [String: Any])
        let params = try #require(request["params"] as? [String: Any])
        #expect(params["threadId"] as? String == thread.id)
        #expect(params["numTurns"] as? Int == 1)

        let afterRollback = try #require(await client.debugThreadHistorySnapshot(threadID: thread.id))
        #expect(afterRollback.turns.map(\.id) == ["turn-older"])
        #expect(afterRollback.state.completeness == "serverParity")
        #expect(afterRollback.rollbacks.count == 1)
        #expect(afterRollback.rollbacks[0].requestedTurnCount == 1)
        #expect(afterRollback.rollbacks[0].previousNewestTurnID == "turn-newer")
        #expect(afterRollback.rollbacks[0].resultingNewestTurnID == "turn-older")
        #expect(afterRollback.rollbacks[0].removedTurnIDs == ["turn-newer"])
        #expect(afterRollback.rollbacks[0].serverUpdatedAt == 1713350010)

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

}
