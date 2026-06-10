import SwiftASB

/// Framework-neutral state for a mixed recent activity rail.
public struct RecentActivitySnapshot: Sendable, Equatable {
    public var items: [RecentActivityItem]
    public var selectedItemID: String?
    public var visibleItemIDs: [String]
    public var isLoadingOlderItems: Bool
    public var canLoadOlderItems: Bool
    public var errorDescription: String?

    public init(
        items: [RecentActivityItem] = [],
        selectedItemID: String? = nil,
        visibleItemIDs: [String] = [],
        isLoadingOlderItems: Bool = false,
        canLoadOlderItems: Bool = false,
        errorDescription: String? = nil
    ) {
        self.items = items
        self.selectedItemID = selectedItemID
        self.visibleItemIDs = visibleItemIDs
        self.isLoadingOlderItems = isLoadingOlderItems
        self.canLoadOlderItems = canLoadOlderItems
        self.errorDescription = errorDescription
    }

    public var isEmpty: Bool {
        items.isEmpty
    }

    @MainActor
    public init(
        recentFiles: CodexThread.RecentFiles? = nil,
        recentCommands: CodexThread.RecentCommands? = nil,
        selectedItemID: String? = nil,
        visibleItemIDs: [String] = []
    ) {
        let fileItems = recentFiles?.files.map(RecentActivityItem.init(file:)) ?? []
        let commandItems = recentCommands?.commands.map(RecentActivityItem.init(command:)) ?? []
        let items = (fileItems + commandItems).sorted(by: Self.sort)

        self.init(
            items: items,
            selectedItemID: selectedItemID ?? recentFiles?.selectedFileID ?? recentCommands?.selectedCommandID,
            visibleItemIDs: visibleItemIDs.isEmpty
                ? (recentFiles?.visibleFileIDs ?? []) + (recentCommands?.visibleCommandIDs ?? [])
                : visibleItemIDs,
            isLoadingOlderItems: (recentFiles?.isLoadingOlderFiles ?? false)
                || (recentCommands?.isLoadingOlderCommands ?? false),
            canLoadOlderItems: recentFiles?.nextOlderCursor != nil || recentCommands?.nextOlderCursor != nil,
            errorDescription: recentFiles?.lastLoadErrorDescription ?? recentCommands?.lastLoadErrorDescription
        )
    }

    private static func sort(_ lhs: RecentActivityItem, _ rhs: RecentActivityItem) -> Bool {
        switch (lhs.turnStartedAt, rhs.turnStartedAt) {
        case let (left?, right?) where left != right:
            return left > right
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        default:
            break
        }

        switch (lhs.turnOrderIndex, rhs.turnOrderIndex) {
        case let (left?, right?) where left != right:
            return left > right
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        default:
            break
        }

        switch (lhs.itemOrderIndex, rhs.itemOrderIndex) {
        case let (left?, right?) where left != right:
            return left < right
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        default:
            return lhs.id < rhs.id
        }
    }
}

/// One command or file activity item in a framework-neutral rail.
public struct RecentActivityItem: Sendable, Equatable, Identifiable {
    public var id: String
    public var sourceID: String
    public var turnID: String
    public var kind: RecentActivityKind
    public var title: String
    public var subtitle: String?
    public var status: RecentActivityStatus
    public var payloadText: String?
    public var isPayloadComplete: Bool
    public var omittedPayloadCharacterCount: Int
    public var path: String?
    public var command: String?
    public var turnOrderIndex: Int?
    public var itemOrderIndex: Int?
    public var turnStartedAt: Int?

    public init(
        id: String,
        sourceID: String,
        turnID: String,
        kind: RecentActivityKind,
        title: String,
        subtitle: String? = nil,
        status: RecentActivityStatus,
        payloadText: String? = nil,
        isPayloadComplete: Bool = true,
        omittedPayloadCharacterCount: Int = 0,
        path: String? = nil,
        command: String? = nil,
        turnOrderIndex: Int? = nil,
        itemOrderIndex: Int? = nil,
        turnStartedAt: Int? = nil
    ) {
        self.id = id
        self.sourceID = sourceID
        self.turnID = turnID
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.payloadText = payloadText
        self.isPayloadComplete = isPayloadComplete
        self.omittedPayloadCharacterCount = omittedPayloadCharacterCount
        self.path = path
        self.command = command
        self.turnOrderIndex = turnOrderIndex
        self.itemOrderIndex = itemOrderIndex
        self.turnStartedAt = turnStartedAt
    }

    public init(file: CodexThread.RecentFiles.FileSnapshot) {
        self.init(
            id: "file:\(file.id)",
            sourceID: file.id,
            turnID: file.turnID,
            kind: .file,
            title: file.displayName,
            subtitle: file.latestStatusText,
            status: .init(file.status),
            payloadText: file.payloadText,
            isPayloadComplete: file.isPayloadComplete,
            omittedPayloadCharacterCount: file.omittedPayloadCharacterCount,
            path: file.path,
            turnOrderIndex: file.turnOrderIndex,
            itemOrderIndex: file.itemOrderIndex,
            turnStartedAt: file.turnStartedAt
        )
    }

    public init(command: CodexThread.RecentCommands.CommandSnapshot) {
        self.init(
            id: "command:\(command.id)",
            sourceID: command.id,
            turnID: command.turnID,
            kind: .command,
            title: command.displayName,
            subtitle: command.latestStatusText,
            status: .init(command.status),
            payloadText: command.outputText,
            isPayloadComplete: command.isOutputComplete,
            omittedPayloadCharacterCount: command.omittedOutputCharacterCount,
            command: command.command,
            turnOrderIndex: command.turnOrderIndex,
            itemOrderIndex: command.itemOrderIndex,
            turnStartedAt: command.turnStartedAt
        )
    }
}

public enum RecentActivityKind: String, Sendable, Equatable {
    case command
    case file
}

public enum RecentActivityStatus: String, Sendable, Equatable {
    case completed
    case errored
    case inProgress

    public init(_ status: CodexThread.RecentFiles.FileSnapshot.Status) {
        switch status {
        case .completed:
            self = .completed
        case .errored:
            self = .errored
        case .inProgress:
            self = .inProgress
        }
    }

    public init(_ status: CodexThread.RecentCommands.CommandSnapshot.Status) {
        switch status {
        case .completed:
            self = .completed
        case .errored:
            self = .errored
        case .inProgress:
            self = .inProgress
        }
    }
}

public enum RecentActivityIntent: Sendable, Equatable {
    case loadOlderItems
    case updateVisibleItemIDs([String])
    case selectItem(id: String?)
    case rehydratePayload(itemID: String)
}
