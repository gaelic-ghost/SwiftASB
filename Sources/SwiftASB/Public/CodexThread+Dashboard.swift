import Foundation
import Observation

extension CodexThread {
    @MainActor
    @Observable
    public final class Dashboard {
        public struct HookRun: Sendable, Equatable, Identifiable {
            public struct Entry: Sendable, Equatable {
                public enum Kind: String, Sendable, Equatable {
                    case context
                    case error
                    case feedback
                    case stop
                    case warning
                }

                public let kind: Kind
                public let text: String
            }

            public enum EventName: String, Sendable, Equatable {
                case permissionRequest
                case postCompact
                case postToolUse
                case preCompact
                case preToolUse
                case sessionStart
                case stop
                case subagentStart
                case subagentStop
                case userPromptSubmit
            }

            public enum ExecutionMode: String, Sendable, Equatable {
                case async
                case sync
            }

            public enum HandlerType: String, Sendable, Equatable {
                case agent
                case command
                case prompt
            }

            public enum Scope: String, Sendable, Equatable {
                case thread
                case turn
            }

            public enum Status: String, Sendable, Equatable {
                case blocked
                case completed
                case failed
                case running
                case stopped
            }

            public let id: String
            public let completedAt: Int?
            public let displayOrder: Int
            public let durationMS: Int?
            public let entries: [Entry]
            public let eventName: EventName
            public let executionMode: ExecutionMode
            public let handlerType: HandlerType
            public let scope: Scope
            public let sourcePath: String
            public let startedAt: Int
            public let status: Status
            public let statusMessage: String?
            public let turnID: String?
        }

        public enum ActivityStatus: String, Sendable, Equatable {
            case errored
            case idle
            case inProgress
        }

        public enum AutoReviewStatus: String, Sendable, Equatable {
            case aborted
            case approved
            case denied
            case idle
            case inProgress
            case timedOut
        }

        internal struct ActivityState: Sendable, Equatable {
            var activeAutoReviewIDs: Set<String> = []
            var activeMcpItemIDs: Set<String> = []
            var activeToolLikeItemIDs: Set<String> = []
            var autoReviewStatus: AutoReviewStatus = .idle
            var hasMcpErrorResidue = false
            var hookRuns: [HookRun] = []
            var hasToolErrorResidue = false
            var isCompactingThreadContext = false
        }

        public let threadID: String
        public private(set) var isArchived: Bool
        public private(set) var isClosed: Bool
        public private(set) var isCompactingThreadContext: Bool
        public private(set) var goalTitle: String
        public private(set) var autoReviewStatus: AutoReviewStatus
        public private(set) var latestDiagnostic: CodexDiagnosticEvent?
        public private(set) var latestTokenUsage: CodexThreadTokenUsageUpdated?
        public private(set) var mcpCallingStatus: ActivityStatus
        public private(set) var mcpServers: [CodexAppServer.McpServerSummary]
        public private(set) var name: String?
        public private(set) var planTitle: String
        public private(set) var preview: String
        public private(set) var status: CodexAppServer.ThreadStatus
        public private(set) var toolCallingStatus: ActivityStatus
        public private(set) var hookRuns: [HookRun]

        @ObservationIgnored
        private var eventTask: Task<Void, Never>?

        @ObservationIgnored
        private var turnEventTask: Task<Void, Never>?

        @ObservationIgnored
        private var activityTask: Task<Void, Never>?

        @ObservationIgnored
        private var activityState: ActivityState

        internal init(
            threadID: String,
            initialInfo: CodexAppServer.ThreadInfo,
            initialMcpServers: [CodexAppServer.McpServerSummary],
            events: AsyncThrowingStream<CodexThreadEvent, Error>,
            turnEvents: AsyncThrowingStream<CodexTurnEvent, Error>,
            initialActivityState: ActivityState,
            activityUpdates: AsyncStream<ActivityState>
        ) {
            self.threadID = threadID
            self.isArchived = false
            self.isClosed = false
            self.latestDiagnostic = nil
            self.goalTitle = ""
            self.latestTokenUsage = nil
            self.mcpServers = initialMcpServers
            self.name = initialInfo.name
            self.planTitle = ""
            self.preview = initialInfo.preview
            self.status = initialInfo.status
            self.activityState = initialActivityState
            self.autoReviewStatus = initialActivityState.autoReviewStatus
            self.hookRuns = initialActivityState.hookRuns
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

            turnEventTask = Task { [weak self] in
                guard let self else { return }

                do {
                    for try await event in turnEvents {
                        self.apply(event)
                    }
                } catch is CancellationError {
                    return
                } catch {
                    return
                }
            }

            activityTask = Task { [weak self] in
                guard let self else { return }

                for await state in activityUpdates {
                    self.apply(activityState: state)
                }
            }
        }

        deinit {
            eventTask?.cancel()
            turnEventTask?.cancel()
            activityTask?.cancel()
        }

        private func apply(_ event: CodexThreadEvent) {
            switch event {
            case let .started(started):
                name = started.thread.name
                preview = started.thread.preview
                status = started.thread.status
            case let .statusChanged(change):
                status = change.status
            case let .diagnostic(diagnostic):
                latestDiagnostic = diagnostic
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
            case let .goalUpdated(update):
                goalTitle = update.goal.objective
            case .goalCleared:
                goalTitle = ""
            }
        }

        private func apply(_ event: CodexTurnEvent) {
            switch event {
            case let .planUpdated(update):
                planTitle = Self.planTitle(from: update)
            case .started,
                .planDelta,
                .diffUpdated,
                .diagnostic,
                .approvalRequested,
                .elicitationRequested,
                .serverRequestResolved,
                .itemStarted,
                .itemCompleted,
                .agentMessageDelta,
                .reasoningSummaryPartAdded,
                .reasoningSummaryTextDelta,
                .reasoningTextDelta,
                .completed:
                return
            }
        }

        private func apply(activityState: ActivityState) {
            self.activityState = activityState
            syncActivityPresentation()
        }

        private func syncActivityPresentation() {
            hookRuns = activityState.hookRuns
            autoReviewStatus = activityState.autoReviewStatus
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

        private static func planTitle(from update: CodexTurnPlanUpdate) -> String {
            if let activeStep = update.plan.first(where: { $0.status == .inProgress }) {
                return activeStep.step
            }
            if let pendingStep = update.plan.first(where: { $0.status == .pending }) {
                return pendingStep.step
            }
            if let firstStep = update.plan.first {
                return firstStep.step
            }
            return update.explanation ?? ""
        }
    }

}
