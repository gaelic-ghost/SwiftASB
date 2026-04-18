import Foundation
import Testing
@testable import SwiftASB

@Suite("CodexAppServer live integration")
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
        self.sameThreadWorkspace = rootDirectoryURL.appendingPathComponent("same-thread", isDirectory: true)
        self.codexExecutableURL = try Self.resolveCodexExecutableURL()

        try fileManager.createDirectory(at: codexHomeURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: threadAWorkspace, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: threadBWorkspace, withIntermediateDirectories: true)
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

private enum LiveTurnStartOutcome {
    case started(CodexTurnHandle)
    case failed(String)
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
    label: String
) async throws -> CodexThread {
    return try await withTimeout(seconds: 15, operation: "starting the \(label) thread") {
        try await client.startThread(
            .init(
                approvalPolicy: .never,
                currentDirectoryPath: workspacePath,
                developerInstructions: """
                You are running inside a SwiftASB live integration test.
                Do not call tools.
                Do not edit files.
                Do not ask follow-up questions.
                Reply only with the exact text requested by the user message.
                """,
                ephemeral: true,
                sandboxMode: .workspaceWrite
            )
        )
    }
}

private func startTurn(
    on thread: CodexThread,
    prompt: String
) async throws -> CodexTurnHandle {
    return try await withTimeout(seconds: 20, operation: "starting a live turn on thread \(thread.id)") {
        try await thread.startTextTurn(
            prompt,
            approvalPolicy: .never,
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
