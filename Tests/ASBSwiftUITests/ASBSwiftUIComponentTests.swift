@testable import ASBSwiftUI
import ASBPresentation
import Testing

@Suite("ASBSwiftUI components")
@MainActor
struct ASBSwiftUIComponentTests {
    @Test("thread sidebar stores snapshot and intent handler")
    func threadSidebarStoresInputs() {
        let snapshot = sidebarSnapshot(selectedThreadID: "thread-1")
        let sidebar = ASBThreadSidebar(snapshot: snapshot) { _ in }

        #expect(sidebar.snapshot == snapshot)
        #expect(sidebar.onIntent != nil)
    }

    @Test("agenda panel stores snapshot and intent handler")
    func agendaPanelStoresInputs() {
        let snapshot = AgendaSnapshot(
            threadID: "thread-1",
            goalTitle: "Ship slice 5",
            goalStatus: .active,
            planTitle: "Implementation Plan",
            currentPlan: AgendaPlan(
                turnID: "turn-1",
                explanation: "Build the first SwiftUI renderers.",
                steps: [
                    AgendaStep(id: "step-1", title: "Wrap sidebar", status: .completed),
                    AgendaStep(id: "step-2", title: "Add panels", status: .inProgress),
                ]
            )
        )
        let panel = ASBAgendaPanel(snapshot: snapshot) { _ in }

        #expect(panel.snapshot == snapshot)
        #expect(panel.onIntent != nil)
    }

    @Test("dashboard panel stores snapshot and intent handler")
    func dashboardPanelStoresInputs() {
        let snapshot = DashboardSnapshot(
            threadID: "thread-1",
            title: "SwiftASB",
            preview: "Slice 5",
            threadStatus: "active",
            goalTitle: "Ship slice 5",
            planTitle: "Implementation Plan",
            toolCallingStatus: .inProgress,
            mcpCallingStatus: .idle,
            autoReviewStatus: .approved,
            latestDiagnosticDescription: "Model verification updated.",
            hookRuns: [
                DashboardHookRun(
                    id: "hook-1",
                    eventName: "PostToolUse",
                    status: "completed",
                    sourcePath: "/tmp/hook",
                    startedAt: 1
                ),
            ],
            activeCalls: [
                DashboardCallSummary(
                    id: "call-1",
                    title: "swift build",
                    kind: .command,
                    status: "inProgress",
                    latestStatusText: "Building"
                ),
            ]
        )
        let panel = ASBDashboardPanel(snapshot: snapshot) { _ in }

        #expect(panel.snapshot == snapshot)
        #expect(panel.onIntent != nil)
    }

    private func sidebarSnapshot(selectedThreadID: String) -> ThreadSidebarSnapshot {
        ThreadSidebarSnapshot(
            sections: [
                ThreadSidebarSection(id: "recent", title: "Recent", items: [
                    sidebarItem(id: "thread-1", title: "First"),
                    sidebarItem(id: "thread-2", title: "Second"),
                ]),
            ],
            selection: .init(selectedThreadID: selectedThreadID)
        )
    }

    private func sidebarItem(id: String, title: String) -> ThreadSidebarItem {
        ThreadSidebarItem(
            id: id,
            title: title,
            sourceBadge: .cli,
            activityStatus: .idle,
            projectID: "project",
            projectTitle: "Project",
            worktreeID: "worktree",
            worktreeTitle: "Worktree",
            updatedAt: 1
        )
    }
}
