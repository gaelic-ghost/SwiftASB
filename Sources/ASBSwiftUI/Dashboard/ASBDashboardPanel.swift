import ASBPresentation
import SwiftUI

/// Native SwiftUI panel for current thread status and activity.
@MainActor
public struct ASBDashboardPanel: View {
    public typealias IntentHandler = @MainActor (DashboardIntent) -> Void

    public var snapshot: DashboardSnapshot
    public var onIntent: IntentHandler?

    public init(
        snapshot: DashboardSnapshot = .init(),
        onIntent: IntentHandler? = nil
    ) {
        self.snapshot = snapshot
        self.onIntent = onIntent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            summary
            activityRows

            if !snapshot.activeCalls.isEmpty {
                activeCalls
            }

            if !snapshot.hookRuns.isEmpty {
                hookRuns
            }

            if let latestDiagnosticDescription = snapshot.latestDiagnosticDescription,
               !latestDiagnosticDescription.isEmpty {
                ASBDiagnosticMessage(latestDiagnosticDescription)
            }
        }
        .padding(12)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Label("Dashboard", systemImage: "rectangle.grid.2x2")
                .font(.headline)
            Spacer(minLength: 8)
            Button {
                onIntent?(.refreshStatus)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.title.isEmpty ? "Thread" : snapshot.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)

            if !snapshot.preview.isEmpty {
                Text(snapshot.preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 6) {
                if let threadStatus = snapshot.threadStatus, !threadStatus.isEmpty {
                    ASBStatusPill(threadStatus)
                }
                if snapshot.isArchived {
                    ASBStatusPill("Archived", systemImage: "archivebox")
                }
                if snapshot.isClosed {
                    ASBStatusPill("Closed", systemImage: "lock")
                }
                if snapshot.isCompactingThreadContext {
                    ASBStatusPill("Compacting", systemImage: "arrow.triangle.2.circlepath")
                }
            }
        }
    }

    private var activityRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            ASBStatusRow(
                title: "Tools",
                value: snapshot.toolCallingStatus.displayTitle,
                systemImage: snapshot.toolCallingStatus.systemImage
            )
            ASBStatusRow(
                title: "MCP",
                value: snapshot.mcpCallingStatus.displayTitle,
                systemImage: snapshot.mcpCallingStatus.systemImage
            )
            ASBStatusRow(
                title: "Auto Review",
                value: snapshot.autoReviewStatus.displayTitle,
                systemImage: snapshot.autoReviewStatus.systemImage
            )

            if !snapshot.goalTitle.isEmpty {
                ASBStatusRow(title: "Goal", value: snapshot.goalTitle, systemImage: "target")
            }

            if !snapshot.planTitle.isEmpty {
                ASBStatusRow(title: "Plan", value: snapshot.planTitle, systemImage: "checklist")
            }
        }
    }

    private var activeCalls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Active Calls")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(snapshot.activeCalls) { call in
                ASBStatusRow(
                    title: call.title,
                    value: call.latestStatusText ?? call.status,
                    systemImage: call.kind.systemImage
                )
            }
        }
    }

    private var hookRuns: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hooks")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(snapshot.hookRuns) { run in
                ASBStatusRow(
                    title: run.eventName,
                    value: run.statusMessage ?? run.status,
                    systemImage: "point.3.connected.trianglepath.dotted"
                )
            }
        }
    }
}
