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
    private var threadObservableActivityContinuations: [String: [UUID: AsyncStream<CodexThread.Dashboard.ActivityState>.Continuation]] = [:]
    private var threadCommandDeltaContinuations: [String: [UUID: AsyncStream<CommandExecutionOutputDeltaEvent>.Continuation]] = [:]
    private var threadFileDeltaContinuations: [String: [UUID: AsyncStream<FileChangeOutputDeltaEvent>.Continuation]] = [:]
    private var bufferedThreadEvents: [String: [CodexThreadEvent]] = [:]
    private var bufferedDiagnosticEvents: [CodexDiagnosticEvent] = []
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
        historyStore: ThreadHistoryStore? = nil
    ) {
        self.transport = transport
        self.protocolLayer = protocolLayer
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

    public func start() async throws {
        do {
            try await transport.start()
            hasStarted = true
            hasCompletedInitializeHandshake = false
            isStopping = false
            startServerEventLoop()
        } catch {
            throw CodexAppServerError.wrap(error, operation: "start")
        }
    }

    public func stop() async {
        isStopping = true
        serverEventTask?.cancel()
        serverEventTask = nil
        finishAllThreadEventStreams(throwing: nil)
        finishAllDiagnosticEventStreams(throwing: nil)
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
        bufferedTurnEvents.removeAll()
        bufferedTerminalThreadEvents.removeAll()
        bufferedTerminalTurnEvents.removeAll()
        outstandingInteractiveRequests.removeAll()
    }

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

            return CodexThread(
                appServer: self,
                session: session,
                events: makeThreadEventStream(threadID: response.thread.id)
            )
        } catch {
            throw CodexAppServerError.wrap(error, operation: "thread/start")
        }
    }

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

            return CodexThread(
                appServer: self,
                session: session,
                events: makeThreadEventStream(threadID: response.thread.id)
            )
        } catch {
            throw CodexAppServerError.wrap(error, operation: "thread/resume")
        }
    }

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

            return CodexThread(
                appServer: self,
                session: session,
                events: makeThreadEventStream(threadID: response.thread.id)
            )
        } catch {
            throw CodexAppServerError.wrap(error, operation: "thread/fork")
        }
    }

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

            return thread
        } catch {
            throw CodexAppServerError.wrap(error, operation: "thread/rollback")
        }
    }

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
        } catch {
            throw CodexAppServerError.wrap(error, operation: "thread/name/set")
        }
    }

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

            return thread
        } catch {
            throw CodexAppServerError.wrap(error, operation: "thread/metadata/update")
        }
    }

    /// Reads a page of stored Codex threads.
    ///
    /// Omitting `request` sends an empty thread-list request, leaving page
    /// size, sort order, filters, and archive visibility to the app-server.
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

    public func listThreadTurns(_ request: ThreadTurnsListRequest) async throws -> ThreadTurnsPage {
        try requireInitialized(for: "thread/turns/list")

        let requestID = CodexRPCRequestID.generated()

        do {
            let requestPayload = try protocolLayer.makeThreadTurnsListRequest(
                id: requestID,
                params: .init(
                    cursor: request.cursor,
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

    internal func debugThreadHistorySnapshot(
        threadID: String
    ) async throws -> ThreadHistoryStore.ThreadSnapshot? {
        try await requireHistoryStore(for: "thread history snapshot").snapshot(threadID: threadID)
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
                await self.finishAllTurnEventStreams(
                    throwing: CodexAppServerError.wrap(error, operation: "server events")
                )
            }
        }
    }

    private func handleProtocolEvent(_ event: CodexAppServerProtocolEvent) async {
        switch event {
        case let .threadStarted(notification):
            threadStatuses[notification.thread.id] = .init(wireValue: notification.thread.status)
            let threadEvent = CodexThreadEvent.started(
                .init(thread: .init(wireValue: notification.thread))
            )
            publishThreadEvent(threadEvent, for: notification.thread.id, isTerminal: false)
            try? await historyStore?.recordThreadMetadataUpdated(.init(wireValue: notification.thread))
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
        case let .threadArchived(notification):
            let threadEvent = CodexThreadEvent.archived(.init(threadID: notification.threadID))
            publishThreadEvent(threadEvent, for: notification.threadID, isTerminal: false)
            try? await historyStore?.recordThreadArchived(threadID: notification.threadID, isArchived: true)
        case let .threadUnarchived(notification):
            let threadEvent = CodexThreadEvent.unarchived(.init(threadID: notification.threadID))
            publishThreadEvent(threadEvent, for: notification.threadID, isTerminal: false)
            try? await historyStore?.recordThreadArchived(threadID: notification.threadID, isArchived: false)
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
        case let .turnStarted(notification):
            markThreadTurnActive(threadID: notification.threadID, turnID: notification.turn.id)
            let turn = TurnInfo(wireValue: notification.turn)
            let started = CodexTurnStarted(
                threadID: notification.threadID,
                turn: turn
            )
            publishTurnEvent(.started(started), for: notification.turn.id, isTerminal: false)
            try? await historyStore?.recordTurnStarted(threadID: notification.threadID, turn: turn)
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
                threadID: notification.threadID,
                turnID: notification.turnID
            )
            publishThreadFileDelta(deltaEvent, for: notification.threadID)
            try? await historyStore?.recordItemDelta(
                turnID: notification.turnID,
                itemID: notification.itemID,
                delta: notification.delta
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
        }
    }

    private func handleServerEventStreamEnded() {
        serverEventTask = nil

        guard hasStarted, !isStopping else {
            finishAllThreadEventStreams(throwing: nil)
            finishAllDiagnosticEventStreams(throwing: nil)
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

private extension CodexTurnPlanUpdate.Step {
    init(wireValue: CodexWireTurnPlanStep) {
        self.init(
            status: .init(wireValue: wireValue.status),
            step: wireValue.step
        )
    }
}

private struct CodexProtocolCommandExecutionApprovalDecisionPayload: Encodable {
    let decision: CodexProtocolCommandExecutionApprovalDecision
}

private enum CodexProtocolCommandExecutionApprovalDecision: Encodable {
    case accept
    case acceptForSession
    case acceptWithExecpolicyAmendment([String])
    case applyNetworkPolicyAmendment(CodexNetworkPolicyAmendment)
    case decline
    case cancel

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .accept:
            try container.encode("accept")
        case .acceptForSession:
            try container.encode("acceptForSession")
        case let .acceptWithExecpolicyAmendment(amendment):
            try container.encode(
                ["acceptWithExecpolicyAmendment": ["execpolicy_amendment": amendment]]
            )
        case let .applyNetworkPolicyAmendment(amendment):
            try container.encode(
                [
                    "applyNetworkPolicyAmendment": [
                        "network_policy_amendment": [
                            "action": amendment.action.rawValue,
                            "host": amendment.host,
                        ]
                    ]
                ]
            )
        case .decline:
            try container.encode("decline")
        case .cancel:
            try container.encode("cancel")
        }
    }
}

private struct CodexProtocolFileChangeApprovalDecisionPayload: Encodable {
    let decision: String
}

private struct CodexProtocolPermissionsApprovalResponsePayload: Encodable {
    let permissions: CodexProtocolPermissionProfilePayload
    let scope: String
}

private struct CodexProtocolPermissionProfilePayload: Encodable {
    let fileSystem: CodexProtocolPermissionFileSystemPayload?
    let network: CodexProtocolPermissionNetworkPayload?
}

private struct CodexProtocolPermissionFileSystemPayload: Encodable {
    let read: [String]?
    let write: [String]?
}

private struct CodexProtocolPermissionNetworkPayload: Encodable {
    let enabled: Bool?
}

private struct CodexProtocolToolUserInputResponsePayload: Encodable {
    struct AnswerPayload: Encodable {
        let answers: [String]
    }

    let answers: [String: AnswerPayload]
}

private struct CodexProtocolMCPServerElicitationResponsePayload: Encodable {
    let action: String
    let content: CodexWireJSONValue?
    let _meta: CodexWireJSONValue?
}

private extension CodexProtocolCommandExecutionApprovalRequest {
    var publicValue: CodexApprovalRequest {
        .commandExecution(
            .init(
                requestID: requestID,
                threadID: threadID,
                turnID: turnID,
                itemID: itemID,
                approvalID: approvalID,
                command: command,
                commandActions: commandActions?.map(\.publicValue),
                currentDirectoryPath: cwd,
                reason: reason,
                proposedExecPolicyAmendment: proposedExecpolicyAmendment,
                proposedNetworkPolicyAmendments: proposedNetworkPolicyAmendments?.map(\.publicValue),
                networkApprovalContext: networkApprovalContext.map(CodexAppServer.JSONValue.init(wireValue:))
            )
        )
    }
}

private extension CodexProtocolFileChangeApprovalRequest {
    var publicValue: CodexApprovalRequest {
        .fileChange(
            .init(
                requestID: requestID,
                threadID: threadID,
                turnID: turnID,
                itemID: itemID,
                grantRoot: grantRoot,
                reason: reason
            )
        )
    }
}

private extension CodexProtocolPermissionsApprovalRequest {
    var publicValue: CodexApprovalRequest {
        .permissions(
            .init(
                requestID: requestID,
                threadID: threadID,
                turnID: turnID,
                itemID: itemID,
                permissions: permissions.publicValue,
                reason: reason
            )
        )
    }
}

private extension CodexProtocolToolUserInputRequest {
    var publicValue: CodexElicitationRequest {
        .toolUserInput(
            .init(
                requestID: requestID,
                threadID: threadID,
                turnID: turnID,
                itemID: itemID,
                questions: questions.map(\.publicValue)
            )
        )
    }
}

private extension CodexProtocolMCPServerElicitationRequest {
    var publicValue: CodexElicitationRequest {
        .mcpServer(
            .init(
                requestID: requestID,
                serverName: serverName,
                threadID: threadID,
                turnID: turnID,
                mode: mode.publicValue
            )
        )
    }
}

private extension CodexProtocolMCPServerElicitationRequest.Mode {
    var publicValue: CodexMcpServerElicitationRequest.Mode {
        switch self {
        case let .form(form):
            .form(
                .init(
                    message: form.message,
                    requestedSchema: .init(wireValue: form.requestedSchema)
                )
            )
        case let .url(prompt):
            .url(
                .init(
                    elicitationID: prompt.elicitationID,
                    message: prompt.message,
                    url: prompt.url
                )
            )
        }
    }
}

private extension CodexProtocolToolUserInputRequest.Question {
    var publicValue: CodexToolUserInputRequest.Question {
        .init(
            header: header,
            id: id,
            isOther: isOther,
            isSecret: isSecret,
            options: options?.map(\.publicValue),
            question: question
        )
    }
}

private extension CodexProtocolToolUserInputRequest.Question.Option {
    var publicValue: CodexToolUserInputRequest.Question.Option {
        .init(description: description, label: label)
    }
}

private extension CodexProtocolCommandAction {
    var publicValue: CodexCommandAction {
        switch self {
        case let .read(action):
            .read(.init(command: action.command, name: action.name, path: action.path))
        case let .listFiles(action):
            .listFiles(.init(command: action.command, path: action.path))
        case let .search(action):
            .search(.init(command: action.command, path: action.path, query: action.query))
        case let .unknown(action):
            .unknown(.init(command: action.command))
        }
    }
}

private extension CodexProtocolNetworkPolicyAmendment {
    var publicValue: CodexNetworkPolicyAmendment {
        .init(
            action: .init(rawValue: action) ?? .allow,
            host: host
        )
    }
}

private extension CodexProtocolPermissionProfile {
    var publicValue: CodexPermissionProfile {
        .init(
            fileSystem: fileSystem.map { .init(read: $0.read, write: $0.write) },
            network: network.map { .init(enabled: $0.enabled) }
        )
    }
}

private extension CodexCommandExecutionApprovalResponse {
    var protocolValue: CodexProtocolCommandExecutionApprovalDecisionPayload {
        let decision: CodexProtocolCommandExecutionApprovalDecision
        switch self {
        case .accept:
            decision = .accept
        case .acceptForSession:
            decision = .acceptForSession
        case let .acceptWithExecPolicyAmendment(amendment):
            decision = .acceptWithExecpolicyAmendment(amendment)
        case let .applyNetworkPolicyAmendment(amendment):
            decision = .applyNetworkPolicyAmendment(amendment)
        case .decline:
            decision = .decline
        case .cancel:
            decision = .cancel
        }

        return .init(decision: decision)
    }
}

private extension CodexPermissionsApprovalResponse {
    var protocolValue: CodexProtocolPermissionsApprovalResponsePayload {
        .init(
            permissions: .init(
                fileSystem: permissions.fileSystem.map {
                    .init(read: $0.read, write: $0.write)
                },
                network: permissions.network.map {
                    .init(enabled: $0.enabled)
                }
            ),
            scope: scope.rawValue
        )
    }
}

private extension CodexToolUserInputResponse {
    var protocolValue: CodexProtocolToolUserInputResponsePayload {
        .init(
            answers: answers.mapValues {
                .init(answers: $0.answers)
            }
        )
    }
}

private extension CodexMcpServerElicitationResponse {
    var protocolValue: CodexProtocolMCPServerElicitationResponsePayload {
        .init(
            action: action.rawValue,
            content: content?.wireValue,
            _meta: metadata?.wireValue
        )
    }
}

private extension CodexRPCRequestID {
    init(wireValue: CodexWireRequestID) {
        switch wireValue {
        case let .integer(value):
            self = .int(value)
        case let .string(value):
            self = .string(value)
        }
    }
}

private extension CodexTurnPlanUpdate.Step.Status {
    init(wireValue: CodexWireTurnPlanStepStatus) {
        switch wireValue {
        case .completed:
            self = .completed
        case .inProgress:
            self = .inProgress
        case .pending:
            self = .pending
        }
    }
}

private extension CodexTurnItem {
    init(wireValue: CodexWireThreadItem) {
        self.init(
            id: wireValue.id,
            kind: .init(wireValue: wireValue.type),
            command: wireValue.command,
            path: wireValue.path ?? wireValue.savedPath ?? wireValue.changes?.first?.path,
            serverName: wireValue.server,
            text: wireValue.text,
            status: wireValue.status,
            toolName: wireValue.tool
        )
    }
}

private extension CodexTurnItem.Kind {
    init(wireValue: CodexWireThreadItemType) {
        switch wireValue {
        case .agentMessage:
            self = .agentMessage
        case .collabAgentToolCall:
            self = .collabAgentToolCall
        case .commandExecution:
            self = .commandExecution
        case .contextCompaction:
            self = .contextCompaction
        case .dynamicToolCall:
            self = .dynamicToolCall
        case .enteredReviewMode:
            self = .enteredReviewMode
        case .exitedReviewMode:
            self = .exitedReviewMode
        case .fileChange:
            self = .fileChange
        case .hookPrompt:
            self = .hookPrompt
        case .imageGeneration:
            self = .imageGeneration
        case .imageView:
            self = .imageView
        case .mcpToolCall:
            self = .mcpToolCall
        case .plan:
            self = .plan
        case .reasoning:
            self = .reasoning
        case .userMessage:
            self = .userMessage
        case .webSearch:
            self = .webSearch
        }
    }
}

private extension CodexThreadTokenUsageUpdated.Usage {
    init(wireValue: CodexWireTokenUsageBreakdown) {
        self.init(
            cachedInputTokens: wireValue.cachedInputTokens,
            inputTokens: wireValue.inputTokens,
            outputTokens: wireValue.outputTokens,
            reasoningOutputTokens: wireValue.reasoningOutputTokens,
            totalTokens: wireValue.totalTokens
        )
    }
}

private extension CodexAppServer.InitializeRequest {
    var wireValue: CodexWireInitializeParams {
        CodexWireInitializeParams(
            capabilities: CodexWireInitializeCapabilities(
                experimentalAPI: capabilities.experimentalAPI,
                optOutNotificationMethods: capabilities.optOutNotificationMethods
            ),
            clientInfo: CodexWireClientInfo(
                name: clientInfo.name,
                title: clientInfo.title,
                version: clientInfo.version
            )
        )
    }
}

private extension CodexAppServer.ThreadStartRequest {
    var wireValue: CodexWireThreadStartParams {
        CodexWireThreadStartParams(
            approvalPolicy: approvalPolicy?.wireValue,
            approvalsReviewer: approvalsReviewer?.wireValue,
            baseInstructions: baseInstructions,
            config: config?.mapValues(\.wireValue),
            cwd: currentDirectoryPath,
            developerInstructions: developerInstructions,
            dynamicTools: nil,
            environments: nil,
            ephemeral: ephemeral,
            experimentalRawEvents: nil,
            mockExperimentalField: nil,
            model: model,
            modelProvider: modelProvider,
            permissions: nil,
            persistExtendedHistory: nil,
            personality: personality?.wireValue,
            sandbox: sandboxMode?.wireValue,
            serviceName: serviceName,
            serviceTier: serviceTier?.wireValue,
            sessionStartSource: sessionStartSource?.wireValue
        )
    }
}

private extension CodexAppServer.ThreadResumeRequest {
    var wireValue: CodexProtocolThreadResumeParams {
        .init(
            approvalPolicy: approvalPolicy?.wireValue,
            approvalsReviewer: approvalsReviewer?.wireValue,
            baseInstructions: baseInstructions,
            config: config?.mapValues(\.wireValue),
            cwd: currentDirectoryPath,
            developerInstructions: developerInstructions,
            excludeTurns: excludeTurns,
            model: model,
            modelProvider: modelProvider,
            personality: personality?.wireValue,
            sandbox: sandboxMode?.wireValue,
            serviceName: serviceName,
            serviceTier: serviceTier?.wireValue,
            threadID: threadID
        )
    }
}

private extension CodexAppServer.ThreadForkRequest {
    var wireValue: CodexProtocolThreadForkParams {
        .init(
            approvalPolicy: approvalPolicy?.wireValue,
            approvalsReviewer: approvalsReviewer?.wireValue,
            baseInstructions: baseInstructions,
            config: config?.mapValues(\.wireValue),
            cwd: currentDirectoryPath,
            developerInstructions: developerInstructions,
            ephemeral: ephemeral,
            excludeTurns: excludeTurns,
            model: model,
            modelProvider: modelProvider,
            personality: personality?.wireValue,
            sandbox: sandboxMode?.wireValue,
            serviceName: serviceName,
            serviceTier: serviceTier?.wireValue,
            threadID: threadID
        )
    }
}

private extension CodexAppServer.TurnStartRequest {
    var wireValue: CodexWireTurnStartParams {
        CodexWireTurnStartParams(
            approvalPolicy: approvalPolicy?.wireValue,
            approvalsReviewer: approvalsReviewer?.wireValue,
            collaborationMode: nil,
            cwd: currentDirectoryPath,
            effort: effort?.wireValue,
            environments: nil,
            input: input.map(\.wireValue),
            model: model,
            outputSchema: outputSchema?.wireValue,
            permissions: nil,
            personality: personality?.wireValue,
            responsesapiClientMetadata: nil,
            sandboxPolicy: nil,
            serviceTier: serviceTier?.wireValue,
            summary: summary?.wireValue,
            threadID: threadID
        )
    }
}

private extension CodexAppServer.TurnInput {
    var wireValue: CodexWireUserInput {
        CodexWireUserInput(
            text: text,
            textElements: nil,
            type: kind.wireValue,
            url: url,
            path: path,
            name: name
        )
    }
}

private extension CodexAppServer.TurnInput.Kind {
    var wireValue: CodexWireUserInputType {
        switch self {
        case .image:
            .image
        case .localImage:
            .localImage
        case .mention:
            .mention
        case .skill:
            .skill
        case .text:
            .text
        }
    }
}

extension CodexAppServer.JSONValue {
    init(wireValue: CodexWireJSONValue) {
        switch wireValue {
        case .null:
            self = .null
        case let .bool(value):
            self = .bool(value)
        case let .integer(value):
            self = .integer(value)
        case let .double(value):
            self = .double(value)
        case let .string(value):
            self = .string(value)
        case let .array(value):
            self = .array(value.map(Self.init(wireValue:)))
        case let .object(value):
            self = .object(value.mapValues(Self.init(wireValue:)))
        }
    }

    var wireValue: CodexWireJSONValue {
        switch self {
        case .null:
            .null
        case let .bool(value):
            .bool(value)
        case let .integer(value):
            .integer(value)
        case let .double(value):
            .double(value)
        case let .string(value):
            .string(value)
        case let .array(value):
            .array(value.map(\.wireValue))
        case let .object(value):
            .object(value.mapValues(\.wireValue))
        }
    }
}

private extension CodexAppServer.ApprovalPolicy {
    init(wireValue: CodexWireAskForApproval) {
        switch wireValue {
        case let .enumeration(value):
            self = Self(wireEnum: value)
        case let .codexWireGranularAskForApproval(value):
            self = .granular(.init(wireValue: value.granular))
        }
    }

    init(wireEnum: CodexWireApprovalPolicyEnum) {
        switch wireEnum {
        case .never:
            self = .never
        case .onFailure:
            self = .onFailure
        case .onRequest:
            self = .onRequest
        case .untrusted:
            self = .untrusted
        }
    }

    var wireValue: CodexWireApprovalPolicyUnion {
        switch self {
        case .never:
            .enumeration(.never)
        case .onFailure:
            .enumeration(.onFailure)
        case .onRequest:
            .enumeration(.onRequest)
        case .untrusted:
            .enumeration(.untrusted)
        case let .granular(policy):
            .codexWireGranularAskForApproval(
                CodexWireGranularAskForApproval(granular: policy.wireValue)
            )
        }
    }
}

private extension CodexAppServer.GranularApprovalPolicy {
    init(wireValue: CodexWireGranular) {
        self.init(
            mcpElicitations: wireValue.mcpElicitations,
            requestPermissions: wireValue.requestPermissions,
            rules: wireValue.rules,
            sandboxApproval: wireValue.sandboxApproval,
            skillApproval: wireValue.skillApproval
        )
    }

    var wireValue: CodexWireGranular {
        CodexWireGranular(
            mcpElicitations: mcpElicitations,
            requestPermissions: requestPermissions,
            rules: rules,
            sandboxApproval: sandboxApproval,
            skillApproval: skillApproval
        )
    }
}

private extension CodexAppServer.ApprovalsReviewer {
    init(wireValue: CodexWireApprovalsReviewer) {
        switch wireValue {
        case .autoReview:
            self = .autoReview
        case .guardianSubagent:
            self = .guardianSubagent
        case .user:
            self = .user
        }
    }

    var wireValue: CodexWireApprovalsReviewer {
        switch self {
        case .autoReview:
            .autoReview
        case .guardianSubagent:
            .guardianSubagent
        case .user:
            .user
        }
    }
}

private extension CodexAppServer.Personality {
    init(wireValue: CodexWirePersonality) {
        switch wireValue {
        case .friendly:
            self = .friendly
        case .none:
            self = .none
        case .pragmatic:
            self = .pragmatic
        }
    }

    var wireValue: CodexWirePersonality {
        switch self {
        case .friendly:
            .friendly
        case .none:
            .none
        case .pragmatic:
            .pragmatic
        }
    }
}

private extension CodexAppServer.SandboxMode {
    var wireValue: CodexWireSandboxMode {
        switch self {
        case .dangerFullAccess:
            .dangerFullAccess
        case .readOnly:
            .readOnly
        case .workspaceWrite:
            .workspaceWrite
        }
    }
}

private extension CodexAppServer.ServiceTier {
    init?(wireValue: CodexWireServiceTier?) {
        guard let wireValue else { return nil }
        switch wireValue {
        case .fast:
            self = .fast
        case .flex:
            self = .flex
        }
    }

    var wireValue: CodexWireServiceTier {
        switch self {
        case .fast:
            .fast
        case .flex:
            .flex
        }
    }
}

private extension CodexAppServer.SessionStartSource {
    var wireValue: CodexWireThreadStartSource {
        switch self {
        case .clear:
            .clear
        case .startup:
            .startup
        }
    }
}

extension CodexAppServer.ReasoningEffort {
    init(wireValue: CodexWireReasoningEffort) {
        self = Self(wireValue: Optional(wireValue))!
    }

    init?(wireValue: CodexWireReasoningEffort?) {
        guard let wireValue else { return nil }
        switch wireValue {
        case .high:
            self = .high
        case .low:
            self = .low
        case .medium:
            self = .medium
        case .minimal:
            self = .minimal
        case .none:
            self = .none
        case .xhigh:
            self = .xhigh
        }
    }

    var wireValue: CodexWireReasoningEffort {
        switch self {
        case .high:
            .high
        case .low:
            .low
        case .medium:
            .medium
        case .minimal:
            .minimal
        case .none:
            .none
        case .xhigh:
            .xhigh
        }
    }
}

private extension CodexAppServer.ReasoningSummary {
    var wireValue: CodexWireReasoningSummary {
        switch self {
        case .auto:
            .auto
        case .concise:
            .concise
        case .detailed:
            .detailed
        case .none:
            .none
        }
    }
}

private extension CodexAppServer.SandboxPolicy {
    init(wireValue: CodexWireSandboxPolicy) {
        self.init(
            type: .init(wireValue: wireValue.type),
            networkAccess: wireValue.networkAccess.map { CodexAppServer.NetworkAccess(wireValue: $0) },
            excludeSlashTmp: wireValue.excludeSlashTmp,
            excludeTmpdirEnvVar: wireValue.excludeTmpdirEnvVar,
            writableRoots: wireValue.writableRoots ?? []
        )
    }
}

private extension CodexAppServer.NetworkAccess {
    init(wireValue: CodexWireNetworkAccessUnion) {
        switch wireValue {
        case let .bool(value):
            self = .explicit(value)
        case let .enumeration(value):
            switch value {
            case .enabled:
                self = .enabled
            case .restricted:
                self = .restricted
            }
        }
    }
}

private extension CodexAppServer.SandboxPolicyType {
    init(wireValue: CodexWireSandboxPolicyType) {
        switch wireValue {
        case .dangerFullAccess:
            self = .dangerFullAccess
        case .externalSandbox:
            self = .externalSandbox
        case .readOnly:
            self = .readOnly
        case .workspaceWrite:
            self = .workspaceWrite
        }
    }
}

private extension CodexAppServer.InitializeSession {
    init(wireValue: CodexWireInitializeResponse) {
        self.init(
            codexHome: wireValue.codexHome,
            platformFamily: wireValue.platformFamily,
            platformOS: wireValue.platformOS,
            userAgent: wireValue.userAgent
        )
    }
}

private extension CodexAppServer.ThreadSession {
    init(wireValue: CodexWireThreadStartResponse) {
        self.init(
            approvalPolicy: .init(wireValue: wireValue.approvalPolicy),
            approvalsReviewer: .init(wireValue: wireValue.approvalsReviewer),
            currentDirectoryPath: wireValue.cwd,
            instructionSources: wireValue.instructionSources ?? [],
            model: wireValue.model,
            modelProvider: wireValue.modelProvider,
            reasoningEffort: .init(wireValue: wireValue.reasoningEffort),
            sandboxPolicy: .init(wireValue: wireValue.sandbox),
            serviceTier: .init(wireValue: wireValue.serviceTier),
            thread: .init(wireValue: wireValue.thread)
        )
    }
}

private extension CodexAppServer.ThreadInfo {
    init(wireValue: CodexWireThread) {
        self.init(
            id: wireValue.id,
            cliVersion: wireValue.cliVersion,
            createdAt: wireValue.createdAt,
            currentDirectoryPath: wireValue.cwd,
            ephemeral: wireValue.ephemeral,
            forkedFromThreadID: wireValue.forkedFromID,
            gitInfo: wireValue.gitInfo.map(CodexAppServer.GitInfo.init),
            modelProvider: wireValue.modelProvider,
            name: wireValue.name,
            preview: wireValue.preview,
            status: .init(wireValue: wireValue.status),
            updatedAt: wireValue.updatedAt
        )
    }
}

private extension CodexAppServer.CLIExecutableDiagnostics {
    init(resolution: CodexCLIExecutableResolver.Resolution) {
        self.init(
            source: .init(resolution.source),
            resolvedExecutablePath: resolution.resolvedExecutableURL?.path,
            versionString: resolution.versionString,
            compatibility: .init(resolution.compatibility)
        )
    }
}

private extension CodexAppServer.CLIExecutableDiagnostics.Source {
    init(_ source: CodexCLIExecutableResolver.Source) {
        switch source {
        case .explicit:
            self = .explicit
        case .path:
            self = .path
        case .homebrewAppleSilicon:
            self = .homebrewAppleSilicon
        case .homebrewIntel:
            self = .homebrewIntel
        case let .npmGlobal(prefix):
            self = .npmGlobal(prefix: prefix)
        }
    }
}

private extension CodexAppServer.CLIExecutableDiagnostics.Compatibility {
    init(_ compatibility: CodexCLIExecutableResolver.Compatibility) {
        switch compatibility {
        case let .supported(documentedWindow):
            self = .supported(documentedWindow: documentedWindow)
        case let .outsideDocumentedWindow(documentedWindow):
            self = .outsideDocumentedWindow(documentedWindow: documentedWindow)
        case let .unknownVersionFormat(documentedWindow):
            self = .unknownVersionFormat(documentedWindow: documentedWindow)
        }
    }
}

private extension CodexAppServer.ThreadStatus {
    init(wireValue: CodexWireThreadStatus) {
        self.init(
            type: .init(wireValue: wireValue.type),
            activeFlags: (wireValue.activeFlags ?? []).map { CodexAppServer.ThreadActiveFlag(wireValue: $0) }
        )
    }
}

private extension CodexThread.Dashboard.HookRun {
    init(
        wireValue: CodexWireHookRunSummary,
        turnID: String?
    ) {
        self.init(
            id: wireValue.id,
            completedAt: wireValue.completedAt,
            displayOrder: wireValue.displayOrder,
            durationMS: wireValue.durationMS,
            entries: wireValue.entries.map(Entry.init(wireValue:)),
            eventName: .init(wireValue: wireValue.eventName),
            executionMode: .init(wireValue: wireValue.executionMode),
            handlerType: .init(wireValue: wireValue.handlerType),
            scope: .init(wireValue: wireValue.scope),
            sourcePath: wireValue.sourcePath,
            startedAt: wireValue.startedAt,
            status: .init(wireValue: wireValue.status),
            statusMessage: wireValue.statusMessage,
            turnID: turnID
        )
    }
}

private extension CodexThread.Dashboard.HookRun.Entry {
    init(wireValue: CodexWireHookOutputEntry) {
        self.init(
            kind: .init(wireValue: wireValue.kind),
            text: wireValue.text
        )
    }
}

private extension CodexThread.Dashboard.HookRun.Entry.Kind {
    init(wireValue: CodexWireHookOutputEntryKind) {
        switch wireValue {
        case .context:
            self = .context
        case .error:
            self = .error
        case .feedback:
            self = .feedback
        case .stop:
            self = .stop
        case .warning:
            self = .warning
        }
    }
}

private extension CodexThread.Dashboard.HookRun.EventName {
    init(wireValue: CodexWireHookEventName) {
        switch wireValue {
        case .permissionRequest:
            self = .permissionRequest
        case .postToolUse:
            self = .postToolUse
        case .preToolUse:
            self = .preToolUse
        case .sessionStart:
            self = .sessionStart
        case .stop:
            self = .stop
        case .userPromptSubmit:
            self = .userPromptSubmit
        }
    }
}

private extension CodexThread.Dashboard.HookRun.ExecutionMode {
    init(wireValue: CodexWireHookExecutionMode) {
        switch wireValue {
        case .async:
            self = .async
        case .sync:
            self = .sync
        }
    }
}

private extension CodexThread.Dashboard.HookRun.HandlerType {
    init(wireValue: CodexWireHookHandlerType) {
        switch wireValue {
        case .agent:
            self = .agent
        case .command:
            self = .command
        case .prompt:
            self = .prompt
        }
    }
}

private extension CodexThread.Dashboard.HookRun.Scope {
    init(wireValue: CodexWireHookScope) {
        switch wireValue {
        case .thread:
            self = .thread
        case .turn:
            self = .turn
        }
    }
}

private extension CodexThread.Dashboard.HookRun.Status {
    init(wireValue: CodexWireHookRunStatus) {
        switch wireValue {
        case .blocked:
            self = .blocked
        case .completed:
            self = .completed
        case .failed:
            self = .failed
        case .running:
            self = .running
        case .stopped:
            self = .stopped
        }
    }
}

private extension CodexAppServer.ThreadStatusType {
    init(wireValue: CodexWireThreadStatusType) {
        switch wireValue {
        case .active:
            self = .active
        case .idle:
            self = .idle
        case .notLoaded:
            self = .notLoaded
        case .systemError:
            self = .systemError
        }
    }
}

private extension CodexProtocolThreadTurnsSortDirection {
    init(_ direction: CodexAppServer.ThreadTurnsSortDirection) {
        switch direction {
        case .asc:
            self = .asc
        case .desc:
            self = .desc
        }
    }
}

private extension CodexProtocolThreadListSortKey {
    init(_ key: CodexAppServer.ThreadListSortKey) {
        switch key {
        case .createdAt:
            self = .createdAt
        case .updatedAt:
            self = .updatedAt
        }
    }
}

private extension CodexProtocolThreadListSortDirection {
    init(_ direction: CodexAppServer.ThreadListSortDirection) {
        switch direction {
        case .asc:
            self = .asc
        case .desc:
            self = .desc
        }
    }
}

private extension CodexProtocolThreadListSourceKind {
    init(_ sourceKind: CodexAppServer.ThreadListSourceKind) {
        switch sourceKind {
        case .appServer:
            self = .appServer
        case .cli:
            self = .cli
        case .exec:
            self = .exec
        case .unknown:
            self = .unknown
        case .vscode:
            self = .vscode
        }
    }
}

private extension CodexAppServer.ThreadActiveFlag {
    init(wireValue: CodexWireThreadActiveFlag) {
        switch wireValue {
        case .waitingOnApproval:
            self = .waitingOnApproval
        case .waitingOnUserInput:
            self = .waitingOnUserInput
        }
    }
}

private extension CodexAppServer.TurnSession {
    init(wireValue: CodexWireTurnStartResponse) {
        self.init(turn: .init(wireValue: wireValue.turn))
    }
}

private extension CodexAppServer.TurnInfo {
    init(wireValue: CodexWireTurn) {
        self.init(
            completedAt: wireValue.completedAt,
            durationMS: wireValue.durationMS,
            errorMessage: wireValue.error?.message,
            id: wireValue.id,
            startedAt: wireValue.startedAt,
            status: .init(wireValue: wireValue.status)
        )
    }
}

private extension CodexAppServer.TurnStatus {
    init(wireValue: CodexWireTurnStatus) {
        switch wireValue {
        case .completed:
            self = .completed
        case .failed:
            self = .failed
        case .inProgress:
            self = .inProgress
        case .interrupted:
            self = .interrupted
        }
    }
}
