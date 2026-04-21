import Foundation

public actor CodexAppServer {
    public struct CLIExecutableDiagnostics: Sendable, Equatable {
        public enum Source: Sendable, Equatable {
            case explicit
            case path
            case homebrewAppleSilicon
            case homebrewIntel
            case npmGlobal(prefix: String)
        }

        public enum Compatibility: Sendable, Equatable {
            case supported(documentedWindow: String)
            case outsideDocumentedWindow(documentedWindow: String)
            case unknownVersionFormat(documentedWindow: String)
        }

        public let source: Source
        public let resolvedExecutablePath: String?
        public let versionString: String
        public let compatibility: Compatibility
    }

    public struct Configuration: Sendable, Equatable {
        public var codexExecutableURL: URL?
        public var arguments: [String]
        public var currentDirectoryURL: URL?
        public var environment: [String: String]?

        public init(
            codexExecutableURL: URL? = nil,
            arguments: [String] = ["app-server", "--listen", "stdio://"],
            currentDirectoryURL: URL? = nil,
            environment: [String: String]? = nil
        ) {
            self.codexExecutableURL = codexExecutableURL
            self.arguments = arguments
            self.currentDirectoryURL = currentDirectoryURL
            self.environment = environment
        }
    }

    public struct InitializeRequest: Sendable, Equatable {
        public var capabilities: InitializeCapabilities
        public var clientInfo: ClientInfo

        public init(
            capabilities: InitializeCapabilities = .init(),
            clientInfo: ClientInfo
        ) {
            self.capabilities = capabilities
            self.clientInfo = clientInfo
        }
    }

    public struct InitializeCapabilities: Sendable, Equatable {
        public var experimentalAPI: Bool?
        public var optOutNotificationMethods: [String]?

        public init(
            experimentalAPI: Bool? = nil,
            optOutNotificationMethods: [String]? = nil
        ) {
            self.experimentalAPI = experimentalAPI
            self.optOutNotificationMethods = optOutNotificationMethods
        }
    }

    public struct ClientInfo: Sendable, Equatable {
        public var name: String
        public var title: String?
        public var version: String

        public init(
            name: String,
            title: String? = nil,
            version: String
        ) {
            self.name = name
            self.title = title
            self.version = version
        }
    }

    public struct InitializeSession: Sendable, Equatable {
        public let codexHome: String
        public let platformFamily: String
        public let platformOS: String
        public let userAgent: String
    }

    public struct ThreadStartRequest: Sendable, Equatable {
        public var approvalPolicy: ApprovalPolicy?
        public var approvalsReviewer: ApprovalsReviewer?
        public var baseInstructions: String?
        public var config: [String: JSONValue]?
        public var currentDirectoryPath: String?
        public var developerInstructions: String?
        public var ephemeral: Bool?
        public var model: String?
        public var modelProvider: String?
        public var personality: Personality?
        public var sandboxMode: SandboxMode?
        public var serviceName: String?
        public var serviceTier: ServiceTier?
        public var sessionStartSource: SessionStartSource?

        public init(
            approvalPolicy: ApprovalPolicy? = nil,
            approvalsReviewer: ApprovalsReviewer? = nil,
            baseInstructions: String? = nil,
            config: [String: JSONValue]? = nil,
            currentDirectoryPath: String? = nil,
            developerInstructions: String? = nil,
            ephemeral: Bool? = nil,
            model: String? = nil,
            modelProvider: String? = nil,
            personality: Personality? = nil,
            sandboxMode: SandboxMode? = nil,
            serviceName: String? = nil,
            serviceTier: ServiceTier? = nil,
            sessionStartSource: SessionStartSource? = nil
        ) {
            self.approvalPolicy = approvalPolicy
            self.approvalsReviewer = approvalsReviewer
            self.baseInstructions = baseInstructions
            self.config = config
            self.currentDirectoryPath = currentDirectoryPath
            self.developerInstructions = developerInstructions
            self.ephemeral = ephemeral
            self.model = model
            self.modelProvider = modelProvider
            self.personality = personality
            self.sandboxMode = sandboxMode
            self.serviceName = serviceName
            self.serviceTier = serviceTier
            self.sessionStartSource = sessionStartSource
        }
    }

    public struct ThreadSession: Sendable, Equatable {
        public let approvalPolicy: ApprovalPolicy
        public let approvalsReviewer: ApprovalsReviewer
        public let currentDirectoryPath: String
        public let instructionSources: [String]
        public let model: String
        public let modelProvider: String
        public let reasoningEffort: ReasoningEffort?
        public let sandboxPolicy: SandboxPolicy
        public let serviceTier: ServiceTier?
        public let thread: ThreadInfo
    }

    public struct ThreadInfo: Sendable, Equatable {
        public let id: String
        public let cliVersion: String
        public let createdAt: Int
        public let currentDirectoryPath: String
        public let ephemeral: Bool
        public let modelProvider: String
        public let name: String?
        public let preview: String
        public let status: ThreadStatus
        public let updatedAt: Int
    }

    public struct ThreadReadRequest: Sendable, Equatable {
        public var includeTurns: Bool
        public var threadID: String

        public init(
            threadID: String,
            includeTurns: Bool = false
        ) {
            self.threadID = threadID
            self.includeTurns = includeTurns
        }
    }

    public struct ThreadReadResult: Sendable, Equatable {
        public let thread: ThreadInfo
        public let turns: [TurnInfo]
    }

    public enum ThreadTurnsSortDirection: String, Sendable, Equatable {
        case asc
        case desc
    }

    public struct ThreadTurnsListRequest: Sendable, Equatable {
        public var cursor: String?
        public var limit: Int?
        public var sortDirection: ThreadTurnsSortDirection?
        public var threadID: String

        public init(
            threadID: String,
            limit: Int? = nil,
            cursor: String? = nil,
            sortDirection: ThreadTurnsSortDirection? = nil
        ) {
            self.threadID = threadID
            self.limit = limit
            self.cursor = cursor
            self.sortDirection = sortDirection
        }
    }

    public struct ThreadTurnsPage: Sendable, Equatable {
        public let backwardsCursor: String?
        public let nextCursor: String?
        public let turns: [TurnInfo]
    }

    public struct ThreadStatus: Sendable, Equatable {
        public let type: ThreadStatusType
        public let activeFlags: [ThreadActiveFlag]
    }

    public struct TurnStartRequest: Sendable, Equatable {
        public var approvalPolicy: ApprovalPolicy?
        public var approvalsReviewer: ApprovalsReviewer?
        public var currentDirectoryPath: String?
        public var effort: ReasoningEffort?
        public var input: [TurnInput]
        public var model: String?
        public var outputSchema: JSONValue?
        public var personality: Personality?
        public var serviceTier: ServiceTier?
        public var summary: ReasoningSummary?
        public var threadID: String

        public init(
            threadID: String,
            input: [TurnInput],
            approvalPolicy: ApprovalPolicy? = nil,
            approvalsReviewer: ApprovalsReviewer? = nil,
            currentDirectoryPath: String? = nil,
            effort: ReasoningEffort? = nil,
            model: String? = nil,
            outputSchema: JSONValue? = nil,
            personality: Personality? = nil,
            serviceTier: ServiceTier? = nil,
            summary: ReasoningSummary? = nil
        ) {
            self.threadID = threadID
            self.input = input
            self.approvalPolicy = approvalPolicy
            self.approvalsReviewer = approvalsReviewer
            self.currentDirectoryPath = currentDirectoryPath
            self.effort = effort
            self.model = model
            self.outputSchema = outputSchema
            self.personality = personality
            self.serviceTier = serviceTier
            self.summary = summary
        }
    }

    public struct TurnSession: Sendable, Equatable {
        public let turn: TurnInfo
    }

    public struct TurnInfo: Sendable, Equatable {
        public let completedAt: Int?
        public let durationMS: Int?
        public let errorMessage: String?
        public let id: String
        public let startedAt: Int?
        public let status: TurnStatus
    }

    public struct TurnInput: Sendable, Equatable {
        public enum Kind: String, Sendable, Equatable {
            case image, localImage, mention, skill, text
        }

        public var kind: Kind
        public var text: String?
        public var url: String?
        public var path: String?
        public var name: String?

        public init(
            kind: Kind,
            text: String? = nil,
            url: String? = nil,
            path: String? = nil,
            name: String? = nil
        ) {
            self.kind = kind
            self.text = text
            self.url = url
            self.path = path
            self.name = name
        }

        public static func text(_ text: String) -> Self {
            .init(kind: .text, text: text)
        }
    }

    public enum JSONValue: Sendable, Equatable {
        case null
        case bool(Bool)
        case integer(Int)
        case double(Double)
        case string(String)
        case array([JSONValue])
        case object([String: JSONValue])
    }

    public enum ApprovalPolicy: Sendable, Equatable {
        case never
        case onFailure
        case onRequest
        case untrusted
        case granular(GranularApprovalPolicy)
    }

    public struct GranularApprovalPolicy: Sendable, Equatable {
        public var mcpElicitations: Bool
        public var requestPermissions: Bool?
        public var rules: Bool
        public var sandboxApproval: Bool
        public var skillApproval: Bool?

        public init(
            mcpElicitations: Bool,
            requestPermissions: Bool? = nil,
            rules: Bool,
            sandboxApproval: Bool,
            skillApproval: Bool? = nil
        ) {
            self.mcpElicitations = mcpElicitations
            self.requestPermissions = requestPermissions
            self.rules = rules
            self.sandboxApproval = sandboxApproval
            self.skillApproval = skillApproval
        }
    }

    public enum ApprovalsReviewer: String, Sendable, Equatable {
        case guardianSubagent, user
    }

    public enum Personality: String, Sendable, Equatable {
        case friendly, none, pragmatic
    }

    public enum SandboxMode: String, Sendable, Equatable {
        case dangerFullAccess, readOnly, workspaceWrite
    }

    public enum ServiceTier: String, Sendable, Equatable {
        case fast, flex
    }

    public enum SessionStartSource: String, Sendable, Equatable {
        case clear, startup
    }

    public enum ReasoningEffort: String, Sendable, Equatable {
        case high
        case low
        case medium
        case minimal
        case none
        case xhigh
    }

    public struct SandboxPolicy: Sendable, Equatable {
        public let type: SandboxPolicyType
        public let access: ReadOnlyAccess?
        public let networkAccess: NetworkAccess?
        public let excludeSlashTmp: Bool?
        public let excludeTmpdirEnvVar: Bool?
        public let readOnlyAccess: ReadOnlyAccess?
        public let writableRoots: [String]
    }

    public struct ReadOnlyAccess: Sendable, Equatable {
        public let includePlatformDefaults: Bool?
        public let readableRoots: [String]
        public let type: ReadOnlyAccessType
    }

    public enum ReadOnlyAccessType: String, Sendable, Equatable {
        case fullAccess, restricted
    }

    public enum NetworkAccess: Sendable, Equatable {
        case explicit(Bool), enabled, restricted
    }

    public enum SandboxPolicyType: String, Sendable, Equatable {
        case dangerFullAccess, externalSandbox, readOnly, workspaceWrite
    }

    public enum ReasoningSummary: String, Sendable, Equatable {
        case auto, concise, detailed, none
    }

    public enum ThreadStatusType: String, Sendable, Equatable {
        case active, idle, notLoaded, systemError
    }

    public enum ThreadActiveFlag: String, Sendable, Equatable {
        case waitingOnApproval, waitingOnUserInput
    }

    public enum TurnStatus: String, Sendable, Equatable {
        case completed, failed, inProgress, interrupted
    }

    private enum ThreadTurnActivity: Sendable, Equatable {
        case starting, active(turnID: String)
    }

    private struct ThreadObservableActivityState: Sendable, Equatable {
        var activeToolLikeItemIDs: Set<String> = []
        var activeMcpItemIDs: Set<String> = []
        var hasToolErrorResidue = false
        var hasMcpErrorResidue = false
        var isCompactingThreadContext = false
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
    private let historyStore: ThreadHistoryStore?
    private let historyStoreInitializationError: Error?
    private var serverEventTask: Task<Void, Never>?
    private var threadStatuses: [String: ThreadStatus] = [:]
    private var threadEventContinuations: [String: [UUID: AsyncThrowingStream<CodexThreadEvent, Error>.Continuation]] = [:]
    private var bufferedThreadEvents: [String: [CodexThreadEvent]] = [:]
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
        finishAllTurnEventStreams(throwing: nil)
        await transport.stop()
        hasStarted = false
        hasCompletedInitializeHandshake = false
        threadStatuses.removeAll()
        threadTurnActivities.removeAll()
        threadObservableActivityStates.removeAll()
        turnThreadIDs.removeAll()
        bufferedThreadEvents.removeAll()
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

    internal func threadObservableActivityState(threadID: String) -> CodexThread.Dashboard.ActivityState {
        let state = threadObservableActivityStates[threadID] ?? .init()
        return .init(
            activeMcpItemIDs: state.activeMcpItemIDs,
            activeToolLikeItemIDs: state.activeToolLikeItemIDs,
            hasMcpErrorResidue: state.hasMcpErrorResidue,
            hasToolErrorResidue: state.hasToolErrorResidue,
            isCompactingThreadContext: state.isCompactingThreadContext
        )
    }

    internal func debugThreadHistorySnapshot(
        threadID: String
    ) async throws -> ThreadHistoryStore.ThreadSnapshot? {
        try await requireHistoryStore(for: "thread history snapshot").snapshot(threadID: threadID)
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
        threadObservableActivityStates.removeValue(forKey: threadID)
        turnThreadIDs = turnThreadIDs.filter { $0.value != threadID }
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
            threadObservableActivityStates[notification.threadID] = .init()
            let turn = TurnInfo(wireValue: notification.turn)
            let completion = CodexTurnCompletion(
                threadID: notification.threadID,
                turn: turn
            )
            let turnEvent = CodexTurnEvent.completed(completion)
            publishTurnEvent(turnEvent, for: notification.turn.id, isTerminal: true)
            try? await historyStore?.recordTurnCompleted(
                threadID: notification.threadID,
                turn: turn
            )
        }
    }

    private func handleServerEventStreamEnded() {
        serverEventTask = nil

        guard hasStarted, !isStopping else {
            finishAllThreadEventStreams(throwing: nil)
            finishAllTurnEventStreams(throwing: nil)
            return
        }

        finishAllThreadEventStreams(
            throwing: CodexAppServerError.transportFailure(
                operation: "server events",
                reason: "Codex app-server stopped delivering thread notifications before pending thread streams finished."
            )
        )
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
                proposedExecpolicyAmendment: proposedExecpolicyAmendment,
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
        case let .acceptWithExecpolicyAmendment(amendment):
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
            ephemeral: ephemeral,
            model: model,
            modelProvider: modelProvider,
            personality: personality?.wireValue,
            sandbox: sandboxMode?.wireValue,
            serviceName: serviceName,
            serviceTier: serviceTier?.wireValue,
            sessionStartSource: sessionStartSource?.wireValue
        )
    }
}

private extension CodexAppServer.TurnStartRequest {
    var wireValue: CodexWireTurnStartParams {
        CodexWireTurnStartParams(
            approvalPolicy: approvalPolicy?.wireValue,
            approvalsReviewer: approvalsReviewer?.wireValue,
            cwd: currentDirectoryPath,
            effort: effort?.wireValue,
            input: input.map(\.wireValue),
            model: model,
            outputSchema: outputSchema?.wireValue,
            personality: personality?.wireValue,
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

private extension CodexAppServer.JSONValue {
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
        case .guardianSubagent:
            self = .guardianSubagent
        case .user:
            self = .user
        }
    }

    var wireValue: CodexWireApprovalsReviewer {
        switch self {
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

private extension CodexAppServer.ReasoningEffort {
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
            access: wireValue.access.map { CodexAppServer.ReadOnlyAccess(wireValue: $0) },
            networkAccess: wireValue.networkAccess.map { CodexAppServer.NetworkAccess(wireValue: $0) },
            excludeSlashTmp: wireValue.excludeSlashTmp,
            excludeTmpdirEnvVar: wireValue.excludeTmpdirEnvVar,
            readOnlyAccess: wireValue.readOnlyAccess.map { CodexAppServer.ReadOnlyAccess(wireValue: $0) },
            writableRoots: wireValue.writableRoots ?? []
        )
    }
}

private extension CodexAppServer.ReadOnlyAccess {
    init(wireValue: CodexWireReadOnlyAccess) {
        self.init(
            includePlatformDefaults: wireValue.includePlatformDefaults,
            readableRoots: wireValue.readableRoots ?? [],
            type: .init(wireValue: wireValue.type)
        )
    }
}

private extension CodexAppServer.ReadOnlyAccessType {
    init(wireValue: CodexWireReadOnlyAccessType) {
        switch wireValue {
        case .fullAccess:
            self = .fullAccess
        case .restricted:
            self = .restricted
        }
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
