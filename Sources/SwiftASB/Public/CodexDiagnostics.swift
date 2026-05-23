public enum CodexDiagnosticEvent: Sendable, Equatable {
    case warning(CodexRuntimeWarning)
    case guardianWarning(CodexGuardianWarning)
    case modelRerouted(CodexModelReroute)
    case modelVerification(CodexModelVerificationDiagnostic)
    case configWarning(CodexConfigWarning)
    case deprecationNotice(CodexDeprecationNotice)
    case mcpServerStatusChanged(CodexMcpServerStatusDiagnostic)
    case remoteControlStatusChanged(CodexRemoteControlStatusDiagnostic)

    public var threadID: String? {
        switch self {
        case let .warning(warning):
            warning.threadID
        case let .guardianWarning(warning):
            warning.threadID
        case let .modelRerouted(reroute):
            reroute.threadID
        case let .modelVerification(verification):
            verification.threadID
        case .configWarning, .deprecationNotice, .mcpServerStatusChanged, .remoteControlStatusChanged:
            nil
        }
    }

    public var turnID: String? {
        switch self {
        case .warning, .guardianWarning:
            nil
        case let .modelRerouted(reroute):
            reroute.turnID
        case let .modelVerification(verification):
            verification.turnID
        case .configWarning, .deprecationNotice, .mcpServerStatusChanged, .remoteControlStatusChanged:
            nil
        }
    }
}

public struct CodexRuntimeWarning: Sendable, Equatable {
    public let message: String
    public let threadID: String?

    init(message: String, threadID: String?) {
        self.message = message
        self.threadID = threadID
    }
}

public struct CodexGuardianWarning: Sendable, Equatable {
    public let message: String
    public let threadID: String

    init(message: String, threadID: String) {
        self.message = message
        self.threadID = threadID
    }
}

public struct CodexModelReroute: Sendable, Equatable {
    public let fromModel: String
    public let reason: Reason
    public let threadID: String
    public let toModel: String
    public let turnID: String

    init(
        fromModel: String,
        reason: Reason,
        threadID: String,
        toModel: String,
        turnID: String
    ) {
        self.fromModel = fromModel
        self.reason = reason
        self.threadID = threadID
        self.toModel = toModel
        self.turnID = turnID
    }

    public enum Reason: Sendable, Equatable {
        case highRiskCyberActivity
    }
}

public struct CodexModelVerificationDiagnostic: Sendable, Equatable {
    public let threadID: String
    public let turnID: String
    public let verifications: [CodexModelVerification]

    init(
        threadID: String,
        turnID: String,
        verifications: [CodexModelVerification]
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.verifications = verifications
    }
}

public enum CodexModelVerification: Sendable, Equatable {
    case trustedAccessForCyber
}

public struct CodexConfigWarning: Sendable, Equatable {
    public let details: String?
    public let path: String?
    public let range: CodexTextRange?
    public let summary: String
}

public struct CodexTextRange: Sendable, Equatable {
    public let start: CodexTextPosition
    public let end: CodexTextPosition
}

public struct CodexTextPosition: Sendable, Equatable {
    public let line: Int
    public let column: Int
}

public struct CodexDeprecationNotice: Sendable, Equatable {
    public let details: String?
    public let summary: String
}

public struct CodexMcpServerStatusDiagnostic: Sendable, Equatable {
    public let error: String?
    public let name: String
    public let status: Status

    public enum Status: String, Sendable, Equatable {
        case cancelled
        case failed
        case ready
        case starting
    }
}

public struct CodexRemoteControlStatusDiagnostic: Sendable, Equatable {
    public let environmentID: String?
    public let installationID: String
    public let serverName: String
    public let status: Status

    public enum Status: String, Sendable, Equatable {
        case connected
        case connecting
        case disabled
        case errored
    }
}

extension CodexDiagnosticEvent {
    init(wireValue: CodexWireWarningNotification) {
        self = .warning(
            .init(
                message: wireValue.message,
                threadID: wireValue.threadID
            )
        )
    }

    init(wireValue: CodexWireGuardianWarningNotification) {
        self = .guardianWarning(
            .init(
                message: wireValue.message,
                threadID: wireValue.threadID
            )
        )
    }

    init(wireValue: CodexWireModelReroutedNotification) {
        self = .modelRerouted(
            .init(
                fromModel: wireValue.fromModel,
                reason: .init(wireValue: wireValue.reason),
                threadID: wireValue.threadID,
                toModel: wireValue.toModel,
                turnID: wireValue.turnID
            )
        )
    }

    init(wireValue: CodexWireModelVerificationNotification) {
        self = .modelVerification(
            .init(
                threadID: wireValue.threadID,
                turnID: wireValue.turnID,
                verifications: wireValue.verifications.map(CodexModelVerification.init)
            )
        )
    }

    init(wireValue: CodexWireConfigWarningNotification) {
        self = .configWarning(
            .init(
                details: wireValue.details,
                path: wireValue.path,
                range: wireValue.range.map(CodexTextRange.init(wireValue:)),
                summary: wireValue.summary
            )
        )
    }

    init(wireValue: CodexWireDeprecationNoticeNotification) {
        self = .deprecationNotice(
            .init(details: wireValue.details, summary: wireValue.summary)
        )
    }

    init(wireValue: CodexWireMCPServerStatusUpdatedNotification) {
        self = .mcpServerStatusChanged(
            .init(
                error: wireValue.error,
                name: wireValue.name,
                status: .init(wireValue: wireValue.status)
            )
        )
    }

    init(wireValue: CodexWireRemoteControlStatusChangedNotification) {
        self = .remoteControlStatusChanged(
            .init(
                environmentID: wireValue.environmentID,
                installationID: wireValue.installationID,
                serverName: wireValue.serverName,
                status: .init(wireValue: wireValue.status)
            )
        )
    }
}

extension CodexTextRange {
    init(wireValue: CodexWireTextRange) {
        self.init(
            start: .init(wireValue: wireValue.start),
            end: .init(wireValue: wireValue.end)
        )
    }
}

extension CodexTextPosition {
    init(wireValue: CodexWireTextPosition) {
        self.init(line: wireValue.line, column: wireValue.column)
    }
}

extension CodexMcpServerStatusDiagnostic.Status {
    init(wireValue: CodexWireMCPServerStartupState) {
        switch wireValue {
        case .cancelled:
            self = .cancelled
        case .failed:
            self = .failed
        case .ready:
            self = .ready
        case .starting:
            self = .starting
        }
    }
}

extension CodexRemoteControlStatusDiagnostic.Status {
    init(wireValue: CodexWireRemoteControlConnectionStatus) {
        switch wireValue {
        case .connected:
            self = .connected
        case .connecting:
            self = .connecting
        case .disabled:
            self = .disabled
        case .errored:
            self = .errored
        }
    }
}

extension CodexModelReroute.Reason {
    init(wireValue: CodexWireModelRerouteReason) {
        switch wireValue {
        case .highRiskCyberActivity:
            self = .highRiskCyberActivity
        }
    }
}

extension CodexModelVerification {
    init(wireValue: CodexWireModelVerification) {
        switch wireValue {
        case .trustedAccessForCyber:
            self = .trustedAccessForCyber
        }
    }
}
