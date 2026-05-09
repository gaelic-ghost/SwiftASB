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

/// Error surfaced by the one-call app-server startup API.
public enum CodexAppServerStartupError: Error, Sendable, LocalizedError, Equatable {
    case codexCLINotFound(reason: String)
    case incompatibleCodexCLI(diagnostics: CodexAppServer.CLIExecutableDiagnostics)
    case unknownCodexCLIVersion(diagnostics: CodexAppServer.CLIExecutableDiagnostics)
    case launchFailed(reason: String)
    case initializeFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case let .codexCLINotFound(reason):
            return "SwiftASB could not find a compatible Codex CLI executable for app-server startup: \(reason)"
        case let .incompatibleCodexCLI(diagnostics):
            return """
            SwiftASB found Codex CLI \(diagnostics.versionString), but startup requires a version inside \
            SwiftASB's documented reviewed support window.
            """
        case let .unknownCodexCLIVersion(diagnostics):
            return """
            SwiftASB found Codex CLI \(diagnostics.versionString), but could not parse its version string \
            against SwiftASB's documented reviewed support window.
            """
        case let .launchFailed(reason):
            return "SwiftASB could not launch the Codex app-server during startup: \(reason)"
        case let .initializeFailed(reason):
            return "SwiftASB launched the Codex app-server but could not complete startup initialization: \(reason)"
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

internal extension CodexAppServerStartupError {
    static func startFailure(from error: Error) -> Self {
        if let startupError = error as? CodexAppServerStartupError {
            return startupError
        }

        if let transportError = error as? CodexTransportError {
            switch transportError {
            case let .executableDiscoveryFailed(reason):
                return .codexCLINotFound(reason: reason)
            case .alreadyStarted:
                return .launchFailed(reason: transportError.localizedDescription)
            case .failedToLaunch:
                return .launchFailed(reason: transportError.localizedDescription)
            default:
                return .launchFailed(reason: transportError.localizedDescription)
            }
        }

        if let appServerError = error as? CodexAppServerError {
            return .launchFailed(reason: appServerError.localizedDescription)
        }

        return .launchFailed(reason: String(describing: error))
    }

    static func initializeFailure(from error: Error) -> Self {
        if let startupError = error as? CodexAppServerStartupError {
            return startupError
        }

        if let appServerError = error as? CodexAppServerError {
            return .initializeFailed(reason: appServerError.localizedDescription)
        }

        return .initializeFailed(reason: String(describing: error))
    }
}
