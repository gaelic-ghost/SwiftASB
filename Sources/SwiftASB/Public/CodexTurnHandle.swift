import Foundation

public struct CodexTurnHandle: Sendable {
    private let appServer: CodexAppServer
    public let threadID: String
    public let turn: CodexAppServer.TurnInfo
    public let events: AsyncThrowingStream<CodexTurnEvent, Error>

    internal init(
        appServer: CodexAppServer,
        threadID: String,
        turn: CodexAppServer.TurnInfo,
        events: AsyncThrowingStream<CodexTurnEvent, Error>
    ) {
        self.appServer = appServer
        self.threadID = threadID
        self.turn = turn
        self.events = events
    }

    public func waitForCompletion() async throws -> CodexTurnCompletion {
        try await waitForEvent(named: "completion event") { event in
            guard case let .completed(completion) = event else { return nil }
            return completion
        }
    }

    public func waitForNextAgentMessageDelta() async throws -> CodexTurnAgentMessageDelta {
        try await waitForEvent(named: "agent message delta") { event in
            guard case let .agentMessageDelta(delta) = event else { return nil }
            return delta
        }
    }

    public func waitForNextPlanUpdate() async throws -> CodexTurnPlanUpdate {
        try await waitForEvent(named: "plan update") { event in
            guard case let .planUpdated(update) = event else { return nil }
            return update
        }
    }

    public func waitForNextReasoningTextDelta() async throws -> CodexTurnReasoningTextDelta {
        try await waitForEvent(named: "reasoning text delta") { event in
            guard case let .reasoningTextDelta(delta) = event else { return nil }
            return delta
        }
    }

    private func waitForEvent<Event>(
        named eventName: String,
        matching transform: @Sendable (CodexTurnEvent) -> Event?
    ) async throws -> Event {
        let stream = await appServer.turnEventStream(turnID: turn.id)
        var iterator = stream.makeAsyncIterator()

        while let event = try await iterator.next() {
            if let transformed = transform(event) {
                return transformed
            }
        }

        throw CodexAppServerError.transportFailure(
            operation: "turn event wait",
            reason: "Codex app-server stopped delivering turn events before the next \(eventName) for turn \(turn.id) arrived."
        )
    }
}

public enum CodexTurnEvent: Sendable, Equatable {
    case started(CodexTurnStarted)
    case planUpdated(CodexTurnPlanUpdate)
    case planDelta(CodexTurnPlanDelta)
    case diffUpdated(CodexTurnDiffUpdate)
    case itemStarted(CodexTurnItemStarted)
    case itemCompleted(CodexTurnItemCompleted)
    case agentMessageDelta(CodexTurnAgentMessageDelta)
    case reasoningSummaryPartAdded(CodexTurnReasoningSummaryPartAdded)
    case reasoningSummaryTextDelta(CodexTurnReasoningSummaryTextDelta)
    case reasoningTextDelta(CodexTurnReasoningTextDelta)
    case completed(CodexTurnCompletion)
}

public struct CodexTurnStarted: Sendable, Equatable {
    public let threadID: String
    public let turn: CodexAppServer.TurnInfo

    internal init(
        threadID: String,
        turn: CodexAppServer.TurnInfo
    ) {
        self.threadID = threadID
        self.turn = turn
    }
}

public struct CodexTurnPlanUpdate: Sendable, Equatable {
    public struct Step: Sendable, Equatable {
        public enum Status: String, Sendable, Equatable {
            case completed
            case inProgress
            case pending
        }

        public let status: Status
        public let step: String

        internal init(
            status: Status,
            step: String
        ) {
            self.status = status
            self.step = step
        }
    }

    public let threadID: String
    public let turnID: String
    public let explanation: String?
    public let plan: [Step]

    internal init(
        threadID: String,
        turnID: String,
        explanation: String?,
        plan: [Step]
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.explanation = explanation
        self.plan = plan
    }
}

public struct CodexTurnPlanDelta: Sendable, Equatable {
    public let threadID: String
    public let turnID: String
    public let itemID: String
    public let delta: String

    internal init(
        threadID: String,
        turnID: String,
        itemID: String,
        delta: String
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.itemID = itemID
        self.delta = delta
    }
}

public struct CodexTurnDiffUpdate: Sendable, Equatable {
    public let threadID: String
    public let turnID: String
    public let diff: String

    internal init(
        threadID: String,
        turnID: String,
        diff: String
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.diff = diff
    }
}

public struct CodexTurnItem: Sendable, Equatable {
    public enum Kind: String, Sendable, Equatable {
        case agentMessage
        case collabAgentToolCall
        case commandExecution
        case contextCompaction
        case dynamicToolCall
        case enteredReviewMode
        case exitedReviewMode
        case fileChange
        case hookPrompt
        case imageGeneration
        case imageView
        case mcpToolCall
        case plan
        case reasoning
        case userMessage
        case webSearch
    }

    public let id: String
    public let kind: Kind
    public let text: String?
    public let status: String?

    internal init(
        id: String,
        kind: Kind,
        text: String?,
        status: String?
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.status = status
    }
}

public struct CodexTurnItemStarted: Sendable, Equatable {
    public let threadID: String
    public let turnID: String
    public let item: CodexTurnItem

    internal init(
        threadID: String,
        turnID: String,
        item: CodexTurnItem
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.item = item
    }
}

public struct CodexTurnItemCompleted: Sendable, Equatable {
    public let threadID: String
    public let turnID: String
    public let item: CodexTurnItem

    internal init(
        threadID: String,
        turnID: String,
        item: CodexTurnItem
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.item = item
    }
}

public struct CodexTurnAgentMessageDelta: Sendable, Equatable {
    public let threadID: String
    public let turnID: String
    public let itemID: String
    public let delta: String

    internal init(
        threadID: String,
        turnID: String,
        itemID: String,
        delta: String
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.itemID = itemID
        self.delta = delta
    }
}

public struct CodexTurnReasoningSummaryPartAdded: Sendable, Equatable {
    public let threadID: String
    public let turnID: String
    public let itemID: String
    public let summaryIndex: Int

    internal init(
        threadID: String,
        turnID: String,
        itemID: String,
        summaryIndex: Int
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.itemID = itemID
        self.summaryIndex = summaryIndex
    }
}

public struct CodexTurnReasoningSummaryTextDelta: Sendable, Equatable {
    public let threadID: String
    public let turnID: String
    public let itemID: String
    public let summaryIndex: Int
    public let delta: String

    internal init(
        threadID: String,
        turnID: String,
        itemID: String,
        summaryIndex: Int,
        delta: String
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.itemID = itemID
        self.summaryIndex = summaryIndex
        self.delta = delta
    }
}

public struct CodexTurnReasoningTextDelta: Sendable, Equatable {
    public let threadID: String
    public let turnID: String
    public let itemID: String
    public let contentIndex: Int
    public let delta: String

    internal init(
        threadID: String,
        turnID: String,
        itemID: String,
        contentIndex: Int,
        delta: String
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.itemID = itemID
        self.contentIndex = contentIndex
        self.delta = delta
    }
}

public struct CodexTurnCompletion: Sendable, Equatable {
    public let threadID: String
    public let turn: CodexAppServer.TurnInfo

    internal init(
        threadID: String,
        turn: CodexAppServer.TurnInfo
    ) {
        self.threadID = threadID
        self.turn = turn
    }
}
