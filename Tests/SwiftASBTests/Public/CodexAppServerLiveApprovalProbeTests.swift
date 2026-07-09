import CryptoKit
import Foundation
@testable import SwiftASB
import Testing

extension CodexAppServerLiveIntegrationTests {
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
        let expectedDigest = Data(SHA256.hash(data: Data(fixtureText.utf8)))
            .map {
                String(format: "%02x", $0)
            }
            .joined()

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
                        case let .guardianDeniedAction(guardianRequest):
                            #expect(guardianRequest.threadID == approvalThread.id)
                            #expect(guardianRequest.turnID == approvalTurn.turn.id)
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
        let expectedDigest = Data(SHA256.hash(data: Data(readFixtureText.utf8)))
            .map {
                String(format: "%02x", $0)
            }
            .joined()

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
                    try results.append(await runApprovalProbeCaseReport(probeCase, on: caseThread))
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
                try results.append(await runApprovalProbeCaseReport(readOnlyWriteCase, on: readOnlyThread))
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
                        mcpServerOpenaiFormElicitation: nil,
                        optOutNotificationMethods: [
                            "account/rateLimits/updated",
                            "hook/completed",
                            "hook/started",
                            "mcpServer/startupStatus/updated",
                        ],

                        requestAttestation: nil
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
                protocolLayer.makeInitializedNotification(),
                method: "initialized"
            )

            let threadRequestID = CodexRPCRequestID.string("deterministic-approval-thread")
            let threadStartPayload = try protocolLayer.makeThreadStartRequest(
                id: threadRequestID,
                params: CodexWireThreadStartParams(
                    allowProviderModelFallback: nil,
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
                    historyMode: nil,
                    mockExperimentalField: nil,
                    model: nil,
                    modelProvider: nil,
                    multiAgentMode: nil,
                    permissions: nil,
                    personality: nil,
                    runtimeWorkspaceRoots: nil,
                    sandbox: .readOnly,
                    selectedCapabilityRoots: nil,
                    serviceName: nil,
                    serviceTier: nil,
                    sessionStartSource: nil,
                    threadSource: nil
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
                    additionalContext: nil,
                    approvalPolicy: .enumeration(.untrusted),
                    approvalsReviewer: .user,
                    clientUserMessageID: nil,
                    collaborationMode: nil,
                    cwd: nil,
                    effort: nil,
                    environments: nil,
                    input: [
                        CodexWireUserInput(
                            text: "Run the provided command, then report completion.",
                            textElements: nil,
                            type: .text,
                            detail: nil,
                            url: nil,
                            path: nil,
                            name: nil
                        ),
                    ],
                    model: nil,
                    multiAgentMode: nil,
                    outputSchema: nil,
                    permissions: nil,
                    personality: nil,
                    responsesapiClientMetadata: nil,
                    runtimeWorkspaceRoots: nil,
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
                        mcpServerOpenaiFormElicitation: nil,
                        optOutNotificationMethods: [
                            "account/rateLimits/updated",
                            "hook/completed",
                            "hook/started",
                            "mcpServer/startupStatus/updated",
                        ],

                        requestAttestation: nil
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
                protocolLayer.makeInitializedNotification(),
                method: "initialized"
            )

            let threadRequestID = CodexRPCRequestID.string("deterministic-permissions-thread")
            let threadStartPayload = try protocolLayer.makeThreadStartRequest(
                id: threadRequestID,
                params: CodexWireThreadStartParams(
                    allowProviderModelFallback: nil,
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
                    historyMode: nil,
                    mockExperimentalField: nil,
                    model: nil,
                    modelProvider: nil,
                    multiAgentMode: nil,
                    permissions: nil,
                    personality: nil,
                    runtimeWorkspaceRoots: nil,
                    sandbox: .readOnly,
                    selectedCapabilityRoots: nil,
                    serviceName: nil,
                    serviceTier: nil,
                    sessionStartSource: nil,
                    threadSource: nil
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
                    additionalContext: nil,
                    approvalPolicy: .enumeration(.untrusted),
                    approvalsReviewer: .user,
                    clientUserMessageID: nil,
                    collaborationMode: nil,
                    cwd: nil,
                    effort: nil,
                    environments: nil,
                    input: [
                        CodexWireUserInput(
                            text: "Request the provided permissions, then report completion.",
                            textElements: nil,
                            type: .text,
                            detail: nil,
                            url: nil,
                            path: nil,
                            name: nil
                        ),
                    ],
                    model: nil,
                    multiAgentMode: nil,
                    outputSchema: nil,
                    permissions: nil,
                    personality: nil,
                    responsesapiClientMetadata: nil,
                    runtimeWorkspaceRoots: nil,
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
}
