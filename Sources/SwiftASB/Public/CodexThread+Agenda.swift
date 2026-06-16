import Foundation
import Observation

public extension CodexThread {
    @MainActor
    @Observable
    final class Agenda {
        public struct Plan: Sendable, Equatable {
            public struct Step: Sendable, Equatable, Identifiable {
                public enum Status: String, Sendable, Equatable {
                    case completed
                    case inProgress
                    case pending
                }

                public let id: String
                public let status: Status
                public let title: String
            }

            public let turnID: String
            public let explanation: String?
            public let steps: [Step]
        }

        public struct ProposedPlan: Sendable, Equatable {
            public struct Item: Sendable, Equatable, Identifiable {
                public let id: String
                public let text: String
            }

            public let turnID: String
            public let items: [Item]
        }

        public let threadID: String
        public private(set) var currentPlan: Plan?
        public private(set) var goal: Goal?
        public private(set) var goalStatus: Goal.Status?
        public private(set) var proposedPlan: ProposedPlan?
        public private(set) var updatedAt: Int?

        @ObservationIgnored
        private var threadEventTask: Task<Void, Never>?

        @ObservationIgnored
        private var turnEventTask: Task<Void, Never>?

        @ObservationIgnored
        private var proposedPlanItemsByID: [String: String]

        @ObservationIgnored
        private var proposedPlanItemOrder: [String]

        @ObservationIgnored
        private let appServer: CodexAppServer

        public var goalTitle: String {
            goal?.objective ?? ""
        }

        public var planTitle: String {
            if let activeStep = currentPlan?.steps.first(where: { $0.status == .inProgress }) {
                return activeStep.title
            }
            if let pendingStep = currentPlan?.steps.first(where: { $0.status == .pending }) {
                return pendingStep.title
            }
            if let firstStep = currentPlan?.steps.first {
                return firstStep.title
            }
            if let explanation = currentPlan?.explanation, !explanation.isEmpty {
                return explanation
            }
            if let proposedText = proposedPlan?.items.first(where: { !$0.text.isEmpty })?.text {
                return proposedText
            }
            return ""
        }

        init(
            threadID: String,
            initialGoal: Goal?,
            appServer: CodexAppServer,
            threadEvents: AsyncThrowingStream<CodexThreadEvent, Error>,
            turnEvents: AsyncThrowingStream<CodexTurnEvent, Error>
        ) {
            self.threadID = threadID
            self.appServer = appServer
            currentPlan = nil
            goal = initialGoal
            goalStatus = initialGoal?.status
            proposedPlan = nil
            updatedAt = initialGoal?.updatedAt
            proposedPlanItemsByID = [:]
            proposedPlanItemOrder = []

            threadEventTask = Task { [weak self] in
                guard let self else { return }

                do {
                    for try await event in threadEvents {
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
        }

        deinit {
            threadEventTask?.cancel()
            turnEventTask?.cancel()
        }

        /// Creates or updates this thread's app-server goal.
        @discardableResult
        public func setGoal(_ request: GoalSetRequest) async throws -> Goal {
            let updatedGoal = try await appServer.setThreadGoal(
                threadID: threadID,
                request: request
            )
            apply(goal: updatedGoal)
            return updatedGoal
        }

        /// Sets this thread's goal objective.
        @discardableResult
        public func setGoal(
            _ objective: String,
            tokenBudget: Int? = nil
        ) async throws -> Goal {
            try await setGoal(
                .init(
                    objective: objective,
                    status: .active,
                    tokenBudget: tokenBudget
                )
            )
        }

        /// Pauses this thread's current app-server goal.
        @discardableResult
        public func pauseGoal() async throws -> Goal {
            try await setGoal(.init(status: .paused))
        }

        /// Resumes this thread's current app-server goal.
        @discardableResult
        public func resumeGoal() async throws -> Goal {
            try await setGoal(.init(status: .active))
        }

        /// Clears this thread's app-server goal.
        @discardableResult
        public func clearGoal() async throws -> Bool {
            let cleared = try await appServer.clearThreadGoal(threadID: threadID)
            if cleared {
                applyGoalCleared()
            }
            return cleared
        }

        private func apply(_ event: CodexThreadEvent) {
            switch event {
                case let .goalUpdated(update):
                    apply(goal: update.goal)
                case .goalCleared:
                    applyGoalCleared()
                case .started,
                     .statusChanged,
                     .diagnostic,
                     .approvalRequested,
                     .elicitationRequested,
                     .serverRequestResolved,
                     .archived,
                     .unarchived,
                     .closed,
                     .nameUpdated,
                     .tokenUsageUpdated:
                    return
            }
        }

        private func apply(goal: Goal) {
            self.goal = goal
            goalStatus = goal.status
            updatedAt = goal.updatedAt
        }

        private func applyGoalCleared() {
            goal = nil
            goalStatus = nil
            updatedAt = nil
        }

        private func apply(_ event: CodexTurnEvent) {
            switch event {
                case let .planUpdated(update):
                    currentPlan = .init(update)
                    if proposedPlan?.turnID == update.turnID {
                        clearProposedPlan()
                    }
                case let .planDelta(delta):
                    applyPlanDelta(delta)
                case .started,
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

        private func applyPlanDelta(_ delta: CodexTurnPlanDelta) {
            if proposedPlan?.turnID != delta.turnID {
                proposedPlanItemsByID.removeAll()
                proposedPlanItemOrder.removeAll()
            }

            if proposedPlanItemsByID[delta.itemID] == nil {
                proposedPlanItemOrder.append(delta.itemID)
            }

            proposedPlanItemsByID[delta.itemID, default: ""] += delta.delta
            proposedPlan = .init(
                turnID: delta.turnID,
                items: proposedPlanItemOrder.map {
                    .init(id: $0, text: proposedPlanItemsByID[$0] ?? "")
                }
            )
        }

        private func clearProposedPlan() {
            proposedPlan = nil
            proposedPlanItemsByID.removeAll()
            proposedPlanItemOrder.removeAll()
        }
    }
}

extension CodexThread.Agenda.Plan {
    init(_ update: CodexTurnPlanUpdate) {
        self.init(
            turnID: update.turnID,
            explanation: update.explanation,
            steps: update.plan.enumerated().map { index, step in
                .init(
                    id: "\(update.turnID):\(index)",
                    status: .init(step.status),
                    title: step.step
                )
            }
        )
    }
}

extension CodexThread.Agenda.Plan.Step.Status {
    init(_ status: CodexTurnPlanUpdate.Step.Status) {
        switch status {
            case .completed:
                self = .completed
            case .inProgress:
                self = .inProgress
            case .pending:
                self = .pending
        }
    }
}
