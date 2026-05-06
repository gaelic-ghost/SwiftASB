import Foundation
import Testing
@testable import SwiftASB

extension CodexAppServerTests {
    @Test("recent-file descriptors normalize companion intent")
    func recentFileDescriptorsNormalizeCompanionIntent() {
        let cachePolicy = CodexThread.RecentFiles.CachePolicy(
            maxResidentFiles: 4,
            minimumResidentFiles: 2,
            maximumResidentPayloadCost: 10
        )
        let descriptor = CodexThread.RecentFilesQD
            .recent(limit: 0)
            .cached(by: cachePolicy)
            .limited(to: 3)

        #expect(descriptor.limit == 3)
        #expect(descriptor.cachePolicy == cachePolicy)
    }

    @Test("builds a recent-files observable from the local history store")
    func buildsRecentFilesObservable() async throws {
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

        let turn = try await thread.startTextTurn("Edit the README.")
        let eventTask = Task {
            try await turnEvents(from: turn.events, count: 4)
        }

        await transport.emitTurnStarted(threadID: thread.id, turnID: turn.turn.id)
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-file-1",
            item: [
                "id": "item-file-1",
                "path": "/tmp/project/README.md",
                "type": "fileChange",
            ]
        )
        await transport.emitFileChangeOutputDelta(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-file-1",
            delta: "@@ -1 +1 @@\n-Hello\n+Hello, world\n"
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-file-1",
            item: [
                "id": "item-file-1",
                "path": "/tmp/project/README.md",
                "status": "completed",
                "type": "fileChange",
            ]
        )
        await transport.emitTurnCompleted(threadID: thread.id, turnID: turn.turn.id)
        _ = try await eventTask.value

        let recentFiles = try await thread.makeRecentFiles(limit: 4)
        let fileSnapshots = await MainActor.run { recentFiles.files }

        #expect(fileSnapshots.count == 1)
        #expect(fileSnapshots[0].turnID == turn.turn.id)
        #expect(fileSnapshots[0].path == "/tmp/project/README.md")
        #expect(fileSnapshots[0].status == .completed)
        #expect(fileSnapshots[0].latestStatusText == "1 additions, 1 deletions")
        #expect(fileSnapshots[0].payloadText?.contains("+Hello, world") == true)

        await client.stop()
    }

    @MainActor
    @Test("keeps a recent-files observable live with file item updates")
    func recentFilesObservableStaysLive() async throws {
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

        let turn = try await thread.startTextTurn("Edit the package.")
        let recentFiles = try await thread.makeRecentFiles(limit: 3)

        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-file-1",
            item: [
                "id": "item-file-1",
                "path": "/tmp/project/Package.swift",
                "type": "fileChange",
            ]
        )

        await waitForObservableState {
            recentFiles.files.count == 1
                && recentFiles.files[0].status == .inProgress
                && recentFiles.files[0].path == "/tmp/project/Package.swift"
        }

        await transport.emitFileChangeOutputDelta(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-file-1",
            delta: "dependencies: [\n"
        )
        await transport.emitFileChangeOutputDelta(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-file-1",
            delta: "    .package(url: \"https://example.com\")\n"
        )

        await waitForObservableState(maxAttempts: 2_000) {
            recentFiles.files[0].payloadText?.contains("https://example.com") == true
        }

        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-file-1",
            item: [
                "id": "item-file-1",
                "path": "/tmp/project/Package.swift",
                "status": "completed",
                "type": "fileChange",
            ]
        )

        await waitForObservableState(maxAttempts: 2_000) {
            recentFiles.files[0].status == .completed
                && recentFiles.files[0].payloadText?.contains("https://example.com") == true
        }

        #expect(recentFiles.files.count == 1)
        #expect(recentFiles.files[0].displayName == "Package.swift")
        #expect(recentFiles.files[0].status == .completed)
        #expect(recentFiles.files[0].payloadText?.contains("https://example.com") == true)

        await client.stop()
    }

    @MainActor
    @Test("file output deltas trigger recent-file cache maintenance")
    func fileOutputDeltasTriggerRecentFileCacheMaintenance() async throws {
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
                            id: "item-file-older",
                            kind: .fileChange,
                            command: nil,
                            path: "/tmp/project/README.md",
                            serverName: nil,
                            text: "Older line\n",
                            status: "completed",
                            toolName: nil
                        ),
                    ]
                ),
            ]
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
        let turn = try await thread.startTextTurn("Update Package.swift.")

        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-file-live",
            item: [
                "id": "item-file-live",
                "path": "/tmp/project/Package.swift",
                "type": "fileChange",
            ]
        )

        await waitForObservableState {
            recentFiles.files.count == 2
                && recentFiles.files[0].status == .inProgress
        }

        await transport.emitFileChangeOutputDelta(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-file-live",
            delta: String(repeating: "+dependency\n", count: 40)
        )

        await waitForObservableState {
            guard let olderFile = recentFiles.files.first(where: { $0.id == "turn-older:item-file-older" }) else {
                return false
            }
            return olderFile.isPayloadComplete == false && olderFile.payloadText == nil
        }

        let liveFile = try #require(recentFiles.files.first(where: { $0.id == "\(turn.turn.id):item-file-live" }))
        let olderFile = try #require(recentFiles.files.first(where: { $0.id == "turn-older:item-file-older" }))

        #expect(liveFile.status == .inProgress)
        #expect(liveFile.payloadText?.contains("+dependency") == true)
        #expect(olderFile.isPayloadComplete == false)
        #expect(olderFile.payloadText == nil)

        await client.stop()
    }

}
