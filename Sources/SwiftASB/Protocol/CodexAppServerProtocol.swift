import Foundation

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

private struct JSONRPCErrorEnvelope: Decodable {
    let error: JSONRPCErrorBody
    let id: CodexRPCRequestID
}

private struct JSONRPCErrorBody: Decodable {
    let code: Int
    let data: CodexWireJSONValue?
    let message: String
}
