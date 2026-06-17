import Foundation

enum CodexProtocolError: Error, LocalizedError, Equatable {
    case requestEncodingFailed(method: String, reason: String)
    case responseDecodingFailed(context: String, reason: String)
    case eventDecodingFailed(method: String, reason: String)
    case responseIDMismatch(expected: CodexRPCRequestID, actual: CodexRPCRequestID)
    case rpcError(id: CodexRPCRequestID, code: Int, message: String, data: CodexWireJSONValue?)

    var errorDescription: String? {
        switch self {
            case let .requestEncodingFailed(method, reason):
                return "Failed to encode Codex app-server request for \(method): \(reason)"
            case let .responseDecodingFailed(context, reason):
                return "Failed to decode Codex app-server response for \(context): \(reason)"
            case let .eventDecodingFailed(method, reason):
                return "Failed to decode Codex app-server notification for \(method): \(reason)"
            case let .responseIDMismatch(expected, actual):
                return """
                Received a Codex app-server response for request ID \(actual.description), \
                but the caller was waiting for \(expected.description).
                """
            case let .rpcError(id, code, message, data):
                if let data {
                    return """
                    Codex app-server returned an RPC error for request \(id.description) \
                    (code \(code)): \(message). Error data: \(data)
                    """
                }
                return "Codex app-server returned an RPC error for request \(id.description) (code \(code)): \(message)"
        }
    }
}
