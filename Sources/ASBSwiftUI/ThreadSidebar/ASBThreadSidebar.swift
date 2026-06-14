import ASBAppKit
import ASBPresentation
import SwiftUI

/// SwiftUI wrapper for the AppKit-backed thread sidebar.
///
/// `ASBThreadSidebar` keeps dense source-list behavior in `ASBAppKit` while
/// letting SwiftUI hosts feed framework-neutral snapshots and receive typed
/// presentation intents.
@MainActor
public struct ASBThreadSidebar: NSViewRepresentable {
    public typealias IntentHandler = @MainActor (ThreadSidebarIntent) -> Void
    public typealias NSViewType = ASBThreadSidebarView

    public var snapshot: ThreadSidebarSnapshot
    public var onIntent: IntentHandler?

    public init(
        snapshot: ThreadSidebarSnapshot = .init(),
        onIntent: IntentHandler? = nil
    ) {
        self.snapshot = snapshot
        self.onIntent = onIntent
    }

    public func makeNSView(context: Context) -> ASBThreadSidebarView {
        ASBThreadSidebarView(snapshot: snapshot, onIntent: onIntent)
    }

    public func updateNSView(_ nsView: ASBThreadSidebarView, context: Context) {
        nsView.onIntent = onIntent
        nsView.apply(snapshot)
    }
}
