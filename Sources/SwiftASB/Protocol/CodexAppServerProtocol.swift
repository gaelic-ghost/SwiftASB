import Foundation

internal enum CodexAppServerProtocolEvent: Equatable, Sendable {
    case threadStarted(CodexWireThreadStartedNotification)
    case threadStatusChanged(CodexWireThreadStatusChangedNotification)
    case threadArchived(CodexWireThreadArchivedNotification)
    case threadUnarchived(CodexWireThreadUnarchivedNotification)
    case threadClosed(CodexWireThreadClosedNotification)
    case threadNameUpdated(CodexWireThreadNameUpdatedNotification)
    case threadTokenUsageUpdated(CodexWireThreadTokenUsageUpdatedNotification)
    case turnStarted(CodexWireTurnStartedNotification)
    case turnDiffUpdated(CodexWireTurnDiffUpdatedNotification)
    case turnPlanUpdated(CodexWireTurnPlanUpdatedNotification)
    case turnCompleted(CodexWireTurnCompletedNotification)
    case itemStarted(CodexWireItemStartedNotification)
    case itemCompleted(CodexWireItemCompletedNotification)
    case agentMessageDelta(CodexWireAgentMessageDeltaNotification)
    case planDelta(CodexWirePlanDeltaNotification)
    case reasoningSummaryPartAdded(CodexWireReasoningSummaryPartAddedNotification)
    case reasoningSummaryTextDelta(CodexWireReasoningSummaryTextDeltaNotification)
    case reasoningTextDelta(CodexWireReasoningTextDeltaNotification)
    case commandExecutionApprovalRequested(CodexProtocolCommandExecutionApprovalRequest)
    case fileChangeApprovalRequested(CodexProtocolFileChangeApprovalRequest)
    case permissionsApprovalRequested(CodexProtocolPermissionsApprovalRequest)
    case toolUserInputRequested(CodexProtocolToolUserInputRequest)
    case mcpServerElicitationRequested(CodexProtocolMCPServerElicitationRequest)
    case serverRequestResolved(CodexWireServerRequestResolvedNotification)
}

internal struct CodexProtocolCommandExecutionApprovalRequest: Decodable, Equatable, Sendable {
    let approvalID: String?
    let command: String?
    let commandActions: [CodexProtocolCommandAction]?
    let cwd: String?
    let itemID: String
    let networkApprovalContext: CodexWireJSONValue?
    let proposedExecpolicyAmendment: [String]?
    let proposedNetworkPolicyAmendments: [CodexProtocolNetworkPolicyAmendment]?
    let reason: String?
    var requestID: CodexRPCRequestID = .string("unbound")
    let threadID: String
    let turnID: String

    enum CodingKeys: String, CodingKey {
        case approvalID = "approvalId"
        case command
        case commandActions
        case cwd
        case itemID = "itemId"
        case networkApprovalContext
        case proposedExecpolicyAmendment
        case proposedNetworkPolicyAmendments
        case reason
        case threadID = "threadId"
        case turnID = "turnId"
    }
}

internal struct CodexProtocolFileChangeApprovalRequest: Decodable, Equatable, Sendable {
    let grantRoot: String?
    let itemID: String
    let reason: String?
    var requestID: CodexRPCRequestID = .string("unbound")
    let threadID: String
    let turnID: String

    enum CodingKeys: String, CodingKey {
        case grantRoot
        case itemID = "itemId"
        case reason
        case threadID = "threadId"
        case turnID = "turnId"
    }
}

internal struct CodexProtocolPermissionsApprovalRequest: Decodable, Equatable, Sendable {
    let itemID: String
    let permissions: CodexProtocolPermissionProfile
    let reason: String?
    var requestID: CodexRPCRequestID = .string("unbound")
    let threadID: String
    let turnID: String

    enum CodingKeys: String, CodingKey {
        case itemID = "itemId"
        case permissions
        case reason
        case threadID = "threadId"
        case turnID = "turnId"
    }
}

internal struct CodexProtocolToolUserInputRequest: Decodable, Equatable, Sendable {
    let itemID: String
    let questions: [Question]
    var requestID: CodexRPCRequestID = .string("unbound")
    let threadID: String
    let turnID: String

    enum CodingKeys: String, CodingKey {
        case itemID = "itemId"
        case questions
        case threadID = "threadId"
        case turnID = "turnId"
    }

    internal struct Question: Decodable, Equatable, Sendable {
        let header: String
        let id: String
        let isOther: Bool
        let isSecret: Bool
        let options: [Option]?
        let question: String

        enum CodingKeys: String, CodingKey {
            case header
            case id
            case isOther
            case isSecret
            case options
            case question
        }

        internal struct Option: Decodable, Equatable, Sendable {
            let description: String
            let label: String
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            header = try container.decode(String.self, forKey: .header)
            id = try container.decode(String.self, forKey: .id)
            isOther = try container.decodeIfPresent(Bool.self, forKey: .isOther) ?? false
            isSecret = try container.decodeIfPresent(Bool.self, forKey: .isSecret) ?? false
            options = try container.decodeIfPresent([Option].self, forKey: .options)
            question = try container.decode(String.self, forKey: .question)
        }
    }
}

internal struct CodexProtocolMCPServerElicitationRequest: Decodable, Equatable, Sendable {
    let mode: Mode
    let requestID: CodexRPCRequestID
    let serverName: String
    let threadID: String
    let turnID: String?

    enum CodingKeys: String, CodingKey {
        case serverName
        case threadID = "threadId"
        case turnID = "turnId"
        case mode
    }

    internal enum Mode: Equatable, Sendable {
        case form(Form)
        case url(URLPrompt)
    }

    internal struct Form: Decodable, Equatable, Sendable {
        let message: String
        let requestedSchema: CodexWireJSONValue

        enum CodingKeys: String, CodingKey {
            case message
            case requestedSchema
        }
    }

    internal struct URLPrompt: Decodable, Equatable, Sendable {
        let elicitationID: String
        let message: String
        let url: String

        enum CodingKeys: String, CodingKey {
            case elicitationID = "elicitationId"
            case message
            case url
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        serverName = try container.decode(String.self, forKey: .serverName)
        threadID = try container.decode(String.self, forKey: .threadID)
        turnID = try container.decodeIfPresent(String.self, forKey: .turnID)
        requestID = .string("unbound")

        let modeValue = try container.decode(String.self, forKey: .mode)
        switch modeValue {
        case "form":
            mode = .form(try Form(from: decoder))
        case "url":
            mode = .url(try URLPrompt(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .mode,
                in: container,
                debugDescription: "Unsupported MCP elicitation mode \(modeValue)."
            )
        }
    }
}

internal enum CodexProtocolCommandAction: Decodable, Equatable, Sendable {
    case read(Read)
    case listFiles(ListFiles)
    case search(Search)
    case unknown(Unknown)

    internal struct Read: Decodable, Equatable, Sendable {
        let command: String
        let name: String
        let path: String

        enum CodingKeys: String, CodingKey {
            case command
            case name
            case path
        }
    }

    internal struct ListFiles: Decodable, Equatable, Sendable {
        let command: String
        let path: String?

        enum CodingKeys: String, CodingKey {
            case command
            case path
        }
    }

    internal struct Search: Decodable, Equatable, Sendable {
        let command: String
        let path: String?
        let query: String?

        enum CodingKeys: String, CodingKey {
            case command
            case path
            case query
        }
    }

    internal struct Unknown: Decodable, Equatable, Sendable {
        let command: String

        enum CodingKeys: String, CodingKey {
            case command
        }
    }

    private enum CodingKeys: String, CodingKey {
        case command
        case name
        case path
        case query
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "read":
            self = .read(
                .init(
                    command: try container.decode(String.self, forKey: .command),
                    name: try container.decode(String.self, forKey: .name),
                    path: try container.decode(String.self, forKey: .path)
                )
            )
        case "listFiles":
            self = .listFiles(
                .init(
                    command: try container.decode(String.self, forKey: .command),
                    path: try container.decodeIfPresent(String.self, forKey: .path)
                )
            )
        case "search":
            self = .search(
                .init(
                    command: try container.decode(String.self, forKey: .command),
                    path: try container.decodeIfPresent(String.self, forKey: .path),
                    query: try container.decodeIfPresent(String.self, forKey: .query)
                )
            )
        case "unknown":
            self = .unknown(
                .init(command: try container.decode(String.self, forKey: .command))
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unsupported command action type \(type)."
            )
        }
    }
}

internal struct CodexProtocolNetworkPolicyAmendment: Decodable, Equatable, Sendable {
    let action: String
    let host: String
}

internal struct CodexProtocolPermissionProfile: Decodable, Equatable, Sendable {
    let fileSystem: FileSystem?
    let network: Network?

    internal struct FileSystem: Decodable, Equatable, Sendable {
        let read: [String]?
        let write: [String]?
    }

    internal struct Network: Decodable, Equatable, Sendable {
        let enabled: Bool?
    }
}

internal struct CodexAppServerProtocol {
    internal enum Method: String, Sendable, Codable {
        case initialize = "initialize"
        case initialized = "initialized"
        case threadStart = "thread/start"
        case turnStart = "turn/start"
    }

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    internal init(
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.encoder = encoder
        self.decoder = decoder
    }

    internal func makeInitializeRequest(
        id: CodexRPCRequestID,
        params: CodexWireInitializeParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .initialize, params: params),
            method: .initialize
        )
    }

    internal func makeInitializedNotification() throws -> Data {
        try encodeNotification(
            JSONRPCNotificationEnvelope(method: .initialized),
            method: .initialized
        )
    }

    internal func makeThreadStartRequest(
        id: CodexRPCRequestID,
        params: CodexWireThreadStartParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .threadStart, params: params),
            method: .threadStart
        )
    }

    internal func makeTurnStartRequest(
        id: CodexRPCRequestID,
        params: CodexWireTurnStartParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .turnStart, params: params),
            method: .turnStart
        )
    }

    internal func makeServerResponse<Result: Encodable>(
        id: CodexRPCRequestID,
        result: Result
    ) throws -> Data {
        do {
            return try encoder.encode(JSONRPCResultEnvelope(id: id, result: result))
        } catch {
            throw CodexProtocolError.requestEncodingFailed(
                method: "server request response",
                reason: String(describing: error)
            )
        }
    }

    internal func decodeInitializeResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireInitializeResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .initialize,
            resultType: CodexWireInitializeResponse.self
        )
    }

    internal func decodeThreadStartResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireThreadStartResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .threadStart,
            resultType: CodexWireThreadStartResponse.self
        )
    }

    internal func decodeTurnStartResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireTurnStartResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .turnStart,
            resultType: CodexWireTurnStartResponse.self
        )
    }

    internal func decodeServerEvent(
        _ serverEvent: CodexRPCServerEvent
    ) throws -> CodexAppServerProtocolEvent? {
        switch serverEvent {
        case let .request(id, method, payload):
            switch method {
            case "item/commandExecution/requestApproval":
                return .commandExecutionApprovalRequested(
                    try decodeServerRequest(
                        payload,
                        method: method,
                        id: id,
                        requestType: CodexProtocolCommandExecutionApprovalRequest.self
                    )
                )
            case "item/fileChange/requestApproval":
                return .fileChangeApprovalRequested(
                    try decodeServerRequest(
                        payload,
                        method: method,
                        id: id,
                        requestType: CodexProtocolFileChangeApprovalRequest.self
                    )
                )
            case "item/permissions/requestApproval":
                return .permissionsApprovalRequested(
                    try decodeServerRequest(
                        payload,
                        method: method,
                        id: id,
                        requestType: CodexProtocolPermissionsApprovalRequest.self
                    )
                )
            case "item/tool/requestUserInput":
                return .toolUserInputRequested(
                    try decodeServerRequest(
                        payload,
                        method: method,
                        id: id,
                        requestType: CodexProtocolToolUserInputRequest.self
                    )
                )
            case "mcpServer/elicitation/request":
                return .mcpServerElicitationRequested(
                    try decodeMCPServerElicitationRequest(
                        payload,
                        method: method,
                        id: id
                    )
                )
            default:
                return nil
            }
        case let .notification(method, payload):
            switch method {
            case "thread/started":
                return .threadStarted(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireThreadStartedNotification.self
                    )
                )
            case "thread/status/changed":
                return .threadStatusChanged(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireThreadStatusChangedNotification.self
                    )
                )
            case "thread/archived":
                return .threadArchived(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireThreadArchivedNotification.self
                    )
                )
            case "thread/unarchived":
                return .threadUnarchived(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireThreadUnarchivedNotification.self
                    )
                )
            case "thread/closed":
                return .threadClosed(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireThreadClosedNotification.self
                    )
                )
            case "thread/name/updated":
                return .threadNameUpdated(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireThreadNameUpdatedNotification.self
                    )
                )
            case "thread/tokenUsage/updated":
                return .threadTokenUsageUpdated(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireThreadTokenUsageUpdatedNotification.self
                    )
                )
            case "turn/started":
                return .turnStarted(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireTurnStartedNotification.self
                    )
                )
            case "turn/diff/updated":
                return .turnDiffUpdated(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireTurnDiffUpdatedNotification.self
                    )
                )
            case "turn/plan/updated":
                return .turnPlanUpdated(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireTurnPlanUpdatedNotification.self
                    )
                )
            case "turn/completed":
                return .turnCompleted(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireTurnCompletedNotification.self
                    )
                )
            case "item/started":
                return .itemStarted(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireItemStartedNotification.self
                    )
                )
            case "item/completed":
                return .itemCompleted(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireItemCompletedNotification.self
                    )
                )
            case "item/agentMessage/delta":
                return .agentMessageDelta(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireAgentMessageDeltaNotification.self
                    )
                )
            case "item/plan/delta":
                return .planDelta(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWirePlanDeltaNotification.self
                    )
                )
            case "item/reasoning/summaryPartAdded":
                return .reasoningSummaryPartAdded(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireReasoningSummaryPartAddedNotification.self
                    )
                )
            case "item/reasoning/summaryTextDelta":
                return .reasoningSummaryTextDelta(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireReasoningSummaryTextDeltaNotification.self
                    )
                )
            case "item/reasoning/textDelta":
                return .reasoningTextDelta(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireReasoningTextDeltaNotification.self
                    )
                )
            case "serverRequest/resolved":
                return .serverRequestResolved(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireServerRequestResolvedNotification.self
                    )
                )
            default:
                return nil
            }
        }
    }

    private func encodeRequest<Params: Encodable>(
        _ request: JSONRPCRequestEnvelope<Params>,
        method: Method
    ) throws -> Data {
        do {
            return try encoder.encode(request)
        } catch {
            throw CodexProtocolError.requestEncodingFailed(
                method: method.rawValue,
                reason: String(describing: error)
            )
        }
    }

    private func encodeNotification(
        _ notification: JSONRPCNotificationEnvelope,
        method: Method
    ) throws -> Data {
        do {
            return try encoder.encode(notification)
        } catch {
            throw CodexProtocolError.requestEncodingFailed(
                method: method.rawValue,
                reason: String(describing: error)
            )
        }
    }

    private func decodeResponse<Result: Decodable>(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID,
        method: Method,
        resultType: Result.Type
    ) throws -> Result {
        let successfulResponse: JSONRPCResponseEnvelope<Result>
        do {
            successfulResponse = try decoder.decode(
                JSONRPCResponseEnvelope<Result>.self,
                from: responsePayload
            )
        } catch {
            if let rpcError = try? decoder.decode(JSONRPCErrorEnvelope.self, from: responsePayload) {
                throw CodexProtocolError.rpcError(
                    id: rpcError.id,
                    code: rpcError.error.code,
                    message: rpcError.error.message,
                    data: rpcError.error.data
                )
            }

            throw CodexProtocolError.responseDecodingFailed(
                context: method.rawValue,
                reason: String(describing: error)
            )
        }

        guard successfulResponse.id == expectedID else {
            throw CodexProtocolError.responseIDMismatch(
                expected: expectedID,
                actual: successfulResponse.id
            )
        }

        return successfulResponse.result
    }

    private func decodeNotification<Result: Decodable>(
        _ payload: Data,
        method: String,
        resultType: Result.Type
    ) throws -> Result {
        do {
            return try decoder.decode(resultType, from: payload)
        } catch {
            throw CodexProtocolError.eventDecodingFailed(
                method: method,
                reason: String(describing: error)
            )
        }
    }

    private func decodeServerRequest<Request: Decodable & RequestIDBindable>(
        _ payload: Data,
        method: String,
        id: CodexRPCRequestID,
        requestType: Request.Type
    ) throws -> Request {
        do {
            let decoded = try decoder.decode(requestType, from: payload)
            return decoded.settingRequestID(id)
        } catch {
            throw CodexProtocolError.eventDecodingFailed(
                method: method,
                reason: String(describing: error)
            )
        }
    }

    private func decodeMCPServerElicitationRequest(
        _ payload: Data,
        method: String,
        id: CodexRPCRequestID
    ) throws -> CodexProtocolMCPServerElicitationRequest {
        do {
            let decoded = try decoder.decode(CodexProtocolMCPServerElicitationRequest.self, from: payload)
            return decoded.settingRequestID(id)
        } catch {
            throw CodexProtocolError.eventDecodingFailed(
                method: method,
                reason: String(describing: error)
            )
        }
    }
}

private protocol RequestIDBindable {
    func settingRequestID(_ requestID: CodexRPCRequestID) -> Self
}

extension CodexProtocolCommandExecutionApprovalRequest: RequestIDBindable {
    fileprivate func settingRequestID(_ requestID: CodexRPCRequestID) -> Self {
        var copy = self
        copy.requestID = requestID
        return copy
    }
}

extension CodexProtocolFileChangeApprovalRequest: RequestIDBindable {
    fileprivate func settingRequestID(_ requestID: CodexRPCRequestID) -> Self {
        var copy = self
        copy.requestID = requestID
        return copy
    }
}

extension CodexProtocolPermissionsApprovalRequest: RequestIDBindable {
    fileprivate func settingRequestID(_ requestID: CodexRPCRequestID) -> Self {
        var copy = self
        copy.requestID = requestID
        return copy
    }
}

extension CodexProtocolToolUserInputRequest: RequestIDBindable {
    fileprivate func settingRequestID(_ requestID: CodexRPCRequestID) -> Self {
        var copy = self
        copy.requestID = requestID
        return copy
    }
}

extension CodexProtocolMCPServerElicitationRequest {
    fileprivate func settingRequestID(_ requestID: CodexRPCRequestID) -> Self {
        .init(
            mode: mode,
            requestID: requestID,
            serverName: serverName,
            threadID: threadID,
            turnID: turnID
        )
    }

    fileprivate init(
        mode: Mode,
        requestID: CodexRPCRequestID,
        serverName: String,
        threadID: String,
        turnID: String?
    ) {
        self.mode = mode
        self.requestID = requestID
        self.serverName = serverName
        self.threadID = threadID
        self.turnID = turnID
    }
}

private struct JSONRPCRequestEnvelope<Params: Encodable>: Encodable {
    let id: CodexRPCRequestID
    let method: CodexAppServerProtocol.Method
    let params: Params
}

private struct JSONRPCNotificationEnvelope: Encodable {
    let method: CodexAppServerProtocol.Method
}

private struct JSONRPCResponseEnvelope<Result: Decodable>: Decodable {
    let id: CodexRPCRequestID
    let result: Result
}

private struct JSONRPCResultEnvelope<Result: Encodable>: Encodable {
    let id: CodexRPCRequestID
    let result: Result
}

private struct JSONRPCErrorEnvelope: Decodable {
    let error: JSONRPCErrorBody
    let id: CodexRPCRequestID
}

private struct JSONRPCErrorBody: Decodable {
    let code: Int
    let data: CodexWireJSONValue?
    let message: String
}
