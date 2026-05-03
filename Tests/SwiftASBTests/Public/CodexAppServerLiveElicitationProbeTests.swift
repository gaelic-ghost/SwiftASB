import Foundation
import CryptoKit
import Testing
@testable import SwiftASB

extension CodexAppServerLiveIntegrationTests {
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

}
