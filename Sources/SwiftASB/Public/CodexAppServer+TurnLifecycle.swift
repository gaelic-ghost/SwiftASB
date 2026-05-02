import Foundation

extension CodexAppServer {
    /// Request used to start a turn in an existing thread.
    public struct TurnStartRequest: Sendable, Equatable {
        public var approvalPolicy: ApprovalPolicy?
        public var approvalsReviewer: ApprovalsReviewer?
        public var currentDirectoryPath: String?
        public var effort: ReasoningEffort?
        public var input: [TurnInput]
        public var model: String?
        public var outputSchema: JSONValue?
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
            currentDirectoryPath: String? = nil,
            effort: ReasoningEffort? = nil,
            model: String? = nil,
            outputSchema: JSONValue? = nil,
            personality: Personality? = nil,
            serviceTier: ServiceTier? = nil,
            summary: ReasoningSummary? = nil
        ) {
            self.threadID = threadID
            self.input = input
            self.approvalPolicy = approvalPolicy
            self.approvalsReviewer = approvalsReviewer
            self.currentDirectoryPath = currentDirectoryPath
            self.effort = effort
            self.model = model
            self.outputSchema = outputSchema
            self.personality = personality
            self.serviceTier = serviceTier
            self.summary = summary
        }
    }

    public struct TurnSession: Sendable, Equatable {
        public let turn: TurnInfo
    }

    public struct TurnInfo: Sendable, Equatable {
        public let completedAt: Int?
        public let durationMS: Int?
        public let errorMessage: String?
        public let id: String
        public let startedAt: Int?
        public let status: TurnStatus
    }

    /// One input item for a turn-start request.
    public struct TurnInput: Sendable, Equatable {
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
