import ASBPresentation
import SwiftUI

/// Native SwiftUI panel for a thread goal and plan snapshot.
@MainActor
public struct ASBAgendaPanel: View {
    public typealias IntentHandler = @MainActor (AgendaIntent) -> Void

    public var snapshot: AgendaSnapshot
    public var onIntent: IntentHandler?

    public init(
        snapshot: AgendaSnapshot = .init(),
        onIntent: IntentHandler? = nil
    ) {
        self.snapshot = snapshot
        self.onIntent = onIntent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if snapshot.hasGoal {
                goalSection
            }

            if let currentPlan = snapshot.currentPlan {
                planSection(currentPlan)
            } else if let proposedPlan = snapshot.proposedPlan {
                proposedPlanSection(proposedPlan)
            } else if !snapshot.hasGoal {
                ASBEmptyPanelMessage(
                    title: "No agenda",
                    detail: "This thread has no active goal or plan."
                )
            }
        }
        .padding(12)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Label("Agenda", systemImage: "checklist")
                .font(.headline)
            Spacer(minLength: 8)
            Button {
                onIntent?(.startPlanningTurn)
            } label: {
                Label("Plan", systemImage: "sparkles")
            }
            .buttonStyle(.bordered)
        }
    }

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(snapshot.goalTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                Spacer(minLength: 8)
                if let goalStatus = snapshot.goalStatus {
                    ASBStatusPill(goalStatus.displayTitle, systemImage: goalStatus.systemImage)
                }
            }

            HStack(spacing: 8) {
                Button {
                    onIntent?(.pauseGoal)
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
                .disabled(snapshot.goalStatus == .paused)

                Button {
                    onIntent?(.resumeGoal)
                } label: {
                    Label("Resume", systemImage: "play.fill")
                }
                .disabled(snapshot.goalStatus == .active)

                Button(role: .destructive) {
                    onIntent?(.clearGoal)
                } label: {
                    Label("Clear", systemImage: "xmark")
                }
            }
            .buttonStyle(.borderless)
            .labelStyle(.iconOnly)
        }
        .padding(.vertical, 4)
    }

    private func planSection(_ plan: AgendaPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !snapshot.planTitle.isEmpty {
                Text(snapshot.planTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
            }

            if let explanation = plan.explanation, !explanation.isEmpty {
                Text(explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            ForEach(plan.steps) { step in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: step.status.systemImage)
                        .foregroundStyle(step.status.tint)
                        .frame(width: 14)
                    Text(step.title)
                        .font(.caption)
                        .lineLimit(2)
                }
            }
        }
    }

    private func proposedPlanSection(_ plan: AgendaProposedPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Proposed Plan")
                .font(.subheadline)
                .fontWeight(.semibold)

            ForEach(plan.items) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                    Text(item.text)
                        .font(.caption)
                        .lineLimit(2)
                }
            }
        }
    }
}
