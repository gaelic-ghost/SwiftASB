import Foundation

extension CodexAppServer {
    /// Request used to create a new Codex thread.
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
        public var permissions: CodexWorkspace.PermissionSelection?
        public var personality: Personality?
        public var sandboxMode: SandboxMode?
        public var serviceName: String?
        public var serviceTier: ServiceTier?
        public var sessionStartSource: SessionStartSource?

        /// Creates a thread-start request.
        ///
        /// Nil option fields are omitted from the app-server request, which
        /// lets Codex apply its current runtime or configuration defaults. Set
        /// `ephemeral` only when the caller needs to override the app-server's
        /// storage choice for the new thread.
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
            permissions: CodexWorkspace.PermissionSelection? = nil,
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
            self.permissions = permissions
            self.personality = personality
            self.sandboxMode = sandboxMode
            self.serviceName = serviceName
            self.serviceTier = serviceTier
            self.sessionStartSource = sessionStartSource
        }
    }

    /// Request used to reopen an existing Codex thread.
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
        public var permissions: CodexWorkspace.PermissionSelection?
        public var personality: Personality?
        public var sandboxMode: SandboxMode?
        public var serviceName: String?
        public var serviceTier: ServiceTier?
        public var threadID: String

        /// Creates a thread-resume request.
        ///
        /// Nil option fields are omitted from the app-server request so the
        /// resumed thread keeps Codex-owned defaults. Set `excludeTurns` when
        /// the caller wants Codex to resume the thread without embedding prior
        /// turns in the response payload.
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
            permissions: CodexWorkspace.PermissionSelection? = nil,
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
            self.permissions = permissions
            self.personality = personality
            self.sandboxMode = sandboxMode
            self.serviceName = serviceName
            self.serviceTier = serviceTier
        }
    }

    /// Request used to fork an existing Codex thread into a new thread.
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
        public var permissions: CodexWorkspace.PermissionSelection?
        public var personality: Personality?
        public var sandboxMode: SandboxMode?
        public var serviceName: String?
        public var serviceTier: ServiceTier?
        public var threadID: String

        /// Creates a thread-fork request.
        ///
        /// Nil option fields are omitted from the app-server request so the
        /// fork inherits Codex-owned defaults. Set `excludeTurns` when the
        /// caller plans to page history separately, and set `ephemeral` only to
        /// override the app-server's storage choice for the fork.
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
            permissions: CodexWorkspace.PermissionSelection? = nil,
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
            self.permissions = permissions
            self.personality = personality
            self.sandboxMode = sandboxMode
            self.serviceName = serviceName
            self.serviceTier = serviceTier
        }
    }

    /// App-server response and runtime defaults for a started, resumed, or forked thread.
    public struct ThreadSession: Sendable, Equatable {
        public let activePermissionProfile: CodexWorkspace.ActivePermissionProfile?
        public let approvalPolicy: ApprovalPolicy
        public let approvalsReviewer: ApprovalsReviewer
        public let currentDirectoryPath: String
        public let instructionSources: [String]
        public let model: String
        public let modelProvider: String
        public let permissionProfile: CodexWorkspace.PermissionProfile?
        public let reasoningEffort: ReasoningEffort?
        public let sandboxPolicy: SandboxPolicy
        public let serviceTier: ServiceTier?
        public let thread: ThreadInfo

        /// Workspace, Git, sandbox, and permission facts for this session.
        public var workspace: CodexWorkspace.SessionSnapshot {
            .init(session: self)
        }
    }

    /// Metadata for a stored or active Codex thread.
    public struct ThreadInfo: Sendable, Equatable {
        public let id: String
        public let cliVersion: String
        public let createdAt: Int
        public let currentDirectoryPath: String
        public let ephemeral: Bool
        public let forkedFromThreadID: String?
        public let modelProvider: String
        public let name: String?
        public let preview: String
        public let projectInfo: CodexWorkspace.ProjectInfo
        public let source: ThreadSource
        public let status: ThreadStatus
        public let updatedAt: Int

        /// Codex-reported cwd plus optional Git facts for this thread.
        public var worktree: CodexWorkspace.WorktreeSnapshot {
            projectInfo.worktree
        }
    }

    /// Request used to read a stored thread snapshot.
    public struct ThreadReadRequest: Sendable, Equatable {
        public var includeTurns: Bool
        public var threadID: String

        /// Creates a thread-read request.
        ///
        /// `includeTurns` defaults to `false` so a basic read returns thread
        /// metadata without asking Codex for the heavier turn list payload.
        public init(
            threadID: String,
            includeTurns: Bool = false
        ) {
            self.threadID = threadID
            self.includeTurns = includeTurns
        }
    }

    /// Stored thread metadata plus the optional turns returned by a read request.
    public struct ThreadReadResult: Sendable, Equatable {
        public let thread: ThreadInfo
        public let turns: [TurnInfo]
    }

    /// Request used to start app-server context compaction for a thread.
    public struct ThreadCompactRequest: Sendable, Equatable {
        public var threadID: String

        /// Creates a thread-compaction request.
        public init(threadID: String) {
            self.threadID = threadID
        }
    }

    /// Sort key for stored-thread listing.
    public enum ThreadListSortKey: String, Sendable, Equatable {
        case createdAt
        case updatedAt
    }

    /// Sort direction for stored-thread listing.
    public enum ThreadListSortDirection: String, Sendable, Equatable {
        case asc
        case desc
    }

    /// Source family filter for stored-thread listing.
    public enum ThreadListSourceKind: String, Sendable, Equatable {
        case appServer
        case cli
        case exec
        case unknown
        case vscode
    }

    /// App-server-reported source for a stored or active thread.
    public enum ThreadSource: Sendable, Equatable, Codable {
        /// Thread started by the Codex app-server owner.
        case appServer
        /// Thread started by the Codex CLI.
        case cli
        /// Thread started by a direct exec integration.
        case exec
        /// Thread started by a VS Code integration.
        case vscode
        /// Thread started by a named integration outside the built-in cases.
        case custom(String)
        /// Thread created by a Codex sub-agent.
        case subAgent(SubAgentSource)
        /// Source omitted or unknown to the app-server.
        case unknown

        /// App-server-reported source for an agent-created child thread.
        public struct SubAgentSource: Sendable, Equatable, Codable {
            /// Sub-agent source family reported by Codex.
            public enum Kind: String, Sendable, Equatable, Codable {
                case compact
                case memoryConsolidation
                case review
                case threadSpawn
                case other
                case unknown
            }

            /// Coarse source family for the sub-agent thread.
            public let kind: Kind
            /// Raw source label when Codex reports a sub-agent source outside the known families.
            public let other: String?
            /// Thread-spawn details when `kind` is ``Kind/threadSpawn``.
            public let threadSpawn: ThreadSpawn?

            /// Creates a sub-agent source value.
            public init(
                kind: Kind,
                other: String? = nil,
                threadSpawn: ThreadSpawn? = nil
            ) {
                self.kind = kind
                self.other = other
                self.threadSpawn = threadSpawn
            }
        }

        /// Metadata for a sub-agent thread-spawn source.
        public struct ThreadSpawn: Sendable, Equatable, Codable {
            /// Human-facing nickname Codex assigned to the spawned agent, when available.
            public let agentNickname: String?
            /// Agent path reported by Codex, when available.
            public let agentPath: String?
            /// Role assigned to the spawned agent, when available.
            public let agentRole: String?
            /// Spawn depth relative to the parent thread.
            public let depth: Int
            /// Parent thread identifier that spawned this agent thread.
            public let parentThreadID: String

            /// Creates a thread-spawn source value.
            public init(
                agentNickname: String? = nil,
                agentPath: String? = nil,
                agentRole: String? = nil,
                depth: Int,
                parentThreadID: String
            ) {
                self.agentNickname = agentNickname
                self.agentPath = agentPath
                self.agentRole = agentRole
                self.depth = depth
                self.parentThreadID = parentThreadID
            }
        }
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

        /// Creates a thread-list request.
        ///
        /// Nil filters and pagination fields are omitted, which lets the
        /// app-server choose its default page, sort, and visibility behavior.
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

    /// One page of stored-thread list results.
    public struct ThreadListPage: Sendable, Equatable {
        public let nextCursor: String?
        public let threads: [ThreadInfo]
    }

    /// Sort direction for stored turn-history paging.
    public enum ThreadTurnsSortDirection: String, Sendable, Equatable {
        case asc
        case desc
    }

    /// Amount of item detail to include when listing stored turns.
    public enum TurnItemsView: String, Sendable, Equatable {
        case full
        case notLoaded
        case summary
    }

    public struct ThreadTurnsListRequest: Sendable, Equatable {
        public var cursor: String?
        public var itemsView: TurnItemsView?
        public var limit: Int?
        public var sortDirection: ThreadTurnsSortDirection?
        public var threadID: String

        /// Creates a paged turn-list request for a stored thread.
        ///
        /// Nil pagination, item-view, and sort fields are omitted, which keeps
        /// the app-server in charge of its default page size, item detail, and
        /// ordering.
        public init(
            threadID: String,
            limit: Int? = nil,
            cursor: String? = nil,
            itemsView: TurnItemsView? = nil,
            sortDirection: ThreadTurnsSortDirection? = nil
        ) {
            self.threadID = threadID
            self.limit = limit
            self.cursor = cursor
            self.itemsView = itemsView
            self.sortDirection = sortDirection
        }
    }

    /// One page of stored turn-history results.
    public struct ThreadTurnsPage: Sendable, Equatable {
        public let backwardsCursor: String?
        public let nextCursor: String?
        public let turns: [TurnInfo]
    }

    public struct ThreadTurnsItemsListRequest: Sendable, Equatable {
        public var cursor: String?
        public var limit: Int?
        public var sortDirection: ThreadTurnsSortDirection?
        public var threadID: String
        public var turnID: String

        /// Creates a paged item-list request for one stored turn.
        ///
        /// Nil pagination and sort fields are omitted, which keeps the
        /// app-server in charge of its default page size and ordering.
        public init(
            threadID: String,
            turnID: String,
            limit: Int? = nil,
            cursor: String? = nil,
            sortDirection: ThreadTurnsSortDirection? = nil
        ) {
            self.threadID = threadID
            self.turnID = turnID
            self.limit = limit
            self.cursor = cursor
            self.sortDirection = sortDirection
        }
    }

    /// One page of stored item-history results for a turn.
    public struct ThreadTurnsItemsPage: Sendable, Equatable {
        public let backwardsCursor: String?
        public let items: [CodexTurnItem]
        public let nextCursor: String?
    }

    /// Current app-server status for a thread.
    public struct ThreadStatus: Sendable, Equatable {
        public let type: ThreadStatusType
        public let activeFlags: [ThreadActiveFlag]
    }

}
