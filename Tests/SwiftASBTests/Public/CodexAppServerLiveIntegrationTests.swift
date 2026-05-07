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
                timeoutSeconds: liveTimeoutSeconds(default: 45),
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
                timeoutSeconds: liveTimeoutSeconds(default: 45),
                operation: "waiting for the first cross-thread turn to complete"
            )
            async let crossThreadCompletionB = awaitCompletion(
                of: crossThreadTurnB,
                timeoutSeconds: liveTimeoutSeconds(default: 45),
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

            let hooksCwd = harness.rootDirectoryURL.path
            let hooks = try await withTimeout(
                seconds: 15,
                operation: "listing live Codex hook diagnostics"
            ) {
                try await client.listHooks(
                    .init(currentDirectoryPaths: [hooksCwd])
                )
            }
            #expect(hooks.entries.contains { $0.currentDirectoryPath == hooksCwd })
            #expect(hooks.entries.allSatisfy { entry in
                entry.currentDirectoryPath.isEmpty == false
                    && entry.errors.allSatisfy { !$0.message.isEmpty && !$0.path.isEmpty }
                    && entry.hooks.allSatisfy { !$0.key.isEmpty && !$0.sourcePath.isEmpty }
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
                timeoutSeconds: liveTimeoutSeconds(default: 45),
                operation: "waiting for the first live rollback turn to complete"
            )
            #expect(firstCompletion.turn.status == .completed)

            let secondTurn = try await startTurn(
                on: thread,
                prompt: prompt(label: "LIVE_ROLLBACK_SECOND_DONE")
            )
            let secondCompletion = try await awaitCompletion(
                of: secondTurn,
                timeoutSeconds: liveTimeoutSeconds(default: 45),
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
                timeoutSeconds: liveTimeoutSeconds(default: 45),
                operation: "waiting for the first live history turn to complete"
            )
            #expect(firstCompletion.turn.status == .completed)

            let secondTurn = try await startTurn(
                on: thread,
                prompt: prompt(label: "LIVE_HISTORY_SECOND_DONE")
            )
            let secondCompletion = try await awaitCompletion(
                of: secondTurn,
                timeoutSeconds: liveTimeoutSeconds(default: 45),
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

}
