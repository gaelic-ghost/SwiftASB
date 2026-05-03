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
                    liveProbeCoverage: false,
                    liveProbeScript: "scripts/run-live-codex-server-request-probes.sh",
                    status: "blocked",
                    notes: "The public fake-transport suite proves routing and response behavior. A regular stdio MCP fixture now proves the model-to-MCP tool path is deterministic, but this path does not deterministically surface mcpServer/elicitation/request through the app-server; the remaining live gap is an app-connector MCP elicitation fixture matching upstream Codex app-server coverage."
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

private final class LiveCodexHarness {
    let rootDirectoryURL: URL
    let codexHomeURL: URL
    let codexConfigSummary: LiveApprovalProbeReport.CodexConfig?
    let threadAWorkspace: URL
    let threadBWorkspace: URL
    let approvalProbeWorkspace: URL
    let fileScenarioWorkspace: URL
    let rollbackWorkspace: URL
    let sameThreadWorkspace: URL
    let codexExecutableURL: URL

    enum ConfigMode {
        case standard
        case approvalProbe
        case mockResponses(baseURL: String, requestPermissionsTool: Bool = false)
        case mockResponsesWithMcpElicitation(baseURL: String)
    }

    init(configMode: ConfigMode = .standard, fileManager: FileManager = .default) throws {
        let rootDirectoryURL = fileManager.temporaryDirectory
            .appendingPathComponent("SwiftASB-LiveCodex-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: rootDirectoryURL, withIntermediateDirectories: true)

        self.rootDirectoryURL = rootDirectoryURL
        self.codexHomeURL = rootDirectoryURL.appendingPathComponent(".codex", isDirectory: true)
        self.codexConfigSummary = Self.makeCodexConfigSummary(
            configMode: configMode,
            projectRootURL: rootDirectoryURL
        )
        self.threadAWorkspace = rootDirectoryURL.appendingPathComponent("thread-a", isDirectory: true)
        self.threadBWorkspace = rootDirectoryURL.appendingPathComponent("thread-b", isDirectory: true)
        self.approvalProbeWorkspace = rootDirectoryURL.appendingPathComponent("approval-probe", isDirectory: true)
        self.fileScenarioWorkspace = rootDirectoryURL.appendingPathComponent("file-scenario", isDirectory: true)
        self.rollbackWorkspace = rootDirectoryURL.appendingPathComponent("rollback", isDirectory: true)
        self.sameThreadWorkspace = rootDirectoryURL.appendingPathComponent("same-thread", isDirectory: true)
        self.codexExecutableURL = try Self.resolveCodexExecutableURL()

        try fileManager.createDirectory(at: codexHomeURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: threadAWorkspace, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: threadBWorkspace, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: approvalProbeWorkspace, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: fileScenarioWorkspace, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: rollbackWorkspace, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: sameThreadWorkspace, withIntermediateDirectories: true)
        let mcpElicitationServerScriptURL = rootDirectoryURL
            .appendingPathComponent("swiftasb_mcp_elicitation_server.py", isDirectory: false)
        if case .mockResponsesWithMcpElicitation = configMode {
            try Data(Self.mcpElicitationServerPythonScript.utf8).write(to: mcpElicitationServerScriptURL)
        }
        try Self.seedIsolatedCodexHome(
            at: codexHomeURL,
            configMode: configMode,
            projectRootURL: rootDirectoryURL,
            mcpElicitationServerScriptURL: mcpElicitationServerScriptURL,
            fileManager: fileManager
        )
    }

    var configuration: CodexAppServer.Configuration {
        .init(
            codexExecutableURL: codexExecutableURL,
            currentDirectoryURL: rootDirectoryURL,
            environment: Self.makeCodexEnvironment(codexHomeURL: codexHomeURL)
        )
    }

    func cleanup(fileManager: FileManager = .default) {
        if ProcessInfo.processInfo.environment["SWIFTASB_LIVE_CODEX_KEEP_WORKSPACES"] == "1" {
            return
        }
        try? fileManager.removeItem(at: rootDirectoryURL)
    }

    func writeReport<T: Encodable>(
        _ report: T,
        fileName: String,
        fileManager: FileManager = .default
    ) throws {
        guard let reportDirectoryPath = ProcessInfo.processInfo.environment["SWIFTASB_LIVE_CODEX_REPORT_DIR"],
              reportDirectoryPath.isEmpty == false else {
            return
        }

        let reportDirectoryURL = URL(fileURLWithPath: reportDirectoryPath, isDirectory: true)
        try fileManager.createDirectory(at: reportDirectoryURL, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let reportData = try encoder.encode(report)
        try reportData.write(to: reportDirectoryURL.appendingPathComponent(fileName))
    }

    private static func resolveCodexExecutableURL() throws -> URL {
        if let overridePath = ProcessInfo.processInfo.environment["SWIFTASB_LIVE_CODEX_BIN"],
           overridePath.isEmpty == false {
            return URL(fileURLWithPath: overridePath)
        }

        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "command -v codex"]
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()
        process.waitUntilExit()

        let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let errorData = standardError.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let errorText = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw LiveIntegrationError.executableResolutionFailed(
                reason: errorText.isEmpty ? "zsh could not locate a `codex` executable on PATH." : errorText
            )
        }

        let outputText = String(decoding: outputData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard outputText.isEmpty == false else {
            throw LiveIntegrationError.executableResolutionFailed(
                reason: "`command -v codex` returned an empty result."
            )
        }

        return URL(fileURLWithPath: outputText)
    }

    private static func makeCodexEnvironment(codexHomeURL: URL) -> [String: String] {
        let environment = ProcessInfo.processInfo.environment
        let allowedKeys = [
            "HOME",
            "LANG",
            "LC_ALL",
            "LOGNAME",
            "PATH",
            "SHELL",
            "TERM",
            "TMPDIR",
            "USER",
        ]

        var isolatedEnvironment = environment.reduce(into: [String: String]()) { partialResult, entry in
            guard allowedKeys.contains(entry.key) else {
                return
            }
            partialResult[entry.key] = entry.value
        }

        isolatedEnvironment["CODEX_HOME"] = codexHomeURL.path
        return isolatedEnvironment
    }

    private static func seedIsolatedCodexHome(
        at codexHomeURL: URL,
        configMode: ConfigMode,
        projectRootURL: URL,
        mcpElicitationServerScriptURL: URL,
        fileManager: FileManager
    ) throws {
        let sourceCodexHomeURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
        let sourceAuthURL = sourceCodexHomeURL.appendingPathComponent("auth.json")
        let destinationAuthURL = codexHomeURL.appendingPathComponent("auth.json")

        if fileManager.fileExists(atPath: sourceAuthURL.path) {
            try fileManager.copyItem(at: sourceAuthURL, to: destinationAuthURL)
        }

        let configURL = codexHomeURL.appendingPathComponent("config.toml")
        let isolatedConfig: String
        switch configMode {
        case .standard:
            isolatedConfig = """
            model = "gpt-5.4"

            [features]
            apps = false

            [apps._default]
            enabled = false
            """
        case .approvalProbe:
            isolatedConfig = """
            model = "gpt-5.4"
            approval_policy = "untrusted"
            approvals_reviewer = "user"
            sandbox_mode = "workspace-write"

            [auto_review]
            policy = ""

            [features]
            apps = false

            [apps._default]
            enabled = false

            [projects.\(tomlQuotedString(projectRootURL.path))]
            trust_level = "untrusted"
            """
        case let .mockResponses(baseURL, requestPermissionsTool):
            isolatedConfig = """
            model = "mock-model"
            approval_policy = "untrusted"
            approvals_reviewer = "user"
            sandbox_mode = "read-only"
            model_provider = "mock_provider"
            suppress_unstable_features_warning = true

            [features]
            apps = false
            exec_permission_approvals = true
            request_permissions_tool = \(requestPermissionsTool)

            [apps._default]
            enabled = false

            [model_providers.mock_provider]
            name = "SwiftASB Mock Responses Provider"
            base_url = "\(baseURL)/v1"
            wire_api = "responses"
            request_max_retries = 0
            stream_max_retries = 0
            supports_websockets = false

            [projects.\(tomlQuotedString(projectRootURL.path))]
            trust_level = "untrusted"
            """
        case let .mockResponsesWithMcpElicitation(baseURL):
            isolatedConfig = """
            model = "mock-model"
            approval_policy = "untrusted"
            approvals_reviewer = "user"
            sandbox_mode = "read-only"
            model_provider = "mock_provider"
            suppress_unstable_features_warning = true

            [features]
            apps = false
            exec_permission_approvals = true

            [apps._default]
            enabled = false

            [model_providers.mock_provider]
            name = "SwiftASB Mock Responses Provider"
            base_url = "\(baseURL)/v1"
            wire_api = "responses"
            request_max_retries = 0
            stream_max_retries = 0
            supports_websockets = false

            [mcp_servers.swiftasb_elicitation]
            command = "/usr/bin/env"
            args = ["python3", "\(tomlEscapedString(mcpElicitationServerScriptURL.path))"]
            startup_timeout_sec = 5
            enabled = true

            [mcp_servers.swiftasb_elicitation.tools.ask]
            approval_mode = "approve"

            [projects.\(tomlQuotedString(projectRootURL.path))]
            trust_level = "trusted"
            """
        }
        try Data(isolatedConfig.utf8).write(to: configURL)
    }

    private static func makeCodexConfigSummary(
        configMode: ConfigMode,
        projectRootURL: URL
    ) -> LiveApprovalProbeReport.CodexConfig? {
        switch configMode {
        case .standard, .mockResponses, .mockResponsesWithMcpElicitation:
            nil
        case .approvalProbe:
            .init(
                approvalPolicy: "untrusted",
                approvalsReviewer: "user",
                autoReviewPolicy: "",
                projectTrustLevel: "untrusted",
                sandboxMode: "workspace-write"
            )
        }
    }

    private static func tomlQuotedString(_ value: String) -> String {
        let escapedValue = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escapedValue)\""
    }

    private static func tomlEscapedString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static let mcpElicitationServerPythonScript = """
    import json
    import sys

    def send(message):
        sys.stdout.write(json.dumps(message, separators=(",", ":")) + "\\n")
        sys.stdout.flush()

    def success(request_id, result):
        send({"jsonrpc": "2.0", "id": request_id, "result": result})

    def error(request_id, code, message):
        send({"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}})

    for line in sys.stdin:
        if not line.strip():
            continue
        request = json.loads(line)
        request_id = request.get("id")
        method = request.get("method")

        if method == "initialize":
            params = request.get("params", {})
            success(request_id, {
                "protocolVersion": params.get("protocolVersion", "2025-06-18"),
                "capabilities": {
                    "tools": {},
                    "elicitation": {}
                },
                "serverInfo": {
                    "name": "swiftasb-elicitation",
                    "version": "0.1.0"
                }
            })
        elif method == "notifications/initialized":
            continue
        elif method == "tools/list":
            success(request_id, {
                "tools": [{
                    "name": "ask",
                    "description": "Ask for deterministic SwiftASB MCP elicitation input.",
                    "inputSchema": {
                        "type": "object",
                        "properties": {},
                        "additionalProperties": False
                    }
                }]
            })
        elif method == "tools/call":
            elicitation_id = "swiftasb-elicitation-request"
            send({
                "jsonrpc": "2.0",
                "id": elicitation_id,
                "method": "elicitation/create",
                "params": {
                    "message": "Confirm deterministic SwiftASB MCP elicitation.",
                    "requestedSchema": {
                        "type": "object",
                        "properties": {
                            "confirmed": {
                                "type": "boolean",
                                "title": "Confirmed"
                            }
                        },
                        "required": ["confirmed"]
                    }
                }
            })
            while True:
                response_line = sys.stdin.readline()
                if not response_line:
                    sys.exit(0)
                response = json.loads(response_line)
                if response.get("id") == elicitation_id:
                    break
            success(request_id, {
                "content": [{
                    "type": "text",
                    "text": "MCP elicitation completed."
                }]
            })
        elif request_id is not None:
            error(request_id, -32601, f"Unsupported method: {method}")
    """
}

private enum LiveApprovalPathOutcome {
    case approvalRequested(CodexApprovalRequest)
    case completedWithoutApproval(CodexAppServer.TurnStatus, String?)
}

private enum LiveTurnStartOutcome {
    case started(CodexTurnHandle)
    case failed(String)
}

private struct LiveScenarioTurnResult {
    let completion: CodexTurnCompletion
    let acceptedApprovalKinds: [String]
    let callSnapshots: [CodexTurnHandle.Minimap.CallSnapshot]
    let latestCompletedItemText: String?

    func reportTurn(label: String) -> LiveFileMutationScenarioReport.Turn {
        LiveFileMutationScenarioReport.Turn(
            label: label,
            id: completion.turn.id,
            status: completion.turn.status.rawValue,
            acceptedApprovalKinds: acceptedApprovalKinds,
            callKinds: callSnapshots.map(\.kind.rawValue),
            callDisplayNames: callSnapshots.map(\.displayName)
        )
    }
}

private struct LiveApprovalProbeCase {
    let label: String
    let prompt: String
    let expectedFinalText: String
    let inspectedPath: URL
}

private struct LiveBehaviorMatrixCase {
    let label: String
    let approvalPolicy: CodexAppServer.ApprovalPolicy
    let sandboxMode: CodexAppServer.SandboxMode
    let prompt: String
    let expectedFinalText: String
    let inspectedPath: URL?
}

private struct LiveApprovalProbeReport: Codable, Equatable {
    struct CodexConfig: Codable, Equatable {
        let approvalPolicy: String
        let approvalsReviewer: String
        let autoReviewPolicy: String
        let projectTrustLevel: String
        let sandboxMode: String
    }

    struct Result: Codable, Equatable {
        let label: String
        let threadID: String
        let turnID: String
        let status: String
        let acceptedApprovalKinds: [String]
        let callKinds: [String]
        let callDisplayNames: [String]
        let latestCompletedItemText: String?
        let inspectedFile: InspectedFile
        let errorDescription: String?

        init(
            _ probeCase: LiveApprovalProbeCase,
            thread: CodexThread,
            result: LiveScenarioTurnResult
        ) {
            self.label = probeCase.label
            self.threadID = thread.id
            self.turnID = result.completion.turn.id
            self.status = result.completion.turn.status.rawValue
            self.acceptedApprovalKinds = result.acceptedApprovalKinds
            self.callKinds = result.callSnapshots.map(\.kind.rawValue)
            self.callDisplayNames = result.callSnapshots.map(\.displayName)
            self.latestCompletedItemText = result.latestCompletedItemText
            self.inspectedFile = .init(url: probeCase.inspectedPath)
            self.errorDescription = nil
        }

        init(
            _ probeCase: LiveApprovalProbeCase,
            thread: CodexThread,
            turnID: String,
            status: String,
            callSnapshots: [CodexTurnHandle.Minimap.CallSnapshot],
            latestCompletedItemText: String?,
            error: Error
        ) {
            self.label = probeCase.label
            self.threadID = thread.id
            self.turnID = turnID
            self.status = status
            self.acceptedApprovalKinds = []
            self.callKinds = callSnapshots.map(\.kind.rawValue)
            self.callDisplayNames = callSnapshots.map(\.displayName)
            self.latestCompletedItemText = latestCompletedItemText
            self.inspectedFile = .init(url: probeCase.inspectedPath)
            self.errorDescription = String(describing: error)
        }

        init(_ probeCase: LiveApprovalProbeCase, error: Error) {
            self.label = probeCase.label
            self.threadID = ""
            self.turnID = ""
            self.status = "failed"
            self.acceptedApprovalKinds = []
            self.callKinds = []
            self.callDisplayNames = []
            self.latestCompletedItemText = nil
            self.inspectedFile = .init(url: probeCase.inspectedPath)
            self.errorDescription = String(describing: error)
        }
    }

    struct InspectedFile: Codable, Equatable {
        let path: String
        let exists: Bool
        let contents: String?

        init(url: URL) {
            self.path = url.lastPathComponent
            self.exists = FileManager.default.fileExists(atPath: url.path)
            self.contents = try? String(contentsOf: url, encoding: .utf8)
        }
    }

    let threadID: String
    let readOnlyThreadID: String
    let codexConfig: CodexConfig?
    let workspacePath: String
    let results: [Result]
}

private struct LiveBehaviorMatrixReport: Codable, Equatable {
    struct PolicySandboxResult: Codable, Equatable {
        let label: String
        let approvalPolicy: String
        let sandboxMode: String
        let threadID: String
        let turnID: String
        let status: String
        let acceptedApprovalKinds: [String]
        let callKinds: [String]
        let callDisplayNames: [String]
        let latestCompletedItemText: String?
        let inspectedFile: LiveApprovalProbeReport.InspectedFile?
        let matchedExpectedFinalText: Bool
        let errorDescription: String?
    }

    struct HistoryResult: Codable, Equatable {
        let ephemeralThreadID: String?
        let ephemeralRecentTurns: Int?
        let storedThreadID: String?
        let storedRecentTurnsBeforeMaterialization: Int?
        let errorDescription: String?
    }

    struct SameThreadResult: Codable, Equatable {
        let threadID: String
        let firstTurnID: String
        let outcome: String
        let errorDescription: String?
        let firstTurnStatus: String?
    }

    struct CLIDiagnosticsResult: Codable, Equatable {
        let resolvedExecutablePath: String?
        let versionString: String
        let compatibility: String
        let errorDescription: String?
    }

    let codexConfig: LiveApprovalProbeReport.CodexConfig?
    let workspacePath: String
    let policySandboxResults: [PolicySandboxResult]
    let history: HistoryResult
    let sameThread: SameThreadResult
    let cliDiagnostics: CLIDiagnosticsResult
}

private struct LiveServerRequestFamilyCoverageReport: Codable, Equatable {
    struct Family: Codable, Equatable {
        let family: String
        let publicSurface: String
        let deterministicFakeTransportCoverage: Bool
        let liveProbeCoverage: Bool
        let liveProbeScript: String?
        let status: String
        let notes: String
    }

    let codexConfig: LiveApprovalProbeReport.CodexConfig?
    let families: [Family]
    let sourceNotes: [String]
}

private struct LiveFileMutationScenarioReport: Codable, Equatable {
    struct Turn: Codable, Equatable {
        let label: String
        let id: String
        let status: String
        let acceptedApprovalKinds: [String]
        let callKinds: [String]
        let callDisplayNames: [String]
    }

    struct FinalFile: Codable, Equatable {
        let path: String
        let exists: Bool
        let contents: String?
    }

    struct RecentFile: Codable, Equatable {
        let path: String?
        let status: String
        let latestStatusText: String?

        init(_ snapshot: CodexThread.RecentFiles.FileSnapshot) {
            self.path = snapshot.path
            self.status = snapshot.status.rawValue
            self.latestStatusText = snapshot.latestStatusText
        }
    }

    struct RecentCommand: Codable, Equatable {
        let command: String?
        let status: String
        let latestStatusText: String?

        init(_ snapshot: CodexThread.RecentCommands.CommandSnapshot) {
            self.command = snapshot.command
            self.status = snapshot.status.rawValue
            self.latestStatusText = snapshot.latestStatusText
        }
    }

    let threadID: String
    let workspacePath: String
    let turns: [Turn]
    let finalFiles: [FinalFile]
    let recentFiles: [RecentFile]
    let recentCommands: [RecentCommand]
}

private final class MockResponsesServer: @unchecked Sendable {
    private let process: Process
    private let rootDirectoryURL: URL
    private let requestCountFileURL: URL

    let baseURL: URL

    var requestCount: Int {
        guard let text = try? String(contentsOf: requestCountFileURL, encoding: .utf8) else {
            return 0
        }
        return Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    init(responses: [MockResponsesEventStream]) async throws {
        let fileManager = FileManager.default
        self.rootDirectoryURL = fileManager.temporaryDirectory
            .appendingPathComponent("SwiftASB-MockResponses-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: rootDirectoryURL, withIntermediateDirectories: true)

        let responsesFileURL = rootDirectoryURL.appendingPathComponent("responses.json")
        self.requestCountFileURL = rootDirectoryURL.appendingPathComponent("request-count.txt")
        let portFileURL = rootDirectoryURL.appendingPathComponent("port.txt")
        let scriptURL = rootDirectoryURL.appendingPathComponent("mock_responses_server.py")

        let responseData = try JSONEncoder().encode(responses.map(\.body))
        try responseData.write(to: responsesFileURL)
        try Data("0\n".utf8).write(to: requestCountFileURL)
        try Data(Self.pythonScript.utf8).write(to: scriptURL)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "python3",
            scriptURL.path,
            responsesFileURL.path,
            portFileURL.path,
            requestCountFileURL.path,
        ]
        self.process = process
        try process.run()

        let port = try await Self.waitForPortFile(portFileURL)
        self.baseURL = URL(string: "http://127.0.0.1:\(port)")!
    }

    func stop() {
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }
        try? FileManager.default.removeItem(at: rootDirectoryURL)
    }

    private static func waitForPortFile(_ portFileURL: URL) async throws -> Int {
        let deadline = ContinuousClock.now + .seconds(5)
        while ContinuousClock.now < deadline {
            if let text = try? String(contentsOf: portFileURL, encoding: .utf8),
               let port = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return port
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        throw LiveIntegrationError.timedOut(
            operation: "waiting for the local mock Responses server to report its port",
            seconds: 5
        )
    }

    private static let pythonScript = """
    import json
    import sys
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

    responses_path, port_path, count_path = sys.argv[1:4]
    with open(responses_path, "r", encoding="utf-8") as handle:
        responses = json.load(handle)

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, format, *args):
            return

        def do_GET(self):
            body = json.dumps({"models": []}).encode("utf-8")
            self.send_response(200)
            self.send_header("content-type", "application/json")
            self.send_header("content-length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_POST(self):
            length = int(self.headers.get("content-length", "0"))
            if length:
                self.rfile.read(length)

            try:
                with open(count_path, "r", encoding="utf-8") as handle:
                    count = int(handle.read().strip() or "0")
            except FileNotFoundError:
                count = 0
            with open(count_path, "w", encoding="utf-8") as handle:
                handle.write(f"{count + 1}\\n")

            if responses:
                body = responses.pop(0).encode("utf-8")
            else:
                body = (
                    "event: response.created\\n"
                    "data: {\\\"type\\\":\\\"response.created\\\",\\\"response\\\":{\\\"id\\\":\\\"fallback\\\"}}\\n\\n"
                    "event: response.completed\\n"
                    "data: {\\\"type\\\":\\\"response.completed\\\",\\\"response\\\":{\\\"id\\\":\\\"fallback\\\",\\\"usage\\\":{\\\"input_tokens\\\":0,\\\"input_tokens_details\\\":null,\\\"output_tokens\\\":0,\\\"output_tokens_details\\\":null,\\\"total_tokens\\\":0}}}\\n\\n"
                ).encode("utf-8")

            self.send_response(200)
            self.send_header("content-type", "text/event-stream")
            self.send_header("cache-control", "no-cache")
            self.send_header("content-length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    with open(port_path, "w", encoding="utf-8") as handle:
        handle.write(f"{server.server_address[1]}\\n")
    server.serve_forever()
    """
}

private struct MockResponsesEventStream: Encodable, Equatable {
    let body: String

    static func shellCommand(callID: String, command: String) throws -> Self {
        let arguments = try jsonString([
            "command": command,
            "workdir": Optional<String>.none,
            "timeout_ms": 5_000,
        ] as [String: Any?])
        return try .init(events: [
            responseCreated(id: "resp-shell"),
            functionCall(callID: callID, name: "shell_command", arguments: arguments),
            responseCompleted(id: "resp-shell"),
        ])
    }

    static func requestPermissions(
        callID: String,
        reason: String,
        writePaths: [String]
    ) throws -> Self {
        let arguments = try jsonString([
            "reason": reason,
            "permissions": [
                "file_system": [
                    "write": writePaths,
                ],
            ],
        ])
        return try .init(events: [
            responseCreated(id: "resp-permissions"),
            functionCall(callID: callID, name: "request_permissions", arguments: arguments),
            responseCompleted(id: "resp-permissions"),
        ])
    }

    static func requestUserInput(callID: String) throws -> Self {
        let arguments = try jsonString([
            "questions": [
                [
                    "header": "Direction",
                    "id": "direction",
                    "question": "Which deterministic path should the live test choose?",
                    "options": [
                        [
                            "label": "Continue (Recommended)",
                            "description": "Complete the deterministic server-request probe.",
                        ],
                        [
                            "label": "Stop",
                            "description": "Stop before completing the deterministic probe.",
                        ],
                    ],
                ],
            ],
        ])
        return try .init(events: [
            responseCreated(id: "resp-tool-input"),
            functionCall(callID: callID, name: "request_user_input", arguments: arguments),
            responseCompleted(id: "resp-tool-input"),
        ])
    }

    static func mcpElicitationToolCall(callID: String) throws -> Self {
        try .init(events: [
            responseCreated(id: "resp-mcp-elicitation"),
            functionCall(
                callID: callID,
                name: "ask",
                namespace: "mcp__swiftasb_elicitation__",
                arguments: "{}"
            ),
            responseCompleted(id: "resp-mcp-elicitation"),
        ])
    }

    static func assistantMessage(_ message: String) throws -> Self {
        try .init(events: [
            responseCreated(id: "resp-final"),
            [
                "type": "response.output_item.done",
                "item": [
                    "type": "message",
                    "role": "assistant",
                    "id": "msg-final",
                    "content": [
                        [
                            "type": "output_text",
                            "text": message,
                        ],
                    ],
                ],
            ],
            responseCompleted(id: "resp-final"),
        ])
    }

    private init(events: [[String: Any]]) throws {
        var body = ""
        for event in events {
            guard let eventType = event["type"] as? String else {
                continue
            }
            body += "event: \(eventType)\n"
            let data = try JSONSerialization.data(withJSONObject: event, options: [.sortedKeys])
            body += "data: \(String(decoding: data, as: UTF8.self))\n\n"
        }
        self.body = body
    }

    private static func responseCreated(id: String) -> [String: Any] {
        [
            "type": "response.created",
            "response": [
                "id": id,
            ],
        ]
    }

    private static func responseCompleted(id: String) -> [String: Any] {
        [
            "type": "response.completed",
            "response": [
                "id": id,
                "usage": [
                    "input_tokens": 0,
                    "input_tokens_details": NSNull(),
                    "output_tokens": 0,
                    "output_tokens_details": NSNull(),
                    "total_tokens": 0,
                ],
            ],
        ]
    }

    private static func functionCall(
        callID: String,
        name: String,
        namespace: String? = nil,
        arguments: String
    ) -> [String: Any] {
        var item: [String: Any] = [
            "type": "function_call",
            "call_id": callID,
            "name": name,
            "arguments": arguments,
        ]
        if let namespace {
            item["namespace"] = namespace
        }

        return [
            "type": "response.output_item.done",
            "item": item,
        ]
    }

    private static func jsonString(_ object: [String: Any?]) throws -> String {
        let normalized = object.reduce(into: [String: Any]()) { partialResult, entry in
            partialResult[entry.key] = entry.value ?? NSNull()
        }
        let data = try JSONSerialization.data(withJSONObject: normalized, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }
}

private enum LiveIntegrationError: Error, LocalizedError {
    case timedOut(operation: String, seconds: Double)
    case eventStreamEnded(operation: String)
    case executableResolutionFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case let .timedOut(operation, seconds):
            return "The live Codex integration test timed out after \(seconds) seconds while \(operation)."
        case let .eventStreamEnded(operation):
            return "The live Codex integration test lost the expected event stream while \(operation)."
        case let .executableResolutionFailed(reason):
            return "The live Codex integration test could not resolve the local `codex` executable: \(reason)"
        }
    }
}

private func startThread(
    on client: CodexAppServer,
    workspacePath: String,
    label: String,
    approvalPolicy: CodexAppServer.ApprovalPolicy = .never,
    approvalsReviewer: CodexAppServer.ApprovalsReviewer? = nil,
    ephemeral: Bool = true,
    sandboxMode: CodexAppServer.SandboxMode = .workspaceWrite,
    developerInstructions: String = """
    You are running inside a SwiftASB live integration test.
    Do not call tools.
    Do not edit files.
    Do not ask follow-up questions.
    Reply only with the exact text requested by the user message.
    """
) async throws -> CodexThread {
    return try await withTimeout(seconds: 15, operation: "starting the \(label) thread") {
        try await client.startThread(
            .init(
                approvalPolicy: approvalPolicy,
                approvalsReviewer: approvalsReviewer,
                currentDirectoryPath: workspacePath,
                developerInstructions: developerInstructions,
                ephemeral: ephemeral,
                sandboxMode: sandboxMode
            )
        )
    }
}

private func startTurn(
    on thread: CodexThread,
    prompt: String,
    approvalPolicy: CodexAppServer.ApprovalPolicy = .never,
    approvalsReviewer: CodexAppServer.ApprovalsReviewer? = nil
) async throws -> CodexTurnHandle {
    return try await withTimeout(seconds: 20, operation: "starting a live turn on thread \(thread.id)") {
        try await thread.startTextTurn(
            prompt,
            approvalPolicy: approvalPolicy,
            approvalsReviewer: approvalsReviewer,
            summary: CodexAppServer.ReasoningSummary.none
        )
    }
}

private func startSecondSameThreadTurn(
    on thread: CodexThread,
    prompt: String
) async -> LiveTurnStartOutcome {
    do {
        let turnHandle = try await startTurn(on: thread, prompt: prompt)
        return .started(turnHandle)
    } catch {
        return .failed(String(describing: error))
    }
}

private func runApprovalProbeCaseReport(
    _ probeCase: LiveApprovalProbeCase,
    on thread: CodexThread
) async throws -> LiveApprovalProbeReport.Result {
    let turn: CodexTurnHandle
    do {
        turn = try await startTurn(
            on: thread,
            prompt: probeCase.prompt,
            approvalPolicy: .untrusted,
            approvalsReviewer: .user
        )
    } catch {
        return .init(
            probeCase,
            thread: thread,
            turnID: "",
            status: "failed",
            callSnapshots: [],
            latestCompletedItemText: nil,
            error: error
        )
    }

    let minimap = await turn.minimap
    do {
        let result = try await completeLiveTurnAcceptingApprovals(
            turn,
            timeoutSeconds: 90,
            operation: "waiting for the \(probeCase.label) approval probe to complete"
        )
        return .init(probeCase, thread: thread, result: result)
    } catch {
        let snapshots = await MainActor.run(body: { minimap.callSnapshots })
        let completedText = await MainActor.run(body: { minimap.latestCompletedItem?.item.text })
        let status = await MainActor.run(body: { minimap.latestCompletion?.turn.status.rawValue })
        return .init(
            probeCase,
            thread: thread,
            turnID: turn.turn.id,
            status: status ?? "failed",
            callSnapshots: snapshots,
            latestCompletedItemText: completedText,
            error: error
        )
    }
}

private func runBehaviorMatrixCase(
    _ matrixCase: LiveBehaviorMatrixCase,
    on client: CodexAppServer,
    harness: LiveCodexHarness
) async -> LiveBehaviorMatrixReport.PolicySandboxResult {
    do {
        let thread = try await startThread(
            on: client,
            workspacePath: harness.approvalProbeWorkspace.path,
            label: "behavior-matrix-\(matrixCase.label)",
            approvalPolicy: matrixCase.approvalPolicy,
            approvalsReviewer: matrixCase.approvalPolicy.requiresUserReviewer ? .user : nil,
            ephemeral: false,
            sandboxMode: matrixCase.sandboxMode,
            developerInstructions: """
            You are running inside a SwiftASB live behavior-matrix probe.
            Perform only the exact requested action.
            If approval is requested, wait for the test harness to answer it.
            Do not ask follow-up questions.
            Reply only with the exact text requested by the user message.
            """
        )
        let turn = try await startTurn(
            on: thread,
            prompt: matrixCase.prompt,
            approvalPolicy: matrixCase.approvalPolicy,
            approvalsReviewer: matrixCase.approvalPolicy.requiresUserReviewer ? .user : nil
        )
        let result = try await completeLiveTurnAcceptingApprovals(
            turn,
            timeoutSeconds: 90,
            operation: "waiting for the \(matrixCase.label) behavior-matrix case to complete"
        )
        return .init(
            label: matrixCase.label,
            approvalPolicy: matrixCase.approvalPolicy.reportLabel,
            sandboxMode: matrixCase.sandboxMode.rawValue,
            threadID: thread.id,
            turnID: result.completion.turn.id,
            status: result.completion.turn.status.rawValue,
            acceptedApprovalKinds: result.acceptedApprovalKinds,
            callKinds: result.callSnapshots.map(\.kind.rawValue),
            callDisplayNames: result.callSnapshots.map(\.displayName),
            latestCompletedItemText: result.latestCompletedItemText,
            inspectedFile: matrixCase.inspectedPath.map(LiveApprovalProbeReport.InspectedFile.init),
            matchedExpectedFinalText: result.latestCompletedItemText == matrixCase.expectedFinalText,
            errorDescription: nil
        )
    } catch {
        return .init(
            label: matrixCase.label,
            approvalPolicy: matrixCase.approvalPolicy.reportLabel,
            sandboxMode: matrixCase.sandboxMode.rawValue,
            threadID: "",
            turnID: "",
            status: "failed",
            acceptedApprovalKinds: [],
            callKinds: [],
            callDisplayNames: [],
            latestCompletedItemText: nil,
            inspectedFile: matrixCase.inspectedPath.map(LiveApprovalProbeReport.InspectedFile.init),
            matchedExpectedFinalText: false,
            errorDescription: String(describing: error)
        )
    }
}

private func probeLiveHistoryMatrix(
    on client: CodexAppServer,
    harness: LiveCodexHarness
) async -> LiveBehaviorMatrixReport.HistoryResult {
    do {
        let ephemeralThread = try await startThread(
            on: client,
            workspacePath: harness.threadAWorkspace.path,
            label: "behavior-matrix-ephemeral-history",
            ephemeral: true
        )
        let ephemeralRecentTurns = try await ephemeralThread.makeRecentTurns(limit: 5)
        let ephemeralCount = await MainActor.run { ephemeralRecentTurns.turns.count }

        let storedThread = try await startThread(
            on: client,
            workspacePath: harness.threadBWorkspace.path,
            label: "behavior-matrix-stored-history",
            ephemeral: false
        )
        let storedRecentTurns = try await storedThread.makeRecentTurns(limit: 5)
        let storedCount = await MainActor.run { storedRecentTurns.turns.count }

        return .init(
            ephemeralThreadID: ephemeralThread.id,
            ephemeralRecentTurns: ephemeralCount,
            storedThreadID: storedThread.id,
            storedRecentTurnsBeforeMaterialization: storedCount,
            errorDescription: nil
        )
    } catch {
        return .init(
            ephemeralThreadID: nil,
            ephemeralRecentTurns: nil,
            storedThreadID: nil,
            storedRecentTurnsBeforeMaterialization: nil,
            errorDescription: String(describing: error)
        )
    }
}

private func probeLiveSameThreadMatrix(
    on client: CodexAppServer,
    harness: LiveCodexHarness
) async -> LiveBehaviorMatrixReport.SameThreadResult {
    do {
        let thread = try await startThread(
            on: client,
            workspacePath: harness.sameThreadWorkspace.path,
            label: "behavior-matrix-same-thread"
        )
        let firstTurn = try await startTurn(
            on: thread,
            prompt: prompt(label: "BEHAVIOR_MATRIX_SAME_THREAD_FIRST_DONE")
        )
        let outcome = await startSecondSameThreadTurn(
            on: thread,
            prompt: prompt(label: "BEHAVIOR_MATRIX_SAME_THREAD_SECOND_DONE")
        )

        switch outcome {
        case let .failed(errorDescription):
            let completion = try? await awaitCompletion(
                of: firstTurn,
                timeoutSeconds: 45,
                operation: "waiting for the first behavior-matrix same-thread turn to complete"
            )
            return .init(
                threadID: thread.id,
                firstTurnID: firstTurn.turn.id,
                outcome: "rejected",
                errorDescription: errorDescription,
                firstTurnStatus: completion?.turn.status.rawValue
            )
        case .started:
            return .init(
                threadID: thread.id,
                firstTurnID: firstTurn.turn.id,
                outcome: "unexpectedly-started",
                errorDescription: nil,
                firstTurnStatus: nil
            )
        }
    } catch {
        return .init(
            threadID: "",
            firstTurnID: "",
            outcome: "failed",
            errorDescription: String(describing: error),
            firstTurnStatus: nil
        )
    }
}

private func probeLiveCLIDiagnosticsMatrix(
    on client: CodexAppServer
) async -> LiveBehaviorMatrixReport.CLIDiagnosticsResult {
    do {
        let diagnostics = try await client.cliExecutableDiagnostics()
        return .init(
            resolvedExecutablePath: diagnostics.resolvedExecutablePath,
            versionString: diagnostics.versionString,
            compatibility: String(describing: diagnostics.compatibility),
            errorDescription: nil
        )
    } catch {
        return .init(
            resolvedExecutablePath: nil,
            versionString: "",
            compatibility: "",
            errorDescription: String(describing: error)
        )
    }
}

private func startApprovalProbeThread(
    on client: CodexAppServer,
    harness: LiveCodexHarness,
    label: String,
    sandboxMode: CodexAppServer.SandboxMode
) async throws -> CodexThread {
    try await startThread(
        on: client,
        workspacePath: harness.approvalProbeWorkspace.path,
        label: label,
        approvalPolicy: .untrusted,
        approvalsReviewer: .user,
        ephemeral: false,
        sandboxMode: sandboxMode,
        developerInstructions: """
        You are running inside a SwiftASB live integration test.
        Perform only the exact requested action.
        If approval is requested, wait for the test harness to answer it.
        Do not ask follow-up questions.
        Reply only with the exact text requested by the user message.
        """
    )
}

private func awaitCompletion(
    of turnHandle: CodexTurnHandle,
    timeoutSeconds: Double,
    operation: String
) async throws -> CodexTurnCompletion {
    try await withTimeout(seconds: timeoutSeconds, operation: operation) {
        for try await event in turnHandle.events {
            if case let .completed(completion) = event {
                return completion
            }
        }

        throw LiveIntegrationError.eventStreamEnded(operation: operation)
    }
}

private func awaitApprovalPathOutcome(
    in minimap: CodexTurnHandle.Minimap,
    timeoutSeconds: Double,
    operation: String
) async throws -> LiveApprovalPathOutcome {
    let deadline = ContinuousClock.now + .seconds(timeoutSeconds)
    while ContinuousClock.now < deadline {
        if let request = await MainActor.run(body: { minimap.latestApprovalRequest }) {
            return .approvalRequested(request)
        }
        if let completion = await MainActor.run(body: { minimap.latestCompletion }) {
            let completedItem = await MainActor.run(body: { minimap.latestCompletedItem?.item.text })
            return .completedWithoutApproval(completion.turn.status, completedItem)
        }
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    throw LiveIntegrationError.timedOut(operation: operation, seconds: timeoutSeconds)
}

private func awaitRequestResolution(
    in minimap: CodexTurnHandle.Minimap,
    expectedKind: CodexInteractiveRequestKind,
    timeoutSeconds: Double,
    operation: String
) async throws -> CodexInteractiveRequestResolved {
    let deadline = ContinuousClock.now + .seconds(timeoutSeconds)
    while ContinuousClock.now < deadline {
        if let resolution = await MainActor.run(body: { minimap.latestRequestResolution }),
           resolution.kind == expectedKind {
            return resolution
        }
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    throw LiveIntegrationError.timedOut(operation: operation, seconds: timeoutSeconds)
}

private func completeLiveTurnAcceptingApprovals(
    _ turnHandle: CodexTurnHandle,
    timeoutSeconds: Double,
    operation: String
) async throws -> LiveScenarioTurnResult {
    let minimap = await turnHandle.minimap
    let deadline = ContinuousClock.now + .seconds(timeoutSeconds)
    var answeredRequestIDs = Set<CodexRPCRequestID>()
    var acceptedApprovalKinds: [String] = []

    while ContinuousClock.now < deadline {
        if let request = await MainActor.run(body: { minimap.latestApprovalRequest }),
           answeredRequestIDs.contains(request.requestID) == false {
            answeredRequestIDs.insert(request.requestID)
            acceptedApprovalKinds.append(request.kind.rawValue)
            try await turnHandle.respond(
                to: request,
                with: acceptanceResponse(for: request)
            )
        }

        if let completion = await MainActor.run(body: { minimap.latestCompletion }) {
            let snapshots = await MainActor.run(body: { minimap.callSnapshots })
            let completedText = await MainActor.run(body: { minimap.latestCompletedItem?.item.text })
            return LiveScenarioTurnResult(
                completion: completion,
                acceptedApprovalKinds: acceptedApprovalKinds,
                callSnapshots: snapshots,
                latestCompletedItemText: completedText
            )
        }

        try await Task.sleep(nanoseconds: 100_000_000)
    }

    throw LiveIntegrationError.timedOut(operation: operation, seconds: timeoutSeconds)
}

private struct RawCommandApprovalResult: Equatable, Sendable {
    let completion: CodexWireTurnCompletedNotification
    let threadID: String
    let turnID: String
    let sawCommandItem: Bool
    let sawApprovalRequest: Bool
    let sawServerRequestResolved: Bool
    let sawWaitingOnApproval: Bool
}

private struct RawPermissionsApprovalResult: Equatable, Sendable {
    let completion: CodexWireTurnCompletedNotification
    let threadID: String
    let turnID: String
    let requestedWritePaths: [String]?
    let requestReason: String?
    let sawApprovalRequest: Bool
    let sawServerRequestResolved: Bool
    let sawWaitingOnApproval: Bool
}

private struct RawToolUserInputResult: Equatable, Sendable {
    let completion: CodexWireTurnCompletedNotification
    let threadID: String
    let turnID: String
    let questionIDs: [String]
    let sawElicitationRequest: Bool
    let sawServerRequestResolved: Bool
}

private struct RawMcpElicitationResult: Equatable, Sendable {
    let completion: CodexWireTurnCompletedNotification
    let threadID: String
    let turnID: String
    let serverName: String?
    let sawMcpToolCall: Bool
    let sawElicitationRequest: Bool
    let sawServerRequestResolved: Bool
}

private func awaitRawCommandApprovalCompletion(
    eventIterator: inout AsyncStream<CodexRPCServerEvent>.Iterator,
    protocolLayer: CodexAppServerProtocol,
    transport: CodexAppServerTransport,
    threadID: String,
    turnID: String,
    operation: String
) async throws -> RawCommandApprovalResult {
    var sawCommandItem = false
    var sawApprovalRequest = false
    var sawServerRequestResolved = false
    var observedEvents: [String] = []

    while let serverEvent = await eventIterator.next() {
        guard let decodedEvent = try protocolLayer.decodeServerEvent(serverEvent) else {
            continue
        }
        observedEvents.append(String(describing: decodedEvent))

        switch decodedEvent {
        case let .itemStarted(started)
            where started.threadID == threadID
                && started.turnID == turnID
                && started.item.type == .commandExecution:
            sawCommandItem = true
        case let .threadStatusChanged(status)
            where status.threadID == threadID
                && status.status.activeFlags?.contains(.waitingOnApproval) == true:
            continue
        case let .commandExecutionApprovalRequested(request)
            where request.threadID == threadID && request.turnID == turnID:
            sawApprovalRequest = true
            let responsePayload = try protocolLayer.makeServerResponse(
                id: request.requestID,
                result: RawCommandExecutionApprovalResponse(decision: "accept")
            )
            try await transport.sendResponse(responsePayload, requestID: request.requestID)
        case let .serverRequestResolved(notification)
            where notification.threadID == threadID:
            sawServerRequestResolved = true
        case let .turnCompleted(completed)
            where completed.threadID == threadID && completed.turn.id == turnID:
            return .init(
                completion: completed,
                threadID: threadID,
                turnID: turnID,
                sawCommandItem: sawCommandItem,
                sawApprovalRequest: sawApprovalRequest,
                sawServerRequestResolved: sawServerRequestResolved,
                sawWaitingOnApproval: observedEvents.contains { $0.contains("waitingOnApproval") }
            )
        default:
            continue
        }
    }

    throw LiveIntegrationError.eventStreamEnded(operation: "\(operation): observedEvents=\(observedEvents)")
}

private func awaitRawPermissionsApprovalCompletion(
    eventIterator: inout AsyncStream<CodexRPCServerEvent>.Iterator,
    protocolLayer: CodexAppServerProtocol,
    transport: CodexAppServerTransport,
    threadID: String,
    turnID: String,
    operation: String
) async throws -> RawPermissionsApprovalResult {
    var requestedWritePaths: [String]?
    var requestReason: String?
    var sawApprovalRequest = false
    var sawServerRequestResolved = false
    var observedEvents: [String] = []

    while let serverEvent = await eventIterator.next() {
        guard let decodedEvent = try protocolLayer.decodeServerEvent(serverEvent) else {
            continue
        }
        observedEvents.append(String(describing: decodedEvent))

        switch decodedEvent {
        case let .threadStatusChanged(status)
            where status.threadID == threadID
                && status.status.activeFlags?.contains(.waitingOnApproval) == true:
            continue
        case let .permissionsApprovalRequested(request)
            where request.threadID == threadID && request.turnID == turnID:
            sawApprovalRequest = true
            requestedWritePaths = request.permissions.fileSystem?.write
            requestReason = request.reason
            let responsePayload = try protocolLayer.makeServerResponse(
                id: request.requestID,
                result: RawPermissionsApprovalResponse(
                    permissions: .init(
                        fileSystem: .init(read: nil, write: request.permissions.fileSystem?.write),
                        network: request.permissions.network.map { .init(enabled: $0.enabled) }
                    ),
                    scope: "turn"
                )
            )
            try await transport.sendResponse(responsePayload, requestID: request.requestID)
        case let .serverRequestResolved(notification)
            where notification.threadID == threadID:
            sawServerRequestResolved = true
        case let .turnCompleted(completed)
            where completed.threadID == threadID && completed.turn.id == turnID:
            return .init(
                completion: completed,
                threadID: threadID,
                turnID: turnID,
                requestedWritePaths: requestedWritePaths,
                requestReason: requestReason,
                sawApprovalRequest: sawApprovalRequest,
                sawServerRequestResolved: sawServerRequestResolved,
                sawWaitingOnApproval: observedEvents.contains { $0.contains("waitingOnApproval") }
            )
        default:
            continue
        }
    }

    throw LiveIntegrationError.eventStreamEnded(operation: "\(operation): observedEvents=\(observedEvents)")
}

private func awaitRawToolUserInputCompletion(
    eventIterator: inout AsyncStream<CodexRPCServerEvent>.Iterator,
    protocolLayer: CodexAppServerProtocol,
    transport: CodexAppServerTransport,
    threadID: String,
    turnID: String,
    operation: String
) async throws -> RawToolUserInputResult {
    var questionIDs: [String] = []
    var sawElicitationRequest = false
    var sawServerRequestResolved = false
    var observedEvents: [String] = []

    while let serverEvent = await eventIterator.next() {
        guard let decodedEvent = try protocolLayer.decodeServerEvent(serverEvent) else {
            continue
        }
        observedEvents.append(String(describing: decodedEvent))

        switch decodedEvent {
        case let .toolUserInputRequested(request)
            where request.threadID == threadID && request.turnID == turnID:
            sawElicitationRequest = true
            questionIDs = request.questions.map(\.id)
            let responsePayload = try protocolLayer.makeServerResponse(
                id: request.requestID,
                result: RawToolUserInputResponse(
                    answers: [
                        "direction": .init(answers: ["Continue (Recommended)"]),
                    ]
                )
            )
            try await transport.sendResponse(responsePayload, requestID: request.requestID)
        case let .serverRequestResolved(notification)
            where notification.threadID == threadID:
            sawServerRequestResolved = true
        case let .turnCompleted(completed)
            where completed.threadID == threadID && completed.turn.id == turnID:
            guard sawElicitationRequest else {
                throw LiveIntegrationError.eventStreamEnded(operation: "\(operation): observedEvents=\(observedEvents)")
            }
            return .init(
                completion: completed,
                threadID: threadID,
                turnID: turnID,
                questionIDs: questionIDs,
                sawElicitationRequest: sawElicitationRequest,
                sawServerRequestResolved: sawServerRequestResolved
            )
        default:
            continue
        }
    }

    throw LiveIntegrationError.eventStreamEnded(operation: "\(operation): observedEvents=\(observedEvents)")
}

private func awaitRawMcpElicitationCompletion(
    eventIterator: inout AsyncStream<CodexRPCServerEvent>.Iterator,
    protocolLayer: CodexAppServerProtocol,
    transport: CodexAppServerTransport,
    threadID: String,
    turnID: String,
    operation: String
) async throws -> RawMcpElicitationResult {
    var serverName: String?
    var sawMcpToolCall = false
    var sawElicitationRequest = false
    var sawServerRequestResolved = false
    var observedEvents: [String] = []

    while let serverEvent = await eventIterator.next() {
        guard let decodedEvent = try protocolLayer.decodeServerEvent(serverEvent) else {
            continue
        }
        observedEvents.append(String(describing: decodedEvent))

        switch decodedEvent {
        case let .itemStarted(started)
            where started.threadID == threadID
                && started.turnID == turnID
                && started.item.type == .mcpToolCall:
            sawMcpToolCall = true
            serverName = started.item.server
        case let .itemCompleted(completed)
            where completed.threadID == threadID
                && completed.turnID == turnID
                && completed.item.type == .mcpToolCall:
            sawMcpToolCall = true
            serverName = completed.item.server
        case let .mcpServerElicitationRequested(request)
            where request.threadID == threadID && (request.turnID == nil || request.turnID == turnID):
            sawElicitationRequest = true
            serverName = request.serverName
            let responsePayload = try protocolLayer.makeServerResponse(
                id: request.requestID,
                result: RawMcpServerElicitationResponse(
                    action: "accept",
                    content: ["confirmed": true],
                    meta: nil
                )
            )
            try await transport.sendResponse(responsePayload, requestID: request.requestID)
        case let .serverRequestResolved(notification)
            where notification.threadID == threadID:
            sawServerRequestResolved = true
        case let .turnCompleted(completed)
            where completed.threadID == threadID && completed.turn.id == turnID:
            return .init(
                completion: completed,
                threadID: threadID,
                turnID: turnID,
                serverName: serverName,
                sawMcpToolCall: sawMcpToolCall,
                sawElicitationRequest: sawElicitationRequest,
                sawServerRequestResolved: sawServerRequestResolved
            )
        default:
            continue
        }
    }

    throw LiveIntegrationError.eventStreamEnded(operation: "\(operation): observedEvents=\(observedEvents)")
}

private struct RawCommandExecutionApprovalResponse: Encodable {
    let decision: String
}

private struct RawPermissionsApprovalResponse: Encodable {
    let permissions: RawPermissionProfile
    let scope: String
}

private struct RawPermissionProfile: Encodable {
    let fileSystem: FileSystem?
    let network: Network?

    struct FileSystem: Encodable {
        let read: [String]?
        let write: [String]?
    }

    struct Network: Encodable {
        let enabled: Bool?
    }
}

private struct RawToolUserInputResponse: Encodable {
    let answers: [String: Answer]

    struct Answer: Encodable {
        let answers: [String]
    }
}

private struct RawMcpServerElicitationResponse: Encodable {
    let action: String
    let content: [String: Bool]?
    let meta: [String: String]?

    enum CodingKeys: String, CodingKey {
        case action
        case content
        case meta = "_meta"
    }
}

private func acceptanceResponse(for request: CodexApprovalRequest) -> CodexApprovalResponse {
    switch request {
    case .commandExecution:
        return .commandExecution(.accept)
    case .fileChange:
        return .fileChange(.accept)
    case let .permissions(permissionsRequest):
        return .permissions(
            .init(
                permissions: permissionsRequest.permissions,
                scope: .turn
            )
        )
    }
}

private func withTimeout<T: Sendable>(
    seconds: Double,
    operation: String,
    body: @escaping @Sendable () async throws -> T
) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await body()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw LiveIntegrationError.timedOut(operation: operation, seconds: seconds)
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

private func prompt(label: String) -> String {
    """
    This is a live SwiftASB integration test.
    Do not call tools.
    Do not edit files.
    Do not ask questions.
    Reply with exactly this text and nothing else: \(label)
    """
}

private extension CodexAppServer.TurnStatus {
    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .interrupted:
            return true
        case .inProgress:
            return false
        }
    }
}

private extension CodexAppServer.ApprovalPolicy {
    var reportLabel: String {
        switch self {
        case .never:
            return "never"
        case .onFailure:
            return "onFailure"
        case .onRequest:
            return "onRequest"
        case .untrusted:
            return "untrusted"
        case let .granular(policy):
            return """
            granular(mcpElicitations:\(policy.mcpElicitations),requestPermissions:\(String(describing: policy.requestPermissions)),rules:\(policy.rules),sandboxApproval:\(policy.sandboxApproval),skillApproval:\(String(describing: policy.skillApproval)))
            """
        }
    }

    var requiresUserReviewer: Bool {
        switch self {
        case .never:
            return false
        case .onFailure, .onRequest, .untrusted, .granular:
            return true
        }
    }
}

private func makeInitializedLiveClient(
    using harness: LiveCodexHarness,
    experimentalAPI: Bool? = nil
) async throws -> CodexAppServer {
    let client = CodexAppServer(configuration: harness.configuration)
    try await client.start()

    do {
        _ = try await withTimeout(seconds: 15, operation: "initializing the live Codex app-server") {
            try await client.initialize(
                .init(
                    capabilities: .init(
                        experimentalAPI: experimentalAPI,
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
        }
        return client
    } catch {
        await client.stop()
        throw error
    }
}
