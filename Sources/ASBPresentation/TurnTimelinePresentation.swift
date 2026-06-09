import SwiftASB

/// Framework-neutral state for a thread turn timeline.
public struct TurnTimelineSnapshot: Sendable, Equatable {
    public var sections: [TurnTimelineSection]
    public var viewport: TurnTimelineViewportState
    public var selectedItemID: String?
    public var isLoadingOlderTurns: Bool
    public var isLoadingNewerTurns: Bool
    public var canLoadOlderTurns: Bool
    public var canLoadNewerTurns: Bool
    public var errorDescription: String?

    public init(
        sections: [TurnTimelineSection] = [],
        viewport: TurnTimelineViewportState = .init(),
        selectedItemID: String? = nil,
        isLoadingOlderTurns: Bool = false,
        isLoadingNewerTurns: Bool = false,
        canLoadOlderTurns: Bool = false,
        canLoadNewerTurns: Bool = false,
        errorDescription: String? = nil
    ) {
        self.sections = sections
        self.viewport = viewport
        self.selectedItemID = selectedItemID
        self.isLoadingOlderTurns = isLoadingOlderTurns
        self.isLoadingNewerTurns = isLoadingNewerTurns
        self.canLoadOlderTurns = canLoadOlderTurns
        self.canLoadNewerTurns = canLoadNewerTurns
        self.errorDescription = errorDescription
    }

    /// All timeline items in renderer order.
    public var items: [TurnTimelineItem] {
        sections.flatMap(\.items)
    }

    /// True when there is no visible turn or active call row.
    public var isEmpty: Bool {
        items.isEmpty
    }

    @MainActor
    public init(
        recentTurns: CodexThread.RecentTurns,
        activeMinimap: CodexTurnHandle.Minimap? = nil,
        viewport: TurnTimelineViewportState? = nil,
        selectedItemID: String? = nil
    ) {
        var sections = recentTurns.turns.map(TurnTimelineSection.init(turn:))

        if let activeMinimap {
            let activeSection = TurnTimelineSection(activeMinimap: activeMinimap)
            if let index = sections.firstIndex(where: { $0.id == activeSection.id }) {
                sections[index] = activeSection
            } else {
                sections.insert(activeSection, at: 0)
            }
        }

        self.init(
            sections: sections,
            viewport: viewport ?? .init(recentTurns: recentTurns),
            selectedItemID: selectedItemID,
            isLoadingOlderTurns: recentTurns.isLoadingOlderTurns,
            isLoadingNewerTurns: recentTurns.isLoadingNewerTurns,
            canLoadOlderTurns: recentTurns.nextOlderCursor != nil,
            canLoadNewerTurns: recentTurns.nextNewerCursor != nil,
            errorDescription: recentTurns.lastLoadErrorDescription
        )
    }
}

/// One turn section in a framework-neutral timeline.
public struct TurnTimelineSection: Sendable, Equatable, Identifiable {
    public var id: String
    public var turnID: String
    public var title: String
    public var status: String
    public var startedAt: Int?
    public var completedAt: Int?
    public var durationMS: Int?
    public var tokenSummary: TurnTimelineTokenSummary?
    public var items: [TurnTimelineItem]

    public init(
        id: String,
        turnID: String,
        title: String,
        status: String,
        startedAt: Int? = nil,
        completedAt: Int? = nil,
        durationMS: Int? = nil,
        tokenSummary: TurnTimelineTokenSummary? = nil,
        items: [TurnTimelineItem] = []
    ) {
        self.id = id
        self.turnID = turnID
        self.title = title
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.durationMS = durationMS
        self.tokenSummary = tokenSummary
        self.items = items
    }

    public init(turn: CodexThread.RecentTurns.TurnSnapshot) {
        self.init(
            id: turn.id,
            turnID: turn.id,
            title: Self.title(for: turn),
            status: turn.status,
            startedAt: turn.startedAt,
            completedAt: turn.completedAt,
            durationMS: turn.durationMS,
            tokenSummary: turn.tokenUsage.map(TurnTimelineTokenSummary.init(tokenUsage:)),
            items: turn.items.map { TurnTimelineItem(turnID: turn.id, item: $0) }
        )
    }

    @MainActor
    public init(activeMinimap: CodexTurnHandle.Minimap) {
        self.init(
            id: activeMinimap.turnID,
            turnID: activeMinimap.turnID,
            title: "Active turn",
            status: activeMinimap.currentTurn.status.rawValue,
            startedAt: activeMinimap.currentTurn.startedAt,
            completedAt: activeMinimap.latestCompletion?.turn.completedAt,
            durationMS: activeMinimap.latestCompletion?.turn.durationMS,
            tokenSummary: nil,
            items: activeMinimap.callSnapshots.map { TurnTimelineItem(turnID: activeMinimap.turnID, call: $0) }
        )
    }

    private static func title(for turn: CodexThread.RecentTurns.TurnSnapshot) -> String {
        if let completedAt = turn.completedAt {
            return "Turn completed at \(completedAt)"
        }
        if let startedAt = turn.startedAt {
            return "Turn started at \(startedAt)"
        }
        return "Turn \(turn.orderIndex)"
    }
}

/// One visible row inside a turn timeline.
public struct TurnTimelineItem: Sendable, Equatable, Identifiable {
    public var id: String
    public var turnID: String
    public var displayKind: TurnTimelineItemKind
    public var title: String
    public var subtitle: String?
    public var status: String?
    public var text: String?
    public var path: String?
    public var command: String?
    public var serverName: String?
    public var toolName: String?
    public var isPayloadComplete: Bool
    public var omittedPayloadCount: Int
    public var isLowValueForResidency: Bool

    public init(
        id: String,
        turnID: String,
        displayKind: TurnTimelineItemKind,
        title: String,
        subtitle: String? = nil,
        status: String? = nil,
        text: String? = nil,
        path: String? = nil,
        command: String? = nil,
        serverName: String? = nil,
        toolName: String? = nil,
        isPayloadComplete: Bool = true,
        omittedPayloadCount: Int = 0,
        isLowValueForResidency: Bool = false
    ) {
        self.id = id
        self.turnID = turnID
        self.displayKind = displayKind
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.text = text
        self.path = path
        self.command = command
        self.serverName = serverName
        self.toolName = toolName
        self.isPayloadComplete = isPayloadComplete
        self.omittedPayloadCount = omittedPayloadCount
        self.isLowValueForResidency = isLowValueForResidency
    }

    public init(turnID: String, item: CodexThread.RecentTurns.TurnSnapshot.Item) {
        self.init(
            id: item.id,
            turnID: turnID,
            displayKind: .init(rawKind: item.kind),
            title: Self.title(for: item),
            subtitle: item.status,
            status: item.status,
            text: item.text ?? item.streamedText,
            path: item.path,
            command: item.command,
            serverName: item.serverName,
            toolName: item.toolName,
            isPayloadComplete: true,
            omittedPayloadCount: 0,
            isLowValueForResidency: item.isLowValueForResidency
        )
    }

    public init(turnID: String, call: CodexTurnHandle.Minimap.CallSnapshot) {
        self.init(
            id: call.id,
            turnID: turnID,
            displayKind: .init(callKind: call.kind),
            title: call.displayName,
            subtitle: call.latestStatusText,
            status: call.status.rawValue,
            text: call.latestStatusText,
            path: call.filePath,
            serverName: call.serverName,
            toolName: call.toolName,
            isPayloadComplete: call.status != .inProgress,
            omittedPayloadCount: 0,
            isLowValueForResidency: false
        )
    }

    private static func title(for item: CodexThread.RecentTurns.TurnSnapshot.Item) -> String {
        if let command = item.command, !command.isEmpty {
            return command
        }
        if let path = item.path, !path.isEmpty {
            return path
        }
        if let serverName = item.serverName, let toolName = item.toolName {
            return "\(serverName).\(toolName)"
        }
        if let toolName = item.toolName, !toolName.isEmpty {
            return toolName
        }
        if let text = item.text, !text.isEmpty {
            return String(text.prefix(120))
        }
        return item.kind
    }
}

public enum TurnTimelineItemKind: String, Sendable, Equatable {
    case agentMessage
    case collabTool
    case command
    case dynamicTool
    case fileEdit
    case mcp
    case reasoning
    case unknown

    public init(rawKind: String) {
        switch rawKind {
        case "agentMessage":
            self = .agentMessage
        case "collabAgentToolCall":
            self = .collabTool
        case "commandExecution":
            self = .command
        case "dynamicToolCall":
            self = .dynamicTool
        case "fileChange":
            self = .fileEdit
        case "mcpToolCall":
            self = .mcp
        case "reasoning":
            self = .reasoning
        default:
            self = .unknown
        }
    }

    public init(callKind: CodexTurnHandle.Minimap.CallSnapshot.Kind) {
        switch callKind {
        case .collabTool:
            self = .collabTool
        case .command:
            self = .command
        case .dynamicTool:
            self = .dynamicTool
        case .fileEdit:
            self = .fileEdit
        case .mcp:
            self = .mcp
        }
    }
}

/// Renderer-neutral viewport hints for a timeline.
public struct TurnTimelineViewportState: Sendable, Equatable {
    public enum ScrollActivityPhase: String, Sendable, Equatable {
        case idle
        case tracking
        case interacting
        case decelerating
        case animating
    }

    public var visibleTurnIDs: [String]
    public var scrollAnchorTurnID: String?
    public var scrollActivityPhase: ScrollActivityPhase
    public var scrollVelocityPointsPerSecond: Double?

    public init(
        visibleTurnIDs: [String] = [],
        scrollAnchorTurnID: String? = nil,
        scrollActivityPhase: ScrollActivityPhase = .idle,
        scrollVelocityPointsPerSecond: Double? = nil
    ) {
        self.visibleTurnIDs = visibleTurnIDs
        self.scrollAnchorTurnID = scrollAnchorTurnID
        self.scrollActivityPhase = scrollActivityPhase
        self.scrollVelocityPointsPerSecond = scrollVelocityPointsPerSecond
    }

    @MainActor
    public init(recentTurns: CodexThread.RecentTurns) {
        self.init(
            visibleTurnIDs: recentTurns.visibleTurnIDs,
            scrollAnchorTurnID: recentTurns.scrollPositionTurnID,
            scrollActivityPhase: .init(recentTurns.scrollActivityPhase),
            scrollVelocityPointsPerSecond: recentTurns.scrollVelocityPointsPerSecond
        )
    }
}

extension TurnTimelineViewportState.ScrollActivityPhase {
    public init(_ phase: CodexThread.RecentTurns.ScrollActivityPhase) {
        switch phase {
        case .idle:
            self = .idle
        case .tracking:
            self = .tracking
        case .interacting:
            self = .interacting
        case .decelerating:
            self = .decelerating
        case .animating:
            self = .animating
        }
    }
}

public struct TurnTimelineTokenSummary: Sendable, Equatable {
    public var inputTokens: Int?
    public var outputTokens: Int?
    public var reasoningOutputTokens: Int?
    public var totalTokens: Int?
    public var modelContextWindow: Int?

    public init(
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        reasoningOutputTokens: Int? = nil,
        totalTokens: Int? = nil,
        modelContextWindow: Int? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.reasoningOutputTokens = reasoningOutputTokens
        self.totalTokens = totalTokens
        self.modelContextWindow = modelContextWindow
    }

    public init(tokenUsage: CodexThread.RecentTurns.TurnSnapshot.TokenUsage) {
        self.init(
            inputTokens: tokenUsage.inputTokens,
            outputTokens: tokenUsage.outputTokens,
            reasoningOutputTokens: tokenUsage.reasoningOutputTokens,
            totalTokens: tokenUsage.totalTokens,
            modelContextWindow: tokenUsage.modelContextWindow
        )
    }

}

public enum TurnTimelineIntent: Sendable, Equatable {
    case loadOlderTurns
    case loadNewerTurns
    case updateVisibleTurnIDs([String])
    case updateViewport(TurnTimelineViewportState)
    case selectItem(id: String?)
    case rehydratePayload(itemID: String)
}
