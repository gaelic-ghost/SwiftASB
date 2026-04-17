import Foundation

internal enum CodexRPCRequestID: Hashable, Sendable, Codable, CustomStringConvertible {
    case string(String)
    case int(Int)

    internal static func generated() -> Self {
        .string(UUID().uuidString)
    }

    internal var description: String {
        switch self {
        case let .string(value):
            value
        case let .int(value):
            String(value)
        }
    }

    internal init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
            return
        }
        if let integer = try? container.decode(Int.self) {
            self = .int(integer)
            return
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Expected a JSON-RPC request ID to be either a string or an integer."
        )
    }

    internal func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        }
    }
}
