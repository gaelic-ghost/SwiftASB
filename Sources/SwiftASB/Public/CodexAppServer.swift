import Foundation

public actor CodexAppServer {
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
            case image
            case localImage
            case mention
            case skill
            case text
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
        case guardianSubagent
        case user
    }

    public enum Personality: String, Sendable, Equatable {
        case friendly
        case none
        case pragmatic
    }

    public enum SandboxMode: String, Sendable, Equatable {
        case dangerFullAccess
        case readOnly
        case workspaceWrite
    }

    public enum ServiceTier: String, Sendable, Equatable {
        case fast
        case flex
    }

    public enum SessionStartSource: String, Sendable, Equatable {
        case clear
        case startup
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
        case fullAccess
        case restricted
    }

    public enum NetworkAccess: Sendable, Equatable {
        case explicit(Bool)
        case enabled
        case restricted
    }

    public enum SandboxPolicyType: String, Sendable, Equatable {
        case dangerFullAccess
        case externalSandbox
        case readOnly
        case workspaceWrite
    }

    public enum ReasoningSummary: String, Sendable, Equatable {
        case auto
        case concise
        case detailed
        case none
    }

    public enum ThreadStatusType: String, Sendable, Equatable {
        case active
        case idle
        case notLoaded
        case systemError
    }

    public enum ThreadActiveFlag: String, Sendable, Equatable {
        case waitingOnApproval
        case waitingOnUserInput
    }

    public enum TurnStatus: String, Sendable, Equatable {
        case completed
        case failed
        case inProgress
        case interrupted
    }

    private let transport: any CodexAppServerTransporting
    private let protocolLayer: CodexAppServerProtocol
    private var serverEventTask: Task<Void, Never>?
    private var turnEventContinuations: [String: [UUID: AsyncThrowingStream<CodexTurnEvent, Error>.Continuation]] = [:]
    private var bufferedTerminalTurnEvents: [String: CodexTurnEvent] = [:]
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
    }

    internal init(
        transport: any CodexAppServerTransporting,
        protocolLayer: CodexAppServerProtocol = CodexAppServerProtocol()
    ) {
        self.transport = transport
        self.protocolLayer = protocolLayer
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
        finishAllTurnEventStreams(throwing: nil)
        await transport.stop()
        hasStarted = false
        hasCompletedInitializeHandshake = false
        bufferedTerminalTurnEvents.removeAll()
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

            return CodexThread(
                appServer: self,
                session: ThreadSession(wireValue: response)
            )
        } catch {
            throw CodexAppServerError.wrap(error, operation: "thread/start")
        }
    }

    public func startTurn(_ request: TurnStartRequest) async throws -> CodexTurnHandle {
        try requireInitialized(for: "turn/start")

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
            return CodexTurnHandle(
                threadID: request.threadID,
                turn: turn,
                events: makeTurnEventStream(turnID: turn.id)
            )
        } catch {
            throw CodexAppServerError.wrap(error, operation: "turn/start")
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
                await self.finishAllTurnEventStreams(
                    throwing: CodexAppServerError.wrap(error, operation: "server events")
                )
            }
        }
    }

    private func handleProtocolEvent(_ event: CodexAppServerProtocolEvent) {
        switch event {
        case .threadStarted,
             .threadStatusChanged,
             .threadNameUpdated,
             .threadTokenUsageUpdated,
             .turnStarted,
             .turnDiffUpdated,
             .turnPlanUpdated,
             .itemStarted,
             .itemCompleted,
             .agentMessageDelta,
             .planDelta,
             .reasoningSummaryPartAdded,
             .reasoningSummaryTextDelta,
             .reasoningTextDelta:
            return
        case let .turnCompleted(notification):
            let completion = CodexTurnCompletion(
                threadID: notification.threadID,
                turn: TurnInfo(wireValue: notification.turn)
            )
            let turnEvent = CodexTurnEvent.completed(completion)
            publishTurnEvent(turnEvent, for: notification.turn.id, isTerminal: true)
        }
    }

    private func handleServerEventStreamEnded() {
        serverEventTask = nil

        guard hasStarted, !isStopping else {
            finishAllTurnEventStreams(throwing: nil)
            return
        }

        finishAllTurnEventStreams(
            throwing: CodexAppServerError.transportFailure(
                operation: "server events",
                reason: "Codex app-server stopped delivering notifications before pending turn streams finished."
            )
        )
    }

    private func makeTurnEventStream(
        turnID: String
    ) -> AsyncThrowingStream<CodexTurnEvent, Error> {
        let streamID = UUID()

        return AsyncThrowingStream { continuation in
            registerTurnEventContinuation(continuation, streamID: streamID, turnID: turnID)

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

    private func publishTurnEvent(
        _ event: CodexTurnEvent,
        for turnID: String,
        isTerminal: Bool
    ) {
        guard let continuations = turnEventContinuations.removeValue(forKey: turnID), !continuations.isEmpty else {
            if isTerminal {
                bufferedTerminalTurnEvents[turnID] = event
            }
            return
        }

        for continuation in continuations.values {
            continuation.yield(event)
            if isTerminal {
                continuation.finish()
            }
        }
    }

    private func finishAllTurnEventStreams(throwing error: CodexAppServerError?) {
        let activeContinuations = turnEventContinuations.values.flatMap(\.values)
        turnEventContinuations.removeAll()

        for continuation in activeContinuations {
            if let error {
                continuation.finish(throwing: error)
            } else {
                continuation.finish()
            }
        }
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
