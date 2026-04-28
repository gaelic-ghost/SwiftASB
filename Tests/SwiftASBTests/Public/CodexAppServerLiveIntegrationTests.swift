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
                    ephemeral: true,
                    model: nil,
                    modelProvider: nil,
                    permissionProfile: nil,
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
                    ephemeral: true,
                    model: nil,
                    modelProvider: nil,
                    permissionProfile: nil,
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
                    cwd: nil,
                    effort: nil,
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
                    permissionProfile: nil,
                    personality: nil,
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

        let client = try await makeInitializedLiveClient(using: harness)
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
        "probes live approval-path behavior for shell commands",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_APPROVAL_TESTS"] == "1",
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

            let minimap = await approvalTurn.makeMinimap()
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
            #expect(try String(contentsOf: scratchURL, encoding: .utf8) == "alpha\n")

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
            #expect(try String(contentsOf: scratchURL, encoding: .utf8) == "alpha\nbeta\n")

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
    let threadAWorkspace: URL
    let threadBWorkspace: URL
    let fileScenarioWorkspace: URL
    let sameThreadWorkspace: URL
    let codexExecutableURL: URL

    init(fileManager: FileManager = .default) throws {
        let rootDirectoryURL = fileManager.temporaryDirectory
            .appendingPathComponent("SwiftASB-LiveCodex-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: rootDirectoryURL, withIntermediateDirectories: true)

        self.rootDirectoryURL = rootDirectoryURL
        self.codexHomeURL = rootDirectoryURL.appendingPathComponent(".codex", isDirectory: true)
        self.threadAWorkspace = rootDirectoryURL.appendingPathComponent("thread-a", isDirectory: true)
        self.threadBWorkspace = rootDirectoryURL.appendingPathComponent("thread-b", isDirectory: true)
        self.fileScenarioWorkspace = rootDirectoryURL.appendingPathComponent("file-scenario", isDirectory: true)
        self.sameThreadWorkspace = rootDirectoryURL.appendingPathComponent("same-thread", isDirectory: true)
        self.codexExecutableURL = try Self.resolveCodexExecutableURL()

        try fileManager.createDirectory(at: codexHomeURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: threadAWorkspace, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: threadBWorkspace, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: fileScenarioWorkspace, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: sameThreadWorkspace, withIntermediateDirectories: true)
        try Self.seedIsolatedCodexHome(at: codexHomeURL, fileManager: fileManager)
    }

    var configuration: CodexAppServer.Configuration {
        .init(
            codexExecutableURL: codexExecutableURL,
            currentDirectoryURL: rootDirectoryURL,
            environment: Self.makeCodexEnvironment(codexHomeURL: codexHomeURL)
        )
    }

    func cleanup(fileManager: FileManager = .default) {
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

    private static func seedIsolatedCodexHome(at codexHomeURL: URL, fileManager: FileManager) throws {
        let sourceCodexHomeURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
        let sourceAuthURL = sourceCodexHomeURL.appendingPathComponent("auth.json")
        let destinationAuthURL = codexHomeURL.appendingPathComponent("auth.json")

        if fileManager.fileExists(atPath: sourceAuthURL.path) {
            try fileManager.copyItem(at: sourceAuthURL, to: destinationAuthURL)
        }

        let configURL = codexHomeURL.appendingPathComponent("config.toml")
        let isolatedConfig = """
        model = "gpt-5.4"

        [features]
        apps = false

        [apps._default]
        enabled = false
        """
        try Data(isolatedConfig.utf8).write(to: configURL)
    }
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
                sandboxMode: .workspaceWrite
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
    let minimap = await turnHandle.makeMinimap()
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
            return LiveScenarioTurnResult(
                completion: completion,
                acceptedApprovalKinds: acceptedApprovalKinds,
                callSnapshots: snapshots
            )
        }

        try await Task.sleep(nanoseconds: 100_000_000)
    }

    throw LiveIntegrationError.timedOut(operation: operation, seconds: timeoutSeconds)
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

private func makeInitializedLiveClient(using harness: LiveCodexHarness) async throws -> CodexAppServer {
    let client = CodexAppServer(configuration: harness.configuration)
    try await client.start()

    do {
        _ = try await withTimeout(seconds: 15, operation: "initializing the live Codex app-server") {
            try await client.initialize(
                .init(
                    capabilities: .init(
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
