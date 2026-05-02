import Foundation

/// Error surfaced by the public app-server client API.
public enum CodexAppServerError: Error, Sendable, LocalizedError, Equatable {
    case invalidState(reason: String)
    case transportFailure(operation: String, reason: String)
    case protocolFailure(operation: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case let .invalidState(reason):
            return reason
        case let .transportFailure(operation, reason):
            return "Codex app-server transport failed during \(operation): \(reason)"
        case let .protocolFailure(operation, reason):
            return "Codex app-server protocol handling failed during \(operation): \(reason)"
        }
    }
}

internal extension CodexAppServerError {
    static func wrap(_ error: Error, operation: String) -> Self {
        if let appServerError = error as? CodexAppServerError {
            return appServerError
        }

        if let transportError = error as? CodexTransportError {
            return .transportFailure(
                operation: operation,
                reason: transportError.localizedDescription
            )
        }

        if let protocolError = error as? CodexProtocolError {
            return .protocolFailure(
                operation: operation,
                reason: protocolError.localizedDescription
            )
        }

        return .protocolFailure(
            operation: operation,
            reason: String(describing: error)
        )
    }
}
