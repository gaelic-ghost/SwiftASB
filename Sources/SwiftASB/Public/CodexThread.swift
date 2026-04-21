import Foundation
import Observation

public struct CodexThread: Sendable {
    @MainActor
    @Observable
    public final class RecentTurns {
        public struct TurnSnapshot: Sendable, Equatable, Identifiable {
            public struct Item: Sendable, Equatable, Identifiable {
                public let id: String
                public let orderIndex: Int
                public let kind: String
                public let command: String?
                public let path: String?
                public let serverName: String?
                public let status: String?
                public let streamedText: String?
                public let text: String?
                public let toolName: String?
            }

            public struct TokenUsage: Sendable, Equatable {
                public let cachedInputTokens: Int?
                public let inputTokens: Int?
                public let outputTokens: Int?
                public let reasoningOutputTokens: Int?
                public let totalTokens: Int?
                public let modelContextWindow: Int?
            }

            public let id: String
            public let completedAt: Int?
            public let diff: String?
            public let durationMS: Int?
            public let errorMessage: String?
            public let items: [Item]
            public let orderIndex: Int
            public let startedAt: Int?
            public let status: String
            public let tokenUsage: TokenUsage?
        }

        public let threadID: String
        public let residentLimit: Int
        public private(set) var nextNewerCursor: String?
        public private(set) var nextOlderCursor: String?
        public private(set) var turns: [TurnSnapshot]

        @ObservationIgnored
        private let appServer: CodexAppServer

        @ObservationIgnored
        private var eventTask: Task<Void, Never>?

        internal init(
            threadID: String,
            residentLimit: Int,
            nextNewerCursor: String?,
            nextOlderCursor: String?,
            initialTurns: [TurnSnapshot],
            events: AsyncThrowingStream<CodexTurnEvent, Error>,
            appServer: CodexAppServer
        ) {
            self.threadID = threadID
            self.residentLimit = residentLimit
            self.nextNewerCursor = nextNewerCursor
            self.nextOlderCursor = nextOlderCursor
            self.turns = initialTurns
            self.appServer = appServer

            eventTask = Task { [weak self] in
                guard let self else { return }

                do {
                    for try await event in events {
                        await self.apply(event)
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
        }

        public func loadOlderTurns(limit: Int? = nil) async throws {
            guard let oldestOrderIndex = turns.last?.orderIndex else { return }
            let pageLimit = limit ?? residentLimit
            let window = try await appServer.olderTurnWindow(
                threadID: threadID,
                olderThanOrderIndex: oldestOrderIndex,
                cursor: nextOlderCursor,
                limit: pageLimit
            )
            merge(window.turns.map(TurnSnapshot.init))
            nextOlderCursor = window.nextOlderCursor
            if let nextNewerCursor = window.nextNewerCursor {
                self.nextNewerCursor = nextNewerCursor
            }
        }

        public func loadNewerTurns(limit: Int? = nil) async throws {
            guard let newestOrderIndex = turns.first?.orderIndex else { return }
            let pageLimit = limit ?? residentLimit
            let window = try await appServer.newerTurnWindow(
                threadID: threadID,
                newerThanOrderIndex: newestOrderIndex,
                cursor: nextNewerCursor,
                limit: pageLimit
            )
            merge(window.turns.map(TurnSnapshot.init))
            if let nextOlderCursor = window.nextOlderCursor {
                self.nextOlderCursor = nextOlderCursor
            }
            nextNewerCursor = window.nextNewerCursor
        }

        private func apply(_ event: CodexTurnEvent) async {
            guard let turnID = Self.turnID(from: event) else { return }
            guard let snapshot = try? await appServer.turnSnapshot(threadID: threadID, turnID: turnID) else {
                return
            }

            merge([TurnSnapshot(snapshot)])
        }

        private static func turnID(from event: CodexTurnEvent) -> String? {
            switch event {
            case let .started(started):
                started.turn.id
            case let .planUpdated(update):
                update.turnID
            case let .planDelta(delta):
                delta.turnID
            case let .diffUpdated(update):
                update.turnID
            case let .itemStarted(itemStarted):
                itemStarted.turnID
            case let .itemCompleted(itemCompleted):
                itemCompleted.turnID
            case let .agentMessageDelta(delta):
                delta.turnID
            case let .reasoningSummaryPartAdded(delta):
                delta.turnID
            case let .reasoningSummaryTextDelta(delta):
                delta.turnID
            case let .reasoningTextDelta(delta):
                delta.turnID
            case let .completed(completion):
                completion.turn.id
            case .approvalRequested, .elicitationRequested, .serverRequestResolved:
                nil
            }
        }

        private func merge(_ incoming: [TurnSnapshot]) {
            guard !incoming.isEmpty else { return }

            for snapshot in incoming {
                if let index = turns.firstIndex(where: { $0.id == snapshot.id }) {
                    turns[index] = snapshot
                } else {
                    turns.append(snapshot)
                }
            }

            turns.sort { $0.orderIndex > $1.orderIndex }
        }
    }

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

    @MainActor
    public func makeRecentTurns(limit: Int = 12) async throws -> RecentTurns {
        let window = try await appServer.recentTurnWindow(threadID: id, limit: limit)
        let events = await appServer.threadTurnEventStream(threadID: id)
        return RecentTurns(
            threadID: id,
            residentLimit: limit,
            nextNewerCursor: window.nextNewerCursor,
            nextOlderCursor: window.nextOlderCursor,
            initialTurns: window.turns.map(RecentTurns.TurnSnapshot.init),
            events: events,
            appServer: appServer
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

private extension CodexThread.RecentTurns.TurnSnapshot {
    init(_ snapshot: ThreadHistoryStore.ThreadSnapshot.TurnSnapshot) {
        self.init(
            id: snapshot.id,
            completedAt: snapshot.completedAt,
            diff: snapshot.diff,
            durationMS: snapshot.durationMS,
            errorMessage: snapshot.errorMessage,
            items: snapshot.items.map {
                .init(
                    id: $0.id,
                    orderIndex: $0.orderIndex,
                    kind: $0.kind,
                    command: $0.command,
                    path: $0.path,
                    serverName: $0.serverName,
                    status: $0.status,
                    streamedText: $0.streamedText,
                    text: $0.text,
                    toolName: $0.toolName
                )
            },
            orderIndex: snapshot.orderIndex,
            startedAt: snapshot.startedAt,
            status: snapshot.status,
            tokenUsage: snapshot.tokenUsage.map {
                .init(
                    cachedInputTokens: $0.cachedInputTokens,
                    inputTokens: $0.inputTokens,
                    outputTokens: $0.outputTokens,
                    reasoningOutputTokens: $0.reasoningOutputTokens,
                    totalTokens: $0.totalTokens,
                    modelContextWindow: $0.modelContextWindow
                )
            }
        )
    }
}
