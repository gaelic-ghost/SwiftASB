import Foundation

internal enum CodexTransportError: Error, Sendable, LocalizedError, Equatable {
    case alreadyStarted
    case notStarted
    case executableDiscoveryFailed(reason: String)
    case failedToLaunch(
        executable: String,
        reason: String,
        discoverySource: String?,
        versionString: String?,
        compatibilityNote: String?
    )
    case failedToWriteRequest(id: CodexRPCRequestID, reason: String)
    case failedToWriteNotification(method: String, reason: String)
    case duplicatePendingRequest(id: CodexRPCRequestID)
    case requestCancelled(id: CodexRPCRequestID)
    case invalidJSONRPCEnvelope(reason: String)
    case processTerminated(reason: String, status: Int32?, recentStandardError: [String])
    case unexpectedEndOfStream(recentStandardError: [String])

    internal var errorDescription: String? {
        switch self {
        case .alreadyStarted:
            return "Codex app-server transport is already running."
        case .notStarted:
            return "Codex app-server transport has not been started yet."
        case let .executableDiscoveryFailed(reason):
            return reason
        case let .failedToLaunch(executable, reason, discoverySource, versionString, compatibilityNote):
            var lines = ["Failed to launch Codex app-server transport using \(executable): \(reason)"]
            if let discoverySource {
                lines.append("Resolved executable source: \(discoverySource)")
            }
            if let versionString {
                lines.append("Resolved Codex CLI version: \(versionString)")
            }
            if let compatibilityNote {
                lines.append("Compatibility note: \(compatibilityNote)")
            }
            return lines.joined(separator: "\n")
        case let .failedToWriteRequest(id, reason):
            return "Failed to write JSON-RPC request \(id.description) to Codex app-server stdin: \(reason)"
        case let .failedToWriteNotification(method, reason):
            return "Failed to write JSON-RPC notification \(method) to Codex app-server stdin: \(reason)"
        case let .duplicatePendingRequest(id):
            return "Refused to register a duplicate in-flight JSON-RPC request with ID \(id.description)."
        case let .requestCancelled(id):
            return "The in-flight JSON-RPC request \(id.description) was cancelled before Codex app-server returned a response."
        case let .invalidJSONRPCEnvelope(reason):
            return "Received a malformed JSON-RPC envelope from Codex app-server: \(reason)"
        case let .processTerminated(reason, status, recentStandardError):
            let statusText = status.map(String.init) ?? "unknown"
            if recentStandardError.isEmpty {
                return "Codex app-server transport terminated unexpectedly (\(reason), status \(statusText))."
            }
            return """
            Codex app-server transport terminated unexpectedly (\(reason), status \(statusText)).
            Recent stderr:
            \(recentStandardError.joined(separator: "\n"))
            """
        case let .unexpectedEndOfStream(recentStandardError):
            if recentStandardError.isEmpty {
                return "Codex app-server stdout closed before all pending requests completed."
            }
            return """
            Codex app-server stdout closed before all pending requests completed.
            Recent stderr:
            \(recentStandardError.joined(separator: "\n"))
            """
        }
    }
}
