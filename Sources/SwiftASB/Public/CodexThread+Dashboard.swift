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
                case postToolUse
                case preToolUse
                case sessionStart
                case stop
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

        internal struct ActivityState: Sendable, Equatable {
            var activeMcpItemIDs: Set<String> = []
            var activeToolLikeItemIDs: Set<String> = []
            var hasMcpErrorResidue = false
            var hookRuns: [HookRun] = []
            var hasToolErrorResidue = false
            var isCompactingThreadContext = false
        }

        public let threadID: String
        public private(set) var isArchived: Bool
        public private(set) var isClosed: Bool
        public private(set) var isCompactingThreadContext: Bool
        public private(set) var latestDiagnostic: CodexDiagnosticEvent?
        public private(set) var latestTokenUsage: CodexThreadTokenUsageUpdated?
        public private(set) var mcpCallingStatus: ActivityStatus
        public private(set) var name: String?
        public private(set) var preview: String
        public private(set) var status: CodexAppServer.ThreadStatus
        public private(set) var toolCallingStatus: ActivityStatus
        public private(set) var hookRuns: [HookRun]

        @ObservationIgnored
        private var eventTask: Task<Void, Never>?

        @ObservationIgnored
        private var activityTask: Task<Void, Never>?

        @ObservationIgnored
        private var activityState: ActivityState

        internal init(
            threadID: String,
            initialInfo: CodexAppServer.ThreadInfo,
            events: AsyncThrowingStream<CodexThreadEvent, Error>,
            initialActivityState: ActivityState,
            activityUpdates: AsyncStream<ActivityState>
        ) {
            self.threadID = threadID
            self.isArchived = false
            self.isClosed = false
            self.latestDiagnostic = nil
            self.latestTokenUsage = nil
            self.name = initialInfo.name
            self.preview = initialInfo.preview
            self.status = initialInfo.status
            self.activityState = initialActivityState
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

            activityTask = Task { [weak self] in
                guard let self else { return }

                for await state in activityUpdates {
                    self.apply(activityState: state)
                }
            }
        }

        deinit {
            eventTask?.cancel()
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
            }
        }

        private func apply(activityState: ActivityState) {
            self.activityState = activityState
            syncActivityPresentation()
        }

        private func syncActivityPresentation() {
            hookRuns = activityState.hookRuns
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

}
