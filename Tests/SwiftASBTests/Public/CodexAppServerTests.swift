import Foundation
import Testing
@testable import SwiftASB

@Suite("CodexAppServer", .serialized)
struct CodexAppServerTests {
    @Test("requires initialize before starting a thread")
    func requiresInitializeBeforeStartingThread() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()

        await #expect(throws: CodexAppServerError.self) {
            try await client.startThread()
        }

        await client.stop()
    }

    @Test("surfaces Codex CLI diagnostics after start")
    func surfacesCodexCLIDiagnosticsAfterStart() async throws {
        let transport = FakeCodexAppServerTransport(
            executableResolution: .init(
                launchExecutableURL: URL(fileURLWithPath: "/opt/homebrew/bin/codex"),
                launchArgumentsPrefix: [],
                resolvedExecutableURL: URL(fileURLWithPath: "/opt/homebrew/bin/codex"),
                source: .homebrewAppleSilicon,
                versionString: "codex-cli 0.128.0",
                compatibility: .supported(documentedWindow: "0.128.x")
            )
        )
        let client = CodexAppServer(transport: transport)

        try await client.start()

        let diagnostics = try await client.cliExecutableDiagnostics()
        #expect(diagnostics.source == .homebrewAppleSilicon)
        #expect(diagnostics.resolvedExecutablePath == "/opt/homebrew/bin/codex")
        #expect(diagnostics.versionString == "codex-cli 0.128.0")
        #expect(diagnostics.compatibility == .supported(documentedWindow: "0.128.x"))

        await client.stop()
    }

    @Test("lists app-wide models through the public client")
    func listsAppWideModels() async throws {
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

        let page = try await client.listModels(
            .init(cursor: "cursor-start", limit: 2, includeHidden: true)
        )

        #expect(page.nextCursor == "cursor-models-next")
        #expect(page.models.count == 1)
        #expect(page.models[0].id == "gpt-5.4")
        #expect(page.models[0].displayName == "GPT-5.4")
        #expect(page.models[0].defaultReasoningEffort == .medium)
        #expect(page.models[0].supportedReasoningEfforts.map(\.reasoningEffort) == [.low, .medium, .high])
        #expect(page.models[0].inputModalities == [.text, .image])

        let requestPayload = try #require(await transport.recordedRequestPayload(for: "model/list"))
        let request = try #require(try JSONSerialization.jsonObject(with: requestPayload) as? [String: Any])
        let params = try #require(request["params"] as? [String: Any])
        #expect(params["cursor"] as? String == "cursor-start")
        #expect(params["limit"] as? Int == 2)
        #expect(params["includeHidden"] as? Bool == true)

        await client.stop()
    }

    @Test("lists app-wide MCP server status through the public client")
    func listsAppWideMcpServerStatus() async throws {
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

        let page = try await client.listMcpServerStatuses(
            .init(cursor: "cursor-start", limit: 4, detail: .toolsAndAuthOnly)
        )

        #expect(page.nextCursor == nil)
        #expect(page.servers.count == 1)
        #expect(page.servers[0].name == "calendar")
        #expect(page.servers[0].authStatus == .oAuth)
        #expect(page.servers[0].resources[0].uri == "calendar://events/today")
        #expect(page.servers[0].resourceTemplates[0].uriTemplate == "calendar://events/{date}")
        #expect(page.servers[0].tools["list_events"]?.title == "List Events")
        #expect(page.servers[0].tools["list_events"]?.inputSchema == .object(["type": .string("object")]))

        let requestPayload = try #require(await transport.recordedRequestPayload(for: "mcpServerStatus/list"))
        let request = try #require(try JSONSerialization.jsonObject(with: requestPayload) as? [String: Any])
        let params = try #require(request["params"] as? [String: Any])
        #expect(params["cursor"] as? String == "cursor-start")
        #expect(params["limit"] as? Int == 4)
        #expect(params["detail"] as? String == "toolsAndAuthOnly")

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
        #expect(updatedThread.gitInfo?.branch == "main")
        #expect(updatedThread.gitInfo?.originURL == nil)
        #expect(updatedThread.gitInfo?.sha == "abc123")

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

    @Test("runs initialize, thread/start, and turn/start through the public client")
    func runsInitializeAndFirstLifecycleRequests() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()

        let initializeSession = try await client.initialize(
            .init(
                capabilities: .init(
                    experimentalAPI: true,
                    optOutNotificationMethods: ["turn/completed"]
                ),
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        #expect(initializeSession.codexHome == "/Users/galew/.codex")
        #expect(initializeSession.platformFamily == "unix")
        #expect(initializeSession.platformOS == "macos")
        #expect(initializeSession.userAgent == "codex-cli/0.128.0")

        let thread = try await client.startThread(
            .init(
                approvalPolicy: .onRequest,
                currentDirectoryPath: "/tmp/project",
                ephemeral: false,
                model: "gpt-5.4",
                modelProvider: "openai",
                sandboxMode: .workspaceWrite,
                serviceTier: .fast,
                sessionStartSource: .clear
            )
        )

        #expect(thread.model == "gpt-5.4")
        #expect(thread.modelProvider == "openai")
        #expect(thread.currentDirectoryPath == "/tmp/project")
        #expect(thread.serviceTier == .fast)
        #expect(thread.id == "thread-123")
        #expect(thread.info.status.type == .active)
        #expect(thread.info.preview == "Hello from the fake app-server")

        let turnHandle = try await thread.startTextTurn(
            "Hello from SwiftASB",
            effort: .medium,
            model: "gpt-5.4",
            summary: .concise
        )

        #expect(turnHandle.threadID == thread.id)
        #expect(turnHandle.turn.id == "turn-123")
        #expect(turnHandle.turn.status == .inProgress)
        #expect(turnHandle.turn.startedAt == 1713350002)

        let firstEventTask = Task {
            try await turnEvents(from: turnHandle.events, count: 9)
        }

        await transport.emitTurnStarted(
            threadID: thread.id,
            turnID: turnHandle.turn.id
        )
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-plan-1"
        )
        await transport.emitTurnPlanUpdated(
            threadID: thread.id,
            turnID: turnHandle.turn.id
        )
        await transport.emitPlanDelta(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-plan-1"
        )
        await transport.emitAgentMessageDelta(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-agent-1"
        )
        await transport.emitReasoningTextDelta(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-reasoning-1"
        )
        await transport.emitReasoningSummaryTextDelta(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-reasoning-1"
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-agent-1"
        )
        await transport.emitTurnCompleted(
            threadID: thread.id,
            turnID: turnHandle.turn.id
        )

        let receivedEvents = try await firstEventTask.value
        #expect(receivedEvents.count == 9)

        switch receivedEvents[0] {
        case let .started(started):
            #expect(started.threadID == thread.id)
            #expect(started.turn.id == turnHandle.turn.id)
            #expect(started.turn.status == .inProgress)
        default:
            Issue.record("Expected the first streamed event to be .started.")
        }

        switch receivedEvents[1] {
        case let .itemStarted(itemStarted):
            #expect(itemStarted.threadID == thread.id)
            #expect(itemStarted.turnID == turnHandle.turn.id)
            #expect(itemStarted.item.id == "item-plan-1")
            #expect(itemStarted.item.kind == .plan)
            #expect(itemStarted.item.text == nil)
        default:
            Issue.record("Expected the second streamed event to be .itemStarted.")
        }

        switch receivedEvents[2] {
        case let .planUpdated(update):
            #expect(update.threadID == thread.id)
            #expect(update.turnID == turnHandle.turn.id)
            #expect(update.explanation == "Map richer progress notifications.")
            #expect(update.plan.count == 2)
            #expect(update.plan.first?.status == .inProgress)
            #expect(update.plan.last?.status == .pending)
        default:
            Issue.record("Expected the third streamed event to be .planUpdated.")
        }

        switch receivedEvents[3] {
        case let .planDelta(delta):
            #expect(delta.threadID == thread.id)
            #expect(delta.turnID == turnHandle.turn.id)
            #expect(delta.itemID == "item-plan-1")
            #expect(delta.delta == "Stream partial plan text")
        default:
            Issue.record("Expected the fourth streamed event to be .planDelta.")
        }

        switch receivedEvents[4] {
        case let .agentMessageDelta(delta):
            #expect(delta.threadID == thread.id)
            #expect(delta.turnID == turnHandle.turn.id)
            #expect(delta.itemID == "item-agent-1")
            #expect(delta.delta == "Working on it")
        default:
            Issue.record("Expected the fifth streamed event to be .agentMessageDelta.")
        }

        switch receivedEvents[5] {
        case let .reasoningTextDelta(delta):
            #expect(delta.threadID == thread.id)
            #expect(delta.turnID == turnHandle.turn.id)
            #expect(delta.itemID == "item-reasoning-1")
            #expect(delta.contentIndex == 0)
            #expect(delta.delta == "thinking...")
        default:
            Issue.record("Expected the sixth streamed event to be .reasoningTextDelta.")
        }

        switch receivedEvents[6] {
        case let .reasoningSummaryTextDelta(delta):
            #expect(delta.threadID == thread.id)
            #expect(delta.turnID == turnHandle.turn.id)
            #expect(delta.itemID == "item-reasoning-1")
            #expect(delta.summaryIndex == 0)
            #expect(delta.delta == "Summarizing the approach.")
        default:
            Issue.record("Expected the seventh streamed event to be .reasoningSummaryTextDelta.")
        }

        switch receivedEvents[7] {
        case let .itemCompleted(itemCompleted):
            #expect(itemCompleted.threadID == thread.id)
            #expect(itemCompleted.turnID == turnHandle.turn.id)
            #expect(itemCompleted.item.id == "item-agent-1")
            #expect(itemCompleted.item.kind == .agentMessage)
            #expect(itemCompleted.item.text == "Done.")
            #expect(itemCompleted.item.status == "completed")
        default:
            Issue.record("Expected the eighth streamed event to be .itemCompleted.")
        }

        switch receivedEvents[8] {
        case let .completed(completion):
            #expect(completion.threadID == thread.id)
            #expect(completion.turn.id == turnHandle.turn.id)
            #expect(completion.turn.status == CodexAppServer.TurnStatus.completed)
            #expect(completion.turn.completedAt == 1713350005)
        default:
            Issue.record("Expected the ninth streamed event to be .completed.")
        }

        let recordedMethods = await transport.recordedMethods
        #expect(recordedMethods == ["initialize", "initialized", "thread/start", "turn/start"])

        await client.stop()
    }

    @Test("persists sealed turn history in the internal thread history store")
    func persistsSealedTurnHistory() async throws {
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

        let turn = try await thread.startTextTurn(
            "Summarize the project state.",
            approvalPolicy: .onRequest,
            summary: .concise
        )

        let eventTask = Task {
            try await turnEvents(from: turn.events, count: 7)
        }

        await transport.emitTurnStarted(threadID: thread.id, turnID: turn.turn.id)
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-plan-1"
        )
        await transport.emitPlanDelta(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-plan-1"
        )
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-agent-1",
            item: [
                "id": "item-agent-1",
                "type": "agentMessage",
            ]
        )
        await transport.emitAgentMessageDelta(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-agent-1"
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-agent-1"
        )
        await transport.emitThreadTokenUsageUpdated(
            threadID: thread.id,
            turnID: turn.turn.id
        )
        await transport.emitTurnCompleted(threadID: thread.id, turnID: turn.turn.id)
        _ = try await eventTask.value
        await transport.emitThreadNameUpdated(threadID: thread.id, threadName: nil)
        await transport.emitThreadClosed(threadID: thread.id)

        try await waitForCondition {
            let snapshot = try await client.debugThreadHistorySnapshot(threadID: thread.id)
            return snapshot?.isClosed == true && snapshot?.name == nil
        }

        let snapshot = try await client.debugThreadHistorySnapshot(threadID: thread.id)
        let threadSnapshot = try #require(snapshot)
        #expect(threadSnapshot.defaults.approvalPolicy == "onRequest")
        #expect(threadSnapshot.defaults.currentDirectoryPath == "/tmp/project")
        #expect(threadSnapshot.defaults.model == "gpt-5.4")
        #expect(threadSnapshot.defaults.serviceTier == "fast")
        #expect(threadSnapshot.state.completeness == "partial")
        #expect(threadSnapshot.isClosed == true)
        #expect(threadSnapshot.name == nil)
        #expect(threadSnapshot.turns.count == 1)
        #expect(threadSnapshot.turns[0].status == "completed")
        #expect(threadSnapshot.turns[0].items.count == 2)
        #expect(threadSnapshot.turns[0].items[0].kind == "plan")
        #expect(threadSnapshot.turns[0].items[0].streamedText == "Stream partial plan text")
        #expect(threadSnapshot.turns[0].items[1].kind == "agentMessage")
        #expect(threadSnapshot.turns[0].items[1].streamedText == "Working on it")
        #expect(threadSnapshot.turns[0].tokenUsage?.totalTokens == 65)

        await client.stop()
    }

    @Test("completes a turn handle into a final sealed turn snapshot")
    func completesTurnHandle() async throws {
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

        let turn = try await thread.startTextTurn("Summarize the project state.")
        let eventTask = Task {
            try await turnEvents(from: turn.events, count: 5)
        }

        await transport.emitTurnStarted(threadID: thread.id, turnID: turn.turn.id)
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-agent-1",
            item: [
                "id": "item-agent-1",
                "type": "agentMessage",
            ]
        )
        await transport.emitAgentMessageDelta(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-agent-1"
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-agent-1"
        )
        await transport.emitTurnCompleted(threadID: thread.id, turnID: turn.turn.id)
        _ = try await eventTask.value

        let closedTurn = try await turn.complete()
        #expect(closedTurn.id == turn.turn.id)
        #expect(closedTurn.threadID == thread.id)
        #expect(closedTurn.status == "completed")
        #expect(closedTurn.items.count == 1)
        #expect(closedTurn.items[0].text == "Done.")

        await client.stop()
    }

    @Test("completing a turn finishes its live turn stream")
    func completingTurnFinishesTurnStream() async throws {
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

        let turn = try await thread.startTextTurn("Summarize the project state.")
        let eventTask = Task {
            try await turnEvents(from: turn.events, count: 5)
        }

        await transport.emitTurnStarted(threadID: thread.id, turnID: turn.turn.id)
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-agent-1",
            item: [
                "id": "item-agent-1",
                "type": "agentMessage",
            ]
        )
        await transport.emitAgentMessageDelta(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-agent-1"
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-agent-1"
        )
        await transport.emitTurnCompleted(threadID: thread.id, turnID: turn.turn.id)
        _ = try await eventTask.value

        _ = try await turn.complete()
        let nextEvent = try await nextTurnEventOrEnd(from: turn.events)
        #expect(nextEvent == nil)

        await client.stop()
    }

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

    @Test("builds a recent-turns observable from the local history store")
    func buildsRecentTurnsObservable() async throws {
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

        let turn = try await thread.startTextTurn("Summarize the project state.")
        let eventTask = Task {
            try await turnEvents(from: turn.events, count: 5)
        }

        await transport.emitTurnStarted(threadID: thread.id, turnID: turn.turn.id)
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-agent-1",
            item: [
                "id": "item-agent-1",
                "type": "agentMessage",
            ]
        )
        await transport.emitAgentMessageDelta(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-agent-1"
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-agent-1"
        )
        await transport.emitTurnCompleted(threadID: thread.id, turnID: turn.turn.id)
        _ = try await eventTask.value

        let recentTurns = try await thread.makeRecentTurns(limit: 4)
        let recentSnapshots = await MainActor.run { recentTurns.turns }

        #expect(recentSnapshots.count == 1)
        #expect(recentSnapshots[0].id == turn.turn.id)
        #expect(recentSnapshots[0].status == "completed")
        #expect(recentSnapshots[0].items.count == 1)
        #expect(recentSnapshots[0].items[0].text == "Done.")

        await client.stop()
    }

    @Test("reads non-UI recent and directional local turn history windows through CodexThread")
    func readsNonUIThreadHistory() async throws {
        let transport = FakeCodexAppServerTransport(
            threadTurnsListResult: [
                "backwardsCursor": NSNull(),
                "data": [],
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
                            id: "item-older",
                            kind: .agentMessage,
                            command: nil,
                            path: nil,
                            serverName: nil,
                            text: "Older turn",
                            status: "completed",
                            toolName: nil
                        ),
                    ]
                ),
                ThreadHistoryStore.HydratedTurn(
                    turn: CodexAppServer.TurnInfo(
                        completedAt: 1713350105,
                        durationMS: 2500,
                        errorMessage: nil,
                        id: "turn-middle",
                        startedAt: 1713350100,
                        status: .completed
                    ),
                    items: [
                        .init(
                            id: "item-middle",
                            kind: .agentMessage,
                            command: nil,
                            path: nil,
                            serverName: nil,
                            text: "Middle turn",
                            status: "completed",
                            toolName: nil
                        ),
                    ]
                ),
                ThreadHistoryStore.HydratedTurn(
                    turn: CodexAppServer.TurnInfo(
                        completedAt: 1713350255,
                        durationMS: 2500,
                        errorMessage: nil,
                        id: "turn-newest",
                        startedAt: 1713350250,
                        status: .completed
                    ),
                    items: [
                        .init(
                            id: "item-newest",
                            kind: .agentMessage,
                            command: nil,
                            path: nil,
                            serverName: nil,
                            text: "Newest turn",
                            status: "completed",
                            toolName: nil
                        ),
                    ]
                ),
                ThreadHistoryStore.HydratedTurn(
                    turn: CodexAppServer.TurnInfo(
                        completedAt: 1713350205,
                        durationMS: 2500,
                        errorMessage: nil,
                        id: "turn-newer",
                        startedAt: 1713350200,
                        status: .completed
                    ),
                    items: [
                        .init(
                            id: "item-newer",
                            kind: .agentMessage,
                            command: nil,
                            path: nil,
                            serverName: nil,
                            text: "Newer turn",
                            status: "completed",
                            toolName: nil
                        ),
                    ]
                ),
            ]
        )

        let recentWindow = try await thread.readRecentTurnHistoryWindow(limit: 2)
        #expect(recentWindow.turns.map(\.id) == ["turn-newest", "turn-newer"])
        #expect(recentWindow.newestTurnID == "turn-newest")
        #expect(recentWindow.oldestTurnID == "turn-newer")
        #expect(recentWindow.hasNewerTurns == false)
        #expect(recentWindow.hasOlderTurns)

        let recentTurns = try await thread.readRecentTurnHistory(limit: 2)
        #expect(recentTurns.map(\.id) == ["turn-newest", "turn-newer"])

        let readTurn = try await thread.readTurnHistory(turnID: "turn-middle")
        #expect(readTurn?.id == "turn-middle")
        #expect(readTurn?.items.first?.text == "Middle turn")

        let olderWindow = try await thread.readOlderTurnHistoryWindow(olderThan: "turn-middle", limit: 2)
        #expect(olderWindow.turns.map(\.id) == ["turn-older"])
        #expect(olderWindow.hasNewerTurns)
        #expect(olderWindow.hasOlderTurns == false)

        let olderTurns = try await thread.readOlderTurnHistory(olderThan: "turn-middle", limit: 2)
        #expect(olderTurns.map(\.id) == ["turn-older"])

        let newerWindow = try await thread.readNewerTurnHistoryWindow(newerThan: "turn-middle", limit: 1)
        #expect(newerWindow.turns.map(\.id) == ["turn-newer"])
        #expect(newerWindow.hasOlderTurns)
        #expect(newerWindow.hasNewerTurns)

        let newerTurns = try await thread.readNewerTurnHistory(newerThan: "turn-middle", limit: 1)
        #expect(newerTurns.map(\.id) == ["turn-newer"])

        let turnCenteredWindow = try await thread.windowAroundTurn("turn-middle", limit: 3)
        #expect(turnCenteredWindow.turns.map(\.id) == ["turn-newer", "turn-middle", "turn-older"])
        #expect(turnCenteredWindow.hasNewerTurns)
        #expect(turnCenteredWindow.hasOlderTurns == false)

        let itemCenteredWindow = try await thread.windowAroundItem("item-middle", limit: 2)
        #expect(itemCenteredWindow.turns.map(\.id) == ["turn-middle", "turn-older"])
        #expect(itemCenteredWindow.hasNewerTurns)
        #expect(itemCenteredWindow.hasOlderTurns == false)

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @Test("directional non-UI turn history requires a known local boundary turn")
    func nonUIThreadHistoryRequiresKnownBoundaryTurn() async throws {
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

        await #expect(throws: CodexAppServerError.self) {
            try await thread.readOlderTurnHistory(olderThan: "missing-turn", limit: 1)
        }
        await #expect(throws: CodexAppServerError.self) {
            try await thread.windowAroundTurn("missing-turn", limit: 1)
        }
        await #expect(throws: CodexAppServerError.self) {
            try await thread.windowAroundItem("missing-item", limit: 1)
        }

        await client.stop()
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

        await waitForObservableState {
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
        #expect(recentCommands.commands[0].outputText?.contains("Build complete!") == true)

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

    @Test("reads a stored thread and hydrates returned turns into the local history store")
    func readsStoredThreadAndHydratesHistory() async throws {
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

        let result = try await client.readThread(
            .init(
                threadID: "thread-123",
                includeTurns: true
            )
        )

        #expect(result.thread.id == "thread-123")
        #expect(result.thread.status.type == .notLoaded)
        #expect(result.turns.count == 1)
        #expect(result.turns[0].status == .completed)

        let snapshot = try await client.debugThreadHistorySnapshot(threadID: "thread-123")
        let threadSnapshot = try #require(snapshot)
        #expect(threadSnapshot.turns.count == 1)
        #expect(threadSnapshot.turns[0].items.count == 2)
        #expect(threadSnapshot.turns[0].items[0].kind == "userMessage")
        #expect(threadSnapshot.turns[0].items[1].kind == "agentMessage")
        #expect(threadSnapshot.turns[0].items[1].text == "Hydrated reply from thread/read.")
        #expect(threadSnapshot.state.completeness == "serverParity")

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @Test("preserves richer local item detail when thread/read returns a thinner overlapping turn")
    func preservesRicherLocalItemDetailDuringHydration() async throws {
        let transport = FakeCodexAppServerTransport(
            threadReadResult: [
                "thread": [
                    "cliVersion": "0.128.0",
                    "createdAt": 1713350000,
                    "cwd": "/tmp/project",
                    "ephemeral": false,
                    "id": "thread-123",
                    "modelProvider": "openai",
                    "preview": "Hydrated overlap preview",
                    "source": "cli",
                    "status": ["type": "notLoaded"],
                    "turns": [
                        [
                            "completedAt": 1713350005,
                            "durationMs": 3000,
                            "error": NSNull(),
                            "id": "turn-123",
                            "items": [
                                [
                                    "id": "item-agent-1",
                                    "status": "completed",
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
        let turn = try await thread.startTextTurn("Summarize the project state.")
        let eventTask = Task {
            try await turnEvents(from: turn.events, count: 4)
        }

        await transport.emitTurnStarted(threadID: thread.id, turnID: turn.turn.id)
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-agent-1",
            item: [
                "id": "item-agent-1",
                "type": "agentMessage",
            ]
        )
        await transport.emitAgentMessageDelta(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-agent-1"
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-agent-1",
            item: [
                "id": "item-agent-1",
                "status": "completed",
                "type": "agentMessage",
            ]
        )
        await transport.emitTurnCompleted(threadID: thread.id, turnID: turn.turn.id)
        _ = try await eventTask.value

        _ = try await client.readThread(
            .init(
                threadID: thread.id,
                includeTurns: true
            )
        )

        let snapshot = try await client.debugThreadHistorySnapshot(threadID: thread.id)
        let threadSnapshot = try #require(snapshot)
        let overlappingTurn = try #require(threadSnapshot.turns.first { $0.id == "turn-123" })
        let overlappingItem = try #require(overlappingTurn.items.first { $0.id == "item-agent-1" })
        #expect(overlappingItem.streamedText == "Working on it")
        #expect(overlappingItem.status == "completed")
        #expect(threadSnapshot.state.completeness == "richerThanServer")

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @Test("promotes overlapping item status to terminal server state without dropping richer local detail")
    func promotesOverlappingItemStatusToTerminalServerState() async throws {
        let transport = FakeCodexAppServerTransport(
            threadReadResult: [
                "thread": [
                    "cliVersion": "0.128.0",
                    "createdAt": 1713350000,
                    "cwd": "/tmp/project",
                    "ephemeral": false,
                    "id": "thread-123",
                    "modelProvider": "openai",
                    "preview": "Hydrated overlap preview",
                    "source": "cli",
                    "status": ["type": "notLoaded"],
                    "turns": [
                        [
                            "completedAt": 1713350005,
                            "durationMs": 3000,
                            "error": NSNull(),
                            "id": "turn-123",
                            "items": [
                                [
                                    "id": "item-command-1",
                                    "status": "completed",
                                    "type": "commandExecution",
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
        let turn = try await thread.startTextTurn("Run the diagnostics command.")
        let eventTask = Task {
            try await turnEvents(from: turn.events, count: 4)
        }

        await transport.emitTurnStarted(threadID: thread.id, turnID: turn.turn.id)
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-command-1",
            item: [
                "id": "item-command-1",
                "command": "swift test",
                "status": "in_progress",
                "type": "commandExecution",
            ]
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turn.turn.id,
            itemID: "item-command-1",
            item: [
                "id": "item-command-1",
                "command": "swift test",
                "status": "in_progress",
                "type": "commandExecution",
            ]
        )
        await transport.emitTurnCompleted(threadID: thread.id, turnID: turn.turn.id)
        _ = try await eventTask.value

        _ = try await client.readThread(
            .init(
                threadID: thread.id,
                includeTurns: true
            )
        )

        let snapshot = try await client.debugThreadHistorySnapshot(threadID: thread.id)
        let threadSnapshot = try #require(snapshot)
        let overlappingTurn = try #require(threadSnapshot.turns.first { $0.id == "turn-123" })
        let overlappingItem = try #require(overlappingTurn.items.first { $0.id == "item-command-1" })
        #expect(overlappingItem.command == "swift test")
        #expect(overlappingItem.status == "completed")
        #expect(threadSnapshot.state.completeness == "richerThanServer")

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @Test("lists stored thread turns and hydrates paged history into the local history store")
    func listsStoredThreadTurnsAndHydratesHistory() async throws {
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

        let page = try await client.listThreadTurns(
            .init(
                threadID: "thread-123",
                limit: 2,
                sortDirection: .desc
            )
        )

        #expect(page.turns.count == 2)
        #expect(page.nextCursor == "cursor-older")
        #expect(page.backwardsCursor == "cursor-newer")

        let snapshot = try await client.debugThreadHistorySnapshot(threadID: "thread-123")
        let threadSnapshot = try #require(snapshot)
        #expect(threadSnapshot.turns.count == 2)
        #expect(threadSnapshot.turns[0].id == "turn-older")
        #expect(threadSnapshot.turns[1].id == "turn-newer")

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @Test("lists stored thread turns for a thread that has not been hydrated locally yet")
    func listsStoredThreadTurnsForUnknownLocalThread() async throws {
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

        let page = try await client.listThreadTurns(
            .init(
                threadID: "thread-123",
                limit: 2,
                sortDirection: .desc
            )
        )

        #expect(page.turns.count == 2)

        let snapshot = try await client.debugThreadHistorySnapshot(threadID: "thread-123")
        let threadSnapshot = try #require(snapshot)
        #expect(threadSnapshot.id == "thread-123")
        #expect(threadSnapshot.statusType == "notLoaded")
        #expect(threadSnapshot.turns.count == 2)

        await client.stop()
        await tearDownTemporarySQLiteHistoryStore(historyStore, directory: temporaryDirectory)
    }

    @Test("streams thread lifecycle notifications through CodexThread.events")
    func streamsThreadLifecycleNotifications() async throws {
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
                currentDirectoryPath: "/tmp/project",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )

        let threadEventsTask = Task {
            try await threadEvents(from: thread.events, count: 7)
        }

        for _ in 0..<5 {
            await Task.yield()
        }

        await transport.emitThreadStarted(threadID: thread.id)
        await transport.emitThreadStatusChanged(threadID: thread.id)
        await transport.emitThreadArchived(threadID: thread.id)
        await transport.emitThreadUnarchived(threadID: thread.id)
        await transport.emitThreadNameUpdated(threadID: thread.id)
        await transport.emitThreadTokenUsageUpdated(threadID: thread.id, turnID: "turn-123")
        await transport.emitThreadClosed(threadID: thread.id)

        let receivedEvents = try await threadEventsTask.value
        #expect(receivedEvents.count == 7)
        guard receivedEvents.count == 7 else {
            await client.stop()
            return
        }

        switch receivedEvents[0] {
        case let .started(started):
            #expect(started.thread.id == thread.id)
            #expect(started.thread.preview == "Hello from thread/started")
        default:
            Issue.record("Expected the first thread event to be .started.")
        }

        switch receivedEvents[1] {
        case let .statusChanged(change):
            #expect(change.threadID == thread.id)
            #expect(change.status.type == .active)
            #expect(change.status.activeFlags == [.waitingOnApproval])
        default:
            Issue.record("Expected the second thread event to be .statusChanged.")
        }

        switch receivedEvents[2] {
        case let .archived(event):
            #expect(event.threadID == thread.id)
        default:
            Issue.record("Expected the third thread event to be .archived.")
        }

        switch receivedEvents[3] {
        case let .unarchived(event):
            #expect(event.threadID == thread.id)
        default:
            Issue.record("Expected the fourth thread event to be .unarchived.")
        }

        switch receivedEvents[4] {
        case let .nameUpdated(update):
            #expect(update.threadID == thread.id)
            #expect(update.threadName == "Planning Thread")
        default:
            Issue.record("Expected the fifth thread event to be .nameUpdated.")
        }

        switch receivedEvents[5] {
        case let .tokenUsageUpdated(update):
            #expect(update.threadID == thread.id)
            #expect(update.turnID == "turn-123")
            #expect(update.last.totalTokens == 65)
            #expect(update.total.totalTokens == 650)
            #expect(update.modelContextWindow == 200000)
        default:
            Issue.record("Expected the sixth thread event to be .tokenUsageUpdated.")
        }

        switch receivedEvents[6] {
        case let .closed(event):
            #expect(event.threadID == thread.id)
        default:
            Issue.record("Expected the seventh thread event to be .closed.")
        }

        await client.stop()
    }

    @MainActor
    @Test("streams diagnostics through app, thread, and turn public surfaces")
    func streamsDiagnosticsThroughPublicSurfaces() async throws {
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
                currentDirectoryPath: "/tmp/project",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )
        let turnHandle = try await thread.startTextTurn("Trigger diagnostic surfaces.")
        let dashboard = await thread.makeDashboard()
        let minimap = turnHandle.minimap

        let appDiagnosticsTask = Task {
            try await diagnosticEvents(from: await client.diagnosticEvents(), count: 4)
        }
        let threadEventsTask = Task {
            try await threadEvents(from: thread.events, count: 4)
        }
        let turnEventsTask = Task {
            try await turnEvents(from: turnHandle.events, count: 2)
        }

        for _ in 0..<5 {
            await Task.yield()
        }

        await transport.emitWarning(threadID: thread.id)
        await transport.emitGuardianWarning(threadID: thread.id)
        await transport.emitModelRerouted(threadID: thread.id, turnID: turnHandle.turn.id)
        await transport.emitModelVerification(threadID: thread.id, turnID: turnHandle.turn.id)

        let appDiagnostics = try await appDiagnosticsTask.value
        #expect(appDiagnostics.count == 4)
        #expect(appDiagnostics.map(\.threadID) == [thread.id, thread.id, thread.id, thread.id])
        #expect(appDiagnostics.map(\.turnID) == [nil, nil, turnHandle.turn.id, turnHandle.turn.id])

        let receivedThreadEvents = try await threadEventsTask.value
        #expect(receivedThreadEvents.count == 4)
        guard receivedThreadEvents.count == 4 else {
            await client.stop()
            return
        }

        switch receivedThreadEvents[0] {
        case let .diagnostic(.warning(warning)):
            #expect(warning.threadID == thread.id)
            #expect(warning.message == "Runtime configuration is using a fallback.")
        default:
            Issue.record("Expected the first thread diagnostic to be a runtime warning.")
        }

        switch receivedThreadEvents[1] {
        case let .diagnostic(.guardianWarning(warning)):
            #expect(warning.threadID == thread.id)
            #expect(warning.message == "Guardian flagged this session for review.")
        default:
            Issue.record("Expected the second thread diagnostic to be a guardian warning.")
        }

        switch receivedThreadEvents[2] {
        case let .diagnostic(.modelRerouted(reroute)):
            #expect(reroute.threadID == thread.id)
            #expect(reroute.turnID == turnHandle.turn.id)
            #expect(reroute.fromModel == "gpt-5.4")
            #expect(reroute.toModel == "gpt-5.4-safe")
            #expect(reroute.reason == CodexModelReroute.Reason.highRiskCyberActivity)
        default:
            Issue.record("Expected the third thread diagnostic to be a model reroute.")
        }

        switch receivedThreadEvents[3] {
        case let .diagnostic(.modelVerification(verification)):
            #expect(verification.threadID == thread.id)
            #expect(verification.turnID == turnHandle.turn.id)
            #expect(verification.verifications == [CodexModelVerification.trustedAccessForCyber])
        default:
            Issue.record("Expected the fourth thread diagnostic to be a model verification.")
        }

        let receivedTurnEvents = try await turnEventsTask.value
        #expect(receivedTurnEvents.count == 2)
        guard receivedTurnEvents.count == 2 else {
            await client.stop()
            return
        }

        switch receivedTurnEvents[0] {
        case let .diagnostic(.modelRerouted(reroute)):
            #expect(reroute.threadID == thread.id)
            #expect(reroute.turnID == turnHandle.turn.id)
        default:
            Issue.record("Expected the first turn diagnostic to be a model reroute.")
        }

        switch receivedTurnEvents[1] {
        case let .diagnostic(.modelVerification(verification)):
            #expect(verification.threadID == thread.id)
            #expect(verification.turnID == turnHandle.turn.id)
            #expect(verification.verifications == [CodexModelVerification.trustedAccessForCyber])
        default:
            Issue.record("Expected the second turn diagnostic to be a model verification.")
        }

        await waitForObservableState {
            dashboard.latestDiagnostic?.turnID == turnHandle.turn.id
                && minimap.latestDiagnostic?.turnID == turnHandle.turn.id
        }

        switch dashboard.latestDiagnostic {
        case let .modelVerification(verification):
            #expect(verification.threadID == thread.id)
            #expect(verification.turnID == turnHandle.turn.id)
        default:
            Issue.record("Expected the thread dashboard to retain the latest model verification diagnostic.")
        }

        switch minimap.latestDiagnostic {
        case let .modelVerification(verification):
            #expect(verification.threadID == thread.id)
            #expect(verification.turnID == turnHandle.turn.id)
        default:
            Issue.record("Expected the turn minimap to retain the latest model verification diagnostic.")
        }

        await client.stop()
    }

    @Test("streams app-wide diagnostics without a thread target")
    func streamsAppWideDiagnosticsWithoutThreadTarget() async throws {
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

        let appDiagnosticsTask = Task {
            try await diagnosticEvents(from: await client.diagnosticEvents(), count: 1)
        }

        for _ in 0..<5 {
            await Task.yield()
        }

        await transport.emitWarning(threadID: nil, message: "Global configuration warning.")

        let appDiagnostics = try await appDiagnosticsTask.value
        #expect(appDiagnostics.count == 1)

        switch appDiagnostics.first {
        case let .warning(warning):
            #expect(warning.threadID == nil)
            #expect(warning.message == "Global configuration warning.")
        default:
            Issue.record("Expected an app-wide runtime warning diagnostic.")
        }

        await client.stop()
    }

    @Test("finishes diagnostics stream when server-event decoding fails")
    func finishesDiagnosticsStreamWhenServerEventDecodingFails() async throws {
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

        let nextDiagnosticTask = Task {
            try await nextDiagnosticEventOrEnd(from: await client.diagnosticEvents())
        }

        for _ in 0..<5 {
            await Task.yield()
        }

        await transport.emitMalformedModelRerouted()

        do {
            _ = try await nextDiagnosticTask.value
            Issue.record("Expected diagnostics stream to finish with a server-event decoding error.")
        } catch {
            #expect(String(describing: error).contains("server events"))
        }

        await client.stop()
    }

    @Test("interrupts a turn through CodexTurnHandle")
    func interruptsTurnThroughHandle() async throws {
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
                currentDirectoryPath: "/tmp/project",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )
        let turnHandle = try await thread.startTextTurn("Please stop when asked.")

        try await turnHandle.interrupt()

        let recordedMethods = await transport.recordedMethods
        #expect(
            recordedMethods == [
                "initialize",
                "initialized",
                "thread/start",
                "turn/start",
                "turn/interrupt",
            ]
        )

        let interruptRequest = try #require(await transport.recordedRequestPayload(for: "turn/interrupt"))
        let requestObject = try #require(
            try JSONSerialization.jsonObject(with: interruptRequest) as? [String: Any]
        )
        let params = try #require(requestObject["params"] as? [String: Any])
        #expect(params["threadId"] as? String == thread.id)
        #expect(params["turnId"] as? String == turnHandle.turn.id)

        await client.stop()
    }

    @Test("steers a turn through CodexTurnHandle")
    func steersTurnThroughHandle() async throws {
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
                currentDirectoryPath: "/tmp/project",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )
        let turnHandle = try await thread.startTextTurn("Please draft an answer.")

        try await turnHandle.steerText("Please make it shorter and more direct.")

        let recordedMethods = await transport.recordedMethods
        #expect(
            recordedMethods == [
                "initialize",
                "initialized",
                "thread/start",
                "turn/start",
                "turn/steer",
            ]
        )

        let steerRequest = try #require(await transport.recordedRequestPayload(for: "turn/steer"))
        let requestObject = try #require(
            try JSONSerialization.jsonObject(with: steerRequest) as? [String: Any]
        )
        let params = try #require(requestObject["params"] as? [String: Any])
        #expect(params["threadId"] as? String == thread.id)
        #expect(params["expectedTurnId"] as? String == turnHandle.turn.id)

        let input = try #require(params["input"] as? [[String: Any]])
        #expect(input.count == 1)
        #expect(input.first?["type"] as? String == "text")
        #expect(input.first?["text"] as? String == "Please make it shorter and more direct.")

        await client.stop()
    }

    @Test("compacts thread context through CodexThread")
    func compactsThreadContextThroughThreadHandle() async throws {
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
                currentDirectoryPath: "/tmp/project",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )

        try await thread.compactContext()

        let recordedMethods = await transport.recordedMethods
        #expect(recordedMethods == ["initialize", "initialized", "thread/start", "thread/compact/start"])

        let compactRequest = try #require(await transport.recordedRequestPayload(for: "thread/compact/start"))
        let requestObject = try #require(
            try JSONSerialization.jsonObject(with: compactRequest) as? [String: Any]
        )
        let params = try #require(requestObject["params"] as? [String: Any])
        #expect(params["threadId"] as? String == thread.id)

        await client.stop()
    }

    @Test("rejects overlapping same-thread turn starts until the active turn completes")
    func rejectsOverlappingSameThreadTurns() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        do {
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
                    currentDirectoryPath: "/tmp/project",
                    model: "gpt-5.4",
                    modelProvider: "openai"
                )
            )

            let firstTurn = try await thread.startTextTurn("First live turn")
            #expect(firstTurn.turn.id == "turn-123")

            do {
                _ = try await thread.startTextTurn("Second overlapping live turn")
                Issue.record("Expected overlapping same-thread turn start to be rejected.")
            } catch let error as CodexAppServerError {
                switch error {
                case let .invalidState(reason):
                    #expect(reason.contains("overlapping same-thread turns") || reason.contains("already has an active turn"))
                default:
                    Issue.record("Expected overlapping same-thread turn start to throw an invalidState error.")
                }
            }

            let recordedMethodsBeforeCompletion = await transport.recordedMethods
            #expect(recordedMethodsBeforeCompletion == ["initialize", "initialized", "thread/start", "turn/start"])

            let completionTask = Task {
                for try await event in firstTurn.events {
                    if case let .completed(completion) = event {
                        return completion
                    }
                }

                Issue.record("Expected the first turn event stream to finish with a completed event.")
                throw CancellationError()
            }

            await transport.emitTurnCompleted(
                threadID: thread.id,
                turnID: firstTurn.turn.id
            )
            let completion = try await completionTask.value
            #expect(completion.turn.id == firstTurn.turn.id)
            #expect(completion.threadID == thread.id)

            let secondTurn = try await thread.startTextTurn("Second live turn after completion")
            #expect(secondTurn.turn.id == "turn-123")

            let recordedMethodsAfterCompletion = await transport.recordedMethods
            #expect(recordedMethodsAfterCompletion == ["initialize", "initialized", "thread/start", "turn/start", "turn/start"])

            await client.stop()
        } catch {
            await client.stop()
            throw error
        }
    }

    @Test("buffers early interactive turn events and answers command approvals through CodexTurnHandle")
    func buffersInteractiveTurnEventsAndAnswersApproval() async throws {
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
                currentDirectoryPath: "/tmp/project",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )

        let turnHandle = try await thread.startTextTurn("Review the patch.")
        var iterator = turnHandle.events.makeAsyncIterator()
        await transport.emitCommandExecutionApprovalRequest(
            requestID: .string("approval-1"),
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-command-1"
        )

        let firstEvent = try await iterator.next()
        guard case let .approvalRequested(approvalRequest)? = firstEvent else {
            Issue.record("Expected the first buffered turn event to be .approvalRequested.")
            await client.stop()
            return
        }

        guard case let .commandExecution(commandRequest) = approvalRequest else {
            Issue.record("Expected the buffered approval request to be a command execution approval.")
            await client.stop()
            return
        }

        #expect(commandRequest.threadID == thread.id)
        #expect(commandRequest.turnID == turnHandle.turn.id)
        #expect(commandRequest.itemID == "item-command-1")
        #expect(commandRequest.command == "git status")
        #expect(commandRequest.reason == "Needs approval to read repository state.")

        try await turnHandle.respond(
            to: approvalRequest,
            with: .commandExecution(.acceptWithExecPolicyAmendment(["workspace-write"]))
        )

        await transport.emitServerRequestResolved(
            threadID: thread.id,
            requestID: .string("approval-1")
        )

        let secondEvent = try await iterator.next()
        guard case let .serverRequestResolved(resolution)? = secondEvent else {
            Issue.record("Expected the follow-up turn event to be .serverRequestResolved.")
            await client.stop()
            return
        }

        #expect(resolution.threadID == thread.id)
        #expect(resolution.turnID == turnHandle.turn.id)
        #expect(resolution.kind == .commandExecutionApproval)

        let recordedResponses = await transport.recordedResponses
        #expect(recordedResponses.count == 1)
        #expect(recordedResponses.first?.requestID == .string("approval-1"))
        let responseObject = try #require(
            try JSONSerialization.jsonObject(with: recordedResponses[0].payload) as? [String: Any]
        )
        #expect(responseObject["id"] as? String == "approval-1")
        let responseResult = try #require(responseObject["result"] as? [String: Any])
        let decision = try #require(responseResult["decision"] as? [String: Any])
        let amendment = try #require(decision["acceptWithExecpolicyAmendment"] as? [String: Any])
        #expect(amendment["execpolicy_amendment"] as? [String] == ["workspace-write"])

        await client.stop()
    }

    @Test("rejects interactive approval responses sent through the wrong surface")
    func rejectsApprovalResponsesSentThroughWrongSurface() async throws {
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
                currentDirectoryPath: "/tmp/project",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )

        let turnHandle = try await thread.startTextTurn("Review the patch.")
        await transport.emitCommandExecutionApprovalRequest(
            requestID: .string("approval-1"),
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-command-1"
        )

        guard case let .approvalRequested(approvalRequest)? = try await turnHandle.events.first(where: { _ in true }) else {
            Issue.record("Expected a turn-scoped approval request.")
            await client.stop()
            return
        }

        do {
            try await thread.respond(
                to: approvalRequest,
                with: .commandExecution(.accept)
            )
            Issue.record("Expected a turn-scoped approval response sent through CodexThread to fail.")
        } catch let error as CodexAppServerError {
            guard case let .invalidState(reason) = error else {
                Issue.record("Expected an invalidState error for the wrong response surface.")
                await client.stop()
                return
            }
            #expect(reason.contains("belongs to a specific turn"))
            #expect(reason.contains("CodexTurnHandle"))
        }

        #expect(await transport.recordedResponses.isEmpty)

        await client.stop()
    }

    @Test("rejects mismatched and already resolved approval responses")
    func rejectsMismatchedAndResolvedApprovalResponses() async throws {
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
                currentDirectoryPath: "/tmp/project",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )

        let turnHandle = try await thread.startTextTurn("Review the patch.")
        var iterator = turnHandle.events.makeAsyncIterator()
        await transport.emitCommandExecutionApprovalRequest(
            requestID: .string("approval-1"),
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-command-1"
        )

        guard case let .approvalRequested(approvalRequest)? = try await iterator.next() else {
            Issue.record("Expected a command approval request.")
            await client.stop()
            return
        }

        do {
            try await turnHandle.respond(
                to: approvalRequest,
                with: .fileChange(.accept)
            )
            Issue.record("Expected a mismatched approval response kind to fail.")
        } catch let error as CodexAppServerError {
            guard case let .invalidState(reason) = error else {
                Issue.record("Expected an invalidState error for a mismatched approval response kind.")
                await client.stop()
                return
            }
            #expect(reason.contains("response kind did not match"))
        }

        #expect(await transport.recordedResponses.isEmpty)

        try await turnHandle.respond(
            to: approvalRequest,
            with: .commandExecution(.accept)
        )
        await transport.emitServerRequestResolved(
            threadID: thread.id,
            requestID: .string("approval-1")
        )

        guard case .serverRequestResolved? = try await iterator.next() else {
            Issue.record("Expected the command approval request to resolve.")
            await client.stop()
            return
        }

        do {
            try await turnHandle.respond(
                to: approvalRequest,
                with: .commandExecution(.accept)
            )
            Issue.record("Expected responding to an already resolved approval request to fail.")
        } catch let error as CodexAppServerError {
            guard case let .invalidState(reason) = error else {
                Issue.record("Expected an invalidState error for an already resolved approval response.")
                await client.stop()
                return
            }
            #expect(reason.contains("No outstanding interactive server request"))
        }

        #expect(await transport.recordedResponses.count == 1)

        await client.stop()
    }

    @Test("rejects interactive approval responses through the wrong thread route")
    func rejectsApprovalResponsesThroughWrongThreadRoute() async throws {
        let transport = FakeCodexAppServerTransport(
            threadStartIDQueue: ["thread-route-a", "thread-route-b"]
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

        let firstThread = try await client.startThread(
            .init(
                currentDirectoryPath: "/tmp/project-a",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )
        let firstTurn = try await firstThread.startTextTurn("Review the first patch.")
        await transport.emitCommandExecutionApprovalRequest(
            requestID: .string("approval-1"),
            threadID: firstThread.id,
            turnID: firstTurn.turn.id,
            itemID: "item-command-1"
        )

        guard case let .approvalRequested(approvalRequest)? = try await firstTurn.events.first(where: { _ in true }) else {
            Issue.record("Expected a turn-scoped approval request on the first thread.")
            await client.stop()
            return
        }

        let secondThread = try await client.startThread(
            .init(
                currentDirectoryPath: "/tmp/project-b",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )
        let secondTurn = try await secondThread.startTextTurn("Review the second patch.")

        do {
            try await secondTurn.respond(
                to: approvalRequest,
                with: .commandExecution(.accept)
            )
            Issue.record("Expected a response through a different active turn route to fail.")
        } catch let error as CodexAppServerError {
            guard case let .invalidState(reason) = error else {
                Issue.record("Expected an invalidState error for a mismatched active thread route.")
                await client.stop()
                return
            }
            #expect(reason.contains("belongs to thread \(firstThread.id)"))
            #expect(reason.contains("not thread \(secondThread.id)"))
        }

        #expect(await transport.recordedResponses.isEmpty)

        await client.stop()
    }

    @Test("routes unroutable MCP elicitation requests through CodexThread and answers them there")
    func routesUnroutableMcpElicitationsThroughThread() async throws {
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
                currentDirectoryPath: "/tmp/project",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )

        var iterator = thread.events.makeAsyncIterator()

        await transport.emitMcpServerElicitationRequest(
            requestID: .string("mcp-1"),
            threadID: thread.id,
            turnID: nil
        )

        let firstEvent = try await iterator.next()
        guard case let .elicitationRequested(request)? = firstEvent else {
            Issue.record("Expected the first thread event to be .elicitationRequested.")
            await client.stop()
            return
        }

        guard case let .mcpServer(mcpRequest) = request else {
            Issue.record("Expected the thread elicitation event to contain an MCP server request.")
            await client.stop()
            return
        }

        #expect(mcpRequest.threadID == thread.id)
        #expect(mcpRequest.turnID == nil)
        #expect(mcpRequest.serverName == "calendar")

        try await thread.respond(
            to: request,
            with: .mcpServer(.init(action: .decline))
        )

        await transport.emitServerRequestResolved(
            threadID: thread.id,
            requestID: .string("mcp-1")
        )

        let secondEvent = try await iterator.next()
        guard case let .serverRequestResolved(resolution)? = secondEvent else {
            Issue.record("Expected the follow-up thread event to be .serverRequestResolved.")
            await client.stop()
            return
        }

        #expect(resolution.threadID == thread.id)
        #expect(resolution.turnID == nil)
        #expect(resolution.kind == .mcpServerElicitation)

        let recordedResponses = await transport.recordedResponses
        #expect(recordedResponses.count == 1)
        #expect(recordedResponses.first?.requestID == .string("mcp-1"))
        let responseObject = try #require(
            try JSONSerialization.jsonObject(with: recordedResponses[0].payload) as? [String: Any]
        )
        let responseResult = try #require(responseObject["result"] as? [String: Any])
        #expect(responseResult["action"] as? String == "decline")

        await client.stop()
    }

    @Test("answers tool user input requests through CodexTurnHandle")
    func answersToolUserInputRequests() async throws {
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
                currentDirectoryPath: "/tmp/project",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )

        let turnHandle = try await thread.startTextTurn("Ask the user a question.")
        let eventTask = Task {
            try await turnEvents(from: turnHandle.events, count: 1)
        }

        await transport.emitToolUserInputRequest(
            requestID: .string("input-1"),
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-input-1"
        )

        let receivedEvents = try await eventTask.value
        guard case let .elicitationRequested(request) = receivedEvents[0] else {
            Issue.record("Expected the turn event to be .elicitationRequested.")
            await client.stop()
            return
        }

        guard case let .toolUserInput(inputRequest) = request else {
            Issue.record("Expected the elicitation event to contain a tool user input request.")
            await client.stop()
            return
        }

        #expect(inputRequest.questions.count == 1)
        #expect(inputRequest.questions[0].header == "Goal")
        #expect(inputRequest.questions[0].options?.count == 2)

        try await turnHandle.respond(
            to: request,
            with: .toolUserInput(
                .init(
                    answers: [
                        "goal": .init(answers: ["Ship it"])
                    ]
                )
            )
        )

        let recordedResponses = await transport.recordedResponses
        #expect(recordedResponses.count == 1)
        #expect(recordedResponses.first?.requestID == .string("input-1"))
        let responseObject = try #require(
            try JSONSerialization.jsonObject(with: recordedResponses[0].payload) as? [String: Any]
        )
        let responseResult = try #require(responseObject["result"] as? [String: Any])
        let answers = try #require(responseResult["answers"] as? [String: Any])
        let goalAnswer = try #require(answers["goal"] as? [String: Any])
        #expect(goalAnswer["answers"] as? [String] == ["Ship it"])

        await client.stop()
    }

    @MainActor
    @Test("builds a dashboard that stays live with thread events")
    func buildsThreadDashboard() async throws {
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
                currentDirectoryPath: "/tmp/project",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )

        let turnHandle = try await thread.startTextTurn("Track dashboard activity")

        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-command-1",
            item: [
                "command": "ls",
                "id": "item-command-1",
                "type": "commandExecution",
            ]
        )
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-mcp-1",
            item: [
                "id": "item-mcp-1",
                "server": "calendar",
                "tool": "list_events",
                "type": "mcpToolCall",
            ]
        )
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-compact-1",
            item: [
                "id": "item-compact-1",
                "type": "contextCompaction",
            ]
        )

        let dashboard = await thread.makeDashboard()

        #expect(dashboard.threadID == thread.id)
        #expect(dashboard.name == nil)
        #expect(dashboard.preview == "Hello from the fake app-server")
        #expect(dashboard.status.type == .active)
        #expect(dashboard.isArchived == false)
        #expect(dashboard.isClosed == false)
        #expect(dashboard.latestTokenUsage == nil)

        await transport.emitHookStarted(
            threadID: thread.id,
            turnID: turnHandle.turn.id
        )

        try await waitForCondition {
            await client.threadObservableActivityState(threadID: thread.id).hookRuns.count == 1
        }

        await waitForObservableState {
            dashboard.toolCallingStatus == .inProgress
                && dashboard.mcpCallingStatus == .inProgress
                && dashboard.isCompactingThreadContext
                && dashboard.hookRuns.count == 1
        }

        #expect(dashboard.toolCallingStatus == .inProgress)
        #expect(dashboard.mcpCallingStatus == .inProgress)
        #expect(dashboard.isCompactingThreadContext == true)
        #expect(dashboard.hookRuns.count == 1)
        #expect(dashboard.hookRuns[0].status == .running)
        #expect(dashboard.hookRuns[0].turnID == turnHandle.turn.id)

        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-command-1",
            item: [
                "command": "ls",
                "id": "item-command-1",
                "status": "failed",
                "type": "commandExecution",
            ]
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-mcp-1",
            item: [
                "id": "item-mcp-1",
                "server": "calendar",
                "status": "completed",
                "tool": "list_events",
                "type": "mcpToolCall",
            ]
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-compact-1",
            item: [
                "id": "item-compact-1",
                "status": "completed",
                "type": "contextCompaction",
            ]
        )
        await transport.emitHookCompleted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            status: "completed"
        )
        await transport.emitModelRerouted(
            threadID: thread.id,
            turnID: turnHandle.turn.id
        )

        await waitForObservableState {
            dashboard.toolCallingStatus == .errored
                && dashboard.mcpCallingStatus == .idle
                && dashboard.isCompactingThreadContext == false
                && dashboard.hookRuns.first?.status == .completed
        }

        await transport.emitThreadStarted(threadID: thread.id)
        await transport.emitThreadStatusChanged(threadID: thread.id)
        await transport.emitThreadNameUpdated(threadID: thread.id)
        await transport.emitThreadArchived(threadID: thread.id)
        await transport.emitThreadTokenUsageUpdated(threadID: thread.id, turnID: "turn-123")
        await transport.emitThreadClosed(threadID: thread.id)

        await waitForObservableState {
            dashboard.name == "Planning Thread"
                && dashboard.isArchived
                && dashboard.isClosed
                && dashboard.latestTokenUsage?.turnID == "turn-123"
        }

        #expect(dashboard.name == "Planning Thread")
        #expect(dashboard.preview == "Hello from thread/started")
        #expect(dashboard.status.type == .active)
        #expect(dashboard.status.activeFlags == [.waitingOnApproval])
        #expect(dashboard.isArchived == true)
        #expect(dashboard.isClosed == true)
        #expect(dashboard.isCompactingThreadContext == false)
        #expect(dashboard.hookRuns.count == 1)
        #expect(dashboard.hookRuns[0].status == .completed)
        #expect(dashboard.hookRuns[0].entries.first?.kind == .feedback)
        #expect(dashboard.latestTokenUsage?.turnID == "turn-123")
        #expect(dashboard.latestTokenUsage?.total.totalTokens == 650)
        #expect(dashboard.toolCallingStatus == .errored)
        #expect(dashboard.mcpCallingStatus == .idle)

        await client.stop()
    }

    @MainActor
    @Test("builds a minimap that stays live with turn events")
    func buildsTurnMinimap() async throws {
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
                currentDirectoryPath: "/tmp/project",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )

        let turnHandle = try await thread.startTextTurn("Hello from SwiftASB")

        await transport.emitTurnStarted(
            threadID: thread.id,
            turnID: turnHandle.turn.id
        )
        await transport.emitTurnPlanUpdated(
            threadID: thread.id,
            turnID: turnHandle.turn.id
        )
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-command-1",
            item: [
                "command": "ls Sources",
                "id": "item-command-1",
                "type": "commandExecution",
            ]
        )
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-file-1",
            item: [
                "id": "item-file-1",
                "path": "/tmp/project/README.md",
                "type": "fileChange",
            ]
        )
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-mcp-1",
            item: [
                "id": "item-mcp-1",
                "server": "calendar",
                "tool": "list_events",
                "type": "mcpToolCall",
            ]
        )
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-compact-1",
            item: [
                "id": "item-compact-1",
                "type": "contextCompaction",
            ]
        )
        await transport.emitPlanDelta(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-plan-1"
        )
        await transport.emitAgentMessageDelta(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-agent-1"
        )
        await transport.emitReasoningTextDelta(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-reasoning-1"
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-command-1",
            item: [
                "command": "ls Sources",
                "id": "item-command-1",
                "status": "completed",
                "type": "commandExecution",
            ]
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-file-1",
            item: [
                "changes": [
                    [
                        "diff": "@@ -1 +1 @@",
                        "kind": ["type": "update"],
                        "path": "/tmp/project/README.md",
                    ],
                ],
                "id": "item-file-1",
                "status": "completed",
                "type": "fileChange",
            ]
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-mcp-1",
            item: [
                "id": "item-mcp-1",
                "server": "calendar",
                "status": "errored",
                "tool": "list_events",
                "type": "mcpToolCall",
            ]
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-compact-1",
            item: [
                "id": "item-compact-1",
                "status": "completed",
                "type": "contextCompaction",
            ]
        )
        await transport.emitTurnCompleted(
            threadID: thread.id,
            turnID: turnHandle.turn.id
        )

        let minimap = turnHandle.minimap

        #expect(minimap.threadID == thread.id)
        #expect(minimap.turnID == turnHandle.turn.id)
        #expect(minimap.currentTurn.id == turnHandle.turn.id)
        await waitForObservableState {
            minimap.latestPlanUpdate != nil
                && minimap.latestAgentMessageDelta != nil
                && minimap.latestReasoningTextDelta != nil
                && minimap.latestCompletion != nil
                && minimap.callSnapshots.count == 3
                && minimap.isCompactingThreadContext == false
                && minimap.currentTurn.status == .completed
        }

        #expect(minimap.latestStartedTurn?.turn.id == turnHandle.turn.id)
        #expect(minimap.latestPlanUpdate?.turnID == turnHandle.turn.id)
        #expect(minimap.latestPlanDelta?.itemID == "item-plan-1")
        #expect(minimap.latestAgentMessageDelta?.itemID == "item-agent-1")
        #expect(minimap.latestReasoningTextDelta?.itemID == "item-reasoning-1")
        #expect(minimap.latestCompletion?.turn.id == turnHandle.turn.id)
        #expect(minimap.isCompactingThreadContext == false)
        #expect(minimap.currentTurn.status == .completed)
        #expect(minimap.callSnapshots.count == 3)
        #expect(minimap.callSnapshots[0].kind == .command)
        #expect(minimap.callSnapshots[0].displayName == "ls Sources")
        #expect(minimap.callSnapshots[0].status == .completed)
        #expect(minimap.callSnapshots[1].kind == .fileEdit)
        #expect(minimap.callSnapshots[1].filePath == "/tmp/project/README.md")
        #expect(minimap.callSnapshots[1].status == .completed)
        #expect(minimap.callSnapshots[2].kind == .mcp)
        #expect(minimap.callSnapshots[2].displayName == "calendar.list_events")
        #expect(minimap.callSnapshots[2].status == .errored)

        await client.stop()
    }

}

@MainActor
private func waitForObservableState(
    maxAttempts: Int = 200,
    predicate: @MainActor () -> Bool
) async {
    for _ in 0..<maxAttempts {
        if predicate() {
            return
        }
        await Task.yield()
    }
}

private func waitForCondition(
    maxAttempts: Int = 200,
    predicate: @Sendable () async throws -> Bool
) async throws {
    for _ in 0..<maxAttempts {
        if try await predicate() {
            return
        }
        await Task.yield()
    }
}

private actor FakeCodexAppServerTransport: CodexAppServerTransporting {
    struct RecordedResponse: Sendable, Equatable {
        let requestID: CodexRPCRequestID
        let payload: Data
    }

    private(set) var recordedMethods: [String] = []
    private(set) var recordedResponses: [RecordedResponse] = []
    private var recordedRequestPayloads: [String: [Data]] = [:]
    private var threadListResult: [String: Any]?
    private var threadReadResult: [String: Any]?
    private var threadForkResult: [String: Any]?
    private var threadResumeResult: [String: Any]?
    private var threadStartIDQueue: [String]
    private var threadTurnsListErrorMessage: String?
    private var threadTurnsListResult: [String: Any]?
    private var threadTurnsListResultQueue: [[String: Any]]
    private let resolvedExecutable: CodexCLIExecutableResolver.Resolution?
    private var started = false
    private var initializedSeen = false
    private var serverEventContinuation: AsyncStream<CodexRPCServerEvent>.Continuation?

    init(
        executableResolution: CodexCLIExecutableResolver.Resolution? = nil,
        threadListResult: [String: Any]? = nil,
        threadReadResult: [String: Any]? = nil,
        threadForkResult: [String: Any]? = nil,
        threadResumeResult: [String: Any]? = nil,
        threadStartIDQueue: [String] = [],
        threadTurnsListErrorMessage: String? = nil,
        threadTurnsListResult: [String: Any]? = nil,
        threadTurnsListResultQueue: [[String: Any]] = []
    ) {
        self.resolvedExecutable = executableResolution
        self.threadListResult = threadListResult
        self.threadReadResult = threadReadResult
        self.threadForkResult = threadForkResult
        self.threadResumeResult = threadResumeResult
        self.threadStartIDQueue = threadStartIDQueue
        self.threadTurnsListErrorMessage = threadTurnsListErrorMessage
        self.threadTurnsListResult = threadTurnsListResult
        self.threadTurnsListResultQueue = threadTurnsListResultQueue
    }

    func setThreadListResult(_ result: [String: Any]?) {
        threadListResult = result
    }

    func start() throws {
        started = true
        initializedSeen = false
    }

    func stop() {
        started = false
        serverEventContinuation?.finish()
        serverEventContinuation = nil
    }

    func send(_ requestPayload: Data, id: CodexRPCRequestID) async throws -> Data {
        guard started else {
            throw CodexTransportError.notStarted
        }

        let method = try requestMethod(from: requestPayload)
        recordedMethods.append(method)
        recordedRequestPayloads[method, default: []].append(requestPayload)

        switch method {
        case "initialize":
            return responsePayload(
                id: id,
                result: [
                    "codexHome": "/Users/galew/.codex",
                    "platformFamily": "unix",
                    "platformOs": "macos",
                    "userAgent": "codex-cli/0.128.0",
                ]
            )
        case "model/list":
            return responsePayload(
                id: id,
                result: [
                    "data": [
                        [
                            "additionalSpeedTiers": ["fast", "flex"],
                            "availabilityNux": [
                                "message": "Available for this workspace.",
                            ],
                            "defaultReasoningEffort": "medium",
                            "description": "Balanced general-purpose model.",
                            "displayName": "GPT-5.4",
                            "hidden": false,
                            "id": "gpt-5.4",
                            "inputModalities": ["text", "image"],
                            "isDefault": true,
                            "model": "gpt-5.4",
                            "supportedReasoningEfforts": [
                                [
                                    "description": "Faster responses.",
                                    "reasoningEffort": "low",
                                ],
                                [
                                    "description": "Balanced responses.",
                                    "reasoningEffort": "medium",
                                ],
                                [
                                    "description": "Deeper reasoning.",
                                    "reasoningEffort": "high",
                                ],
                            ],
                            "supportsPersonality": true,
                            "upgrade": NSNull(),
                            "upgradeInfo": NSNull(),
                        ],
                    ],
                    "nextCursor": "cursor-models-next",
                ]
            )
        case "mcpServerStatus/list":
            return responsePayload(
                id: id,
                result: [
                    "data": [
                        [
                            "authStatus": "oAuth",
                            "name": "calendar",
                            "resources": [
                                [
                                    "_meta": ["source": "fixture"],
                                    "annotations": NSNull(),
                                    "description": "Today's events.",
                                    "icons": [],
                                    "mimeType": "application/json",
                                    "name": "today",
                                    "size": 128,
                                    "title": "Today",
                                    "uri": "calendar://events/today",
                                ],
                            ],
                            "resourceTemplates": [
                                [
                                    "annotations": NSNull(),
                                    "description": "Events by date.",
                                    "mimeType": "application/json",
                                    "name": "events-by-date",
                                    "title": "Events By Date",
                                    "uriTemplate": "calendar://events/{date}",
                                ],
                            ],
                            "tools": [
                                "list_events": [
                                    "_meta": ["source": "fixture"],
                                    "annotations": NSNull(),
                                    "description": "List calendar events.",
                                    "icons": [],
                                    "inputSchema": ["type": "object"],
                                    "name": "list_events",
                                    "outputSchema": ["type": "object"],
                                    "title": "List Events",
                                ],
                            ],
                        ],
                    ],
                    "nextCursor": NSNull(),
                ]
            )
        case "thread/name/set":
            return responsePayload(id: id, result: [:])
        case "thread/metadata/update":
            return responsePayload(
                id: id,
                result: [
                    "thread": [
                        "cliVersion": "0.128.0",
                        "createdAt": 1713350000,
                        "cwd": "/tmp/project",
                        "ephemeral": false,
                        "gitInfo": [
                            "branch": "main",
                            "originUrl": NSNull(),
                            "sha": "abc123",
                        ],
                        "id": "thread-123",
                        "modelProvider": "openai",
                        "name": "Hydrated Thread",
                        "preview": "Hydrated thread preview",
                        "source": "cli",
                        "status": ["type": "active"],
                        "turns": [],
                        "updatedAt": 1713350006,
                    ],
                ]
            )
        case "thread/rollback":
            return responsePayload(
                id: id,
                result: [
                    "thread": [
                        "cliVersion": "0.128.0",
                        "createdAt": 1713350000,
                        "cwd": "/tmp/project",
                        "ephemeral": false,
                        "id": "thread-123",
                        "modelProvider": "openai",
                        "name": "Hydrated Thread",
                        "preview": "Hydrated thread preview",
                        "source": "cli",
                        "status": ["type": "active"],
                        "turns": [
                            [
                                "completedAt": 1713350004,
                                "durationMs": 2000,
                                "error": NSNull(),
                                "id": "turn-older",
                                "items": [
                                    [
                                        "id": "item-older-user",
                                        "text": "Older prompt",
                                        "type": "userMessage",
                                    ],
                                ],
                                "startedAt": 1713350002,
                                "status": "completed",
                            ],
                        ],
                        "updatedAt": 1713350010,
                    ],
                ]
            )
        case "thread/start":
            if !initializedSeen {
                return errorPayload(
                    id: id,
                    code: -32000,
                    message: "initialized notification missing"
                )
            }

            let threadID = threadStartIDQueue.isEmpty ? "thread-123" : threadStartIDQueue.removeFirst()

            return responsePayload(
                id: id,
                result: [
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
                        "id": threadID,
                        "modelProvider": "openai",
                        "preview": "Hello from the fake app-server",
                        "source": "cli",
                        "status": ["type": "active"],
                        "turns": [],
                        "updatedAt": 1713350001,
                    ],
                ]
            )
        case "thread/list":
            return responsePayload(
                id: id,
                result: threadListResult ?? [
                    "data": [
                        [
                            "cliVersion": "0.128.0",
                            "createdAt": 1713350000,
                            "cwd": "/tmp/project",
                            "ephemeral": false,
                            "id": "thread-123",
                            "modelProvider": "openai",
                            "name": "Hydrated Thread",
                            "preview": "Hydrated thread preview",
                            "source": "cli",
                            "status": ["type": "notLoaded"],
                            "turns": [],
                            "updatedAt": 1713350005,
                        ],
                    ],
                    "nextCursor": "cursor-next",
                ]
            )
        case "thread/read":
            return responsePayload(
                id: id,
                result: threadReadResult ?? [
                    "thread": [
                        "cliVersion": "0.128.0",
                        "createdAt": 1713350000,
                        "cwd": "/tmp/project",
                        "ephemeral": false,
                        "id": "thread-123",
                        "modelProvider": "openai",
                        "name": "Hydrated Thread",
                        "preview": "Hydrated thread preview",
                        "source": "cli",
                        "status": ["type": "notLoaded"],
                        "turns": [
                            [
                                "completedAt": 1713350005,
                                "durationMs": 3000,
                                "error": NSNull(),
                                "id": "turn-hydrated-1",
                                "items": [
                                    [
                                        "id": "item-user-1",
                                        "text": "Hydrated user prompt.",
                                        "type": "userMessage",
                                    ],
                                    [
                                        "id": "item-agent-1",
                                        "status": "completed",
                                        "text": "Hydrated reply from thread/read.",
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
        case "thread/compact/start":
            return responsePayload(
                id: id,
                result: [:]
            )
        case "thread/fork":
            return responsePayload(
                id: id,
                result: threadForkResult ?? [
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
                        "ephemeral": false,
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
                                "id": "turn-hydrated-1",
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
        case "thread/resume":
            return responsePayload(
                id: id,
                result: threadResumeResult ?? [
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
        case "thread/turns/list":
            if let threadTurnsListErrorMessage {
                return errorPayload(
                    id: id,
                    code: -32600,
                    message: threadTurnsListErrorMessage
                )
            }
            if !threadTurnsListResultQueue.isEmpty {
                return responsePayload(
                    id: id,
                    result: threadTurnsListResultQueue.removeFirst()
                )
            }
            return responsePayload(
                id: id,
                result: threadTurnsListResult ?? [
                    "backwardsCursor": "cursor-newer",
                    "data": [
                        [
                            "completedAt": 1713350100,
                            "durationMs": 2500,
                            "error": NSNull(),
                            "id": "turn-newer",
                            "items": [],
                            "startedAt": 1713350050,
                            "status": "completed",
                        ],
                        [
                            "completedAt": 1713350005,
                            "durationMs": 3000,
                            "error": NSNull(),
                            "id": "turn-older",
                            "items": [],
                            "startedAt": 1713350002,
                            "status": "completed",
                        ],
                    ],
                    "nextCursor": "cursor-older",
                ]
            )
        case "turn/start":
            return responsePayload(
                id: id,
                result: [
                    "turn": [
                        "completedAt": NSNull(),
                        "durationMs": NSNull(),
                        "error": NSNull(),
                        "id": "turn-123",
                        "items": [],
                        "startedAt": 1713350002,
                        "status": "inProgress",
                    ],
                ]
            )
        case "turn/steer":
            return responsePayload(
                id: id,
                result: [
                    "turnId": "turn-123",
                ]
            )
        case "turn/interrupt":
            return responsePayload(
                id: id,
                result: [:]
            )
        default:
            return errorPayload(
                id: id,
                code: -32601,
                message: "unsupported method in fake transport"
            )
        }
    }

    func sendNotification(_ notificationPayload: Data, method: String) throws {
        guard started else {
            throw CodexTransportError.notStarted
        }

        recordedMethods.append(method)

        if method == "initialized" {
            initializedSeen = true
        }
    }

    func sendResponse(_ responsePayload: Data, requestID: CodexRPCRequestID) throws {
        guard started else {
            throw CodexTransportError.notStarted
        }

        recordedResponses.append(.init(requestID: requestID, payload: responsePayload))
    }

    func serverEvents() -> AsyncStream<CodexRPCServerEvent> {
        AsyncStream { continuation in
            serverEventContinuation = continuation
            continuation.onTermination = { _ in
                Task {
                    await self.clearServerEventContinuation()
                }
            }
        }
    }

    func executableResolution() -> CodexCLIExecutableResolver.Resolution? {
        resolvedExecutable
    }

    func recordedRequestPayload(for method: String) -> Data? {
        recordedRequestPayloads[method]?.last
    }

    func emitTurnCompleted(threadID: String, turnID: String) {
        let payload = payloadObject([
            "threadId": threadID,
            "turn": [
                "completedAt": 1713350005,
                "durationMs": 3000,
                "error": NSNull(),
                "id": turnID,
                "items": [],
                "startedAt": 1713350002,
                "status": "completed",
            ],
        ])

        serverEventContinuation?.yield(
            .notification(method: "turn/completed", payload: payload)
        )
    }

    func emitCommandExecutionApprovalRequest(
        requestID: CodexRPCRequestID,
        threadID: String,
        turnID: String,
        itemID: String
    ) {
        let payload = payloadObject([
            "command": "git status",
            "commandActions": [
                [
                    "command": "git status",
                    "type": "unknown",
                ]
            ],
            "cwd": "/tmp/project",
            "itemId": itemID,
            "reason": "Needs approval to read repository state.",
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .request(
                id: requestID,
                method: "item/commandExecution/requestApproval",
                payload: payload
            )
        )
    }

    func emitToolUserInputRequest(
        requestID: CodexRPCRequestID,
        threadID: String,
        turnID: String,
        itemID: String
    ) {
        let payload = payloadObject([
            "itemId": itemID,
            "questions": [
                [
                    "header": "Goal",
                    "id": "goal",
                    "options": [
                        [
                            "description": "Use the existing plan as-is.",
                            "label": "Ship it",
                        ],
                        [
                            "description": "Pause the implementation and revisit scope.",
                            "label": "Replan",
                        ],
                    ],
                    "question": "Which direction should we take?",
                ]
            ],
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .request(
                id: requestID,
                method: "item/tool/requestUserInput",
                payload: payload
            )
        )
    }

    func emitMcpServerElicitationRequest(
        requestID: CodexRPCRequestID,
        threadID: String,
        turnID: String?
    ) {
        var payload: [String: Any] = [
            "message": "Do you want to connect the calendar server?",
            "mode": "url",
            "serverName": "calendar",
            "threadId": threadID,
            "url": "https://example.com/authorize",
            "elicitationId": "elicitation-1",
        ]
        payload["turnId"] = turnID ?? NSNull()

        serverEventContinuation?.yield(
            .request(
                id: requestID,
                method: "mcpServer/elicitation/request",
                payload: payloadObject(payload)
            )
        )
    }

    func emitServerRequestResolved(
        threadID: String,
        requestID: CodexRPCRequestID
    ) {
        let jsonRequestID: Any
        switch requestID {
        case let .string(value):
            jsonRequestID = value
        case let .int(value):
            jsonRequestID = value
        }

        let payload = payloadObject([
            "requestId": jsonRequestID,
            "threadId": threadID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "serverRequest/resolved", payload: payload)
        )
    }

    func emitThreadStarted(threadID: String) {
        let payload = payloadObject([
            "thread": [
                "cliVersion": "0.128.0",
                "createdAt": 1713350000,
                "cwd": "/tmp/project",
                "ephemeral": false,
                "id": threadID,
                "modelProvider": "openai",
                "preview": "Hello from thread/started",
                "source": "cli",
                "status": ["type": "active"],
                "turns": [],
                "updatedAt": 1713350001,
            ],
        ])

        serverEventContinuation?.yield(
            .notification(method: "thread/started", payload: payload)
        )
    }

    func emitThreadStatusChanged(threadID: String) {
        let payload = payloadObject([
            "threadId": threadID,
            "status": [
                "type": "active",
                "activeFlags": ["waitingOnApproval"],
            ],
        ])

        serverEventContinuation?.yield(
            .notification(method: "thread/status/changed", payload: payload)
        )
    }

    func emitThreadNameUpdated(threadID: String, threadName: String? = "Planning Thread") {
        let payload = payloadObject([
            "threadId": threadID,
            "threadName": threadName ?? NSNull(),
        ])

        serverEventContinuation?.yield(
            .notification(method: "thread/name/updated", payload: payload)
        )
    }

    func emitThreadArchived(threadID: String) {
        let payload = payloadObject([
            "threadId": threadID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "thread/archived", payload: payload)
        )
    }

    func emitThreadUnarchived(threadID: String) {
        let payload = payloadObject([
            "threadId": threadID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "thread/unarchived", payload: payload)
        )
    }

    func emitThreadTokenUsageUpdated(threadID: String, turnID: String) {
        let payload = payloadObject([
            "threadId": threadID,
            "turnId": turnID,
            "tokenUsage": [
                "last": [
                    "cachedInputTokens": 10,
                    "inputTokens": 20,
                    "outputTokens": 30,
                    "reasoningOutputTokens": 5,
                    "totalTokens": 65,
                ],
                "modelContextWindow": 200000,
                "total": [
                    "cachedInputTokens": 100,
                    "inputTokens": 200,
                    "outputTokens": 300,
                    "reasoningOutputTokens": 50,
                    "totalTokens": 650,
                ],
            ],
        ])

        serverEventContinuation?.yield(
            .notification(method: "thread/tokenUsage/updated", payload: payload)
        )
    }

    func emitThreadClosed(threadID: String) {
        let payload = payloadObject([
            "threadId": threadID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "thread/closed", payload: payload)
        )
    }

    func emitHookStarted(
        threadID: String,
        turnID: String?,
        hookID: String = "hook-1",
        status: String = "running"
    ) {
        let payload = payloadObject([
            "run": [
                "displayOrder": 1,
                "entries": [],
                "eventName": "preToolUse",
                "executionMode": "sync",
                "handlerType": "command",
                "id": hookID,
                "scope": "turn",
                "sourcePath": "/tmp/project/.codex/hooks/pre-tool-use.sh",
                "startedAt": 1713350003,
                "status": status,
                "statusMessage": NSNull(),
            ],
            "threadId": threadID,
            "turnId": turnID ?? NSNull(),
        ])

        serverEventContinuation?.yield(
            .notification(method: "hook/started", payload: payload)
        )
    }

    func emitHookCompleted(
        threadID: String,
        turnID: String?,
        hookID: String = "hook-1",
        status: String = "completed",
        statusMessage: String? = nil
    ) {
        let jsonStatusMessage: Any = statusMessage ?? NSNull()
        let payload = payloadObject([
            "run": [
                "completedAt": 1713350004,
                "displayOrder": 1,
                "durationMs": 150,
                "entries": [
                    [
                        "kind": "feedback",
                        "text": "Hook finished.",
                    ]
                ],
                "eventName": "preToolUse",
                "executionMode": "sync",
                "handlerType": "command",
                "id": hookID,
                "scope": "turn",
                "sourcePath": "/tmp/project/.codex/hooks/pre-tool-use.sh",
                "startedAt": 1713350003,
                "status": status,
                "statusMessage": jsonStatusMessage,
            ],
            "threadId": threadID,
            "turnId": turnID ?? NSNull(),
        ])

        serverEventContinuation?.yield(
            .notification(method: "hook/completed", payload: payload)
        )
    }

    func emitWarning(
        threadID: String?,
        message: String = "Runtime configuration is using a fallback."
    ) {
        let payload = payloadObject([
            "message": message,
            "threadId": threadID ?? NSNull(),
        ])

        serverEventContinuation?.yield(
            .notification(method: "warning", payload: payload)
        )
    }

    func emitGuardianWarning(
        threadID: String,
        message: String = "Guardian flagged this session for review."
    ) {
        let payload = payloadObject([
            "message": message,
            "threadId": threadID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "guardianWarning", payload: payload)
        )
    }

    func emitModelRerouted(
        threadID: String,
        turnID: String,
        fromModel: String = "gpt-5.4",
        toModel: String = "gpt-5.4-safe"
    ) {
        let payload = payloadObject([
            "fromModel": fromModel,
            "reason": "highRiskCyberActivity",
            "threadId": threadID,
            "toModel": toModel,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "model/rerouted", payload: payload)
        )
    }

    func emitModelVerification(
        threadID: String,
        turnID: String
    ) {
        let payload = payloadObject([
            "threadId": threadID,
            "turnId": turnID,
            "verifications": ["trustedAccessForCyber"],
        ])

        serverEventContinuation?.yield(
            .notification(method: "model/verification", payload: payload)
        )
    }

    func emitMalformedModelRerouted() {
        let payload = payloadObject([
            "fromModel": "gpt-5.4",
            "reason": "unexpectedFutureReason",
            "threadId": "thread-123",
            "toModel": "gpt-5.4-safe",
            "turnId": "turn-123",
        ])

        serverEventContinuation?.yield(
            .notification(method: "model/rerouted", payload: payload)
        )
    }

    func emitTurnStarted(threadID: String, turnID: String) {
        let payload = payloadObject([
            "threadId": threadID,
            "turn": [
                "completedAt": NSNull(),
                "durationMs": NSNull(),
                "error": NSNull(),
                "id": turnID,
                "items": [],
                "startedAt": 1713350002,
                "status": "inProgress",
            ],
        ])

        serverEventContinuation?.yield(
            .notification(method: "turn/started", payload: payload)
        )
    }

    func emitTurnPlanUpdated(threadID: String, turnID: String) {
        let payload = payloadObject([
            "explanation": "Map richer progress notifications.",
            "plan": [
                [
                    "status": "inProgress",
                    "step": "Promote protocol events into CodexTurnEvent",
                ],
                [
                    "status": "pending",
                    "step": "Add consumer-facing stream tests",
                ],
            ],
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "turn/plan/updated", payload: payload)
        )
    }

    func emitItemStarted(
        threadID: String,
        turnID: String,
        itemID: String,
        item: [String: Any]? = nil
    ) {
        let payload = payloadObject([
            "item": item ?? [
                "id": itemID,
                "type": "plan",
            ],
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "item/started", payload: payload)
        )
    }

    func emitAgentMessageDelta(threadID: String, turnID: String, itemID: String) {
        let payload = payloadObject([
            "delta": "Working on it",
            "itemId": itemID,
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "item/agentMessage/delta", payload: payload)
        )
    }

    func emitFileChangeOutputDelta(
        threadID: String,
        turnID: String,
        itemID: String,
        delta: String
    ) {
        let payload = payloadObject([
            "delta": delta,
            "itemId": itemID,
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "item/fileChange/outputDelta", payload: payload)
        )
    }

    func emitCommandExecutionOutputDelta(
        threadID: String,
        turnID: String,
        itemID: String,
        delta: String
    ) {
        let payload = payloadObject([
            "delta": delta,
            "itemId": itemID,
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "item/commandExecution/outputDelta", payload: payload)
        )
    }

    func emitPlanDelta(threadID: String, turnID: String, itemID: String) {
        let payload = payloadObject([
            "delta": "Stream partial plan text",
            "itemId": itemID,
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "item/plan/delta", payload: payload)
        )
    }

    func emitReasoningTextDelta(threadID: String, turnID: String, itemID: String) {
        let payload = payloadObject([
            "contentIndex": 0,
            "delta": "thinking...",
            "itemId": itemID,
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "item/reasoning/textDelta", payload: payload)
        )
    }

    func emitReasoningSummaryTextDelta(threadID: String, turnID: String, itemID: String) {
        let payload = payloadObject([
            "delta": "Summarizing the approach.",
            "itemId": itemID,
            "summaryIndex": 0,
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "item/reasoning/summaryTextDelta", payload: payload)
        )
    }

    func emitItemCompleted(
        threadID: String,
        turnID: String,
        itemID: String,
        item: [String: Any]? = nil
    ) {
        let payload = payloadObject([
            "item": item ?? [
                "id": itemID,
                "status": "completed",
                "text": "Done.",
                "type": "agentMessage",
            ],
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "item/completed", payload: payload)
        )
    }

    private func requestMethod(from payload: Data) throws -> String {
        let object = try #require(
            try JSONSerialization.jsonObject(with: payload) as? [String: Any]
        )
        return try #require(object["method"] as? String)
    }

    private func responsePayload(id: CodexRPCRequestID, result: [String: Any]) -> Data {
        payloadObject([
            "id": id.jsonObjectValue,
            "result": result,
        ])
    }

    private func errorPayload(id: CodexRPCRequestID, code: Int, message: String) -> Data {
        payloadObject([
            "id": id.jsonObjectValue,
            "error": [
                "code": code,
                "message": message,
            ],
        ])
    }

    private func payloadObject(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }

    private func clearServerEventContinuation() {
        serverEventContinuation = nil
    }
}

private func turnEvents(
    from stream: AsyncThrowingStream<CodexTurnEvent, Error>,
    count: Int
) async throws -> [CodexTurnEvent] {
    var iterator = stream.makeAsyncIterator()
    var events: [CodexTurnEvent] = []

    while events.count < count, let event = try await iterator.next() {
        events.append(event)
    }

    return events
}

private func diagnosticEvents(
    from stream: AsyncThrowingStream<CodexDiagnosticEvent, Error>,
    count: Int
) async throws -> [CodexDiagnosticEvent] {
    var iterator = stream.makeAsyncIterator()
    var events: [CodexDiagnosticEvent] = []

    while events.count < count, let event = try await iterator.next() {
        events.append(event)
    }

    return events
}

private func nextDiagnosticEventOrEnd(
    from stream: AsyncThrowingStream<CodexDiagnosticEvent, Error>,
    timeoutNanoseconds: UInt64 = 1_000_000_000
) async throws -> CodexDiagnosticEvent? {
    let iteratorTask = Task {
        var iterator = stream.makeAsyncIterator()
        return try await iterator.next()
    }

    let timeoutTask = Task {
        try await Task.sleep(nanoseconds: timeoutNanoseconds)
    }

    defer {
        iteratorTask.cancel()
        timeoutTask.cancel()
    }

    return try await withThrowingTaskGroup(of: CodexDiagnosticEvent?.self) { group in
        defer { group.cancelAll() }

        group.addTask {
            try await iteratorTask.value
        }
        group.addTask {
            try await timeoutTask.value
            throw TimeoutError()
        }

        let result = try await group.next()
        return try #require(result)
    }
}

private func nextTurnEventOrEnd(
    from stream: AsyncThrowingStream<CodexTurnEvent, Error>,
    timeoutNanoseconds: UInt64 = 1_000_000_000
) async throws -> CodexTurnEvent? {
    let iteratorTask = Task {
        var iterator = stream.makeAsyncIterator()
        return try await iterator.next()
    }

    let timeoutTask = Task {
        try await Task.sleep(nanoseconds: timeoutNanoseconds)
    }

    defer {
        iteratorTask.cancel()
        timeoutTask.cancel()
    }

    return try await withThrowingTaskGroup(of: CodexTurnEvent?.self) { group in
        group.addTask {
            try await iteratorTask.value
        }
        group.addTask {
            try await timeoutTask.value
            throw TimeoutError()
        }

        let result = try await group.next()
        group.cancelAll()
        return try #require(result)
    }
}

private func threadEvents(
    from stream: AsyncThrowingStream<CodexThreadEvent, Error>,
    count: Int
) async throws -> [CodexThreadEvent] {
    var iterator = stream.makeAsyncIterator()
    var events: [CodexThreadEvent] = []

    while events.count < count, let event = try await iterator.next() {
        events.append(event)
    }

    return events
}

private func temporarySQLiteHistoryStore() throws -> (ThreadHistoryStore, URL) {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
        at: temporaryDirectory,
        withIntermediateDirectories: true
    )
    let historyStore = try ThreadHistoryStore(
        configuration: .init(
            inMemory: false,
            storeURL: temporaryDirectory.appendingPathComponent("ThreadHistory.sqlite")
        )
    )
    return (historyStore, temporaryDirectory)
}

private func tearDownTemporarySQLiteHistoryStore(
    _ historyStore: ThreadHistoryStore,
    directory: URL
) async {
    try? await historyStore.detachPersistentStoresForTeardown()
    try? FileManager.default.removeItem(at: directory)
}

private func settleObservableTeardown() async {
    await Task.yield()
    await Task.yield()
}

private extension CodexRPCRequestID {
    var jsonObjectValue: Any {
        switch self {
        case let .string(value):
            value
        case let .int(value):
            value
        }
    }
}

private struct TimeoutError: Error {}
