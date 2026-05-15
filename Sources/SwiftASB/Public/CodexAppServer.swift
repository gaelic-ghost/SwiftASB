import Foundation
import OSLog

public actor CodexAppServer {
    private enum ThreadTurnActivity: Sendable, Equatable {
        case starting, active(turnID: String)
    }

    private struct ThreadObservableActivityState: Sendable, Equatable {
        var activeToolLikeItemIDs: Set<String> = []
        var activeMcpItemIDs: Set<String> = []
        var hasToolErrorResidue = false
        var hasMcpErrorResidue = false
        var hookRuns: [CodexThread.Dashboard.HookRun] = []
        var isCompactingThreadContext = false
    }

    internal struct RecentTurnWindowResult: Sendable {
        let turns: [ThreadHistoryStore.ThreadSnapshot.TurnSnapshot]
        let nextOlderCursor: String?
        let nextNewerCursor: String?
    }

    internal struct RecentFileSnapshot: Sendable, Equatable, Identifiable {
        let id: String
        let itemID: String
        let latestStatusText: String?
        let path: String?
        let payloadText: String?
        let status: String?
        let threadID: String
        let turnID: String
        let turnOrderIndex: Int
        let itemOrderIndex: Int
        let turnStartedAt: Int?
    }

    internal struct RecentCommandSnapshot: Sendable, Equatable, Identifiable {
        let id: String
        let itemID: String
        let command: String?
        let latestStatusText: String?
        let outputText: String?
        let status: String?
        let threadID: String
        let turnID: String
        let turnOrderIndex: Int
        let itemOrderIndex: Int
        let turnStartedAt: Int?
    }

    internal struct RecentFileWindowResult: Sendable {
        let files: [RecentFileSnapshot]
        let nextOlderCursor: String?
    }

    internal struct RecentCommandWindowResult: Sendable {
        let commands: [RecentCommandSnapshot]
        let nextOlderCursor: String?
    }

    internal struct CommandExecutionOutputDeltaEvent: Sendable, Equatable {
        let delta: String
        let itemID: String
        let threadID: String
        let turnID: String
    }

    internal struct FileChangeOutputDeltaEvent: Sendable, Equatable {
        let delta: String
        let itemID: String
        let path: String?
        let replacesPayload: Bool
        let threadID: String
        let turnID: String
    }

    private enum InteractiveRequestDestination: Sendable, Equatable {
        case thread(threadID: String), turn(turnID: String)
    }

    private struct OutstandingInteractiveRequest: Sendable, Equatable {
        let destination: InteractiveRequestDestination
        let kind: CodexInteractiveRequestKind
        let threadID: String
        let turnID: String?
    }

    private let transport: any CodexAppServerTransporting
    private let protocolLayer: CodexAppServerProtocol
    private let featurePolicy: SwiftASBFeaturePolicy
    private static let logger = Logger(
        subsystem: "com.gaelic-ghost.SwiftASB",
        category: "CodexAppServer"
    )
    private let historyStore: ThreadHistoryStore?
    private let historyStoreInitializationError: Error?
    private var serverEventTask: Task<Void, Never>?
    private var threadStatuses: [String: ThreadStatus] = [:]
    private var threadEventContinuations: [String: [UUID: AsyncThrowingStream<CodexThreadEvent, Error>.Continuation]] = [:]
    private var diagnosticEventContinuations: [UUID: AsyncThrowingStream<CodexDiagnosticEvent, Error>.Continuation] = [:]
    private var libraryEventContinuations: [UUID: AsyncStream<LibraryEvent>.Continuation] = [:]
    private var featureOperationEventContinuations: [UUID: AsyncStream<SwiftASBFeatureOperationEvent>.Continuation] = [:]
    private var fsChangeContinuations: [String: [UUID: AsyncStream<CodexFS.ChangeEvent>.Continuation]] = [:]
    private var threadObservableActivityContinuations: [String: [UUID: AsyncStream<CodexThread.Dashboard.ActivityState>.Continuation]] = [:]
    private var threadCommandDeltaContinuations: [String: [UUID: AsyncStream<CommandExecutionOutputDeltaEvent>.Continuation]] = [:]
    private var threadFileDeltaContinuations: [String: [UUID: AsyncStream<FileChangeOutputDeltaEvent>.Continuation]] = [:]
    private var bufferedThreadEvents: [String: [CodexThreadEvent]] = [:]
    private var bufferedDiagnosticEvents: [CodexDiagnosticEvent] = []
    private var bufferedFeatureOperationEvents: [SwiftASBFeatureOperationEvent] = []
    private var bufferedTerminalThreadEvents: [String: CodexThreadEvent] = [:]
    private var threadTurnEventContinuations: [String: [UUID: AsyncThrowingStream<CodexTurnEvent, Error>.Continuation]] = [:]
    private var turnEventContinuations: [String: [UUID: AsyncThrowingStream<CodexTurnEvent, Error>.Continuation]] = [:]
    private var bufferedTurnEvents: [String: [CodexTurnEvent]] = [:]
    private var bufferedTerminalTurnEvents: [String: CodexTurnEvent] = [:]
    private var threadTurnActivities: [String: ThreadTurnActivity] = [:]
    private var threadObservableActivityStates: [String: ThreadObservableActivityState] = [:]
    private var turnThreadIDs: [String: String] = [:]
    private var outstandingInteractiveRequests: [CodexRPCRequestID: OutstandingInteractiveRequest] = [:]
    private var hasStarted = false
    private var hasCompletedInitializeHandshake = false
    private var isStopping = false

    /// Creates a client for a locally launched Codex app-server.
    ///
    /// Omitting `configuration` uses SwiftASB's standard app-server launch
    /// command and local Codex executable discovery.
    public init(configuration: Configuration = .init()) {
        self.featurePolicy = configuration.featurePolicy
        self.transport = CodexAppServerTransport(
            configuration: CodexAppServerTransport.Configuration(
                codexExecutableURL: configuration.codexExecutableURL,
                arguments: configuration.arguments,
                currentDirectoryURL: configuration.currentDirectoryURL,
                environment: configuration.environment
            )
        )
        self.protocolLayer = CodexAppServerProtocol()
        do {
            self.historyStore = try ThreadHistoryStore()
            self.historyStoreInitializationError = nil
        } catch {
            self.historyStore = nil
            self.historyStoreInitializationError = error
        }
    }

    internal init(
        transport: any CodexAppServerTransporting,
        protocolLayer: CodexAppServerProtocol = CodexAppServerProtocol(),
        historyStore: ThreadHistoryStore? = nil,
        featurePolicy: SwiftASBFeaturePolicy = .defaults
    ) {
        self.transport = transport
        self.protocolLayer = protocolLayer
        self.featurePolicy = featurePolicy
        if let historyStore {
            self.historyStore = historyStore
            self.historyStoreInitializationError = nil
        } else {
            do {
                self.historyStore = try ThreadHistoryStore(configuration: .inMemory())
                self.historyStoreInitializationError = nil
            } catch {
                self.historyStore = nil
                self.historyStoreInitializationError = error
            }
        }
    }

    /// Launches the configured local Codex app-server subprocess.
    ///
    /// Call this before `initialize(_:)` or any other protocol request. A
    /// successful start also begins SwiftASB's background event loop for
    /// diagnostics, thread events, and turn events.
    public func start() async throws {
        do {
            try await startTransport()
        } catch {
            throw CodexAppServerError.wrap(error, operation: "start")
        }
    }

    /// Launches the app-server, validates Codex CLI compatibility, and initializes.
    ///
    /// Use this one-call startup path for app clients that want a ready
    /// app-server session or a typed startup error. The lower-level `start()`,
    /// `cliExecutableDiagnostics()`, and `initialize(_:)` calls remain available
    /// for clients that intentionally own each step.
    public func start(_ request: StartupRequest) async throws -> StartupSession {
        do {
            try await startTransport()
        } catch {
            throw CodexAppServerStartupError.startFailure(from: error)
        }

        do {
            let diagnostics = try await cliExecutableDiagnostics()
            try validateStartupCompatibility(
                diagnostics,
                policy: request.compatibilityPolicy
            )
            let session = try await initialize(request.initializeRequest)
            return .init(
                cliExecutableDiagnostics: diagnostics,
                initializeSession: session
            )
        } catch {
            await stop()
            throw CodexAppServerStartupError.initializeFailure(from: error)
        }
    }

    /// Stops the app-server subprocess and finishes all public streams.
    ///
    /// Streams finish normally when shutdown is initiated through SwiftASB.
    /// After stopping, call `start()` and `initialize(_:)` again before sending
    /// more app-server requests.
    public func stop() async {
        isStopping = true
        serverEventTask?.cancel()
        serverEventTask = nil
        finishAllThreadEventStreams(throwing: nil)
        finishAllDiagnosticEventStreams(throwing: nil)
        finishAllLibraryEventStreams()
        finishAllFeatureOperationEventStreams()
        finishAllFSChangeStreams()
        finishAllThreadObservableActivityStreams()
        finishAllThreadCommandDeltaStreams()
        finishAllThreadFileDeltaStreams()
        finishAllTurnEventStreams(throwing: nil)
        await transport.stop()
        hasStarted = false
        hasCompletedInitializeHandshake = false
        threadStatuses.removeAll()
        threadTurnActivities.removeAll()
        threadObservableActivityStates.removeAll()
        turnThreadIDs.removeAll()
        bufferedThreadEvents.removeAll()
        bufferedDiagnosticEvents.removeAll()
        bufferedFeatureOperationEvents.removeAll()
        bufferedTurnEvents.removeAll()
        bufferedTerminalThreadEvents.removeAll()
        bufferedTerminalTurnEvents.removeAll()
        outstandingInteractiveRequests.removeAll()
    }

    private func startTransport() async throws {
        try await transport.start()
        hasStarted = true
        hasCompletedInitializeHandshake = false
        isStopping = false
        startServerEventLoop()
    }

    private func validateStartupCompatibility(
        _ diagnostics: CLIExecutableDiagnostics,
        policy: StartupCompatibilityPolicy
    ) throws {
        switch (policy, diagnostics.compatibility) {
        case (.allowOutsideReviewedSupportWindow, _), (.requireReviewedSupportWindow, .supported):
            return
        case (.requireReviewedSupportWindow, .outsideDocumentedWindow):
            throw CodexAppServerStartupError.incompatibleCodexCLI(
                diagnostics: diagnostics
            )
        case (.requireReviewedSupportWindow, .unknownVersionFormat):
            throw CodexAppServerStartupError.unknownCodexCLIVersion(
                diagnostics: diagnostics
            )
        }
    }

    /// Returns diagnostics for the Codex CLI executable selected at startup.
    ///
    /// The value is available after `start()` succeeds. Use it to show users
    /// where `codex` was found, which version was launched, and whether that
    /// version is inside SwiftASB's documented reviewed support window.
    public func cliExecutableDiagnostics() async throws -> CLIExecutableDiagnostics {
        guard hasStarted else {
            throw CodexAppServerError.invalidState(
                reason: "Codex CLI diagnostics are only available after the app-server transport has been started."
            )
        }

        guard let resolution = await transport.executableResolution() else {
            throw CodexAppServerError.invalidState(
                reason: "Codex CLI diagnostics are not available for the current transport."
            )
        }

        return .init(resolution: resolution)
    }

    /// Subscribes to app-wide diagnostic events.
    ///
    /// Diagnostics are passive signals, not answerable requests. Events that
    /// arrive before the first subscriber are buffered and delivered to the
    /// first diagnostic stream. The stream finishes normally when the app-server
    /// is stopped through SwiftASB and finishes by throwing when the underlying
    /// event feed fails unexpectedly.
    public func diagnosticEvents() -> AsyncThrowingStream<CodexDiagnosticEvent, Error> {
        makeDiagnosticEventStream()
    }

    /// Subscribes to SwiftASB-owned feature-operation events.
    ///
    /// Feature-operation events are app-wide, human-readable records for
    /// SwiftASB convenience operations such as future repo-guidance sync,
    /// extension maintenance, and typed Git actions. Routine read-only
    /// refreshes do not emit events. The stream finishes normally when the
    /// app-server is stopped through SwiftASB.
    public func featureOperationEvents() -> AsyncStream<SwiftASBFeatureOperationEvent> {
        makeFeatureOperationEventStream()
    }

    /// Performs the app-server initialize handshake.
    ///
    /// Call this once after `start()`. SwiftASB sends the app-server's required
    /// `initialized` notification after the response is decoded successfully.
    public func initialize(_ request: InitializeRequest) async throws -> InitializeSession {
        try requireStarted(for: "initialize")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeInitializeRequest(
                id: requestID,
                params: request.wireValue
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeInitializeResponse(
                responsePayload,
                expectedID: requestID
            )

            let initializedPayload = try protocolLayer.makeInitializedNotification()
            try await transport.sendNotification(initializedPayload, method: "initialized")

            hasCompletedInitializeHandshake = true
            return InitializeSession(wireValue: response)
        } catch {
            throw CodexAppServerError.wrap(error, operation: "initialize")
        }
    }

    /// Runs one argv command through app-server `command/exec`.
    ///
    /// This intentionally omits permission-profile and sandbox overrides so
    /// Codex applies the user's configured command permissions by default.
    internal func executeCommand(_ request: CommandExecRequest) async throws -> CommandExecResult {
        try requireInitialized(for: "command/exec")

        guard !request.command.isEmpty else {
            throw CodexAppServerError.invalidState(
                reason: "SwiftASB cannot run command/exec with an empty argv vector."
            )
        }

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeCommandExecRequest(
                id: requestID,
                params: CodexProtocolCommandExecParams(
                    command: request.command,
                    cwd: request.currentDirectoryPath,
                    disableOutputCap: nil,
                    disableTimeout: nil,
                    env: request.environment.isEmpty ? nil : request.environment,
                    outputBytesCap: request.outputBytesCap,
                    permissionProfile: nil,
                    processID: nil,
                    sandboxPolicy: nil,
                    size: nil,
                    streamStdin: nil,
                    streamStdoutStderr: nil,
                    timeoutMS: request.timeoutMilliseconds,
                    tty: nil
                )
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeCommandExecResponse(
                responsePayload,
                expectedID: requestID
            )

            return .init(
                exitCode: response.exitCode,
                stdout: response.stdout,
                stderr: response.stderr
            )
        } catch {
            throw CodexAppServerError.wrap(error, operation: "command/exec")
        }
    }

    /// Sends one user-level shell command string to a running thread.
    ///
    /// `thread/shellCommand` is intentionally different from `command/exec`.
    /// `command/exec` runs argv-shaped SwiftASB helper commands through the
    /// app-server command runner. `thread/shellCommand` sends literal shell
    /// syntax to the thread's configured shell, preserving pipes, redirects,
    /// quoting, and other shell behavior, and the upstream schema documents
    /// that it runs unsandboxed with the user's full shell access.
    internal func sendThreadShellCommand(
        command: String,
        threadID: String
    ) async throws {
        try requireInitialized(for: "thread/shellCommand")
        try requireFeatureEnabled(.shellCommandExecution, for: "thread/shellCommand")

        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else {
            throw CodexAppServerError.invalidState(
                reason: "SwiftASB cannot send thread/shellCommand with an empty shell command string."
            )
        }

        let operationID = UUID().uuidString
        let startedAt = Date()

        do {
            let requestID = CodexRPCRequestID.generated()
            let requestPayload = try protocolLayer.makeThreadShellCommandRequest(
                id: requestID,
                params: .init(command: command, threadID: threadID)
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            _ = try protocolLayer.decodeThreadShellCommandResponse(
                responsePayload,
                expectedID: requestID
            )

            publishFeatureOperationEvent(
                .init(
                    categoryID: .shellCommandExecution,
                    operationID: operationID,
                    title: "Send shell command",
                    summary: "Sent a user-level shell command to the Codex thread.",
                    reason: "Shell command execution is enabled by the host app.",
                    startedAt: startedAt,
                    completedAt: Date(),
                    appServerMethod: "thread/shellCommand",
                    intentKind: "threadShellCommand",
                    status: .succeeded
                )
            )
        } catch {
            publishFeatureOperationEvent(
                .init(
                    categoryID: .shellCommandExecution,
                    operationID: operationID,
                    title: "Send shell command",
                    summary: "Failed to send a user-level shell command to the Codex thread.",
                    reason: "Shell command execution is enabled by the host app.",
                    startedAt: startedAt,
                    completedAt: Date(),
                    appServerMethod: "thread/shellCommand",
                    intentKind: "threadShellCommand",
                    status: .failed,
                    diagnosticText: String(describing: error)
                )
            )
            throw CodexAppServerError.wrap(error, operation: "thread/shellCommand")
        }
    }

    internal func codexCommandExecutablePath() async -> String {
        await transport.executableResolution()?.resolvedExecutableURL?.path ?? "codex"
    }

    internal func requireFeatureEnabled(
        _ categoryID: SwiftASBFeatureCategory.ID,
        for operation: String
    ) throws {
        guard featurePolicy.mode(for: categoryID) == .enabled else {
            let categoryName = SwiftASBFeatureCategory.builtInCategory(id: categoryID)?.displayName
                ?? categoryID.rawValue
            throw CodexAppServerError.invalidState(
                reason: """
                SwiftASB cannot run \(operation) because the \(categoryName) feature category is not enabled. \
                Enable \(categoryID.rawValue) in SwiftASBFeaturePolicy before requesting this SwiftASB-owned mutation.
                """
            )
        }
    }

    /// Reads the app-server's current model catalog.
    ///
    /// Omitting `request` sends an empty list request, leaving pagination and
    /// hidden-model behavior to the app-server defaults.
    public func listModels(_ request: ModelListRequest = .init()) async throws -> ModelListPage {
        try requireInitialized(for: "model/list")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeModelListRequest(
                id: requestID,
                params: .init(
                    cursor: request.cursor,
                    includeHidden: request.includeHidden,
                    limit: request.limit
                )
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeModelListResponse(
                responsePayload,
                expectedID: requestID
            )

            return .init(
                models: response.data.map(Model.init(wireValue:)),
                nextCursor: response.nextCursor
            )
        } catch {
            throw CodexAppServerError.wrap(error, operation: "model/list")
        }
    }

    /// Reads feature gates for the current model provider.
    ///
    /// Use this app-wide snapshot to decide whether UI affordances for web
    /// search, image generation, or namespace tools should be available before
    /// starting a turn.
    public func readModelCapabilities() async throws -> ModelCapabilities {
        try requireInitialized(for: "modelProvider/capabilities/read")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeModelProviderCapabilitiesReadRequest(
                id: requestID,
                params: .init()
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeModelProviderCapabilitiesReadResponse(
                responsePayload,
                expectedID: requestID
            )

            return .init(wireValue: response)
        } catch {
            throw CodexAppServerError.wrap(error, operation: "modelProvider/capabilities/read")
        }
    }

    /// Reads configured hooks and diagnostics for one or more working directories.
    ///
    /// Omitting `request` sends an empty list request, leaving the app-server to
    /// use its current session working directory.
    public func listHooks(_ request: HookListRequest = .init()) async throws -> HookListSnapshot {
        try requireInitialized(for: "hooks/list")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeHooksListRequest(
                id: requestID,
                params: .init(cwds: request.currentDirectoryPaths)
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeHooksListResponse(
                responsePayload,
                expectedID: requestID
            )

            return .init(entries: response.data.map(HookListEntry.init(protocolValue:)))
        } catch {
            throw CodexAppServerError.wrap(error, operation: "hooks/list")
        }
    }

    /// Reads the app-server's current MCP server status snapshots.
    ///
    /// Omitting `request` sends an empty status-list request, leaving
    /// pagination and detail level to the app-server defaults.
    public func listMcpServerStatuses(
        _ request: McpServerStatusListRequest = .init()
    ) async throws -> McpServerStatusPage {
        try requireInitialized(for: "mcpServerStatus/list")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeMcpServerStatusListRequest(
                id: requestID,
                params: .init(
                    cursor: request.cursor,
                    detail: request.detail?.wireValue,
                    limit: request.limit
                )
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeMcpServerStatusListResponse(
                responsePayload,
                expectedID: requestID
            )

            return .init(
                nextCursor: response.nextCursor,
                servers: response.data.map(McpServerStatus.init(wireValue:))
            )
        } catch {
            throw CodexAppServerError.wrap(error, operation: "mcpServerStatus/list")
        }
    }

    /// Reads one resource from a configured MCP server.
    public func readMcpResource(_ request: McpResourceReadRequest) async throws -> McpResourceReadResult {
        try requireInitialized(for: "mcpServer/resource/read")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeMcpResourceReadRequest(
                id: requestID,
                params: .init(
                    server: request.server,
                    threadID: request.threadID,
                    uri: request.uri
                )
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeMcpResourceReadResponse(
                responsePayload,
                expectedID: requestID
            )

            return .init(wireValue: response)
        } catch {
            throw CodexAppServerError.wrap(error, operation: "mcpServer/resource/read")
        }
    }

    /// Starts a new Codex thread.
    ///
    /// Omitting `request` sends an empty thread-start request, letting Codex
    /// choose its configured model, sandbox, approval, and storage defaults.
    public func startThread(_ request: ThreadStartRequest = .init()) async throws -> CodexThread {
        try requireInitialized(for: "thread/start")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeThreadStartRequest(
                id: requestID,
                params: request.wireValue
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeThreadStartResponse(
                responsePayload,
                expectedID: requestID
            )
            let session = ThreadSession(wireValue: response)
            threadStatuses[response.thread.id] = .init(wireValue: response.thread.status)
            try await requireHistoryStore(for: "thread/start").recordThreadStarted(session: session)
            publishLibraryEvent(.threadChanged(threadID: response.thread.id))

            return CodexThread(
                appServer: self,
                session: session,
                events: makeThreadEventStream(threadID: response.thread.id)
            )
        } catch {
            throw CodexAppServerError.wrap(error, operation: "thread/start")
        }
    }

    /// Reopens an existing stored Codex thread and returns a thread handle.
    ///
    /// The returned handle carries refreshed thread metadata, default turn
    /// settings, and a new thread-event stream. When `excludeTurns` is set on
    /// the request, Codex owns how much prior turn context is hidden from the
    /// resumed session.
    public func resumeThread(_ request: ThreadResumeRequest) async throws -> CodexThread {
        try requireInitialized(for: "thread/resume")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeThreadResumeRequest(
                id: requestID,
                params: request.wireValue
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeThreadResumeResponse(
                responsePayload,
                expectedID: requestID
            )
            let session = ThreadSession(wireValue: response)
            threadStatuses[response.thread.id] = .init(wireValue: response.thread.status)
            let historyStore = try requireHistoryStore(for: "thread/resume")
            try await historyStore.recordThreadResumed(
                session: session,
                turns: response.thread.turns.map {
                    .init(
                        turn: .init(wireValue: $0),
                        items: $0.items.map(CodexTurnItem.init(wireValue:))
                    )
                }
            )
            try await historyStore.recordThreadArchived(threadID: response.thread.id, isArchived: false)
            publishLibraryEvent(.threadChanged(threadID: response.thread.id))

            return CodexThread(
                appServer: self,
                session: session,
                events: makeThreadEventStream(threadID: response.thread.id)
            )
        } catch {
            throw CodexAppServerError.wrap(error, operation: "thread/resume")
        }
    }

    /// Creates a new thread from an existing stored thread.
    ///
    /// Forking returns a handle for the new thread and records the forked
    /// history in SwiftASB's local store. When `excludeTurns` is set on the
    /// request, Codex owns which prior turns are omitted from the fork context.
    public func forkThread(_ request: ThreadForkRequest) async throws -> CodexThread {
        try requireInitialized(for: "thread/fork")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeThreadForkRequest(
                id: requestID,
                params: request.wireValue
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeThreadForkResponse(
                responsePayload,
                expectedID: requestID
            )
            let session = ThreadSession(wireValue: response)
            threadStatuses[response.thread.id] = .init(wireValue: response.thread.status)
            let historyStore = try requireHistoryStore(for: "thread/fork")
            try await historyStore.recordThreadForked(
                session: session,
                turns: response.thread.turns.map {
                    .init(
                        turn: .init(wireValue: $0),
                        items: $0.items.map(CodexTurnItem.init(wireValue:))
                    )
                }
            )
            try await historyStore.recordThreadArchived(threadID: response.thread.id, isArchived: false)
            publishLibraryEvent(.threadChanged(threadID: response.thread.id))

            return CodexThread(
                appServer: self,
                session: session,
                events: makeThreadEventStream(threadID: response.thread.id)
            )
        } catch {
            throw CodexAppServerError.wrap(error, operation: "thread/fork")
        }
    }

    /// Starts app-server context compaction for a stored thread.
    ///
    /// Most consumers should call `CodexThread.compactContext()` when they
    /// already have a thread handle. This lower-level app-server method is
    /// useful when the caller owns only a thread identifier.
    public func compactThread(_ request: ThreadCompactRequest) async throws {
        try requireInitialized(for: "thread/compact/start")

        let requestID = CodexRPCRequestID.generated()

        do {
            let payload = try protocolLayer.makeThreadCompactStartRequest(
                id: requestID,
                params: .init(threadID: request.threadID)
            )
            let response = try await transport.send(payload, id: requestID)
            _ = try protocolLayer.decodeThreadCompactStartResponse(
                response,
                expectedID: requestID
            )
        } catch {
            throw CodexAppServerError.wrap(error, operation: "thread/compact/start")
        }
    }

    /// Rolls back trailing turns from a stored thread and returns refreshed metadata.
    ///
    /// SwiftASB records a local rollback marker and reconciles local history to
    /// the app-server response. It does not preserve a full forensic archive of
    /// removed turn payloads.
    public func rollbackThread(_ request: ThreadRollbackRequest) async throws -> ThreadInfo {
        try requireInitialized(for: "thread/rollback")
        guard request.numberOfTurns >= 1 else {
            throw CodexAppServerError.invalidState(
                reason: "thread/rollback requires numberOfTurns to be at least 1."
            )
        }

        let requestID = CodexRPCRequestID.generated()

        do {
            let payload = try protocolLayer.makeThreadRollbackRequest(
                id: requestID,
                params: .init(
                    numTurns: request.numberOfTurns,
                    threadID: request.threadID
                )
            )
            let responsePayload = try await transport.send(payload, id: requestID)
            let response = try protocolLayer.decodeThreadRollbackResponse(
                responsePayload,
                expectedID: requestID
            )
            let thread = ThreadInfo(wireValue: response.thread)
            try await requireHistoryStore(for: "thread/rollback").recordThreadRollback(
                requestedTurnCount: request.numberOfTurns,
                thread: thread,
                turns: response.thread.turns.map {
                    .init(
                        turn: .init(wireValue: $0),
                        items: $0.items.map(CodexTurnItem.init(wireValue:))
                    )
                }
            )
            publishLibraryEvent(.threadChanged(threadID: thread.id))

            return thread
        } catch {
            throw CodexAppServerError.wrap(error, operation: "thread/rollback")
        }
    }

    /// Sets the stored human-readable name for a thread.
    ///
    /// Most consumers should call `CodexThread.setName(_:)` from an existing
    /// thread handle. This lower-level app-server method is useful when the
    /// caller owns only a thread identifier.
    public func setThreadName(_ request: ThreadSetNameRequest) async throws {
        try requireInitialized(for: "thread/name/set")

        let requestID = CodexRPCRequestID.generated()

        do {
            let payload = try protocolLayer.makeThreadSetNameRequest(
                id: requestID,
                params: .init(name: request.name, threadID: request.threadID)
            )
            let response = try await transport.send(payload, id: requestID)
            _ = try protocolLayer.decodeThreadSetNameResponse(
                response,
                expectedID: requestID
            )
            try await requireHistoryStore(for: "thread/name/set").recordThreadNameUpdated(
                threadID: request.threadID,
                name: request.name
            )
            publishLibraryEvent(.threadChanged(threadID: request.threadID))
        } catch {
            throw CodexAppServerError.wrap(error, operation: "thread/name/set")
        }
    }

    /// Archives a stored thread.
    ///
    /// Most consumers should call `CodexThread.archive()` from an existing
    /// thread handle. This lower-level app-server method is useful when the
    /// caller owns only a thread identifier.
    public func archiveThread(_ request: ThreadArchiveRequest) async throws {
        try requireInitialized(for: "thread/archive")
        let historyStore = try requireHistoryStore(for: "thread/archive")

        let requestID = CodexRPCRequestID.generated()

        do {
            let payload = try protocolLayer.makeThreadArchiveRequest(
                id: requestID,
                params: .init(threadID: request.threadID)
            )
            let response = try await transport.send(payload, id: requestID)
            _ = try protocolLayer.decodeThreadArchiveResponse(
                response,
                expectedID: requestID
            )
            try await historyStore.recordThreadArchived(
                threadID: request.threadID,
                isArchived: true
            )
            publishLibraryEvent(.threadChanged(threadID: request.threadID))
        } catch {
            throw CodexAppServerError.wrap(error, operation: "thread/archive")
        }
    }

    /// Unarchives a stored thread and returns refreshed thread metadata.
    ///
    /// Most consumers should call `CodexThread.unarchive()` from an existing
    /// thread handle. This lower-level app-server method is useful when the
    /// caller owns only a thread identifier.
    @discardableResult
    public func unarchiveThread(_ request: ThreadArchiveRequest) async throws -> ThreadInfo {
        try requireInitialized(for: "thread/unarchive")
        let historyStore = try requireHistoryStore(for: "thread/unarchive")

        let requestID = CodexRPCRequestID.generated()

        do {
            let payload = try protocolLayer.makeThreadUnarchiveRequest(
                id: requestID,
                params: .init(threadID: request.threadID)
            )
            let responsePayload = try await transport.send(payload, id: requestID)
            let response = try protocolLayer.decodeThreadUnarchiveResponse(
                responsePayload,
                expectedID: requestID
            )
            let thread = ThreadInfo(wireValue: response.thread)
            try await historyStore.recordThreadMetadataUpdated(thread)
            try await historyStore.recordThreadArchived(
                threadID: thread.id,
                isArchived: false
            )
            publishLibraryEvent(.threadChanged(threadID: thread.id))

            return thread
        } catch {
            throw CodexAppServerError.wrap(error, operation: "thread/unarchive")
        }
    }

    /// Patches stored thread metadata and returns refreshed thread metadata.
    ///
    /// Field updates distinguish values to replace, values to clear, and values
    /// to leave unchanged so callers can express the app-server's null-versus-
    /// omitted behavior without using generated wire types.
    public func updateThreadMetadata(_ request: ThreadMetadataUpdateRequest) async throws -> ThreadInfo {
        try requireInitialized(for: "thread/metadata/update")

        let requestID = CodexRPCRequestID.generated()

        do {
            let payload = try protocolLayer.makeThreadMetadataUpdateRequest(
                id: requestID,
                params: request.protocolValue
            )
            let responsePayload = try await transport.send(payload, id: requestID)
            let response = try protocolLayer.decodeThreadMetadataUpdateResponse(
                responsePayload,
                expectedID: requestID
            )
            let thread = ThreadInfo(wireValue: response.thread)
            try await requireHistoryStore(for: "thread/metadata/update").recordThreadMetadataUpdated(thread)
            publishLibraryEvent(.threadChanged(threadID: thread.id))

            return thread
        } catch {
            throw CodexAppServerError.wrap(error, operation: "thread/metadata/update")
        }
    }

    /// Reads a page of stored Codex threads.
    ///
    /// Omitting `request` sends an empty thread-list request, leaving page
    /// size, sort order, filters, and archive visibility to the app-server.
    /// Reads a page of stored thread snapshots from the app-server.
    ///
    /// Omitting `request` sends an empty list request, leaving filters, sort
    /// order, and page size to the app-server defaults.
    public func listThreads(_ request: ThreadListRequest = .init()) async throws -> ThreadListPage {
        try requireInitialized(for: "thread/list")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeThreadListRequest(
                id: requestID,
                params: .init(
                    archived: request.archived,
                    cursor: request.cursor,
                    cwd: request.currentDirectoryPath,
                    limit: request.limit,
                    modelProviders: request.modelProviders,
                    searchTerm: request.searchTerm,
                    sortDirection: request.sortDirection.map(CodexProtocolThreadListSortDirection.init),
                    sortKey: request.sortKey.map(CodexProtocolThreadListSortKey.init),
                    sourceKinds: request.sourceKinds?.map(CodexProtocolThreadListSourceKind.init)
                )
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeThreadListResponse(
                responsePayload,
                expectedID: requestID
            )

            let threads = response.data.map(ThreadInfo.init(wireValue:))
            try await requireHistoryStore(for: "thread/list").reconcileThreadListPage(
                threads,
                archived: request.archived
            )

            return .init(
                nextCursor: response.nextCursor,
                threads: threads
            )
        } catch {
            throw CodexAppServerError.wrap(error, operation: "thread/list")
        }
    }

    /// Reads a page of stored Codex threads from a SwiftASB query descriptor.
    ///
    /// This overload compiles `query` into the app-server `thread/list` request
    /// shape. Use `CodexAppServer.Library` when the same descriptor should load
    /// local history snapshots first and reconcile app-server pages in the
    /// background.
    public func listThreads(
        _ query: ThreadListQD,
        cursor: String? = nil
    ) async throws -> ThreadListPage {
        try await listThreads(query.threadListRequest(cursor: cursor))
    }

    /// Lists thread ids currently loaded in the app-server runtime.
    public func listLoadedThreads(_ request: LoadedThreadListRequest = .init()) async throws -> LoadedThreadListPage {
        try requireInitialized(for: "thread/loaded/list")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeThreadLoadedListRequest(
                id: requestID,
                params: .init(cursor: request.cursor, limit: request.limit)
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeThreadLoadedListResponse(
                responsePayload,
                expectedID: requestID
            )

            return .init(nextCursor: response.nextCursor, threadIDs: response.data)
        } catch {
            throw CodexAppServerError.wrap(error, operation: "thread/loaded/list")
        }
    }

    func readThreadGoal(threadID: String) async throws -> CodexThread.Goal? {
        try requireInitialized(for: "thread/goal/get")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeThreadGoalGetRequest(
                id: requestID,
                params: .init(threadID: threadID)
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeThreadGoalGetResponse(
                responsePayload,
                expectedID: requestID
            )

            return response.goal.map(CodexThread.Goal.init(wireValue:))
        } catch {
            throw CodexAppServerError.wrap(error, operation: "thread/goal/get")
        }
    }

    func setThreadGoal(
        threadID: String,
        request: CodexThread.GoalSetRequest
    ) async throws -> CodexThread.Goal {
        try requireInitialized(for: "thread/goal/set")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeThreadGoalSetRequest(
                id: requestID,
                params: .init(
                    objective: request.objective,
                    status: request.status?.wireValue,
                    threadID: threadID,
                    tokenBudget: request.tokenBudget
                )
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeThreadGoalSetResponse(
                responsePayload,
                expectedID: requestID
            )

            return .init(wireValue: response.goal)
        } catch {
            throw CodexAppServerError.wrap(error, operation: "thread/goal/set")
        }
    }

    func clearThreadGoal(threadID: String) async throws -> Bool {
        try requireInitialized(for: "thread/goal/clear")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeThreadGoalClearRequest(
                id: requestID,
                params: .init(threadID: threadID)
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeThreadGoalClearResponse(
                responsePayload,
                expectedID: requestID
            )

            return response.cleared
        } catch {
            throw CodexAppServerError.wrap(error, operation: "thread/goal/clear")
        }
    }

    func readFSMetadata(_ request: CodexFS.MetadataRequest) async throws -> CodexFS.Metadata {
        try requireInitialized(for: "fs/getMetadata")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeFSGetMetadataRequest(
                id: requestID,
                params: .init(path: request.path)
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeFSGetMetadataResponse(
                responsePayload,
                expectedID: requestID
            )

            return .init(wireValue: response)
        } catch {
            throw CodexAppServerError.wrap(error, operation: "fs/getMetadata")
        }
    }

    func readFSDirectory(_ request: CodexFS.DirectoryReadRequest) async throws -> CodexFS.DirectoryReadResult {
        try requireInitialized(for: "fs/readDirectory")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeFSReadDirectoryRequest(
                id: requestID,
                params: .init(path: request.path)
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeFSReadDirectoryResponse(
                responsePayload,
                expectedID: requestID
            )

            return .init(wireValue: response)
        } catch {
            throw CodexAppServerError.wrap(error, operation: "fs/readDirectory")
        }
    }

    func readFSFile(_ request: CodexFS.FileReadRequest) async throws -> CodexFS.FileReadResult {
        try requireInitialized(for: "fs/readFile")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeFSReadFileRequest(
                id: requestID,
                params: .init(path: request.path)
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeFSReadFileResponse(
                responsePayload,
                expectedID: requestID
            )

            guard let data = Data(base64Encoded: response.dataBase64) else {
                throw CodexAppServerError.protocolFailure(
                    operation: "fs/readFile",
                    reason: "The app-server returned file contents that were not valid base64."
                )
            }

            return .init(data: data)
        } catch {
            throw CodexAppServerError.wrap(error, operation: "fs/readFile")
        }
    }

    func watchFSChanges(_ request: CodexFS.WatchRequest) async throws -> CodexFS.Watch {
        try requireInitialized(for: "fs/watch")

        let requestID = CodexRPCRequestID.generated()
        let watchID = request.watchID ?? UUID().uuidString

        do {
            let events = fsChangeStream(watchID: watchID)
            let requestPayload = try protocolLayer.makeFSWatchRequest(
                id: requestID,
                params: .init(path: request.path, watchID: watchID)
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeFSWatchResponse(
                responsePayload,
                expectedID: requestID
            )

            return .init(events: events, path: response.path, watchID: watchID)
        } catch {
            removeFSChangeContinuations(watchID: watchID)
            throw CodexAppServerError.wrap(error, operation: "fs/watch")
        }
    }

    func unwatchFSChanges(_ request: CodexFS.UnwatchRequest) async throws {
        try requireInitialized(for: "fs/unwatch")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeFSUnwatchRequest(
                id: requestID,
                params: .init(watchID: request.watchID)
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            _ = try protocolLayer.decodeFSUnwatchResponse(
                responsePayload,
                expectedID: requestID
            )
            removeFSChangeContinuations(watchID: request.watchID)
        } catch {
            throw CodexAppServerError.wrap(error, operation: "fs/unwatch")
        }
    }

    func readConfig(_ request: CodexConfig.ReadRequest) async throws -> CodexConfig.Snapshot {
        try requireInitialized(for: "config/read")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeConfigReadRequest(
                id: requestID,
                params: .init(
                    cwd: request.currentDirectoryPath,
                    includeLayers: request.includeLayers
                )
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeConfigReadResponse(
                responsePayload,
                expectedID: requestID
            )

            return try .init(wireValue: response)
        } catch {
            throw CodexAppServerError.wrap(error, operation: "config/read")
        }
    }

    func readConfigRequirements() async throws -> CodexConfig.RequirementsSnapshot {
        try requireInitialized(for: "configRequirements/read")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeConfigRequirementsReadRequest(id: requestID)
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeConfigRequirementsReadResponse(
                responsePayload,
                expectedID: requestID
            )

            return try .init(wireValue: response)
        } catch {
            throw CodexAppServerError.wrap(error, operation: "configRequirements/read")
        }
    }

    func listExtensionApps(
        _ request: CodexExtensions.AppListRequest
    ) async throws -> CodexExtensions.AppListPage {
        try requireInitialized(for: "app/list")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeAppListRequest(
                id: requestID,
                params: .init(
                    cursor: request.cursor,
                    forceRefetch: request.forceRefetch,
                    limit: request.limit,
                    threadID: request.threadID
                )
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeAppListResponse(
                responsePayload,
                expectedID: requestID
            )

            return .init(wireValue: response)
        } catch {
            throw CodexAppServerError.wrap(error, operation: "app/list")
        }
    }

    func listExtensionSkills(
        _ request: CodexExtensions.SkillListRequest
    ) async throws -> CodexExtensions.SkillListSnapshot {
        try requireInitialized(for: "skills/list")
        if request.perCurrentDirectoryExtraUserRoots != nil {
            throw CodexAppServerError.invalidState(
                reason: "Codex CLI 0.130.0 removed per-cwd extra user roots from skills/list; pass currentDirectoryPaths and forceReload only."
            )
        }

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeSkillsListRequest(
                id: requestID,
                params: .init(
                    cwds: request.currentDirectoryPaths,
                    forceReload: request.forceReload
                )
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeSkillsListResponse(
                responsePayload,
                expectedID: requestID
            )

            return .init(wireValue: response)
        } catch {
            throw CodexAppServerError.wrap(error, operation: "skills/list")
        }
    }

    func listExtensionPlugins(
        _ request: CodexExtensions.PluginListRequest
    ) async throws -> CodexExtensions.PluginListSnapshot {
        try requireInitialized(for: "plugin/list")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makePluginListRequest(
                id: requestID,
                params: .init(cwds: request.currentDirectoryPaths, marketplaceKinds: nil)
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodePluginListResponse(
                responsePayload,
                expectedID: requestID
            )

            return .init(wireValue: response)
        } catch {
            throw CodexAppServerError.wrap(error, operation: "plugin/list")
        }
    }

    func readExtensionPlugin(
        _ request: CodexExtensions.PluginReadRequest
    ) async throws -> CodexExtensions.PluginDetail {
        try requireInitialized(for: "plugin/read")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makePluginReadRequest(
                id: requestID,
                params: .init(
                    marketplacePath: request.marketplacePath,
                    pluginName: request.pluginName,
                    remoteMarketplaceName: request.remoteMarketplaceName
                )
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodePluginReadResponse(
                responsePayload,
                expectedID: requestID
            )

            return .init(wireValue: response.plugin)
        } catch {
            throw CodexAppServerError.wrap(error, operation: "plugin/read")
        }
    }

    func listExtensionCollaborationModes() async throws -> CodexExtensions.CollaborationModeList {
        try requireInitialized(for: "collaborationMode/list")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeCollaborationModeListRequest(
                id: requestID,
                params: .init()
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeCollaborationModeListResponse(
                responsePayload,
                expectedID: requestID
            )

            return .init(wireValue: response)
        } catch {
            throw CodexAppServerError.wrap(error, operation: "collaborationMode/list")
        }
    }

    /// Reads a stored thread snapshot and optionally includes turns.
    ///
    /// Returned turns are hydrated into SwiftASB's local history store so later
    /// thread-scoped history helpers can read the same completed-turn data.
    public func readThread(_ request: ThreadReadRequest) async throws -> ThreadReadResult {
        try requireInitialized(for: "thread/read")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeThreadReadRequest(
                id: requestID,
                params: .init(
                    includeTurns: request.includeTurns ? true : nil,
                    threadID: request.threadID
                )
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeThreadReadResponse(
                responsePayload,
                expectedID: requestID
            )

            let thread = ThreadInfo(wireValue: response.thread)
            let turns = response.thread.turns.map(TurnInfo.init(wireValue:))
            if request.includeTurns {
                try await requireHistoryStore(for: "thread/read").hydrateThreadRead(
                    thread: thread,
                    turns: response.thread.turns.map {
                        .init(
                            turn: .init(wireValue: $0),
                            items: $0.items.map(CodexTurnItem.init(wireValue:))
                        )
                    }
                )
            } else {
                try await requireHistoryStore(for: "thread/read").recordThreadMetadataUpdated(thread)
            }

            return .init(thread: thread, turns: turns)
        } catch {
            throw CodexAppServerError.wrap(error, operation: "thread/read")
        }
    }

    /// Reads a page of turns for a stored thread directly from the app-server.
    ///
    /// This low-level paging API surfaces app-server errors as failures. Recent
    /// observable companions use a narrower startup fallback for known
    /// history-unavailable responses.
    public func listThreadTurns(_ request: ThreadTurnsListRequest) async throws -> ThreadTurnsPage {
        try requireInitialized(for: "thread/turns/list")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeThreadTurnsListRequest(
                id: requestID,
                params: .init(
                    cursor: request.cursor,
                    itemsView: request.itemsView.map(CodexWireTurnItemsView.init),
                    limit: request.limit,
                    sortDirection: request.sortDirection.map(CodexProtocolThreadTurnsSortDirection.init),
                    threadID: request.threadID
                )
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeThreadTurnsListResponse(
                responsePayload,
                expectedID: requestID
            )

            try await requireHistoryStore(for: "thread/turns/list").hydrateHistoricalTurns(
                threadID: request.threadID,
                turns: response.data.map {
                    .init(
                        turn: .init(wireValue: $0),
                        items: $0.items.map(CodexTurnItem.init(wireValue:))
                    )
                }
            )

            return .init(
                backwardsCursor: response.backwardsCursor,
                nextCursor: response.nextCursor,
                turns: response.data.map(TurnInfo.init(wireValue:))
            )
        } catch {
            throw CodexAppServerError.wrap(error, operation: "thread/turns/list")
        }
    }

    /// Reads a page of stored items for one turn directly from the app-server.
    ///
    /// This low-level paging API returns app-server item snapshots without
    /// assuming the caller has loaded the full containing turn. Paged item reads
    /// do not mutate SwiftASB's local history store because a single item page
    /// does not carry enough information to safely reconcile whole-turn item
    /// ordering.
    public func listThreadTurnItems(_ request: ThreadTurnsItemsListRequest) async throws -> ThreadTurnsItemsPage {
        try requireInitialized(for: "thread/turns/items/list")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeThreadTurnsItemsListRequest(
                id: requestID,
                params: .init(
                    cursor: request.cursor,
                    limit: request.limit,
                    sortDirection: request.sortDirection.map(CodexWireSortDirection.init),
                    threadID: request.threadID,
                    turnID: request.turnID
                )
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeThreadTurnsItemsListResponse(
                responsePayload,
                expectedID: requestID
            )

            return .init(
                backwardsCursor: response.backwardsCursor,
                items: response.data.map(CodexTurnItem.init(wireValue:)),
                nextCursor: response.nextCursor
            )
        } catch {
            throw CodexAppServerError.wrap(error, operation: "thread/turns/items/list")
        }
    }

    /// Starts a turn from an app-server-owned request.
    ///
    /// Most consumers should prefer `CodexThread.startTurn(_:)` or
    /// `CodexThread.startTextTurn(...)` so the thread identity and defaults are
    /// supplied by the thread handle.
    public func startTurn(_ request: TurnStartRequest) async throws -> CodexTurnHandle {
        try requireInitialized(for: "turn/start")
        try reserveThreadForTurnStart(threadID: request.threadID)

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeTurnStartRequest(
                id: requestID,
                params: request.wireValue
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeTurnStartResponse(
                responsePayload,
                expectedID: requestID
            )

            let turn = TurnInfo(wireValue: response.turn)
            markThreadTurnActive(threadID: request.threadID, turnID: turn.id)
            try await requireHistoryStore(for: "turn/start").recordTurnStarted(threadID: request.threadID, turn: turn)
            let eventStream = makeTurnEventStream(turnID: turn.id)
            let minimapStream = makeTurnEventStream(turnID: turn.id)
            let minimap = await MainActor.run {
                CodexTurnHandle.Minimap(
                    threadID: request.threadID,
                    initialTurn: turn,
                    events: minimapStream
                )
            }
            return CodexTurnHandle(
                appServer: self,
                threadID: request.threadID,
                turn: turn,
                events: eventStream,
                minimap: minimap
            )
        } catch {
            clearThreadTurnReservation(threadID: request.threadID)
            throw CodexAppServerError.wrap(error, operation: "turn/start")
        }
    }

    internal func interruptTurn(
        threadID: String,
        turnID: String
    ) async throws {
        try requireInitialized(for: "turn/interrupt")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeTurnInterruptRequest(
                id: requestID,
                params: .init(threadID: threadID, turnID: turnID)
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            _ = try protocolLayer.decodeTurnInterruptResponse(
                responsePayload,
                expectedID: requestID
            )
        } catch {
            throw CodexAppServerError.wrap(error, operation: "turn/interrupt")
        }
    }

    internal func steerTurn(
        threadID: String,
        turnID: String,
        input: [TurnInput]
    ) async throws {
        try requireInitialized(for: "turn/steer")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeTurnSteerRequest(
                id: requestID,
                params: .init(
                    expectedTurnID: turnID,
                    input: input.map(\.wireValue),
                    threadID: threadID
                )
            )
            let responsePayload = try await transport.send(requestPayload, id: requestID)
            let response = try protocolLayer.decodeTurnSteerResponse(
                responsePayload,
                expectedID: requestID
            )

            guard response.turnID == turnID else {
                throw CodexAppServerError.invalidState(
                    reason: "Codex app-server acknowledged turn steering for turn \(response.turnID), but this handle owns turn \(turnID)."
                )
            }
        } catch {
            throw CodexAppServerError.wrap(error, operation: "turn/steer")
        }
    }

    internal func threadEventStream(
        threadID: String
    ) -> AsyncThrowingStream<CodexThreadEvent, Error> {
        makeThreadEventStream(threadID: threadID)
    }

    internal func threadStatus(threadID: String) -> ThreadStatus? {
        threadStatuses[threadID]
    }

    internal func turnEventStream(
        turnID: String
    ) -> AsyncThrowingStream<CodexTurnEvent, Error> {
        makeTurnEventStream(turnID: turnID)
    }

    internal func threadTurnEventStream(
        threadID: String
    ) -> AsyncThrowingStream<CodexTurnEvent, Error> {
        makeThreadTurnEventStream(threadID: threadID)
    }

    internal func unresolvedInteractiveTurnIDs(threadID: String) -> Set<String> {
        Set(
            outstandingInteractiveRequests.values.compactMap { request in
                guard request.threadID == threadID else { return nil }
                return request.turnID
            }
        )
    }

    internal func threadObservableActivityState(threadID: String) -> CodexThread.Dashboard.ActivityState {
        let state = threadObservableActivityStates[threadID] ?? .init()
        return .init(
            activeMcpItemIDs: state.activeMcpItemIDs,
            activeToolLikeItemIDs: state.activeToolLikeItemIDs,
            hasMcpErrorResidue: state.hasMcpErrorResidue,
            hookRuns: state.hookRuns,
            hasToolErrorResidue: state.hasToolErrorResidue,
            isCompactingThreadContext: state.isCompactingThreadContext
        )
    }

    internal func threadObservableActivityStream(
        threadID: String
    ) -> AsyncStream<CodexThread.Dashboard.ActivityState> {
        let streamID = UUID()

        return AsyncStream { continuation in
            var continuations = threadObservableActivityContinuations[threadID] ?? [:]
            continuations[streamID] = continuation
            threadObservableActivityContinuations[threadID] = continuations
            continuation.yield(threadObservableActivityState(threadID: threadID))

            continuation.onTermination = { _ in
                Task {
                    await self.removeThreadObservableActivityContinuation(
                        streamID: streamID,
                        threadID: threadID
                    )
                }
            }
        }
    }

    internal func threadFileChangeOutputDeltaStream(
        threadID: String
    ) -> AsyncStream<FileChangeOutputDeltaEvent> {
        let streamID = UUID()

        return AsyncStream { continuation in
            var continuations = threadFileDeltaContinuations[threadID] ?? [:]
            continuations[streamID] = continuation
            threadFileDeltaContinuations[threadID] = continuations

            continuation.onTermination = { _ in
                Task {
                    await self.removeThreadFileDeltaContinuation(
                        streamID: streamID,
                        threadID: threadID
                    )
                }
            }
        }
    }

    internal func threadCommandExecutionOutputDeltaStream(
        threadID: String
    ) -> AsyncStream<CommandExecutionOutputDeltaEvent> {
        let streamID = UUID()

        return AsyncStream { continuation in
            var continuations = threadCommandDeltaContinuations[threadID] ?? [:]
            continuations[streamID] = continuation
            threadCommandDeltaContinuations[threadID] = continuations

            continuation.onTermination = { _ in
                Task {
                    await self.removeThreadCommandDeltaContinuation(
                        streamID: streamID,
                        threadID: threadID
                    )
                }
            }
        }
    }

    internal func libraryEvents() -> AsyncStream<LibraryEvent> {
        let streamID = UUID()

        return AsyncStream { continuation in
            libraryEventContinuations[streamID] = continuation

            continuation.onTermination = { _ in
                Task {
                    await self.removeLibraryEventContinuation(streamID: streamID)
                }
            }
        }
    }

    internal func publishFeatureOperationEvent(_ event: SwiftASBFeatureOperationEvent) {
        bufferedFeatureOperationEvents.append(event)
        if bufferedFeatureOperationEvents.count > 100 {
            bufferedFeatureOperationEvents.removeFirst(bufferedFeatureOperationEvents.count - 100)
        }

        guard !featureOperationEventContinuations.isEmpty else {
            return
        }

        for continuation in featureOperationEventContinuations.values {
            continuation.yield(event)
        }
    }

    internal func fsChangeStream(watchID: String) -> AsyncStream<CodexFS.ChangeEvent> {
        let streamID = UUID()

        return AsyncStream { continuation in
            var continuations = fsChangeContinuations[watchID] ?? [:]
            continuations[streamID] = continuation
            fsChangeContinuations[watchID] = continuations

            continuation.onTermination = { _ in
                Task {
                    await self.removeFSChangeContinuation(streamID: streamID, watchID: watchID)
                }
            }
        }
    }

    internal func debugThreadHistorySnapshot(
        threadID: String
    ) async throws -> ThreadHistoryStore.ThreadSnapshot? {
        try await requireHistoryStore(for: "thread history snapshot").snapshot(threadID: threadID)
    }

    internal func libraryThreadSnapshots(
        query: ThreadListQD
    ) async throws -> [Library.ThreadSnapshot] {
        let historyStore = try requireHistoryStore(for: "library thread snapshots")
        return try await historyStore.threadListSnapshots()
            .map(Library.ThreadSnapshot.init)
            .filter { thread in
                if let archived = query.archived, thread.isArchived != archived {
                    return false
                }
                if let currentDirectoryPath = query.currentDirectoryPath,
                   thread.currentDirectoryPath != currentDirectoryPath {
                    return false
                }
                if let modelProviders = query.modelProviders,
                   !modelProviders.isEmpty,
                   !modelProviders.contains(thread.modelProvider) {
                    return false
                }
                if let searchTerm = query.searchTerm?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !searchTerm.isEmpty {
                    let haystack = [
                        thread.name ?? "",
                        thread.preview,
                        thread.currentDirectoryPath,
                    ].joined(separator: "\n")
                    return haystack.localizedCaseInsensitiveContains(searchTerm)
                }
                return true
            }
    }

    internal func reconcileLibraryThreads(
        query: ThreadListQD,
        archived: Bool,
        maxPages: Int
    ) async throws {
        var cursor: String?
        let pageCount = max(1, maxPages)
        for _ in 0..<pageCount {
            try Task.checkCancellation()
            let page = try await listThreads(
                query.threadListRequest(
                    archived: archived,
                    cursor: cursor
                )
            )
            cursor = page.nextCursor
            if cursor == nil {
                break
            }
            await Task.yield()
        }
    }

    internal func recentClosedTurnWindow(
        threadID: String,
        limit: Int
    ) async throws -> CodexThread.HistoryWindow {
        let historyStore = try requireHistoryStore(for: "recent turn history")
        if let threadSnapshot = try await historyStore.snapshot(threadID: threadID) {
            let orderedTurns = orderedClosedTurnSnapshots(from: threadSnapshot.turns)
            if !orderedTurns.isEmpty {
                let turns = orderedTurns
                    .prefix(max(1, limit))
                    .map { CodexTurnHandle.ClosedTurn(threadID: threadID, snapshot: $0) }
                return CodexThread.HistoryWindow(
                    threadID: threadID,
                    turns: turns,
                    hasOlderTurns: orderedTurns.count > turns.count,
                    hasNewerTurns: false
                )
            }
        }

        let window = try await recentTurnWindow(threadID: threadID, limit: limit)
        return CodexThread.HistoryWindow(
            threadID: threadID,
            turns: window.turns.map { .init(threadID: threadID, snapshot: $0) },
            hasOlderTurns: window.nextOlderCursor != nil,
            hasNewerTurns: window.nextNewerCursor != nil
        )
    }

    internal func recentClosedTurns(
        threadID: String,
        limit: Int
    ) async throws -> [CodexTurnHandle.ClosedTurn] {
        try await recentClosedTurnWindow(threadID: threadID, limit: limit).turns
    }

    internal func olderClosedTurnWindow(
        threadID: String,
        olderThan turnID: String,
        limit: Int
    ) async throws -> CodexThread.HistoryWindow {
        let historyStore = try requireHistoryStore(for: "older turn history")
        guard let threadSnapshot = try await historyStore.snapshot(threadID: threadID) else {
            throw CodexAppServerError.invalidState(
                reason: """
                SwiftASB could not read older turn history before turn \(turnID) because thread \(threadID) does not currently have a readable local history snapshot. Load recent or stored history for the thread before paging older local history around a boundary turn.
                """
            )
        }
        let orderedTurns = orderedClosedTurnSnapshots(from: threadSnapshot.turns)
        guard let boundaryIndex = orderedTurns.firstIndex(where: { $0.id == turnID }) else {
            throw CodexAppServerError.invalidState(
                reason: """
                SwiftASB could not read older turn history before turn \(turnID) because that turn is not currently present in the local history store for thread \(threadID). Load recent or stored history that includes the boundary turn before paging older local history around it.
                """
            )
        }

        let turns = orderedTurns
            .suffix(from: orderedTurns.index(after: boundaryIndex))
            .prefix(limit)
            .map { CodexTurnHandle.ClosedTurn(threadID: threadID, snapshot: $0) }
        return CodexThread.HistoryWindow(
            threadID: threadID,
            turns: turns,
            hasOlderTurns: orderedTurns.index(boundaryIndex, offsetBy: turns.count + 1) < orderedTurns.endIndex,
            hasNewerTurns: true
        )
    }

    internal func olderClosedTurns(
        threadID: String,
        olderThan turnID: String,
        limit: Int
    ) async throws -> [CodexTurnHandle.ClosedTurn] {
        try await olderClosedTurnWindow(threadID: threadID, olderThan: turnID, limit: limit).turns
    }

    internal func newerClosedTurnWindow(
        threadID: String,
        newerThan turnID: String,
        limit: Int
    ) async throws -> CodexThread.HistoryWindow {
        let historyStore = try requireHistoryStore(for: "newer turn history")
        guard let threadSnapshot = try await historyStore.snapshot(threadID: threadID) else {
            throw CodexAppServerError.invalidState(
                reason: """
                SwiftASB could not read newer turn history after turn \(turnID) because thread \(threadID) does not currently have a readable local history snapshot. Load recent or stored history for the thread before paging newer local history around a boundary turn.
                """
            )
        }
        let orderedTurns = orderedClosedTurnSnapshots(from: threadSnapshot.turns)
        guard let boundaryIndex = orderedTurns.firstIndex(where: { $0.id == turnID }) else {
            throw CodexAppServerError.invalidState(
                reason: """
                SwiftASB could not read newer turn history after turn \(turnID) because that turn is not currently present in the local history store for thread \(threadID). Load recent or stored history that includes the boundary turn before paging newer local history around it.
                """
            )
        }

        let newerCandidates = orderedTurns.prefix(boundaryIndex)
        let turns = newerCandidates
            .suffix(limit)
            .map { CodexTurnHandle.ClosedTurn(threadID: threadID, snapshot: $0) }
        return CodexThread.HistoryWindow(
            threadID: threadID,
            turns: turns,
            hasOlderTurns: true,
            hasNewerTurns: newerCandidates.count > turns.count
        )
    }

    internal func newerClosedTurns(
        threadID: String,
        newerThan turnID: String,
        limit: Int
    ) async throws -> [CodexTurnHandle.ClosedTurn] {
        try await newerClosedTurnWindow(threadID: threadID, newerThan: turnID, limit: limit).turns
    }

    internal func closedTurnWindowAroundTurn(
        threadID: String,
        turnID: String,
        limit: Int
    ) async throws -> CodexThread.HistoryWindow {
        let historyStore = try requireHistoryStore(for: "turn-centered history window")
        guard let threadSnapshot = try await historyStore.snapshot(threadID: threadID) else {
            throw CodexAppServerError.invalidState(
                reason: """
                SwiftASB could not read a local history window around turn \(turnID) because thread \(threadID) does not currently have a readable local history snapshot. Load recent or stored history for the thread before reading a centered local history window.
                """
            )
        }

        let orderedTurns = orderedClosedTurnSnapshots(from: threadSnapshot.turns)
        guard let boundaryIndex = orderedTurns.firstIndex(where: { $0.id == turnID }) else {
            throw CodexAppServerError.invalidState(
                reason: """
                SwiftASB could not read a local history window around turn \(turnID) because that turn is not currently present in the local history store for thread \(threadID). Load recent or stored history that includes the boundary turn before reading a centered local history window.
                """
            )
        }

        return closedTurnWindow(
            threadID: threadID,
            orderedTurns: orderedTurns,
            around: boundaryIndex,
            limit: limit
        )
    }

    internal func closedTurnWindowAroundItem(
        threadID: String,
        itemID: String,
        limit: Int
    ) async throws -> CodexThread.HistoryWindow {
        let historyStore = try requireHistoryStore(for: "item-centered history window")
        guard let threadSnapshot = try await historyStore.snapshot(threadID: threadID) else {
            throw CodexAppServerError.invalidState(
                reason: """
                SwiftASB could not read a local history window around item \(itemID) because thread \(threadID) does not currently have a readable local history snapshot. Load recent or stored history for the thread before reading a centered local history window.
                """
            )
        }

        let orderedTurns = orderedClosedTurnSnapshots(from: threadSnapshot.turns)
        guard let boundaryIndex = orderedTurns.firstIndex(where: { turn in
            turn.items.contains { $0.id == itemID }
        }) else {
            throw CodexAppServerError.invalidState(
                reason: """
                SwiftASB could not read a local history window around item \(itemID) because that item is not currently present in the local history store for thread \(threadID). Load recent or stored history that includes the item before reading a centered local history window.
                """
            )
        }

        return closedTurnWindow(
            threadID: threadID,
            orderedTurns: orderedTurns,
            around: boundaryIndex,
            limit: limit
        )
    }

    internal func recentTurnSnapshots(
        threadID: String,
        limit: Int
    ) async throws -> [ThreadHistoryStore.ThreadSnapshot.TurnSnapshot] {
        try await recentTurnWindow(threadID: threadID, limit: limit).turns
    }

    internal func recentTurnWindow(
        threadID: String,
        limit: Int
    ) async throws -> RecentTurnWindowResult {
        let historyStore = try requireHistoryStore(for: "recent turn history")
        let localTurns = try await historyStore.recentTurnSnapshots(threadID: threadID, limit: limit)
        if !localTurns.isEmpty {
            let seededRemotePage = try? await listThreadTurns(
                .init(
                    threadID: threadID,
                    limit: limit,
                    sortDirection: .desc
                )
            )
            return .init(
                turns: localTurns,
                nextOlderCursor: seededRemotePage?.nextCursor,
                nextNewerCursor: seededRemotePage?.backwardsCursor
            )
        }

        let page: ThreadTurnsPage
        do {
            page = try await listThreadTurns(
                .init(
                    threadID: threadID,
                    limit: limit,
                    sortDirection: .desc
                )
            )
        } catch let error as CodexAppServerError where Self.isThreadTurnsHistoryUnavailable(error) {
            return .init(turns: [], nextOlderCursor: nil, nextNewerCursor: nil)
        }

        return .init(
            turns: try await historyStore.turnSnapshots(
                threadID: threadID,
                turnIDs: page.turns.map(\.id)
            ),
            nextOlderCursor: page.nextCursor,
            nextNewerCursor: page.backwardsCursor
        )
    }

    internal func olderTurnWindow(
        threadID: String,
        olderThanOrderIndex: Int,
        cursor: String?,
        limit: Int
    ) async throws -> RecentTurnWindowResult {
        let historyStore = try requireHistoryStore(for: "older turn window")
        let localTurns = try await historyStore.olderTurnSnapshots(
            threadID: threadID,
            olderThanOrderIndex: olderThanOrderIndex,
            limit: limit
        )
        if !localTurns.isEmpty {
            return .init(
                turns: localTurns,
                nextOlderCursor: cursor,
                nextNewerCursor: nil
            )
        }

        let page = try await listThreadTurns(
            .init(
                threadID: threadID,
                limit: limit,
                cursor: cursor,
                sortDirection: .desc
            )
        )

        return .init(
            turns: try await historyStore.turnSnapshots(
                threadID: threadID,
                turnIDs: page.turns.map(\.id)
            ),
            nextOlderCursor: page.nextCursor,
            nextNewerCursor: page.backwardsCursor
        )
    }

    internal func newerTurnWindow(
        threadID: String,
        newerThanOrderIndex: Int,
        cursor: String?,
        limit: Int
    ) async throws -> RecentTurnWindowResult {
        let historyStore = try requireHistoryStore(for: "newer turn window")
        let localTurns = try await historyStore.newerTurnSnapshots(
            threadID: threadID,
            newerThanOrderIndex: newerThanOrderIndex,
            limit: limit
        )
        if !localTurns.isEmpty {
            return .init(
                turns: localTurns,
                nextOlderCursor: nil,
                nextNewerCursor: cursor
            )
        }

        guard let cursor else {
            return .init(turns: [], nextOlderCursor: nil, nextNewerCursor: nil)
        }

        let page = try await listThreadTurns(
            .init(
                threadID: threadID,
                limit: limit,
                cursor: cursor,
                sortDirection: .desc
            )
        )

        return .init(
            turns: try await historyStore.turnSnapshots(
                threadID: threadID,
                turnIDs: page.turns.map(\.id)
            ),
            nextOlderCursor: page.nextCursor,
            nextNewerCursor: page.backwardsCursor
        )
    }

    internal func recentFileWindow(
        threadID: String,
        limit: Int
    ) async throws -> RecentFileWindowResult {
        guard limit > 0 else {
            return .init(files: [], nextOlderCursor: nil)
        }

        let turnBatchLimit = max(limit, 12)
        let historyStore = try requireHistoryStore(for: "recent file history")
        let localTurns = try await historyStore.recentTurnSnapshots(threadID: threadID, limit: turnBatchLimit)

        if !localTurns.isEmpty {
            var collected = makeRecentFileSnapshots(from: localTurns, threadID: threadID)
            var oldestTurnOrderIndex = localTurns.last?.orderIndex

            while collected.count < limit, let currentOldestTurnOrderIndex = oldestTurnOrderIndex {
                let olderTurns = try await historyStore.olderTurnSnapshots(
                    threadID: threadID,
                    olderThanOrderIndex: currentOldestTurnOrderIndex,
                    limit: turnBatchLimit
                )

                if olderTurns.isEmpty {
                    break
                }

                collected.append(contentsOf: makeRecentFileSnapshots(from: olderTurns, threadID: threadID))
                oldestTurnOrderIndex = olderTurns.last?.orderIndex
            }

            return .init(
                files: Array(collected.prefix(limit)),
                nextOlderCursor: try? await seedRemoteOlderCursor(
                    threadID: threadID,
                    limit: turnBatchLimit
                )
            )
        }

        var page = try await recentTurnWindow(threadID: threadID, limit: turnBatchLimit)
        var collected = makeRecentFileSnapshots(from: page.turns, threadID: threadID)
        var nextOlderCursor = page.nextOlderCursor

        while collected.count < limit,
              let cursor = nextOlderCursor,
              let oldestTurnOrderIndex = page.turns.last?.orderIndex {
            page = try await olderTurnWindow(
                threadID: threadID,
                olderThanOrderIndex: oldestTurnOrderIndex,
                cursor: cursor,
                limit: turnBatchLimit
            )

            if page.turns.isEmpty {
                nextOlderCursor = page.nextOlderCursor
                break
            }

            collected.append(contentsOf: makeRecentFileSnapshots(from: page.turns, threadID: threadID))
            nextOlderCursor = page.nextOlderCursor
        }

        return .init(
            files: Array(collected.prefix(limit)),
            nextOlderCursor: nextOlderCursor
        )
    }

    internal func recentCommandWindow(
        threadID: String,
        limit: Int
    ) async throws -> RecentCommandWindowResult {
        guard limit > 0 else {
            return .init(commands: [], nextOlderCursor: nil)
        }

        let turnBatchLimit = max(limit, 12)
        let historyStore = try requireHistoryStore(for: "recent command history")
        let localTurns = try await historyStore.recentTurnSnapshots(threadID: threadID, limit: turnBatchLimit)

        if !localTurns.isEmpty {
            var collected = makeRecentCommandSnapshots(from: localTurns, threadID: threadID)
            var oldestTurnOrderIndex = localTurns.last?.orderIndex

            while collected.count < limit, let currentOldestTurnOrderIndex = oldestTurnOrderIndex {
                let olderTurns = try await historyStore.olderTurnSnapshots(
                    threadID: threadID,
                    olderThanOrderIndex: currentOldestTurnOrderIndex,
                    limit: turnBatchLimit
                )

                if olderTurns.isEmpty {
                    break
                }

                collected.append(contentsOf: makeRecentCommandSnapshots(from: olderTurns, threadID: threadID))
                oldestTurnOrderIndex = olderTurns.last?.orderIndex
            }

            return .init(
                commands: Array(collected.prefix(limit)),
                nextOlderCursor: try? await seedRemoteOlderCursor(
                    threadID: threadID,
                    limit: turnBatchLimit
                )
            )
        }

        var page = try await recentTurnWindow(threadID: threadID, limit: turnBatchLimit)
        var collected = makeRecentCommandSnapshots(from: page.turns, threadID: threadID)
        var nextOlderCursor = page.nextOlderCursor

        while collected.count < limit,
              let cursor = nextOlderCursor,
              let oldestTurnOrderIndex = page.turns.last?.orderIndex {
            page = try await olderTurnWindow(
                threadID: threadID,
                olderThanOrderIndex: oldestTurnOrderIndex,
                cursor: cursor,
                limit: turnBatchLimit
            )

            if page.turns.isEmpty {
                nextOlderCursor = page.nextOlderCursor
                break
            }

            collected.append(contentsOf: makeRecentCommandSnapshots(from: page.turns, threadID: threadID))
            nextOlderCursor = page.nextOlderCursor
        }

        return .init(
            commands: Array(collected.prefix(limit)),
            nextOlderCursor: nextOlderCursor
        )
    }

    internal func olderFileWindow(
        threadID: String,
        olderThan oldestFile: RecentFileSnapshot,
        cursor: String?,
        limit: Int
    ) async throws -> RecentFileWindowResult {
        guard limit > 0 else {
            return .init(files: [], nextOlderCursor: cursor)
        }

        var collected: [RecentFileSnapshot] = []
        if let sameTurnSnapshot = try await turnSnapshot(threadID: threadID, turnID: oldestFile.turnID) {
            let olderFilesInSameTurn = makeRecentFileSnapshots(
                from: sameTurnSnapshot,
                threadID: threadID
            ).filter {
                $0.itemOrderIndex < oldestFile.itemOrderIndex
            }
            collected.append(contentsOf: olderFilesInSameTurn.prefix(limit))
        }

        var nextOlderCursor = cursor
        var oldestTurnOrderIndex = oldestFile.turnOrderIndex
        let turnBatchLimit = max(limit, 12)

        while collected.count < limit {
            let page = try await olderTurnWindow(
                threadID: threadID,
                olderThanOrderIndex: oldestTurnOrderIndex,
                cursor: nextOlderCursor,
                limit: turnBatchLimit
            )

            if page.turns.isEmpty {
                nextOlderCursor = page.nextOlderCursor
                break
            }

            collected.append(contentsOf: makeRecentFileSnapshots(from: page.turns, threadID: threadID))
            nextOlderCursor = page.nextOlderCursor
            oldestTurnOrderIndex = page.turns.last?.orderIndex ?? oldestTurnOrderIndex
        }

        return .init(
            files: Array(collected.prefix(limit)),
            nextOlderCursor: nextOlderCursor
        )
    }

    internal func olderCommandWindow(
        threadID: String,
        olderThan oldestCommand: RecentCommandSnapshot,
        cursor: String?,
        limit: Int
    ) async throws -> RecentCommandWindowResult {
        guard limit > 0 else {
            return .init(commands: [], nextOlderCursor: cursor)
        }

        var collected: [RecentCommandSnapshot] = []
        if let sameTurnSnapshot = try await turnSnapshot(threadID: threadID, turnID: oldestCommand.turnID) {
            let olderCommandsInSameTurn = makeRecentCommandSnapshots(
                from: sameTurnSnapshot,
                threadID: threadID
            ).filter {
                $0.itemOrderIndex < oldestCommand.itemOrderIndex
            }
            collected.append(contentsOf: olderCommandsInSameTurn.prefix(limit))
        }

        var nextOlderCursor = cursor
        var oldestTurnOrderIndex = oldestCommand.turnOrderIndex
        let turnBatchLimit = max(limit, 12)

        while collected.count < limit {
            let page = try await olderTurnWindow(
                threadID: threadID,
                olderThanOrderIndex: oldestTurnOrderIndex,
                cursor: nextOlderCursor,
                limit: turnBatchLimit
            )

            if page.turns.isEmpty {
                nextOlderCursor = page.nextOlderCursor
                break
            }

            collected.append(contentsOf: makeRecentCommandSnapshots(from: page.turns, threadID: threadID))
            nextOlderCursor = page.nextOlderCursor
            oldestTurnOrderIndex = page.turns.last?.orderIndex ?? oldestTurnOrderIndex
        }

        return .init(
            commands: Array(collected.prefix(limit)),
            nextOlderCursor: nextOlderCursor
        )
    }

    internal func turnSnapshot(
        threadID: String,
        turnID: String
    ) async throws -> ThreadHistoryStore.ThreadSnapshot.TurnSnapshot? {
        try await requireHistoryStore(for: "turn snapshot").turnSnapshot(threadID: threadID, turnID: turnID)
    }

    internal func closedTurn(
        threadID: String,
        turnID: String
    ) async throws -> CodexTurnHandle.ClosedTurn {
        let historyStore = try requireHistoryStore(for: "closed turn snapshot")
        guard let snapshot = try await historyStore.turnSnapshot(threadID: threadID, turnID: turnID) else {
            let reason = """
            SwiftASB could not close turn \(turnID) for thread \(threadID) because no persisted turn snapshot is available yet.
            Wait for `turn/completed` to arrive before closing the turn handle.
            """
            throw CodexAppServerError.invalidState(reason: reason)
        }

        guard snapshot.status == TurnStatus.completed.rawValue
            || snapshot.status == TurnStatus.failed.rawValue
            || snapshot.status == TurnStatus.interrupted.rawValue
        else {
            let reason = """
            SwiftASB cannot close turn \(turnID) for thread \(threadID) while it is still \(snapshot.status).
            Wait for a terminal turn status before calling `complete()`.
            """
            throw CodexAppServerError.invalidState(reason: reason)
        }

        releaseTurnObservation(turnID: turnID)
        return .init(threadID: threadID, snapshot: snapshot)
    }

    internal func respond(
        to request: CodexApprovalRequest,
        with response: CodexApprovalResponse,
        expectedThreadID: String,
        expectedTurnID: String?
    ) async throws {
        let requestID = request.requestID
        let outstandingRequest = try requireOutstandingInteractiveRequest(
            requestID: requestID,
            expectedThreadID: expectedThreadID,
            expectedTurnID: expectedTurnID
        )

        let payload: Data
        switch (request, response) {
        case (_, .commandExecution(let decision)) where outstandingRequest.kind == .commandExecutionApproval:
            payload = try protocolLayer.makeServerResponse(
                id: requestID,
                result: decision.protocolValue
            )
        case (_, .fileChange(let decision)) where outstandingRequest.kind == .fileChangeApproval:
            payload = try protocolLayer.makeServerResponse(
                id: requestID,
                result: CodexProtocolFileChangeApprovalDecisionPayload(decision: decision.rawValue)
            )
        case (_, .permissions(let grantedPermissions)) where outstandingRequest.kind == .permissionsApproval:
            payload = try protocolLayer.makeServerResponse(
                id: requestID,
                result: grantedPermissions.protocolValue
            )
        default:
            throw CodexAppServerError.invalidState(
                reason: "Interactive approval response kind did not match the outstanding request kind for request \(requestID.description)."
            )
        }

        do {
            try await transport.sendResponse(payload, requestID: requestID)
        } catch {
            throw CodexAppServerError.wrap(error, operation: "server request response")
        }
    }

    internal func respond(
        to request: CodexElicitationRequest,
        with response: CodexElicitationResponse,
        expectedThreadID: String,
        expectedTurnID: String?
    ) async throws {
        let requestID = request.requestID
        let outstandingRequest = try requireOutstandingInteractiveRequest(
            requestID: requestID,
            expectedThreadID: expectedThreadID,
            expectedTurnID: expectedTurnID
        )

        let payload: Data
        switch (request, response) {
        case (_, .toolUserInput(let answers)) where outstandingRequest.kind == .toolUserInput:
            payload = try protocolLayer.makeServerResponse(
                id: requestID,
                result: answers.protocolValue
            )
        case (_, .mcpServer(let elicitation)) where outstandingRequest.kind == .mcpServerElicitation:
            payload = try protocolLayer.makeServerResponse(
                id: requestID,
                result: elicitation.protocolValue
            )
        default:
            throw CodexAppServerError.invalidState(
                reason: "Interactive elicitation response kind did not match the outstanding request kind for request \(requestID.description)."
            )
        }

        do {
            try await transport.sendResponse(payload, requestID: requestID)
        } catch {
            throw CodexAppServerError.wrap(error, operation: "server request response")
        }
    }

    private func requireStarted(for operation: String) throws {
        guard hasStarted else {
            throw CodexAppServerError.invalidState(
                reason: "Codex app-server must be started before \(operation) can run."
            )
        }
    }

    private func requireInitialized(for operation: String) throws {
        try requireStarted(for: operation)
        guard hasCompletedInitializeHandshake else {
            throw CodexAppServerError.invalidState(
                reason: "Codex app-server must complete initialize(...) before \(operation) can run."
            )
        }
    }

    private func reserveThreadForTurnStart(threadID: String) throws {
        guard let existingActivity = threadTurnActivities[threadID] else {
            threadTurnActivities[threadID] = .starting
            return
        }

        let reason: String
        switch existingActivity {
        case .starting:
            reason = """
            Codex app-server already has another turn start in flight for thread \(threadID). \
            SwiftASB rejects overlapping same-thread turns because the live app-server does not \
            currently provide a reliable independent lifecycle for them.
            """
        case let .active(turnID):
            reason = """
            Codex app-server thread \(threadID) already has an active turn (\(turnID)). \
            SwiftASB rejects overlapping same-thread turns because the live app-server does not \
            currently provide a reliable independent lifecycle for them.
            """
        }

        throw CodexAppServerError.invalidState(reason: reason)
    }

    private func markThreadTurnActive(threadID: String, turnID: String) {
        threadTurnActivities[threadID] = .active(turnID: turnID)
        turnThreadIDs[turnID] = threadID
    }

    private func clearThreadTurnReservation(threadID: String) {
        threadTurnActivities.removeValue(forKey: threadID)
    }

    private func clearTurnActivity(turnID: String) {
        guard let threadID = turnThreadIDs.removeValue(forKey: turnID) else {
            return
        }

        if case let .active(activeTurnID)? = threadTurnActivities[threadID], activeTurnID == turnID {
            threadTurnActivities.removeValue(forKey: threadID)
        }
    }

    private func clearTurnActivities(threadID: String) {
        threadTurnActivities.removeValue(forKey: threadID)
        turnThreadIDs = turnThreadIDs.filter { $0.value != threadID }
    }

    private func settleThreadObservableActivity(threadID: String) {
        var state = threadObservableActivityStates[threadID] ?? .init()
        state.activeMcpItemIDs.removeAll()
        state.activeToolLikeItemIDs.removeAll()
        state.isCompactingThreadContext = false
        threadObservableActivityStates[threadID] = state
        publishThreadObservableActivityState(threadID: threadID)
    }

    private func finishThreadObservableActivityStreams(threadID: String) {
        guard let continuations = threadObservableActivityContinuations.removeValue(forKey: threadID)?.values else {
            return
        }

        for continuation in continuations {
            continuation.finish()
        }
    }

    private func finishThreadFileDeltaStreams(threadID: String) {
        guard let continuations = threadFileDeltaContinuations.removeValue(forKey: threadID)?.values else {
            return
        }

        for continuation in continuations {
            continuation.finish()
        }
    }

    private func finishThreadCommandDeltaStreams(threadID: String) {
        guard let continuations = threadCommandDeltaContinuations.removeValue(forKey: threadID)?.values else {
            return
        }

        for continuation in continuations {
            continuation.finish()
        }
    }

    private func startServerEventLoop() {
        serverEventTask?.cancel()
        let transport = self.transport
        let protocolLayer = self.protocolLayer

        serverEventTask = Task { [weak self] in
            guard let self else { return }

            let stream = await transport.serverEvents()
            do {
                for await serverEvent in stream {
                    if let decodedEvent = try protocolLayer.decodeServerEvent(serverEvent) {
                        await self.handleProtocolEvent(decodedEvent)
                    }
                }

                await self.handleServerEventStreamEnded()
            } catch {
                await self.finishAllThreadEventStreams(
                    throwing: CodexAppServerError.wrap(error, operation: "server events")
                )
                await self.finishAllDiagnosticEventStreams(
                    throwing: CodexAppServerError.wrap(error, operation: "server events")
                )
                await self.finishAllLibraryEventStreams()
                await self.finishAllFeatureOperationEventStreams()
                await self.finishAllFSChangeStreams()
                await self.finishAllTurnEventStreams(
                    throwing: CodexAppServerError.wrap(error, operation: "server events")
                )
            }
        }
    }

    private func handleProtocolEvent(_ event: CodexAppServerProtocolEvent) async {
        switch event {
        case .appListUpdated, .skillsChanged:
            publishLibraryEvent(.appSnapshotsChanged)
        case let .mcpServerStatusUpdated(notification):
            handleDiagnosticEvent(.init(wireValue: notification))
            publishLibraryEvent(.appSnapshotsChanged)
        case let .configWarning(notification):
            handleDiagnosticEvent(.init(wireValue: notification))
        case let .deprecationNotice(notification):
            handleDiagnosticEvent(.init(wireValue: notification))
        case let .remoteControlStatusChanged(notification):
            handleDiagnosticEvent(.init(wireValue: notification))
        case let .threadStarted(notification):
            threadStatuses[notification.thread.id] = .init(wireValue: notification.thread.status)
            let threadEvent = CodexThreadEvent.started(
                .init(thread: .init(wireValue: notification.thread))
            )
            publishThreadEvent(threadEvent, for: notification.thread.id, isTerminal: false)
            try? await historyStore?.recordThreadMetadataUpdated(.init(wireValue: notification.thread))
            publishLibraryEvent(.threadChanged(threadID: notification.thread.id))
        case let .threadStatusChanged(notification):
            threadStatuses[notification.threadID] = .init(wireValue: notification.status)
            let threadEvent = CodexThreadEvent.statusChanged(
                .init(
                    threadID: notification.threadID,
                    status: .init(wireValue: notification.status)
                )
            )
            publishThreadEvent(threadEvent, for: notification.threadID, isTerminal: false)
            try? await historyStore?.recordThreadStatusChanged(
                threadID: notification.threadID,
                status: .init(wireValue: notification.status)
            )
            publishLibraryEvent(.threadChanged(threadID: notification.threadID))
        case let .threadArchived(notification):
            let threadEvent = CodexThreadEvent.archived(.init(threadID: notification.threadID))
            publishThreadEvent(threadEvent, for: notification.threadID, isTerminal: false)
            try? await historyStore?.recordThreadArchived(threadID: notification.threadID, isArchived: true)
            publishLibraryEvent(.threadChanged(threadID: notification.threadID))
        case let .threadUnarchived(notification):
            let threadEvent = CodexThreadEvent.unarchived(.init(threadID: notification.threadID))
            publishThreadEvent(threadEvent, for: notification.threadID, isTerminal: false)
            try? await historyStore?.recordThreadArchived(threadID: notification.threadID, isArchived: false)
            publishLibraryEvent(.threadChanged(threadID: notification.threadID))
        case let .threadClosed(notification):
            threadStatuses.removeValue(forKey: notification.threadID)
            clearTurnActivities(threadID: notification.threadID)
            settleThreadObservableActivity(threadID: notification.threadID)
            finishThreadObservableActivityStreams(threadID: notification.threadID)
            finishThreadCommandDeltaStreams(threadID: notification.threadID)
            finishThreadFileDeltaStreams(threadID: notification.threadID)
            let threadEvent = CodexThreadEvent.closed(.init(threadID: notification.threadID))
            publishThreadEvent(threadEvent, for: notification.threadID, isTerminal: true)
            try? await historyStore?.recordThreadClosed(threadID: notification.threadID)
            publishLibraryEvent(.threadChanged(threadID: notification.threadID))
        case let .threadNameUpdated(notification):
            let threadEvent = CodexThreadEvent.nameUpdated(
                .init(
                    threadID: notification.threadID,
                    threadName: notification.threadName
                )
            )
            publishThreadEvent(threadEvent, for: notification.threadID, isTerminal: false)
            try? await historyStore?.recordThreadNameUpdated(
                threadID: notification.threadID,
                name: notification.threadName
            )
            publishLibraryEvent(.threadChanged(threadID: notification.threadID))
        case let .threadTokenUsageUpdated(notification):
            let lastUsage = CodexThreadTokenUsageUpdated.Usage(wireValue: notification.tokenUsage.last)
            let threadEvent = CodexThreadEvent.tokenUsageUpdated(
                .init(
                    threadID: notification.threadID,
                    turnID: notification.turnID,
                    last: lastUsage,
                    modelContextWindow: notification.tokenUsage.modelContextWindow,
                    total: .init(wireValue: notification.tokenUsage.total)
                )
            )
            publishThreadEvent(threadEvent, for: notification.threadID, isTerminal: false)
            try? await historyStore?.recordTurnTokenUsageUpdated(
                threadID: notification.threadID,
                turnID: notification.turnID,
                usage: lastUsage,
                modelContextWindow: notification.tokenUsage.modelContextWindow
            )
            publishLibraryEvent(.threadChanged(threadID: notification.threadID))
        case let .threadGoalUpdated(notification):
            publishThreadEvent(
                .goalUpdated(
                    .init(
                        threadID: notification.threadID,
                        turnID: notification.turnID,
                        goal: .init(wireValue: notification.goal)
                    )
                ),
                for: notification.threadID,
                isTerminal: false
            )
            publishLibraryEvent(.threadChanged(threadID: notification.threadID))
        case let .threadGoalCleared(notification):
            publishThreadEvent(
                .goalCleared(.init(threadID: notification.threadID)),
                for: notification.threadID,
                isTerminal: false
            )
            publishLibraryEvent(.threadChanged(threadID: notification.threadID))
        case let .fsChanged(notification):
            publishFSChanged(
                .init(
                    watchID: notification.watchID,
                    changedPaths: notification.changedPaths
                )
            )
        case let .turnStarted(notification):
            markThreadTurnActive(threadID: notification.threadID, turnID: notification.turn.id)
            let turn = TurnInfo(wireValue: notification.turn)
            let started = CodexTurnStarted(
                threadID: notification.threadID,
                turn: turn
            )
            publishTurnEvent(.started(started), for: notification.turn.id, isTerminal: false)
            try? await historyStore?.recordTurnStarted(threadID: notification.threadID, turn: turn)
            publishLibraryEvent(.threadChanged(threadID: notification.threadID))
        case let .turnDiffUpdated(notification):
            let diffUpdate = CodexTurnDiffUpdate(
                threadID: notification.threadID,
                turnID: notification.turnID,
                diff: notification.diff
            )
            publishTurnEvent(.diffUpdated(diffUpdate), for: notification.turnID, isTerminal: false)
            try? await historyStore?.recordTurnDiffUpdated(turnID: notification.turnID, diff: notification.diff)
        case let .itemStarted(notification):
            updateThreadObservableActivityForItemStarted(notification.item, threadID: notification.threadID)
            let item = CodexTurnItem(wireValue: notification.item)
            let itemStarted = CodexTurnItemStarted(
                threadID: notification.threadID,
                turnID: notification.turnID,
                item: item
            )
            publishTurnEvent(.itemStarted(itemStarted), for: notification.turnID, isTerminal: false)
            try? await historyStore?.recordItemStarted(
                threadID: notification.threadID,
                turnID: notification.turnID,
                item: item
            )
        case let .itemCompleted(notification):
            updateThreadObservableActivityForItemCompleted(notification.item, threadID: notification.threadID)
            let item = CodexTurnItem(wireValue: notification.item)
            let itemCompleted = CodexTurnItemCompleted(
                threadID: notification.threadID,
                turnID: notification.turnID,
                item: item
            )
            publishTurnEvent(.itemCompleted(itemCompleted), for: notification.turnID, isTerminal: false)
            try? await historyStore?.recordItemCompleted(
                threadID: notification.threadID,
                turnID: notification.turnID,
                item: item
            )
        case let .commandExecutionOutputDelta(notification):
            let deltaEvent = CommandExecutionOutputDeltaEvent(
                delta: notification.delta,
                itemID: notification.itemID,
                threadID: notification.threadID,
                turnID: notification.turnID
            )
            publishThreadCommandDelta(deltaEvent, for: notification.threadID)
            try? await historyStore?.recordItemDelta(
                turnID: notification.turnID,
                itemID: notification.itemID,
                delta: notification.delta
            )
        case .commandExecOutputDelta:
            break
        case let .hookStarted(notification):
            updateThreadObservableActivityForHookRun(
                notification.run,
                turnID: notification.turnID,
                threadID: notification.threadID
            )
        case let .hookCompleted(notification):
            updateThreadObservableActivityForHookRun(
                notification.run,
                turnID: notification.turnID,
                threadID: notification.threadID
            )
        case let .warning(notification):
            handleDiagnosticEvent(.init(wireValue: notification))
        case let .guardianWarning(notification):
            handleDiagnosticEvent(.init(wireValue: notification))
        case let .modelRerouted(notification):
            handleDiagnosticEvent(.init(wireValue: notification))
            Self.logger.notice(
                "Model rerouted for thread \(notification.threadID, privacy: .public) turn \(notification.turnID, privacy: .public): \(notification.fromModel, privacy: .public) -> \(notification.toModel, privacy: .public) because \(notification.reason.rawValue, privacy: .public)"
            )
        case let .modelVerification(notification):
            handleDiagnosticEvent(.init(wireValue: notification))
        case let .fileChangeOutputDelta(notification):
            let deltaEvent = FileChangeOutputDeltaEvent(
                delta: notification.delta,
                itemID: notification.itemID,
                path: nil,
                replacesPayload: false,
                threadID: notification.threadID,
                turnID: notification.turnID
            )
            publishThreadFileDelta(deltaEvent, for: notification.threadID)
            try? await historyStore?.recordItemDelta(
                turnID: notification.turnID,
                itemID: notification.itemID,
                delta: notification.delta
            )
        case let .fileChangePatchUpdated(notification):
            let patchText = notification.changes.map(\.diff).joined(separator: "\n")
            let path = notification.changes.count == 1 ? notification.changes.first?.path : nil
            let deltaEvent = FileChangeOutputDeltaEvent(
                delta: patchText,
                itemID: notification.itemID,
                path: path,
                replacesPayload: true,
                threadID: notification.threadID,
                turnID: notification.turnID
            )
            publishThreadFileDelta(deltaEvent, for: notification.threadID)
            try? await historyStore?.recordItemReplacement(
                turnID: notification.turnID,
                itemID: notification.itemID,
                text: patchText,
                path: path
            )
        case let .planDelta(notification):
            let planDelta = CodexTurnPlanDelta(
                threadID: notification.threadID,
                turnID: notification.turnID,
                itemID: notification.itemID,
                delta: notification.delta
            )
            publishTurnEvent(.planDelta(planDelta), for: notification.turnID, isTerminal: false)
            try? await historyStore?.recordItemDelta(
                turnID: notification.turnID,
                itemID: notification.itemID,
                delta: notification.delta
            )
        case let .turnPlanUpdated(notification):
            let planUpdate = CodexTurnPlanUpdate(
                threadID: notification.threadID,
                turnID: notification.turnID,
                explanation: notification.explanation,
                plan: notification.plan.map(CodexTurnPlanUpdate.Step.init(wireValue:))
            )
            publishTurnEvent(.planUpdated(planUpdate), for: notification.turnID, isTerminal: false)
        case let .agentMessageDelta(notification):
            let delta = CodexTurnAgentMessageDelta(
                threadID: notification.threadID,
                turnID: notification.turnID,
                itemID: notification.itemID,
                delta: notification.delta
            )
            publishTurnEvent(.agentMessageDelta(delta), for: notification.turnID, isTerminal: false)
            try? await historyStore?.recordItemDelta(
                turnID: notification.turnID,
                itemID: notification.itemID,
                delta: notification.delta
            )
        case let .reasoningSummaryPartAdded(notification):
            let partAdded = CodexTurnReasoningSummaryPartAdded(
                threadID: notification.threadID,
                turnID: notification.turnID,
                itemID: notification.itemID,
                summaryIndex: notification.summaryIndex
            )
            publishTurnEvent(.reasoningSummaryPartAdded(partAdded), for: notification.turnID, isTerminal: false)
        case let .reasoningSummaryTextDelta(notification):
            let delta = CodexTurnReasoningSummaryTextDelta(
                threadID: notification.threadID,
                turnID: notification.turnID,
                itemID: notification.itemID,
                summaryIndex: notification.summaryIndex,
                delta: notification.delta
            )
            publishTurnEvent(.reasoningSummaryTextDelta(delta), for: notification.turnID, isTerminal: false)
            try? await historyStore?.recordItemDelta(
                turnID: notification.turnID,
                itemID: notification.itemID,
                delta: notification.delta
            )
        case let .reasoningTextDelta(notification):
            let delta = CodexTurnReasoningTextDelta(
                threadID: notification.threadID,
                turnID: notification.turnID,
                itemID: notification.itemID,
                contentIndex: notification.contentIndex,
                delta: notification.delta
            )
            publishTurnEvent(.reasoningTextDelta(delta), for: notification.turnID, isTerminal: false)
            try? await historyStore?.recordItemDelta(
                turnID: notification.turnID,
                itemID: notification.itemID,
                delta: notification.delta
            )
        case let .commandExecutionApprovalRequested(request):
            handleInteractiveApprovalRequest(request.publicValue)
        case let .fileChangeApprovalRequested(request):
            handleInteractiveApprovalRequest(request.publicValue)
        case let .permissionsApprovalRequested(request):
            handleInteractiveApprovalRequest(request.publicValue)
        case let .toolUserInputRequested(request):
            handleInteractiveElicitationRequest(request.publicValue)
        case let .mcpServerElicitationRequested(request):
            handleInteractiveElicitationRequest(request.publicValue)
        case let .serverRequestResolved(notification):
            handleServerRequestResolved(notification)
        case let .turnCompleted(notification):
            clearTurnActivity(turnID: notification.turn.id)
            settleThreadObservableActivity(threadID: notification.threadID)
            let turn = TurnInfo(wireValue: notification.turn)
            try? await historyStore?.recordTurnCompleted(
                threadID: notification.threadID,
                turn: turn
            )
            let completion = CodexTurnCompletion(
                threadID: notification.threadID,
                turn: turn
            )
            let turnEvent = CodexTurnEvent.completed(completion)
            publishTurnEvent(turnEvent, for: notification.turn.id, isTerminal: true)
            publishLibraryEvent(.turnCompleted(threadID: notification.threadID))
        }
    }

    private func handleServerEventStreamEnded() {
        serverEventTask = nil

        guard hasStarted, !isStopping else {
            finishAllThreadEventStreams(throwing: nil)
            finishAllDiagnosticEventStreams(throwing: nil)
            finishAllLibraryEventStreams()
            finishAllFeatureOperationEventStreams()
            finishAllFSChangeStreams()
            finishAllThreadObservableActivityStreams()
            finishAllThreadCommandDeltaStreams()
            finishAllThreadFileDeltaStreams()
            finishAllTurnEventStreams(throwing: nil)
            return
        }

        finishAllThreadEventStreams(
            throwing: CodexAppServerError.transportFailure(
                operation: "server events",
                reason: "Codex app-server stopped delivering thread notifications before pending thread streams finished."
            )
        )
        finishAllDiagnosticEventStreams(
            throwing: CodexAppServerError.transportFailure(
                operation: "server events",
                reason: "Codex app-server stopped delivering diagnostics before pending diagnostic streams finished."
            )
        )
        finishAllLibraryEventStreams()
        finishAllFeatureOperationEventStreams()
        finishAllFSChangeStreams()
        finishAllThreadObservableActivityStreams()
        finishAllThreadCommandDeltaStreams()
        finishAllThreadFileDeltaStreams()
        finishAllTurnEventStreams(
            throwing: CodexAppServerError.transportFailure(
                operation: "server events",
                reason: "Codex app-server stopped delivering notifications before pending turn streams finished."
            )
        )
    }

    private func makeThreadEventStream(
        threadID: String
    ) -> AsyncThrowingStream<CodexThreadEvent, Error> {
        let streamID = UUID()

        return AsyncThrowingStream { continuation in
            registerThreadEventContinuation(continuation, streamID: streamID, threadID: threadID)

            if let bufferedEvents = bufferedThreadEvents.removeValue(forKey: threadID) {
                for event in bufferedEvents {
                    continuation.yield(event)
                }
            }

            if let bufferedEvent = bufferedTerminalThreadEvents.removeValue(forKey: threadID) {
                continuation.yield(bufferedEvent)
                continuation.finish()
                removeThreadEventContinuation(streamID: streamID, threadID: threadID)
                return
            }

            continuation.onTermination = { _ in
                Task {
                    await self.removeThreadEventContinuation(streamID: streamID, threadID: threadID)
                }
            }
        }
    }

    private func makeDiagnosticEventStream() -> AsyncThrowingStream<CodexDiagnosticEvent, Error> {
        let streamID = UUID()

        return AsyncThrowingStream { continuation in
            registerDiagnosticEventContinuation(continuation, streamID: streamID)

            for event in bufferedDiagnosticEvents {
                continuation.yield(event)
            }
            bufferedDiagnosticEvents.removeAll()

            continuation.onTermination = { _ in
                Task {
                    await self.removeDiagnosticEventContinuation(streamID: streamID)
                }
            }
        }
    }

    private func makeFeatureOperationEventStream() -> AsyncStream<SwiftASBFeatureOperationEvent> {
        let streamID = UUID()

        return AsyncStream { continuation in
            featureOperationEventContinuations[streamID] = continuation

            for event in bufferedFeatureOperationEvents {
                continuation.yield(event)
            }

            continuation.onTermination = { _ in
                Task {
                    await self.removeFeatureOperationEventContinuation(streamID: streamID)
                }
            }
        }
    }

    private func makeTurnEventStream(
        turnID: String
    ) -> AsyncThrowingStream<CodexTurnEvent, Error> {
        let streamID = UUID()

        return AsyncThrowingStream { continuation in
            registerTurnEventContinuation(continuation, streamID: streamID, turnID: turnID)

            if let bufferedEvents = bufferedTurnEvents.removeValue(forKey: turnID) {
                for event in bufferedEvents {
                    continuation.yield(event)
                }
            }

            if let bufferedEvent = bufferedTerminalTurnEvents.removeValue(forKey: turnID) {
                continuation.yield(bufferedEvent)
                continuation.finish()
                removeTurnEventContinuation(streamID: streamID, turnID: turnID)
                return
            }

            continuation.onTermination = { _ in
                Task {
                    await self.removeTurnEventContinuation(streamID: streamID, turnID: turnID)
                }
            }
        }
    }

    private func makeThreadTurnEventStream(
        threadID: String
    ) -> AsyncThrowingStream<CodexTurnEvent, Error> {
        let streamID = UUID()

        return AsyncThrowingStream { continuation in
            registerThreadTurnEventContinuation(
                continuation,
                streamID: streamID,
                threadID: threadID
            )

            continuation.onTermination = { _ in
                Task {
                    await self.removeThreadTurnEventContinuation(
                        streamID: streamID,
                        threadID: threadID
                    )
                }
            }
        }
    }

    private func registerTurnEventContinuation(
        _ continuation: AsyncThrowingStream<CodexTurnEvent, Error>.Continuation,
        streamID: UUID,
        turnID: String
    ) {
        var continuations = turnEventContinuations[turnID] ?? [:]
        continuations[streamID] = continuation
        turnEventContinuations[turnID] = continuations
    }

    private func removeTurnEventContinuation(streamID: UUID, turnID: String) {
        guard var continuations = turnEventContinuations[turnID] else { return }
        continuations.removeValue(forKey: streamID)
        if continuations.isEmpty {
            turnEventContinuations.removeValue(forKey: turnID)
        } else {
            turnEventContinuations[turnID] = continuations
        }
    }

    private func releaseTurnObservation(turnID: String) {
        bufferedTurnEvents.removeValue(forKey: turnID)
        bufferedTerminalTurnEvents.removeValue(forKey: turnID)
        if let continuations = turnEventContinuations.removeValue(forKey: turnID)?.values {
            for continuation in continuations {
                continuation.finish()
            }
        }
    }

    private func registerDiagnosticEventContinuation(
        _ continuation: AsyncThrowingStream<CodexDiagnosticEvent, Error>.Continuation,
        streamID: UUID
    ) {
        diagnosticEventContinuations[streamID] = continuation
    }

    private func removeDiagnosticEventContinuation(streamID: UUID) {
        diagnosticEventContinuations.removeValue(forKey: streamID)
    }

    private func removeLibraryEventContinuation(streamID: UUID) {
        libraryEventContinuations.removeValue(forKey: streamID)
    }

    private func removeFeatureOperationEventContinuation(streamID: UUID) {
        featureOperationEventContinuations.removeValue(forKey: streamID)
    }

    private func removeFSChangeContinuation(streamID: UUID, watchID: String) {
        guard var continuations = fsChangeContinuations[watchID] else { return }
        continuations.removeValue(forKey: streamID)
        if continuations.isEmpty {
            fsChangeContinuations.removeValue(forKey: watchID)
        } else {
            fsChangeContinuations[watchID] = continuations
        }
    }

    private func removeFSChangeContinuations(watchID: String) {
        guard let continuations = fsChangeContinuations.removeValue(forKey: watchID)?.values else {
            return
        }

        for continuation in continuations {
            continuation.finish()
        }
    }

    private func registerThreadEventContinuation(
        _ continuation: AsyncThrowingStream<CodexThreadEvent, Error>.Continuation,
        streamID: UUID,
        threadID: String
    ) {
        var continuations = threadEventContinuations[threadID] ?? [:]
        continuations[streamID] = continuation
        threadEventContinuations[threadID] = continuations
    }

    private func removeThreadEventContinuation(streamID: UUID, threadID: String) {
        guard var continuations = threadEventContinuations[threadID] else { return }
        continuations.removeValue(forKey: streamID)
        if continuations.isEmpty {
            threadEventContinuations.removeValue(forKey: threadID)
        } else {
            threadEventContinuations[threadID] = continuations
        }
    }

    private func removeThreadObservableActivityContinuation(streamID: UUID, threadID: String) {
        guard var continuations = threadObservableActivityContinuations[threadID] else { return }
        continuations.removeValue(forKey: streamID)
        if continuations.isEmpty {
            threadObservableActivityContinuations.removeValue(forKey: threadID)
        } else {
            threadObservableActivityContinuations[threadID] = continuations
        }
    }

    private func removeThreadFileDeltaContinuation(streamID: UUID, threadID: String) {
        guard var continuations = threadFileDeltaContinuations[threadID] else { return }
        continuations.removeValue(forKey: streamID)
        if continuations.isEmpty {
            threadFileDeltaContinuations.removeValue(forKey: threadID)
        } else {
            threadFileDeltaContinuations[threadID] = continuations
        }
    }

    private func removeThreadCommandDeltaContinuation(streamID: UUID, threadID: String) {
        guard var continuations = threadCommandDeltaContinuations[threadID] else { return }
        continuations.removeValue(forKey: streamID)
        if continuations.isEmpty {
            threadCommandDeltaContinuations.removeValue(forKey: threadID)
        } else {
            threadCommandDeltaContinuations[threadID] = continuations
        }
    }

    private func registerThreadTurnEventContinuation(
        _ continuation: AsyncThrowingStream<CodexTurnEvent, Error>.Continuation,
        streamID: UUID,
        threadID: String
    ) {
        var continuations = threadTurnEventContinuations[threadID] ?? [:]
        continuations[streamID] = continuation
        threadTurnEventContinuations[threadID] = continuations
    }

    private func removeThreadTurnEventContinuation(streamID: UUID, threadID: String) {
        guard var continuations = threadTurnEventContinuations[threadID] else { return }
        continuations.removeValue(forKey: streamID)
        if continuations.isEmpty {
            threadTurnEventContinuations.removeValue(forKey: threadID)
        } else {
            threadTurnEventContinuations[threadID] = continuations
        }
    }

    private func publishThreadEvent(
        _ event: CodexThreadEvent,
        for threadID: String,
        isTerminal: Bool
    ) {
        guard let continuations = threadEventContinuations[threadID], !continuations.isEmpty else {
            if isTerminal {
                bufferedTerminalThreadEvents[threadID] = event
            } else {
                bufferedThreadEvents[threadID, default: []].append(event)
            }
            return
        }

        if isTerminal {
            threadEventContinuations.removeValue(forKey: threadID)
        }

        for continuation in continuations.values {
            continuation.yield(event)
            if isTerminal {
                continuation.finish()
            }
        }
    }

    private func publishDiagnosticEvent(_ event: CodexDiagnosticEvent) {
        guard !diagnosticEventContinuations.isEmpty else {
            bufferedDiagnosticEvents.append(event)
            return
        }

        for continuation in diagnosticEventContinuations.values {
            continuation.yield(event)
        }
    }

    private func publishLibraryEvent(_ event: LibraryEvent) {
        guard !libraryEventContinuations.isEmpty else {
            return
        }

        for continuation in libraryEventContinuations.values {
            continuation.yield(event)
        }
    }

    private func publishFSChanged(_ event: CodexFS.ChangeEvent) {
        guard let continuations = fsChangeContinuations[event.watchID], !continuations.isEmpty else {
            return
        }

        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    private func publishThreadObservableActivityState(threadID: String) {
        guard let continuations = threadObservableActivityContinuations[threadID], !continuations.isEmpty else {
            return
        }

        let state = threadObservableActivityState(threadID: threadID)
        for continuation in continuations.values {
            continuation.yield(state)
        }
    }

    private func publishThreadFileDelta(
        _ event: FileChangeOutputDeltaEvent,
        for threadID: String
    ) {
        guard let continuations = threadFileDeltaContinuations[threadID], !continuations.isEmpty else {
            return
        }

        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    private func publishThreadCommandDelta(
        _ event: CommandExecutionOutputDeltaEvent,
        for threadID: String
    ) {
        guard let continuations = threadCommandDeltaContinuations[threadID], !continuations.isEmpty else {
            return
        }

        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    private func publishTurnEvent(
        _ event: CodexTurnEvent,
        for turnID: String,
        isTerminal: Bool,
        bufferIfUnobserved: Bool = false
    ) {
        if let threadID = turnThreadIDs[turnID] {
            publishThreadTurnEvent(event, for: threadID)
        }

        guard let continuations = turnEventContinuations[turnID], !continuations.isEmpty else {
            if isTerminal {
                bufferedTerminalTurnEvents[turnID] = event
            } else if bufferIfUnobserved {
                bufferedTurnEvents[turnID, default: []].append(event)
            }
            return
        }

        if isTerminal {
            turnEventContinuations.removeValue(forKey: turnID)
        }

        for continuation in continuations.values {
            continuation.yield(event)
            if isTerminal {
                continuation.finish()
            }
        }
    }

    private func publishThreadTurnEvent(_ event: CodexTurnEvent, for threadID: String) {
        guard let continuations = threadTurnEventContinuations[threadID], !continuations.isEmpty else {
            return
        }

        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    private func finishAllTurnEventStreams(throwing error: CodexAppServerError?) {
        let activeContinuations = turnEventContinuations.values.flatMap(\.values)
        let activeThreadTurnContinuations = threadTurnEventContinuations.values.flatMap(\.values)
        turnEventContinuations.removeAll()
        threadTurnEventContinuations.removeAll()

        for continuation in activeContinuations {
            if let error {
                continuation.finish(throwing: error)
            } else {
                continuation.finish()
            }
        }

        for continuation in activeThreadTurnContinuations {
            if let error {
                continuation.finish(throwing: error)
            } else {
                continuation.finish()
            }
        }
    }

    private func finishAllThreadObservableActivityStreams() {
        let activeContinuations = threadObservableActivityContinuations.values.flatMap(\.values)
        threadObservableActivityContinuations.removeAll()

        for continuation in activeContinuations {
            continuation.finish()
        }
    }

    private func finishAllLibraryEventStreams() {
        let activeContinuations = libraryEventContinuations.values
        libraryEventContinuations.removeAll()

        for continuation in activeContinuations {
            continuation.finish()
        }
    }

    private func finishAllFeatureOperationEventStreams() {
        let activeContinuations = featureOperationEventContinuations.values
        featureOperationEventContinuations.removeAll()

        for continuation in activeContinuations {
            continuation.finish()
        }
    }

    private func finishAllFSChangeStreams() {
        let activeContinuations = fsChangeContinuations.values.flatMap(\.values)
        fsChangeContinuations.removeAll()

        for continuation in activeContinuations {
            continuation.finish()
        }
    }

    private func finishAllThreadCommandDeltaStreams() {
        let activeContinuations = threadCommandDeltaContinuations.values.flatMap(\.values)
        threadCommandDeltaContinuations.removeAll()

        for continuation in activeContinuations {
            continuation.finish()
        }
    }

    private func finishAllThreadFileDeltaStreams() {
        let activeContinuations = threadFileDeltaContinuations.values.flatMap(\.values)
        threadFileDeltaContinuations.removeAll()

        for continuation in activeContinuations {
            continuation.finish()
        }
    }

    private func updateThreadObservableActivityForItemStarted(
        _ item: CodexWireThreadItem,
        threadID: String
    ) {
        var state = threadObservableActivityStates[threadID] ?? .init()
        switch item.type {
        case .commandExecution, .dynamicToolCall, .collabAgentToolCall, .fileChange:
            state.activeToolLikeItemIDs.insert(item.id)
        case .mcpToolCall:
            state.activeMcpItemIDs.insert(item.id)
        case .contextCompaction:
            state.isCompactingThreadContext = true
        default:
            break
        }
        threadObservableActivityStates[threadID] = state
        publishThreadObservableActivityState(threadID: threadID)
    }

    private func updateThreadObservableActivityForItemCompleted(
        _ item: CodexWireThreadItem,
        threadID: String
    ) {
        var state = threadObservableActivityStates[threadID] ?? .init()
        switch item.type {
        case .commandExecution, .dynamicToolCall, .collabAgentToolCall, .fileChange:
            state.activeToolLikeItemIDs.remove(item.id)
            if itemHasError(status: item.status) {
                state.hasToolErrorResidue = true
            }
        case .mcpToolCall:
            state.activeMcpItemIDs.remove(item.id)
            if itemHasError(status: item.status) {
                state.hasMcpErrorResidue = true
            }
        case .contextCompaction:
            state.isCompactingThreadContext = false
        default:
            break
        }
        threadObservableActivityStates[threadID] = state
        publishThreadObservableActivityState(threadID: threadID)
    }

    private func updateThreadObservableActivityForHookRun(
        _ run: CodexWireHookRunSummary,
        turnID: String?,
        threadID: String
    ) {
        var state = threadObservableActivityStates[threadID] ?? .init()
        let hookRun = CodexThread.Dashboard.HookRun(
            wireValue: run,
            turnID: turnID
        )

        if let index = state.hookRuns.firstIndex(where: { $0.id == hookRun.id }) {
            state.hookRuns[index] = hookRun
        } else {
            state.hookRuns.append(hookRun)
        }
        state.hookRuns.sort { lhs, rhs in
            if lhs.displayOrder == rhs.displayOrder {
                return lhs.startedAt < rhs.startedAt
            }
            return lhs.displayOrder < rhs.displayOrder
        }

        threadObservableActivityStates[threadID] = state
        publishThreadObservableActivityState(threadID: threadID)
    }

    private func makeRecentFileSnapshots(
        from turns: [ThreadHistoryStore.ThreadSnapshot.TurnSnapshot],
        threadID: String
    ) -> [RecentFileSnapshot] {
        turns.flatMap { makeRecentFileSnapshots(from: $0, threadID: threadID) }
    }

    private func makeRecentFileSnapshots(
        from turn: ThreadHistoryStore.ThreadSnapshot.TurnSnapshot,
        threadID: String
    ) -> [RecentFileSnapshot] {
        turn.items
            .filter { $0.kind == CodexTurnItem.Kind.fileChange.rawValue }
            .sorted { $0.orderIndex > $1.orderIndex }
            .map {
                RecentFileSnapshot(
                    id: Self.recentFileSnapshotID(turnID: turn.id, itemID: $0.id),
                    itemID: $0.id,
                    latestStatusText: Self.recentFileStatusSummary(
                        status: $0.status,
                        text: $0.streamedText ?? $0.text
                    ),
                    path: $0.path,
                    payloadText: $0.streamedText ?? $0.text,
                    status: $0.status,
                    threadID: threadID,
                    turnID: turn.id,
                    turnOrderIndex: turn.orderIndex,
                    itemOrderIndex: $0.orderIndex,
                    turnStartedAt: turn.startedAt
                )
            }
    }

    private func makeRecentCommandSnapshots(
        from turns: [ThreadHistoryStore.ThreadSnapshot.TurnSnapshot],
        threadID: String
    ) -> [RecentCommandSnapshot] {
        turns.flatMap { makeRecentCommandSnapshots(from: $0, threadID: threadID) }
    }

    private func makeRecentCommandSnapshots(
        from turn: ThreadHistoryStore.ThreadSnapshot.TurnSnapshot,
        threadID: String
    ) -> [RecentCommandSnapshot] {
        turn.items
            .filter { $0.kind == CodexTurnItem.Kind.commandExecution.rawValue }
            .sorted { $0.orderIndex > $1.orderIndex }
            .map {
                RecentCommandSnapshot(
                    id: Self.recentCommandSnapshotID(turnID: turn.id, itemID: $0.id),
                    itemID: $0.id,
                    command: $0.command,
                    latestStatusText: Self.recentCommandStatusSummary(
                        command: $0.command,
                        status: $0.status,
                        text: $0.streamedText ?? $0.text
                    ),
                    outputText: $0.streamedText ?? $0.text,
                    status: $0.status,
                    threadID: threadID,
                    turnID: turn.id,
                    turnOrderIndex: turn.orderIndex,
                    itemOrderIndex: $0.orderIndex,
                    turnStartedAt: turn.startedAt
                )
            }
    }

    private static func recentFileSnapshotID(turnID: String, itemID: String) -> String {
        "\(turnID):\(itemID)"
    }

    private static func recentCommandSnapshotID(turnID: String, itemID: String) -> String {
        "\(turnID):\(itemID)"
    }

    private static func isThreadTurnsHistoryUnavailable(_ error: CodexAppServerError) -> Bool {
        guard case let .protocolFailure(operation, reason) = error,
              operation == "thread/turns/list" else {
            return false
        }

        return reason.contains("ephemeral threads do not support thread/turns/list")
            || reason.contains("thread/turns/list is unavailable before first user message")
    }

    private static func recentFileStatusSummary(status: String?, text: String?) -> String? {
        let normalizedStatus = status?.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedStatus = normalizedStatus?.lowercased()

        if lowercasedStatus == "completed", let payloadSummary = recentFilePayloadSummary(text: text) {
            return payloadSummary
        }

        if let normalizedStatus, !normalizedStatus.isEmpty {
            return normalizedStatus
        }

        return recentFilePayloadSummary(text: text)
    }

    private static func recentFilePayloadSummary(text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }

        var additions = 0
        var deletions = 0
        var hunkCount = 0
        var nonEmptyLineCount = 0

        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let lineString = String(line)
            if !lineString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                nonEmptyLineCount += 1
            }

            if lineString.hasPrefix("@@") {
                hunkCount += 1
            } else if lineString.hasPrefix("+"), !lineString.hasPrefix("+++") {
                additions += 1
            } else if lineString.hasPrefix("-"), !lineString.hasPrefix("---") {
                deletions += 1
            }
        }

        if additions > 0 || deletions > 0 || hunkCount > 0 {
            var parts: [String] = []
            if additions > 0 {
                parts.append("\(additions) additions")
            }
            if deletions > 0 {
                parts.append("\(deletions) deletions")
            }
            if hunkCount > 1 {
                parts.append("\(hunkCount) hunks")
            }
            if !parts.isEmpty {
                return parts.joined(separator: ", ")
            }
        }

        if nonEmptyLineCount > 1 {
            return "\(nonEmptyLineCount) lines changed"
        }

        let firstLine = text.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? text
        return String(firstLine.prefix(160))
    }

    private static func recentCommandStatusSummary(command: String?, status: String?, text: String?) -> String? {
        let normalizedStatus = status?.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedStatus = normalizedStatus?.lowercased()

        if lowercasedStatus == "completed", let payloadSummary = recentCommandOutputSummary(text: text) {
            return payloadSummary
        }

        if let normalizedStatus, !normalizedStatus.isEmpty {
            return normalizedStatus
        }

        if let payloadSummary = recentCommandOutputSummary(text: text) {
            return payloadSummary
        }

        return command
    }

    private static func recentCommandOutputSummary(text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        if nonEmptyLines.count > 1 {
            return "\(nonEmptyLines.count) output lines"
        }

        guard let firstNonEmptyLine = nonEmptyLines.first else {
            return nil
        }

        return String(firstNonEmptyLine.prefix(160))
    }

    private func orderedClosedTurnSnapshots(
        from turns: [ThreadHistoryStore.ThreadSnapshot.TurnSnapshot]
    ) -> [ThreadHistoryStore.ThreadSnapshot.TurnSnapshot] {
        turns.sorted { lhs, rhs in
            let lhsStartedAt = lhs.startedAt ?? Int.min
            let rhsStartedAt = rhs.startedAt ?? Int.min
            if lhsStartedAt != rhsStartedAt {
                return lhsStartedAt > rhsStartedAt
            }

            let lhsCompletedAt = lhs.completedAt ?? Int.min
            let rhsCompletedAt = rhs.completedAt ?? Int.min
            if lhsCompletedAt != rhsCompletedAt {
                return lhsCompletedAt > rhsCompletedAt
            }

            if lhs.orderIndex != rhs.orderIndex {
                return lhs.orderIndex > rhs.orderIndex
            }

            return lhs.id > rhs.id
        }
    }

    private func closedTurnWindow(
        threadID: String,
        orderedTurns: [ThreadHistoryStore.ThreadSnapshot.TurnSnapshot],
        around boundaryIndex: Array<ThreadHistoryStore.ThreadSnapshot.TurnSnapshot>.Index,
        limit: Int
    ) -> CodexThread.HistoryWindow {
        let normalizedLimit = max(1, limit)
        let remainingSlots = normalizedLimit - 1
        let preferredNewerCount = remainingSlots / 2
        let preferredOlderCount = remainingSlots - preferredNewerCount

        let availableNewerCount = boundaryIndex
        let availableOlderCount = orderedTurns.distance(
            from: orderedTurns.index(after: boundaryIndex),
            to: orderedTurns.endIndex
        )
        var newerCount = min(preferredNewerCount, availableNewerCount)
        var olderCount = min(preferredOlderCount, availableOlderCount)

        let unfilledSlots = remainingSlots - newerCount - olderCount
        if unfilledSlots > 0 {
            let additionalNewerCount = min(unfilledSlots, availableNewerCount - newerCount)
            newerCount += additionalNewerCount
            olderCount += min(
                unfilledSlots - additionalNewerCount,
                availableOlderCount - olderCount
            )
        }

        let startIndex = orderedTurns.index(boundaryIndex, offsetBy: -newerCount)
        let endIndex = orderedTurns.index(
            orderedTurns.index(after: boundaryIndex),
            offsetBy: olderCount
        )
        let turns = orderedTurns[startIndex..<endIndex]
            .map { CodexTurnHandle.ClosedTurn(threadID: threadID, snapshot: $0) }

        return CodexThread.HistoryWindow(
            threadID: threadID,
            turns: turns,
            hasOlderTurns: endIndex < orderedTurns.endIndex,
            hasNewerTurns: startIndex > orderedTurns.startIndex
        )
    }

    private func seedRemoteOlderCursor(
        threadID: String,
        limit: Int
    ) async throws -> String? {
        try await listThreadTurns(
            .init(
                threadID: threadID,
                limit: limit,
                sortDirection: .desc
            )
        ).nextCursor
    }

    private func itemHasError(status: String?) -> Bool {
        guard let status else { return false }
        return switch status.lowercased() {
        case "error", "errored", "failed", "interrupted":
            true
        default:
            false
        }
    }

    private func requireHistoryStore(for operation: String) throws -> ThreadHistoryStore {
        if let historyStore {
            return historyStore
        }

        let reason: String
        if let historyStoreInitializationError {
            reason = """
            SwiftASB could not initialize the internal thread history store for \(operation). \
            The Core Data-backed history database failed to open or create successfully: \
            \(historyStoreInitializationError.localizedDescription)
            """
        } else {
            reason = """
            SwiftASB could not initialize the internal thread history store for \(operation). \
            No history store instance is currently available.
            """
        }

        throw CodexAppServerError.invalidState(reason: reason)
    }

    private func requireOutstandingInteractiveRequest(
        requestID: CodexRPCRequestID,
        expectedThreadID: String,
        expectedTurnID: String?
    ) throws -> OutstandingInteractiveRequest {
        guard let outstandingRequest = outstandingInteractiveRequests[requestID] else {
            throw CodexAppServerError.invalidState(
                reason: "No outstanding interactive server request with id \(requestID.description) is currently tracked."
            )
        }

        guard outstandingRequest.threadID == expectedThreadID else {
            throw CodexAppServerError.invalidState(
                reason: "Interactive server request \(requestID.description) belongs to thread \(outstandingRequest.threadID), not thread \(expectedThreadID)."
            )
        }

        switch (expectedTurnID, outstandingRequest.destination) {
        case let (.some(expectedTurnID), .turn(turnID)) where expectedTurnID == turnID:
            return outstandingRequest
        case (.none, .thread):
            return outstandingRequest
        case let (.some(expectedTurnID), .turn(turnID)):
            throw CodexAppServerError.invalidState(
                reason: "Interactive server request \(requestID.description) belongs to turn \(turnID), not turn \(expectedTurnID)."
            )
        case (.some, .thread):
            throw CodexAppServerError.invalidState(
                reason: "Interactive server request \(requestID.description) was surfaced at the thread level and must be answered through CodexThread."
            )
        case (.none, .turn):
            throw CodexAppServerError.invalidState(
                reason: "Interactive server request \(requestID.description) belongs to a specific turn and must be answered through CodexTurnHandle."
            )
        }
    }

    private func handleInteractiveApprovalRequest(_ request: CodexApprovalRequest) {
        let destination = interactiveRequestDestination(
            threadID: request.threadID,
            turnID: request.turnID
        )
        outstandingInteractiveRequests[request.requestID] = OutstandingInteractiveRequest(
            destination: destination,
            kind: request.kind,
            threadID: request.threadID,
            turnID: request.turnID
        )

        switch destination {
        case let .thread(threadID):
            publishThreadEvent(.approvalRequested(request), for: threadID, isTerminal: false)
        case let .turn(turnID):
            publishTurnEvent(
                .approvalRequested(request),
                for: turnID,
                isTerminal: false,
                bufferIfUnobserved: true
            )
        }
    }

    private func handleDiagnosticEvent(_ diagnostic: CodexDiagnosticEvent) {
        publishDiagnosticEvent(diagnostic)

        if let threadID = diagnostic.threadID {
            publishThreadEvent(.diagnostic(diagnostic), for: threadID, isTerminal: false)
        }

        if let turnID = diagnostic.turnID {
            publishTurnEvent(
                .diagnostic(diagnostic),
                for: turnID,
                isTerminal: false,
                bufferIfUnobserved: true
            )
        }
    }

    private func handleInteractiveElicitationRequest(_ request: CodexElicitationRequest) {
        let destination = interactiveRequestDestination(
            threadID: request.threadID,
            turnID: request.turnID
        )
        outstandingInteractiveRequests[request.requestID] = OutstandingInteractiveRequest(
            destination: destination,
            kind: request.kind,
            threadID: request.threadID,
            turnID: request.turnID
        )

        switch destination {
        case let .thread(threadID):
            publishThreadEvent(.elicitationRequested(request), for: threadID, isTerminal: false)
        case let .turn(turnID):
            publishTurnEvent(
                .elicitationRequested(request),
                for: turnID,
                isTerminal: false,
                bufferIfUnobserved: true
            )
        }
    }

    private func handleServerRequestResolved(_ notification: CodexWireServerRequestResolvedNotification) {
        let requestID = CodexRPCRequestID(wireValue: notification.requestID)
        guard let outstandingRequest = outstandingInteractiveRequests.removeValue(forKey: requestID) else {
            return
        }

        let resolution = CodexInteractiveRequestResolved(
            requestID: requestID,
            threadID: outstandingRequest.threadID,
            turnID: outstandingRequest.turnID,
            kind: outstandingRequest.kind
        )

        switch outstandingRequest.destination {
        case let .thread(threadID):
            publishThreadEvent(.serverRequestResolved(resolution), for: threadID, isTerminal: false)
        case let .turn(turnID):
            publishTurnEvent(
                .serverRequestResolved(resolution),
                for: turnID,
                isTerminal: false,
                bufferIfUnobserved: true
            )
        }
    }

    private func interactiveRequestDestination(
        threadID: String,
        turnID: String?
    ) -> InteractiveRequestDestination {
        guard
            let turnID,
            turnThreadIDs[turnID] == threadID
        else {
            return .thread(threadID: threadID)
        }

        return .turn(turnID: turnID)
    }

    private func finishAllThreadEventStreams(throwing error: CodexAppServerError?) {
        let activeContinuations = threadEventContinuations.values.flatMap(\.values)
        threadEventContinuations.removeAll()

        for continuation in activeContinuations {
            if let error {
                continuation.finish(throwing: error)
            } else {
                continuation.finish()
            }
        }
    }

    private func finishAllDiagnosticEventStreams(throwing error: CodexAppServerError?) {
        let activeContinuations = diagnosticEventContinuations.values
        diagnosticEventContinuations.removeAll()

        for continuation in activeContinuations {
            if let error {
                continuation.finish(throwing: error)
            } else {
                continuation.finish()
            }
        }
    }
}
