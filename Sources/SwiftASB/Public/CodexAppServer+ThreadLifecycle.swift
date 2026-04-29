import Foundation

extension CodexAppServer {
    public struct ThreadStartRequest: Sendable, Equatable {
        public var approvalPolicy: ApprovalPolicy?
        public var approvalsReviewer: ApprovalsReviewer?
        public var baseInstructions: String?
        public var config: [String: JSONValue]?
        public var currentDirectoryPath: String?
        public var developerInstructions: String?
        public var ephemeral: Bool?
        public var model: String?
        public var modelProvider: String?
        public var personality: Personality?
        public var sandboxMode: SandboxMode?
        public var serviceName: String?
        public var serviceTier: ServiceTier?
        public var sessionStartSource: SessionStartSource?

        public init(
            approvalPolicy: ApprovalPolicy? = nil,
            approvalsReviewer: ApprovalsReviewer? = nil,
            baseInstructions: String? = nil,
            config: [String: JSONValue]? = nil,
            currentDirectoryPath: String? = nil,
            developerInstructions: String? = nil,
            ephemeral: Bool? = nil,
            model: String? = nil,
            modelProvider: String? = nil,
            personality: Personality? = nil,
            sandboxMode: SandboxMode? = nil,
            serviceName: String? = nil,
            serviceTier: ServiceTier? = nil,
            sessionStartSource: SessionStartSource? = nil
        ) {
            self.approvalPolicy = approvalPolicy
            self.approvalsReviewer = approvalsReviewer
            self.baseInstructions = baseInstructions
            self.config = config
            self.currentDirectoryPath = currentDirectoryPath
            self.developerInstructions = developerInstructions
            self.ephemeral = ephemeral
            self.model = model
            self.modelProvider = modelProvider
            self.personality = personality
            self.sandboxMode = sandboxMode
            self.serviceName = serviceName
            self.serviceTier = serviceTier
            self.sessionStartSource = sessionStartSource
        }
    }

    public struct ThreadResumeRequest: Sendable, Equatable {
        public var approvalPolicy: ApprovalPolicy?
        public var approvalsReviewer: ApprovalsReviewer?
        public var baseInstructions: String?
        public var config: [String: JSONValue]?
        public var currentDirectoryPath: String?
        public var developerInstructions: String?
        public var excludeTurns: Bool?
        public var model: String?
        public var modelProvider: String?
        public var personality: Personality?
        public var sandboxMode: SandboxMode?
        public var serviceName: String?
        public var serviceTier: ServiceTier?
        public var threadID: String

        public init(
            threadID: String,
            approvalPolicy: ApprovalPolicy? = nil,
            approvalsReviewer: ApprovalsReviewer? = nil,
            baseInstructions: String? = nil,
            config: [String: JSONValue]? = nil,
            currentDirectoryPath: String? = nil,
            developerInstructions: String? = nil,
            excludeTurns: Bool? = nil,
            model: String? = nil,
            modelProvider: String? = nil,
            personality: Personality? = nil,
            sandboxMode: SandboxMode? = nil,
            serviceName: String? = nil,
            serviceTier: ServiceTier? = nil
        ) {
            self.threadID = threadID
            self.approvalPolicy = approvalPolicy
            self.approvalsReviewer = approvalsReviewer
            self.baseInstructions = baseInstructions
            self.config = config
            self.currentDirectoryPath = currentDirectoryPath
            self.developerInstructions = developerInstructions
            self.excludeTurns = excludeTurns
            self.model = model
            self.modelProvider = modelProvider
            self.personality = personality
            self.sandboxMode = sandboxMode
            self.serviceName = serviceName
            self.serviceTier = serviceTier
        }
    }

    public struct ThreadForkRequest: Sendable, Equatable {
        public var approvalPolicy: ApprovalPolicy?
        public var approvalsReviewer: ApprovalsReviewer?
        public var baseInstructions: String?
        public var config: [String: JSONValue]?
        public var currentDirectoryPath: String?
        public var developerInstructions: String?
        public var ephemeral: Bool?
        public var excludeTurns: Bool?
        public var model: String?
        public var modelProvider: String?
        public var personality: Personality?
        public var sandboxMode: SandboxMode?
        public var serviceName: String?
        public var serviceTier: ServiceTier?
        public var threadID: String

        public init(
            threadID: String,
            approvalPolicy: ApprovalPolicy? = nil,
            approvalsReviewer: ApprovalsReviewer? = nil,
            baseInstructions: String? = nil,
            config: [String: JSONValue]? = nil,
            currentDirectoryPath: String? = nil,
            developerInstructions: String? = nil,
            ephemeral: Bool? = nil,
            excludeTurns: Bool? = nil,
            model: String? = nil,
            modelProvider: String? = nil,
            personality: Personality? = nil,
            sandboxMode: SandboxMode? = nil,
            serviceName: String? = nil,
            serviceTier: ServiceTier? = nil
        ) {
            self.threadID = threadID
            self.approvalPolicy = approvalPolicy
            self.approvalsReviewer = approvalsReviewer
            self.baseInstructions = baseInstructions
            self.config = config
            self.currentDirectoryPath = currentDirectoryPath
            self.developerInstructions = developerInstructions
            self.ephemeral = ephemeral
            self.excludeTurns = excludeTurns
            self.model = model
            self.modelProvider = modelProvider
            self.personality = personality
            self.sandboxMode = sandboxMode
            self.serviceName = serviceName
            self.serviceTier = serviceTier
        }
    }

    public struct ThreadSession: Sendable, Equatable {
        public let approvalPolicy: ApprovalPolicy
        public let approvalsReviewer: ApprovalsReviewer
        public let currentDirectoryPath: String
        public let instructionSources: [String]
        public let model: String
        public let modelProvider: String
        public let reasoningEffort: ReasoningEffort?
        public let sandboxPolicy: SandboxPolicy
        public let serviceTier: ServiceTier?
        public let thread: ThreadInfo
    }

    public struct ThreadInfo: Sendable, Equatable {
        public let id: String
        public let cliVersion: String
        public let createdAt: Int
        public let currentDirectoryPath: String
        public let ephemeral: Bool
        public let forkedFromThreadID: String?
        public let gitInfo: GitInfo?
        public let modelProvider: String
        public let name: String?
        public let preview: String
        public let status: ThreadStatus
        public let updatedAt: Int
    }

    public struct ThreadReadRequest: Sendable, Equatable {
        public var includeTurns: Bool
        public var threadID: String

        public init(
            threadID: String,
            includeTurns: Bool = false
        ) {
            self.threadID = threadID
            self.includeTurns = includeTurns
        }
    }

    public struct ThreadReadResult: Sendable, Equatable {
        public let thread: ThreadInfo
        public let turns: [TurnInfo]
    }

    public struct ThreadCompactRequest: Sendable, Equatable {
        public var threadID: String

        public init(threadID: String) {
            self.threadID = threadID
        }
    }

    public enum ThreadListSortKey: String, Sendable, Equatable {
        case createdAt
        case updatedAt
    }

    public enum ThreadListSortDirection: String, Sendable, Equatable {
        case asc
        case desc
    }

    public enum ThreadListSourceKind: String, Sendable, Equatable {
        case appServer
        case cli
        case exec
        case unknown
        case vscode
    }

    public struct ThreadListRequest: Sendable, Equatable {
        public var archived: Bool?
        public var cursor: String?
        public var currentDirectoryPath: String?
        public var limit: Int?
        public var modelProviders: [String]?
        public var searchTerm: String?
        public var sortDirection: ThreadListSortDirection?
        public var sortKey: ThreadListSortKey?
        public var sourceKinds: [ThreadListSourceKind]?

        public init(
            cursor: String? = nil,
            limit: Int? = nil,
            sortKey: ThreadListSortKey? = nil,
            sortDirection: ThreadListSortDirection? = nil,
            modelProviders: [String]? = nil,
            sourceKinds: [ThreadListSourceKind]? = nil,
            archived: Bool? = nil,
            currentDirectoryPath: String? = nil,
            searchTerm: String? = nil
        ) {
            self.archived = archived
            self.cursor = cursor
            self.currentDirectoryPath = currentDirectoryPath
            self.limit = limit
            self.modelProviders = modelProviders
            self.searchTerm = searchTerm
            self.sortDirection = sortDirection
            self.sortKey = sortKey
            self.sourceKinds = sourceKinds
        }
    }

    public struct ThreadListPage: Sendable, Equatable {
        public let nextCursor: String?
        public let threads: [ThreadInfo]
    }

    public enum ThreadTurnsSortDirection: String, Sendable, Equatable {
        case asc
        case desc
    }

    public struct ThreadTurnsListRequest: Sendable, Equatable {
        public var cursor: String?
        public var limit: Int?
        public var sortDirection: ThreadTurnsSortDirection?
        public var threadID: String

        public init(
            threadID: String,
            limit: Int? = nil,
            cursor: String? = nil,
            sortDirection: ThreadTurnsSortDirection? = nil
        ) {
            self.threadID = threadID
            self.limit = limit
            self.cursor = cursor
            self.sortDirection = sortDirection
        }
    }

    public struct ThreadTurnsPage: Sendable, Equatable {
        public let backwardsCursor: String?
        public let nextCursor: String?
        public let turns: [TurnInfo]
    }

    public struct ThreadStatus: Sendable, Equatable {
        public let type: ThreadStatusType
        public let activeFlags: [ThreadActiveFlag]
    }

}
