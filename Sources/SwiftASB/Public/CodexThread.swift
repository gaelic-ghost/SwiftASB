import Foundation
import Observation

public struct CodexThread: Sendable {
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

    public struct TurnStartRequest: Sendable, Equatable {
        public var approvalPolicy: CodexAppServer.ApprovalPolicy?
        public var approvalsReviewer: CodexAppServer.ApprovalsReviewer?
        public var currentDirectoryPath: String?
        public var effort: CodexAppServer.ReasoningEffort?
        public var input: [CodexAppServer.TurnInput]
        public var model: String?
        public var outputSchema: CodexAppServer.JSONValue?
        public var personality: CodexAppServer.Personality?
        public var serviceTier: CodexAppServer.ServiceTier?
        public var summary: CodexAppServer.ReasoningSummary?

        public init(
            input: [CodexAppServer.TurnInput],
            approvalPolicy: CodexAppServer.ApprovalPolicy? = nil,
            approvalsReviewer: CodexAppServer.ApprovalsReviewer? = nil,
            currentDirectoryPath: String? = nil,
            effort: CodexAppServer.ReasoningEffort? = nil,
            model: String? = nil,
            outputSchema: CodexAppServer.JSONValue? = nil,
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
            self.personality = personality
            self.serviceTier = serviceTier
            self.summary = summary
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
    public let reasoningEffort: CodexAppServer.ReasoningEffort?
    public let sandboxPolicy: CodexAppServer.SandboxPolicy
    public let serviceTier: CodexAppServer.ServiceTier?
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
        self.reasoningEffort = session.reasoningEffort
        self.sandboxPolicy = session.sandboxPolicy
        self.serviceTier = session.serviceTier
        self.events = events
    }

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
                personality: request.personality,
                serviceTier: request.serviceTier,
                summary: request.summary
            )
        )
    }

    public func startTextTurn(
        _ text: String,
        approvalPolicy: CodexAppServer.ApprovalPolicy? = nil,
        approvalsReviewer: CodexAppServer.ApprovalsReviewer? = nil,
        currentDirectoryPath: String? = nil,
        effort: CodexAppServer.ReasoningEffort? = nil,
        model: String? = nil,
        outputSchema: CodexAppServer.JSONValue? = nil,
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
                personality: personality,
                serviceTier: serviceTier,
                summary: summary
            )
        )
    }

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

    public func compactContext() async throws {
        try await appServer.compactThread(.init(threadID: id))
    }

    public func rollbackLastTurns(_ count: Int) async throws -> CodexThread {
        let threadInfo = try await appServer.rollbackThread(
            .init(threadID: id, numberOfTurns: count)
        )
        let events = await appServer.threadEventStream(threadID: id)
        return CodexThread(
            appServer: appServer,
            session: .init(
                approvalPolicy: approvalPolicy,
                approvalsReviewer: approvalsReviewer,
                currentDirectoryPath: currentDirectoryPath,
                instructionSources: instructionSources,
                model: model,
                modelProvider: modelProvider,
                reasoningEffort: reasoningEffort,
                sandboxPolicy: sandboxPolicy,
                serviceTier: serviceTier,
                thread: threadInfo
            ),
            events: events
        )
    }

    public func setName(_ name: String) async throws {
        try await appServer.setThreadName(.init(threadID: id, name: name))
    }

    public func updateMetadata(
        gitInfo: CodexAppServer.ThreadMetadataGitInfoUpdate
    ) async throws -> CodexAppServer.ThreadInfo {
        try await appServer.updateThreadMetadata(
            .init(threadID: id, gitInfo: gitInfo)
        )
    }

    public func readTurnHistory(turnID: String) async throws -> CodexTurnHandle.ClosedTurn? {
        try await appServer.closedTurn(threadID: id, turnID: turnID)
    }

    public func readRecentTurnHistoryWindow(
        limit: Int = 12
    ) async throws -> HistoryWindow {
        try await appServer.recentClosedTurnWindow(threadID: id, limit: limit)
    }

    public func readRecentTurnHistory(
        limit: Int = 12
    ) async throws -> [CodexTurnHandle.ClosedTurn] {
        try await readRecentTurnHistoryWindow(limit: limit).turns
    }

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

    public func readOlderTurnHistory(
        olderThan turnID: String,
        limit: Int = 12
    ) async throws -> [CodexTurnHandle.ClosedTurn] {
        try await readOlderTurnHistoryWindow(olderThan: turnID, limit: limit).turns
    }

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

    public func readNewerTurnHistory(
        newerThan turnID: String,
        limit: Int = 12
    ) async throws -> [CodexTurnHandle.ClosedTurn] {
        try await readNewerTurnHistoryWindow(newerThan: turnID, limit: limit).turns
    }

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
