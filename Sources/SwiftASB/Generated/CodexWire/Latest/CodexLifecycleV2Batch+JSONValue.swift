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
    let agentMessageDeltaNotification: CodexWireAgentMessageDeltaNotification?
    let appListUpdatedNotification: CodexWireAppListUpdatedNotification?
    let appsListParams: CodexWireAppsListParams?
    let appsListResponse: CodexWireAppsListResponse?
    let collaborationModeListParams: [String: CodexWireJSONValue]?
    let collaborationModeListResponse: CodexWireCollaborationModeListResponse?
    let commandExecOutputDeltaNotification: CodexWireCommandExecOutputDeltaNotification?
    let commandExecutionOutputDeltaNotification: CodexWireCommandExecutionOutputDeltaNotification?
    let configReadParams: CodexWireConfigReadParams?
    let configReadResponse: CodexWireConfigReadResponse?
    let configRequirementsReadResponse: CodexWireConfigRequirementsReadResponse?
    let configWarningNotification: CodexWireConfigWarningNotification?
    let contextCompactedNotification: CodexWireContextCompactedNotification?
    let deprecationNoticeNotification: CodexWireDeprecationNoticeNotification?
    let errorNotification: CodexWireErrorNotification?
    let externalAgentConfigImportCompletedNotification: [String: CodexWireJSONValue]?
    let fileChangeOutputDeltaNotification: CodexWireFileChangeOutputDeltaNotification?
    let fileChangePatchUpdatedNotification: CodexWireFileChangePatchUpdatedNotification?
    let fsChangedNotification: CodexWireFSChangedNotification?
    let fsGetMetadataParams: CodexWireFSGetMetadataParams?
    let fsGetMetadataResponse: CodexWireFSGetMetadataResponse?
    let fsReadDirectoryParams: CodexWireFSReadDirectoryParams?
    let fsReadDirectoryResponse: CodexWireFSReadDirectoryResponse?
    let fsReadFileParams: CodexWireFSReadFileParams?
    let fsReadFileResponse: CodexWireFSReadFileResponse?
    let fsUnwatchParams: CodexWireFSUnwatchParams?
    let fsUnwatchResponse: [String: CodexWireJSONValue]?
    let fsWatchParams: CodexWireFSWatchParams?
    let fsWatchResponse: CodexWireFSWatchResponse?
    let guardianWarningNotification: CodexWireGuardianWarningNotification?
    let hookCompletedNotification: CodexWireHookCompletedNotification?
    let hookStartedNotification: CodexWireHookStartedNotification?
    let initializeParams: CodexWireInitializeParams?
    let itemCompletedNotification: CodexWireItemCompletedNotification?
    let itemGuardianApprovalReviewCompletedNotification: CodexWireItemGuardianApprovalReviewCompletedNotification?
    let itemGuardianApprovalReviewStartedNotification: CodexWireItemGuardianApprovalReviewStartedNotification?
    let itemStartedNotification: CodexWireItemStartedNotification?
    let listMCPServerStatusParams: CodexWireListMCPServerStatusParams?
    let listMCPServerStatusResponse: CodexWireListMCPServerStatusResponse?
    let mcpResourceReadParams: CodexWireMCPResourceReadParams?
    let mcpResourceReadResponse: CodexWireMCPResourceReadResponse?
    let mcpServerStatusUpdatedNotification: CodexWireMCPServerStatusUpdatedNotification?
    let mcpToolCallProgressNotification: CodexWireMCPToolCallProgressNotification?
    let modelListParams: CodexWireModelListParams?
    let modelListResponse: CodexWireModelListResponse?
    let modelReroutedNotification: CodexWireModelReroutedNotification?
    let modelVerificationNotification: CodexWireModelVerificationNotification?
    let planDeltaNotification: CodexWirePlanDeltaNotification?
    let pluginListParams: CodexWirePluginListParams?
    let pluginListResponse: CodexWirePluginListResponse?
    let pluginReadParams: CodexWirePluginReadParams?
    let pluginReadResponse: CodexWirePluginReadResponse?
    let pluginShareDeleteParams: CodexWirePluginShareDeleteParams?
    let pluginShareDeleteResponse, pluginShareListParams: [String: CodexWireJSONValue]?
    let pluginShareListResponse: CodexWirePluginShareListResponse?
    let pluginShareSaveParams: CodexWirePluginShareSaveParams?
    let pluginShareSaveResponse: CodexWirePluginShareSaveResponse?
    let pluginShareUpdateTargetsParams: CodexWirePluginShareUpdateTargetsParams?
    let pluginShareUpdateTargetsResponse: CodexWirePluginShareUpdateTargetsResponse?
    let pluginSkillReadParams: CodexWirePluginSkillReadParams?
    let pluginSkillReadResponse: CodexWirePluginSkillReadResponse?
    let processExitedNotification: CodexWireProcessExitedNotification?
    let processKillParams: CodexWireProcessKillParams?
    let processKillResponse: [String: CodexWireJSONValue]?
    let processOutputDeltaNotification: CodexWireProcessOutputDeltaNotification?
    let processResizePtyParams: CodexWireProcessResizePtyParams?
    let processResizePtyResponse: [String: CodexWireJSONValue]?
    let processSpawnParams: CodexWireProcessSpawnParams?
    let processSpawnResponse: [String: CodexWireJSONValue]?
    let processWriteStdinParams: CodexWireProcessWriteStdinParams?
    let processWriteStdinResponse: [String: CodexWireJSONValue]?
    let rawResponseItemCompletedNotification: CodexWireRawResponseItemCompletedNotification?
    let reasoningSummaryPartAddedNotification: CodexWireReasoningSummaryPartAddedNotification?
    let reasoningSummaryTextDeltaNotification: CodexWireReasoningSummaryTextDeltaNotification?
    let reasoningTextDeltaNotification: CodexWireReasoningTextDeltaNotification?
    let remoteControlStatusChangedNotification: CodexWireRemoteControlStatusChangedNotification?
    let serverRequestResolvedNotification: CodexWireServerRequestResolvedNotification?
    let skillsChangedNotification: [String: CodexWireJSONValue]?
    let skillsListParams: CodexWireSkillsListParams?
    let skillsListResponse: CodexWireSkillsListResponse?
    let threadApproveGuardianDeniedActionParams: CodexWireThreadApproveGuardianDeniedActionParams?
    let threadApproveGuardianDeniedActionResponse: [String: CodexWireJSONValue]?
    let threadArchivedNotification: CodexWireThreadArchivedNotification?
    let threadArchiveParams: CodexWireThreadArchiveParams?
    let threadArchiveResponse: [String: CodexWireJSONValue]?
    let threadClosedNotification: CodexWireThreadClosedNotification?
    let threadCompactStartParams: CodexWireThreadCompactStartParams?
    let threadCompactStartResponse: [String: CodexWireJSONValue]?
    let threadGoalClearedNotification: CodexWireThreadGoalClearedNotification?
    let threadGoalClearParams: CodexWireThreadGoalClearParams?
    let threadGoalClearResponse: CodexWireThreadGoalClearResponse?
    let threadGoalGetParams: CodexWireThreadGoalGetParams?
    let threadGoalGetResponse: CodexWireThreadGoalGetResponse?
    let threadGoalSetParams: CodexWireThreadGoalSetParams?
    let threadGoalSetResponse: CodexWireThreadGoalSetResponse?
    let threadGoalUpdatedNotification: CodexWireThreadGoalUpdatedNotification?
    let threadLoadedListParams: CodexWireThreadLoadedListParams?
    let threadLoadedListResponse: CodexWireThreadLoadedListResponse?
    let threadMetadataUpdateParams: CodexWireThreadMetadataUpdateParams?
    let threadMetadataUpdateResponse: CodexWireThreadMetadataUpdateResponse?
    let threadNameUpdatedNotification: CodexWireThreadNameUpdatedNotification?
    let threadRollbackParams: CodexWireThreadRollbackParams?
    let threadRollbackResponse: CodexWireThreadRollbackResponse?
    let threadSetNameParams: CodexWireThreadSetNameParams?
    let threadSetNameResponse: [String: CodexWireJSONValue]?
    let threadStartedNotification: CodexWireThreadStartedNotification?
    let threadStartParams: CodexWireThreadStartParams?
    let threadStartResponse: CodexWireThreadStartResponse?
    let threadStatusChangedNotification: CodexWireThreadStatusChangedNotification?
    let threadTokenUsageUpdatedNotification: CodexWireThreadTokenUsageUpdatedNotification?
    let threadTurnsItemsListParams: CodexWireThreadTurnsItemsListParams?
    let threadTurnsItemsListResponse: CodexWireThreadTurnsItemsListResponse?
    let threadTurnsListParams: CodexWireThreadTurnsListParams?
    let threadTurnsListResponse: CodexWireThreadTurnsListResponse?
    let threadUnarchivedNotification: CodexWireThreadUnarchivedNotification?
    let threadUnarchiveParams: CodexWireThreadUnarchiveParams?
    let threadUnarchiveResponse: CodexWireThreadUnarchiveResponse?
    let turnCompletedNotification: CodexWireTurnCompletedNotification?
    let turnDiffUpdatedNotification: CodexWireTurnDiffUpdatedNotification?
    let turnPlanUpdatedNotification: CodexWireTurnPlanUpdatedNotification?
    let turnStartedNotification: CodexWireTurnStartedNotification?
    let turnStartParams: CodexWireTurnStartParams?
    let turnStartResponse: CodexWireTurnStartResponse?
    let warningNotification: CodexWireWarningNotification?
    let windowsSandboxReadinessResponse: CodexWireWindowsSandboxReadinessResponse?

    enum CodingKeys: String, CodingKey {
        case agentMessageDeltaNotification, appListUpdatedNotification, appsListParams, appsListResponse, collaborationModeListParams, collaborationModeListResponse, commandExecOutputDeltaNotification, commandExecutionOutputDeltaNotification, configReadParams, configReadResponse, configRequirementsReadResponse, configWarningNotification, contextCompactedNotification, deprecationNoticeNotification, errorNotification, externalAgentConfigImportCompletedNotification, fileChangeOutputDeltaNotification, fileChangePatchUpdatedNotification, fsChangedNotification, fsGetMetadataParams, fsGetMetadataResponse, fsReadDirectoryParams, fsReadDirectoryResponse, fsReadFileParams, fsReadFileResponse, fsUnwatchParams, fsUnwatchResponse, fsWatchParams, fsWatchResponse, guardianWarningNotification, hookCompletedNotification, hookStartedNotification, initializeParams, itemCompletedNotification, itemGuardianApprovalReviewCompletedNotification, itemGuardianApprovalReviewStartedNotification, itemStartedNotification
        case listMCPServerStatusParams = "listMcpServerStatusParams"
        case listMCPServerStatusResponse = "listMcpServerStatusResponse"
        case mcpResourceReadParams, mcpResourceReadResponse, mcpServerStatusUpdatedNotification, mcpToolCallProgressNotification, modelListParams, modelListResponse, modelReroutedNotification, modelVerificationNotification, planDeltaNotification, pluginListParams, pluginListResponse, pluginReadParams, pluginReadResponse, pluginShareDeleteParams, pluginShareDeleteResponse, pluginShareListParams, pluginShareListResponse, pluginShareSaveParams, pluginShareSaveResponse, pluginShareUpdateTargetsParams, pluginShareUpdateTargetsResponse, pluginSkillReadParams, pluginSkillReadResponse, processExitedNotification, processKillParams, processKillResponse, processOutputDeltaNotification, processResizePtyParams, processResizePtyResponse, processSpawnParams, processSpawnResponse, processWriteStdinParams, processWriteStdinResponse, rawResponseItemCompletedNotification, reasoningSummaryPartAddedNotification, reasoningSummaryTextDeltaNotification, reasoningTextDeltaNotification, remoteControlStatusChangedNotification, serverRequestResolvedNotification, skillsChangedNotification, skillsListParams, skillsListResponse, threadApproveGuardianDeniedActionParams, threadApproveGuardianDeniedActionResponse, threadArchivedNotification, threadArchiveParams, threadArchiveResponse, threadClosedNotification, threadCompactStartParams, threadCompactStartResponse, threadGoalClearedNotification, threadGoalClearParams, threadGoalClearResponse, threadGoalGetParams, threadGoalGetResponse, threadGoalSetParams, threadGoalSetResponse, threadGoalUpdatedNotification, threadLoadedListParams, threadLoadedListResponse, threadMetadataUpdateParams, threadMetadataUpdateResponse, threadNameUpdatedNotification, threadRollbackParams, threadRollbackResponse, threadSetNameParams, threadSetNameResponse, threadStartedNotification, threadStartParams, threadStartResponse, threadStatusChangedNotification, threadTokenUsageUpdatedNotification, threadTurnsItemsListParams, threadTurnsItemsListResponse, threadTurnsListParams, threadTurnsListResponse, threadUnarchivedNotification, threadUnarchiveParams, threadUnarchiveResponse, turnCompletedNotification, turnDiffUpdatedNotification, turnPlanUpdatedNotification, turnStartedNotification, turnStartParams, turnStartResponse, warningNotification, windowsSandboxReadinessResponse
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireAgentMessageDeltaNotification
struct CodexWireAgentMessageDeltaNotification: Codable, Equatable, Sendable {
    let delta, itemID, threadID, turnID: String

    enum CodingKeys: String, CodingKey {
        case delta
        case itemID = "itemId"
        case threadID = "threadId"
        case turnID = "turnId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// EXPERIMENTAL - notification emitted when the app list changes.
// MARK: - CodexWireAppListUpdatedNotification
struct CodexWireAppListUpdatedNotification: Codable, Equatable, Sendable {
    let data: [CodexWireAppInfo]
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// EXPERIMENTAL - app metadata returned by app-list APIs.
// MARK: - CodexWireAppInfo
struct CodexWireAppInfo: Codable, Equatable, Sendable {
    let appMetadata: CodexWireAppMetadata?
    let branding: CodexWireAppBranding?
    let description, distributionChannel: String?
    let id: String
    let installURL: String?
    let isAccessible: Bool?
    /// Whether this app is enabled in config.toml. Example: ```toml [apps.bad_app] enabled =
    /// false ```
    let isEnabled: Bool?
    let labels: [String: String]?
    let logoURL, logoURLDark: String?
    let name: String
    let pluginDisplayNames: [String]?

    enum CodingKeys: String, CodingKey {
        case appMetadata, branding, description, distributionChannel, id
        case installURL = "installUrl"
        case isAccessible, isEnabled, labels
        case logoURL = "logoUrl"
        case logoURLDark = "logoUrlDark"
        case name, pluginDisplayNames
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireAppMetadata
struct CodexWireAppMetadata: Codable, Equatable, Sendable {
    let categories: [String]?
    let developer: String?
    let firstPartyRequiresInstall: Bool?
    let firstPartyType: String?
    let review: CodexWireAppReview?
    let screenshots: [CodexWireAppScreenshot]?
    let seoDescription: String?
    let showInComposerWhenUnlinked: Bool?
    let subCategories: [String]?
    let version, versionID, versionNotes: String?

    enum CodingKeys: String, CodingKey {
        case categories, developer, firstPartyRequiresInstall, firstPartyType, review, screenshots, seoDescription, showInComposerWhenUnlinked, subCategories, version
        case versionID = "versionId"
        case versionNotes
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireAppReview
struct CodexWireAppReview: Codable, Equatable, Sendable {
    let status: String
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireAppScreenshot
struct CodexWireAppScreenshot: Codable, Equatable, Sendable {
    let fileID, url: String?
    let userPrompt: String

    enum CodingKeys: String, CodingKey {
        case fileID = "fileId"
        case url, userPrompt
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// EXPERIMENTAL - app metadata returned by app-list APIs.
// MARK: - CodexWireAppBranding
struct CodexWireAppBranding: Codable, Equatable, Sendable {
    let category, developer: String?
    let isDiscoverableApp: Bool
    let privacyPolicy, termsOfService, website: String?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// EXPERIMENTAL - list available apps/connectors.
// MARK: - CodexWireAppsListParams
struct CodexWireAppsListParams: Codable, Equatable, Sendable {
    /// Opaque pagination cursor returned by a previous call.
    let cursor: String?
    /// When true, bypass app caches and fetch the latest data from sources.
    let forceRefetch: Bool?
    /// Optional page size; defaults to a reasonable server-side value.
    let limit: Int?
    /// Optional thread id used to evaluate app feature gating from that thread's config.
    let threadID: String?

    enum CodingKeys: String, CodingKey {
        case cursor, forceRefetch, limit
        case threadID = "threadId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// EXPERIMENTAL - app list response.
// MARK: - CodexWireAppsListResponse
struct CodexWireAppsListResponse: Codable, Equatable, Sendable {
    let data: [CodexWireAppInfo]
    /// Opaque cursor to pass to the next call to continue after the last item. If None, there
    /// are no more items to return.
    let nextCursor: String?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// EXPERIMENTAL - collaboration mode presets response.
// MARK: - CodexWireCollaborationModeListResponse
struct CodexWireCollaborationModeListResponse: Codable, Equatable, Sendable {
    let data: [CodexWireCollaborationModeMask]
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// EXPERIMENTAL - collaboration mode preset metadata for clients.
// MARK: - CodexWireCollaborationModeMask
struct CodexWireCollaborationModeMask: Codable, Equatable, Sendable {
    let mode: CodexWireModeKind?
    let model: String?
    let name: String
    let reasoningEffort: CodexWireReasoningEffort?

    enum CodingKeys: String, CodingKey {
        case mode, model, name
        case reasoningEffort = "reasoning_effort"
    }
}

/// Initial collaboration mode to use when the TUI starts.
enum CodexWireModeKind: String, Codable, Equatable, Sendable {
    case modeKindDefault = "default"
    case plan = "plan"
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

/// Base64-encoded output chunk emitted for a streaming `command/exec` request.
///
/// These notifications are connection-scoped. If the originating connection closes, the
/// server terminates the process.
// MARK: - CodexWireCommandExecOutputDeltaNotification
struct CodexWireCommandExecOutputDeltaNotification: Codable, Equatable, Sendable {
    /// `true` on the final streamed chunk for a stream when `outputBytesCap` truncated later
    /// output on that stream.
    let capReached: Bool
    /// Base64-encoded output bytes.
    let deltaBase64: String
    /// Client-supplied, connection-scoped `processId` from the original `command/exec` request.
    let processID: String
    /// Output stream for this chunk.
    let stream: CodexWireOutputStream

    enum CodingKeys: String, CodingKey {
        case capReached, deltaBase64
        case processID = "processId"
        case stream
    }
}

/// Output stream for this chunk.
///
/// Stream label for `command/exec/outputDelta` notifications.
///
/// stdout stream. PTY mode multiplexes terminal output here.
///
/// stderr stream.
///
/// Output stream this chunk belongs to.
///
/// Stream label for `process/outputDelta` notifications.
enum CodexWireOutputStream: String, Codable, Equatable, Sendable {
    case stderr = "stderr"
    case stdout = "stdout"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireCommandExecutionOutputDeltaNotification
struct CodexWireCommandExecutionOutputDeltaNotification: Codable, Equatable, Sendable {
    let delta, itemID, threadID, turnID: String

    enum CodingKeys: String, CodingKey {
        case delta
        case itemID = "itemId"
        case threadID = "threadId"
        case turnID = "turnId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireConfigReadParams
struct CodexWireConfigReadParams: Codable, Equatable, Sendable {
    /// Optional working directory to resolve project config layers. If specified, return the
    /// effective config as seen from that directory (i.e., including any project layers between
    /// `cwd` and the project/repo root).
    let cwd: String?
    let includeLayers: Bool?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireConfigReadResponse
struct CodexWireConfigReadResponse: Codable, Equatable, Sendable {
    let config: CodexWireConfig
    let layers: [CodexWireConfigLayer]?
    let origins: [String: CodexWireConfigLayerMetadata]
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireConfig
struct CodexWireConfig: Codable, Equatable, Sendable {
    let analytics: CodexWireAnalyticsConfig?
    let approvalPolicy: CodexWireApprovalPolicyUnion?
    /// [UNSTABLE] Optional default for where approval requests are routed for review.
    let approvalsReviewer: CodexWireApprovalsReviewer?
    let apps: CodexWireAppsConfig?
    let compactPrompt, developerInstructions, forcedChatgptWorkspaceID: String?
    let forcedLoginMethod: CodexWireForcedLoginMethod?
    let instructions, model: String?
    let modelAutoCompactTokenLimit, modelContextWindow: Int?
    let modelProvider: String?
    let modelReasoningEffort: CodexWireReasoningEffort?
    let modelReasoningSummary: CodexWireReasoningSummary?
    let modelVerbosity: CodexWireVerbosity?
    let profile: String?
    let profiles: [String: CodexWireProfileV2]?
    let reviewModel: String?
    let sandboxMode: CodexWireSandboxMode?
    let sandboxWorkspaceWrite: CodexWireSandboxWorkspaceWrite?
    let serviceTier: String?
    let tools: CodexWireToolsV2?
    let webSearch: CodexWireWebSearchMode?

    enum CodingKeys: String, CodingKey {
        case analytics
        case approvalPolicy = "approval_policy"
        case approvalsReviewer = "approvals_reviewer"
        case apps
        case compactPrompt = "compact_prompt"
        case developerInstructions = "developer_instructions"
        case forcedChatgptWorkspaceID = "forced_chatgpt_workspace_id"
        case forcedLoginMethod = "forced_login_method"
        case instructions, model
        case modelAutoCompactTokenLimit = "model_auto_compact_token_limit"
        case modelContextWindow = "model_context_window"
        case modelProvider = "model_provider"
        case modelReasoningEffort = "model_reasoning_effort"
        case modelReasoningSummary = "model_reasoning_summary"
        case modelVerbosity = "model_verbosity"
        case profile, profiles
        case reviewModel = "review_model"
        case sandboxMode = "sandbox_mode"
        case sandboxWorkspaceWrite = "sandbox_workspace_write"
        case serviceTier = "service_tier"
        case tools
        case webSearch = "web_search"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireAnalyticsConfig
struct CodexWireAnalyticsConfig: Codable, Equatable, Sendable {
    let enabled: Bool?
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
/// `user`. `auto_review` uses a carefully prompted subagent to gather relevant context and
/// apply a risk-based decision framework before approving or denying the request. The legacy
/// value `guardian_subagent` is accepted for compatibility.
///
/// Reviewer currently used for approval requests on this thread.
enum CodexWireApprovalsReviewer: String, Codable, Equatable, Sendable {
    case autoReview = "auto_review"
    case guardianSubagent = "guardian_subagent"
    case user = "user"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireAppsConfig
struct CodexWireAppsConfig: Codable, Equatable, Sendable {
    let appsConfigDefault: CodexWireAppsDefaultConfig?

    enum CodingKeys: String, CodingKey {
        case appsConfigDefault = "_default"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireAppsDefaultConfig
struct CodexWireAppsDefaultConfig: Codable, Equatable, Sendable {
    let destructiveEnabled, enabled, openWorldEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case destructiveEnabled = "destructive_enabled"
        case enabled
        case openWorldEnabled = "open_world_enabled"
    }
}

enum CodexWireForcedLoginMethod: String, Codable, Equatable, Sendable {
    case api = "api"
    case chatgpt = "chatgpt"
}

/// Option to disable reasoning summaries.
enum CodexWireReasoningSummary: String, Codable, Equatable, Sendable {
    case auto = "auto"
    case concise = "concise"
    case detailed = "detailed"
    case none = "none"
}

/// Controls output length/detail on GPT-5 models via the Responses API. Serialized with
/// lowercase values to match the OpenAI API.
enum CodexWireVerbosity: String, Codable, Equatable, Sendable {
    case high = "high"
    case low = "low"
    case medium = "medium"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireProfileV2
struct CodexWireProfileV2: Codable, Equatable, Sendable {
    let approvalPolicy: CodexWireApprovalPolicyUnion?
    /// [UNSTABLE] Optional profile-level override for where approval requests are routed for
    /// review. If omitted, the enclosing config default is used.
    let approvalsReviewer: CodexWireApprovalsReviewer?
    let chatgptBaseURL, model, modelProvider: String?
    let modelReasoningEffort: CodexWireReasoningEffort?
    let modelReasoningSummary: CodexWireReasoningSummary?
    let modelVerbosity: CodexWireVerbosity?
    let serviceTier: String?
    let tools: CodexWireToolsV2?
    let webSearch: CodexWireWebSearchMode?

    enum CodingKeys: String, CodingKey {
        case approvalPolicy = "approval_policy"
        case approvalsReviewer = "approvals_reviewer"
        case chatgptBaseURL = "chatgpt_base_url"
        case model
        case modelProvider = "model_provider"
        case modelReasoningEffort = "model_reasoning_effort"
        case modelReasoningSummary = "model_reasoning_summary"
        case modelVerbosity = "model_verbosity"
        case serviceTier = "service_tier"
        case tools
        case webSearch = "web_search"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireToolsV2
struct CodexWireToolsV2: Codable, Equatable, Sendable {
    let viewImage: Bool?
    let webSearch: CodexWireWebSearchToolConfig?

    enum CodingKeys: String, CodingKey {
        case viewImage = "view_image"
        case webSearch = "web_search"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireWebSearchToolConfig
struct CodexWireWebSearchToolConfig: Codable, Equatable, Sendable {
    let allowedDomains: [String]?
    let contextSize: CodexWireVerbosity?
    let location: CodexWireWebSearchLocation?

    enum CodingKeys: String, CodingKey {
        case allowedDomains = "allowed_domains"
        case contextSize = "context_size"
        case location
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireWebSearchLocation
struct CodexWireWebSearchLocation: Codable, Equatable, Sendable {
    let city, country, region, timezone: String?
}

enum CodexWireWebSearchMode: String, Codable, Equatable, Sendable {
    case cached = "cached"
    case disabled = "disabled"
    case live = "live"
}

enum CodexWireSandboxMode: String, Codable, Equatable, Sendable {
    case dangerFullAccess = "danger-full-access"
    case readOnly = "read-only"
    case workspaceWrite = "workspace-write"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireSandboxWorkspaceWrite
struct CodexWireSandboxWorkspaceWrite: Codable, Equatable, Sendable {
    let excludeSlashTmp, excludeTmpdirEnvVar, networkAccess: Bool?
    let writableRoots: [String]?

    enum CodingKeys: String, CodingKey {
        case excludeSlashTmp = "exclude_slash_tmp"
        case excludeTmpdirEnvVar = "exclude_tmpdir_env_var"
        case networkAccess = "network_access"
        case writableRoots = "writable_roots"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireConfigLayer
struct CodexWireConfigLayer: Codable, Equatable, Sendable {
    let config: CodexWireJSONValue
    let disabledReason: String?
    let name: CodexWireConfigLayerSource
    let version: String
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Managed preferences layer delivered by MDM (macOS only).
///
/// Managed config layer from a file (usually `managed_config.toml`).
///
/// User config layer from $CODEX_HOME/config.toml. This layer is special in that it is
/// expected to be: - writable by the user - generally outside the workspace directory
///
/// Path to a .codex/ folder within a project. There could be multiple of these between `cwd`
/// and the project/repo root.
///
/// Session-layer overrides supplied via `-c`/`--config`.
///
/// `managed_config.toml` was designed to be a config that was loaded as the last layer on
/// top of everything else. This scheme did not quite work out as intended, but we keep this
/// variant as a "best effort" while we phase out `managed_config.toml` in favor of
/// `requirements.toml`.
// MARK: - CodexWireConfigLayerSource
struct CodexWireConfigLayerSource: Codable, Equatable, Sendable {
    let domain, key: String?
    let type: CodexWireConfigLayerSourceType
    /// This is the path to the system config.toml file, though it is not guaranteed to exist.
    ///
    /// This is the path to the user's config.toml file, though it is not guaranteed to exist.
    let file: String?
    let dotCodexFolder: String?
}

enum CodexWireConfigLayerSourceType: String, Codable, Equatable, Sendable {
    case legacyManagedConfigTomlFromFile = "legacyManagedConfigTomlFromFile"
    case legacyManagedConfigTomlFromMdm = "legacyManagedConfigTomlFromMdm"
    case mdm = "mdm"
    case project = "project"
    case sessionFlags = "sessionFlags"
    case system = "system"
    case user = "user"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireConfigLayerMetadata
struct CodexWireConfigLayerMetadata: Codable, Equatable, Sendable {
    let name: CodexWireConfigLayerSource
    let version: String
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireConfigRequirementsReadResponse
struct CodexWireConfigRequirementsReadResponse: Codable, Equatable, Sendable {
    /// Null if no requirements are configured (e.g. no requirements.toml/MDM entries).
    let requirements: CodexWireConfigRequirements?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireConfigRequirements
struct CodexWireConfigRequirements: Codable, Equatable, Sendable {
    let allowedApprovalPolicies: [CodexWireAskForApproval]?
    let allowedApprovalsReviewers: [CodexWireApprovalsReviewer]?
    let allowedSandboxModes: [CodexWireSandboxMode]?
    let allowedWebSearchModes: [CodexWireWebSearchMode]?
    let enforceResidency: CodexWireResidencyRequirement?
    let featureRequirements: [String: Bool]?
    let hooks: CodexWireManagedHooksRequirements?
    let network: CodexWireNetworkRequirements?
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

enum CodexWireResidencyRequirement: String, Codable, Equatable, Sendable {
    case us = "us"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireManagedHooksRequirements
struct CodexWireManagedHooksRequirements: Codable, Equatable, Sendable {
    let managedDir: String?
    let permissionRequest, postCompact, postToolUse, preCompact: [CodexWireConfiguredHookMatcherGroup]
    let preToolUse, sessionStart, stop, userPromptSubmit: [CodexWireConfiguredHookMatcherGroup]
    let windowsManagedDir: String?

    enum CodingKeys: String, CodingKey {
        case managedDir
        case permissionRequest = "PermissionRequest"
        case postCompact = "PostCompact"
        case postToolUse = "PostToolUse"
        case preCompact = "PreCompact"
        case preToolUse = "PreToolUse"
        case sessionStart = "SessionStart"
        case stop = "Stop"
        case userPromptSubmit = "UserPromptSubmit"
        case windowsManagedDir
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireConfiguredHookMatcherGroup
struct CodexWireConfiguredHookMatcherGroup: Codable, Equatable, Sendable {
    let hooks: [CodexWireConfiguredHookHandler]
    let matcher: String?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireConfiguredHookHandler
struct CodexWireConfiguredHookHandler: Codable, Equatable, Sendable {
    let async: Bool?
    let command: String?
    let statusMessage: String?
    let timeoutSEC: Int?
    let type: CodexWireHookHandlerType

    enum CodingKeys: String, CodingKey {
        case async, command, statusMessage
        case timeoutSEC = "timeoutSec"
        case type
    }
}

enum CodexWireHookHandlerType: String, Codable, Equatable, Sendable {
    case agent = "agent"
    case command = "command"
    case prompt = "prompt"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireNetworkRequirements
struct CodexWireNetworkRequirements: Codable, Equatable, Sendable {
    /// Legacy compatibility view derived from `domains`.
    let allowedDomains: [String]?
    let allowLocalBinding: Bool?
    /// Legacy compatibility view derived from `unix_sockets`.
    let allowUnixSockets: [String]?
    let allowUpstreamProxy, dangerouslyAllowAllUnixSockets, dangerouslyAllowNonLoopbackProxy: Bool?
    /// Legacy compatibility view derived from `domains`.
    let deniedDomains: [String]?
    /// Canonical network permission map for `experimental_network`.
    let domains: [String: CodexWireNetworkDomainPermission]?
    let enabled: Bool?
    let httpPort: Int?
    /// When true, only managed allowlist entries are respected while managed network enforcement
    /// is active.
    let managedAllowedDomainsOnly: Bool?
    let socksPort: Int?
    /// Canonical unix socket permission map for `experimental_network`.
    let unixSockets: [String: CodexWireNetworkUnixSocketPermission]?
}

enum CodexWireNetworkDomainPermission: String, Codable, Equatable, Sendable {
    case allow = "allow"
    case deny = "deny"
}

enum CodexWireNetworkUnixSocketPermission: String, Codable, Equatable, Sendable {
    case allow = "allow"
    case none = "none"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireConfigWarningNotification
struct CodexWireConfigWarningNotification: Codable, Equatable, Sendable {
    /// Optional extra guidance or error details.
    let details: String?
    /// Optional path to the config file that triggered the warning.
    let path: String?
    /// Optional range for the error location inside the config file.
    let range: CodexWireTextRange?
    /// Concise summary of the warning.
    let summary: String
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireTextRange
struct CodexWireTextRange: Codable, Equatable, Sendable {
    let end, start: CodexWireTextPosition
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireTextPosition
struct CodexWireTextPosition: Codable, Equatable, Sendable {
    /// 1-based column number (in Unicode scalar values).
    let column: Int
    /// 1-based line number.
    let line: Int
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Deprecated: Use `ContextCompaction` item type instead.
// MARK: - CodexWireContextCompactedNotification
struct CodexWireContextCompactedNotification: Codable, Equatable, Sendable {
    let threadID, turnID: String

    enum CodingKeys: String, CodingKey {
        case threadID = "threadId"
        case turnID = "turnId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireDeprecationNoticeNotification
struct CodexWireDeprecationNoticeNotification: Codable, Equatable, Sendable {
    /// Optional extra guidance, such as migration steps or rationale.
    let details: String?
    /// Concise summary of what is deprecated.
    let summary: String
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireErrorNotification
struct CodexWireErrorNotification: Codable, Equatable, Sendable {
    let error: CodexWireTurnError
    let threadID, turnID: String
    let willRetry: Bool

    enum CodingKeys: String, CodingKey {
        case error
        case threadID = "threadId"
        case turnID = "turnId"
        case willRetry
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
    case cyberPolicy = "cyberPolicy"
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

/// Deprecated legacy notification for `apply_patch` textual output.
///
/// The server no longer emits this notification.
// MARK: - CodexWireFileChangeOutputDeltaNotification
struct CodexWireFileChangeOutputDeltaNotification: Codable, Equatable, Sendable {
    let delta, itemID, threadID, turnID: String

    enum CodingKeys: String, CodingKey {
        case delta
        case itemID = "itemId"
        case threadID = "threadId"
        case turnID = "turnId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireFileChangePatchUpdatedNotification
struct CodexWireFileChangePatchUpdatedNotification: Codable, Equatable, Sendable {
    let changes: [CodexWireFileUpdateChange]
    let itemID, threadID, turnID: String

    enum CodingKeys: String, CodingKey {
        case changes
        case itemID = "itemId"
        case threadID = "threadId"
        case turnID = "turnId"
    }
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

/// Filesystem watch notification emitted for `fs/watch` subscribers.
// MARK: - CodexWireFSChangedNotification
struct CodexWireFSChangedNotification: Codable, Equatable, Sendable {
    /// File or directory paths associated with this event.
    let changedPaths: [String]
    /// Watch identifier previously provided to `fs/watch`.
    let watchID: String

    enum CodingKeys: String, CodingKey {
        case changedPaths
        case watchID = "watchId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Request metadata for an absolute path.
// MARK: - CodexWireFSGetMetadataParams
struct CodexWireFSGetMetadataParams: Codable, Equatable, Sendable {
    /// Absolute path to inspect.
    let path: String
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Metadata returned by `fs/getMetadata`.
// MARK: - CodexWireFSGetMetadataResponse
struct CodexWireFSGetMetadataResponse: Codable, Equatable, Sendable {
    /// File creation time in Unix milliseconds when available, otherwise `0`.
    let createdAtMS: Int
    /// Whether the path resolves to a directory.
    let isDirectory: Bool
    /// Whether the path resolves to a regular file.
    let isFile: Bool
    /// Whether the path itself is a symbolic link.
    let isSymlink: Bool
    /// File modification time in Unix milliseconds when available, otherwise `0`.
    let modifiedAtMS: Int

    enum CodingKeys: String, CodingKey {
        case createdAtMS = "createdAtMs"
        case isDirectory, isFile, isSymlink
        case modifiedAtMS = "modifiedAtMs"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// List direct child names for a directory.
// MARK: - CodexWireFSReadDirectoryParams
struct CodexWireFSReadDirectoryParams: Codable, Equatable, Sendable {
    /// Absolute directory path to read.
    let path: String
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Directory entries returned by `fs/readDirectory`.
// MARK: - CodexWireFSReadDirectoryResponse
struct CodexWireFSReadDirectoryResponse: Codable, Equatable, Sendable {
    /// Direct child entries in the requested directory.
    let entries: [CodexWireFSReadDirectoryEntry]
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// A directory entry returned by `fs/readDirectory`.
// MARK: - CodexWireFSReadDirectoryEntry
struct CodexWireFSReadDirectoryEntry: Codable, Equatable, Sendable {
    /// Direct child entry name only, not an absolute or relative path.
    let fileName: String
    /// Whether this entry resolves to a directory.
    let isDirectory: Bool
    /// Whether this entry resolves to a regular file.
    let isFile: Bool
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Read a file from the host filesystem.
// MARK: - CodexWireFSReadFileParams
struct CodexWireFSReadFileParams: Codable, Equatable, Sendable {
    /// Absolute path to read.
    let path: String
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Base64-encoded file contents returned by `fs/readFile`.
// MARK: - CodexWireFSReadFileResponse
struct CodexWireFSReadFileResponse: Codable, Equatable, Sendable {
    /// File contents encoded as base64.
    let dataBase64: String
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Stop filesystem watch notifications for a prior `fs/watch`.
// MARK: - CodexWireFSUnwatchParams
struct CodexWireFSUnwatchParams: Codable, Equatable, Sendable {
    /// Watch identifier previously provided to `fs/watch`.
    let watchID: String

    enum CodingKeys: String, CodingKey {
        case watchID = "watchId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Start filesystem watch notifications for an absolute path.
// MARK: - CodexWireFSWatchParams
struct CodexWireFSWatchParams: Codable, Equatable, Sendable {
    /// Absolute file or directory path to watch.
    let path: String
    /// Connection-scoped watch identifier used for `fs/unwatch` and `fs/changed`.
    let watchID: String

    enum CodingKeys: String, CodingKey {
        case path
        case watchID = "watchId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Successful response for `fs/watch`.
// MARK: - CodexWireFSWatchResponse
struct CodexWireFSWatchResponse: Codable, Equatable, Sendable {
    /// Canonicalized path associated with the watch.
    let path: String
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireGuardianWarningNotification
struct CodexWireGuardianWarningNotification: Codable, Equatable, Sendable {
    /// Concise guardian warning message for the user.
    let message: String
    /// Thread target for the guardian warning.
    let threadID: String

    enum CodingKeys: String, CodingKey {
        case message
        case threadID = "threadId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireHookCompletedNotification
struct CodexWireHookCompletedNotification: Codable, Equatable, Sendable {
    let run: CodexWireHookRunSummary
    let threadID: String
    let turnID: String?

    enum CodingKeys: String, CodingKey {
        case run
        case threadID = "threadId"
        case turnID = "turnId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireHookRunSummary
struct CodexWireHookRunSummary: Codable, Equatable, Sendable {
    let completedAt: Int?
    let displayOrder: Int
    let durationMS: Int?
    let entries: [CodexWireHookOutputEntry]
    let eventName: CodexWireHookEventName
    let executionMode: CodexWireHookExecutionMode
    let handlerType: CodexWireHookHandlerType
    let id: String
    let scope: CodexWireHookScope
    let source: CodexWireHookSource?
    let sourcePath: String
    let startedAt: Int
    let status: CodexWireHookRunStatus
    let statusMessage: String?

    enum CodingKeys: String, CodingKey {
        case completedAt, displayOrder
        case durationMS = "durationMs"
        case entries, eventName, executionMode, handlerType, id, scope, source, sourcePath, startedAt, status, statusMessage
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireHookOutputEntry
struct CodexWireHookOutputEntry: Codable, Equatable, Sendable {
    let kind: CodexWireHookOutputEntryKind
    let text: String
}

enum CodexWireHookOutputEntryKind: String, Codable, Equatable, Sendable {
    case context = "context"
    case error = "error"
    case feedback = "feedback"
    case stop = "stop"
    case warning = "warning"
}

enum CodexWireHookEventName: String, Codable, Equatable, Sendable {
    case permissionRequest = "permissionRequest"
    case postCompact = "postCompact"
    case postToolUse = "postToolUse"
    case preCompact = "preCompact"
    case preToolUse = "preToolUse"
    case sessionStart = "sessionStart"
    case stop = "stop"
    case userPromptSubmit = "userPromptSubmit"
}

enum CodexWireHookExecutionMode: String, Codable, Equatable, Sendable {
    case async = "async"
    case sync = "sync"
}

enum CodexWireHookScope: String, Codable, Equatable, Sendable {
    case thread = "thread"
    case turn = "turn"
}

enum CodexWireHookSource: String, Codable, Equatable, Sendable {
    case cloudRequirements = "cloudRequirements"
    case legacyManagedConfigFile = "legacyManagedConfigFile"
    case legacyManagedConfigMdm = "legacyManagedConfigMdm"
    case mdm = "mdm"
    case plugin = "plugin"
    case project = "project"
    case sessionFlags = "sessionFlags"
    case system = "system"
    case unknown = "unknown"
    case user = "user"
}

enum CodexWireHookRunStatus: String, Codable, Equatable, Sendable {
    case blocked = "blocked"
    case completed = "completed"
    case failed = "failed"
    case running = "running"
    case stopped = "stopped"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireHookStartedNotification
struct CodexWireHookStartedNotification: Codable, Equatable, Sendable {
    let run: CodexWireHookRunSummary
    let threadID: String
    let turnID: String?

    enum CodingKeys: String, CodingKey {
        case run
        case threadID = "threadId"
        case turnID = "turnId"
    }
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

// MARK: - CodexWireItemCompletedNotification
struct CodexWireItemCompletedNotification: Codable, Equatable, Sendable {
    /// Unix timestamp (in milliseconds) when this item lifecycle completed.
    let completedAtMS: Int?
    let item: CodexWireThreadItem
    let threadID, turnID: String

    enum CodingKeys: String, CodingKey {
        case completedAtMS = "completedAtMs"
        case item
        case threadID = "threadId"
        case turnID = "turnId"
    }
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
    let mcpAppResourceURI: String?
    let result: CodexWireResult?
    let server: String?
    /// Name of the collab tool that was invoked.
    let tool: String?
    let contentItems: [CodexWireDynamicToolCallOutputContentItem]?
    let namespace: String?
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
        case source, status, changes, arguments, error
        case mcpAppResourceURI = "mcpAppResourceUri"
        case result, server, tool, contentItems, namespace, success, agentsStates, model, prompt, reasoningEffort
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

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// [UNSTABLE] Temporary notification payload for approval auto-review. This shape is
/// expected to change soon.
// MARK: - CodexWireItemGuardianApprovalReviewCompletedNotification
struct CodexWireItemGuardianApprovalReviewCompletedNotification: Codable, Equatable, Sendable {
    let action: CodexWireGuardianApprovalReviewAction
    /// Unix timestamp (in milliseconds) when this review completed.
    let completedAtMS: Int?
    let decisionSource: CodexWireAutoReviewDecisionSource
    let review: CodexWireGuardianApprovalReview
    /// Stable identifier for this review.
    let reviewID: String
    /// Unix timestamp (in milliseconds) when this review started.
    let startedAtMS: Int?
    /// Identifier for the reviewed item or tool call when one exists.
    ///
    /// In most cases, one review maps to one target item. The exceptions are - execve reviews,
    /// where a single command may contain multiple execve calls to review (only possible when
    /// using the shell_zsh_fork feature) - network policy reviews, where there is no target
    /// item
    ///
    /// A network call is triggered by a CommandExecution item, so having a target_item_id set to
    /// the CommandExecution item would be misleading because the review is about the network
    /// call, not the command execution. Therefore, target_item_id is set to None for network
    /// policy reviews.
    let targetItemID: String?
    let threadID, turnID: String

    enum CodingKeys: String, CodingKey {
        case action
        case completedAtMS = "completedAtMs"
        case decisionSource, review
        case reviewID = "reviewId"
        case startedAtMS = "startedAtMs"
        case targetItemID = "targetItemId"
        case threadID = "threadId"
        case turnID = "turnId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireGuardianApprovalReviewAction
struct CodexWireGuardianApprovalReviewAction: Codable, Equatable, Sendable {
    let command, cwd: String?
    let source: CodexWireGuardianCommandSource?
    let type: CodexWireGuardianApprovalReviewActionType
    let argv: [String]?
    let program: String?
    let files: [String]?
    let host: String?
    let port: Int?
    let guardianApprovalReviewActionProtocol: CodexWireNetworkApprovalProtocol?
    let target: String?
    let connectorID, connectorName: String?
    let server, toolName: String?
    let toolTitle: String?
    let permissions: CodexWireRequestPermissionProfile?
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case command, cwd, source, type, argv, program, files, host, port
        case guardianApprovalReviewActionProtocol = "protocol"
        case target
        case connectorID = "connectorId"
        case connectorName, server, toolName, toolTitle, permissions, reason
    }
}

enum CodexWireNetworkApprovalProtocol: String, Codable, Equatable, Sendable {
    case http = "http"
    case https = "https"
    case socks5TCP = "socks5Tcp"
    case socks5UDP = "socks5Udp"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireRequestPermissionProfile
struct CodexWireRequestPermissionProfile: Codable, Equatable, Sendable {
    let fileSystem: CodexWireAdditionalFileSystemPermissions?
    let network: CodexWireAdditionalNetworkPermissions?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireAdditionalFileSystemPermissions
struct CodexWireAdditionalFileSystemPermissions: Codable, Equatable, Sendable {
    let entries: [CodexWireFileSystemSandboxEntry]?
    let globScanMaxDepth: Int?
    /// This will be removed in favor of `entries`.
    let read: [String]?
    /// This will be removed in favor of `entries`.
    let write: [String]?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireFileSystemSandboxEntry
struct CodexWireFileSystemSandboxEntry: Codable, Equatable, Sendable {
    let access: CodexWireFileSystemAccessMode
    let path: CodexWireFileSystemPath
}

enum CodexWireFileSystemAccessMode: String, Codable, Equatable, Sendable {
    case none = "none"
    case read = "read"
    case write = "write"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireFileSystemPath
struct CodexWireFileSystemPath: Codable, Equatable, Sendable {
    let path: String?
    let type: CodexWireFileSystemPathType
    let pattern: String?
    let value: CodexWireFileSystemSpecialPath?
}

enum CodexWireFileSystemPathType: String, Codable, Equatable, Sendable {
    case globPattern = "glob_pattern"
    case path = "path"
    case special = "special"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireFileSystemSpecialPath
struct CodexWireFileSystemSpecialPath: Codable, Equatable, Sendable {
    let kind: CodexWireKind
    let subpath: String?
    let path: String?
}

enum CodexWireKind: String, Codable, Equatable, Sendable {
    case minimal = "minimal"
    case projectRoots = "project_roots"
    case root = "root"
    case slashTmp = "slash_tmp"
    case tmpdir = "tmpdir"
    case unknown = "unknown"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireAdditionalNetworkPermissions
struct CodexWireAdditionalNetworkPermissions: Codable, Equatable, Sendable {
    let enabled: Bool?
}

enum CodexWireGuardianCommandSource: String, Codable, Equatable, Sendable {
    case shell = "shell"
    case unifiedExec = "unifiedExec"
}

enum CodexWireGuardianApprovalReviewActionType: String, Codable, Equatable, Sendable {
    case applyPatch = "applyPatch"
    case command = "command"
    case execve = "execve"
    case mcpToolCall = "mcpToolCall"
    case networkAccess = "networkAccess"
    case requestPermissions = "requestPermissions"
}

/// [UNSTABLE] Source that produced a terminal approval auto-review decision.
enum CodexWireAutoReviewDecisionSource: String, Codable, Equatable, Sendable {
    case agent = "agent"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// [UNSTABLE] Temporary approval auto-review payload used by `item/autoApprovalReview/*`
/// notifications. This shape is expected to change soon.
// MARK: - CodexWireGuardianApprovalReview
struct CodexWireGuardianApprovalReview: Codable, Equatable, Sendable {
    let rationale: String?
    let riskLevel: CodexWireGuardianRiskLevel?
    let status: CodexWireGuardianApprovalReviewStatus
    let userAuthorization: CodexWireGuardianUserAuthorization?
}

/// [UNSTABLE] Risk level assigned by approval auto-review.
enum CodexWireGuardianRiskLevel: String, Codable, Equatable, Sendable {
    case critical = "critical"
    case high = "high"
    case low = "low"
    case medium = "medium"
}

/// [UNSTABLE] Lifecycle state for an approval auto-review.
enum CodexWireGuardianApprovalReviewStatus: String, Codable, Equatable, Sendable {
    case aborted = "aborted"
    case approved = "approved"
    case denied = "denied"
    case inProgress = "inProgress"
    case timedOut = "timedOut"
}

/// [UNSTABLE] Authorization level assigned by approval auto-review.
enum CodexWireGuardianUserAuthorization: String, Codable, Equatable, Sendable {
    case high = "high"
    case low = "low"
    case medium = "medium"
    case unknown = "unknown"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// [UNSTABLE] Temporary notification payload for approval auto-review. This shape is
/// expected to change soon.
// MARK: - CodexWireItemGuardianApprovalReviewStartedNotification
struct CodexWireItemGuardianApprovalReviewStartedNotification: Codable, Equatable, Sendable {
    let action: CodexWireGuardianApprovalReviewAction
    let review: CodexWireGuardianApprovalReview
    /// Stable identifier for this review.
    let reviewID: String
    /// Unix timestamp (in milliseconds) when this review started.
    let startedAtMS: Int?
    /// Identifier for the reviewed item or tool call when one exists.
    ///
    /// In most cases, one review maps to one target item. The exceptions are - execve reviews,
    /// where a single command may contain multiple execve calls to review (only possible when
    /// using the shell_zsh_fork feature) - network policy reviews, where there is no target
    /// item
    ///
    /// A network call is triggered by a CommandExecution item, so having a target_item_id set to
    /// the CommandExecution item would be misleading because the review is about the network
    /// call, not the command execution. Therefore, target_item_id is set to None for network
    /// policy reviews.
    let targetItemID: String?
    let threadID, turnID: String

    enum CodingKeys: String, CodingKey {
        case action, review
        case reviewID = "reviewId"
        case startedAtMS = "startedAtMs"
        case targetItemID = "targetItemId"
        case threadID = "threadId"
        case turnID = "turnId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireItemStartedNotification
struct CodexWireItemStartedNotification: Codable, Equatable, Sendable {
    let item: CodexWireThreadItem
    /// Unix timestamp (in milliseconds) when this item lifecycle started.
    let startedAtMS: Int?
    let threadID, turnID: String

    enum CodingKeys: String, CodingKey {
        case item
        case startedAtMS = "startedAtMs"
        case threadID = "threadId"
        case turnID = "turnId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireListMCPServerStatusParams
struct CodexWireListMCPServerStatusParams: Codable, Equatable, Sendable {
    /// Opaque pagination cursor returned by a previous call.
    let cursor: String?
    /// Controls how much MCP inventory data to fetch for each server. Defaults to `Full` when
    /// omitted.
    let detail: CodexWireMCPServerStatusDetail?
    /// Optional page size; defaults to a server-defined value.
    let limit: Int?
}

enum CodexWireMCPServerStatusDetail: String, Codable, Equatable, Sendable {
    case full = "full"
    case toolsAndAuthOnly = "toolsAndAuthOnly"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireListMCPServerStatusResponse
struct CodexWireListMCPServerStatusResponse: Codable, Equatable, Sendable {
    let data: [CodexWireMCPServerStatus]
    /// Opaque cursor to pass to the next call to continue after the last item. If None, there
    /// are no more items to return.
    let nextCursor: String?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireMCPServerStatus
struct CodexWireMCPServerStatus: Codable, Equatable, Sendable {
    let authStatus: CodexWireMCPAuthStatus
    let name: String
    let resources: [CodexWireResource]
    let resourceTemplates: [CodexWireResourceTemplate]
    let tools: [String: CodexWireTool]
}

enum CodexWireMCPAuthStatus: String, Codable, Equatable, Sendable {
    case bearerToken = "bearerToken"
    case notLoggedIn = "notLoggedIn"
    case oAuth = "oAuth"
    case unsupported = "unsupported"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// A template description for resources available on the server.
// MARK: - CodexWireResourceTemplate
struct CodexWireResourceTemplate: Codable, Equatable, Sendable {
    let annotations: CodexWireJSONValue?
    let description, mimeType: String?
    let name: String
    let title: String?
    let uriTemplate: String
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// A known resource that the server is capable of reading.
// MARK: - CodexWireResource
struct CodexWireResource: Codable, Equatable, Sendable {
    let meta, annotations: CodexWireJSONValue?
    let description: String?
    let icons: [CodexWireJSONValue]?
    let mimeType: String?
    let name: String
    let size: Int?
    let title: String?
    let uri: String

    enum CodingKeys: String, CodingKey {
        case meta = "_meta"
        case annotations, description, icons, mimeType, name, size, title, uri
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Definition for a tool the client can call.
// MARK: - CodexWireTool
struct CodexWireTool: Codable, Equatable, Sendable {
    let meta, annotations: CodexWireJSONValue?
    let description: String?
    let icons: [CodexWireJSONValue]?
    let inputSchema: CodexWireJSONValue
    let name: String
    let outputSchema: CodexWireJSONValue?
    let title: String?

    enum CodingKeys: String, CodingKey {
        case meta = "_meta"
        case annotations, description, icons, inputSchema, name, outputSchema, title
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireMCPResourceReadParams
struct CodexWireMCPResourceReadParams: Codable, Equatable, Sendable {
    let server: String
    let threadID: String?
    let uri: String

    enum CodingKeys: String, CodingKey {
        case server
        case threadID = "threadId"
        case uri
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireMCPResourceReadResponse
struct CodexWireMCPResourceReadResponse: Codable, Equatable, Sendable {
    let contents: [CodexWireResourceContent]
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Contents returned when reading a resource from an MCP server.
// MARK: - CodexWireResourceContent
struct CodexWireResourceContent: Codable, Equatable, Sendable {
    let meta: CodexWireJSONValue?
    let mimeType: String?
    let text: String?
    /// The URI of this resource.
    let uri: String
    let blob: String?

    enum CodingKeys: String, CodingKey {
        case meta = "_meta"
        case mimeType, text, uri, blob
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireMCPServerStatusUpdatedNotification
struct CodexWireMCPServerStatusUpdatedNotification: Codable, Equatable, Sendable {
    let error: String?
    let name: String
    let status: CodexWireMCPServerStartupState
}

enum CodexWireMCPServerStartupState: String, Codable, Equatable, Sendable {
    case cancelled = "cancelled"
    case failed = "failed"
    case ready = "ready"
    case starting = "starting"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireMCPToolCallProgressNotification
struct CodexWireMCPToolCallProgressNotification: Codable, Equatable, Sendable {
    let itemID, message, threadID, turnID: String

    enum CodingKeys: String, CodingKey {
        case itemID = "itemId"
        case message
        case threadID = "threadId"
        case turnID = "turnId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireModelListParams
struct CodexWireModelListParams: Codable, Equatable, Sendable {
    /// Opaque pagination cursor returned by a previous call.
    let cursor: String?
    /// When true, include models that are hidden from the default picker list.
    let includeHidden: Bool?
    /// Optional page size; defaults to a reasonable server-side value.
    let limit: Int?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireModelListResponse
struct CodexWireModelListResponse: Codable, Equatable, Sendable {
    let data: [CodexWireModel]
    /// Opaque cursor to pass to the next call to continue after the last item. If None, there
    /// are no more items to return.
    let nextCursor: String?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireModel
struct CodexWireModel: Codable, Equatable, Sendable {
    /// Deprecated: use `serviceTiers` instead.
    let additionalSpeedTiers: [String]?
    let availabilityNux: CodexWireModelAvailabilityNux?
    let defaultReasoningEffort: CodexWireReasoningEffort
    let description, displayName: String
    let hidden: Bool
    let id: String
    let inputModalities: [CodexWireInputModality]?
    let isDefault: Bool
    let model: String
    let serviceTiers: [CodexWireModelServiceTier]?
    let supportedReasoningEfforts: [CodexWireReasoningEffortOption]
    let supportsPersonality: Bool?
    let upgrade: String?
    let upgradeInfo: CodexWireModelUpgradeInfo?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireModelAvailabilityNux
struct CodexWireModelAvailabilityNux: Codable, Equatable, Sendable {
    let message: String
}

/// Canonical user-input modality tags advertised by a model.
///
/// Plain text turns and tool payloads.
///
/// Image attachments included in user turns.
enum CodexWireInputModality: String, Codable, Equatable, Sendable {
    case image = "image"
    case text = "text"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireModelServiceTier
struct CodexWireModelServiceTier: Codable, Equatable, Sendable {
    let description, id, name: String
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireReasoningEffortOption
struct CodexWireReasoningEffortOption: Codable, Equatable, Sendable {
    let description: String
    let reasoningEffort: CodexWireReasoningEffort
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireModelUpgradeInfo
struct CodexWireModelUpgradeInfo: Codable, Equatable, Sendable {
    let migrationMarkdown: String?
    let model: String
    let modelLink, upgradeCopy: String?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireModelReroutedNotification
struct CodexWireModelReroutedNotification: Codable, Equatable, Sendable {
    let fromModel: String
    let reason: CodexWireModelRerouteReason
    let threadID, toModel, turnID: String

    enum CodingKeys: String, CodingKey {
        case fromModel, reason
        case threadID = "threadId"
        case toModel
        case turnID = "turnId"
    }
}

enum CodexWireModelRerouteReason: String, Codable, Equatable, Sendable {
    case highRiskCyberActivity = "highRiskCyberActivity"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireModelVerificationNotification
struct CodexWireModelVerificationNotification: Codable, Equatable, Sendable {
    let threadID, turnID: String
    let verifications: [CodexWireModelVerification]

    enum CodingKeys: String, CodingKey {
        case threadID = "threadId"
        case turnID = "turnId"
        case verifications
    }
}

enum CodexWireModelVerification: String, Codable, Equatable, Sendable {
    case trustedAccessForCyber = "trustedAccessForCyber"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// EXPERIMENTAL - proposed plan streaming deltas for plan items. Clients should not assume
/// concatenated deltas match the completed plan item content.
// MARK: - CodexWirePlanDeltaNotification
struct CodexWirePlanDeltaNotification: Codable, Equatable, Sendable {
    let delta, itemID, threadID, turnID: String

    enum CodingKeys: String, CodingKey {
        case delta
        case itemID = "itemId"
        case threadID = "threadId"
        case turnID = "turnId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWirePluginListParams
struct CodexWirePluginListParams: Codable, Equatable, Sendable {
    /// Optional working directories used to discover repo marketplaces. When omitted, only
    /// home-scoped marketplaces and the official curated marketplace are considered.
    let cwds: [String]?
    /// Optional marketplace kind filter. When omitted, only local marketplaces are queried, plus
    /// the default remote catalog when enabled by feature flag.
    let marketplaceKinds: [CodexWirePluginListMarketplaceKind]?
}

enum CodexWirePluginListMarketplaceKind: String, Codable, Equatable, Sendable {
    case local = "local"
    case sharedWithMe = "shared-with-me"
    case workspaceDirectory = "workspace-directory"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWirePluginListResponse
struct CodexWirePluginListResponse: Codable, Equatable, Sendable {
    let featuredPluginIDS: [String]?
    let marketplaceLoadErrors: [CodexWireMarketplaceLoadErrorInfo]?
    let marketplaces: [CodexWirePluginMarketplaceEntry]

    enum CodingKeys: String, CodingKey {
        case featuredPluginIDS = "featuredPluginIds"
        case marketplaceLoadErrors, marketplaces
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireMarketplaceLoadErrorInfo
struct CodexWireMarketplaceLoadErrorInfo: Codable, Equatable, Sendable {
    let marketplacePath, message: String
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWirePluginMarketplaceEntry
struct CodexWirePluginMarketplaceEntry: Codable, Equatable, Sendable {
    let interface: CodexWireMarketplaceInterface?
    let name: String
    /// Local marketplace file path when the marketplace is backed by a local file. Remote-only
    /// catalog marketplaces do not have a local path.
    let path: String?
    let plugins: [CodexWirePluginSummary]
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireMarketplaceInterface
struct CodexWireMarketplaceInterface: Codable, Equatable, Sendable {
    let displayName: String?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWirePluginSummary
struct CodexWirePluginSummary: Codable, Equatable, Sendable {
    let authPolicy: CodexWirePluginAuthPolicy
    /// Availability state for installing and using the plugin.
    let availability: CodexWirePluginAvailability?
    let enabled: Bool
    let id: String
    let installed: Bool
    let installPolicy: CodexWirePluginInstallPolicy
    let interface: CodexWirePluginInterface?
    let keywords: [String]?
    let name: String
    /// Remote sharing context associated with this plugin when available.
    let shareContext: CodexWirePluginShareContext?
    let source: CodexWirePluginSource
}

enum CodexWirePluginAuthPolicy: String, Codable, Equatable, Sendable {
    case onInstall = "ON_INSTALL"
    case onUse = "ON_USE"
}

/// Availability state for installing and using the plugin.
///
/// Plugin-service currently sends `"ENABLED"` for available remote plugins. Codex app-server
/// exposes `"AVAILABLE"` in its API; the alias keeps decoding compatible with that upstream
/// response.
enum CodexWirePluginAvailability: String, Codable, Equatable, Sendable {
    case available = "AVAILABLE"
    case disabledByAdmin = "DISABLED_BY_ADMIN"
}

enum CodexWirePluginInstallPolicy: String, Codable, Equatable, Sendable {
    case available = "AVAILABLE"
    case installedByDefault = "INSTALLED_BY_DEFAULT"
    case notAvailable = "NOT_AVAILABLE"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWirePluginInterface
struct CodexWirePluginInterface: Codable, Equatable, Sendable {
    let brandColor: String?
    let capabilities: [String]
    let category: String?
    /// Local composer icon path, resolved from the installed plugin package.
    let composerIcon: String?
    /// Remote composer icon URL from the plugin catalog.
    let composerIconURL: String?
    /// Starter prompts for the plugin. Capped at 3 entries with a maximum of 128 characters per
    /// entry.
    let defaultPrompt: [String]?
    let developerName, displayName: String?
    /// Local logo path, resolved from the installed plugin package.
    let logo: String?
    /// Remote logo URL from the plugin catalog.
    let logoURL: String?
    let longDescription, privacyPolicyURL: String?
    /// Local screenshot paths, resolved from the installed plugin package.
    let screenshots: [String]
    /// Remote screenshot URLs from the plugin catalog.
    let screenshotUrls: [String]
    let shortDescription, termsOfServiceURL, websiteURL: String?

    enum CodingKeys: String, CodingKey {
        case brandColor, capabilities, category, composerIcon
        case composerIconURL = "composerIconUrl"
        case defaultPrompt, developerName, displayName, logo
        case logoURL = "logoUrl"
        case longDescription
        case privacyPolicyURL = "privacyPolicyUrl"
        case screenshots, screenshotUrls, shortDescription
        case termsOfServiceURL = "termsOfServiceUrl"
        case websiteURL = "websiteUrl"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWirePluginShareContext
struct CodexWirePluginShareContext: Codable, Equatable, Sendable {
    let creatorAccountUserID, creatorName: String?
    let remotePluginID: String
    let shareTargets: [CodexWirePluginSharePrincipal]?
    let shareURL: String?

    enum CodingKeys: String, CodingKey {
        case creatorAccountUserID = "creatorAccountUserId"
        case creatorName
        case remotePluginID = "remotePluginId"
        case shareTargets
        case shareURL = "shareUrl"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWirePluginSharePrincipal
struct CodexWirePluginSharePrincipal: Codable, Equatable, Sendable {
    let name, principalID: String
    let principalType: CodexWirePluginSharePrincipalType

    enum CodingKeys: String, CodingKey {
        case name
        case principalID = "principalId"
        case principalType
    }
}

enum CodexWirePluginSharePrincipalType: String, Codable, Equatable, Sendable {
    case group = "group"
    case user = "user"
    case workspace = "workspace"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// The plugin is available in the remote catalog. Download metadata is kept server-side and
/// is not exposed through the app-server API.
// MARK: - CodexWirePluginSource
struct CodexWirePluginSource: Codable, Equatable, Sendable {
    let path: String?
    let type: CodexWirePluginSourceType
    let refName, sha: String?
    let url: String?
}

enum CodexWirePluginSourceType: String, Codable, Equatable, Sendable {
    case git = "git"
    case local = "local"
    case remote = "remote"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWirePluginReadParams
struct CodexWirePluginReadParams: Codable, Equatable, Sendable {
    let marketplacePath: String?
    let pluginName: String
    let remoteMarketplaceName: String?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWirePluginReadResponse
struct CodexWirePluginReadResponse: Codable, Equatable, Sendable {
    let plugin: CodexWirePluginDetail
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWirePluginDetail
struct CodexWirePluginDetail: Codable, Equatable, Sendable {
    let apps: [CodexWireAppSummary]
    let description: String?
    let hooks: [CodexWirePluginHookSummary]
    let marketplaceName: String
    let marketplacePath: String?
    let mcpServers: [String]
    let skills: [CodexWireSkillSummary]
    let summary: CodexWirePluginSummary
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// EXPERIMENTAL - app metadata summary for plugin responses.
// MARK: - CodexWireAppSummary
struct CodexWireAppSummary: Codable, Equatable, Sendable {
    let description: String?
    let id: String
    let installURL: String?
    let name: String
    let needsAuth: Bool

    enum CodingKeys: String, CodingKey {
        case description, id
        case installURL = "installUrl"
        case name, needsAuth
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWirePluginHookSummary
struct CodexWirePluginHookSummary: Codable, Equatable, Sendable {
    let eventName: CodexWireHookEventName
    let key: String
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireSkillSummary
struct CodexWireSkillSummary: Codable, Equatable, Sendable {
    let description: String
    let enabled: Bool
    let interface: CodexWireSkillInterface?
    let name: String
    let path, shortDescription: String?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireSkillInterface
struct CodexWireSkillInterface: Codable, Equatable, Sendable {
    let brandColor, defaultPrompt, displayName, iconLarge: String?
    let iconSmall, shortDescription: String?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWirePluginShareDeleteParams
struct CodexWirePluginShareDeleteParams: Codable, Equatable, Sendable {
    let remotePluginID: String

    enum CodingKeys: String, CodingKey {
        case remotePluginID = "remotePluginId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWirePluginShareListResponse
struct CodexWirePluginShareListResponse: Codable, Equatable, Sendable {
    let data: [CodexWirePluginShareListItem]
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWirePluginShareListItem
struct CodexWirePluginShareListItem: Codable, Equatable, Sendable {
    let localPluginPath: String?
    let plugin: CodexWirePluginSummary
    let shareURL: String

    enum CodingKeys: String, CodingKey {
        case localPluginPath, plugin
        case shareURL = "shareUrl"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWirePluginShareSaveParams
struct CodexWirePluginShareSaveParams: Codable, Equatable, Sendable {
    let discoverability: CodexWirePluginShareDiscoverability?
    let pluginPath: String
    let remotePluginID: String?
    let shareTargets: [CodexWirePluginShareTarget]?

    enum CodingKeys: String, CodingKey {
        case discoverability, pluginPath
        case remotePluginID = "remotePluginId"
        case shareTargets
    }
}

enum CodexWirePluginShareDiscoverability: String, Codable, Equatable, Sendable {
    case listed = "LISTED"
    case pluginShareDiscoverabilityPRIVATE = "PRIVATE"
    case unlisted = "UNLISTED"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWirePluginShareTarget
struct CodexWirePluginShareTarget: Codable, Equatable, Sendable {
    let principalID: String
    let principalType: CodexWirePluginSharePrincipalType

    enum CodingKeys: String, CodingKey {
        case principalID = "principalId"
        case principalType
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWirePluginShareSaveResponse
struct CodexWirePluginShareSaveResponse: Codable, Equatable, Sendable {
    let remotePluginID, shareURL: String

    enum CodingKeys: String, CodingKey {
        case remotePluginID = "remotePluginId"
        case shareURL = "shareUrl"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWirePluginShareUpdateTargetsParams
struct CodexWirePluginShareUpdateTargetsParams: Codable, Equatable, Sendable {
    let discoverability: CodexWirePluginShareUpdateDiscoverability
    let remotePluginID: String
    let shareTargets: [CodexWirePluginShareTarget]

    enum CodingKeys: String, CodingKey {
        case discoverability
        case remotePluginID = "remotePluginId"
        case shareTargets
    }
}

enum CodexWirePluginShareUpdateDiscoverability: String, Codable, Equatable, Sendable {
    case pluginShareUpdateDiscoverabilityPRIVATE = "PRIVATE"
    case unlisted = "UNLISTED"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWirePluginShareUpdateTargetsResponse
struct CodexWirePluginShareUpdateTargetsResponse: Codable, Equatable, Sendable {
    let discoverability: CodexWirePluginShareDiscoverability
    let principals: [CodexWirePluginSharePrincipal]
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWirePluginSkillReadParams
struct CodexWirePluginSkillReadParams: Codable, Equatable, Sendable {
    let remoteMarketplaceName, remotePluginID, skillName: String

    enum CodingKeys: String, CodingKey {
        case remoteMarketplaceName
        case remotePluginID = "remotePluginId"
        case skillName
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWirePluginSkillReadResponse
struct CodexWirePluginSkillReadResponse: Codable, Equatable, Sendable {
    let contents: String?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Final process exit notification for `process/spawn`.
// MARK: - CodexWireProcessExitedNotification
struct CodexWireProcessExitedNotification: Codable, Equatable, Sendable {
    /// Process exit code.
    let exitCode: Int
    /// Client-supplied, connection-scoped `processHandle` from `process/spawn`.
    let processHandle: String
    /// Buffered stderr capture.
    ///
    /// Empty when stderr was streamed via `process/outputDelta`.
    let stderr: String
    /// Whether stderr reached `outputBytesCap`.
    ///
    /// In streaming mode, stderr is empty and cap state is also reported on the final stderr
    /// `process/outputDelta` notification.
    let stderrCapReached: Bool
    /// Buffered stdout capture.
    ///
    /// Empty when stdout was streamed via `process/outputDelta`.
    let stdout: String
    /// Whether stdout reached `outputBytesCap`.
    ///
    /// In streaming mode, stdout is empty and cap state is also reported on the final stdout
    /// `process/outputDelta` notification.
    let stdoutCapReached: Bool
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Terminate a running `process/spawn` session.
// MARK: - CodexWireProcessKillParams
struct CodexWireProcessKillParams: Codable, Equatable, Sendable {
    /// Client-supplied, connection-scoped `processHandle` from `process/spawn`.
    let processHandle: String
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Base64-encoded output chunk emitted for a streaming `process/spawn` request.
// MARK: - CodexWireProcessOutputDeltaNotification
struct CodexWireProcessOutputDeltaNotification: Codable, Equatable, Sendable {
    /// True on the final streamed chunk for this stream when output was truncated by
    /// `outputBytesCap`.
    let capReached: Bool
    /// Base64-encoded output bytes.
    let deltaBase64: String
    /// Client-supplied, connection-scoped `processHandle` from `process/spawn`.
    let processHandle: String
    /// Output stream this chunk belongs to.
    let stream: CodexWireOutputStream
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Resize a running PTY-backed `process/spawn` session.
// MARK: - CodexWireProcessResizePtyParams
struct CodexWireProcessResizePtyParams: Codable, Equatable, Sendable {
    /// Client-supplied, connection-scoped `processHandle` from `process/spawn`.
    let processHandle: String
    /// New PTY size in character cells.
    let size: CodexWireProcessTerminalSize
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// New PTY size in character cells.
///
/// PTY size in character cells for `process/spawn` PTY sessions.
// MARK: - CodexWireProcessTerminalSize
struct CodexWireProcessTerminalSize: Codable, Equatable, Sendable {
    /// Terminal width in character cells.
    let cols: Int
    /// Terminal height in character cells.
    let rows: Int
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Spawn a standalone process (argv vector) without a Codex sandbox on the host where the
/// app server is running.
///
/// `process/spawn` returns after the process has started and the connection-scoped
/// `processHandle` has been registered. Process output and exit are reported via
/// `process/outputDelta` and `process/exited` notifications.
// MARK: - CodexWireProcessSpawnParams
struct CodexWireProcessSpawnParams: Codable, Equatable, Sendable {
    /// Command argv vector. Empty arrays are rejected.
    let command: [String]
    /// Absolute working directory for the process.
    let cwd: String
    /// Optional environment overrides merged into the app-server process environment.
    ///
    /// Matching names override inherited values. Set a key to `null` to unset an inherited
    /// variable.
    let env: [String: String?]?
    /// Optional per-stream stdout/stderr capture cap in bytes.
    ///
    /// When omitted, the server default applies. Set to `null` to disable the cap.
    let outputBytesCap: Int?
    /// Client-supplied, connection-scoped process handle.
    ///
    /// Duplicate active handles are rejected on the same connection. The same handle can be
    /// reused after the prior process exits.
    let processHandle: String
    /// Optional initial PTY size in character cells. Only valid when `tty` is true.
    let size: CodexWireProcessTerminalSize?
    /// Allow follow-up `process/writeStdin` requests to write stdin bytes.
    let streamStdin: Bool?
    /// Stream stdout/stderr via `process/outputDelta` notifications.
    ///
    /// Streamed bytes are not duplicated into the `process/exited` notification.
    let streamStdoutStderr: Bool?
    /// Optional timeout in milliseconds.
    ///
    /// When omitted, the server default applies. Set to `null` to disable the timeout.
    let timeoutMS: Int?
    /// Enable PTY mode.
    ///
    /// This implies `streamStdin` and `streamStdoutStderr`.
    let tty: Bool?

    enum CodingKeys: String, CodingKey {
        case command, cwd, env, outputBytesCap, processHandle, size, streamStdin, streamStdoutStderr
        case timeoutMS = "timeoutMs"
        case tty
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Write stdin bytes to a running `process/spawn` session, close stdin, or both.
// MARK: - CodexWireProcessWriteStdinParams
struct CodexWireProcessWriteStdinParams: Codable, Equatable, Sendable {
    /// Close stdin after writing `deltaBase64`, if present.
    let closeStdin: Bool?
    /// Optional base64-encoded stdin bytes to write.
    let deltaBase64: String?
    /// Client-supplied, connection-scoped `processHandle` from `process/spawn`.
    let processHandle: String
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireRawResponseItemCompletedNotification
struct CodexWireRawResponseItemCompletedNotification: Codable, Equatable, Sendable {
    let item: CodexWireResponseItem
    let threadID, turnID: String

    enum CodingKeys: String, CodingKey {
        case item
        case threadID = "threadId"
        case turnID = "turnId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireResponseItem
struct CodexWireResponseItem: Codable, Equatable, Sendable {
    let content: [CodexWireContentItem]?
    /// Legacy id field retained for compatibility with older payloads.
    let id: String?
    let phase: CodexWireMessagePhase?
    let role: String?
    let type: CodexWireResponseItemType
    let encryptedContent: String?
    let summary: [CodexWireReasoningItemReasoningSummary]?
    let action: CodexWireResponsesAPIWebSearchAction?
    /// Set when using the Responses API.
    let callID: String?
    let status: String?
    let arguments: CodexWireJSONValue?
    let name, namespace: String?
    let execution: String?
    let output: CodexWireFunctionCallOutputBody?
    let input: String?
    let tools: [CodexWireJSONValue]?
    let result: String?
    let revisedPrompt: String?

    enum CodingKeys: String, CodingKey {
        case content, id, phase, role, type
        case encryptedContent = "encrypted_content"
        case summary, action
        case callID = "call_id"
        case status, arguments, name, namespace, execution, output, input, tools, result
        case revisedPrompt = "revised_prompt"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireResponsesAPIWebSearchAction
struct CodexWireResponsesAPIWebSearchAction: Codable, Equatable, Sendable {
    let command: [String]?
    let env: [String: String]?
    let timeoutMS: Int?
    let type: CodexWireExecLocalShellActionType
    let user, workingDirectory: String?
    let queries: [String]?
    let query, url, pattern: String?

    enum CodingKeys: String, CodingKey {
        case command, env
        case timeoutMS = "timeout_ms"
        case type, user
        case workingDirectory = "working_directory"
        case queries, query, url, pattern
    }
}

enum CodexWireExecLocalShellActionType: String, Codable, Equatable, Sendable {
    case exec = "exec"
    case findInPage = "find_in_page"
    case openPage = "open_page"
    case other = "other"
    case search = "search"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireContentItem
struct CodexWireContentItem: Codable, Equatable, Sendable {
    let text: String?
    let type: CodexWireType
    let detail: CodexWireImageDetail?
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case text, type, detail
        case imageURL = "image_url"
    }
}

enum CodexWireImageDetail: String, Codable, Equatable, Sendable {
    case auto = "auto"
    case high = "high"
    case low = "low"
    case original = "original"
}

enum CodexWireType: String, Codable, Equatable, Sendable {
    case inputImage = "input_image"
    case inputText = "input_text"
    case outputText = "output_text"
    case reasoningText = "reasoning_text"
    case text = "text"
}

enum CodexWireFunctionCallOutputBody: Codable, Equatable, Sendable {
    case codexWireFunctionCallOutputContentItemArray([CodexWireFunctionCallOutputContentItem])
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode([CodexWireFunctionCallOutputContentItem].self) {
            self = .codexWireFunctionCallOutputContentItemArray(x)
            return
        }
        if let x = try? container.decode(String.self) {
            self = .string(x)
            return
        }
        throw DecodingError.typeMismatch(CodexWireFunctionCallOutputBody.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for CodexWireFunctionCallOutputBody"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .codexWireFunctionCallOutputContentItemArray(let x):
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

/// Responses API compatible content items that can be returned by a tool call. This is a
/// subset of ContentItem with the types we support as function call outputs.
// MARK: - CodexWireFunctionCallOutputContentItem
struct CodexWireFunctionCallOutputContentItem: Codable, Equatable, Sendable {
    let text: String?
    let type: CodexWireInputFunctionCallOutputContentItemType
    let detail: CodexWireImageDetail?
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case text, type, detail
        case imageURL = "image_url"
    }
}

enum CodexWireInputFunctionCallOutputContentItemType: String, Codable, Equatable, Sendable {
    case inputImage = "input_image"
    case inputText = "input_text"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireReasoningItemReasoningSummary
struct CodexWireReasoningItemReasoningSummary: Codable, Equatable, Sendable {
    let text: String
    let type: CodexWireSummaryTextReasoningItemReasoningSummaryType
}

enum CodexWireSummaryTextReasoningItemReasoningSummaryType: String, Codable, Equatable, Sendable {
    case summaryText = "summary_text"
}

enum CodexWireResponseItemType: String, Codable, Equatable, Sendable {
    case compaction = "compaction"
    case contextCompaction = "context_compaction"
    case customToolCall = "custom_tool_call"
    case customToolCallOutput = "custom_tool_call_output"
    case functionCall = "function_call"
    case functionCallOutput = "function_call_output"
    case imageGenerationCall = "image_generation_call"
    case localShellCall = "local_shell_call"
    case message = "message"
    case other = "other"
    case reasoning = "reasoning"
    case toolSearchCall = "tool_search_call"
    case toolSearchOutput = "tool_search_output"
    case webSearchCall = "web_search_call"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireReasoningSummaryPartAddedNotification
struct CodexWireReasoningSummaryPartAddedNotification: Codable, Equatable, Sendable {
    let itemID: String
    let summaryIndex: Int
    let threadID, turnID: String

    enum CodingKeys: String, CodingKey {
        case itemID = "itemId"
        case summaryIndex
        case threadID = "threadId"
        case turnID = "turnId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireReasoningSummaryTextDeltaNotification
struct CodexWireReasoningSummaryTextDeltaNotification: Codable, Equatable, Sendable {
    let delta, itemID: String
    let summaryIndex: Int
    let threadID, turnID: String

    enum CodingKeys: String, CodingKey {
        case delta
        case itemID = "itemId"
        case summaryIndex
        case threadID = "threadId"
        case turnID = "turnId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireReasoningTextDeltaNotification
struct CodexWireReasoningTextDeltaNotification: Codable, Equatable, Sendable {
    let contentIndex: Int
    let delta, itemID, threadID, turnID: String

    enum CodingKeys: String, CodingKey {
        case contentIndex, delta
        case itemID = "itemId"
        case threadID = "threadId"
        case turnID = "turnId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Current remote-control connection status and environment id exposed to clients.
// MARK: - CodexWireRemoteControlStatusChangedNotification
struct CodexWireRemoteControlStatusChangedNotification: Codable, Equatable, Sendable {
    let environmentID: String?
    let status: CodexWireRemoteControlConnectionStatus

    enum CodingKeys: String, CodingKey {
        case environmentID = "environmentId"
        case status
    }
}

enum CodexWireRemoteControlConnectionStatus: String, Codable, Equatable, Sendable {
    case connected = "connected"
    case connecting = "connecting"
    case disabled = "disabled"
    case errored = "errored"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireServerRequestResolvedNotification
struct CodexWireServerRequestResolvedNotification: Codable, Equatable, Sendable {
    let requestID: CodexWireRequestID
    let threadID: String

    enum CodingKeys: String, CodingKey {
        case requestID = "requestId"
        case threadID = "threadId"
    }
}

enum CodexWireRequestID: Codable, Equatable, Sendable {
    case integer(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(Int.self) {
            self = .integer(x)
            return
        }
        if let x = try? container.decode(String.self) {
            self = .string(x)
            return
        }
        throw DecodingError.typeMismatch(CodexWireRequestID.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for CodexWireRequestID"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .integer(let x):
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

// MARK: - CodexWireSkillsListParams
struct CodexWireSkillsListParams: Codable, Equatable, Sendable {
    /// When empty, defaults to the current session working directory.
    let cwds: [String]?
    /// When true, bypass the skills cache and re-scan skills from disk.
    let forceReload: Bool?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireSkillsListResponse
struct CodexWireSkillsListResponse: Codable, Equatable, Sendable {
    let data: [CodexWireSkillsListEntry]
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireSkillsListEntry
struct CodexWireSkillsListEntry: Codable, Equatable, Sendable {
    let cwd: String
    let errors: [CodexWireSkillErrorInfo]
    let skills: [CodexWireSkillMetadata]
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireSkillErrorInfo
struct CodexWireSkillErrorInfo: Codable, Equatable, Sendable {
    let message, path: String
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireSkillMetadata
struct CodexWireSkillMetadata: Codable, Equatable, Sendable {
    let dependencies: CodexWireSkillDependencies?
    let description: String
    let enabled: Bool
    let interface: CodexWireSkillInterface?
    let name, path: String
    let scope: CodexWireSkillScope
    /// Legacy short_description from SKILL.md. Prefer SKILL.json interface.short_description.
    let shortDescription: String?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireSkillDependencies
struct CodexWireSkillDependencies: Codable, Equatable, Sendable {
    let tools: [CodexWireSkillToolDependency]
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireSkillToolDependency
struct CodexWireSkillToolDependency: Codable, Equatable, Sendable {
    let command, description, transport: String?
    let type: String
    let url: String?
    let value: String
}

enum CodexWireSkillScope: String, Codable, Equatable, Sendable {
    case admin = "admin"
    case repo = "repo"
    case system = "system"
    case user = "user"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadApproveGuardianDeniedActionParams
struct CodexWireThreadApproveGuardianDeniedActionParams: Codable, Equatable, Sendable {
    /// Serialized `codex_protocol::protocol::GuardianAssessmentEvent`.
    let event: CodexWireJSONValue
    let threadID: String

    enum CodingKeys: String, CodingKey {
        case event
        case threadID = "threadId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadArchiveParams
struct CodexWireThreadArchiveParams: Codable, Equatable, Sendable {
    let threadID: String

    enum CodingKeys: String, CodingKey {
        case threadID = "threadId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadArchivedNotification
struct CodexWireThreadArchivedNotification: Codable, Equatable, Sendable {
    let threadID: String

    enum CodingKeys: String, CodingKey {
        case threadID = "threadId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadClosedNotification
struct CodexWireThreadClosedNotification: Codable, Equatable, Sendable {
    let threadID: String

    enum CodingKeys: String, CodingKey {
        case threadID = "threadId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadCompactStartParams
struct CodexWireThreadCompactStartParams: Codable, Equatable, Sendable {
    let threadID: String

    enum CodingKeys: String, CodingKey {
        case threadID = "threadId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadGoalClearParams
struct CodexWireThreadGoalClearParams: Codable, Equatable, Sendable {
    let threadID: String

    enum CodingKeys: String, CodingKey {
        case threadID = "threadId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadGoalClearResponse
struct CodexWireThreadGoalClearResponse: Codable, Equatable, Sendable {
    let cleared: Bool
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadGoalClearedNotification
struct CodexWireThreadGoalClearedNotification: Codable, Equatable, Sendable {
    let threadID: String

    enum CodingKeys: String, CodingKey {
        case threadID = "threadId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadGoalGetParams
struct CodexWireThreadGoalGetParams: Codable, Equatable, Sendable {
    let threadID: String

    enum CodingKeys: String, CodingKey {
        case threadID = "threadId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadGoalGetResponse
struct CodexWireThreadGoalGetResponse: Codable, Equatable, Sendable {
    let goal: CodexWireThreadGoal?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadGoal
struct CodexWireThreadGoal: Codable, Equatable, Sendable {
    let createdAt: Int
    let objective: String
    let status: CodexWireThreadGoalStatus
    let threadID: String
    let timeUsedSeconds: Int
    let tokenBudget: Int?
    let tokensUsed, updatedAt: Int

    enum CodingKeys: String, CodingKey {
        case createdAt, objective, status
        case threadID = "threadId"
        case timeUsedSeconds, tokenBudget, tokensUsed, updatedAt
    }
}

enum CodexWireThreadGoalStatus: String, Codable, Equatable, Sendable {
    case active = "active"
    case budgetLimited = "budgetLimited"
    case complete = "complete"
    case paused = "paused"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadGoalSetParams
struct CodexWireThreadGoalSetParams: Codable, Equatable, Sendable {
    let objective: String?
    let status: CodexWireThreadGoalStatus?
    let threadID: String
    let tokenBudget: Int?

    enum CodingKeys: String, CodingKey {
        case objective, status
        case threadID = "threadId"
        case tokenBudget
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadGoalSetResponse
struct CodexWireThreadGoalSetResponse: Codable, Equatable, Sendable {
    let goal: CodexWireThreadGoal
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadGoalUpdatedNotification
struct CodexWireThreadGoalUpdatedNotification: Codable, Equatable, Sendable {
    let goal: CodexWireThreadGoal
    let threadID: String
    let turnID: String?

    enum CodingKeys: String, CodingKey {
        case goal
        case threadID = "threadId"
        case turnID = "turnId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadLoadedListParams
struct CodexWireThreadLoadedListParams: Codable, Equatable, Sendable {
    /// Opaque pagination cursor returned by a previous call.
    let cursor: String?
    /// Optional page size; defaults to no limit.
    let limit: Int?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadLoadedListResponse
struct CodexWireThreadLoadedListResponse: Codable, Equatable, Sendable {
    /// Thread ids for sessions currently loaded in memory.
    let data: [String]
    /// Opaque cursor to pass to the next call to continue after the last item. if None, there
    /// are no more items to return.
    let nextCursor: String?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadMetadataUpdateParams
struct CodexWireThreadMetadataUpdateParams: Codable, Equatable, Sendable {
    /// Patch the stored Git metadata for this thread. Omit a field to leave it unchanged, set it
    /// to `null` to clear it, or provide a string to replace the stored value.
    let gitInfo: CodexWireThreadMetadataGitInfoUpdateParams?
    let threadID: String

    enum CodingKeys: String, CodingKey {
        case gitInfo
        case threadID = "threadId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadMetadataGitInfoUpdateParams
struct CodexWireThreadMetadataGitInfoUpdateParams: Codable, Equatable, Sendable {
    /// Omit to leave the stored branch unchanged, set to `null` to clear it, or provide a
    /// non-empty string to replace it.
    let branch: String?
    /// Omit to leave the stored origin URL unchanged, set to `null` to clear it, or provide a
    /// non-empty string to replace it.
    let originURL: String?
    /// Omit to leave the stored commit unchanged, set to `null` to clear it, or provide a
    /// non-empty string to replace it.
    let sha: String?

    enum CodingKeys: String, CodingKey {
        case branch
        case originURL = "originUrl"
        case sha
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadMetadataUpdateResponse
struct CodexWireThreadMetadataUpdateResponse: Codable, Equatable, Sendable {
    let thread: CodexWireThread
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// The updated thread after applying the rollback, with `turns` populated.
///
/// The ThreadItems stored in each Turn are lossy since we explicitly do not persist all
/// agent interactions, such as command executions. This is the same behavior as
/// `thread/resume`.
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
    /// Session id shared by threads that belong to the same session tree.
    let sessionID: String?
    /// Origin of the thread (CLI, VSCode, codex exec, codex app-server, etc.).
    let source: CodexWireSessionSourceUnion
    /// Current runtime status for the thread.
    let status: CodexWireThreadStatus
    /// Optional analytics source classification for this thread.
    let threadSource: CodexWireThreadSource?
    /// Only populated on `thread/resume`, `thread/rollback`, `thread/fork`, and `thread/read`
    /// (when `includeTurns` is true) responses. For all other responses and notifications
    /// returning a Thread, the turns field will be an empty list.
    let turns: [CodexWireTurn]
    /// Unix timestamp (in seconds) when the thread was last updated.
    let updatedAt: Int

    enum CodingKeys: String, CodingKey {
        case agentNickname, agentRole, cliVersion, createdAt, cwd, ephemeral
        case forkedFromID = "forkedFromId"
        case gitInfo, id, modelProvider, name, path, preview
        case sessionID = "sessionId"
        case source, status, threadSource, turns, updatedAt
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

enum CodexWireThreadSource: String, Codable, Equatable, Sendable {
    case memoryConsolidation = "memory_consolidation"
    case subagent = "subagent"
    case user = "user"
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
    /// Thread items currently included in this turn payload.
    let items: [CodexWireThreadItem]
    /// Describes how much of `items` has been loaded for this turn.
    let itemsView: CodexWireTurnItemsView?
    /// Unix timestamp (in seconds) when the turn started.
    let startedAt: Int?
    let status: CodexWireTurnStatus

    enum CodingKeys: String, CodingKey {
        case completedAt
        case durationMS = "durationMs"
        case error, id, items, itemsView, startedAt, status
    }
}

/// Describes how much of `items` has been loaded for this turn.
///
/// `items` was not loaded for this turn. The field is intentionally empty.
///
/// `items` contains only a display summary for this turn.
///
/// `items` contains every ThreadItem available from persisted app-server history for this
/// turn.
enum CodexWireTurnItemsView: String, Codable, Equatable, Sendable {
    case full = "full"
    case notLoaded = "notLoaded"
    case summary = "summary"
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

// MARK: - CodexWireThreadNameUpdatedNotification
struct CodexWireThreadNameUpdatedNotification: Codable, Equatable, Sendable {
    let threadID: String
    let threadName: String?

    enum CodingKeys: String, CodingKey {
        case threadID = "threadId"
        case threadName
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadRollbackParams
struct CodexWireThreadRollbackParams: Codable, Equatable, Sendable {
    /// The number of turns to drop from the end of the thread. Must be >= 1.
    ///
    /// This only modifies the thread's history and does not revert local file changes that have
    /// been made by the agent. Clients are responsible for reverting these changes.
    let numTurns: Int
    let threadID: String

    enum CodingKeys: String, CodingKey {
        case numTurns
        case threadID = "threadId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadRollbackResponse
struct CodexWireThreadRollbackResponse: Codable, Equatable, Sendable {
    /// The updated thread after applying the rollback, with `turns` populated.
    ///
    /// The ThreadItems stored in each Turn are lossy since we explicitly do not persist all
    /// agent interactions, such as command executions. This is the same behavior as
    /// `thread/resume`.
    let thread: CodexWireThread
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadSetNameParams
struct CodexWireThreadSetNameParams: Codable, Equatable, Sendable {
    let name, threadID: String

    enum CodingKeys: String, CodingKey {
        case name
        case threadID = "threadId"
    }
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
    let dynamicTools: [CodexWireDynamicToolSpec]?
    /// Optional sticky environments for this thread.
    ///
    /// Omitted selects the default environment when environment access is enabled. Empty
    /// disables environment access for turns that do not provide a turn override. Non-empty
    /// selects the first environment as the current turn environment.
    let environments: [CodexWireTurnEnvironmentParams]?
    let ephemeral: Bool?
    /// If true, opt into emitting raw Responses API items on the event stream. This is for
    /// internal use only (e.g. Codex Cloud).
    let experimentalRawEvents: Bool?
    /// Test-only experimental field used to validate experimental gating and schema filtering
    /// behavior in a stable way.
    let mockExperimentalField: String?
    let model, modelProvider: String?
    /// Named profile selection for this thread. Cannot be combined with `sandbox`. Use bounded
    /// `modifications` for supported turn/thread adjustments instead of replacing the full
    /// permissions profile.
    let permissions: CodexWirePermissionProfileSelectionParams?
    /// Deprecated and ignored by app-server. Kept only so older clients can continue sending the
    /// field while rollout persistence always uses the limited history policy.
    let persistExtendedHistory: Bool?
    let personality: CodexWirePersonality?
    let sandbox: CodexWireSandboxMode?
    let serviceName, serviceTier: String?
    let sessionStartSource: CodexWireThreadStartSource?
    /// Optional client-supplied analytics source classification for this thread.
    let threadSource: CodexWireThreadSource?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireDynamicToolSpec
struct CodexWireDynamicToolSpec: Codable, Equatable, Sendable {
    let deferLoading: Bool?
    let description: String
    let inputSchema: CodexWireJSONValue
    let name: String
    let namespace: String?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireTurnEnvironmentParams
struct CodexWireTurnEnvironmentParams: Codable, Equatable, Sendable {
    let cwd, environmentID: String

    enum CodingKeys: String, CodingKey {
        case cwd
        case environmentID = "environmentId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Select a named built-in or user-defined profile and optionally apply bounded
/// modifications that Codex knows how to validate.
// MARK: - CodexWirePermissionProfileSelectionParams
struct CodexWirePermissionProfileSelectionParams: Codable, Equatable, Sendable {
    let id: String
    let modifications: [CodexWirePermissionProfileModificationParams]?
    let type: CodexWireProfilePermissionProfileSelectionParamsType
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Additional concrete directory that should be writable.
// MARK: - CodexWirePermissionProfileModificationParams
struct CodexWirePermissionProfileModificationParams: Codable, Equatable, Sendable {
    let path: String
    let type: CodexWireAdditionalWritableRootType
}

enum CodexWireAdditionalWritableRootType: String, Codable, Equatable, Sendable {
    case additionalWritableRoot = "additionalWritableRoot"
}

enum CodexWireProfilePermissionProfileSelectionParamsType: String, Codable, Equatable, Sendable {
    case profile = "profile"
}

enum CodexWirePersonality: String, Codable, Equatable, Sendable {
    case friendly = "friendly"
    case none = "none"
    case pragmatic = "pragmatic"
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
    /// Named or implicit built-in profile that produced the active permissions, when known.
    let activePermissionProfile: CodexWireActivePermissionProfile?
    let approvalPolicy: CodexWireAskForApproval
    /// Reviewer currently used for approval requests on this thread.
    let approvalsReviewer: CodexWireApprovalsReviewer
    let cwd: String
    /// Instruction source files currently loaded for this thread.
    let instructionSources: [String]?
    let model, modelProvider: String
    /// Full active permissions for this thread. `activePermissionProfile` carries
    /// display/provenance metadata for this runtime profile.
    let permissionProfile: CodexWirePermissionProfile?
    let reasoningEffort: CodexWireReasoningEffort?
    /// Legacy sandbox policy retained for compatibility. Experimental clients should prefer
    /// `permissionProfile` when they need exact runtime permissions.
    let sandbox: CodexWireSandboxPolicy
    let serviceTier: String?
    let thread: CodexWireThread
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireActivePermissionProfile
struct CodexWireActivePermissionProfile: Codable, Equatable, Sendable {
    /// Parent profile identifier once permissions profiles support inheritance. This is
    /// currently always `null`.
    let extends: String?
    /// Identifier from `default_permissions` or the implicit built-in default, such as
    /// `:workspace` or a user-defined `[permissions.<id>]` profile.
    let id: String
    /// Bounded user-requested modifications applied on top of the named profile, if any.
    let modifications: [CodexWireActivePermissionProfileModification]?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Additional concrete directory that should be writable.
// MARK: - CodexWireActivePermissionProfileModification
struct CodexWireActivePermissionProfileModification: Codable, Equatable, Sendable {
    let path: String
    let type: CodexWireAdditionalWritableRootType
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Codex owns sandbox construction for this profile.
///
/// Do not apply an outer sandbox.
///
/// Filesystem isolation is enforced by an external caller.
// MARK: - CodexWirePermissionProfile
struct CodexWirePermissionProfile: Codable, Equatable, Sendable {
    let fileSystem: CodexWirePermissionProfileFileSystemPermissions?
    let network: CodexWirePermissionProfileNetworkPermissions?
    let type: CodexWirePermissionProfileType
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWirePermissionProfileFileSystemPermissions
struct CodexWirePermissionProfileFileSystemPermissions: Codable, Equatable, Sendable {
    let entries: [CodexWireFileSystemSandboxEntry]?
    let globScanMaxDepth: Int?
    let type: CodexWireRestrictedPermissionProfileFileSystemPermissionsType
}

enum CodexWireRestrictedPermissionProfileFileSystemPermissionsType: String, Codable, Equatable, Sendable {
    case restricted = "restricted"
    case unrestricted = "unrestricted"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWirePermissionProfileNetworkPermissions
struct CodexWirePermissionProfileNetworkPermissions: Codable, Equatable, Sendable {
    let enabled: Bool
}

enum CodexWirePermissionProfileType: String, Codable, Equatable, Sendable {
    case disabled = "disabled"
    case external = "external"
    case managed = "managed"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Legacy sandbox policy retained for compatibility. Experimental clients should prefer
/// `permissionProfile` when they need exact runtime permissions.
// MARK: - CodexWireSandboxPolicy
struct CodexWireSandboxPolicy: Codable, Equatable, Sendable {
    let type: CodexWireSandboxPolicyType
    let networkAccess: CodexWireNetworkAccessUnion?
    let excludeSlashTmp, excludeTmpdirEnvVar: Bool?
    let writableRoots: [String]?
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

// MARK: - CodexWireThreadStartedNotification
struct CodexWireThreadStartedNotification: Codable, Equatable, Sendable {
    let thread: CodexWireThread
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadStatusChangedNotification
struct CodexWireThreadStatusChangedNotification: Codable, Equatable, Sendable {
    let status: CodexWireThreadStatus
    let threadID: String

    enum CodingKeys: String, CodingKey {
        case status
        case threadID = "threadId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadTokenUsageUpdatedNotification
struct CodexWireThreadTokenUsageUpdatedNotification: Codable, Equatable, Sendable {
    let threadID: String
    let tokenUsage: CodexWireThreadTokenUsage
    let turnID: String

    enum CodingKeys: String, CodingKey {
        case threadID = "threadId"
        case tokenUsage
        case turnID = "turnId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadTokenUsage
struct CodexWireThreadTokenUsage: Codable, Equatable, Sendable {
    let last: CodexWireTokenUsageBreakdown
    let modelContextWindow: Int?
    let total: CodexWireTokenUsageBreakdown
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireTokenUsageBreakdown
struct CodexWireTokenUsageBreakdown: Codable, Equatable, Sendable {
    let cachedInputTokens, inputTokens, outputTokens, reasoningOutputTokens: Int
    let totalTokens: Int
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadTurnsItemsListParams
struct CodexWireThreadTurnsItemsListParams: Codable, Equatable, Sendable {
    /// Opaque cursor to pass to the next call to continue after the last item.
    let cursor: String?
    /// Optional item page size.
    let limit: Int?
    /// Optional item pagination direction; defaults to ascending.
    let sortDirection: CodexWireSortDirection?
    let threadID, turnID: String

    enum CodingKeys: String, CodingKey {
        case cursor, limit, sortDirection
        case threadID = "threadId"
        case turnID = "turnId"
    }
}

enum CodexWireSortDirection: String, Codable, Equatable, Sendable {
    case asc = "asc"
    case desc = "desc"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadTurnsItemsListResponse
struct CodexWireThreadTurnsItemsListResponse: Codable, Equatable, Sendable {
    /// Opaque cursor to pass as `cursor` when reversing `sortDirection`. This is only populated
    /// when the page contains at least one item.
    let backwardsCursor: String?
    let data: [CodexWireThreadItem]
    /// Opaque cursor to pass to the next call to continue after the last item. if None, there
    /// are no more items to return.
    let nextCursor: String?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadTurnsListParams
struct CodexWireThreadTurnsListParams: Codable, Equatable, Sendable {
    /// Opaque cursor to pass to the next call to continue after the last turn.
    let cursor: String?
    /// How much item detail to include for each returned turn; defaults to summary.
    let itemsView: CodexWireTurnItemsView?
    /// Optional turn page size.
    let limit: Int?
    /// Optional turn pagination direction; defaults to descending.
    let sortDirection: CodexWireSortDirection?
    let threadID: String

    enum CodingKeys: String, CodingKey {
        case cursor, itemsView, limit, sortDirection
        case threadID = "threadId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadTurnsListResponse
struct CodexWireThreadTurnsListResponse: Codable, Equatable, Sendable {
    /// Opaque cursor to pass as `cursor` when reversing `sortDirection`. This is only populated
    /// when the page contains at least one turn. Use it with the opposite `sortDirection` to
    /// include the anchor turn again and catch updates to that turn.
    let backwardsCursor: String?
    let data: [CodexWireTurn]
    /// Opaque cursor to pass to the next call to continue after the last turn. if None, there
    /// are no more turns to return.
    let nextCursor: String?
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadUnarchiveParams
struct CodexWireThreadUnarchiveParams: Codable, Equatable, Sendable {
    let threadID: String

    enum CodingKeys: String, CodingKey {
        case threadID = "threadId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadUnarchiveResponse
struct CodexWireThreadUnarchiveResponse: Codable, Equatable, Sendable {
    let thread: CodexWireThread
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireThreadUnarchivedNotification
struct CodexWireThreadUnarchivedNotification: Codable, Equatable, Sendable {
    let threadID: String

    enum CodingKeys: String, CodingKey {
        case threadID = "threadId"
    }
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

/// Notification that the turn-level unified diff has changed. Contains the latest aggregated
/// diff across all file changes in the turn.
// MARK: - CodexWireTurnDiffUpdatedNotification
struct CodexWireTurnDiffUpdatedNotification: Codable, Equatable, Sendable {
    let diff, threadID, turnID: String

    enum CodingKeys: String, CodingKey {
        case diff
        case threadID = "threadId"
        case turnID = "turnId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireTurnPlanUpdatedNotification
struct CodexWireTurnPlanUpdatedNotification: Codable, Equatable, Sendable {
    let explanation: String?
    let plan: [CodexWireTurnPlanStep]
    let threadID, turnID: String

    enum CodingKeys: String, CodingKey {
        case explanation, plan
        case threadID = "threadId"
        case turnID = "turnId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireTurnPlanStep
struct CodexWireTurnPlanStep: Codable, Equatable, Sendable {
    let status: CodexWireTurnPlanStepStatus
    let step: String
}

enum CodexWireTurnPlanStepStatus: String, Codable, Equatable, Sendable {
    case completed = "completed"
    case inProgress = "inProgress"
    case pending = "pending"
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
    /// EXPERIMENTAL - Set a pre-set collaboration mode. Takes precedence over model,
    /// reasoning_effort, and developer instructions if set.
    ///
    /// For `collaboration_mode.settings.developer_instructions`, `null` means "use the built-in
    /// instructions for the selected mode".
    let collaborationMode: CodexWireCollaborationMode?
    /// Override the working directory for this turn and subsequent turns.
    let cwd: String?
    /// Override the reasoning effort for this turn and subsequent turns.
    let effort: CodexWireReasoningEffort?
    /// Optional turn-scoped environments.
    ///
    /// Omitted uses the thread sticky environments. Empty disables environment access for this
    /// turn. Non-empty selects the first environment as the current turn environment for this
    /// turn.
    let environments: [CodexWireTurnEnvironmentParams]?
    let input: [CodexWireUserInput]
    /// Override the model for this turn and subsequent turns.
    let model: String?
    /// Optional JSON Schema used to constrain the final assistant message for this turn.
    let outputSchema: CodexWireJSONValue?
    /// Select a named permissions profile for this turn and subsequent turns. Cannot be combined
    /// with `sandboxPolicy`. Use bounded `modifications` for supported turn adjustments instead
    /// of replacing the full permissions profile.
    let permissions: CodexWirePermissionProfileSelectionParams?
    /// Override the personality for this turn and subsequent turns.
    let personality: CodexWirePersonality?
    /// Optional turn-scoped Responses API client metadata.
    let responsesapiClientMetadata: [String: String]?
    /// Override the sandbox policy for this turn and subsequent turns.
    let sandboxPolicy: CodexWireDangerFullAccessSandboxPolicyClass?
    /// Override the service tier for this turn and subsequent turns.
    let serviceTier: String?
    /// Override the reasoning summary for this turn and subsequent turns.
    let summary: CodexWireReasoningSummary?
    let threadID: String

    enum CodingKeys: String, CodingKey {
        case approvalPolicy, approvalsReviewer, collaborationMode, cwd, effort, environments, input, model, outputSchema, permissions, personality, responsesapiClientMetadata, sandboxPolicy, serviceTier, summary
        case threadID = "threadId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Collaboration mode for a Codex session.
// MARK: - CodexWireCollaborationMode
struct CodexWireCollaborationMode: Codable, Equatable, Sendable {
    let mode: CodexWireModeKind
    let settings: CodexWireSettings
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

/// Settings for a collaboration mode.
// MARK: - CodexWireSettings
struct CodexWireSettings: Codable, Equatable, Sendable {
    let developerInstructions: String?
    let model: String
    let reasoningEffort: CodexWireReasoningEffort?

    enum CodingKeys: String, CodingKey {
        case developerInstructions = "developer_instructions"
        case model
        case reasoningEffort = "reasoning_effort"
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
    let networkAccess: CodexWireNetworkAccessUnion?
    let excludeSlashTmp, excludeTmpdirEnvVar: Bool?
    let writableRoots: [String]?
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

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireTurnStartedNotification
struct CodexWireTurnStartedNotification: Codable, Equatable, Sendable {
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

// MARK: - CodexWireWarningNotification
struct CodexWireWarningNotification: Codable, Equatable, Sendable {
    /// Concise warning message for the user.
    let message: String
    /// Optional thread target when the warning applies to a specific thread.
    let threadID: String?

    enum CodingKeys: String, CodingKey {
        case message
        case threadID = "threadId"
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of CodexWireJSONValue, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - CodexWireWindowsSandboxReadinessResponse
struct CodexWireWindowsSandboxReadinessResponse: Codable, Equatable, Sendable {
    let status: CodexWireWindowsSandboxReadiness
}

enum CodexWireWindowsSandboxReadiness: String, Codable, Equatable, Sendable {
    case notConfigured = "notConfigured"
    case ready = "ready"
    case updateRequired = "updateRequired"
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
