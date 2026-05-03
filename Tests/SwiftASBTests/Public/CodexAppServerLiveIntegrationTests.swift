import Foundation
import CryptoKit
import Testing
@testable import SwiftASB

@Suite("CodexAppServer live integration", .serialized)
struct CodexAppServerLiveIntegrationTests {
    @Test(
        "initializes through the raw live transport and protocol stack",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TRANSPORT_TESTS"] == "1",
            "Requires explicit opt-in because this test launches the local Codex CLI."
        ),
        .timeLimit(.minutes(2))
    )
    func initializesThroughRawLiveTransport() async throws {
        let harness = try LiveCodexHarness()
        defer { harness.cleanup() }

        let transport = CodexAppServerTransport(
            configuration: .init(
                codexExecutableURL: harness.codexExecutableURL,
                currentDirectoryURL: harness.rootDirectoryURL
            )
        )
        let protocolLayer = CodexAppServerProtocol()
        let requestID = CodexRPCRequestID.string("live-initialize")

        do {
            try await transport.start()

            let requestPayload = try protocolLayer.makeInitializeRequest(
                id: requestID,
                params: CodexWireInitializeParams(
                    capabilities: nil,
                    clientInfo: .init(
                        name: "SwiftASBLiveTransportTests",
                        title: nil,
                        version: "0.1.0"
                    )
                )
            )

            let responsePayload = try await withTimeout(
                seconds: 15,
                operation: "waiting for the raw transport initialize response"
            ) {
                try await transport.send(requestPayload, id: requestID)
            }

            let response = try protocolLayer.decodeInitializeResponse(
                responsePayload,
                expectedID: requestID
            )
            #expect(response.codexHome.isEmpty == false)
            #expect(response.platformFamily == "unix")
            #expect(response.platformOS == "macos")

            await transport.stop()
        } catch {
            await transport.stop()
            throw error
        }
    }

    @Test(
        "starts a thread through the raw live transport and protocol stack",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TRANSPORT_TESTS"] == "1",
            "Requires explicit opt-in because this test launches the local Codex CLI."
        ),
        .timeLimit(.minutes(2))
    )
    func startsThreadThroughRawLiveTransport() async throws {
        let harness = try LiveCodexHarness(configMode: .approvalProbe)
        defer { harness.cleanup() }

        let transport = CodexAppServerTransport(
            configuration: .init(
                codexExecutableURL: harness.codexExecutableURL,
                currentDirectoryURL: harness.rootDirectoryURL,
                environment: harness.configuration.environment
            )
        )
        let protocolLayer = CodexAppServerProtocol()
        let initializeRequestID = CodexRPCRequestID.string("live-initialize")
        let threadRequestID = CodexRPCRequestID.string("live-thread-start")

        do {
            try await transport.start()

            let initializePayload = try protocolLayer.makeInitializeRequest(
                id: initializeRequestID,
                params: CodexWireInitializeParams(
                    capabilities: CodexWireInitializeCapabilities(
                        experimentalAPI: nil,
                        optOutNotificationMethods: [
                            "account/rateLimits/updated",
                            "hook/completed",
                            "hook/started",
                            "mcpServer/startupStatus/updated",
                        ]
                    ),
                    clientInfo: .init(
                        name: "SwiftASBLiveTests",
                        title: "SwiftASB Live Integration Tests",
                        version: "0.1.0"
                    )
                )
            )
            let initializeResponsePayload = try await withTimeout(
                seconds: 15,
                operation: "waiting for the raw transport initialize response before thread/start"
            ) {
                try await transport.send(initializePayload, id: initializeRequestID)
            }
            _ = try protocolLayer.decodeInitializeResponse(
                initializeResponsePayload,
                expectedID: initializeRequestID
            )

            let initializedPayload = try protocolLayer.makeInitializedNotification()
            try await transport.sendNotification(initializedPayload, method: "initialized")

            let threadStartPayload = try protocolLayer.makeThreadStartRequest(
                id: threadRequestID,
                params: CodexWireThreadStartParams(
                    approvalPolicy: .enumeration(.never),
                    approvalsReviewer: nil,
                    baseInstructions: nil,
                    config: nil,
                    cwd: harness.threadAWorkspace.path,
                    developerInstructions: """
                    You are running inside a SwiftASB live integration test.
                    Do not call tools.
                    Do not edit files.
                    Do not ask follow-up questions.
                    Reply only with the exact text requested by the user message.
                    """,
                    dynamicTools: nil,
                    environments: nil,
                    ephemeral: true,
                    experimentalRawEvents: nil,
                    mockExperimentalField: nil,
                    model: nil,
                    modelProvider: nil,
                    permissions: nil,
                    persistExtendedHistory: nil,
                    personality: nil,
                    sandbox: .workspaceWrite,
                    serviceName: nil,
                    serviceTier: nil,
                    sessionStartSource: nil
                )
            )
            let threadResponsePayload = try await withTimeout(
                seconds: 15,
                operation: "waiting for the raw transport thread/start response"
            ) {
                try await transport.send(threadStartPayload, id: threadRequestID)
            }
            let threadResponse = try protocolLayer.decodeThreadStartResponse(
                threadResponsePayload,
                expectedID: threadRequestID
            )

            #expect(threadResponse.thread.id.isEmpty == false)
            #expect(threadResponse.cwd == harness.threadAWorkspace.path)
            #expect(threadResponse.thread.status.type == .idle)

            await transport.stop()
        } catch {
            await transport.stop()
            throw error
        }
    }

    @Test(
        "surfaces live Codex CLI executable diagnostics after start",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TRANSPORT_TESTS"] == "1",
            "Requires explicit opt-in because this test launches the local Codex CLI."
        ),
        .timeLimit(.minutes(2))
    )
    func surfacesLiveCodexCLIDiagnosticsAfterStart() async throws {
        let harness = try LiveCodexHarness()
        defer { harness.cleanup() }

        let client = CodexAppServer(configuration: harness.configuration)
        do {
            try await client.start()

            let diagnostics = try await client.cliExecutableDiagnostics()
            #expect(diagnostics.resolvedExecutablePath == harness.codexExecutableURL.path)
            #expect(diagnostics.versionString.contains("codex-cli"))
            #expect(diagnostics.compatibility == .supported(documentedWindow: "0.128.x"))

            await client.stop()
        } catch {
            await client.stop()
            throw error
        }
    }

    @Test(
        "completes a single live turn through the raw live transport and protocol stack",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TRANSPORT_TESTS"] == "1",
            "Requires explicit opt-in because this test launches the local Codex CLI."
        ),
        .timeLimit(.minutes(2))
    )
    func completesSingleLiveTurnThroughRawLiveTransport() async throws {
        let harness = try LiveCodexHarness()
        defer { harness.cleanup() }

        let transport = CodexAppServerTransport(
            configuration: .init(
                codexExecutableURL: harness.codexExecutableURL,
                currentDirectoryURL: harness.rootDirectoryURL,
                environment: harness.configuration.environment
            )
        )
        let protocolLayer = CodexAppServerProtocol()
        let initializeRequestID = CodexRPCRequestID.string("live-initialize")
        let threadRequestID = CodexRPCRequestID.string("live-thread-start")
        let turnRequestID = CodexRPCRequestID.string("live-turn-start")

        do {
            try await transport.start()

            let initializePayload = try protocolLayer.makeInitializeRequest(
                id: initializeRequestID,
                params: CodexWireInitializeParams(
                    capabilities: CodexWireInitializeCapabilities(
                        experimentalAPI: nil,
                        optOutNotificationMethods: [
                            "account/rateLimits/updated",
                            "hook/completed",
                            "hook/started",
                            "mcpServer/startupStatus/updated",
                        ]
                    ),
                    clientInfo: .init(
                        name: "SwiftASBLiveTests",
                        title: "SwiftASB Live Integration Tests",
                        version: "0.1.0"
                    )
                )
            )
            let initializeResponsePayload = try await withTimeout(
                seconds: 15,
                operation: "waiting for the raw transport initialize response before a live turn"
            ) {
                try await transport.send(initializePayload, id: initializeRequestID)
            }
            _ = try protocolLayer.decodeInitializeResponse(
                initializeResponsePayload,
                expectedID: initializeRequestID
            )

            let initializedPayload = try protocolLayer.makeInitializedNotification()
            try await transport.sendNotification(initializedPayload, method: "initialized")

            let threadStartPayload = try protocolLayer.makeThreadStartRequest(
                id: threadRequestID,
                params: CodexWireThreadStartParams(
                    approvalPolicy: .enumeration(.never),
                    approvalsReviewer: nil,
                    baseInstructions: nil,
                    config: nil,
                    cwd: harness.threadAWorkspace.path,
                    developerInstructions: """
                    You are running inside a SwiftASB live integration test.
                    Do not call tools.
                    Do not edit files.
                    Do not ask follow-up questions.
                    Reply only with the exact text requested by the user message.
                    """,
                    dynamicTools: nil,
                    environments: nil,
                    ephemeral: true,
                    experimentalRawEvents: nil,
                    mockExperimentalField: nil,
                    model: nil,
                    modelProvider: nil,
                    permissions: nil,
                    persistExtendedHistory: nil,
                    personality: nil,
                    sandbox: .workspaceWrite,
                    serviceName: nil,
                    serviceTier: nil,
                    sessionStartSource: nil
                )
            )
            let threadResponsePayload = try await withTimeout(
                seconds: 15,
                operation: "waiting for the raw transport thread/start response before a live turn"
            ) {
                try await transport.send(threadStartPayload, id: threadRequestID)
            }
            let threadResponse = try protocolLayer.decodeThreadStartResponse(
                threadResponsePayload,
                expectedID: threadRequestID
            )

            let serverEvents = await transport.serverEvents()
            let turnStartPayload = try protocolLayer.makeTurnStartRequest(
                id: turnRequestID,
                params: CodexWireTurnStartParams(
                    approvalPolicy: .enumeration(.never),
                    approvalsReviewer: nil,
                    collaborationMode: nil,
                    cwd: nil,
                    effort: nil,
                    environments: nil,
                    input: [
                        CodexWireUserInput(
                            text: prompt(label: "RAW_SINGLE_TURN_DONE"),
                            textElements: nil,
                            type: .text,
                            url: nil,
                            path: nil,
                            name: nil
                        )
                    ],
                    model: nil,
                    outputSchema: nil,
                    permissions: nil,
                    personality: nil,
                    responsesapiClientMetadata: nil,
                    sandboxPolicy: nil,
                    serviceTier: nil,
                    summary: CodexWireReasoningSummary.none,
                    threadID: threadResponse.thread.id
                )
            )
            let turnResponsePayload = try await withTimeout(
                seconds: 20,
                operation: "waiting for the raw transport turn/start response"
            ) {
                try await transport.send(turnStartPayload, id: turnRequestID)
            }
            let turnResponse = try protocolLayer.decodeTurnStartResponse(
                turnResponsePayload,
                expectedID: turnRequestID
            )

            let completion = try await withTimeout(
                seconds: 45,
                operation: "waiting for the raw transport live turn to complete"
            ) {
                for await serverEvent in serverEvents {
                    guard let decodedEvent = try protocolLayer.decodeServerEvent(serverEvent) else {
                        continue
                    }

                    switch decodedEvent {
                    case let .turnCompleted(notification) where notification.turn.id == turnResponse.turn.id:
                        return notification
                    default:
                        continue
                    }
                }

                throw LiveIntegrationError.eventStreamEnded(
                    operation: "waiting for the raw transport live turn to complete"
                )
            }

            #expect(completion.threadID == threadResponse.thread.id)
            #expect(completion.turn.id == turnResponse.turn.id)
            #expect(completion.turn.status == CodexWireTurnStatus.completed)

            await transport.stop()
        } catch {
            await transport.stop()
            throw error
        }
    }

    @Test(
        "completes a single live turn through the public client",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_SINGLE_TURN_TESTS"] == "1",
            "Requires explicit opt-in because this test launches the local Codex CLI."
        ),
        .timeLimit(.minutes(2))
    )
    func completesSingleLiveTurn() async throws {
        let harness = try LiveCodexHarness()
        defer { harness.cleanup() }

        let client = try await makeInitializedLiveClient(using: harness)
        do {
            let thread = try await startThread(
                on: client,
                workspacePath: harness.threadAWorkspace.path,
                label: "single-turn"
            )

            let turn = try await startTurn(
                on: thread,
                prompt: prompt(label: "SINGLE_TURN_DONE")
            )

            let completion = try await awaitCompletion(
                of: turn,
                timeoutSeconds: 45,
                operation: "waiting for the single live turn to complete"
            )
            #expect(completion.turn.status == .completed)

            await client.stop()
        } catch {
            await client.stop()
            throw error
        }
    }

    @Test(
        "completes two live turns across different threads",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_CROSS_THREAD_TESTS"] == "1",
            "Requires explicit opt-in because this test launches the local Codex CLI."
        ),
        .timeLimit(.minutes(2))
    )
    func completesTwoLiveTurnsAcrossDifferentThreads() async throws {
        let harness = try LiveCodexHarness()
        defer { harness.cleanup() }

        let client = try await makeInitializedLiveClient(using: harness, experimentalAPI: true)
        do {
            let threadA = try await startThread(
                on: client,
                workspacePath: harness.threadAWorkspace.path,
                label: "cross-thread-a"
            )
            let threadB = try await startThread(
                on: client,
                workspacePath: harness.threadBWorkspace.path,
                label: "cross-thread-b"
            )

            let crossThreadTurnA = try await startTurn(
                on: threadA,
                prompt: prompt(label: "CROSS_THREAD_A_DONE")
            )
            let crossThreadTurnB = try await startTurn(
                on: threadB,
                prompt: prompt(label: "CROSS_THREAD_B_DONE")
            )

            async let crossThreadCompletionA = awaitCompletion(
                of: crossThreadTurnA,
                timeoutSeconds: 45,
                operation: "waiting for the first cross-thread turn to complete"
            )
            async let crossThreadCompletionB = awaitCompletion(
                of: crossThreadTurnB,
                timeoutSeconds: 45,
                operation: "waiting for the second cross-thread turn to complete"
            )

            let completedCrossThreadTurnA = try await crossThreadCompletionA
            let completedCrossThreadTurnB = try await crossThreadCompletionB
            let crossThreadStatuses = [
                completedCrossThreadTurnA.turn.status,
                completedCrossThreadTurnB.turn.status,
            ]
            #expect(crossThreadStatuses == [.completed, .completed])

            await client.stop()
        } catch {
            await client.stop()
            throw error
        }
    }

    @Test(
        "lists live app-wide capability snapshots through the public client",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_CAPABILITY_TESTS"] == "1",
            "Requires explicit opt-in because this test launches the local Codex CLI."
        ),
        .timeLimit(.minutes(2))
    )
    func listsLiveAppWideCapabilitySnapshots() async throws {
        let harness = try LiveCodexHarness()
        defer { harness.cleanup() }

        let client = try await makeInitializedLiveClient(using: harness)
        do {
            let models = try await withTimeout(
                seconds: 15,
                operation: "listing live Codex model capabilities"
            ) {
                try await client.listModels(
                    .init(
                        limit: 20,
                        includeHidden: true
                    )
                )
            }
            #expect(models.models.isEmpty == false)
            #expect(models.models.allSatisfy { model in
                model.id.isEmpty == false
                    && model.model.isEmpty == false
                    && model.displayName.isEmpty == false
            })

            let mcpServers = try await withTimeout(
                seconds: 15,
                operation: "listing live Codex MCP server capabilities"
            ) {
                try await client.listMcpServerStatuses(
                    .init(
                        limit: 20,
                        detail: .toolsAndAuthOnly
                    )
                )
            }
            #expect(mcpServers.servers.allSatisfy { server in
                server.name.isEmpty == false
            })

            await client.stop()
        } catch {
            await client.stop()
            throw error
        }
    }

    @Test(
        "sets a live thread name through the public thread handle",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_THREAD_MANAGEMENT_TESTS"] == "1",
            "Requires explicit opt-in because this test launches the local Codex CLI."
        ),
        .timeLimit(.minutes(2))
    )
    func setsLiveThreadName() async throws {
        let harness = try LiveCodexHarness()
        defer { harness.cleanup() }

        let client = try await makeInitializedLiveClient(using: harness)
        do {
            let thread = try await startThread(
                on: client,
                workspacePath: harness.threadAWorkspace.path,
                label: "thread-name"
            )
            let expectedName = "SwiftASB live name \(UUID().uuidString)"

            try await withTimeout(
                seconds: 15,
                operation: "setting a live Codex thread name"
            ) {
                try await thread.setName(expectedName)
            }

            await client.stop()
        } catch {
            await client.stop()
            throw error
        }
    }

    @Test(
        "rolls back a disposable live thread and records a local marker",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_ROLLBACK_TESTS"] == "1",
            "Requires explicit opt-in because this test launches the local Codex CLI and mutates stored thread history."
        ),
        .timeLimit(.minutes(3))
    )
    func rollsBackLiveThreadAndRecordsMarker() async throws {
        let harness = try LiveCodexHarness()
        defer { harness.cleanup() }

        let client = try await makeInitializedLiveClient(using: harness)
        do {
            let thread = try await startThread(
                on: client,
                workspacePath: harness.rollbackWorkspace.path,
                label: "rollback",
                ephemeral: false,
                developerInstructions: """
                You are running inside a SwiftASB live integration test.
                Do not call tools.
                Do not edit files.
                Do not ask follow-up questions.
                Reply only with the exact text requested by the user message.
                """
            )

            let firstTurn = try await startTurn(
                on: thread,
                prompt: prompt(label: "LIVE_ROLLBACK_FIRST_DONE")
            )
            let firstCompletion = try await awaitCompletion(
                of: firstTurn,
                timeoutSeconds: 45,
                operation: "waiting for the first live rollback turn to complete"
            )
            #expect(firstCompletion.turn.status == .completed)

            let secondTurn = try await startTurn(
                on: thread,
                prompt: prompt(label: "LIVE_ROLLBACK_SECOND_DONE")
            )
            let secondCompletion = try await awaitCompletion(
                of: secondTurn,
                timeoutSeconds: 45,
                operation: "waiting for the second live rollback turn to complete"
            )
            #expect(secondCompletion.turn.status == .completed)

            let beforeRollback = try #require(await client.debugThreadHistorySnapshot(threadID: thread.id))
            #expect(beforeRollback.turns.map(\.id).contains(firstCompletion.turn.id))
            #expect(beforeRollback.turns.map(\.id).contains(secondCompletion.turn.id))

            let rolledBackThread = try await withTimeout(
                seconds: 20,
                operation: "rolling back the latest live Codex turn"
            ) {
                try await thread.rollbackLastTurns(1)
            }
            #expect(rolledBackThread.id == thread.id)

            let afterRollback = try #require(await client.debugThreadHistorySnapshot(threadID: thread.id))
            let remainingTurnIDs = afterRollback.turns.map(\.id)
            #expect(remainingTurnIDs.contains(firstCompletion.turn.id))
            #expect(remainingTurnIDs.contains(secondCompletion.turn.id) == false)
            #expect(afterRollback.rollbacks.isEmpty == false)

            let latestRollback = try #require(afterRollback.rollbacks.last)
            #expect(latestRollback.requestedTurnCount == 1)
            #expect(latestRollback.previousNewestTurnID == secondCompletion.turn.id)
            #expect(latestRollback.removedTurnIDs == [secondCompletion.turn.id])
            #expect(latestRollback.resultingNewestTurnID == firstCompletion.turn.id)

            await client.stop()
        } catch {
            await client.stop()
            throw error
        }
    }

    @Test(
        "materializes a non-ephemeral live thread and pages its turns through the public client",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_HISTORY_TESTS"] == "1",
            "Requires explicit opt-in because this test launches the local Codex CLI and reads stored thread history."
        ),
        .timeLimit(.minutes(3))
    )
    func materializesLiveThreadHistoryThroughPublicClient() async throws {
        let mockResponses = try await MockResponsesServer(
            responses: [
                .assistantMessage("LIVE_HISTORY_FIRST_DONE"),
                .assistantMessage("LIVE_HISTORY_SECOND_DONE"),
            ]
        )
        defer { mockResponses.stop() }

        let harness = try LiveCodexHarness(
            configMode: .mockResponses(baseURL: mockResponses.baseURL.absoluteString)
        )
        defer { harness.cleanup() }

        let client = try await makeInitializedLiveClient(using: harness)
        do {
            let thread = try await startThread(
                on: client,
                workspacePath: harness.threadAWorkspace.path,
                label: "history",
                ephemeral: false
            )

            let firstTurn = try await startTurn(
                on: thread,
                prompt: prompt(label: "LIVE_HISTORY_FIRST_DONE")
            )
            let firstCompletion = try await awaitCompletion(
                of: firstTurn,
                timeoutSeconds: 45,
                operation: "waiting for the first live history turn to complete"
            )
            #expect(firstCompletion.turn.status == .completed)

            let secondTurn = try await startTurn(
                on: thread,
                prompt: prompt(label: "LIVE_HISTORY_SECOND_DONE")
            )
            let secondCompletion = try await awaitCompletion(
                of: secondTurn,
                timeoutSeconds: 45,
                operation: "waiting for the second live history turn to complete"
            )
            #expect(secondCompletion.turn.status == .completed)

            let readResult = try await withTimeout(
                seconds: 20,
                operation: "reading the materialized live thread"
            ) {
                try await client.readThread(
                    .init(
                        threadID: thread.id,
                        includeTurns: true
                    )
                )
            }
            #expect(readResult.thread.id == thread.id)
            #expect(readResult.turns.map(\.id).contains(firstCompletion.turn.id))
            #expect(readResult.turns.map(\.id).contains(secondCompletion.turn.id))

            let turnsPage = try await withTimeout(
                seconds: 20,
                operation: "listing materialized live thread turns"
            ) {
                try await client.listThreadTurns(
                    .init(
                        threadID: thread.id,
                        limit: 10,
                        sortDirection: .asc
                    )
                )
            }
            let pagedTurnIDs = turnsPage.turns.map(\.id)
            #expect(pagedTurnIDs.contains(firstCompletion.turn.id))
            #expect(pagedTurnIDs.contains(secondCompletion.turn.id))
            #expect(mockResponses.requestCount >= 2)

            await client.stop()
        } catch {
            await client.stop()
            throw error
        }
    }

    @Test(
        "probes live approval-path behavior for shell commands",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_APPROVAL_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_APPROVAL_PROBE_TESTS"] == "1",
            "Requires explicit opt-in because this test launches the local Codex CLI."
        ),
        .timeLimit(.minutes(2))
    )
    func acceptsLiveApprovalRequestAndCompletesTurn() async throws {
        let harness = try LiveCodexHarness()
        defer { harness.cleanup() }

        let approvalFixtureURL = harness.threadAWorkspace
            .appendingPathComponent("approval-target.txt", isDirectory: false)
        let fixtureText = "approval-fixture-\(UUID().uuidString)\n"
        try Data(fixtureText.utf8).write(to: approvalFixtureURL)
        let expectedDigest = Data(SHA256.hash(data: Data(fixtureText.utf8))).map {
            String(format: "%02x", $0)
        }.joined()

        let client = try await makeInitializedLiveClient(using: harness)
        do {
            let approvalThread = try await startThread(
                on: client,
                workspacePath: harness.threadAWorkspace.path,
                label: "approval",
                approvalPolicy: .onRequest,
                approvalsReviewer: .user,
                developerInstructions: """
                You are running inside a SwiftASB live integration test.
                You must use a shell command if approval is granted.
                Do not ask follow-up questions.
                Do not guess or answer from memory.
                After the shell command succeeds, reply with exactly the requested digest and nothing else.
                """
            )

            let approvalTurn = try await startTurn(
                on: approvalThread,
                prompt: """
                Use a shell command to print the SHA-256 digest of approval-target.txt in the current
                working directory, then reply with exactly that digest and nothing else.
                """,
                approvalPolicy: .onRequest,
                approvalsReviewer: .user
            )

            let minimap = await approvalTurn.minimap
            let approvalOutcome = try await awaitApprovalPathOutcome(
                in: minimap,
                timeoutSeconds: 20,
                operation: "waiting for a live approval-path outcome"
            )

            switch approvalOutcome {
            case let .approvalRequested(approvalRequest):
                switch approvalRequest {
                case let .commandExecution(commandRequest):
                    #expect(commandRequest.threadID == approvalThread.id)
                    #expect(commandRequest.turnID == approvalTurn.turn.id)
                    #expect(commandRequest.reason?.isEmpty == false)
                case let .fileChange(fileRequest):
                    #expect(fileRequest.threadID == approvalThread.id)
                    #expect(fileRequest.turnID == approvalTurn.turn.id)
                case let .permissions(permissionsRequest):
                    #expect(permissionsRequest.threadID == approvalThread.id)
                    #expect(permissionsRequest.turnID == approvalTurn.turn.id)
                }

                try await approvalTurn.respond(
                    to: approvalRequest,
                    with: acceptanceResponse(for: approvalRequest)
                )

                let resolution = try await awaitRequestResolution(
                    in: minimap,
                    expectedKind: approvalRequest.kind,
                    timeoutSeconds: 20,
                    operation: "waiting for the accepted live approval request to resolve"
                )
                #expect(resolution.threadID == approvalThread.id)
                #expect(resolution.turnID == approvalTurn.turn.id)

                let completion = try await awaitCompletion(
                    of: approvalTurn,
                    timeoutSeconds: 45,
                    operation: "waiting for the live approval-path turn to complete"
                )
                #expect(completion.turn.status == .completed)
            case let .completedWithoutApproval(status, completedText):
                #expect(status == .completed)
                #expect(completedText == expectedDigest)
            }

            let latestCompletedItemText = await MainActor.run(body: { minimap.latestCompletedItem?.item.text })
            #expect(latestCompletedItemText == expectedDigest)

            await client.stop()
        } catch {
            await client.stop()
            throw error
        }
    }

    @Test(
        "probes live approval and server-request candidate scenarios",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_APPROVAL_PROBE_TESTS"] == "1",
            "Requires explicit opt-in because this test launches the local Codex CLI and probes nondeterministic approval behavior."
        ),
        .timeLimit(.minutes(5))
    )
    func probesLiveApprovalAndServerRequestCandidates() async throws {
        let harness = try LiveCodexHarness(configMode: .approvalProbe)
        defer { harness.cleanup() }

        let readFixtureURL = harness.approvalProbeWorkspace
            .appendingPathComponent("approval-read-target.txt", isDirectory: false)
        let readFixtureText = "approval-probe-\(UUID().uuidString)\n"
        try Data(readFixtureText.utf8).write(to: readFixtureURL)
        let expectedDigest = Data(SHA256.hash(data: Data(readFixtureText.utf8))).map {
            String(format: "%02x", $0)
        }.joined()

        let editFixtureURL = harness.approvalProbeWorkspace
            .appendingPathComponent("approval-edit-target.txt", isDirectory: false)
        try Data("before\n".utf8).write(to: editFixtureURL)

        let createURL = harness.approvalProbeWorkspace
            .appendingPathComponent("approval-create-target.txt", isDirectory: false)

        let client = try await makeInitializedLiveClient(using: harness)
        do {
            let cases = [
                LiveApprovalProbeCase(
                    label: "command-read",
                    prompt: """
                    Use a shell command to print the SHA-256 digest of approval-read-target.txt in the
                    current working directory, then reply with exactly this text and nothing else:
                    \(expectedDigest)
                    """,
                    expectedFinalText: expectedDigest,
                    inspectedPath: readFixtureURL
                ),
                LiveApprovalProbeCase(
                    label: "file-create",
                    prompt: """
                    Create approval-create-target.txt with exactly this content:
                    created by approval probe

                    Then reply with exactly APPROVAL_PROBE_CREATE_DONE and nothing else.
                    """,
                    expectedFinalText: "APPROVAL_PROBE_CREATE_DONE",
                    inspectedPath: createURL
                ),
                LiveApprovalProbeCase(
                    label: "file-edit",
                    prompt: """
                    Replace approval-edit-target.txt with exactly this content:
                    after

                    Then reply with exactly APPROVAL_PROBE_EDIT_DONE and nothing else.
                    """,
                    expectedFinalText: "APPROVAL_PROBE_EDIT_DONE",
                    inspectedPath: editFixtureURL
                ),
            ]

            var results: [LiveApprovalProbeReport.Result] = []
            for probeCase in cases {
                do {
                    let caseThread = try await startApprovalProbeThread(
                        on: client,
                        harness: harness,
                        label: "approval-probe-\(probeCase.label)",
                        sandboxMode: .workspaceWrite
                    )
                    results.append(try await runApprovalProbeCaseReport(probeCase, on: caseThread))
                } catch {
                    results.append(.init(probeCase, error: error))
                }
            }

            let readOnlyTargetURL = harness.approvalProbeWorkspace
                .appendingPathComponent("approval-read-only-target.txt", isDirectory: false)
            let readOnlyWriteCase = LiveApprovalProbeCase(
                label: "read-only-file-create",
                prompt: """
                Create approval-read-only-target.txt with exactly this content:
                created from read-only sandbox

                Then reply with exactly APPROVAL_PROBE_READ_ONLY_CREATE_DONE and nothing else.
                """,
                expectedFinalText: "APPROVAL_PROBE_READ_ONLY_CREATE_DONE",
                inspectedPath: readOnlyTargetURL
            )
            do {
                let readOnlyThread = try await startApprovalProbeThread(
                    on: client,
                    harness: harness,
                    label: "approval-probe-read-only",
                    sandboxMode: .readOnly
                )
                results.append(try await runApprovalProbeCaseReport(readOnlyWriteCase, on: readOnlyThread))
            } catch {
                results.append(.init(readOnlyWriteCase, error: error))
            }

            let report = LiveApprovalProbeReport(
                threadID: results.first?.threadID ?? "",
                readOnlyThreadID: results.first { $0.label == readOnlyWriteCase.label }?.threadID ?? "",
                codexConfig: harness.codexConfigSummary,
                workspacePath: harness.approvalProbeWorkspace.path,
                results: results
            )
            try harness.writeReport(report, fileName: "live-approval-server-request-probe.json")

            #expect(results.map(\.label) == (cases + [readOnlyWriteCase]).map(\.label))

            await client.stop()
        } catch {
            await client.stop()
            throw error
        }
    }

    @Test(
        "completes deterministic command approval through the raw real app-server",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_APPROVAL_PROBE_TESTS"] == "1",
            "Requires explicit opt-in because this test launches the local Codex CLI."
        ),
        .timeLimit(.minutes(2))
    )
    func completesDeterministicCommandApprovalThroughRawRealAppServer() async throws {
        let mockResponses = try await MockResponsesServer(
            responses: [
                .shellCommand(callID: "approval-shell-call", command: "/usr/bin/perl -e 'print 42, qq(\\n)'"),
                .assistantMessage("APPROVAL_ACCEPTED_DONE"),
            ]
        )
        defer { mockResponses.stop() }

        let harness = try LiveCodexHarness(
            configMode: .mockResponses(baseURL: mockResponses.baseURL.absoluteString)
        )
        defer { harness.cleanup() }

        let transport = CodexAppServerTransport(
            configuration: .init(
                codexExecutableURL: harness.codexExecutableURL,
                currentDirectoryURL: harness.rootDirectoryURL,
                environment: harness.configuration.environment
            )
        )
        let protocolLayer = CodexAppServerProtocol()
        let serverEvents = await transport.serverEvents()
        var eventIterator = serverEvents.makeAsyncIterator()

        do {
            try await transport.start()

            let initializeRequestID = CodexRPCRequestID.string("deterministic-approval-initialize")
            let initializePayload = try protocolLayer.makeInitializeRequest(
                id: initializeRequestID,
                params: CodexWireInitializeParams(
                    capabilities: CodexWireInitializeCapabilities(
                        experimentalAPI: nil,
                        optOutNotificationMethods: [
                            "account/rateLimits/updated",
                            "hook/completed",
                            "hook/started",
                            "mcpServer/startupStatus/updated",
                        ]
                    ),
                    clientInfo: .init(
                        name: "SwiftASBDeterministicApprovalTests",
                        title: "SwiftASB Deterministic Approval Tests",
                        version: "0.1.0"
                    )
                )
            )
            let initializeResponsePayload = try await withTimeout(
                seconds: 15,
                operation: "waiting for deterministic approval initialize response"
            ) {
                try await transport.send(initializePayload, id: initializeRequestID)
            }
            _ = try protocolLayer.decodeInitializeResponse(
                initializeResponsePayload,
                expectedID: initializeRequestID
            )

            try await transport.sendNotification(
                try protocolLayer.makeInitializedNotification(),
                method: "initialized"
            )

            let threadRequestID = CodexRPCRequestID.string("deterministic-approval-thread")
            let threadStartPayload = try protocolLayer.makeThreadStartRequest(
                id: threadRequestID,
                params: CodexWireThreadStartParams(
                    approvalPolicy: .enumeration(.untrusted),
                    approvalsReviewer: .user,
                    baseInstructions: nil,
                    config: nil,
                    cwd: harness.approvalProbeWorkspace.path,
                    developerInstructions: "Use the model-provided tool call exactly as emitted.",
                    dynamicTools: nil,
                    environments: nil,
                    ephemeral: true,
                    experimentalRawEvents: nil,
                    mockExperimentalField: nil,
                    model: nil,
                    modelProvider: nil,
                    permissions: nil,
                    persistExtendedHistory: nil,
                    personality: nil,
                    sandbox: .readOnly,
                    serviceName: nil,
                    serviceTier: nil,
                    sessionStartSource: nil
                )
            )
            let threadResponsePayload = try await withTimeout(
                seconds: 15,
                operation: "waiting for deterministic approval thread/start response"
            ) {
                try await transport.send(threadStartPayload, id: threadRequestID)
            }
            let threadResponse = try protocolLayer.decodeThreadStartResponse(
                threadResponsePayload,
                expectedID: threadRequestID
            )

            let turnRequestID = CodexRPCRequestID.string("deterministic-approval-turn")
            let turnStartPayload = try protocolLayer.makeTurnStartRequest(
                id: turnRequestID,
                params: CodexWireTurnStartParams(
                    approvalPolicy: .enumeration(.untrusted),
                    approvalsReviewer: .user,
                    collaborationMode: nil,
                    cwd: nil,
                    effort: nil,
                    environments: nil,
                    input: [
                        CodexWireUserInput(
                            text: "Run the provided command, then report completion.",
                            textElements: nil,
                            type: .text,
                            url: nil,
                            path: nil,
                            name: nil
                        )
                    ],
                    model: nil,
                    outputSchema: nil,
                    permissions: nil,
                    personality: nil,
                    responsesapiClientMetadata: nil,
                    sandboxPolicy: nil,
                    serviceTier: nil,
                    summary: CodexWireReasoningSummary.none,
                    threadID: threadResponse.thread.id
                )
            )
            let turnResponsePayload = try await withTimeout(
                seconds: 15,
                operation: "waiting for deterministic approval turn/start response"
            ) {
                try await transport.send(turnStartPayload, id: turnRequestID)
            }
            let turnResponse = try protocolLayer.decodeTurnStartResponse(
                turnResponsePayload,
                expectedID: turnRequestID
            )

            let approvalResult = try await awaitRawCommandApprovalCompletion(
                eventIterator: &eventIterator,
                protocolLayer: protocolLayer,
                transport: transport,
                threadID: threadResponse.thread.id,
                turnID: turnResponse.turn.id,
                operation: "waiting for deterministic raw command approval completion"
            )
            #expect(approvalResult.threadID == threadResponse.thread.id)
            #expect(approvalResult.turnID == turnResponse.turn.id)
            #expect(approvalResult.sawCommandItem)
            #expect(approvalResult.sawWaitingOnApproval)
            #expect(approvalResult.sawApprovalRequest)
            #expect(approvalResult.sawServerRequestResolved)
            #expect(approvalResult.completion.turn.status == .completed)
            #expect(mockResponses.requestCount >= 2)

            await transport.stop()
        } catch {
            await transport.stop()
            throw error
        }
    }

    @Test(
        "completes deterministic permissions approval through the raw real app-server",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_APPROVAL_PROBE_TESTS"] == "1",
            "Requires explicit opt-in because this test launches the local Codex CLI."
        ),
        .timeLimit(.minutes(2))
    )
    func completesDeterministicPermissionsApprovalThroughRawRealAppServer() async throws {
        let mockResponses = try await MockResponsesServer(
            responses: [
                .requestPermissions(
                    callID: "permissions-call",
                    reason: "Need write access to the live test workspace.",
                    writePaths: ["/tmp/swiftasb-permissions-placeholder"]
                ),
                .assistantMessage("PERMISSIONS_ACCEPTED_DONE"),
            ]
        )
        defer { mockResponses.stop() }

        let harness = try LiveCodexHarness(
            configMode: .mockResponses(
                baseURL: mockResponses.baseURL.absoluteString,
                requestPermissionsTool: true
            )
        )
        defer { harness.cleanup() }

        let transport = CodexAppServerTransport(
            configuration: .init(
                codexExecutableURL: harness.codexExecutableURL,
                currentDirectoryURL: harness.rootDirectoryURL,
                environment: harness.configuration.environment
            )
        )
        let protocolLayer = CodexAppServerProtocol()
        let serverEvents = await transport.serverEvents()
        var eventIterator = serverEvents.makeAsyncIterator()

        do {
            try await transport.start()

            let initializeRequestID = CodexRPCRequestID.string("deterministic-permissions-initialize")
            let initializePayload = try protocolLayer.makeInitializeRequest(
                id: initializeRequestID,
                params: CodexWireInitializeParams(
                    capabilities: CodexWireInitializeCapabilities(
                        experimentalAPI: nil,
                        optOutNotificationMethods: [
                            "account/rateLimits/updated",
                            "hook/completed",
                            "hook/started",
                            "mcpServer/startupStatus/updated",
                        ]
                    ),
                    clientInfo: .init(
                        name: "SwiftASBDeterministicPermissionsTests",
                        title: "SwiftASB Deterministic Permissions Tests",
                        version: "0.1.0"
                    )
                )
            )
            let initializeResponsePayload = try await withTimeout(
                seconds: 15,
                operation: "waiting for deterministic permissions initialize response"
            ) {
                try await transport.send(initializePayload, id: initializeRequestID)
            }
            _ = try protocolLayer.decodeInitializeResponse(
                initializeResponsePayload,
                expectedID: initializeRequestID
            )

            try await transport.sendNotification(
                try protocolLayer.makeInitializedNotification(),
                method: "initialized"
            )

            let threadRequestID = CodexRPCRequestID.string("deterministic-permissions-thread")
            let threadStartPayload = try protocolLayer.makeThreadStartRequest(
                id: threadRequestID,
                params: CodexWireThreadStartParams(
                    approvalPolicy: .enumeration(.untrusted),
                    approvalsReviewer: .user,
                    baseInstructions: nil,
                    config: nil,
                    cwd: harness.approvalProbeWorkspace.path,
                    developerInstructions: "Use the model-provided tool call exactly as emitted.",
                    dynamicTools: nil,
                    environments: nil,
                    ephemeral: true,
                    experimentalRawEvents: nil,
                    mockExperimentalField: nil,
                    model: nil,
                    modelProvider: nil,
                    permissions: nil,
                    persistExtendedHistory: nil,
                    personality: nil,
                    sandbox: .readOnly,
                    serviceName: nil,
                    serviceTier: nil,
                    sessionStartSource: nil
                )
            )
            let threadResponsePayload = try await withTimeout(
                seconds: 15,
                operation: "waiting for deterministic permissions thread/start response"
            ) {
                try await transport.send(threadStartPayload, id: threadRequestID)
            }
            let threadResponse = try protocolLayer.decodeThreadStartResponse(
                threadResponsePayload,
                expectedID: threadRequestID
            )

            let turnRequestID = CodexRPCRequestID.string("deterministic-permissions-turn")
            let turnStartPayload = try protocolLayer.makeTurnStartRequest(
                id: turnRequestID,
                params: CodexWireTurnStartParams(
                    approvalPolicy: .enumeration(.untrusted),
                    approvalsReviewer: .user,
                    collaborationMode: nil,
                    cwd: nil,
                    effort: nil,
                    environments: nil,
                    input: [
                        CodexWireUserInput(
                            text: "Request the provided permissions, then report completion.",
                            textElements: nil,
                            type: .text,
                            url: nil,
                            path: nil,
                            name: nil
                        )
                    ],
                    model: nil,
                    outputSchema: nil,
                    permissions: nil,
                    personality: nil,
                    responsesapiClientMetadata: nil,
                    sandboxPolicy: nil,
                    serviceTier: nil,
                    summary: CodexWireReasoningSummary.none,
                    threadID: threadResponse.thread.id
                )
            )
            let turnResponsePayload = try await withTimeout(
                seconds: 15,
                operation: "waiting for deterministic permissions turn/start response"
            ) {
                try await transport.send(turnStartPayload, id: turnRequestID)
            }
            let turnResponse = try protocolLayer.decodeTurnStartResponse(
                turnResponsePayload,
                expectedID: turnRequestID
            )

            let approvalResult = try await awaitRawPermissionsApprovalCompletion(
                eventIterator: &eventIterator,
                protocolLayer: protocolLayer,
                transport: transport,
                threadID: threadResponse.thread.id,
                turnID: turnResponse.turn.id,
                operation: "waiting for deterministic raw permissions approval completion"
            )
            #expect(approvalResult.threadID == threadResponse.thread.id)
            #expect(approvalResult.turnID == turnResponse.turn.id)
            #expect(approvalResult.sawApprovalRequest)
            #expect(approvalResult.sawServerRequestResolved)
            #expect(approvalResult.sawWaitingOnApproval)
            #expect(approvalResult.requestedWritePaths == ["/tmp/swiftasb-permissions-placeholder"])
            #expect(approvalResult.requestReason == "Need write access to the live test workspace.")
            #expect(approvalResult.completion.turn.status == .completed)
            #expect(mockResponses.requestCount >= 2)

            await transport.stop()
        } catch {
            await transport.stop()
            throw error
        }
    }

    @Test(
        "completes deterministic tool user input through the raw real app-server",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_SERVER_REQUEST_TESTS"] == "1",
            "Requires explicit opt-in because this test launches the local Codex CLI."
        ),
        .timeLimit(.minutes(2))
    )
    func completesDeterministicToolUserInputThroughRawRealAppServer() async throws {
        let mockResponses = try await MockResponsesServer(
            responses: [
                .requestUserInput(callID: "tool-input-call"),
                .assistantMessage("TOOL_USER_INPUT_DONE"),
            ]
        )
        defer { mockResponses.stop() }

        let harness = try LiveCodexHarness(
            configMode: .mockResponses(baseURL: mockResponses.baseURL.absoluteString)
        )
        defer { harness.cleanup() }

        let transport = CodexAppServerTransport(
            configuration: .init(
                codexExecutableURL: harness.codexExecutableURL,
                currentDirectoryURL: harness.rootDirectoryURL,
                environment: harness.configuration.environment
            )
        )
        let protocolLayer = CodexAppServerProtocol()
        let serverEvents = await transport.serverEvents()
        var eventIterator = serverEvents.makeAsyncIterator()

        do {
            try await transport.start()

            let initializeRequestID = CodexRPCRequestID.string("deterministic-tool-input-initialize")
            let initializePayload = try protocolLayer.makeInitializeRequest(
                id: initializeRequestID,
                params: CodexWireInitializeParams(
                    capabilities: CodexWireInitializeCapabilities(
                        experimentalAPI: true,
                        optOutNotificationMethods: [
                            "account/rateLimits/updated",
                            "hook/completed",
                            "hook/started",
                            "mcpServer/startupStatus/updated",
                        ]
                    ),
                    clientInfo: .init(
                        name: "SwiftASBDeterministicToolInputTests",
                        title: "SwiftASB Deterministic Tool Input Tests",
                        version: "0.1.0"
                    )
                )
            )
            let initializeResponsePayload = try await withTimeout(
                seconds: 15,
                operation: "waiting for deterministic tool-user-input initialize response"
            ) {
                try await transport.send(initializePayload, id: initializeRequestID)
            }
            _ = try protocolLayer.decodeInitializeResponse(
                initializeResponsePayload,
                expectedID: initializeRequestID
            )

            try await transport.sendNotification(
                try protocolLayer.makeInitializedNotification(),
                method: "initialized"
            )

            let threadRequestID = CodexRPCRequestID.string("deterministic-tool-input-thread")
            let threadStartPayload = try protocolLayer.makeThreadStartRequest(
                id: threadRequestID,
                params: CodexWireThreadStartParams(
                    approvalPolicy: .enumeration(.never),
                    approvalsReviewer: nil,
                    baseInstructions: nil,
                    config: nil,
                    cwd: harness.approvalProbeWorkspace.path,
                    developerInstructions: "Use the model-provided request_user_input tool call exactly as emitted.",
                    dynamicTools: nil,
                    environments: nil,
                    ephemeral: true,
                    experimentalRawEvents: nil,
                    mockExperimentalField: nil,
                    model: nil,
                    modelProvider: nil,
                    permissions: nil,
                    persistExtendedHistory: nil,
                    personality: nil,
                    sandbox: .readOnly,
                    serviceName: nil,
                    serviceTier: nil,
                    sessionStartSource: nil
                )
            )
            let threadResponsePayload = try await withTimeout(
                seconds: 15,
                operation: "waiting for deterministic tool-user-input thread/start response"
            ) {
                try await transport.send(threadStartPayload, id: threadRequestID)
            }
            let threadResponse = try protocolLayer.decodeThreadStartResponse(
                threadResponsePayload,
                expectedID: threadRequestID
            )

            let turnRequestID = CodexRPCRequestID.string("deterministic-tool-input-turn")
            let turnStartPayload = try protocolLayer.makeTurnStartRequest(
                id: turnRequestID,
                params: CodexWireTurnStartParams(
                    approvalPolicy: .enumeration(.never),
                    approvalsReviewer: nil,
                    collaborationMode: CodexWireCollaborationMode(
                        mode: .plan,
                        settings: CodexWireSettings(
                            developerInstructions: nil,
                            model: "mock-model",
                            reasoningEffort: nil
                        )
                    ),
                    cwd: nil,
                    effort: nil,
                    environments: nil,
                    input: [
                        CodexWireUserInput(
                            text: "Ask the provided question, then report completion.",
                            textElements: nil,
                            type: .text,
                            url: nil,
                            path: nil,
                            name: nil
                        )
                    ],
                    model: nil,
                    outputSchema: nil,
                    permissions: nil,
                    personality: nil,
                    responsesapiClientMetadata: nil,
                    sandboxPolicy: nil,
                    serviceTier: nil,
                    summary: CodexWireReasoningSummary.none,
                    threadID: threadResponse.thread.id
                )
            )
            let turnResponsePayload = try await withTimeout(
                seconds: 15,
                operation: "waiting for deterministic tool-user-input turn/start response"
            ) {
                try await transport.send(turnStartPayload, id: turnRequestID)
            }
            let turnResponse = try protocolLayer.decodeTurnStartResponse(
                turnResponsePayload,
                expectedID: turnRequestID
            )

            let inputResult = try await awaitRawToolUserInputCompletion(
                eventIterator: &eventIterator,
                protocolLayer: protocolLayer,
                transport: transport,
                threadID: threadResponse.thread.id,
                turnID: turnResponse.turn.id,
                operation: "waiting for deterministic raw tool-user-input completion"
            )
            #expect(inputResult.threadID == threadResponse.thread.id)
            #expect(inputResult.turnID == turnResponse.turn.id)
            #expect(inputResult.questionIDs == ["direction"])
            #expect(inputResult.sawElicitationRequest)
            #expect(inputResult.sawServerRequestResolved)
            #expect(inputResult.completion.turn.status == .completed)
            #expect(mockResponses.requestCount >= 2)

            await transport.stop()
        } catch {
            await transport.stop()
            throw error
        }
    }

    @Test(
        "records deterministic regular MCP elicitation fixture behavior through the raw real app-server",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_SERVER_REQUEST_TESTS"] == "1",
            "Requires explicit opt-in because this test launches the local Codex CLI and a temporary MCP server fixture."
        ),
        .timeLimit(.minutes(2))
    )
    func recordsDeterministicRegularMcpElicitationFixtureBehaviorThroughRawRealAppServer() async throws {
        let mockResponses = try await MockResponsesServer(
            responses: [
                .mcpElicitationToolCall(callID: "mcp-elicitation-call"),
                .assistantMessage("MCP_ELICITATION_DONE"),
            ]
        )
        defer { mockResponses.stop() }

        let harness = try LiveCodexHarness(
            configMode: .mockResponsesWithMcpElicitation(baseURL: mockResponses.baseURL.absoluteString)
        )
        defer { harness.cleanup() }

        let transport = CodexAppServerTransport(
            configuration: .init(
                codexExecutableURL: harness.codexExecutableURL,
                currentDirectoryURL: harness.rootDirectoryURL,
                environment: harness.configuration.environment
            )
        )
        let protocolLayer = CodexAppServerProtocol()
        let serverEvents = await transport.serverEvents()
        var eventIterator = serverEvents.makeAsyncIterator()

        do {
            try await transport.start()

            let initializeRequestID = CodexRPCRequestID.string("deterministic-mcp-elicitation-initialize")
            let initializePayload = try protocolLayer.makeInitializeRequest(
                id: initializeRequestID,
                params: CodexWireInitializeParams(
                    capabilities: CodexWireInitializeCapabilities(
                        experimentalAPI: nil,
                        optOutNotificationMethods: [
                            "account/rateLimits/updated",
                            "hook/completed",
                            "hook/started",
                            "mcpServer/startupStatus/updated",
                        ]
                    ),
                    clientInfo: .init(
                        name: "SwiftASBDeterministicMcpElicitationTests",
                        title: "SwiftASB Deterministic MCP Elicitation Tests",
                        version: "0.1.0"
                    )
                )
            )
            let initializeResponsePayload = try await withTimeout(
                seconds: 15,
                operation: "waiting for deterministic MCP elicitation initialize response"
            ) {
                try await transport.send(initializePayload, id: initializeRequestID)
            }
            _ = try protocolLayer.decodeInitializeResponse(
                initializeResponsePayload,
                expectedID: initializeRequestID
            )

            try await transport.sendNotification(
                try protocolLayer.makeInitializedNotification(),
                method: "initialized"
            )

            let threadRequestID = CodexRPCRequestID.string("deterministic-mcp-elicitation-thread")
            let threadStartPayload = try protocolLayer.makeThreadStartRequest(
                id: threadRequestID,
                params: CodexWireThreadStartParams(
                    approvalPolicy: .enumeration(.never),
                    approvalsReviewer: nil,
                    baseInstructions: nil,
                    config: nil,
                    cwd: harness.approvalProbeWorkspace.path,
                    developerInstructions: "Use the model-provided MCP tool call exactly as emitted.",
                    dynamicTools: nil,
                    environments: nil,
                    ephemeral: true,
                    experimentalRawEvents: nil,
                    mockExperimentalField: nil,
                    model: nil,
                    modelProvider: nil,
                    permissions: nil,
                    persistExtendedHistory: nil,
                    personality: nil,
                    sandbox: .readOnly,
                    serviceName: nil,
                    serviceTier: nil,
                    sessionStartSource: nil
                )
            )
            let threadResponsePayload = try await withTimeout(
                seconds: 15,
                operation: "waiting for deterministic MCP elicitation thread/start response"
            ) {
                try await transport.send(threadStartPayload, id: threadRequestID)
            }
            let threadResponse = try protocolLayer.decodeThreadStartResponse(
                threadResponsePayload,
                expectedID: threadRequestID
            )

            let turnRequestID = CodexRPCRequestID.string("deterministic-mcp-elicitation-turn")
            let turnStartPayload = try protocolLayer.makeTurnStartRequest(
                id: turnRequestID,
                params: CodexWireTurnStartParams(
                    approvalPolicy: .enumeration(.never),
                    approvalsReviewer: nil,
                    collaborationMode: nil,
                    cwd: nil,
                    effort: nil,
                    environments: nil,
                    input: [
                        CodexWireUserInput(
                            text: "Call the provided MCP tool, then report completion.",
                            textElements: nil,
                            type: .text,
                            url: nil,
                            path: nil,
                            name: nil
                        )
                    ],
                    model: nil,
                    outputSchema: nil,
                    permissions: nil,
                    personality: nil,
                    responsesapiClientMetadata: nil,
                    sandboxPolicy: nil,
                    serviceTier: nil,
                    summary: CodexWireReasoningSummary.none,
                    threadID: threadResponse.thread.id
                )
            )
            let turnResponsePayload = try await withTimeout(
                seconds: 15,
                operation: "waiting for deterministic MCP elicitation turn/start response"
            ) {
                try await transport.send(turnStartPayload, id: turnRequestID)
            }
            let turnResponse = try protocolLayer.decodeTurnStartResponse(
                turnResponsePayload,
                expectedID: turnRequestID
            )

            let elicitationResult = try await awaitRawMcpElicitationCompletion(
                eventIterator: &eventIterator,
                protocolLayer: protocolLayer,
                transport: transport,
                threadID: threadResponse.thread.id,
                turnID: turnResponse.turn.id,
                operation: "waiting for deterministic raw MCP elicitation completion"
            )
            #expect(elicitationResult.threadID == threadResponse.thread.id)
            #expect(elicitationResult.turnID == turnResponse.turn.id)
            #expect(elicitationResult.serverName == "swiftasb_elicitation")
            #expect(elicitationResult.sawMcpToolCall)
            #expect(elicitationResult.completion.turn.status == .completed)
            #expect(mockResponses.requestCount >= 2)

            await transport.stop()
        } catch {
            await transport.stop()
            throw error
        }
    }

    @Test(
        "completes deterministic app connector MCP elicitation through the raw real app-server",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_SERVER_REQUEST_TESTS"] == "1",
            "Requires explicit opt-in because this test launches the local Codex CLI and a temporary app connector MCP server fixture."
        ),
        .timeLimit(.minutes(2))
    )
    func completesDeterministicAppConnectorMcpElicitationThroughRawRealAppServer() async throws {
        let mockResponses = try await MockResponsesServer(
            responses: [
                .assistantMessage("APP_CONNECTOR_WARMUP_DONE"),
                .appConnectorMcpElicitationToolCall(callID: "app-connector-mcp-elicitation-call"),
                .assistantMessage("APP_CONNECTOR_MCP_ELICITATION_DONE"),
            ]
        )
        defer { mockResponses.stop() }

        let appsServer = try await MockAppConnectorMcpServer()
        defer { appsServer.stop() }

        let harness = try LiveCodexHarness(
            configMode: .mockResponsesWithAppConnectorMcpElicitation(
                baseURL: mockResponses.baseURL.absoluteString,
                appsBaseURL: appsServer.baseURL.absoluteString
            )
        )
        defer { harness.cleanup() }

        let transport = CodexAppServerTransport(
            configuration: .init(
                codexExecutableURL: harness.codexExecutableURL,
                currentDirectoryURL: harness.rootDirectoryURL,
                environment: harness.configuration.environment
            )
        )
        let protocolLayer = CodexAppServerProtocol()
        let serverEvents = await transport.serverEvents()
        var eventIterator = serverEvents.makeAsyncIterator()

        do {
            try await transport.start()

            let initializeRequestID = CodexRPCRequestID.string("deterministic-app-connector-mcp-initialize")
            let initializePayload = try protocolLayer.makeInitializeRequest(
                id: initializeRequestID,
                params: CodexWireInitializeParams(
                    capabilities: CodexWireInitializeCapabilities(
                        experimentalAPI: nil,
                        optOutNotificationMethods: [
                            "account/rateLimits/updated",
                            "hook/completed",
                            "hook/started",
                            "mcpServer/startupStatus/updated",
                        ]
                    ),
                    clientInfo: .init(
                        name: "SwiftASBDeterministicAppConnectorMcpTests",
                        title: "SwiftASB Deterministic App Connector MCP Tests",
                        version: "0.1.0"
                    )
                )
            )
            let initializeResponsePayload = try await withTimeout(
                seconds: 15,
                operation: "waiting for deterministic app-connector MCP initialize response"
            ) {
                try await transport.send(initializePayload, id: initializeRequestID)
            }
            _ = try protocolLayer.decodeInitializeResponse(
                initializeResponsePayload,
                expectedID: initializeRequestID
            )

            try await transport.sendNotification(
                try protocolLayer.makeInitializedNotification(),
                method: "initialized"
            )

            let threadRequestID = CodexRPCRequestID.string("deterministic-app-connector-mcp-thread")
            let threadStartPayload = try protocolLayer.makeThreadStartRequest(
                id: threadRequestID,
                params: CodexWireThreadStartParams(
                    approvalPolicy: .enumeration(.onRequest),
                    approvalsReviewer: .user,
                    baseInstructions: nil,
                    config: nil,
                    cwd: harness.approvalProbeWorkspace.path,
                    developerInstructions: "Use the model-provided app connector MCP tool call exactly as emitted.",
                    dynamicTools: nil,
                    environments: nil,
                    ephemeral: true,
                    experimentalRawEvents: nil,
                    mockExperimentalField: nil,
                    model: "mock-model",
                    modelProvider: nil,
                    permissions: nil,
                    persistExtendedHistory: nil,
                    personality: nil,
                    sandbox: .readOnly,
                    serviceName: nil,
                    serviceTier: nil,
                    sessionStartSource: nil
                )
            )
            let threadResponsePayload = try await withTimeout(
                seconds: 15,
                operation: "waiting for deterministic app-connector MCP thread/start response"
            ) {
                try await transport.send(threadStartPayload, id: threadRequestID)
            }
            let threadResponse = try protocolLayer.decodeThreadStartResponse(
                threadResponsePayload,
                expectedID: threadRequestID
            )

            let warmupRequestID = CodexRPCRequestID.string("deterministic-app-connector-mcp-warmup-turn")
            let warmupPayload = try protocolLayer.makeTurnStartRequest(
                id: warmupRequestID,
                params: CodexWireTurnStartParams(
                    approvalPolicy: .enumeration(.onRequest),
                    approvalsReviewer: .user,
                    collaborationMode: nil,
                    cwd: nil,
                    effort: nil,
                    environments: nil,
                    input: [
                        CodexWireUserInput(
                            text: "Warm up connectors.",
                            textElements: nil,
                            type: .text,
                            url: nil,
                            path: nil,
                            name: nil
                        )
                    ],
                    model: "mock-model",
                    outputSchema: nil,
                    permissions: nil,
                    personality: nil,
                    responsesapiClientMetadata: nil,
                    sandboxPolicy: nil,
                    serviceTier: nil,
                    summary: CodexWireReasoningSummary.none,
                    threadID: threadResponse.thread.id
                )
            )
            let warmupResponsePayload = try await withTimeout(
                seconds: 15,
                operation: "waiting for deterministic app-connector MCP warmup turn/start response"
            ) {
                try await transport.send(warmupPayload, id: warmupRequestID)
            }
            let warmupResponse = try protocolLayer.decodeTurnStartResponse(
                warmupResponsePayload,
                expectedID: warmupRequestID
            )
            let warmupCompletion = try await awaitRawTurnCompletion(
                eventIterator: &eventIterator,
                protocolLayer: protocolLayer,
                threadID: threadResponse.thread.id,
                turnID: warmupResponse.turn.id,
                operation: "waiting for deterministic app-connector MCP warmup completion"
            )
            #expect(warmupCompletion.turn.status == .completed)

            let turnRequestID = CodexRPCRequestID.string("deterministic-app-connector-mcp-turn")
            let turnStartPayload = try protocolLayer.makeTurnStartRequest(
                id: turnRequestID,
                params: CodexWireTurnStartParams(
                    approvalPolicy: .enumeration(.onRequest),
                    approvalsReviewer: .user,
                    collaborationMode: nil,
                    cwd: nil,
                    effort: nil,
                    environments: nil,
                    input: [
                        CodexWireUserInput(
                            text: "Use [$calendar](app://calendar) to run the calendar tool.",
                            textElements: nil,
                            type: .text,
                            url: nil,
                            path: nil,
                            name: nil
                        )
                    ],
                    model: "mock-model",
                    outputSchema: nil,
                    permissions: nil,
                    personality: nil,
                    responsesapiClientMetadata: nil,
                    sandboxPolicy: nil,
                    serviceTier: nil,
                    summary: CodexWireReasoningSummary.none,
                    threadID: threadResponse.thread.id
                )
            )
            let turnResponsePayload = try await withTimeout(
                seconds: 15,
                operation: "waiting for deterministic app-connector MCP turn/start response"
            ) {
                try await transport.send(turnStartPayload, id: turnRequestID)
            }
            let turnResponse = try protocolLayer.decodeTurnStartResponse(
                turnResponsePayload,
                expectedID: turnRequestID
            )

            let elicitationResult = try await awaitRawMcpElicitationCompletion(
                eventIterator: &eventIterator,
                protocolLayer: protocolLayer,
                transport: transport,
                threadID: threadResponse.thread.id,
                turnID: turnResponse.turn.id,
                operation: "waiting for deterministic app-connector MCP elicitation completion"
            )
            #expect(elicitationResult.threadID == threadResponse.thread.id)
            #expect(elicitationResult.turnID == turnResponse.turn.id)
            #expect(elicitationResult.serverName == "codex_apps")
            #expect(elicitationResult.sawMcpToolCall)
            if !elicitationResult.sawElicitationRequest {
                Issue.record("app connector debug log:\n\(appsServer.debugLog)")
            }
            #expect(elicitationResult.sawElicitationRequest)
            #expect(elicitationResult.sawServerRequestResolved)
            #expect(elicitationResult.completion.turn.status == .completed)
            #expect(mockResponses.requestCount >= 3)
            #expect(appsServer.directoryRequestCount >= 1)
            #expect(appsServer.toolCallRequestCount >= 1)

            await transport.stop()
        } catch {
            await transport.stop()
            throw error
        }
    }

    @Test(
        "records live approval, sandbox, history, and diagnostics behavior matrix",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_BEHAVIOR_MATRIX_TESTS"] == "1",
            "Requires explicit opt-in because this test launches the local Codex CLI and records observational runtime behavior."
        ),
        .timeLimit(.minutes(8))
    )
    func recordsLiveBehaviorMatrix() async throws {
        let harness = try LiveCodexHarness(configMode: .approvalProbe)
        defer { harness.cleanup() }

        let readFixtureURL = harness.approvalProbeWorkspace
            .appendingPathComponent("behavior-matrix-read.txt", isDirectory: false)
        let readFixtureText = "behavior-matrix-\(UUID().uuidString)\n"
        try Data(readFixtureText.utf8).write(to: readFixtureURL)
        let expectedDigest = Data(SHA256.hash(data: Data(readFixtureText.utf8))).map {
            String(format: "%02x", $0)
        }.joined()

        let untrustedCreateURL = harness.approvalProbeWorkspace
            .appendingPathComponent("behavior-matrix-untrusted-create.txt", isDirectory: false)
        let granularCreateURL = harness.approvalProbeWorkspace
            .appendingPathComponent("behavior-matrix-granular-create.txt", isDirectory: false)

        let client = try await makeInitializedLiveClient(using: harness, experimentalAPI: true)
        do {
            let cases = [
                LiveBehaviorMatrixCase(
                    label: "never-text-only",
                    approvalPolicy: .never,
                    sandboxMode: .workspaceWrite,
                    prompt: prompt(label: "BEHAVIOR_MATRIX_NEVER_DONE"),
                    expectedFinalText: "BEHAVIOR_MATRIX_NEVER_DONE",
                    inspectedPath: nil
                ),
                LiveBehaviorMatrixCase(
                    label: "on-request-command-read",
                    approvalPolicy: .onRequest,
                    sandboxMode: .workspaceWrite,
                    prompt: """
                    Use a shell command to print the SHA-256 digest of behavior-matrix-read.txt in the
                    current working directory, then reply with exactly this text and nothing else:
                    \(expectedDigest)
                    """,
                    expectedFinalText: expectedDigest,
                    inspectedPath: readFixtureURL
                ),
                LiveBehaviorMatrixCase(
                    label: "untrusted-file-create",
                    approvalPolicy: .untrusted,
                    sandboxMode: .workspaceWrite,
                    prompt: """
                    Create behavior-matrix-untrusted-create.txt with exactly this content:
                    created by behavior matrix

                    Then reply with exactly BEHAVIOR_MATRIX_UNTRUSTED_CREATE_DONE and nothing else.
                    """,
                    expectedFinalText: "BEHAVIOR_MATRIX_UNTRUSTED_CREATE_DONE",
                    inspectedPath: untrustedCreateURL
                ),
                LiveBehaviorMatrixCase(
                    label: "granular-read-only-write-candidate",
                    approvalPolicy: .granular(
                        .init(
                            mcpElicitations: false,
                            requestPermissions: true,
                            rules: true,
                            sandboxApproval: true
                        )
                    ),
                    sandboxMode: .readOnly,
                    prompt: """
                    Create behavior-matrix-granular-create.txt with exactly this content:
                    created from read-only granular behavior matrix

                    Then reply with exactly BEHAVIOR_MATRIX_GRANULAR_CREATE_DONE and nothing else.
                    """,
                    expectedFinalText: "BEHAVIOR_MATRIX_GRANULAR_CREATE_DONE",
                    inspectedPath: granularCreateURL
                ),
            ]

            var caseResults: [LiveBehaviorMatrixReport.PolicySandboxResult] = []
            for matrixCase in cases {
                caseResults.append(
                    await runBehaviorMatrixCase(
                        matrixCase,
                        on: client,
                        harness: harness
                    )
                )
            }

            let history = await probeLiveHistoryMatrix(on: client, harness: harness)
            let sameThread = await probeLiveSameThreadMatrix(on: client, harness: harness)
            let diagnostics = await probeLiveCLIDiagnosticsMatrix(on: client)
            let report = LiveBehaviorMatrixReport(
                codexConfig: harness.codexConfigSummary,
                workspacePath: harness.approvalProbeWorkspace.path,
                policySandboxResults: caseResults,
                history: history,
                sameThread: sameThread,
                cliDiagnostics: diagnostics
            )
            try harness.writeReport(report, fileName: "live-behavior-matrix.json")

            #expect(caseResults.map(\.label) == cases.map(\.label))
            #expect(history.ephemeralRecentTurns != nil || history.errorDescription != nil)
            #expect(sameThread.outcome.isEmpty == false)
            #expect(diagnostics.versionString.isEmpty == false || diagnostics.errorDescription != nil)

            await client.stop()
        } catch {
            await client.stop()
            throw error
        }
    }

    @Test(
        "records live server-request family coverage status",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_SERVER_REQUEST_TESTS"] == "1",
            "Requires explicit opt-in because this test records live Codex server-request coverage status."
        )
    )
    func recordsLiveServerRequestFamilyCoverageStatus() throws {
        let harness = try LiveCodexHarness(configMode: .approvalProbe)
        defer { harness.cleanup() }

        let report = LiveServerRequestFamilyCoverageReport(
            codexConfig: harness.codexConfigSummary,
            families: [
                .init(
                    family: "commandExecutionApproval",
                    publicSurface: "CodexTurnHandle.respond(to:with:)",
                    deterministicFakeTransportCoverage: true,
                    liveProbeCoverage: true,
                    liveProbeScript: "scripts/run-live-codex-approval-probe.sh",
                    status: "covered",
                    notes: "The focused approval probe drives the real app-server with a mock Responses shell_command call and asserts request delivery, response, serverRequest/resolved, command completion, and terminal turn completion."
                ),
                .init(
                    family: "permissionsApproval",
                    publicSurface: "CodexTurnHandle.respond(to:with:)",
                    deterministicFakeTransportCoverage: true,
                    liveProbeCoverage: true,
                    liveProbeScript: "scripts/run-live-codex-approval-probe.sh",
                    status: "covered",
                    notes: "The focused approval probe drives the real app-server with request_permissions_tool enabled and asserts the permissions request, response, serverRequest/resolved, and terminal turn completion."
                ),
                .init(
                    family: "toolUserInput",
                    publicSurface: "CodexTurnHandle.respond(to:with:)",
                    deterministicFakeTransportCoverage: true,
                    liveProbeCoverage: true,
                    liveProbeScript: "scripts/run-live-codex-server-request-probes.sh",
                    status: "covered",
                    notes: "The focused server-request probe drives the real app-server with a mock Responses request_user_input call in plan collaboration mode and asserts request delivery, response, serverRequest/resolved, and terminal turn completion."
                ),
                .init(
                    family: "mcpServerElicitation",
                    publicSurface: "CodexThread.respond(to:with:) when turnId is null; CodexTurnHandle.respond(to:with:) when turn-routed",
                    deterministicFakeTransportCoverage: true,
                    liveProbeCoverage: true,
                    liveProbeScript: "scripts/run-live-codex-server-request-probes.sh",
                    status: "covered",
                    notes: "The focused server-request probe drives an app-connector MCP fixture through the real app-server and asserts MCP tool-call delivery, mcpServer/elicitation/request delivery, SwiftASB's JSON-RPC response, serverRequest/resolved, and terminal turn completion. The regular stdio fixture remains covered separately as model-to-MCP tool-path evidence, but app-connector MCP is the deterministic elicitation path."
                ),
            ],
            sourceNotes: [
                "OpenAI app-server docs describe item/tool/requestUserInput as a server-originated request that resolves with serverRequest/resolved.",
                "OpenAI app-server docs describe mcpServer/elicitation/request as an MCP-server-originated structured input request that resolves with serverRequest/resolved.",
            ]
        )

        try harness.writeReport(report, fileName: "live-server-request-family-coverage.json")
        #expect(report.families.count == 4)
        #expect(report.families.filter(\.liveProbeCoverage).map(\.family) == [
            "commandExecutionApproval",
            "permissionsApproval",
            "toolUserInput",
            "mcpServerElicitation",
        ])
    }

    @Test(
        "runs a multi-turn live file mutation scenario",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_FILE_SCENARIO_TESTS"] == "1",
            "Requires explicit opt-in because this test launches the local Codex CLI and asks it to mutate files."
        ),
        .timeLimit(.minutes(5))
    )
    func runsMultiTurnLiveFileMutationScenario() async throws {
        let harness = try LiveCodexHarness()
        defer { harness.cleanup() }

        let scratchURL = harness.fileScenarioWorkspace.appendingPathComponent("scratch.txt")
        let auditURL = harness.fileScenarioWorkspace.appendingPathComponent("audit.txt")

        let client = try await makeInitializedLiveClient(using: harness)
        do {
            let thread = try await startThread(
                on: client,
                workspacePath: harness.fileScenarioWorkspace.path,
                label: "file-mutation-scenario",
                approvalPolicy: .onRequest,
                approvalsReviewer: .user,
                ephemeral: false,
                developerInstructions: """
                You are running inside a SwiftASB live integration test.
                Make only the exact filesystem change requested by the user.
                Stay inside the current working directory.
                If approval is requested, wait for the test harness to answer it.
                Do not ask follow-up questions.
                After the requested filesystem change succeeds, reply with exactly FILE_SCENARIO_DONE and nothing else.
                """
            )

            let createTurn = try await startTurn(
                on: thread,
                prompt: """
                Create scratch.txt with exactly this content:
                alpha

                Then reply with exactly FILE_SCENARIO_DONE and nothing else.
                """,
                approvalPolicy: .onRequest,
                approvalsReviewer: .user
            )
            let createResult = try await completeLiveTurnAcceptingApprovals(
                createTurn,
                timeoutSeconds: 90,
                operation: "waiting for the live file scenario create turn to complete"
            )
            #expect(createResult.completion.turn.status == .completed)
            #expect(FileManager.default.fileExists(atPath: scratchURL.path))

            let recentFiles = try await thread.makeRecentFiles(limit: 10)
            let recentCommands = try await thread.makeRecentCommands(limit: 10)

            let editTurn = try await startTurn(
                on: thread,
                prompt: """
                Replace scratch.txt with exactly this content:
                alpha
                beta

                Then reply with exactly FILE_SCENARIO_DONE and nothing else.
                """,
                approvalPolicy: .onRequest,
                approvalsReviewer: .user
            )
            let editResult = try await completeLiveTurnAcceptingApprovals(
                editTurn,
                timeoutSeconds: 90,
                operation: "waiting for the live file scenario edit turn to complete"
            )
            #expect(editResult.completion.turn.status == .completed)
            #expect(FileManager.default.fileExists(atPath: scratchURL.path))

            let deleteTurn = try await startTurn(
                on: thread,
                prompt: """
                Delete scratch.txt.
                Create audit.txt with exactly this content:
                deleted scratch.txt

                Then reply with exactly FILE_SCENARIO_DONE and nothing else.
                """,
                approvalPolicy: .onRequest,
                approvalsReviewer: .user
            )
            let deleteResult = try await completeLiveTurnAcceptingApprovals(
                deleteTurn,
                timeoutSeconds: 90,
                operation: "waiting for the live file scenario delete turn to complete"
            )
            #expect(deleteResult.completion.turn.status == .completed)
            #expect(FileManager.default.fileExists(atPath: scratchURL.path) == false)
            #expect(try String(contentsOf: auditURL, encoding: .utf8) == "deleted scratch.txt\n")

            let observedCalls = createResult.callSnapshots + editResult.callSnapshots + deleteResult.callSnapshots
            #expect(observedCalls.contains { $0.kind == .fileEdit || $0.kind == .command })

            let fileSnapshots = await MainActor.run { recentFiles.files }
            let commandSnapshots = await MainActor.run { recentCommands.commands }
            #expect(fileSnapshots.isEmpty == false || commandSnapshots.isEmpty == false)

            let report = LiveFileMutationScenarioReport(
                threadID: thread.id,
                workspacePath: harness.fileScenarioWorkspace.path,
                turns: [
                    createResult.reportTurn(label: "create"),
                    editResult.reportTurn(label: "edit"),
                    deleteResult.reportTurn(label: "delete"),
                ],
                finalFiles: [
                    .init(
                        path: scratchURL.lastPathComponent,
                        exists: FileManager.default.fileExists(atPath: scratchURL.path),
                        contents: nil
                    ),
                    .init(
                        path: auditURL.lastPathComponent,
                        exists: FileManager.default.fileExists(atPath: auditURL.path),
                        contents: try String(contentsOf: auditURL, encoding: .utf8)
                    ),
                ],
                recentFiles: fileSnapshots.map(LiveFileMutationScenarioReport.RecentFile.init),
                recentCommands: commandSnapshots.map(LiveFileMutationScenarioReport.RecentCommand.init)
            )
            #expect(report.turns.allSatisfy { $0.status == "completed" })
            #expect(report.finalFiles.contains { $0.path == "scratch.txt" && $0.exists == false })
            #expect(report.finalFiles.contains { $0.path == "audit.txt" && $0.contents == "deleted scratch.txt\n" })
            try harness.writeReport(report, fileName: "live-file-mutation-scenario.json")

            await client.stop()
        } catch {
            await client.stop()
            throw error
        }
    }

    @Test(
        "probes live same-thread overlapping turn behavior",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_SAME_THREAD_TESTS"] == "1",
            "Requires explicit opt-in because this test launches the local Codex CLI."
        ),
        .timeLimit(.minutes(2))
    )
    func probesLiveSameThreadOverlappingTurnBehavior() async throws {
        let harness = try LiveCodexHarness()
        defer { harness.cleanup() }

        let client = try await makeInitializedLiveClient(using: harness)
        do {
            let sharedThread = try await startThread(
                on: client,
                workspacePath: harness.sameThreadWorkspace.path,
                label: "same-thread"
            )

            let firstSameThreadTurn = try await startTurn(
                on: sharedThread,
                prompt: prompt(label: "SAME_THREAD_FIRST_DONE")
            )

            let secondSameThreadOutcome = await startSecondSameThreadTurn(
                on: sharedThread,
                prompt: prompt(label: "SAME_THREAD_SECOND_DONE")
            )

            switch secondSameThreadOutcome {
            case .started:
                Issue.record(
                    """
                    SwiftASB should reject overlapping same-thread turns before they reach the live \
                    Codex app-server because the live same-thread lifecycle is not independently \
                    routable today.
                    """
                )
            case let .failed(errorDescription):
                #expect(
                    errorDescription.contains("overlapping same-thread turns")
                        || errorDescription.contains("another turn start in flight")
                        || errorDescription.contains("already has an active turn")
                )
                #expect(errorDescription.isEmpty == false)

                let firstCompletion = try await awaitCompletion(
                    of: firstSameThreadTurn,
                    timeoutSeconds: 45,
                    operation: "waiting for the first same-thread turn to complete after the second start was rejected"
                )
                #expect(firstCompletion.turn.status.isTerminal)
            }

            await client.stop()
        } catch {
            await client.stop()
            throw error
        }
    }
}
