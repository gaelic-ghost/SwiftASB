import Foundation
import Observation

public struct CodexThread: Sendable {
    /// A local-history window read from a thread.
    public struct HistoryWindow: Sendable, Equatable {
        public let threadID: String
        public let turns: [CodexTurnHandle.ClosedTurn]
        public let hasOlderTurns: Bool
        public let hasNewerTurns: Bool
        public let oldestTurnID: String?
        public let newestTurnID: String?

        internal init(
            threadID: String,
            turns: [CodexTurnHandle.ClosedTurn],
            hasOlderTurns: Bool,
            hasNewerTurns: Bool
        ) {
            self.threadID = threadID
            self.turns = turns
            self.hasOlderTurns = hasOlderTurns
            self.hasNewerTurns = hasNewerTurns
            self.oldestTurnID = turns.last?.id
            self.newestTurnID = turns.first?.id
        }
    }

    /// Repeatable local-history window intent for a thread.
    ///
    /// `HistoryWindowQD` describes the window a caller wants without exposing
    /// SwiftASB's Core Data-backed history store or app-server turn paging
    /// details. It currently targets the local completed-turn windows that
    /// SwiftASB can answer safely after history has been hydrated.
    public struct HistoryWindowQD: Sendable, Equatable {
        /// Anchor used to choose the local history window.
        public enum Anchor: Sendable, Equatable {
            case recent
            case olderThanTurn(String)
            case newerThanTurn(String)
            case aroundTurn(String)
            case aroundItem(String)
        }

        public var anchor: Anchor
        public var limit: Int

        /// Creates a local-history window descriptor.
        ///
        /// `limit` is normalized to at least `1` so the descriptor always asks
        /// for a meaningful window.
        public init(
            anchor: Anchor = .recent,
            limit: Int = 12
        ) {
            self.anchor = anchor
            self.limit = max(1, limit)
        }

        /// The newest known completed turns.
        public static func recent(limit: Int = 12) -> Self {
            .init(anchor: .recent, limit: limit)
        }

        /// Completed turns older than the known boundary turn.
        public static func olderThanTurn(
            _ turnID: String,
            limit: Int = 12
        ) -> Self {
            .init(anchor: .olderThanTurn(turnID), limit: limit)
        }

        /// Completed turns newer than the known boundary turn.
        public static func newerThanTurn(
            _ turnID: String,
            limit: Int = 12
        ) -> Self {
            .init(anchor: .newerThanTurn(turnID), limit: limit)
        }

        /// A completed-turn window centered around the known turn.
        public static func aroundTurn(
            _ turnID: String,
            limit: Int = 12
        ) -> Self {
            .init(anchor: .aroundTurn(turnID), limit: limit)
        }

        /// A completed-turn window centered around the turn containing the known item.
        public static func aroundItem(
            _ itemID: String,
            limit: Int = 12
        ) -> Self {
            .init(anchor: .aroundItem(itemID), limit: limit)
        }

        /// Returns the same query with a normalized window limit.
        public func limited(to limit: Int) -> Self {
            .init(anchor: anchor, limit: limit)
        }
    }

    /// Repeatable recent-file companion intent for a thread.
    ///
    /// `RecentFilesQD` describes the initial resident file-change window and
    /// cache policy without exposing SwiftASB's local history storage or
    /// observable companion construction details.
    public struct RecentFilesQD: Sendable, Equatable {
        public var cachePolicy: RecentFiles.CachePolicy?
        public var limit: Int

        /// Creates a recent-file descriptor.
        ///
        /// `limit` is normalized to at least `1`. Nil `cachePolicy` lets
        /// SwiftASB derive the companion's automatic cache policy from the
        /// normalized limit.
        public init(
            limit: Int = 12,
            cachePolicy: RecentFiles.CachePolicy? = nil
        ) {
            self.cachePolicy = cachePolicy
            self.limit = max(1, limit)
        }

        /// The newest known file-change items for this thread.
        public static func recent(
            limit: Int = 12,
            cachePolicy: RecentFiles.CachePolicy? = nil
        ) -> Self {
            .init(limit: limit, cachePolicy: cachePolicy)
        }

        /// Returns the same descriptor with a normalized resident limit.
        public func limited(to limit: Int) -> Self {
            .init(limit: limit, cachePolicy: cachePolicy)
        }

        /// Returns the same descriptor with an explicit cache policy.
        public func cached(by cachePolicy: RecentFiles.CachePolicy?) -> Self {
            .init(limit: limit, cachePolicy: cachePolicy)
        }
    }

    /// Repeatable recent-command companion intent for a thread.
    ///
    /// `RecentCommandsQD` describes the initial resident command-output window
    /// and cache policy without exposing SwiftASB's local history storage or
    /// observable companion construction details.
    public struct RecentCommandsQD: Sendable, Equatable {
        public var cachePolicy: RecentCommands.CachePolicy?
        public var limit: Int

        /// Creates a recent-command descriptor.
        ///
        /// `limit` is normalized to at least `1`. Nil `cachePolicy` lets
        /// SwiftASB derive the companion's automatic cache policy from the
        /// normalized limit.
        public init(
            limit: Int = 12,
            cachePolicy: RecentCommands.CachePolicy? = nil
        ) {
            self.cachePolicy = cachePolicy
            self.limit = max(1, limit)
        }

        /// The newest known command-output items for this thread.
        public static func recent(
            limit: Int = 12,
            cachePolicy: RecentCommands.CachePolicy? = nil
        ) -> Self {
            .init(limit: limit, cachePolicy: cachePolicy)
        }

        /// Returns the same descriptor with a normalized resident limit.
        public func limited(to limit: Int) -> Self {
            .init(limit: limit, cachePolicy: cachePolicy)
        }

        /// Returns the same descriptor with an explicit cache policy.
        public func cached(by cachePolicy: RecentCommands.CachePolicy?) -> Self {
            .init(limit: limit, cachePolicy: cachePolicy)
        }
    }

    /// Request used to start a turn from this thread handle.
    public struct TurnStartRequest: Sendable, Equatable {
        public var approvalPolicy: CodexAppServer.ApprovalPolicy?
        public var approvalsReviewer: CodexAppServer.ApprovalsReviewer?
        public var currentDirectoryPath: String?
        public var effort: CodexAppServer.ReasoningEffort?
        public var input: [CodexAppServer.TurnInput]
        public var model: String?
        public var outputSchema: CodexAppServer.JSONValue?
        public var permissions: CodexWorkspace.PermissionSelection?
        public var personality: CodexAppServer.Personality?
        public var serviceTier: CodexAppServer.ServiceTier?
        public var summary: CodexAppServer.ReasoningSummary?

        /// Creates a thread-scoped turn-start request.
        ///
        /// Nil option fields are omitted from the app-server request so the
        /// turn inherits this thread's defaults. Provide values only for the
        /// settings that should differ for this turn.
        public init(
            input: [CodexAppServer.TurnInput],
            approvalPolicy: CodexAppServer.ApprovalPolicy? = nil,
            approvalsReviewer: CodexAppServer.ApprovalsReviewer? = nil,
            currentDirectoryPath: String? = nil,
            effort: CodexAppServer.ReasoningEffort? = nil,
            model: String? = nil,
            outputSchema: CodexAppServer.JSONValue? = nil,
            permissions: CodexWorkspace.PermissionSelection? = nil,
            personality: CodexAppServer.Personality? = nil,
            serviceTier: CodexAppServer.ServiceTier? = nil,
            summary: CodexAppServer.ReasoningSummary? = nil
        ) {
            self.input = input
            self.approvalPolicy = approvalPolicy
            self.approvalsReviewer = approvalsReviewer
            self.currentDirectoryPath = currentDirectoryPath
            self.effort = effort
            self.model = model
            self.outputSchema = outputSchema
            self.permissions = permissions
            self.personality = personality
            self.serviceTier = serviceTier
            self.summary = summary
        }
    }

    /// Goal state stored by the app-server for this thread.
    public struct Goal: Sendable, Equatable {
        /// App-server goal status.
        public enum Status: String, Sendable, Equatable {
            case active
            case budgetLimited
            case complete
            case paused
        }

        public let createdAt: Int
        public let objective: String
        public let status: Status
        public let threadID: String
        public let timeUsedSeconds: Int
        public let tokenBudget: Int?
        public let tokensUsed: Int
        public let updatedAt: Int
    }

    /// Request used to create or update a thread goal.
    public struct GoalSetRequest: Sendable, Equatable {
        public var objective: String?
        public var status: Goal.Status?
        public var tokenBudget: Int?

        /// Creates a goal update request.
        ///
        /// Nil fields are omitted so callers can update one part of the goal
        /// without re-sending the complete state.
        public init(
            objective: String? = nil,
            status: Goal.Status? = nil,
            tokenBudget: Int? = nil
        ) {
            self.objective = objective
            self.status = status
            self.tokenBudget = tokenBudget
        }
    }

    public let id: String
    public let info: CodexAppServer.ThreadInfo
    public let approvalPolicy: CodexAppServer.ApprovalPolicy
    public let approvalsReviewer: CodexAppServer.ApprovalsReviewer
    public let currentDirectoryPath: String
    public let instructionSources: [String]
    public let model: String
    public let modelProvider: String
    public let activePermissionProfile: CodexWorkspace.ActivePermissionProfile?
    public let permissionProfile: CodexWorkspace.PermissionProfile?
    public let reasoningEffort: CodexAppServer.ReasoningEffort?
    public let sandboxPolicy: CodexAppServer.SandboxPolicy
    public let serviceTier: CodexAppServer.ServiceTier?
    public let workspace: CodexWorkspace.SessionSnapshot

    /// Typed events for this thread.
    ///
    /// Thread events are buffered until the handle's stream is observed, then
    /// delivered in order. Terminal thread events, such as close, are delivered
    /// before the stream finishes. The stream finishes normally when SwiftASB
    /// stops the app-server and finishes by throwing when the underlying
    /// app-server event feed fails unexpectedly.
    public let events: AsyncThrowingStream<CodexThreadEvent, Error>

    private let appServer: CodexAppServer

    internal init(
        appServer: CodexAppServer,
        session: CodexAppServer.ThreadSession,
        events: AsyncThrowingStream<CodexThreadEvent, Error>
    ) {
        self.appServer = appServer
        self.id = session.thread.id
        self.info = session.thread
        self.approvalPolicy = session.approvalPolicy
        self.approvalsReviewer = session.approvalsReviewer
        self.currentDirectoryPath = session.currentDirectoryPath
        self.instructionSources = session.instructionSources
        self.model = session.model
        self.modelProvider = session.modelProvider
        self.activePermissionProfile = session.activePermissionProfile
        self.permissionProfile = session.permissionProfile
        self.reasoningEffort = session.reasoningEffort
        self.sandboxPolicy = session.sandboxPolicy
        self.serviceTier = session.serviceTier
        self.workspace = session.workspace
        self.events = events
    }

    /// Starts a turn from a fully-shaped request.
    public func startTurn(_ request: TurnStartRequest) async throws -> CodexTurnHandle {
        try await appServer.startTurn(
            .init(
                threadID: id,
                input: request.input,
                approvalPolicy: request.approvalPolicy,
                approvalsReviewer: request.approvalsReviewer,
                currentDirectoryPath: request.currentDirectoryPath,
                effort: request.effort,
                model: request.model,
                outputSchema: request.outputSchema,
                permissions: request.permissions,
                personality: request.personality,
                serviceTier: request.serviceTier,
                summary: request.summary
            )
        )
    }

    /// Starts a turn containing one text input item.
    ///
    /// Nil option fields inherit this thread's defaults for the new turn.
    public func startTextTurn(
        _ text: String,
        approvalPolicy: CodexAppServer.ApprovalPolicy? = nil,
        approvalsReviewer: CodexAppServer.ApprovalsReviewer? = nil,
        currentDirectoryPath: String? = nil,
        effort: CodexAppServer.ReasoningEffort? = nil,
        model: String? = nil,
        outputSchema: CodexAppServer.JSONValue? = nil,
        permissions: CodexWorkspace.PermissionSelection? = nil,
        personality: CodexAppServer.Personality? = nil,
        serviceTier: CodexAppServer.ServiceTier? = nil,
        summary: CodexAppServer.ReasoningSummary? = nil
    ) async throws -> CodexTurnHandle {
        try await startTurn(
            .init(
                input: [.text(text)],
                approvalPolicy: approvalPolicy,
                approvalsReviewer: approvalsReviewer,
                currentDirectoryPath: currentDirectoryPath,
                effort: effort,
                model: model,
                outputSchema: outputSchema,
                permissions: permissions,
                personality: personality,
                serviceTier: serviceTier,
                summary: summary
            )
        )
    }

    /// Creates an observable dashboard for this thread.
    ///
    /// The dashboard consumes the thread event stream plus live aggregate
    /// activity updates. It is a current-state mirror rather than a replayable
    /// event log; activity updates that arrive before the dashboard exists are
    /// represented only by the initial activity snapshot.
    @MainActor
    public func makeDashboard() async -> Dashboard {
        let events = await appServer.threadEventStream(threadID: id)
        let initialActivityState = await appServer.threadObservableActivityState(threadID: id)
        let activityUpdates = await appServer.threadObservableActivityStream(threadID: id)
        return Dashboard(
            threadID: id,
            initialInfo: info,
            events: events,
            initialActivityState: initialActivityState,
            activityUpdates: activityUpdates
        )
    }

    /// Asks the app-server to compact this thread's context.
    ///
    /// Dashboard and minimap companions mirror compaction activity when the
    /// runtime emits item lifecycle events for that work.
    public func compactContext() async throws {
        try await appServer.compactThread(.init(threadID: id))
    }

    /// Rolls back trailing turns from this stored thread.
    ///
    /// The returned handle carries refreshed thread metadata and a fresh event
    /// stream. SwiftASB records a local rollback marker but does not preserve a
    /// full archive of removed turn payloads.
    public func rollbackLastTurns(_ count: Int) async throws -> CodexThread {
        let threadInfo = try await appServer.rollbackThread(
            .init(threadID: id, numberOfTurns: count)
        )
        let events = await appServer.threadEventStream(threadID: id)
        return CodexThread(
            appServer: appServer,
            session: .init(
                activePermissionProfile: activePermissionProfile,
                approvalPolicy: approvalPolicy,
                approvalsReviewer: approvalsReviewer,
                currentDirectoryPath: currentDirectoryPath,
                instructionSources: instructionSources,
                model: model,
                modelProvider: modelProvider,
                permissionProfile: permissionProfile,
                reasoningEffort: reasoningEffort,
                sandboxPolicy: sandboxPolicy,
                serviceTier: serviceTier,
                thread: threadInfo
            ),
            events: events
        )
    }

    /// Sets the stored human-readable name for this thread.
    public func setName(_ name: String) async throws {
        try await appServer.setThreadName(.init(threadID: id, name: name))
    }

    /// Archives this stored thread.
    public func archive() async throws {
        try await appServer.archiveThread(.init(threadID: id))
    }

    /// Unarchives this stored thread and returns refreshed thread metadata.
    @discardableResult
    public func unarchive() async throws -> CodexAppServer.ThreadInfo {
        try await appServer.unarchiveThread(.init(threadID: id))
    }

    /// Patches this thread's stored Git metadata.
    ///
    /// Each field in `gitInfo` can replace, clear, or leave the corresponding
    /// app-server value unchanged.
    public func updateMetadata(
        gitInfo: CodexAppServer.ThreadMetadataGitInfoUpdate
    ) async throws -> CodexAppServer.ThreadInfo {
        try await appServer.updateThreadMetadata(
            .init(threadID: id, gitInfo: gitInfo)
        )
    }

    /// Reads the current app-server goal for this thread, when one is set.
    public func readGoal() async throws -> Goal? {
        try await appServer.readThreadGoal(threadID: id)
    }

    /// Creates or updates this thread's app-server goal.
    public func setGoal(_ request: GoalSetRequest) async throws -> Goal {
        try await appServer.setThreadGoal(threadID: id, request: request)
    }

    /// Clears this thread's app-server goal.
    public func clearGoal() async throws -> Bool {
        try await appServer.clearThreadGoal(threadID: id)
    }

    /// Reads one completed turn from SwiftASB's local history store.
    ///
    /// Returns `nil` when the turn has not been persisted or hydrated locally.
    public func readTurnHistory(turnID: String) async throws -> CodexTurnHandle.ClosedTurn? {
        try await appServer.closedTurn(threadID: id, turnID: turnID)
    }

    /// Reads the most recent completed turns from local history.
    ///
    /// The default `limit` of 12 is a SwiftASB convenience for compact UI
    /// summaries; pass a different limit when the caller owns the paging size.
    public func readRecentTurnHistoryWindow(
        limit: Int = 12
    ) async throws -> HistoryWindow {
        try await appServer.recentClosedTurnWindow(threadID: id, limit: limit)
    }

    /// Reads a local completed-turn history window from a SwiftASB descriptor.
    ///
    /// Use descriptor reads when UI state or inspection tools need to preserve
    /// a repeatable window intent, then issue it again after local history has
    /// been refreshed or a selection changes.
    public func readHistoryWindow(_ query: HistoryWindowQD = .recent()) async throws -> HistoryWindow {
        switch query.anchor {
        case .recent:
            try await readRecentTurnHistoryWindow(limit: query.limit)
        case let .olderThanTurn(turnID):
            try await readOlderTurnHistoryWindow(olderThan: turnID, limit: query.limit)
        case let .newerThanTurn(turnID):
            try await readNewerTurnHistoryWindow(newerThan: turnID, limit: query.limit)
        case let .aroundTurn(turnID):
            try await windowAroundTurn(turnID, limit: query.limit)
        case let .aroundItem(itemID):
            try await windowAroundItem(itemID, limit: query.limit)
        }
    }

    /// Reads the most recent completed turns from local history.
    ///
    /// The default `limit` of 12 matches `readRecentTurnHistoryWindow(limit:)`.
    public func readRecentTurnHistory(
        limit: Int = 12
    ) async throws -> [CodexTurnHandle.ClosedTurn] {
        try await readRecentTurnHistoryWindow(limit: limit).turns
    }

    /// Reads a page of completed turns older than the given turn.
    ///
    /// The default `limit` of 12 is a SwiftASB local-history page size.
    public func readOlderTurnHistoryWindow(
        olderThan turnID: String,
        limit: Int = 12
    ) async throws -> HistoryWindow {
        try await appServer.olderClosedTurnWindow(
            threadID: id,
            olderThan: turnID,
            limit: limit
        )
    }

    /// Reads completed turns older than the given turn.
    ///
    /// The default `limit` of 12 matches `readOlderTurnHistoryWindow(olderThan:limit:)`.
    public func readOlderTurnHistory(
        olderThan turnID: String,
        limit: Int = 12
    ) async throws -> [CodexTurnHandle.ClosedTurn] {
        try await readOlderTurnHistoryWindow(olderThan: turnID, limit: limit).turns
    }

    /// Reads a page of completed turns newer than the given turn.
    ///
    /// The default `limit` of 12 is a SwiftASB local-history page size.
    public func readNewerTurnHistoryWindow(
        newerThan turnID: String,
        limit: Int = 12
    ) async throws -> HistoryWindow {
        try await appServer.newerClosedTurnWindow(
            threadID: id,
            newerThan: turnID,
            limit: limit
        )
    }

    /// Reads completed turns newer than the given turn.
    ///
    /// The default `limit` of 12 matches `readNewerTurnHistoryWindow(newerThan:limit:)`.
    public func readNewerTurnHistory(
        newerThan turnID: String,
        limit: Int = 12
    ) async throws -> [CodexTurnHandle.ClosedTurn] {
        try await readNewerTurnHistoryWindow(newerThan: turnID, limit: limit).turns
    }

    /// Reads a local-history window centered around a turn.
    ///
    /// The default `limit` of 12 is a SwiftASB local-history page size.
    public func windowAroundTurn(
        _ turnID: String,
        limit: Int = 12
    ) async throws -> HistoryWindow {
        try await appServer.closedTurnWindowAroundTurn(
            threadID: id,
            turnID: turnID,
            limit: limit
        )
    }

    /// Reads a local-history window centered around an item.
    ///
    /// The default `limit` of 12 is a SwiftASB local-history page size.
    public func windowAroundItem(
        _ itemID: String,
        limit: Int = 12
    ) async throws -> HistoryWindow {
        try await appServer.closedTurnWindowAroundItem(
            threadID: id,
            itemID: itemID,
            limit: limit
        )
    }

    /// Creates an observable recent-turn companion for this thread.
    ///
    /// The default `limit` of 12 controls the initial resident page. Omitting
    /// `cachePolicy` derives SwiftASB's automatic cache policy from that limit.
    /// The companion listens to this thread's live turn-event feed as a
    /// current-state mirror; it records load errors on the companion and stops
    /// updating when the event feed finishes.
    @MainActor
    public func makeRecentTurns(
        limit: Int = 12,
        cachePolicy: RecentTurns.CachePolicy? = nil
    ) async throws -> RecentTurns {
        let window = try await appServer.recentTurnWindow(threadID: id, limit: limit)
        let events = await appServer.threadTurnEventStream(threadID: id)
        return RecentTurns(
            cachePolicy: cachePolicy ?? .automatic(pageSize: limit),
            threadID: id,
            residentLimit: limit,
            nextNewerCursor: window.nextNewerCursor,
            nextOlderCursor: window.nextOlderCursor,
            initialTurns: window.turns.map(RecentTurns.TurnSnapshot.init),
            events: events,
            appServer: appServer
        )
    }

    /// Creates an observable recent-file companion for this thread.
    ///
    /// The default `limit` of 12 controls the initial resident page. Omitting
    /// `cachePolicy` derives SwiftASB's automatic cache policy from that limit.
    /// The companion listens to live turn events and file-output deltas as a
    /// current-state mirror; missed file deltas are not replayed after the
    /// stream is created.
    @MainActor
    public func makeRecentFiles(
        limit: Int = 12,
        cachePolicy: RecentFiles.CachePolicy? = nil
    ) async throws -> RecentFiles {
        let window = try await appServer.recentFileWindow(threadID: id, limit: limit)
        let turnEvents = await appServer.threadTurnEventStream(threadID: id)
        let fileDeltaEvents = await appServer.threadFileChangeOutputDeltaStream(threadID: id)
        return RecentFiles(
            cachePolicy: cachePolicy ?? .automatic(pageSize: limit),
            threadID: id,
            residentLimit: limit,
            nextOlderCursor: window.nextOlderCursor,
            initialFiles: window.files.map(RecentFiles.FileSnapshot.init),
            turnEvents: turnEvents,
            fileDeltaEvents: fileDeltaEvents,
            appServer: appServer
        )
    }

    /// Creates an observable recent-file companion from a repeatable descriptor.
    @MainActor
    public func makeRecentFiles(_ query: RecentFilesQD) async throws -> RecentFiles {
        try await makeRecentFiles(limit: query.limit, cachePolicy: query.cachePolicy)
    }

    /// Creates an observable recent-command companion for this thread.
    ///
    /// The default `limit` of 12 controls the initial resident page. Omitting
    /// `cachePolicy` derives SwiftASB's automatic cache policy from that limit.
    /// The companion listens to live turn events and command-output deltas as a
    /// current-state mirror; missed command deltas are not replayed after the
    /// stream is created.
    @MainActor
    public func makeRecentCommands(
        limit: Int = 12,
        cachePolicy: RecentCommands.CachePolicy? = nil
    ) async throws -> RecentCommands {
        let window = try await appServer.recentCommandWindow(threadID: id, limit: limit)
        let turnEvents = await appServer.threadTurnEventStream(threadID: id)
        let commandDeltaEvents = await appServer.threadCommandExecutionOutputDeltaStream(threadID: id)
        return RecentCommands(
            cachePolicy: cachePolicy ?? .automatic(pageSize: limit),
            threadID: id,
            residentLimit: limit,
            nextOlderCursor: window.nextOlderCursor,
            initialCommands: window.commands.map(RecentCommands.CommandSnapshot.init),
            turnEvents: turnEvents,
            commandDeltaEvents: commandDeltaEvents,
            appServer: appServer
        )
    }

    /// Creates an observable recent-command companion from a repeatable descriptor.
    @MainActor
    public func makeRecentCommands(_ query: RecentCommandsQD) async throws -> RecentCommands {
        try await makeRecentCommands(limit: query.limit, cachePolicy: query.cachePolicy)
    }

    /// Answers a thread-routed approval request.
    ///
    /// SwiftASB rejects responses for requests that belong to another thread or
    /// to an active turn-specific route.
    public func respond(
        to request: CodexApprovalRequest,
        with response: CodexApprovalResponse
    ) async throws {
        try await appServer.respond(
            to: request,
            with: response,
            expectedThreadID: id,
            expectedTurnID: nil
        )
    }

    /// Answers a thread-routed elicitation request.
    ///
    /// SwiftASB rejects responses for requests that belong to another thread or
    /// to an active turn-specific route.
    public func respond(
        to request: CodexElicitationRequest,
        with response: CodexElicitationResponse
    ) async throws {
        try await appServer.respond(
            to: request,
            with: response,
            expectedThreadID: id,
            expectedTurnID: nil
        )
    }

}

public enum CodexThreadEvent: Sendable, Equatable {
    case started(CodexThreadStarted)
    case statusChanged(CodexThreadStatusChanged)
    case diagnostic(CodexDiagnosticEvent)
    case approvalRequested(CodexApprovalRequest)
    case elicitationRequested(CodexElicitationRequest)
    case serverRequestResolved(CodexInteractiveRequestResolved)
    case archived(CodexThreadArchived)
    case unarchived(CodexThreadUnarchived)
    case closed(CodexThreadClosed)
    case nameUpdated(CodexThreadNameUpdated)
    case tokenUsageUpdated(CodexThreadTokenUsageUpdated)
    case goalUpdated(CodexThreadGoalUpdated)
    case goalCleared(CodexThreadGoalCleared)
}

public struct CodexThreadStarted: Sendable, Equatable {
    public let thread: CodexAppServer.ThreadInfo

    internal init(thread: CodexAppServer.ThreadInfo) {
        self.thread = thread
    }
}

public struct CodexThreadStatusChanged: Sendable, Equatable {
    public let threadID: String
    public let status: CodexAppServer.ThreadStatus

    internal init(
        threadID: String,
        status: CodexAppServer.ThreadStatus
    ) {
        self.threadID = threadID
        self.status = status
    }
}

public struct CodexThreadNameUpdated: Sendable, Equatable {
    public let threadID: String
    public let threadName: String?

    internal init(
        threadID: String,
        threadName: String?
    ) {
        self.threadID = threadID
        self.threadName = threadName
    }
}

public struct CodexThreadArchived: Sendable, Equatable {
    public let threadID: String

    internal init(threadID: String) {
        self.threadID = threadID
    }
}

public struct CodexThreadUnarchived: Sendable, Equatable {
    public let threadID: String

    internal init(threadID: String) {
        self.threadID = threadID
    }
}

public struct CodexThreadClosed: Sendable, Equatable {
    public let threadID: String

    internal init(threadID: String) {
        self.threadID = threadID
    }
}

public struct CodexThreadTokenUsageUpdated: Sendable, Equatable {
    public struct Usage: Sendable, Equatable {
        public let cachedInputTokens: Int
        public let inputTokens: Int
        public let outputTokens: Int
        public let reasoningOutputTokens: Int
        public let totalTokens: Int

        internal init(
            cachedInputTokens: Int,
            inputTokens: Int,
            outputTokens: Int,
            reasoningOutputTokens: Int,
            totalTokens: Int
        ) {
            self.cachedInputTokens = cachedInputTokens
            self.inputTokens = inputTokens
            self.outputTokens = outputTokens
            self.reasoningOutputTokens = reasoningOutputTokens
            self.totalTokens = totalTokens
        }
    }

    public let threadID: String
    public let turnID: String
    public let last: Usage
    public let modelContextWindow: Int?
    public let total: Usage

    internal init(
        threadID: String,
        turnID: String,
        last: Usage,
        modelContextWindow: Int?,
        total: Usage
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.last = last
        self.modelContextWindow = modelContextWindow
        self.total = total
    }
}

public struct CodexThreadGoalUpdated: Sendable, Equatable {
    public let threadID: String
    public let turnID: String?
    public let goal: CodexThread.Goal

    internal init(
        threadID: String,
        turnID: String?,
        goal: CodexThread.Goal
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.goal = goal
    }
}

public struct CodexThreadGoalCleared: Sendable, Equatable {
    public let threadID: String

    internal init(threadID: String) {
        self.threadID = threadID
    }
}

extension CodexThread.Goal {
    init(wireValue: CodexWireThreadGoal) {
        self.init(
            createdAt: wireValue.createdAt,
            objective: wireValue.objective,
            status: .init(wireValue: wireValue.status),
            threadID: wireValue.threadID,
            timeUsedSeconds: wireValue.timeUsedSeconds,
            tokenBudget: wireValue.tokenBudget,
            tokensUsed: wireValue.tokensUsed,
            updatedAt: wireValue.updatedAt
        )
    }
}

extension CodexThread.Goal.Status {
    init(wireValue: CodexWireThreadGoalStatus) {
        switch wireValue {
        case .active:
            self = .active
        case .budgetLimited:
            self = .budgetLimited
        case .complete:
            self = .complete
        case .paused:
            self = .paused
        }
    }

    var wireValue: CodexWireThreadGoalStatus {
        switch self {
        case .active:
            .active
        case .budgetLimited:
            .budgetLimited
        case .complete:
            .complete
        case .paused:
            .paused
        }
    }
}
