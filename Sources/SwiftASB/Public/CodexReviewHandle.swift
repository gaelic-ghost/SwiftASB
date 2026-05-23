import Foundation

/// Handle returned after starting an app-server code review.
public struct CodexReviewHandle: Sendable {
    /// The thread that requested the review.
    public let sourceThreadID: String
    /// The thread where the review turn runs.
    public let reviewThreadID: String
    /// Where the review turn was placed.
    public let placement: CodexThread.ReviewPlacement
    /// What the review inspects.
    public let subject: CodexThread.ReviewSubject
    /// The active review turn.
    public let turn: CodexTurnHandle

    internal init(
        sourceThreadID: String,
        reviewThreadID: String,
        placement: CodexThread.ReviewPlacement,
        subject: CodexThread.ReviewSubject,
        turn: CodexTurnHandle
    ) {
        self.sourceThreadID = sourceThreadID
        self.reviewThreadID = reviewThreadID
        self.placement = placement
        self.subject = subject
        self.turn = turn
    }
}
