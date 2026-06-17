import SwiftASB

/// Framework-neutral state for a thread goal and plan panel.
public struct AgendaSnapshot: Sendable, Equatable {
    public var threadID: String?
    public var goalTitle: String
    public var goalStatus: AgendaGoalStatus?
    public var planTitle: String
    public var currentPlan: AgendaPlan?
    public var proposedPlan: AgendaProposedPlan?
    public var updatedAt: Int?

    public var hasGoal: Bool {
        !goalTitle.isEmpty
    }

    public var hasPlan: Bool {
        currentPlan != nil || proposedPlan != nil
    }

    public init(
        threadID: String? = nil,
        goalTitle: String = "",
        goalStatus: AgendaGoalStatus? = nil,
        planTitle: String = "",
        currentPlan: AgendaPlan? = nil,
        proposedPlan: AgendaProposedPlan? = nil,
        updatedAt: Int? = nil
    ) {
        self.threadID = threadID
        self.goalTitle = goalTitle
        self.goalStatus = goalStatus
        self.planTitle = planTitle
        self.currentPlan = currentPlan
        self.proposedPlan = proposedPlan
        self.updatedAt = updatedAt
    }

    @MainActor
    public init(agenda: CodexThread.Agenda) {
        self.init(
            threadID: agenda.threadID,
            goalTitle: agenda.goalTitle,
            goalStatus: agenda.goalStatus.map(AgendaGoalStatus.init),
            planTitle: agenda.planTitle,
            currentPlan: agenda.currentPlan.map(AgendaPlan.init),
            proposedPlan: agenda.proposedPlan.map(AgendaProposedPlan.init),
            updatedAt: agenda.updatedAt
        )
    }
}

public struct AgendaPlan: Sendable, Equatable {
    public var turnID: String
    public var explanation: String?
    public var steps: [AgendaStep]

    public init(
        turnID: String,
        explanation: String? = nil,
        steps: [AgendaStep] = []
    ) {
        self.turnID = turnID
        self.explanation = explanation
        self.steps = steps
    }

    public init(_ plan: CodexThread.Agenda.Plan) {
        self.init(
            turnID: plan.turnID,
            explanation: plan.explanation,
            steps: plan.steps.map(AgendaStep.init)
        )
    }
}

public struct AgendaProposedPlan: Sendable, Equatable {
    public var turnID: String
    public var items: [AgendaProposedItem]

    public init(
        turnID: String,
        items: [AgendaProposedItem] = []
    ) {
        self.turnID = turnID
        self.items = items
    }

    public init(_ plan: CodexThread.Agenda.ProposedPlan) {
        self.init(
            turnID: plan.turnID,
            items: plan.items.map(AgendaProposedItem.init)
        )
    }
}

public struct AgendaStep: Sendable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var status: AgendaStepStatus

    public init(
        id: String,
        title: String,
        status: AgendaStepStatus
    ) {
        self.id = id
        self.title = title
        self.status = status
    }

    public init(_ step: CodexThread.Agenda.Plan.Step) {
        self.init(
            id: step.id,
            title: step.title,
            status: .init(step.status)
        )
    }
}

public struct AgendaProposedItem: Sendable, Equatable, Identifiable {
    public var id: String
    public var text: String

    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }

    public init(_ item: CodexThread.Agenda.ProposedPlan.Item) {
        self.init(id: item.id, text: item.text)
    }
}

public enum AgendaGoalStatus: String, Sendable, Equatable {
    case active
    case blocked
    case budgetLimited
    case complete
    case paused
    case usageLimited

    public init(_ status: CodexThread.Goal.Status) {
        switch status {
            case .active:
                self = .active
            case .blocked:
                self = .blocked
            case .budgetLimited:
                self = .budgetLimited
            case .complete:
                self = .complete
            case .paused:
                self = .paused
            case .usageLimited:
                self = .usageLimited
        }
    }
}

public enum AgendaStepStatus: String, Sendable, Equatable {
    case completed
    case inProgress
    case pending

    public init(_ status: CodexThread.Agenda.Plan.Step.Status) {
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

public enum AgendaIntent: Sendable, Equatable {
    case startPlanningTurn
    case setGoal(objective: String, tokenBudget: Int?)
    case pauseGoal
    case resumeGoal
    case clearGoal
}

/// Framework-neutral state for a thread status dashboard.
public struct DashboardSnapshot: Sendable, Equatable {
    public var threadID: String?
    public var title: String
    public var preview: String
    public var threadStatus: String?
    public var isArchived: Bool
    public var isClosed: Bool
    public var isCompactingThreadContext: Bool
    public var goalTitle: String
    public var planTitle: String
    public var toolCallingStatus: DashboardActivityStatus
    public var mcpCallingStatus: DashboardActivityStatus
    public var autoReviewStatus: DashboardAutoReviewStatus
    public var latestDiagnosticDescription: String?
    public var hookRuns: [DashboardHookRun]
    public var activeCalls: [DashboardCallSummary]

    public init(
        threadID: String? = nil,
        title: String = "",
        preview: String = "",
        threadStatus: String? = nil,
        isArchived: Bool = false,
        isClosed: Bool = false,
        isCompactingThreadContext: Bool = false,
        goalTitle: String = "",
        planTitle: String = "",
        toolCallingStatus: DashboardActivityStatus = .idle,
        mcpCallingStatus: DashboardActivityStatus = .idle,
        autoReviewStatus: DashboardAutoReviewStatus = .idle,
        latestDiagnosticDescription: String? = nil,
        hookRuns: [DashboardHookRun] = [],
        activeCalls: [DashboardCallSummary] = []
    ) {
        self.threadID = threadID
        self.title = title
        self.preview = preview
        self.threadStatus = threadStatus
        self.isArchived = isArchived
        self.isClosed = isClosed
        self.isCompactingThreadContext = isCompactingThreadContext
        self.goalTitle = goalTitle
        self.planTitle = planTitle
        self.toolCallingStatus = toolCallingStatus
        self.mcpCallingStatus = mcpCallingStatus
        self.autoReviewStatus = autoReviewStatus
        self.latestDiagnosticDescription = latestDiagnosticDescription
        self.hookRuns = hookRuns
        self.activeCalls = activeCalls
    }

    @MainActor
    public init(
        dashboard: CodexThread.Dashboard,
        activeMinimap: CodexTurnHandle.Minimap? = nil
    ) {
        self.init(
            threadID: dashboard.threadID,
            title: dashboard.name ?? dashboard.preview,
            preview: dashboard.preview,
            threadStatus: dashboard.status.type.rawValue,
            isArchived: dashboard.isArchived,
            isClosed: dashboard.isClosed,
            isCompactingThreadContext: dashboard.isCompactingThreadContext,
            goalTitle: dashboard.goalTitle,
            planTitle: dashboard.planTitle,
            toolCallingStatus: .init(dashboard.toolCallingStatus),
            mcpCallingStatus: .init(dashboard.mcpCallingStatus),
            autoReviewStatus: .init(dashboard.autoReviewStatus),
            latestDiagnosticDescription: dashboard.latestDiagnostic.map(Self.describe),
            hookRuns: dashboard.hookRuns.map(DashboardHookRun.init),
            activeCalls: activeMinimap?.callSnapshots.map(DashboardCallSummary.init) ?? []
        )
    }

    private static func describe(_ diagnostic: CodexDiagnosticEvent) -> String {
        switch diagnostic {
            case let .warning(warning):
                warning.message
            case let .guardianWarning(warning):
                warning.message
            case let .modelRerouted(reroute):
                "Model rerouted from \(reroute.fromModel) to \(reroute.toModel)."
            case .modelVerification:
                "Model verification updated."
            case let .configWarning(warning):
                warning.summary
            case let .deprecationNotice(notice):
                notice.summary
            case let .mcpServerStatusChanged(status):
                "MCP server \(status.name) status changed to \(status.status.rawValue)."
            case let .remoteControlStatusChanged(status):
                "Remote control \(status.serverName) status changed to \(status.status.rawValue)."
        }
    }
}

public enum DashboardActivityStatus: String, Sendable, Equatable {
    case errored
    case idle
    case inProgress

    public init(_ status: CodexThread.Dashboard.ActivityStatus) {
        switch status {
            case .errored:
                self = .errored
            case .idle:
                self = .idle
            case .inProgress:
                self = .inProgress
        }
    }
}

public enum DashboardAutoReviewStatus: String, Sendable, Equatable {
    case aborted
    case approved
    case denied
    case idle
    case inProgress
    case timedOut

    public init(_ status: CodexThread.Dashboard.AutoReviewStatus) {
        switch status {
            case .aborted:
                self = .aborted
            case .approved:
                self = .approved
            case .denied:
                self = .denied
            case .idle:
                self = .idle
            case .inProgress:
                self = .inProgress
            case .timedOut:
                self = .timedOut
        }
    }
}

public struct DashboardHookRun: Sendable, Equatable, Identifiable {
    public var id: String
    public var eventName: String
    public var status: String
    public var sourcePath: String
    public var startedAt: Int
    public var completedAt: Int?
    public var durationMS: Int?
    public var statusMessage: String?

    public init(
        id: String,
        eventName: String,
        status: String,
        sourcePath: String,
        startedAt: Int,
        completedAt: Int? = nil,
        durationMS: Int? = nil,
        statusMessage: String? = nil
    ) {
        self.id = id
        self.eventName = eventName
        self.status = status
        self.sourcePath = sourcePath
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.durationMS = durationMS
        self.statusMessage = statusMessage
    }

    public init(_ run: CodexThread.Dashboard.HookRun) {
        self.init(
            id: run.id,
            eventName: run.eventName.rawValue,
            status: run.status.rawValue,
            sourcePath: run.sourcePath,
            startedAt: run.startedAt,
            completedAt: run.completedAt,
            durationMS: run.durationMS,
            statusMessage: run.statusMessage
        )
    }
}

public struct DashboardCallSummary: Sendable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var kind: TurnTimelineItemKind
    public var status: String
    public var latestStatusText: String?

    public init(
        id: String,
        title: String,
        kind: TurnTimelineItemKind,
        status: String,
        latestStatusText: String? = nil
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.status = status
        self.latestStatusText = latestStatusText
    }

    public init(_ call: CodexTurnHandle.Minimap.CallSnapshot) {
        self.init(
            id: call.id,
            title: call.displayName,
            kind: .init(callKind: call.kind),
            status: call.status.rawValue,
            latestStatusText: call.latestStatusText
        )
    }
}

public enum DashboardIntent: Sendable, Equatable {
    case answerApproval(requestID: String, approved: Bool)
    case answerElicitation(requestID: String, response: String)
    case refreshStatus
}
