import Foundation

public extension CodexAppServer {
    /// Request used to start a turn in an existing thread.
    struct TurnStartRequest: Sendable, Equatable {
        public var approvalPolicy: ApprovalPolicy?
        public var approvalsReviewer: ApprovalsReviewer?
        public var collaborationMode: TurnCollaborationMode?
        public var currentDirectoryPath: String?
        public var effort: ReasoningEffort?
        public var input: [TurnInput]
        public var model: String?
        public var outputSchema: JSONValue?
        public var permissions: CodexWorkspace.PermissionSelection?
        public var personality: Personality?
        public var serviceTier: ServiceTier?
        public var summary: ReasoningSummary?
        public var threadID: String

        /// Creates a turn-start request.
        ///
        /// Nil option fields are omitted from the app-server request so the
        /// turn inherits the thread or Codex runtime defaults. Provide values
        /// only for the turn-specific settings the caller wants to override.
        public init(
            threadID: String,
            input: [TurnInput],
            approvalPolicy: ApprovalPolicy? = nil,
            approvalsReviewer: ApprovalsReviewer? = nil,
            collaborationMode: TurnCollaborationMode? = nil,
            currentDirectoryPath: String? = nil,
            effort: ReasoningEffort? = nil,
            model: String? = nil,
            outputSchema: JSONValue? = nil,
            permissions: CodexWorkspace.PermissionSelection? = nil,
            personality: Personality? = nil,
            serviceTier: ServiceTier? = nil,
            summary: ReasoningSummary? = nil
        ) {
            self.threadID = threadID
            self.input = input
            self.approvalPolicy = approvalPolicy
            self.approvalsReviewer = approvalsReviewer
            self.collaborationMode = collaborationMode
            self.currentDirectoryPath = currentDirectoryPath
            self.effort = effort
            self.model = model
            self.outputSchema = outputSchema
            self.permissions = permissions
            self.personality = personality
            self.serviceTier = serviceTier
            self.summary = summary
        }
    }

    /// Collaboration preset used for one turn.
    ///
    /// The app-server currently treats collaboration presets as experimental,
    /// but plan mode is useful enough for SwiftASB to expose behind a small
    /// Swift-owned value instead of asking callers to emulate slash commands.
    struct TurnCollaborationMode: Sendable, Equatable {
        public enum Kind: String, Sendable, Equatable {
            case defaultMode = "default"
            case plan
        }

        public var developerInstructions: String?
        public var kind: Kind
        public var model: String
        public var reasoningEffort: ReasoningEffort?

        /// Creates a collaboration preset for a turn.
        ///
        /// `model` is required because the app-server collaboration-mode
        /// settings require it. Thread helpers default this to the thread's
        /// current model when a caller asks for plan mode.
        public init(
            kind: Kind,
            model: String,
            reasoningEffort: ReasoningEffort? = nil,
            developerInstructions: String? = nil
        ) {
            self.kind = kind
            self.model = model
            self.reasoningEffort = reasoningEffort
            self.developerInstructions = developerInstructions
        }

        /// Starts the turn in Codex plan mode.
        public static func plan(
            model: String,
            reasoningEffort: ReasoningEffort? = nil,
            developerInstructions: String? = nil
        ) -> Self {
            .init(
                kind: .plan,
                model: model,
                reasoningEffort: reasoningEffort,
                developerInstructions: developerInstructions
            )
        }
    }

    /// App-server response for a newly started turn.
    struct TurnSession: Sendable, Equatable {
        public let turn: TurnInfo
    }

    /// Metadata for a turn known to the app-server.
    struct TurnInfo: Sendable, Equatable {
        public let completedAt: Int?
        public let durationMS: Int?
        public let errorMessage: String?
        public let id: String
        public let startedAt: Int?
        public let status: TurnStatus
    }

    /// One input item for a turn-start request.
    struct TurnInput: Sendable, Equatable {
        public enum Kind: String, Sendable, Equatable {
            case image, localImage, mention, skill, text
        }

        public var kind: Kind
        public var text: String?
        public var url: String?
        public var path: String?
        public var name: String?

        /// Creates a turn input item.
        ///
        /// Nil payload fields are omitted. The caller is responsible for
        /// supplying the field that matches `kind`, such as `text` for text
        /// input or `path` for local image input.
        public init(
            kind: Kind,
            text: String? = nil,
            url: String? = nil,
            path: String? = nil,
            name: String? = nil
        ) {
            self.kind = kind
            self.text = text
            self.url = url
            self.path = path
            self.name = name
        }

        /// Creates a plain text turn input item.
        public static func text(_ text: String) -> Self {
            .init(kind: .text, text: text)
        }
    }
}
