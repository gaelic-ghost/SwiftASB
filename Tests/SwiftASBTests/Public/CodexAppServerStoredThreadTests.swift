import Foundation
import Testing
@testable import SwiftASB

extension CodexAppServerTests {
    @Test("lists stored threads and reconciles archive state into the local history store")
    func listsStoredThreadsAndReconcilesArchiveState() async throws {
        let transport = FakeCodexAppServerTransport(
            threadListResult: [
                "data": [
                    [
                        "cliVersion": "0.128.0",
                        "createdAt": 1713350000,
                        "cwd": "/tmp/project",
                        "ephemeral": false,
                        "id": "thread-123",
                        "modelProvider": "openai",
                        "name": "Archived release prep",
                        "preview": "Summarize the release notes",
                        "source": "cli",
                        "status": ["type": "notLoaded"],
                        "turns": [],
                        "updatedAt": 1713350005,
                    ],
                ],
                "nextCursor": "cursor-next",
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
                approvalPolicy: .onRequest,
                currentDirectoryPath: "/tmp/project",
                ephemeral: false,
                model: "gpt-5.4",
                modelProvider: "openai",
                sandboxMode: .workspaceWrite,
                serviceTier: .fast
            )
        )

        let archivedPage = try await client.listThreads(
            .init(
                limit: 20,
                sortKey: .updatedAt,
                sortDirection: .desc,
                sourceKinds: [.cli],
                archived: true,
                currentDirectoryPath: "/tmp/project"
            )
        )

        #expect(archivedPage.threads.count == 1)
        #expect(archivedPage.threads[0].id == "thread-123")
        #expect(archivedPage.threads[0].name == "Archived release prep")
        #expect(archivedPage.nextCursor == "cursor-next")

        let archivedSnapshot = try await client.debugThreadHistorySnapshot(threadID: "thread-123")
        let archivedThread = try #require(archivedSnapshot)
        #expect(archivedThread.isArchived == true)
        #expect(archivedThread.name == "Archived release prep")
        #expect(archivedThread.statusType == "notLoaded")
        #expect(archivedThread.state.completeness == "partial")

        await transport.setThreadListResult([
            "data": [
                [
                    "cliVersion": "0.128.0",
                    "createdAt": 1713350000,
                    "cwd": "/tmp/project",
                    "ephemeral": false,
                    "id": "thread-123",
                    "modelProvider": "openai",
                    "name": "Active release prep",
                    "preview": "Summarize the release notes",
                    "source": "cli",
                    "status": ["type": "idle"],
                    "turns": [],
                    "updatedAt": 1713350007,
                ],
            ],
        ])

        let activePage = try await client.listThreads(
            .init(
                archived: false,
                currentDirectoryPath: "/tmp/project"
            )
        )

        #expect(activePage.threads.count == 1)
        #expect(activePage.threads[0].name == "Active release prep")
        #expect(activePage.nextCursor == nil)

        let activeSnapshot = try await client.debugThreadHistorySnapshot(threadID: "thread-123")
        let activeThread = try #require(activeSnapshot)
        #expect(activeThread.isArchived == false)
        #expect(activeThread.name == "Active release prep")
        #expect(activeThread.statusType == "idle")

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @Test("resumes a stored thread and hydrates resumed history into the local history store")
    func resumesStoredThreadAndHydratesHistory() async throws {
        let transport = FakeCodexAppServerTransport(
            threadResumeResult: [
                "approvalPolicy": "on-request",
                "approvalsReviewer": "user",
                "cwd": "/tmp/project",
                "instructionSources": ["AGENTS.md"],
                "model": "gpt-5.4",
                "modelProvider": "openai",
                "reasoningEffort": "medium",
                "sandbox": [
                    "type": "workspaceWrite",
                    "networkAccess": "enabled",
                    "writableRoots": ["/tmp/project"],
                ],
                "serviceTier": "fast",
                "thread": [
                    "cliVersion": "0.128.0",
                    "createdAt": 1713350000,
                    "cwd": "/tmp/project",
                    "ephemeral": false,
                    "id": "thread-123",
                    "modelProvider": "openai",
                    "name": "Resumed Thread",
                    "preview": "Hydrated resume preview",
                    "source": "cli",
                    "status": ["type": "idle"],
                    "turns": [
                        [
                            "completedAt": 1713350005,
                            "durationMs": 3000,
                            "error": NSNull(),
                            "id": "turn-hydrated-1",
                            "items": [
                                [
                                    "id": "item-agent-1",
                                    "status": "completed",
                                    "text": "Resumed reply from thread/resume.",
                                    "type": "agentMessage",
                                ],
                            ],
                            "startedAt": 1713350002,
                            "status": "completed",
                        ],
                    ],
                    "updatedAt": 1713350005,
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

        _ = try await client.listThreads(
            .init(
                archived: true,
                currentDirectoryPath: "/tmp/project"
            )
        )

        let thread = try await client.resumeThread(
            .init(
                threadID: "thread-123",
                personality: .friendly
            )
        )

        #expect(thread.id == "thread-123")
        #expect(thread.model == "gpt-5.4")
        #expect(thread.modelProvider == "openai")
        #expect(thread.currentDirectoryPath == "/tmp/project")
        #expect(thread.info.status.type == .idle)
        #expect(thread.info.preview == "Hydrated resume preview")

        let snapshot = try await client.debugThreadHistorySnapshot(threadID: "thread-123")
        let threadSnapshot = try #require(snapshot)
        #expect(threadSnapshot.name == "Resumed Thread")
        #expect(threadSnapshot.isArchived == false)
        #expect(threadSnapshot.statusType == "idle")
        #expect(threadSnapshot.defaults.approvalPolicy == "onRequest")
        #expect(threadSnapshot.defaults.currentDirectoryPath == "/tmp/project")
        #expect(threadSnapshot.turns.count == 1)
        #expect(threadSnapshot.turns[0].id == "turn-hydrated-1")
        #expect(threadSnapshot.turns[0].items.count == 1)
        #expect(threadSnapshot.turns[0].items[0].text == "Resumed reply from thread/resume.")
        #expect(threadSnapshot.state.completeness == "serverParity")

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @Test("forks a stored thread and persists fork lineage plus copied history")
    func forksStoredThreadAndPersistsLineage() async throws {
        let transport = FakeCodexAppServerTransport(
            threadForkResult: [
                "approvalPolicy": "on-request",
                "approvalsReviewer": "user",
                "cwd": "/tmp/project",
                "instructionSources": ["AGENTS.md"],
                "model": "gpt-5.4",
                "modelProvider": "openai",
                "reasoningEffort": "medium",
                "sandbox": [
                    "type": "workspaceWrite",
                    "networkAccess": "enabled",
                    "writableRoots": ["/tmp/project"],
                ],
                "serviceTier": "fast",
                "thread": [
                    "cliVersion": "0.128.0",
                    "createdAt": 1713350010,
                    "cwd": "/tmp/project",
                    "ephemeral": true,
                    "forkedFromId": "thread-123",
                    "id": "thread-456",
                    "modelProvider": "openai",
                    "name": "Forked Thread",
                    "preview": "Hydrated fork preview",
                    "source": "cli",
                    "status": ["type": "idle"],
                    "turns": [
                        [
                            "completedAt": 1713350005,
                            "durationMs": 3000,
                            "error": NSNull(),
                            "id": "turn-shared-1",
                            "items": [
                                [
                                    "id": "item-agent-1",
                                    "status": "completed",
                                    "text": "Forked reply from thread/fork.",
                                    "type": "agentMessage",
                                ],
                            ],
                            "startedAt": 1713350002,
                            "status": "completed",
                        ],
                    ],
                    "updatedAt": 1713350011,
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

        let forkedThread = try await client.forkThread(
            .init(
                threadID: "thread-123",
                ephemeral: true,
                personality: .pragmatic
            )
        )

        #expect(forkedThread.id == "thread-456")
        #expect(forkedThread.info.forkedFromThreadID == "thread-123")
        #expect(forkedThread.info.ephemeral == true)
        #expect(forkedThread.info.status.type == .idle)

        let snapshot = try await client.debugThreadHistorySnapshot(threadID: "thread-456")
        let threadSnapshot = try #require(snapshot)
        #expect(threadSnapshot.forkedFromThreadID == "thread-123")
        #expect(threadSnapshot.forkedFromTurnID == "turn-shared-1")
        #expect(threadSnapshot.isArchived == false)
        #expect(threadSnapshot.turns.count == 1)
        #expect(threadSnapshot.turns[0].id == "turn-shared-1")
        #expect(threadSnapshot.turns[0].items.count == 1)
        #expect(threadSnapshot.turns[0].items[0].id == "item-agent-1")
        #expect(threadSnapshot.turns[0].items[0].text == "Forked reply from thread/fork.")
        #expect(threadSnapshot.state.completeness == "serverParity")

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

}
