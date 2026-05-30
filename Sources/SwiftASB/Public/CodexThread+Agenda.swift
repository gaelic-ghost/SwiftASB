import Foundation
import Observation

extension CodexThread {
    @MainActor
    @Observable
    public final class Agenda {
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

        @ObservationIgnored
        private var threadEventTask: Task<Void, Never>?

        @ObservationIgnored
        private var turnEventTask: Task<Void, Never>?

        @ObservationIgnored
        private var proposedPlanItemsByID: [String: String]

        @ObservationIgnored
        private var proposedPlanItemOrder: [String]

        internal init(
            threadID: String,
            initialGoal: Goal?,
            threadEvents: AsyncThrowingStream<CodexThreadEvent, Error>,
            turnEvents: AsyncThrowingStream<CodexTurnEvent, Error>
        ) {
            self.threadID = threadID
            self.currentPlan = nil
            self.goal = initialGoal
            self.goalStatus = initialGoal?.status
            self.proposedPlan = nil
            self.updatedAt = initialGoal?.updatedAt
            self.proposedPlanItemsByID = [:]
            self.proposedPlanItemOrder = []

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

        private func apply(_ event: CodexThreadEvent) {
            switch event {
            case let .goalUpdated(update):
                goal = update.goal
                goalStatus = update.goal.status
                updatedAt = update.goal.updatedAt
            case .goalCleared:
                goal = nil
                goalStatus = nil
                updatedAt = nil
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
