import Foundation

public struct CodexTurnHandle: Sendable {
    public let threadID: String
    public let turn: CodexAppServer.TurnInfo
    public let events: AsyncThrowingStream<CodexTurnEvent, Error>

    internal init(
        threadID: String,
        turn: CodexAppServer.TurnInfo,
        events: AsyncThrowingStream<CodexTurnEvent, Error>
    ) {
        self.threadID = threadID
        self.turn = turn
        self.events = events
    }
}

public enum CodexTurnEvent: Sendable, Equatable {
    case completed(CodexTurnCompletion)
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
