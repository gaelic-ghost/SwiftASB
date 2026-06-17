import Foundation

public extension CodexAppServer {
    /// Open JSON payload used only for genuinely dynamic app-server fields.
    enum JSONValue: Sendable, Equatable {
        case null
        case bool(Bool)
        case integer(Int)
        case double(Double)
        case string(String)
        case array([JSONValue])
        case object([String: JSONValue])
    }

    /// Codex approval policy option for thread and turn requests.
    enum ApprovalPolicy: Sendable, Equatable {
        case never
        case onFailure
        case onRequest
        case untrusted
        case granular(GranularApprovalPolicy)
    }

    /// Fine-grained approval settings used with `.granular`.
    struct GranularApprovalPolicy: Sendable, Equatable {
        public var mcpElicitations: Bool
        public var requestPermissions: Bool?
        public var rules: Bool
        public var sandboxApproval: Bool
        public var skillApproval: Bool?

        /// Creates a granular approval policy.
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

    /// Actor or reviewer that should evaluate approval requests.
    enum ApprovalsReviewer: String, Sendable, Equatable {
        case autoReview, guardianSubagent, user
    }

    /// Personality option passed to Codex for thread or turn behavior.
    enum Personality: String, Sendable, Equatable {
        case friendly, none, pragmatic
    }

    /// Sandbox mode option passed to Codex when starting or resuming work.
    enum SandboxMode: String, Sendable, Equatable {
        case dangerFullAccess, readOnly, workspaceWrite
    }

    /// Service tier option passed to Codex requests.
    enum ServiceTier: String, Sendable, Equatable {
        case fast, flex
    }

    /// Source marker for a started session.
    enum SessionStartSource: String, Sendable, Equatable {
        case clear, startup
    }

    /// Reasoning effort option passed to Codex requests.
    enum ReasoningEffort: Sendable, Equatable {
        case high
        case low
        case medium
        case minimal
        case none
        case unrecognized(String)
        case xhigh
    }

    /// Effective sandbox policy reported by the app-server.
    struct SandboxPolicy: Sendable, Equatable {
        public let type: SandboxPolicyType
        public let networkAccess: NetworkAccess?
        public let excludeSlashTmp: Bool?
        public let excludeTmpdirEnvVar: Bool?
        public let writableRoots: [String]
    }

    /// Effective network access state reported by the app-server.
    enum NetworkAccess: Sendable, Equatable {
        case explicit(Bool), enabled, restricted
    }

    /// Effective sandbox policy family reported by the app-server.
    enum SandboxPolicyType: String, Sendable, Equatable {
        case dangerFullAccess, externalSandbox, readOnly, workspaceWrite
    }

    /// Reasoning summary option passed to Codex requests.
    enum ReasoningSummary: String, Sendable, Equatable {
        case auto, concise, detailed, none
    }

    /// Thread status family reported by the app-server.
    enum ThreadStatusType: String, Sendable, Equatable {
        case active, idle, notLoaded, systemError
    }

    /// Active work flags reported for a thread.
    enum ThreadActiveFlag: String, Sendable, Equatable {
        case waitingOnApproval, waitingOnUserInput
    }

    /// Turn status reported by the app-server.
    enum TurnStatus: String, Sendable, Equatable {
        case completed, failed, inProgress, interrupted
    }
}
