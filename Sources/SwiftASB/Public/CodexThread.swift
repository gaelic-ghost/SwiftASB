import Foundation
import Observation

public struct CodexThread: Sendable {
    @MainActor
    @Observable
    public final class Dashboard {
        public enum ActivityStatus: String, Sendable, Equatable {
            case errored
            case idle
            case inProgress
        }

        internal struct ActivityState: Sendable, Equatable {
            var activeMcpItemIDs: Set<String> = []
            var activeToolLikeItemIDs: Set<String> = []
            var hasMcpErrorResidue = false
            var hasToolErrorResidue = false
            var isCompactingThreadContext = false
        }

        public let threadID: String
        public private(set) var isArchived: Bool
        public private(set) var isClosed: Bool
        public private(set) var isCompactingThreadContext: Bool
        public private(set) var latestTokenUsage: CodexThreadTokenUsageUpdated?
        public private(set) var mcpCallingStatus: ActivityStatus
        public private(set) var name: String?
        public private(set) var preview: String
        public private(set) var status: CodexAppServer.ThreadStatus
        public private(set) var toolCallingStatus: ActivityStatus

        @ObservationIgnored
        private var eventTask: Task<Void, Never>?

        @ObservationIgnored
        private var turnActivityTask: Task<Void, Never>?

        @ObservationIgnored
        private var activityState: ActivityState

        internal init(
            threadID: String,
            initialInfo: CodexAppServer.ThreadInfo,
            events: AsyncThrowingStream<CodexThreadEvent, Error>,
            initialActivityState: ActivityState,
            turnEvents: AsyncThrowingStream<CodexTurnEvent, Error>
        ) {
            self.threadID = threadID
            self.isArchived = false
            self.isClosed = false
            self.latestTokenUsage = nil
            self.name = initialInfo.name
            self.preview = initialInfo.preview
            self.status = initialInfo.status
            self.activityState = initialActivityState
            self.isCompactingThreadContext = initialActivityState.isCompactingThreadContext
            self.mcpCallingStatus = Self.activityStatus(
                activeIDs: initialActivityState.activeMcpItemIDs,
                hasErrorResidue: initialActivityState.hasMcpErrorResidue
            )
            self.toolCallingStatus = Self.activityStatus(
                activeIDs: initialActivityState.activeToolLikeItemIDs,
                hasErrorResidue: initialActivityState.hasToolErrorResidue
            )

            eventTask = Task { [weak self] in
                guard let self else { return }

                do {
                    for try await event in events {
                        self.apply(event)
                    }
                } catch is CancellationError {
                    return
                } catch {
                    return
                }
            }

            turnActivityTask = Task { [weak self] in
                guard let self else { return }

                do {
                    for try await event in turnEvents {
                        self.apply(turnEvent: event)
                    }
                } catch is CancellationError {
                    return
                } catch {
                    return
                }
            }
        }

        deinit {
            eventTask?.cancel()
            turnActivityTask?.cancel()
        }

        private func apply(_ event: CodexThreadEvent) {
            switch event {
            case let .started(started):
                name = started.thread.name
                preview = started.thread.preview
                status = started.thread.status
            case let .statusChanged(change):
                status = change.status
            case .approvalRequested:
                return
            case .elicitationRequested:
                return
            case .serverRequestResolved:
                return
            case .archived:
                isArchived = true
            case .unarchived:
                isArchived = false
            case .closed:
                isClosed = true
            case let .nameUpdated(update):
                name = update.threadName
            case let .tokenUsageUpdated(update):
                latestTokenUsage = update
            }
        }

        private func apply(turnEvent: CodexTurnEvent) {
            switch turnEvent {
            case let .itemStarted(itemStarted):
                handleItemStarted(itemStarted.item)
            case let .itemCompleted(itemCompleted):
                handleItemCompleted(itemCompleted.item)
            case .completed:
                activityState = .init()
                syncActivityPresentation()
            default:
                return
            }
        }

        private func handleItemStarted(_ item: CodexTurnItem) {
            switch item.kind {
            case .commandExecution, .dynamicToolCall, .collabAgentToolCall, .fileChange:
                activityState.activeToolLikeItemIDs.insert(item.id)
            case .mcpToolCall:
                activityState.activeMcpItemIDs.insert(item.id)
            case .contextCompaction:
                activityState.isCompactingThreadContext = true
            default:
                return
            }
            syncActivityPresentation()
        }

        private func handleItemCompleted(_ item: CodexTurnItem) {
            switch item.kind {
            case .commandExecution, .dynamicToolCall, .collabAgentToolCall, .fileChange:
                activityState.activeToolLikeItemIDs.remove(item.id)
                if item.isErrored {
                    activityState.hasToolErrorResidue = true
                }
            case .mcpToolCall:
                activityState.activeMcpItemIDs.remove(item.id)
                if item.isErrored {
                    activityState.hasMcpErrorResidue = true
                }
            case .contextCompaction:
                activityState.isCompactingThreadContext = false
            default:
                return
            }
            syncActivityPresentation()
        }

        private func syncActivityPresentation() {
            isCompactingThreadContext = activityState.isCompactingThreadContext
            toolCallingStatus = Self.activityStatus(
                activeIDs: activityState.activeToolLikeItemIDs,
                hasErrorResidue: activityState.hasToolErrorResidue
            )
            mcpCallingStatus = Self.activityStatus(
                activeIDs: activityState.activeMcpItemIDs,
                hasErrorResidue: activityState.hasMcpErrorResidue
            )
        }

        private static func activityStatus(
            activeIDs: Set<String>,
            hasErrorResidue: Bool
        ) -> ActivityStatus {
            if !activeIDs.isEmpty {
                return .inProgress
            }
            if hasErrorResidue {
                return .errored
            }
            return .idle
        }
    }

    public struct TurnRequest: Sendable, Equatable {
        public var approvalPolicy: CodexAppServer.ApprovalPolicy?
        public var approvalsReviewer: CodexAppServer.ApprovalsReviewer?
        public var currentDirectoryPath: String?
        public var effort: CodexAppServer.ReasoningEffort?
        public var input: [CodexAppServer.TurnInput]
        public var model: String?
        public var outputSchema: CodexAppServer.JSONValue?
        public var personality: CodexAppServer.Personality?
        public var serviceTier: CodexAppServer.ServiceTier?
        public var summary: CodexAppServer.ReasoningSummary?

        public init(
            input: [CodexAppServer.TurnInput],
            approvalPolicy: CodexAppServer.ApprovalPolicy? = nil,
            approvalsReviewer: CodexAppServer.ApprovalsReviewer? = nil,
            currentDirectoryPath: String? = nil,
            effort: CodexAppServer.ReasoningEffort? = nil,
            model: String? = nil,
            outputSchema: CodexAppServer.JSONValue? = nil,
            personality: CodexAppServer.Personality? = nil,
            serviceTier: CodexAppServer.ServiceTier? = nil,
            summary: CodexAppServer.ReasoningSummary? = nil
        ) {
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

    public let id: String
    public let info: CodexAppServer.ThreadInfo
    public let approvalPolicy: CodexAppServer.ApprovalPolicy
    public let approvalsReviewer: CodexAppServer.ApprovalsReviewer
    public let currentDirectoryPath: String
    public let instructionSources: [String]
    public let model: String
    public let modelProvider: String
    public let reasoningEffort: CodexAppServer.ReasoningEffort?
    public let sandboxPolicy: CodexAppServer.SandboxPolicy
    public let serviceTier: CodexAppServer.ServiceTier?
    public let events: AsyncThrowingStream<CodexThreadEvent, Error>

    private let appServer: CodexAppServer

    internal init(
        appServer: CodexAppServer,
        session: CodexAppServer.ThreadSession,
        events: AsyncThrowingStream<CodexThreadEvent, Error>
    ) {
        self.appServer = appServer
        self.id = session.thread.id
        self.info = session.thread
        self.approvalPolicy = session.approvalPolicy
        self.approvalsReviewer = session.approvalsReviewer
        self.currentDirectoryPath = session.currentDirectoryPath
        self.instructionSources = session.instructionSources
        self.model = session.model
        self.modelProvider = session.modelProvider
        self.reasoningEffort = session.reasoningEffort
        self.sandboxPolicy = session.sandboxPolicy
        self.serviceTier = session.serviceTier
        self.events = events
    }

    public func startTurn(_ request: TurnRequest) async throws -> CodexTurnHandle {
        try await appServer.startTurn(
            .init(
                threadID: id,
                input: request.input,
                approvalPolicy: request.approvalPolicy,
                approvalsReviewer: request.approvalsReviewer,
                currentDirectoryPath: request.currentDirectoryPath,
                effort: request.effort,
                model: request.model,
                outputSchema: request.outputSchema,
                personality: request.personality,
                serviceTier: request.serviceTier,
                summary: request.summary
            )
        )
    }

    public func startTextTurn(
        _ text: String,
        approvalPolicy: CodexAppServer.ApprovalPolicy? = nil,
        approvalsReviewer: CodexAppServer.ApprovalsReviewer? = nil,
        currentDirectoryPath: String? = nil,
        effort: CodexAppServer.ReasoningEffort? = nil,
        model: String? = nil,
        outputSchema: CodexAppServer.JSONValue? = nil,
        personality: CodexAppServer.Personality? = nil,
        serviceTier: CodexAppServer.ServiceTier? = nil,
        summary: CodexAppServer.ReasoningSummary? = nil
    ) async throws -> CodexTurnHandle {
        try await startTurn(
            .init(
                input: [.text(text)],
                approvalPolicy: approvalPolicy,
                approvalsReviewer: approvalsReviewer,
                currentDirectoryPath: currentDirectoryPath,
                effort: effort,
                model: model,
                outputSchema: outputSchema,
                personality: personality,
                serviceTier: serviceTier,
                summary: summary
            )
        )
    }

    @MainActor
    public func makeDashboard() async -> Dashboard {
        let events = await appServer.threadEventStream(threadID: id)
        let initialActivityState = await appServer.threadObservableActivityState(threadID: id)
        let turnEvents = await appServer.threadTurnEventStream(threadID: id)
        return Dashboard(
            threadID: id,
            initialInfo: info,
            events: events,
            initialActivityState: initialActivityState,
            turnEvents: turnEvents
        )
    }

    public func respond(
        to request: CodexApprovalRequest,
        with response: CodexApprovalResponse
    ) async throws {
        try await appServer.respond(
            to: request,
            with: response,
            expectedThreadID: id,
            expectedTurnID: nil
        )
    }

    public func respond(
        to request: CodexElicitationRequest,
        with response: CodexElicitationResponse
    ) async throws {
        try await appServer.respond(
            to: request,
            with: response,
            expectedThreadID: id,
            expectedTurnID: nil
        )
    }

}

public enum CodexThreadEvent: Sendable, Equatable {
    case started(CodexThreadStarted)
    case statusChanged(CodexThreadStatusChanged)
    case approvalRequested(CodexApprovalRequest)
    case elicitationRequested(CodexElicitationRequest)
    case serverRequestResolved(CodexInteractiveRequestResolved)
    case archived(CodexThreadArchived)
    case unarchived(CodexThreadUnarchived)
    case closed(CodexThreadClosed)
    case nameUpdated(CodexThreadNameUpdated)
    case tokenUsageUpdated(CodexThreadTokenUsageUpdated)
}

public struct CodexThreadStarted: Sendable, Equatable {
    public let thread: CodexAppServer.ThreadInfo

    internal init(thread: CodexAppServer.ThreadInfo) {
        self.thread = thread
    }
}

public struct CodexThreadStatusChanged: Sendable, Equatable {
    public let threadID: String
    public let status: CodexAppServer.ThreadStatus

    internal init(
        threadID: String,
        status: CodexAppServer.ThreadStatus
    ) {
        self.threadID = threadID
        self.status = status
    }
}

public struct CodexThreadNameUpdated: Sendable, Equatable {
    public let threadID: String
    public let threadName: String?

    internal init(
        threadID: String,
        threadName: String?
    ) {
        self.threadID = threadID
        self.threadName = threadName
    }
}

public struct CodexThreadArchived: Sendable, Equatable {
    public let threadID: String

    internal init(threadID: String) {
        self.threadID = threadID
    }
}

public struct CodexThreadUnarchived: Sendable, Equatable {
    public let threadID: String

    internal init(threadID: String) {
        self.threadID = threadID
    }
}

public struct CodexThreadClosed: Sendable, Equatable {
    public let threadID: String

    internal init(threadID: String) {
        self.threadID = threadID
    }
}

public struct CodexThreadTokenUsageUpdated: Sendable, Equatable {
    public struct Usage: Sendable, Equatable {
        public let cachedInputTokens: Int
        public let inputTokens: Int
        public let outputTokens: Int
        public let reasoningOutputTokens: Int
        public let totalTokens: Int

        internal init(
            cachedInputTokens: Int,
            inputTokens: Int,
            outputTokens: Int,
            reasoningOutputTokens: Int,
            totalTokens: Int
        ) {
            self.cachedInputTokens = cachedInputTokens
            self.inputTokens = inputTokens
            self.outputTokens = outputTokens
            self.reasoningOutputTokens = reasoningOutputTokens
            self.totalTokens = totalTokens
        }
    }

    public let threadID: String
    public let turnID: String
    public let last: Usage
    public let modelContextWindow: Int?
    public let total: Usage

    internal init(
        threadID: String,
        turnID: String,
        last: Usage,
        modelContextWindow: Int?,
        total: Usage
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.last = last
        self.modelContextWindow = modelContextWindow
        self.total = total
    }
}
