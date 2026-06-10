import ASBPresentation
import Testing

@Suite("Agenda and dashboard presentation")
struct AgendaDashboardPresentationTests {
    @Test("agenda snapshot exposes goal, current plan, and proposed plan")
    func agendaSnapshotCarriesGoalAndPlan() {
        let plan = AgendaPlan(
            turnID: "turn-plan",
            explanation: "Prepare implementation",
            steps: [
                .init(id: "step-1", title: "Inspect sources", status: .completed),
                .init(id: "step-2", title: "Add contracts", status: .inProgress),
            ]
        )
        let proposed = AgendaProposedPlan(
            turnID: "turn-proposed",
            items: [.init(id: "proposal-1", text: "Validate before renderer work")]
        )
        let snapshot = AgendaSnapshot(
            threadID: "thread-1",
            goalTitle: "Finish ASBPresentation",
            goalStatus: .active,
            planTitle: "Add contracts",
            currentPlan: plan,
            proposedPlan: proposed,
            updatedAt: 42
        )

        #expect(snapshot.hasGoal)
        #expect(snapshot.hasPlan)
        #expect(snapshot.currentPlan?.steps.map(\.id) == ["step-1", "step-2"])
        #expect(snapshot.currentPlan?.steps[1].status == .inProgress)
        #expect(snapshot.proposedPlan?.items.first?.text == "Validate before renderer work")
    }

    @Test("agenda intents represent goal and planning actions")
    func agendaIntentsRepresentRuntimeActions() {
        let intents: [AgendaIntent] = [
            .startPlanningTurn,
            .setGoal(objective: "Ship foundation", tokenBudget: 4000),
            .pauseGoal,
            .resumeGoal,
            .clearGoal,
        ]

        #expect(intents.contains(.startPlanningTurn))
        #expect(intents.contains(.setGoal(objective: "Ship foundation", tokenBudget: 4000)))
        #expect(intents.contains(.clearGoal))
    }

    @Test("dashboard snapshot carries status summaries and active calls")
    func dashboardSnapshotCarriesStatusSummaries() {
        let call = DashboardCallSummary(
            id: "call-1",
            title: "swift test",
            kind: .command,
            status: "inProgress",
            latestStatusText: "Running tests"
        )
        let hook = DashboardHookRun(
            id: "hook-1",
            eventName: "postToolUse",
            status: "completed",
            sourcePath: ".codex/hooks/post-tool-use.sh",
            startedAt: 10,
            completedAt: 12,
            durationMS: 2
        )
        let snapshot = DashboardSnapshot(
            threadID: "thread-1",
            title: "SwiftASB",
            preview: "Working on presentation",
            threadStatus: "active",
            isCompactingThreadContext: true,
            goalTitle: "Finish ASBPresentation",
            planTitle: "Add dashboard",
            toolCallingStatus: .inProgress,
            mcpCallingStatus: .idle,
            autoReviewStatus: .approved,
            latestDiagnosticDescription: "Model verification updated.",
            hookRuns: [hook],
            activeCalls: [call]
        )

        #expect(snapshot.threadID == "thread-1")
        #expect(snapshot.isCompactingThreadContext)
        #expect(snapshot.toolCallingStatus == .inProgress)
        #expect(snapshot.hookRuns.map(\.id) == ["hook-1"])
        #expect(snapshot.activeCalls.map(\.id) == ["call-1"])
    }

    @Test("dashboard intents keep request answers typed")
    func dashboardIntentsKeepRequestAnswersTyped() {
        let intents: [DashboardIntent] = [
            .answerApproval(requestID: "request-1", approved: true),
            .answerElicitation(requestID: "request-2", response: "value"),
            .refreshStatus,
        ]

        #expect(intents.contains(.answerApproval(requestID: "request-1", approved: true)))
        #expect(intents.contains(.answerElicitation(requestID: "request-2", response: "value")))
        #expect(intents.contains(.refreshStatus))
    }
}
