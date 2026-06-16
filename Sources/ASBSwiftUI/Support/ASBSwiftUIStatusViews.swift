import ASBPresentation
import SwiftUI

@MainActor
struct ASBStatusPill: View {
    var title: String
    var systemImage: String?

    init(_ title: String, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
                .lineLimit(1)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.quaternary, in: Capsule())
    }
}

@MainActor
struct ASBStatusRow: View {
    var title: String
    var value: String
    var systemImage: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(value)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
    }
}

@MainActor
struct ASBEmptyPanelMessage: View {
    var title: String
    var detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

@MainActor
struct ASBDiagnosticMessage: View {
    var text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Label {
            Text(text)
                .font(.caption)
                .lineLimit(3)
        } icon: {
            Image(systemName: "exclamationmark.triangle")
        }
        .foregroundStyle(.secondary)
    }
}

extension AgendaGoalStatus {
    var displayTitle: String {
        switch self {
            case .active:
                "Active"
            case .blocked:
                "Blocked"
            case .budgetLimited:
                "Budget Limited"
            case .complete:
                "Complete"
            case .paused:
                "Paused"
            case .usageLimited:
                "Usage Limited"
        }
    }

    var systemImage: String {
        switch self {
            case .active:
                "play.circle"
            case .blocked:
                "exclamationmark.octagon"
            case .budgetLimited:
                "gauge.with.dots.needle.bottom.50percent"
            case .complete:
                "checkmark.circle"
            case .paused:
                "pause.circle"
            case .usageLimited:
                "speedometer"
        }
    }
}

extension AgendaStepStatus {
    var systemImage: String {
        switch self {
            case .completed:
                "checkmark.circle.fill"
            case .inProgress:
                "play.circle.fill"
            case .pending:
                "circle"
        }
    }

    var tint: HierarchicalShapeStyle {
        switch self {
            case .completed:
                .primary
            case .inProgress:
                .secondary
            case .pending:
                .tertiary
        }
    }
}

extension DashboardActivityStatus {
    var displayTitle: String {
        switch self {
            case .errored:
                "Errored"
            case .idle:
                "Idle"
            case .inProgress:
                "In Progress"
        }
    }

    var systemImage: String {
        switch self {
            case .errored:
                "exclamationmark.triangle"
            case .idle:
                "circle"
            case .inProgress:
                "play.circle"
        }
    }
}

extension DashboardAutoReviewStatus {
    var displayTitle: String {
        switch self {
            case .aborted:
                "Aborted"
            case .approved:
                "Approved"
            case .denied:
                "Denied"
            case .idle:
                "Idle"
            case .inProgress:
                "In Progress"
            case .timedOut:
                "Timed Out"
        }
    }

    var systemImage: String {
        switch self {
            case .aborted:
                "xmark.octagon"
            case .approved:
                "checkmark.seal"
            case .denied:
                "hand.raised"
            case .idle:
                "circle"
            case .inProgress:
                "clock"
            case .timedOut:
                "timer"
        }
    }
}

extension TurnTimelineItemKind {
    var systemImage: String {
        switch self {
            case .agentMessage:
                "text.bubble"
            case .collabTool:
                "person.2.wave.2"
            case .command:
                "terminal"
            case .dynamicTool:
                "wrench.and.screwdriver"
            case .fileEdit:
                "doc.text"
            case .mcp:
                "point.3.connected.trianglepath.dotted"
            case .reasoning:
                "brain"
            case .unknown:
                "questionmark.circle"
        }
    }
}
