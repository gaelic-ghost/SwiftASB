// This file was generated from JSON Schema using quicktype, do not modify it directly.
// To parse the JSON, add this file to your project and do:
//
//   let codexWireCodexLifecycleV2Batch = try? JSONDecoder().decode(CodexWireCodexLifecycleV2Batch.self, from: jsonData)

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

import Foundation

/// Synthetic quicktype root generated from the bundled Codex app-server protocol schema.
/// Each top-level property references one selected definition from the original bundle.
// MARK: - CodexWireCodexLifecycleV2Batch
struct CodexWireCodexLifecycleV2Batch: Codable, Equatable, Sendable {
    let initializeParams: CodexWireInitializeParams?
    let threadStartParams: CodexWireThreadStartParams?
    let threadStartResponse: CodexWireThreadStartResponse?
    let turnCompletedNotification: CodexWireTurnCompletedNotification?
    let turnStartParams: CodexWireTurnStartParams?
    let turnStartResponse: CodexWireTurnStartResponse?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireInitializeParams
struct CodexWireInitializeParams: Codable, Equatable, Sendable {
    let capabilities: CodexWireInitializeCapabilities?
    let clientInfo: CodexWireClientInfo
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Client-declared capabilities negotiated during initialize.
// MARK: - CodexWireInitializeCapabilities
struct CodexWireInitializeCapabilities: Codable, Equatable, Sendable {
    /// Opt into receiving experimental API methods and fields.
    let experimentalAPI: Bool?
    /// Exact notification method names that should be suppressed for this connection (for
    /// example `thread/started`).
    let optOutNotificationMethods: [String]?

    enum CodingKeys: String, CodingKey {
        case experimentalAPI = "experimentalApi"
        case optOutNotificationMethods
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireClientInfo
struct CodexWireClientInfo: Codable, Equatable, Sendable {
    let name: String
    let title: String?
    let version: String
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadStartParams
struct CodexWireThreadStartParams: Codable, Equatable, Sendable {
    let approvalPolicy: CodexWireApprovalPolicyUnion?
    /// Override where approval requests are routed for review on this thread and subsequent
    /// turns.
    let approvalsReviewer: CodexWireApprovalsReviewer?
    let baseInstructions: String?
    let config: [String: CodexWireJSONValue]?
    let cwd, developerInstructions: String?
    let ephemeral: Bool?
    let model, modelProvider: String?
    let personality: CodexWirePersonality?
    let sandbox: CodexWireSandboxMode?
    let serviceName: String?
    let serviceTier: CodexWireServiceTier?
    let sessionStartSource: CodexWireThreadStartSource?
}

enum CodexWireApprovalPolicyUnion: Codable, Equatable, Sendable {
    case codexWireGranularAskForApproval(CodexWireGranularAskForApproval)
    case enumeration(CodexWireApprovalPolicyEnum)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(CodexWireApprovalPolicyEnum.self) {
            self = .enumeration(x)
            return
        }
        if let x = try? container.decode(CodexWireGranularAskForApproval.self) {
            self = .codexWireGranularAskForApproval(x)
            return
        }
        if container.decodeNil() {
            self = .null
            return
        }
        throw DecodingError.typeMismatch(CodexWireApprovalPolicyUnion.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for CodexWireApprovalPolicyUnion"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .codexWireGranularAskForApproval(let x):
            try container.encode(x)
        case .enumeration(let x):
            try container.encode(x)
        case .null:
            try container.encodeNil()
        }
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireGranularAskForApproval
struct CodexWireGranularAskForApproval: Codable, Equatable, Sendable {
    let granular: CodexWireGranular
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireGranular
struct CodexWireGranular: Codable, Equatable, Sendable {
    let mcpElicitations: Bool
    let requestPermissions: Bool?
    let rules, sandboxApproval: Bool
    let skillApproval: Bool?

    enum CodingKeys: String, CodingKey {
        case mcpElicitations = "mcp_elicitations"
        case requestPermissions = "request_permissions"
        case rules
        case sandboxApproval = "sandbox_approval"
        case skillApproval = "skill_approval"
    }
}

enum CodexWireApprovalPolicyEnum: String, Codable, Equatable, Sendable {
    case never = "never"
    case onFailure = "on-failure"
    case onRequest = "on-request"
    case untrusted = "untrusted"
}

/// Configures who approval requests are routed to for review. Examples include sandbox
/// escapes, blocked network access, MCP approval prompts, and ARC escalations. Defaults to
/// `user`. `guardian_subagent` uses a carefully prompted subagent to gather relevant context
/// and apply a risk-based decision framework before approving or denying the request.
///
/// Reviewer currently used for approval requests on this thread.
enum CodexWireApprovalsReviewer: String, Codable, Equatable, Sendable {
    case guardianSubagent = "guardian_subagent"
    case user = "user"
}

enum CodexWirePersonality: String, Codable, Equatable, Sendable {
    case friendly = "friendly"
    case none = "none"
    case pragmatic = "pragmatic"
}

enum CodexWireSandboxMode: String, Codable, Equatable, Sendable {
    case dangerFullAccess = "danger-full-access"
    case readOnly = "read-only"
    case workspaceWrite = "workspace-write"
}

enum CodexWireServiceTier: String, Codable, Equatable, Sendable {
    case fast = "fast"
    case flex = "flex"
}

enum CodexWireThreadStartSource: String, Codable, Equatable, Sendable {
    case clear = "clear"
    case startup = "startup"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadStartResponse
struct CodexWireThreadStartResponse: Codable, Equatable, Sendable {
    let approvalPolicy: CodexWireAskForApproval
    /// Reviewer currently used for approval requests on this thread.
    let approvalsReviewer: CodexWireApprovalsReviewer
    let cwd: String
    /// Instruction source files currently loaded for this thread.
    let instructionSources: [String]?
    let model, modelProvider: String
    let reasoningEffort: CodexWireReasoningEffort?
    let sandbox: CodexWireSandboxPolicy
    let serviceTier: CodexWireServiceTier?
    let thread: CodexWireThread
}

enum CodexWireAskForApproval: Codable, Equatable, Sendable {
    case codexWireGranularAskForApproval(CodexWireGranularAskForApproval)
    case enumeration(CodexWireApprovalPolicyEnum)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(CodexWireApprovalPolicyEnum.self) {
            self = .enumeration(x)
            return
        }
        if let x = try? container.decode(CodexWireGranularAskForApproval.self) {
            self = .codexWireGranularAskForApproval(x)
            return
        }
        throw DecodingError.typeMismatch(CodexWireAskForApproval.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for CodexWireAskForApproval"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .codexWireGranularAskForApproval(let x):
            try container.encode(x)
        case .enumeration(let x):
            try container.encode(x)
        }
    }
}

/// See
/// https://platform.openai.com/docs/guides/reasoning?api-mode=responses#get-started-with-reasoning
enum CodexWireReasoningEffort: String, Codable, Equatable, Sendable {
    case high = "high"
    case low = "low"
    case medium = "medium"
    case minimal = "minimal"
    case none = "none"
    case xhigh = "xhigh"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireSandboxPolicy
struct CodexWireSandboxPolicy: Codable, Equatable, Sendable {
    let type: CodexWireSandboxPolicyType
    let access: CodexWireReadOnlyAccess?
    let networkAccess: CodexWireNetworkAccessUnion?
    let excludeSlashTmp, excludeTmpdirEnvVar: Bool?
    let readOnlyAccess: CodexWireReadOnlyAccess?
    let writableRoots: [String]?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireReadOnlyAccess
struct CodexWireReadOnlyAccess: Codable, Equatable, Sendable {
    let includePlatformDefaults: Bool?
    let readableRoots: [String]?
    let type: CodexWireReadOnlyAccessType
}

enum CodexWireReadOnlyAccessType: String, Codable, Equatable, Sendable {
    case fullAccess = "fullAccess"
    case restricted = "restricted"
}

enum CodexWireNetworkAccessUnion: Codable, Equatable, Sendable {
    case bool(Bool)
    case enumeration(CodexWireNetworkAccess)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(Bool.self) {
            self = .bool(x)
            return
        }
        if let x = try? container.decode(CodexWireNetworkAccess.self) {
            self = .enumeration(x)
            return
        }
        throw DecodingError.typeMismatch(CodexWireNetworkAccessUnion.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for CodexWireNetworkAccessUnion"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let x):
            try container.encode(x)
        case .enumeration(let x):
            try container.encode(x)
        }
    }
}

enum CodexWireNetworkAccess: String, Codable, Equatable, Sendable {
    case enabled = "enabled"
    case restricted = "restricted"
}

enum CodexWireSandboxPolicyType: String, Codable, Equatable, Sendable {
    case dangerFullAccess = "dangerFullAccess"
    case externalSandbox = "externalSandbox"
    case readOnly = "readOnly"
    case workspaceWrite = "workspaceWrite"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThread
struct CodexWireThread: Codable, Equatable, Sendable {
    /// Optional random unique nickname assigned to an AgentControl-spawned sub-agent.
    let agentNickname: String?
    /// Optional role (agent_role) assigned to an AgentControl-spawned sub-agent.
    let agentRole: String?
    /// Version of the CLI that created the thread.
    let cliVersion: String
    /// Unix timestamp (in seconds) when the thread was created.
    let createdAt: Int
    /// Working directory captured for the thread.
    let cwd: String
    /// Whether the thread is ephemeral and should not be materialized on disk.
    let ephemeral: Bool
    /// Source thread id when this thread was created by forking another thread.
    let forkedFromID: String?
    /// Optional Git metadata captured when the thread was created.
    let gitInfo: CodexWireGitInfo?
    let id: String
    /// Model provider used for this thread (for example, 'openai').
    let modelProvider: String
    /// Optional user-facing thread title.
    let name: String?
    /// [UNSTABLE] Path to the thread on disk.
    let path: String?
    /// Usually the first user message in the thread, if available.
    let preview: String
    /// Origin of the thread (CLI, VSCode, codex exec, codex app-server, etc.).
    let source: CodexWireSessionSourceUnion
    /// Current runtime status for the thread.
    let status: CodexWireThreadStatus
    /// Only populated on `thread/resume`, `thread/rollback`, `thread/fork`, and `thread/read`
    /// (when `includeTurns` is true) responses. For all other responses and notifications
    /// returning a Thread, the turns field will be an empty list.
    let turns: [CodexWireTurn]
    /// Unix timestamp (in seconds) when the thread was last updated.
    let updatedAt: Int

    enum CodingKeys: String, CodingKey {
        case agentNickname, agentRole, cliVersion, createdAt, cwd, ephemeral
        case forkedFromID = "forkedFromId"
        case gitInfo, id, modelProvider, name, path, preview, source, status, turns, updatedAt
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireGitInfo
struct CodexWireGitInfo: Codable, Equatable, Sendable {
    let branch, originURL, sha: String?

    enum CodingKeys: String, CodingKey {
        case branch
        case originURL = "originUrl"
        case sha
    }
}

/// Origin of the thread (CLI, VSCode, codex exec, codex app-server, etc.).
enum CodexWireSessionSourceUnion: Codable, Equatable, Sendable {
    case codexWireSessionSource(CodexWireSessionSource)
    case enumeration(CodexWireSessionSourceEnum)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(CodexWireSessionSourceEnum.self) {
            self = .enumeration(x)
            return
        }
        if let x = try? container.decode(CodexWireSessionSource.self) {
            self = .codexWireSessionSource(x)
            return
        }
        throw DecodingError.typeMismatch(CodexWireSessionSourceUnion.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for CodexWireSessionSourceUnion"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .codexWireSessionSource(let x):
            try container.encode(x)
        case .enumeration(let x):
            try container.encode(x)
        }
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireSessionSource
struct CodexWireSessionSource: Codable, Equatable, Sendable {
    let custom: String?
    let subAgent: CodexWireSubAgentSourceUnion?
}

enum CodexWireSubAgentSourceUnion: Codable, Equatable, Sendable {
    case codexWireSubAgentSource(CodexWireSubAgentSource)
    case enumeration(CodexWireSubAgentSourceEnum)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(CodexWireSubAgentSourceEnum.self) {
            self = .enumeration(x)
            return
        }
        if let x = try? container.decode(CodexWireSubAgentSource.self) {
            self = .codexWireSubAgentSource(x)
            return
        }
        throw DecodingError.typeMismatch(CodexWireSubAgentSourceUnion.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for CodexWireSubAgentSourceUnion"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .codexWireSubAgentSource(let x):
            try container.encode(x)
        case .enumeration(let x):
            try container.encode(x)
        }
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireSubAgentSource
struct CodexWireSubAgentSource: Codable, Equatable, Sendable {
    let threadSpawn: CodexWireThreadSpawn?
    let other: String?

    enum CodingKeys: String, CodingKey {
        case threadSpawn = "thread_spawn"
        case other
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadSpawn
struct CodexWireThreadSpawn: Codable, Equatable, Sendable {
    let agentNickname, agentPath, agentRole: String?
    let depth: Int
    let parentThreadID: String

    enum CodingKeys: String, CodingKey {
        case agentNickname = "agent_nickname"
        case agentPath = "agent_path"
        case agentRole = "agent_role"
        case depth
        case parentThreadID = "parent_thread_id"
    }
}

enum CodexWireSubAgentSourceEnum: String, Codable, Equatable, Sendable {
    case compact = "compact"
    case memoryConsolidation = "memory_consolidation"
    case review = "review"
}

enum CodexWireSessionSourceEnum: String, Codable, Equatable, Sendable {
    case appServer = "appServer"
    case cli = "cli"
    case exec = "exec"
    case unknown = "unknown"
    case vscode = "vscode"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Current runtime status for the thread.
// MARK: - CodexWireThreadStatus
struct CodexWireThreadStatus: Codable, Equatable, Sendable {
    let type: CodexWireThreadStatusType
    let activeFlags: [CodexWireThreadActiveFlag]?
}

enum CodexWireThreadActiveFlag: String, Codable, Equatable, Sendable {
    case waitingOnApproval = "waitingOnApproval"
    case waitingOnUserInput = "waitingOnUserInput"
}

enum CodexWireThreadStatusType: String, Codable, Equatable, Sendable {
    case active = "active"
    case idle = "idle"
    case notLoaded = "notLoaded"
    case systemError = "systemError"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireTurn
struct CodexWireTurn: Codable, Equatable, Sendable {
    /// Unix timestamp (in seconds) when the turn completed.
    let completedAt: Int?
    /// Duration between turn start and completion in milliseconds, if known.
    let durationMS: Int?
    /// Only populated when the Turn's status is failed.
    let error: CodexWireTurnError?
    let id: String
    /// Only populated on a `thread/resume` or `thread/fork` response. For all other responses
    /// and notifications returning a Turn, the items field will be an empty list.
    let items: [CodexWireThreadItem]
    /// Unix timestamp (in seconds) when the turn started.
    let startedAt: Int?
    let status: CodexWireTurnStatus

    enum CodingKeys: String, CodingKey {
        case completedAt
        case durationMS = "durationMs"
        case error, id, items, startedAt, status
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireTurnError
struct CodexWireTurnError: Codable, Equatable, Sendable {
    let additionalDetails: String?
    let codexErrorInfo: CodexWireCodexErrorInfoUnion?
    let message: String
}

enum CodexWireCodexErrorInfoUnion: Codable, Equatable, Sendable {
    case codexWireCodexErrorInfo(CodexWireCodexErrorInfo)
    case enumeration(CodexWireCodexErrorInfoEnum)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(CodexWireCodexErrorInfoEnum.self) {
            self = .enumeration(x)
            return
        }
        if let x = try? container.decode(CodexWireCodexErrorInfo.self) {
            self = .codexWireCodexErrorInfo(x)
            return
        }
        if container.decodeNil() {
            self = .null
            return
        }
        throw DecodingError.typeMismatch(CodexWireCodexErrorInfoUnion.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for CodexWireCodexErrorInfoUnion"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .codexWireCodexErrorInfo(let x):
            try container.encode(x)
        case .enumeration(let x):
            try container.encode(x)
        case .null:
            try container.encodeNil()
        }
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Failed to connect to the response SSE stream.
///
/// The response SSE stream disconnected in the middle of a turn before completion.
///
/// Reached the retry limit for responses.
///
/// Returned when `turn/start` or `turn/steer` is submitted while the current active turn
/// cannot accept same-turn steering, for example `/review` or manual `/compact`.
// MARK: - CodexWireCodexErrorInfo
struct CodexWireCodexErrorInfo: Codable, Equatable, Sendable {
    let httpConnectionFailed: CodexWireHTTPConnectionFailed?
    let responseStreamConnectionFailed: CodexWireResponseStreamConnectionFailed?
    let responseStreamDisconnected: CodexWireResponseStreamDisconnected?
    let responseTooManyFailedAttempts: CodexWireResponseTooManyFailedAttempts?
    let activeTurnNotSteerable: CodexWireActiveTurnNotSteerable?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireActiveTurnNotSteerable
struct CodexWireActiveTurnNotSteerable: Codable, Equatable, Sendable {
    let turnKind: CodexWireNonSteerableTurnKind
}

enum CodexWireNonSteerableTurnKind: String, Codable, Equatable, Sendable {
    case compact = "compact"
    case review = "review"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireHTTPConnectionFailed
struct CodexWireHTTPConnectionFailed: Codable, Equatable, Sendable {
    let httpStatusCode: Int?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireResponseStreamConnectionFailed
struct CodexWireResponseStreamConnectionFailed: Codable, Equatable, Sendable {
    let httpStatusCode: Int?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireResponseStreamDisconnected
struct CodexWireResponseStreamDisconnected: Codable, Equatable, Sendable {
    let httpStatusCode: Int?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireResponseTooManyFailedAttempts
struct CodexWireResponseTooManyFailedAttempts: Codable, Equatable, Sendable {
    let httpStatusCode: Int?
}

enum CodexWireCodexErrorInfoEnum: String, Codable, Equatable, Sendable {
    case badRequest = "badRequest"
    case contextWindowExceeded = "contextWindowExceeded"
    case internalServerError = "internalServerError"
    case other = "other"
    case sandboxError = "sandboxError"
    case serverOverloaded = "serverOverloaded"
    case threadRollbackFailed = "threadRollbackFailed"
    case unauthorized = "unauthorized"
    case usageLimitExceeded = "usageLimitExceeded"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// EXPERIMENTAL - proposed plan item content. The completed plan item is authoritative and
/// may not match the concatenation of `PlanDelta` text.
// MARK: - CodexWireThreadItem
struct CodexWireThreadItem: Codable, Equatable, Sendable {
    let content: [CodexWireContent]?
    /// Unique identifier for this collab tool call.
    let id: String
    let type: CodexWireThreadItemType
    let fragments: [CodexWireHookPromptFragment]?
    let memoryCitation: CodexWireMemoryCitation?
    let phase: CodexWireMessagePhase?
    let text: String?
    let summary: [String]?
    /// The command's output, aggregated from stdout and stderr.
    let aggregatedOutput: String?
    /// The command to be executed.
    let command: String?
    /// A best-effort parsing of the command to understand the action(s) it will perform. This
    /// returns a list of CommandAction objects because a single shell command may be composed of
    /// many commands piped together.
    let commandActions: [CodexWireCommandAction]?
    /// The command's working directory.
    let cwd: String?
    /// The duration of the command execution in milliseconds.
    ///
    /// The duration of the MCP tool call in milliseconds.
    ///
    /// The duration of the dynamic tool call in milliseconds.
    let durationMS: Int?
    /// The command's exit code.
    let exitCode: Int?
    /// Identifier for the underlying PTY process (when available).
    let processID: String?
    let source: CodexWireCommandExecutionSource?
    /// Current status of the collab tool call.
    let status: String?
    let changes: [CodexWireFileUpdateChange]?
    let arguments: CodexWireJSONValue?
    let error: CodexWireMCPToolCallError?
    let result: CodexWireResult?
    let server: String?
    /// Name of the collab tool that was invoked.
    let tool: String?
    let contentItems: [CodexWireDynamicToolCallOutputContentItem]?
    let success: Bool?
    /// Last known status of the target agents, when available.
    let agentsStates: [String: CodexWireCollabAgentState]?
    /// Model requested for the spawned agent, when applicable.
    let model: String?
    /// Prompt text sent as part of the collab tool call, when available.
    let prompt: String?
    /// Reasoning effort requested for the spawned agent, when applicable.
    let reasoningEffort: CodexWireReasoningEffort?
    /// Thread ID of the receiving agent, when applicable. In case of spawn operation, this
    /// corresponds to the newly spawned agent.
    let receiverThreadIDS: [String]?
    /// Thread ID of the agent issuing the collab request.
    let senderThreadID: String?
    let action: CodexWireWebSearchAction?
    let query, path: String?
    let revisedPrompt, savedPath: String?
    let review: String?

    enum CodingKeys: String, CodingKey {
        case content, id, type, fragments, memoryCitation, phase, text, summary, aggregatedOutput, command, commandActions, cwd
        case durationMS = "durationMs"
        case exitCode
        case processID = "processId"
        case source, status, changes, arguments, error, result, server, tool, contentItems, success, agentsStates, model, prompt, reasoningEffort
        case receiverThreadIDS = "receiverThreadIds"
        case senderThreadID = "senderThreadId"
        case action, query, path, revisedPrompt, savedPath, review
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireWebSearchAction
struct CodexWireWebSearchAction: Codable, Equatable, Sendable {
    let queries: [String]?
    let query: String?
    let type: CodexWireWebSearchActionType
    let url, pattern: String?
}

enum CodexWireWebSearchActionType: String, Codable, Equatable, Sendable {
    case findInPage = "findInPage"
    case openPage = "openPage"
    case other = "other"
    case search = "search"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireCollabAgentState
struct CodexWireCollabAgentState: Codable, Equatable, Sendable {
    let message: String?
    let status: CodexWireCollabAgentStatus
}

enum CodexWireCollabAgentStatus: String, Codable, Equatable, Sendable {
    case completed = "completed"
    case errored = "errored"
    case interrupted = "interrupted"
    case notFound = "notFound"
    case pendingInit = "pendingInit"
    case running = "running"
    case shutdown = "shutdown"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireFileUpdateChange
struct CodexWireFileUpdateChange: Codable, Equatable, Sendable {
    let diff: String
    let kind: CodexWirePatchChangeKind
    let path: String
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWirePatchChangeKind
struct CodexWirePatchChangeKind: Codable, Equatable, Sendable {
    let type: CodexWirePatchChangeKindType
    let movePath: String?

    enum CodingKeys: String, CodingKey {
        case type
        case movePath = "move_path"
    }
}

enum CodexWirePatchChangeKindType: String, Codable, Equatable, Sendable {
    case add = "add"
    case delete = "delete"
    case update = "update"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireCommandAction
struct CodexWireCommandAction: Codable, Equatable, Sendable {
    let command: String
    let name: String?
    let path: String?
    let type: CodexWireCommandActionType
    let query: String?
}

enum CodexWireCommandActionType: String, Codable, Equatable, Sendable {
    case listFiles = "listFiles"
    case read = "read"
    case search = "search"
    case unknown = "unknown"
}

enum CodexWireContent: Codable, Equatable, Sendable {
    case codexWireUserInput(CodexWireUserInput)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(String.self) {
            self = .string(x)
            return
        }
        if let x = try? container.decode(CodexWireUserInput.self) {
            self = .codexWireUserInput(x)
            return
        }
        throw DecodingError.typeMismatch(CodexWireContent.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for CodexWireContent"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .codexWireUserInput(let x):
            try container.encode(x)
        case .string(let x):
            try container.encode(x)
        }
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireUserInput
struct CodexWireUserInput: Codable, Equatable, Sendable {
    let text: String?
    /// UI-defined spans within `text` used to render or persist special elements.
    let textElements: [CodexWireTextElement]?
    let type: CodexWireUserInputType
    let url, path, name: String?

    enum CodingKeys: String, CodingKey {
        case text
        case textElements = "text_elements"
        case type, url, path, name
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireTextElement
struct CodexWireTextElement: Codable, Equatable, Sendable {
    /// Byte range in the parent `text` buffer that this element occupies.
    let byteRange: CodexWireByteRange
    /// Optional human-readable placeholder for the element, displayed in the UI.
    let placeholder: String?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Byte range in the parent `text` buffer that this element occupies.
// MARK: - CodexWireByteRange
struct CodexWireByteRange: Codable, Equatable, Sendable {
    let end, start: Int
}

enum CodexWireUserInputType: String, Codable, Equatable, Sendable {
    case image = "image"
    case localImage = "localImage"
    case mention = "mention"
    case skill = "skill"
    case text = "text"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireDynamicToolCallOutputContentItem
struct CodexWireDynamicToolCallOutputContentItem: Codable, Equatable, Sendable {
    let text: String?
    let type: CodexWireInputDynamicToolCallOutputContentItemType
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case text, type
        case imageURL = "imageUrl"
    }
}

enum CodexWireInputDynamicToolCallOutputContentItemType: String, Codable, Equatable, Sendable {
    case inputImage = "inputImage"
    case inputText = "inputText"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireMCPToolCallError
struct CodexWireMCPToolCallError: Codable, Equatable, Sendable {
    let message: String
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireHookPromptFragment
struct CodexWireHookPromptFragment: Codable, Equatable, Sendable {
    let hookRunID, text: String

    enum CodingKeys: String, CodingKey {
        case hookRunID = "hookRunId"
        case text
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireMemoryCitation
struct CodexWireMemoryCitation: Codable, Equatable, Sendable {
    let entries: [CodexWireMemoryCitationEntry]
    let threadIDS: [String]

    enum CodingKeys: String, CodingKey {
        case entries
        case threadIDS = "threadIds"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireMemoryCitationEntry
struct CodexWireMemoryCitationEntry: Codable, Equatable, Sendable {
    let lineEnd, lineStart: Int
    let note, path: String
}

/// Mid-turn assistant text (for example preamble/progress narration).
///
/// Additional tool calls or assistant output may follow before turn completion.
///
/// The assistant's terminal answer text for the current turn.
enum CodexWireMessagePhase: String, Codable, Equatable, Sendable {
    case commentary = "commentary"
    case finalAnswer = "final_answer"
}

enum CodexWireResult: Codable, Equatable, Sendable {
    case codexWireMCPToolCallResult(CodexWireMCPToolCallResult)
    case string(String)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(String.self) {
            self = .string(x)
            return
        }
        if let x = try? container.decode(CodexWireMCPToolCallResult.self) {
            self = .codexWireMCPToolCallResult(x)
            return
        }
        if container.decodeNil() {
            self = .null
            return
        }
        throw DecodingError.typeMismatch(CodexWireResult.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for CodexWireResult"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .codexWireMCPToolCallResult(let x):
            try container.encode(x)
        case .string(let x):
            try container.encode(x)
        case .null:
            try container.encodeNil()
        }
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireMCPToolCallResult
struct CodexWireMCPToolCallResult: Codable, Equatable, Sendable {
    let meta: CodexWireJSONValue?
    let content: [CodexWireJSONValue]
    let structuredContent: CodexWireJSONValue?

    enum CodingKeys: String, CodingKey {
        case meta = "_meta"
        case content, structuredContent
    }
}

enum CodexWireCommandExecutionSource: String, Codable, Equatable, Sendable {
    case agent = "agent"
    case unifiedExecInteraction = "unifiedExecInteraction"
    case unifiedExecStartup = "unifiedExecStartup"
    case userShell = "userShell"
}

enum CodexWireThreadItemType: String, Codable, Equatable, Sendable {
    case agentMessage = "agentMessage"
    case collabAgentToolCall = "collabAgentToolCall"
    case commandExecution = "commandExecution"
    case contextCompaction = "contextCompaction"
    case dynamicToolCall = "dynamicToolCall"
    case enteredReviewMode = "enteredReviewMode"
    case exitedReviewMode = "exitedReviewMode"
    case fileChange = "fileChange"
    case hookPrompt = "hookPrompt"
    case imageGeneration = "imageGeneration"
    case imageView = "imageView"
    case mcpToolCall = "mcpToolCall"
    case plan = "plan"
    case reasoning = "reasoning"
    case userMessage = "userMessage"
    case webSearch = "webSearch"
}

enum CodexWireTurnStatus: String, Codable, Equatable, Sendable {
    case completed = "completed"
    case failed = "failed"
    case inProgress = "inProgress"
    case interrupted = "interrupted"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireTurnCompletedNotification
struct CodexWireTurnCompletedNotification: Codable, Equatable, Sendable {
    let threadID: String
    let turn: CodexWireTurn

    enum CodingKeys: String, CodingKey {
        case threadID = "threadId"
        case turn
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireTurnStartParams
struct CodexWireTurnStartParams: Codable, Equatable, Sendable {
    /// Override the approval policy for this turn and subsequent turns.
    let approvalPolicy: CodexWireApprovalPolicyUnion?
    /// Override where approval requests are routed for review on this turn and subsequent turns.
    let approvalsReviewer: CodexWireApprovalsReviewer?
    /// Override the working directory for this turn and subsequent turns.
    let cwd: String?
    /// Override the reasoning effort for this turn and subsequent turns.
    let effort: CodexWireReasoningEffort?
    let input: [CodexWireUserInput]
    /// Override the model for this turn and subsequent turns.
    let model: String?
    /// Optional JSON Schema used to constrain the final assistant message for this turn.
    let outputSchema: CodexWireJSONValue?
    /// Override the personality for this turn and subsequent turns.
    let personality: CodexWirePersonality?
    /// Override the sandbox policy for this turn and subsequent turns.
    let sandboxPolicy: CodexWireDangerFullAccessSandboxPolicyClass?
    /// Override the service tier for this turn and subsequent turns.
    let serviceTier: CodexWireServiceTier?
    /// Override the reasoning summary for this turn and subsequent turns.
    let summary: CodexWireReasoningSummary?
    let threadID: String

    enum CodingKeys: String, CodingKey {
        case approvalPolicy, approvalsReviewer, cwd, effort, input, model, outputSchema, personality, sandboxPolicy, serviceTier, summary
        case threadID = "threadId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireDangerFullAccessSandboxPolicyClass
struct CodexWireDangerFullAccessSandboxPolicyClass: Codable, Equatable, Sendable {
    let type: CodexWireSandboxPolicyType
    let access: CodexWireReadOnlyAccess?
    let networkAccess: CodexWireNetworkAccessUnion?
    let excludeSlashTmp, excludeTmpdirEnvVar: Bool?
    let readOnlyAccess: CodexWireReadOnlyAccess?
    let writableRoots: [String]?
}

/// Option to disable reasoning summaries.
enum CodexWireReasoningSummary: String, Codable, Equatable, Sendable {
    case auto = "auto"
    case concise = "concise"
    case detailed = "detailed"
    case none = "none"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireTurnStartResponse
struct CodexWireTurnStartResponse: Codable, Equatable, Sendable {
    let turn: CodexWireTurn
}

indirect enum CodexWireJSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case integer(Int)
    case double(Double)
    case string(String)
    case array([CodexWireJSONValue])
    case object([String: CodexWireJSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let integer = try? container.decode(Int.self) {
            self = .integer(integer)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([CodexWireJSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: CodexWireJSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value while decoding CodexWireJSONValue."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case let .bool(value):
            try container.encode(value)
        case let .integer(value):
            try container.encode(value)
        case let .double(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        }
    }
}
