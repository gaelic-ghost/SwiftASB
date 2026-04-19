import Foundation

public enum CodexInteractiveRequestKind: String, Sendable, Equatable {
    case commandExecutionApproval
    case fileChangeApproval
    case permissionsApproval
    case toolUserInput
    case mcpServerElicitation
}

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

public enum CodexApprovalRequest: Sendable, Equatable {
    case commandExecution(CodexCommandExecutionApprovalRequest)
    case fileChange(CodexFileChangeApprovalRequest)
    case permissions(CodexPermissionsApprovalRequest)

    public var threadID: String {
        switch self {
        case let .commandExecution(request):
            request.threadID
        case let .fileChange(request):
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
        case let .permissions(request):
            request.requestID
        }
    }
}

public struct CodexCommandExecutionApprovalRequest: Sendable, Equatable {
    public let threadID: String
    public let turnID: String
    public let itemID: String
    public let approvalID: String?
    public let command: String?
    public let commandActions: [CodexCommandAction]?
    public let currentDirectoryPath: String?
    public let reason: String?
    public let proposedExecpolicyAmendment: [String]?
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
        proposedExecpolicyAmendment: [String]?,
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
        self.proposedExecpolicyAmendment = proposedExecpolicyAmendment
        self.proposedNetworkPolicyAmendments = proposedNetworkPolicyAmendments
        self.networkApprovalContext = networkApprovalContext
    }
}

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

public enum CodexCommandAction: Sendable, Equatable {
    case read(Read)
    case listFiles(ListFiles)
    case search(Search)
    case unknown(Unknown)

    public struct Read: Sendable, Equatable {
        public let command: String
        public let name: String
        public let path: String

        public init(command: String, name: String, path: String) {
            self.command = command
            self.name = name
            self.path = path
        }
    }

    public struct ListFiles: Sendable, Equatable {
        public let command: String
        public let path: String?

        public init(command: String, path: String?) {
            self.command = command
            self.path = path
        }
    }

    public struct Search: Sendable, Equatable {
        public let command: String
        public let path: String?
        public let query: String?

        public init(command: String, path: String?, query: String?) {
            self.command = command
            self.path = path
            self.query = query
        }
    }

    public struct Unknown: Sendable, Equatable {
        public let command: String

        public init(command: String) {
            self.command = command
        }
    }
}

public struct CodexNetworkPolicyAmendment: Sendable, Equatable {
    public enum Action: String, Sendable, Equatable {
        case allow
        case deny
    }

    public let action: Action
    public let host: String

    public init(action: Action, host: String) {
        self.action = action
        self.host = host
    }
}

public struct CodexPermissionProfile: Sendable, Equatable {
    public struct FileSystem: Sendable, Equatable {
        public let read: [String]?
        public let write: [String]?

        public init(read: [String]? = nil, write: [String]? = nil) {
            self.read = read
            self.write = write
        }
    }

    public struct Network: Sendable, Equatable {
        public let enabled: Bool?

        public init(enabled: Bool? = nil) {
            self.enabled = enabled
        }
    }

    public let fileSystem: FileSystem?
    public let network: Network?

    public init(
        fileSystem: FileSystem? = nil,
        network: Network? = nil
    ) {
        self.fileSystem = fileSystem
        self.network = network
    }
}

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

public struct CodexToolUserInputRequest: Sendable, Equatable {
    public struct Question: Sendable, Equatable {
        public struct Option: Sendable, Equatable {
            public let description: String
            public let label: String

            public init(description: String, label: String) {
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

        public init(
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

public struct CodexMcpServerElicitationRequest: Sendable, Equatable {
    public enum Mode: Sendable, Equatable {
        case form(Form)
        case url(URLPrompt)
    }

    public struct Form: Sendable, Equatable {
        public let message: String
        public let requestedSchema: CodexAppServer.JSONValue

        public init(
            message: String,
            requestedSchema: CodexAppServer.JSONValue
        ) {
            self.message = message
            self.requestedSchema = requestedSchema
        }
    }

    public struct URLPrompt: Sendable, Equatable {
        public let elicitationID: String
        public let message: String
        public let url: String

        public init(
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

public enum CodexApprovalResponse: Sendable, Equatable {
    case commandExecution(CodexCommandExecutionApprovalResponse)
    case fileChange(CodexFileChangeApprovalResponse)
    case permissions(CodexPermissionsApprovalResponse)
}

public enum CodexCommandExecutionApprovalResponse: Sendable, Equatable {
    case accept
    case acceptForSession
    case acceptWithExecpolicyAmendment([String])
    case applyNetworkPolicyAmendment(CodexNetworkPolicyAmendment)
    case decline
    case cancel
}

public enum CodexFileChangeApprovalResponse: String, Sendable, Equatable {
    case accept
    case acceptForSession
    case decline
    case cancel
}

public struct CodexPermissionsApprovalResponse: Sendable, Equatable {
    public enum Scope: String, Sendable, Equatable {
        case turn
        case session
    }

    public let permissions: CodexPermissionProfile
    public let scope: Scope

    public init(
        permissions: CodexPermissionProfile,
        scope: Scope = .turn
    ) {
        self.permissions = permissions
        self.scope = scope
    }
}

public enum CodexElicitationResponse: Sendable, Equatable {
    case toolUserInput(CodexToolUserInputResponse)
    case mcpServer(CodexMcpServerElicitationResponse)
}

public struct CodexToolUserInputResponse: Sendable, Equatable {
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

public struct CodexMcpServerElicitationResponse: Sendable, Equatable {
    public enum Action: String, Sendable, Equatable {
        case accept
        case decline
        case cancel
    }

    public let action: Action
    public let content: CodexAppServer.JSONValue?
    public let metadata: CodexAppServer.JSONValue?

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
