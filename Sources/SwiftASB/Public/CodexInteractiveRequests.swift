import Foundation

/// Interactive request family emitted by Codex while a turn is waiting on caller input.
public enum CodexInteractiveRequestKind: String, Sendable, Equatable {
    case commandExecutionApproval
    case fileChangeApproval
    case guardianDeniedActionApproval
    case permissionsApproval
    case toolUserInput
    case mcpServerElicitation
}

/// Confirmation that an interactive request was answered and resolved by the app-server.
public struct CodexInteractiveRequestResolved: Sendable, Equatable {
    public let threadID: String
    public let turnID: String?
    public let kind: CodexInteractiveRequestKind

    internal let requestID: CodexRPCRequestID

    internal init(
        requestID: CodexRPCRequestID,
        threadID: String,
        turnID: String?,
        kind: CodexInteractiveRequestKind
    ) {
        self.requestID = requestID
        self.threadID = threadID
        self.turnID = turnID
        self.kind = kind
    }
}

/// Approval request that must be answered before Codex can continue a turn.
public enum CodexApprovalRequest: Sendable, Equatable {
    case commandExecution(CodexCommandExecutionApprovalRequest)
    case fileChange(CodexFileChangeApprovalRequest)
    case guardianDeniedAction(CodexGuardianDeniedActionApprovalRequest)
    case permissions(CodexPermissionsApprovalRequest)

    public var threadID: String {
        switch self {
        case let .commandExecution(request):
            request.threadID
        case let .fileChange(request):
            request.threadID
        case let .guardianDeniedAction(request):
            request.threadID
        case let .permissions(request):
            request.threadID
        }
    }

    public var turnID: String {
        switch self {
        case let .commandExecution(request):
            request.turnID
        case let .fileChange(request):
            request.turnID
        case let .guardianDeniedAction(request):
            request.turnID
        case let .permissions(request):
            request.turnID
        }
    }

    public var kind: CodexInteractiveRequestKind {
        switch self {
        case .commandExecution:
            .commandExecutionApproval
        case .fileChange:
            .fileChangeApproval
        case .guardianDeniedAction:
            .guardianDeniedActionApproval
        case .permissions:
            .permissionsApproval
        }
    }

    internal var requestID: CodexRPCRequestID {
        switch self {
        case let .commandExecution(request):
            request.requestID
        case let .fileChange(request):
            request.requestID
        case let .guardianDeniedAction(request):
            request.requestID
        case let .permissions(request):
            request.requestID
        }
    }
}

/// Command-execution approval request emitted by Codex.
public struct CodexCommandExecutionApprovalRequest: Sendable, Equatable {
    public let threadID: String
    public let turnID: String
    public let itemID: String
    public let approvalID: String?
    public let command: String?
    public let commandActions: [CodexCommandAction]?
    public let currentDirectoryPath: String?
    public let reason: String?
    public let proposedExecPolicyAmendment: [String]?
    public let proposedNetworkPolicyAmendments: [CodexNetworkPolicyAmendment]?
    public let networkApprovalContext: CodexAppServer.JSONValue?

    internal let requestID: CodexRPCRequestID

    internal init(
        requestID: CodexRPCRequestID,
        threadID: String,
        turnID: String,
        itemID: String,
        approvalID: String?,
        command: String?,
        commandActions: [CodexCommandAction]?,
        currentDirectoryPath: String?,
        reason: String?,
        proposedExecPolicyAmendment: [String]?,
        proposedNetworkPolicyAmendments: [CodexNetworkPolicyAmendment]?,
        networkApprovalContext: CodexAppServer.JSONValue?
    ) {
        self.requestID = requestID
        self.threadID = threadID
        self.turnID = turnID
        self.itemID = itemID
        self.approvalID = approvalID
        self.command = command
        self.commandActions = commandActions
        self.currentDirectoryPath = currentDirectoryPath
        self.reason = reason
        self.proposedExecPolicyAmendment = proposedExecPolicyAmendment
        self.proposedNetworkPolicyAmendments = proposedNetworkPolicyAmendments
        self.networkApprovalContext = networkApprovalContext
    }
}

/// File-change approval request emitted by Codex.
public struct CodexFileChangeApprovalRequest: Sendable, Equatable {
    public let threadID: String
    public let turnID: String
    public let itemID: String
    public let grantRoot: String?
    public let reason: String?

    internal let requestID: CodexRPCRequestID

    internal init(
        requestID: CodexRPCRequestID,
        threadID: String,
        turnID: String,
        itemID: String,
        grantRoot: String?,
        reason: String?
    ) {
        self.requestID = requestID
        self.threadID = threadID
        self.turnID = turnID
        self.itemID = itemID
        self.grantRoot = grantRoot
        self.reason = reason
    }
}

/// Permissions approval request emitted by Codex.
public struct CodexPermissionsApprovalRequest: Sendable, Equatable {
    public let threadID: String
    public let turnID: String
    public let itemID: String
    public let permissions: CodexPermissionProfile
    public let reason: String?

    internal let requestID: CodexRPCRequestID

    internal init(
        requestID: CodexRPCRequestID,
        threadID: String,
        turnID: String,
        itemID: String,
        permissions: CodexPermissionProfile,
        reason: String?
    ) {
        self.requestID = requestID
        self.threadID = threadID
        self.turnID = turnID
        self.itemID = itemID
        self.permissions = permissions
        self.reason = reason
    }
}

/// Guardian auto-review denial that can be explicitly approved by the caller.
public struct CodexGuardianDeniedActionApprovalRequest: Sendable, Equatable {
    public let threadID: String
    public let turnID: String
    public let reviewID: String
    public let targetItemID: String?
    public let startedAtMS: Int?
    public let completedAtMS: Int?
    public let decisionSource: String
    public let action: CodexGuardianApprovalReviewAction
    public let review: CodexGuardianApprovalReview
    public let event: CodexAppServer.JSONValue

    internal let requestID: CodexRPCRequestID

    internal init(
        requestID: CodexRPCRequestID,
        threadID: String,
        turnID: String,
        reviewID: String,
        targetItemID: String?,
        startedAtMS: Int?,
        completedAtMS: Int?,
        decisionSource: String,
        action: CodexGuardianApprovalReviewAction,
        review: CodexGuardianApprovalReview,
        event: CodexAppServer.JSONValue
    ) {
        self.requestID = requestID
        self.threadID = threadID
        self.turnID = turnID
        self.reviewID = reviewID
        self.targetItemID = targetItemID
        self.startedAtMS = startedAtMS
        self.completedAtMS = completedAtMS
        self.decisionSource = decisionSource
        self.action = action
        self.review = review
        self.event = event
    }
}

/// Action reviewed by guardian auto-review.
public struct CodexGuardianApprovalReviewAction: Sendable, Equatable {
    public enum ActionType: String, Sendable, Equatable {
        case applyPatch, command, execve, mcpToolCall, networkAccess, requestPermissions
    }

    public enum CommandSource: String, Sendable, Equatable {
        case shell, unifiedExec
    }

    public enum NetworkProtocol: String, Sendable, Equatable {
        case http, https, socks5TCP, socks5UDP
    }

    public let type: ActionType
    public let command: String?
    public let currentDirectoryPath: String?
    public let source: CommandSource?
    public let argv: [String]?
    public let program: String?
    public let files: [String]?
    public let host: String?
    public let port: Int?
    public let networkProtocol: NetworkProtocol?
    public let target: String?
    public let connectorID: String?
    public let connectorName: String?
    public let server: String?
    public let toolName: String?
    public let toolTitle: String?
    public let permissions: CodexPermissionProfile?
    public let reason: String?

    internal init(
        type: ActionType,
        command: String?,
        currentDirectoryPath: String?,
        source: CommandSource?,
        argv: [String]?,
        program: String?,
        files: [String]?,
        host: String?,
        port: Int?,
        networkProtocol: NetworkProtocol?,
        target: String?,
        connectorID: String?,
        connectorName: String?,
        server: String?,
        toolName: String?,
        toolTitle: String?,
        permissions: CodexPermissionProfile?,
        reason: String?
    ) {
        self.type = type
        self.command = command
        self.currentDirectoryPath = currentDirectoryPath
        self.source = source
        self.argv = argv
        self.program = program
        self.files = files
        self.host = host
        self.port = port
        self.networkProtocol = networkProtocol
        self.target = target
        self.connectorID = connectorID
        self.connectorName = connectorName
        self.server = server
        self.toolName = toolName
        self.toolTitle = toolTitle
        self.permissions = permissions
        self.reason = reason
    }
}

/// Guardian auto-review result attached to a reviewed action.
public struct CodexGuardianApprovalReview: Sendable, Equatable {
    public enum RiskLevel: String, Sendable, Equatable {
        case critical, high, low, medium
    }

    public enum Status: String, Sendable, Equatable {
        case aborted, approved, denied, inProgress, timedOut
    }

    public enum UserAuthorization: String, Sendable, Equatable {
        case high, low, medium, unknown
    }

    public let rationale: String?
    public let riskLevel: RiskLevel?
    public let status: Status
    public let userAuthorization: UserAuthorization?

    internal init(
        rationale: String?,
        riskLevel: RiskLevel?,
        status: Status,
        userAuthorization: UserAuthorization?
    ) {
        self.rationale = rationale
        self.riskLevel = riskLevel
        self.status = status
        self.userAuthorization = userAuthorization
    }
}

/// Structured command action attached to a command-execution approval request.
public enum CodexCommandAction: Sendable, Equatable {
    case read(Read)
    case listFiles(ListFiles)
    case search(Search)
    case unknown(Unknown)

    public struct Read: Sendable, Equatable {
        public let command: String
        public let name: String
        public let path: String

        init(command: String, name: String, path: String) {
            self.command = command
            self.name = name
            self.path = path
        }
    }

    public struct ListFiles: Sendable, Equatable {
        public let command: String
        public let path: String?

        init(command: String, path: String?) {
            self.command = command
            self.path = path
        }
    }

    public struct Search: Sendable, Equatable {
        public let command: String
        public let path: String?
        public let query: String?

        init(command: String, path: String?, query: String?) {
            self.command = command
            self.path = path
            self.query = query
        }
    }

    public struct Unknown: Sendable, Equatable {
        public let command: String

        init(command: String) {
            self.command = command
        }
    }
}

/// Network-policy change proposed by Codex or returned by a caller.
public struct CodexNetworkPolicyAmendment: Sendable, Equatable {
    /// Network-policy action requested for one host.
    public enum Action: Sendable, Equatable {
        case allow
        case deny
        case unknown(String)

        public init(wireValue: String) {
            switch wireValue {
            case "allow":
                self = .allow
            case "deny":
                self = .deny
            default:
                self = .unknown(wireValue)
            }
        }

        public var wireValue: String {
            switch self {
            case .allow:
                "allow"
            case .deny:
                "deny"
            case let .unknown(value):
                value
            }
        }
    }

    public let action: Action
    public let host: String

    public init(action: Action, host: String) {
        self.action = action
        self.host = host
    }
}

/// Permission profile used when answering a permissions approval request.
public struct CodexPermissionProfile: Sendable, Equatable {
    /// Filesystem permission section of a Codex permission profile.
    public struct FileSystem: Sendable, Equatable {
        public let read: [String]?
        public let write: [String]?

        /// Creates a filesystem permission profile.
        ///
        /// Nil access lists are omitted from the response, leaving any existing
        /// Codex permission behavior unchanged for that access direction.
        public init(read: [String]? = nil, write: [String]? = nil) {
            self.read = read
            self.write = write
        }
    }

    /// Network permission section of a Codex permission profile.
    public struct Network: Sendable, Equatable {
        public let enabled: Bool?

        /// Creates a network permission profile.
        ///
        /// Omitting `enabled` sends no network permission change.
        public init(enabled: Bool? = nil) {
            self.enabled = enabled
        }
    }

    public let fileSystem: FileSystem?
    public let network: Network?

    /// Creates a permission profile response.
    ///
    /// Nil sections are omitted from the response.
    public init(
        fileSystem: FileSystem? = nil,
        network: Network? = nil
    ) {
        self.fileSystem = fileSystem
        self.network = network
    }
}

/// Elicitation request that asks the caller to provide user or MCP-server input.
public enum CodexElicitationRequest: Sendable, Equatable {
    case toolUserInput(CodexToolUserInputRequest)
    case mcpServer(CodexMcpServerElicitationRequest)

    public var threadID: String {
        switch self {
        case let .toolUserInput(request):
            request.threadID
        case let .mcpServer(request):
            request.threadID
        }
    }

    public var turnID: String? {
        switch self {
        case let .toolUserInput(request):
            request.turnID
        case let .mcpServer(request):
            request.turnID
        }
    }

    public var kind: CodexInteractiveRequestKind {
        switch self {
        case .toolUserInput:
            .toolUserInput
        case .mcpServer:
            .mcpServerElicitation
        }
    }

    internal var requestID: CodexRPCRequestID {
        switch self {
        case let .toolUserInput(request):
            request.requestID
        case let .mcpServer(request):
            request.requestID
        }
    }
}

/// Tool user-input request emitted by Codex.
public struct CodexToolUserInputRequest: Sendable, Equatable {
    /// One question in a tool user-input request.
    public struct Question: Sendable, Equatable {
        /// One selectable option in a tool user-input question.
        public struct Option: Sendable, Equatable {
            public let description: String
            public let label: String

            init(description: String, label: String) {
                self.description = description
                self.label = label
            }
        }

        public let header: String
        public let id: String
        public let isOther: Bool
        public let isSecret: Bool
        public let options: [Option]?
        public let question: String

        /// Creates a tool-user-input question.
        ///
        /// `isOther` and `isSecret` default to ordinary visible input, and
        /// omitting `options` leaves the question as free-form input.
        init(
            header: String,
            id: String,
            isOther: Bool = false,
            isSecret: Bool = false,
            options: [Option]? = nil,
            question: String
        ) {
            self.header = header
            self.id = id
            self.isOther = isOther
            self.isSecret = isSecret
            self.options = options
            self.question = question
        }
    }

    public let threadID: String
    public let turnID: String
    public let itemID: String
    public let questions: [Question]

    internal let requestID: CodexRPCRequestID

    internal init(
        requestID: CodexRPCRequestID,
        threadID: String,
        turnID: String,
        itemID: String,
        questions: [Question]
    ) {
        self.requestID = requestID
        self.threadID = threadID
        self.turnID = turnID
        self.itemID = itemID
        self.questions = questions
    }
}

/// MCP-server elicitation request emitted by Codex.
public struct CodexMcpServerElicitationRequest: Sendable, Equatable {
    /// MCP elicitation presentation mode.
    public enum Mode: Sendable, Equatable {
        case form(Form)
        case url(URLPrompt)
    }

    /// Form-style MCP elicitation payload.
    public struct Form: Sendable, Equatable {
        public let message: String
        public let requestedSchema: CodexAppServer.JSONValue

        init(
            message: String,
            requestedSchema: CodexAppServer.JSONValue
        ) {
            self.message = message
            self.requestedSchema = requestedSchema
        }
    }

    /// URL-style MCP elicitation payload.
    public struct URLPrompt: Sendable, Equatable {
        public let elicitationID: String
        public let message: String
        public let url: String

        init(
            elicitationID: String,
            message: String,
            url: String
        ) {
            self.elicitationID = elicitationID
            self.message = message
            self.url = url
        }
    }

    public let serverName: String
    public let threadID: String
    public let turnID: String?
    public let mode: Mode

    internal let requestID: CodexRPCRequestID

    internal init(
        requestID: CodexRPCRequestID,
        serverName: String,
        threadID: String,
        turnID: String?,
        mode: Mode
    ) {
        self.requestID = requestID
        self.serverName = serverName
        self.threadID = threadID
        self.turnID = turnID
        self.mode = mode
    }
}

/// Approval response sent by the caller to unblock a waiting turn.
public enum CodexApprovalResponse: Sendable, Equatable {
    case commandExecution(CodexCommandExecutionApprovalResponse)
    case fileChange(CodexFileChangeApprovalResponse)
    case guardianDeniedAction(CodexGuardianDeniedActionApprovalResponse)
    case permissions(CodexPermissionsApprovalResponse)
}

/// Command-execution approval response sent by the caller.
public enum CodexCommandExecutionApprovalResponse: Sendable, Equatable {
    case accept
    case acceptForSession
    case acceptWithExecPolicyAmendment([String])
    case applyNetworkPolicyAmendment(CodexNetworkPolicyAmendment)
    case decline
    case cancel
}

/// File-change approval response sent by the caller.
public enum CodexFileChangeApprovalResponse: String, Sendable, Equatable {
    case accept, acceptForSession, decline, cancel
}

/// Guardian denied-action approval response sent by the caller.
public enum CodexGuardianDeniedActionApprovalResponse: Sendable, Equatable {
    case approve
}

/// Permissions approval response sent by the caller.
public struct CodexPermissionsApprovalResponse: Sendable, Equatable {
    /// Duration of a permissions grant.
    public enum Scope: String, Sendable, Equatable {
        case turn
        case session
    }

    public let permissions: CodexPermissionProfile
    public let scope: Scope

    /// Creates a permissions approval response.
    ///
    /// The default `.turn` scope applies the granted permissions only to the
    /// current turn. Pass `.session` when the caller intentionally wants the
    /// grant to remain active for the rest of the Codex session.
    public init(
        permissions: CodexPermissionProfile,
        scope: Scope = .turn
    ) {
        self.permissions = permissions
        self.scope = scope
    }
}

/// Elicitation response sent by the caller to unblock a waiting turn.
public enum CodexElicitationResponse: Sendable, Equatable {
    case toolUserInput(CodexToolUserInputResponse)
    case mcpServer(CodexMcpServerElicitationResponse)
}

/// Tool user-input response sent by the caller.
public struct CodexToolUserInputResponse: Sendable, Equatable {
    /// Answer values for one tool user-input question.
    public struct Answer: Sendable, Equatable {
        public let answers: [String]

        public init(answers: [String]) {
            self.answers = answers
        }
    }

    public let answers: [String: Answer]

    public init(answers: [String: Answer]) {
        self.answers = answers
    }
}

/// MCP-server elicitation response sent by the caller.
public struct CodexMcpServerElicitationResponse: Sendable, Equatable {
    /// MCP elicitation outcome.
    public enum Action: String, Sendable, Equatable {
        case accept, decline, cancel
    }

    public let action: Action
    public let content: CodexAppServer.JSONValue?
    public let metadata: CodexAppServer.JSONValue?

    /// Creates an MCP elicitation response.
    ///
    /// Nil `content` and `metadata` values are omitted from the response.
    public init(
        action: Action,
        content: CodexAppServer.JSONValue? = nil,
        metadata: CodexAppServer.JSONValue? = nil
    ) {
        self.action = action
        self.content = content
        self.metadata = metadata
    }
}
