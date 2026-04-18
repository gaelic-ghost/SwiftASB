import Foundation
import Observation

public struct CodexTurnHandle: Sendable {
    @MainActor
    @Observable
    public final class Minimap {
        public let threadID: String
        public let turnID: String
        public private(set) var currentTurn: CodexAppServer.TurnInfo
        public private(set) var latestAgentMessageDelta: CodexTurnAgentMessageDelta?
        public private(set) var latestCompletedItem: CodexTurnItemCompleted?
        public private(set) var latestCompletion: CodexTurnCompletion?
        public private(set) var latestDiffUpdate: CodexTurnDiffUpdate?
        public private(set) var latestPlanDelta: CodexTurnPlanDelta?
        public private(set) var latestPlanUpdate: CodexTurnPlanUpdate?
        public private(set) var latestReasoningSummaryPartAdded: CodexTurnReasoningSummaryPartAdded?
        public private(set) var latestReasoningSummaryTextDelta: CodexTurnReasoningSummaryTextDelta?
        public private(set) var latestReasoningTextDelta: CodexTurnReasoningTextDelta?
        public private(set) var latestStartedItem: CodexTurnItemStarted?
        public private(set) var latestStartedTurn: CodexTurnStarted?

        @ObservationIgnored
        private var eventTask: Task<Void, Never>?

        internal init(
            threadID: String,
            initialTurn: CodexAppServer.TurnInfo,
            events: AsyncThrowingStream<CodexTurnEvent, Error>
        ) {
            self.threadID = threadID
            self.turnID = initialTurn.id
            self.currentTurn = initialTurn
            self.latestAgentMessageDelta = nil
            self.latestCompletedItem = nil
            self.latestCompletion = nil
            self.latestDiffUpdate = nil
            self.latestPlanDelta = nil
            self.latestPlanUpdate = nil
            self.latestReasoningSummaryPartAdded = nil
            self.latestReasoningSummaryTextDelta = nil
            self.latestReasoningTextDelta = nil
            self.latestStartedItem = nil
            self.latestStartedTurn = nil

            eventTask = Task { [weak self] in
                guard let self else { return }

                do {
                    for try await event in events {
                        self.apply(event)
                    }
                } catch is CancellationError {
                    return
                } catch {
                    return
                }
            }
        }

        deinit {
            eventTask?.cancel()
        }

        private func apply(_ event: CodexTurnEvent) {
            switch event {
            case let .started(started):
                latestStartedTurn = started
                currentTurn = started.turn
            case let .planUpdated(update):
                latestPlanUpdate = update
            case let .planDelta(delta):
                latestPlanDelta = delta
            case let .diffUpdated(update):
                latestDiffUpdate = update
            case let .itemStarted(itemStarted):
                latestStartedItem = itemStarted
            case let .itemCompleted(itemCompleted):
                latestCompletedItem = itemCompleted
            case let .agentMessageDelta(delta):
                latestAgentMessageDelta = delta
            case let .reasoningSummaryPartAdded(partAdded):
                latestReasoningSummaryPartAdded = partAdded
            case let .reasoningSummaryTextDelta(delta):
                latestReasoningSummaryTextDelta = delta
            case let .reasoningTextDelta(delta):
                latestReasoningTextDelta = delta
            case let .completed(completion):
                latestCompletion = completion
                currentTurn = completion.turn
            }
        }
    }

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

    @MainActor
    public func makeMinimap() async -> Minimap {
        let events = await appServer.turnEventStream(turnID: turn.id)
        return Minimap(
            threadID: threadID,
            initialTurn: turn,
            events: events
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
