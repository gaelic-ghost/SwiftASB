public enum CodexDiagnosticEvent: Sendable, Equatable {
    case warning(CodexRuntimeWarning)
    case guardianWarning(CodexGuardianWarning)
    case modelRerouted(CodexModelReroute)
    case modelVerification(CodexModelVerificationDiagnostic)

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
        }
    }
}

public struct CodexRuntimeWarning: Sendable, Equatable {
    public let message: String
    public let threadID: String?

    public init(message: String, threadID: String?) {
        self.message = message
        self.threadID = threadID
    }
}

public struct CodexGuardianWarning: Sendable, Equatable {
    public let message: String
    public let threadID: String

    public init(message: String, threadID: String) {
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

    public init(
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

    public init(
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
