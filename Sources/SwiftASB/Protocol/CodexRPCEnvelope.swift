import Foundation

internal enum CodexRPCInboundMessage: Equatable, Sendable {
    case response(id: CodexRPCRequestID, payload: Data)
    case serverEvent(CodexRPCServerEvent)
}

internal enum CodexRPCServerEvent: Equatable, Sendable {
    case notification(method: String, payload: Data)
    case request(id: CodexRPCRequestID, method: String, payload: Data)
}

internal enum CodexRPCEnvelope {
    internal static func classifyInboundMessage(_ data: Data) throws -> CodexRPCInboundMessage {
        let object = try parseJSONObject(from: data)

        let method = object["method"] as? String
        let requestID = try object["id"].map(parseRequestID)

        switch (method, requestID) {
        case let (.some(method), .some(id)):
            return .serverEvent(.request(id: id, method: method, payload: data))
        case let (.some(method), .none):
            return .serverEvent(.notification(method: method, payload: data))
        case let (.none, .some(id)):
            return .response(id: id, payload: data)
        case (.none, .none):
            throw CodexTransportError.invalidJSONRPCEnvelope(
                reason: "Expected the inbound message to contain either a method, an ID, or both."
            )
        }
    }

    private static func parseJSONObject(from data: Data) throws -> [String: Any] {
        let json = try JSONSerialization.jsonObject(with: data)
        guard let object = json as? [String: Any] else {
            throw CodexTransportError.invalidJSONRPCEnvelope(
                reason: "Expected the inbound JSON-RPC payload to be a top-level object."
            )
        }
        return object
    }

    private static func parseRequestID(_ rawValue: Any) throws -> CodexRPCRequestID {
        if let string = rawValue as? String {
            return .string(string)
        }

        if rawValue is Bool {
            throw CodexTransportError.invalidJSONRPCEnvelope(
                reason: "JSON-RPC request IDs must not be booleans."
            )
        }

        if let integer = rawValue as? Int {
            return .int(integer)
        }

        if let number = rawValue as? NSNumber {
            let doubleValue = number.doubleValue
            let integerValue = number.intValue
            guard doubleValue.rounded(.towardZero) == doubleValue else {
                throw CodexTransportError.invalidJSONRPCEnvelope(
                    reason: "JSON-RPC numeric request IDs must be whole numbers."
                )
            }
            return .int(integerValue)
        }

        throw CodexTransportError.invalidJSONRPCEnvelope(
            reason: "Unsupported JSON-RPC request ID type \(String(describing: type(of: rawValue)))."
        )
    }
}
