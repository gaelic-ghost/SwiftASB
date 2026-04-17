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
        case .request:
            return nil
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
}

private struct JSONRPCRequestEnvelope<Params: Encodable>: Encodable {
    let jsonrpc = "2.0"
    let id: CodexRPCRequestID
    let method: CodexAppServerProtocol.Method
    let params: Params
}

private struct JSONRPCNotificationEnvelope: Encodable {
    let jsonrpc = "2.0"
    let method: CodexAppServerProtocol.Method
}

private struct JSONRPCResponseEnvelope<Result: Decodable>: Decodable {
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
