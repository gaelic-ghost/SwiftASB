import Foundation

extension CodexAppServer {
    public enum JSONValue: Sendable, Equatable {
        case null
        case bool(Bool)
        case integer(Int)
        case double(Double)
        case string(String)
        case array([JSONValue])
        case object([String: JSONValue])
    }

    public enum ApprovalPolicy: Sendable, Equatable {
        case never
        case onFailure
        case onRequest
        case untrusted
        case granular(GranularApprovalPolicy)
    }

    public struct GranularApprovalPolicy: Sendable, Equatable {
        public var mcpElicitations: Bool
        public var requestPermissions: Bool?
        public var rules: Bool
        public var sandboxApproval: Bool
        public var skillApproval: Bool?

        public init(
            mcpElicitations: Bool,
            requestPermissions: Bool? = nil,
            rules: Bool,
            sandboxApproval: Bool,
            skillApproval: Bool? = nil
        ) {
            self.mcpElicitations = mcpElicitations
            self.requestPermissions = requestPermissions
            self.rules = rules
            self.sandboxApproval = sandboxApproval
            self.skillApproval = skillApproval
        }
    }

    public enum ApprovalsReviewer: String, Sendable, Equatable {
        case autoReview, guardianSubagent, user
    }

    public enum Personality: String, Sendable, Equatable {
        case friendly, none, pragmatic
    }

    public enum SandboxMode: String, Sendable, Equatable {
        case dangerFullAccess, readOnly, workspaceWrite
    }

    public enum ServiceTier: String, Sendable, Equatable {
        case fast, flex
    }

    public enum SessionStartSource: String, Sendable, Equatable {
        case clear, startup
    }

    public enum ReasoningEffort: String, Sendable, Equatable {
        case high
        case low
        case medium
        case minimal
        case none
        case xhigh
    }

    public struct SandboxPolicy: Sendable, Equatable {
        public let type: SandboxPolicyType
        public let networkAccess: NetworkAccess?
        public let excludeSlashTmp: Bool?
        public let excludeTmpdirEnvVar: Bool?
        public let writableRoots: [String]
    }

    public enum NetworkAccess: Sendable, Equatable {
        case explicit(Bool), enabled, restricted
    }

    public enum SandboxPolicyType: String, Sendable, Equatable {
        case dangerFullAccess, externalSandbox, readOnly, workspaceWrite
    }

    public enum ReasoningSummary: String, Sendable, Equatable {
        case auto, concise, detailed, none
    }

    public enum ThreadStatusType: String, Sendable, Equatable {
        case active, idle, notLoaded, systemError
    }

    public enum ThreadActiveFlag: String, Sendable, Equatable {
        case waitingOnApproval, waitingOnUserInput
    }

    public enum TurnStatus: String, Sendable, Equatable {
        case completed, failed, inProgress, interrupted
    }

}
