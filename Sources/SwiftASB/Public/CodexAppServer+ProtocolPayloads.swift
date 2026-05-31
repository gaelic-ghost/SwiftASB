import Foundation

extension CodexTurnPlanUpdate.Step {
    init(wireValue: CodexWireTurnPlanStep) {
        self.init(
            status: .init(wireValue: wireValue.status),
            step: wireValue.step
        )
    }
}

struct CodexProtocolCommandExecutionApprovalDecisionPayload: Encodable {
    let decision: CodexProtocolCommandExecutionApprovalDecision
}

enum CodexProtocolCommandExecutionApprovalDecision: Encodable {
    case accept
    case acceptForSession
    case acceptWithExecpolicyAmendment([String])
    case applyNetworkPolicyAmendment(CodexNetworkPolicyAmendment)
    case decline
    case cancel

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .accept:
            try container.encode("accept")
        case .acceptForSession:
            try container.encode("acceptForSession")
        case let .acceptWithExecpolicyAmendment(amendment):
            try container.encode(
                ["acceptWithExecpolicyAmendment": ["execpolicy_amendment": amendment]]
            )
        case let .applyNetworkPolicyAmendment(amendment):
            try container.encode(
                [
                    "applyNetworkPolicyAmendment": [
                        "network_policy_amendment": [
                            "action": amendment.action.wireValue,
                            "host": amendment.host,
                        ]
                    ]
                ]
            )
        case .decline:
            try container.encode("decline")
        case .cancel:
            try container.encode("cancel")
        }
    }
}

struct CodexProtocolFileChangeApprovalDecisionPayload: Encodable {
    let decision: String
}

struct CodexProtocolPermissionsApprovalResponsePayload: Encodable {
    let permissions: CodexProtocolPermissionProfilePayload
    let scope: String
}

struct CodexProtocolPermissionProfilePayload: Encodable {
    let fileSystem: CodexProtocolPermissionFileSystemPayload?
    let network: CodexProtocolPermissionNetworkPayload?
}

struct CodexProtocolPermissionFileSystemPayload: Encodable {
    let read: [String]?
    let write: [String]?
}

struct CodexProtocolPermissionNetworkPayload: Encodable {
    let enabled: Bool?
}

struct CodexProtocolToolUserInputResponsePayload: Encodable {
    struct AnswerPayload: Encodable {
        let answers: [String]
    }

    let answers: [String: AnswerPayload]
}

struct CodexProtocolMCPServerElicitationResponsePayload: Encodable {
    let action: String
    let content: CodexWireJSONValue?
    let _meta: CodexWireJSONValue?
}

extension CodexProtocolCommandExecutionApprovalRequest {
    var publicValue: CodexApprovalRequest {
        .commandExecution(
            .init(
                requestID: requestID,
                threadID: threadID,
                turnID: turnID,
                itemID: itemID,
                approvalID: approvalID,
                command: command,
                commandActions: commandActions?.map(\.publicValue),
                currentDirectoryPath: cwd,
                reason: reason,
                proposedExecPolicyAmendment: proposedExecpolicyAmendment,
                proposedNetworkPolicyAmendments: proposedNetworkPolicyAmendments?.map(\.publicValue),
                networkApprovalContext: networkApprovalContext.map(CodexAppServer.JSONValue.init(wireValue:))
            )
        )
    }
}

extension CodexProtocolFileChangeApprovalRequest {
    var publicValue: CodexApprovalRequest {
        .fileChange(
            .init(
                requestID: requestID,
                threadID: threadID,
                turnID: turnID,
                itemID: itemID,
                grantRoot: grantRoot,
                reason: reason
            )
        )
    }
}

extension CodexProtocolPermissionsApprovalRequest {
    var publicValue: CodexApprovalRequest {
        .permissions(
            .init(
                requestID: requestID,
                threadID: threadID,
                turnID: turnID,
                itemID: itemID,
                permissions: permissions.publicValue,
                reason: reason
            )
        )
    }
}

extension CodexProtocolGuardianApprovalReviewCompletedNotification {
    var publicDeniedActionApprovalRequest: CodexApprovalRequest? {
        guard notification.review.status == .denied else {
            return nil
        }

        return .guardianDeniedAction(
            .init(
                requestID: .string("guardian-denied-action:\(notification.reviewID)"),
                threadID: notification.threadID,
                turnID: notification.turnID,
                reviewID: notification.reviewID,
                targetItemID: notification.targetItemID,
                startedAtMS: notification.startedAtMS,
                completedAtMS: notification.completedAtMS,
                decisionSource: notification.decisionSource.rawValue,
                action: .init(wireValue: notification.action),
                review: .init(wireValue: notification.review),
                event: .init(wireValue: event)
            )
        )
    }
}

extension CodexGuardianApprovalReviewAction {
    init(wireValue: CodexWireGuardianApprovalReviewAction) {
        self.init(
            type: .init(wireValue: wireValue.type),
            command: wireValue.command,
            currentDirectoryPath: wireValue.cwd,
            source: wireValue.source.map(CommandSource.init(wireValue:)),
            argv: wireValue.argv,
            program: wireValue.program,
            files: wireValue.files,
            host: wireValue.host,
            port: wireValue.port,
            networkProtocol: wireValue.guardianApprovalReviewActionProtocol.map(NetworkProtocol.init(wireValue:)),
            target: wireValue.target,
            connectorID: wireValue.connectorID,
            connectorName: wireValue.connectorName,
            server: wireValue.server,
            toolName: wireValue.toolName,
            toolTitle: wireValue.toolTitle,
            permissions: wireValue.permissions.map(CodexPermissionProfile.init(wireValue:)),
            reason: wireValue.reason
        )
    }
}

extension CodexGuardianApprovalReviewAction.ActionType {
    init(wireValue: CodexWireGuardianApprovalReviewActionType) {
        switch wireValue {
        case .applyPatch:
            self = .applyPatch
        case .command:
            self = .command
        case .execve:
            self = .execve
        case .mcpToolCall:
            self = .mcpToolCall
        case .networkAccess:
            self = .networkAccess
        case .requestPermissions:
            self = .requestPermissions
        }
    }
}

extension CodexGuardianApprovalReviewAction.CommandSource {
    init(wireValue: CodexWireGuardianCommandSource) {
        switch wireValue {
        case .shell:
            self = .shell
        case .unifiedExec:
            self = .unifiedExec
        }
    }
}

extension CodexGuardianApprovalReviewAction.NetworkProtocol {
    init(wireValue: CodexWireNetworkApprovalProtocol) {
        switch wireValue {
        case .http:
            self = .http
        case .https:
            self = .https
        case .socks5TCP:
            self = .socks5TCP
        case .socks5UDP:
            self = .socks5UDP
        }
    }
}

extension CodexGuardianApprovalReview {
    init(wireValue: CodexWireGuardianApprovalReview) {
        self.init(
            rationale: wireValue.rationale,
            riskLevel: wireValue.riskLevel.map(RiskLevel.init(wireValue:)),
            status: .init(wireValue: wireValue.status),
            userAuthorization: wireValue.userAuthorization.map(UserAuthorization.init(wireValue:))
        )
    }
}

extension CodexGuardianApprovalReview.RiskLevel {
    init(wireValue: CodexWireGuardianRiskLevel) {
        switch wireValue {
        case .critical:
            self = .critical
        case .high:
            self = .high
        case .low:
            self = .low
        case .medium:
            self = .medium
        }
    }
}

extension CodexGuardianApprovalReview.Status {
    init(wireValue: CodexWireGuardianApprovalReviewStatus) {
        switch wireValue {
        case .aborted:
            self = .aborted
        case .approved:
            self = .approved
        case .denied:
            self = .denied
        case .inProgress:
            self = .inProgress
        case .timedOut:
            self = .timedOut
        }
    }
}

extension CodexGuardianApprovalReview.UserAuthorization {
    init(wireValue: CodexWireGuardianUserAuthorization) {
        switch wireValue {
        case .high:
            self = .high
        case .low:
            self = .low
        case .medium:
            self = .medium
        case .unknown:
            self = .unknown
        }
    }
}

extension CodexPermissionProfile {
    init(wireValue: CodexWireRequestPermissionProfile) {
        self.init(
            fileSystem: wireValue.fileSystem.map {
                .init(read: $0.read, write: $0.write)
            },
            network: wireValue.network.map {
                .init(enabled: $0.enabled)
            }
        )
    }
}

extension CodexProtocolToolUserInputRequest {
    var publicValue: CodexElicitationRequest {
        .toolUserInput(
            .init(
                requestID: requestID,
                threadID: threadID,
                turnID: turnID,
                itemID: itemID,
                questions: questions.map(\.publicValue)
            )
        )
    }
}

extension CodexProtocolMCPServerElicitationRequest {
    var publicValue: CodexElicitationRequest {
        .mcpServer(
            .init(
                requestID: requestID,
                serverName: serverName,
                threadID: threadID,
                turnID: turnID,
                mode: mode.publicValue
            )
        )
    }
}

extension CodexProtocolMCPServerElicitationRequest.Mode {
    var publicValue: CodexMcpServerElicitationRequest.Mode {
        switch self {
        case let .form(form):
            .form(
                .init(
                    message: form.message,
                    requestedSchema: .init(wireValue: form.requestedSchema)
                )
            )
        case let .url(prompt):
            .url(
                .init(
                    elicitationID: prompt.elicitationID,
                    message: prompt.message,
                    url: prompt.url
                )
            )
        }
    }
}

extension CodexProtocolToolUserInputRequest.Question {
    var publicValue: CodexToolUserInputRequest.Question {
        .init(
            header: header,
            id: id,
            isOther: isOther,
            isSecret: isSecret,
            options: options?.map(\.publicValue),
            question: question
        )
    }
}

extension CodexProtocolToolUserInputRequest.Question.Option {
    var publicValue: CodexToolUserInputRequest.Question.Option {
        .init(description: description, label: label)
    }
}

extension CodexProtocolCommandAction {
    var publicValue: CodexCommandAction {
        switch self {
        case let .read(action):
            .read(.init(command: action.command, name: action.name, path: action.path))
        case let .listFiles(action):
            .listFiles(.init(command: action.command, path: action.path))
        case let .search(action):
            .search(.init(command: action.command, path: action.path, query: action.query))
        case let .unknown(action):
            .unknown(.init(command: action.command))
        }
    }
}

extension CodexProtocolNetworkPolicyAmendment {
    var publicValue: CodexNetworkPolicyAmendment {
        .init(
            action: .init(wireValue: action),
            host: host
        )
    }
}

extension CodexProtocolPermissionProfile {
    var publicValue: CodexPermissionProfile {
        .init(
            fileSystem: fileSystem.map { .init(read: $0.read, write: $0.write) },
            network: network.map { .init(enabled: $0.enabled) }
        )
    }
}

extension CodexCommandExecutionApprovalResponse {
    var protocolValue: CodexProtocolCommandExecutionApprovalDecisionPayload {
        let decision: CodexProtocolCommandExecutionApprovalDecision
        switch self {
        case .accept:
            decision = .accept
        case .acceptForSession:
            decision = .acceptForSession
        case let .acceptWithExecPolicyAmendment(amendment):
            decision = .acceptWithExecpolicyAmendment(amendment)
        case let .applyNetworkPolicyAmendment(amendment):
            decision = .applyNetworkPolicyAmendment(amendment)
        case .decline:
            decision = .decline
        case .cancel:
            decision = .cancel
        }

        return .init(decision: decision)
    }
}

extension CodexPermissionsApprovalResponse {
    var protocolValue: CodexProtocolPermissionsApprovalResponsePayload {
        .init(
            permissions: .init(
                fileSystem: permissions.fileSystem.map {
                    .init(read: $0.read, write: $0.write)
                },
                network: permissions.network.map {
                    .init(enabled: $0.enabled)
                }
            ),
            scope: scope.rawValue
        )
    }
}

extension CodexToolUserInputResponse {
    var protocolValue: CodexProtocolToolUserInputResponsePayload {
        .init(
            answers: answers.mapValues {
                .init(answers: $0.answers)
            }
        )
    }
}

extension CodexMcpServerElicitationResponse {
    var protocolValue: CodexProtocolMCPServerElicitationResponsePayload {
        .init(
            action: action.rawValue,
            content: content?.wireValue,
            _meta: metadata?.wireValue
        )
    }
}

extension CodexRPCRequestID {
    init(wireValue: CodexWireRequestID) {
        switch wireValue {
        case let .integer(value):
            self = .int(value)
        case let .string(value):
            self = .string(value)
        }
    }
}
