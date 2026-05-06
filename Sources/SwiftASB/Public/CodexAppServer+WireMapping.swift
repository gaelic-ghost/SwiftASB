import Foundation

extension CodexTurnPlanUpdate.Step.Status {
    init(wireValue: CodexWireTurnPlanStepStatus) {
        switch wireValue {
        case .completed:
            self = .completed
        case .inProgress:
            self = .inProgress
        case .pending:
            self = .pending
        }
    }
}

extension CodexTurnItem {
    init(wireValue: CodexWireThreadItem) {
        self.init(
            id: wireValue.id,
            kind: .init(wireValue: wireValue.type),
            command: wireValue.command,
            path: wireValue.path ?? wireValue.savedPath ?? wireValue.changes?.first?.path,
            serverName: wireValue.server,
            text: wireValue.text,
            status: wireValue.status,
            toolName: wireValue.tool
        )
    }
}

extension CodexTurnItem.Kind {
    init(wireValue: CodexWireThreadItemType) {
        switch wireValue {
        case .agentMessage:
            self = .agentMessage
        case .collabAgentToolCall:
            self = .collabAgentToolCall
        case .commandExecution:
            self = .commandExecution
        case .contextCompaction:
            self = .contextCompaction
        case .dynamicToolCall:
            self = .dynamicToolCall
        case .enteredReviewMode:
            self = .enteredReviewMode
        case .exitedReviewMode:
            self = .exitedReviewMode
        case .fileChange:
            self = .fileChange
        case .hookPrompt:
            self = .hookPrompt
        case .imageGeneration:
            self = .imageGeneration
        case .imageView:
            self = .imageView
        case .mcpToolCall:
            self = .mcpToolCall
        case .plan:
            self = .plan
        case .reasoning:
            self = .reasoning
        case .userMessage:
            self = .userMessage
        case .webSearch:
            self = .webSearch
        }
    }
}

extension CodexThreadTokenUsageUpdated.Usage {
    init(wireValue: CodexWireTokenUsageBreakdown) {
        self.init(
            cachedInputTokens: wireValue.cachedInputTokens,
            inputTokens: wireValue.inputTokens,
            outputTokens: wireValue.outputTokens,
            reasoningOutputTokens: wireValue.reasoningOutputTokens,
            totalTokens: wireValue.totalTokens
        )
    }
}

extension CodexAppServer.InitializeRequest {
    var wireValue: CodexWireInitializeParams {
        CodexWireInitializeParams(
            capabilities: CodexWireInitializeCapabilities(
                experimentalAPI: capabilities.experimentalAPI,
                optOutNotificationMethods: capabilities.optOutNotificationMethods
            ),
            clientInfo: CodexWireClientInfo(
                name: clientInfo.name,
                title: clientInfo.title,
                version: clientInfo.version
            )
        )
    }
}

extension CodexAppServer.ThreadStartRequest {
    var wireValue: CodexWireThreadStartParams {
        CodexWireThreadStartParams(
            approvalPolicy: approvalPolicy?.wireValue,
            approvalsReviewer: approvalsReviewer?.wireValue,
            baseInstructions: baseInstructions,
            config: config?.mapValues(\.wireValue),
            cwd: currentDirectoryPath,
            developerInstructions: developerInstructions,
            dynamicTools: nil,
            environments: nil,
            ephemeral: ephemeral,
            experimentalRawEvents: nil,
            mockExperimentalField: nil,
            model: model,
            modelProvider: modelProvider,
            permissions: permissions?.wireValue,
            persistExtendedHistory: nil,
            personality: personality?.wireValue,
            sandbox: sandboxMode?.wireValue,
            serviceName: serviceName,
            serviceTier: serviceTier?.wireValue,
            sessionStartSource: sessionStartSource?.wireValue
        )
    }
}

extension CodexAppServer.ThreadResumeRequest {
    var wireValue: CodexProtocolThreadResumeParams {
        .init(
            approvalPolicy: approvalPolicy?.wireValue,
            approvalsReviewer: approvalsReviewer?.wireValue,
            baseInstructions: baseInstructions,
            config: config?.mapValues(\.wireValue),
            cwd: currentDirectoryPath,
            developerInstructions: developerInstructions,
            excludeTurns: excludeTurns,
            model: model,
            modelProvider: modelProvider,
            permissions: permissions?.wireValue,
            personality: personality?.wireValue,
            sandbox: sandboxMode?.wireValue,
            serviceName: serviceName,
            serviceTier: serviceTier?.wireValue,
            threadID: threadID
        )
    }
}

extension CodexAppServer.ThreadForkRequest {
    var wireValue: CodexProtocolThreadForkParams {
        .init(
            approvalPolicy: approvalPolicy?.wireValue,
            approvalsReviewer: approvalsReviewer?.wireValue,
            baseInstructions: baseInstructions,
            config: config?.mapValues(\.wireValue),
            cwd: currentDirectoryPath,
            developerInstructions: developerInstructions,
            ephemeral: ephemeral,
            excludeTurns: excludeTurns,
            model: model,
            modelProvider: modelProvider,
            permissions: permissions?.wireValue,
            personality: personality?.wireValue,
            sandbox: sandboxMode?.wireValue,
            serviceName: serviceName,
            serviceTier: serviceTier?.wireValue,
            threadID: threadID
        )
    }
}

extension CodexAppServer.TurnStartRequest {
    var wireValue: CodexWireTurnStartParams {
        CodexWireTurnStartParams(
            approvalPolicy: approvalPolicy?.wireValue,
            approvalsReviewer: approvalsReviewer?.wireValue,
            collaborationMode: nil,
            cwd: currentDirectoryPath,
            effort: effort?.wireValue,
            environments: nil,
            input: input.map(\.wireValue),
            model: model,
            outputSchema: outputSchema?.wireValue,
            permissions: permissions?.wireValue,
            personality: personality?.wireValue,
            responsesapiClientMetadata: nil,
            sandboxPolicy: nil,
            serviceTier: serviceTier?.wireValue,
            summary: summary?.wireValue,
            threadID: threadID
        )
    }
}

extension CodexAppServer.TurnInput {
    var wireValue: CodexWireUserInput {
        CodexWireUserInput(
            text: text,
            textElements: nil,
            type: kind.wireValue,
            url: url,
            path: path,
            name: name
        )
    }
}

extension CodexAppServer.TurnInput.Kind {
    var wireValue: CodexWireUserInputType {
        switch self {
        case .image:
            .image
        case .localImage:
            .localImage
        case .mention:
            .mention
        case .skill:
            .skill
        case .text:
            .text
        }
    }
}

extension CodexAppServer.JSONValue {
    init(wireValue: CodexWireJSONValue) {
        switch wireValue {
        case .null:
            self = .null
        case let .bool(value):
            self = .bool(value)
        case let .integer(value):
            self = .integer(value)
        case let .double(value):
            self = .double(value)
        case let .string(value):
            self = .string(value)
        case let .array(value):
            self = .array(value.map(Self.init(wireValue:)))
        case let .object(value):
            self = .object(value.mapValues(Self.init(wireValue:)))
        }
    }

    var wireValue: CodexWireJSONValue {
        switch self {
        case .null:
            .null
        case let .bool(value):
            .bool(value)
        case let .integer(value):
            .integer(value)
        case let .double(value):
            .double(value)
        case let .string(value):
            .string(value)
        case let .array(value):
            .array(value.map(\.wireValue))
        case let .object(value):
            .object(value.mapValues(\.wireValue))
        }
    }
}

extension CodexAppServer.ApprovalPolicy {
    init(wireValue: CodexWireAskForApproval) {
        switch wireValue {
        case let .enumeration(value):
            self = Self(wireEnum: value)
        case let .codexWireGranularAskForApproval(value):
            self = .granular(.init(wireValue: value.granular))
        }
    }

    init(wireEnum: CodexWireApprovalPolicyEnum) {
        switch wireEnum {
        case .never:
            self = .never
        case .onFailure:
            self = .onFailure
        case .onRequest:
            self = .onRequest
        case .untrusted:
            self = .untrusted
        }
    }

    var wireValue: CodexWireApprovalPolicyUnion {
        switch self {
        case .never:
            .enumeration(.never)
        case .onFailure:
            .enumeration(.onFailure)
        case .onRequest:
            .enumeration(.onRequest)
        case .untrusted:
            .enumeration(.untrusted)
        case let .granular(policy):
            .codexWireGranularAskForApproval(
                CodexWireGranularAskForApproval(granular: policy.wireValue)
            )
        }
    }
}

extension CodexAppServer.GranularApprovalPolicy {
    init(wireValue: CodexWireGranular) {
        self.init(
            mcpElicitations: wireValue.mcpElicitations,
            requestPermissions: wireValue.requestPermissions,
            rules: wireValue.rules,
            sandboxApproval: wireValue.sandboxApproval,
            skillApproval: wireValue.skillApproval
        )
    }

    var wireValue: CodexWireGranular {
        CodexWireGranular(
            mcpElicitations: mcpElicitations,
            requestPermissions: requestPermissions,
            rules: rules,
            sandboxApproval: sandboxApproval,
            skillApproval: skillApproval
        )
    }
}

extension CodexAppServer.ApprovalsReviewer {
    init(wireValue: CodexWireApprovalsReviewer) {
        switch wireValue {
        case .autoReview:
            self = .autoReview
        case .guardianSubagent:
            self = .guardianSubagent
        case .user:
            self = .user
        }
    }

    var wireValue: CodexWireApprovalsReviewer {
        switch self {
        case .autoReview:
            .autoReview
        case .guardianSubagent:
            .guardianSubagent
        case .user:
            .user
        }
    }
}

extension CodexAppServer.Personality {
    init(wireValue: CodexWirePersonality) {
        switch wireValue {
        case .friendly:
            self = .friendly
        case .none:
            self = .none
        case .pragmatic:
            self = .pragmatic
        }
    }

    var wireValue: CodexWirePersonality {
        switch self {
        case .friendly:
            .friendly
        case .none:
            .none
        case .pragmatic:
            .pragmatic
        }
    }
}

extension CodexAppServer.SandboxMode {
    var wireValue: CodexWireSandboxMode {
        switch self {
        case .dangerFullAccess:
            .dangerFullAccess
        case .readOnly:
            .readOnly
        case .workspaceWrite:
            .workspaceWrite
        }
    }
}

extension CodexAppServer.ServiceTier {
    init?(wireValue: CodexWireServiceTier?) {
        guard let wireValue else { return nil }
        switch wireValue {
        case .fast:
            self = .fast
        case .flex:
            self = .flex
        }
    }

    var wireValue: CodexWireServiceTier {
        switch self {
        case .fast:
            .fast
        case .flex:
            .flex
        }
    }
}

extension CodexAppServer.SessionStartSource {
    var wireValue: CodexWireThreadStartSource {
        switch self {
        case .clear:
            .clear
        case .startup:
            .startup
        }
    }
}

extension CodexAppServer.ReasoningEffort {
    init(wireValue: CodexWireReasoningEffort) {
        self = Self(wireValue: Optional(wireValue))!
    }

    init?(wireValue: CodexWireReasoningEffort?) {
        guard let wireValue else { return nil }
        switch wireValue {
        case .high:
            self = .high
        case .low:
            self = .low
        case .medium:
            self = .medium
        case .minimal:
            self = .minimal
        case .none:
            self = .none
        case .xhigh:
            self = .xhigh
        }
    }

    var wireValue: CodexWireReasoningEffort {
        switch self {
        case .high:
            .high
        case .low:
            .low
        case .medium:
            .medium
        case .minimal:
            .minimal
        case .none:
            .none
        case .xhigh:
            .xhigh
        }
    }
}

extension CodexAppServer.ReasoningSummary {
    var wireValue: CodexWireReasoningSummary {
        switch self {
        case .auto:
            .auto
        case .concise:
            .concise
        case .detailed:
            .detailed
        case .none:
            .none
        }
    }
}

extension CodexAppServer.SandboxPolicy {
    init(wireValue: CodexWireSandboxPolicy) {
        self.init(
            type: .init(wireValue: wireValue.type),
            networkAccess: wireValue.networkAccess.map { CodexAppServer.NetworkAccess(wireValue: $0) },
            excludeSlashTmp: wireValue.excludeSlashTmp,
            excludeTmpdirEnvVar: wireValue.excludeTmpdirEnvVar,
            writableRoots: wireValue.writableRoots ?? []
        )
    }
}

extension CodexAppServer.NetworkAccess {
    init(wireValue: CodexWireNetworkAccessUnion) {
        switch wireValue {
        case let .bool(value):
            self = .explicit(value)
        case let .enumeration(value):
            switch value {
            case .enabled:
                self = .enabled
            case .restricted:
                self = .restricted
            }
        }
    }
}

extension CodexAppServer.SandboxPolicyType {
    init(wireValue: CodexWireSandboxPolicyType) {
        switch wireValue {
        case .dangerFullAccess:
            self = .dangerFullAccess
        case .externalSandbox:
            self = .externalSandbox
        case .readOnly:
            self = .readOnly
        case .workspaceWrite:
            self = .workspaceWrite
        }
    }
}

extension CodexAppServer.InitializeSession {
    init(wireValue: CodexWireInitializeResponse) {
        self.init(
            codexHome: wireValue.codexHome,
            platformFamily: wireValue.platformFamily,
            platformOS: wireValue.platformOS,
            userAgent: wireValue.userAgent
        )
    }
}

extension CodexAppServer.ThreadSession {
    init(wireValue: CodexWireThreadStartResponse) {
        self.init(
            activePermissionProfile: wireValue.activePermissionProfile.map(CodexWorkspace.ActivePermissionProfile.init),
            approvalPolicy: .init(wireValue: wireValue.approvalPolicy),
            approvalsReviewer: .init(wireValue: wireValue.approvalsReviewer),
            currentDirectoryPath: wireValue.cwd,
            instructionSources: wireValue.instructionSources ?? [],
            model: wireValue.model,
            modelProvider: wireValue.modelProvider,
            permissionProfile: wireValue.permissionProfile.map(CodexWorkspace.PermissionProfile.init),
            reasoningEffort: .init(wireValue: wireValue.reasoningEffort),
            sandboxPolicy: .init(wireValue: wireValue.sandbox),
            serviceTier: .init(wireValue: wireValue.serviceTier),
            thread: .init(wireValue: wireValue.thread)
        )
    }
}

extension CodexAppServer.ThreadInfo {
    init(wireValue: CodexWireThread) {
        self.init(
            id: wireValue.id,
            cliVersion: wireValue.cliVersion,
            createdAt: wireValue.createdAt,
            currentDirectoryPath: wireValue.cwd,
            ephemeral: wireValue.ephemeral,
            forkedFromThreadID: wireValue.forkedFromID,
            gitInfo: wireValue.gitInfo.map(CodexAppServer.GitInfo.init),
            modelProvider: wireValue.modelProvider,
            name: wireValue.name,
            preview: wireValue.preview,
            status: .init(wireValue: wireValue.status),
            updatedAt: wireValue.updatedAt
        )
    }
}

extension CodexAppServer.CLIExecutableDiagnostics {
    init(resolution: CodexCLIExecutableResolver.Resolution) {
        self.init(
            source: .init(resolution.source),
            resolvedExecutablePath: resolution.resolvedExecutableURL?.path,
            versionString: resolution.versionString,
            compatibility: .init(resolution.compatibility)
        )
    }
}

extension CodexAppServer.CLIExecutableDiagnostics.Source {
    init(_ source: CodexCLIExecutableResolver.Source) {
        switch source {
        case .explicit:
            self = .explicit
        case .path:
            self = .path
        case .homebrewAppleSilicon:
            self = .homebrewAppleSilicon
        case .homebrewIntel:
            self = .homebrewIntel
        case let .npmGlobal(prefix):
            self = .npmGlobal(prefix: prefix)
        }
    }
}

extension CodexAppServer.CLIExecutableDiagnostics.Compatibility {
    init(_ compatibility: CodexCLIExecutableResolver.Compatibility) {
        switch compatibility {
        case let .supported(documentedWindow):
            self = .supported(documentedWindow: documentedWindow)
        case let .outsideDocumentedWindow(documentedWindow):
            self = .outsideDocumentedWindow(documentedWindow: documentedWindow)
        case let .unknownVersionFormat(documentedWindow):
            self = .unknownVersionFormat(documentedWindow: documentedWindow)
        }
    }
}

extension CodexAppServer.ThreadStatus {
    init(wireValue: CodexWireThreadStatus) {
        self.init(
            type: .init(wireValue: wireValue.type),
            activeFlags: (wireValue.activeFlags ?? []).map { CodexAppServer.ThreadActiveFlag(wireValue: $0) }
        )
    }
}

extension CodexThread.Dashboard.HookRun {
    init(
        wireValue: CodexWireHookRunSummary,
        turnID: String?
    ) {
        self.init(
            id: wireValue.id,
            completedAt: wireValue.completedAt,
            displayOrder: wireValue.displayOrder,
            durationMS: wireValue.durationMS,
            entries: wireValue.entries.map(Entry.init(wireValue:)),
            eventName: .init(wireValue: wireValue.eventName),
            executionMode: .init(wireValue: wireValue.executionMode),
            handlerType: .init(wireValue: wireValue.handlerType),
            scope: .init(wireValue: wireValue.scope),
            sourcePath: wireValue.sourcePath,
            startedAt: wireValue.startedAt,
            status: .init(wireValue: wireValue.status),
            statusMessage: wireValue.statusMessage,
            turnID: turnID
        )
    }
}

extension CodexThread.Dashboard.HookRun.Entry {
    init(wireValue: CodexWireHookOutputEntry) {
        self.init(
            kind: .init(wireValue: wireValue.kind),
            text: wireValue.text
        )
    }
}

extension CodexThread.Dashboard.HookRun.Entry.Kind {
    init(wireValue: CodexWireHookOutputEntryKind) {
        switch wireValue {
        case .context:
            self = .context
        case .error:
            self = .error
        case .feedback:
            self = .feedback
        case .stop:
            self = .stop
        case .warning:
            self = .warning
        }
    }
}

extension CodexThread.Dashboard.HookRun.EventName {
    init(wireValue: CodexWireHookEventName) {
        switch wireValue {
        case .permissionRequest:
            self = .permissionRequest
        case .postToolUse:
            self = .postToolUse
        case .preToolUse:
            self = .preToolUse
        case .sessionStart:
            self = .sessionStart
        case .stop:
            self = .stop
        case .userPromptSubmit:
            self = .userPromptSubmit
        }
    }
}

extension CodexThread.Dashboard.HookRun.ExecutionMode {
    init(wireValue: CodexWireHookExecutionMode) {
        switch wireValue {
        case .async:
            self = .async
        case .sync:
            self = .sync
        }
    }
}

extension CodexThread.Dashboard.HookRun.HandlerType {
    init(wireValue: CodexWireHookHandlerType) {
        switch wireValue {
        case .agent:
            self = .agent
        case .command:
            self = .command
        case .prompt:
            self = .prompt
        }
    }
}

extension CodexThread.Dashboard.HookRun.Scope {
    init(wireValue: CodexWireHookScope) {
        switch wireValue {
        case .thread:
            self = .thread
        case .turn:
            self = .turn
        }
    }
}

extension CodexThread.Dashboard.HookRun.Status {
    init(wireValue: CodexWireHookRunStatus) {
        switch wireValue {
        case .blocked:
            self = .blocked
        case .completed:
            self = .completed
        case .failed:
            self = .failed
        case .running:
            self = .running
        case .stopped:
            self = .stopped
        }
    }
}

extension CodexAppServer.ThreadStatusType {
    init(wireValue: CodexWireThreadStatusType) {
        switch wireValue {
        case .active:
            self = .active
        case .idle:
            self = .idle
        case .notLoaded:
            self = .notLoaded
        case .systemError:
            self = .systemError
        }
    }
}

extension CodexProtocolThreadTurnsSortDirection {
    init(_ direction: CodexAppServer.ThreadTurnsSortDirection) {
        switch direction {
        case .asc:
            self = .asc
        case .desc:
            self = .desc
        }
    }
}

extension CodexProtocolThreadListSortKey {
    init(_ key: CodexAppServer.ThreadListSortKey) {
        switch key {
        case .createdAt:
            self = .createdAt
        case .updatedAt:
            self = .updatedAt
        }
    }
}

extension CodexProtocolThreadListSortDirection {
    init(_ direction: CodexAppServer.ThreadListSortDirection) {
        switch direction {
        case .asc:
            self = .asc
        case .desc:
            self = .desc
        }
    }
}

extension CodexProtocolThreadListSourceKind {
    init(_ sourceKind: CodexAppServer.ThreadListSourceKind) {
        switch sourceKind {
        case .appServer:
            self = .appServer
        case .cli:
            self = .cli
        case .exec:
            self = .exec
        case .unknown:
            self = .unknown
        case .vscode:
            self = .vscode
        }
    }
}

extension CodexAppServer.ThreadActiveFlag {
    init(wireValue: CodexWireThreadActiveFlag) {
        switch wireValue {
        case .waitingOnApproval:
            self = .waitingOnApproval
        case .waitingOnUserInput:
            self = .waitingOnUserInput
        }
    }
}

extension CodexAppServer.TurnSession {
    init(wireValue: CodexWireTurnStartResponse) {
        self.init(turn: .init(wireValue: wireValue.turn))
    }
}

extension CodexAppServer.TurnInfo {
    init(wireValue: CodexWireTurn) {
        self.init(
            completedAt: wireValue.completedAt,
            durationMS: wireValue.durationMS,
            errorMessage: wireValue.error?.message,
            id: wireValue.id,
            startedAt: wireValue.startedAt,
            status: .init(wireValue: wireValue.status)
        )
    }
}

extension CodexAppServer.TurnStatus {
    init(wireValue: CodexWireTurnStatus) {
        switch wireValue {
        case .completed:
            self = .completed
        case .failed:
            self = .failed
        case .inProgress:
            self = .inProgress
        case .interrupted:
            self = .interrupted
        }
    }
}
