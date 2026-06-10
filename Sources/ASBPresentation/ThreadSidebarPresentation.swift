import SwiftASB

/// Framework-neutral state for a thread sidebar.
///
/// The snapshot carries stable list identity, grouping, selection, loading, and
/// error-display inputs for renderers. It intentionally avoids AppKit and
/// SwiftUI concepts such as index paths, reuse identifiers, bindings, or view
/// lifetimes.
public struct ThreadSidebarSnapshot: Sendable, Equatable {
    public var sections: [ThreadSidebarSection]
    public var selection: ThreadSelectionState
    public var isLoading: Bool
    public var errorDescription: String?

    public init(
        sections: [ThreadSidebarSection] = [],
        selection: ThreadSelectionState = .init(),
        isLoading: Bool = false,
        errorDescription: String? = nil
    ) {
        self.sections = sections
        self.selection = selection
        self.isLoading = isLoading
        self.errorDescription = errorDescription
    }

    /// All visible items in renderer order.
    public var items: [ThreadSidebarItem] {
        sections.flatMap(\.items)
    }

    /// True when there is no visible thread row.
    public var isEmpty: Bool {
        items.isEmpty
    }

    /// Projects the current app-wide library companion into a sidebar snapshot.
    @MainActor
    public init(
        library: CodexAppServer.Library,
        includeArchived: Bool = false
    ) {
        var projectedSections = library.groups.isEmpty
            ? Self.ungroupedSections(from: library.unarchivedThreads)
            : library.groups.map(ThreadSidebarSection.init(group:))

        if includeArchived, !library.archivedThreads.isEmpty {
            projectedSections.append(
                ThreadSidebarSection(
                    id: ThreadSidebarSection.archiveSectionID,
                    title: "Archived",
                    projectID: nil,
                    worktreeID: nil,
                    repositoryID: nil,
                    items: library.archivedThreads.map(ThreadSidebarItem.init(thread:))
                )
            )
        }

        self.init(
            sections: projectedSections,
            selection: .init(
                selectedThreadID: library.selectedThreadID,
                selectedWorktreeID: library.selectedWorktree?.id,
                selectedRepositoryID: library.selectedRepository?.originURL
            ),
            isLoading: library.isLoadingLocalSnapshot || library.isReconciling,
            errorDescription: library.latestErrorDescription
        )
    }

    private static func ungroupedSections(
        from threads: [CodexAppServer.Library.ThreadSnapshot]
    ) -> [ThreadSidebarSection] {
        guard !threads.isEmpty else { return [] }
        return [
            ThreadSidebarSection(
                id: ThreadSidebarSection.defaultSectionID,
                title: "Threads",
                projectID: nil,
                worktreeID: nil,
                repositoryID: nil,
                items: threads.map(ThreadSidebarItem.init(thread:))
            ),
        ]
    }
}

/// One visible section in a thread sidebar.
public struct ThreadSidebarSection: Sendable, Equatable, Identifiable {
    public static let defaultSectionID = "threads"
    public static let archiveSectionID = "archived"

    public var id: String
    public var title: String
    public var projectID: String?
    public var worktreeID: String?
    public var repositoryID: String?
    public var items: [ThreadSidebarItem]

    public init(
        id: String,
        title: String,
        projectID: String? = nil,
        worktreeID: String? = nil,
        repositoryID: String? = nil,
        items: [ThreadSidebarItem] = []
    ) {
        self.id = id
        self.title = title
        self.projectID = projectID
        self.worktreeID = worktreeID
        self.repositoryID = repositoryID
        self.items = items
    }

    @MainActor
    public init(group: CodexAppServer.Library.ThreadGroup) {
        self.init(
            id: group.id,
            title: group.title,
            projectID: group.projectInfo?.id,
            worktreeID: group.worktree?.id,
            repositoryID: group.worktree?.repository?.originURL,
            items: group.threads.map(ThreadSidebarItem.init(thread:))
        )
    }
}

/// One visible thread row in a framework-neutral sidebar snapshot.
public struct ThreadSidebarItem: Sendable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var preview: String
    public var sourceBadge: ThreadSidebarSourceBadge
    public var activityStatus: ThreadSidebarActivityStatus
    public var isArchived: Bool
    public var isClosed: Bool
    public var projectID: String
    public var projectTitle: String
    public var worktreeID: String
    public var worktreeTitle: String
    public var repositoryID: String?
    public var updatedAt: Int
    public var lastCompletedTurnAt: Int?

    public init(
        id: String,
        title: String,
        preview: String = "",
        sourceBadge: ThreadSidebarSourceBadge = .unknown,
        activityStatus: ThreadSidebarActivityStatus = .idle,
        isArchived: Bool = false,
        isClosed: Bool = false,
        projectID: String,
        projectTitle: String,
        worktreeID: String,
        worktreeTitle: String,
        repositoryID: String? = nil,
        updatedAt: Int,
        lastCompletedTurnAt: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.preview = preview
        self.sourceBadge = sourceBadge
        self.activityStatus = activityStatus
        self.isArchived = isArchived
        self.isClosed = isClosed
        self.projectID = projectID
        self.projectTitle = projectTitle
        self.worktreeID = worktreeID
        self.worktreeTitle = worktreeTitle
        self.repositoryID = repositoryID
        self.updatedAt = updatedAt
        self.lastCompletedTurnAt = lastCompletedTurnAt
    }

    public init(thread: CodexAppServer.Library.ThreadSnapshot) {
        self.init(
            id: thread.id,
            title: thread.name ?? thread.preview,
            preview: thread.preview,
            sourceBadge: .init(source: thread.source),
            activityStatus: .init(thread: thread),
            isArchived: thread.isArchived,
            isClosed: thread.isClosed,
            projectID: thread.projectInfo.id,
            projectTitle: thread.projectInfo.displayName,
            worktreeID: thread.worktree.id,
            worktreeTitle: thread.worktree.displayName,
            repositoryID: thread.worktree.repository?.originURL,
            updatedAt: thread.updatedAt,
            lastCompletedTurnAt: thread.lastCompletedTurnAt
        )
    }
}

/// The selected identities owned by a presentation/controller instance.
public struct ThreadSelectionState: Sendable, Equatable {
    public var selectedThreadID: String?
    public var selectedWorktreeID: String?
    public var selectedRepositoryID: String?

    public init(
        selectedThreadID: String? = nil,
        selectedWorktreeID: String? = nil,
        selectedRepositoryID: String? = nil
    ) {
        self.selectedThreadID = selectedThreadID
        self.selectedWorktreeID = selectedWorktreeID
        self.selectedRepositoryID = selectedRepositoryID
    }

    public func isSelected(_ item: ThreadSidebarItem) -> Bool {
        item.id == selectedThreadID
    }

    public func selectingThread(_ item: ThreadSidebarItem?) -> Self {
        .init(
            selectedThreadID: item?.id,
            selectedWorktreeID: item?.worktreeID,
            selectedRepositoryID: item?.repositoryID
        )
    }
}

/// Renderer-neutral badge for the app-server source that created a thread.
public enum ThreadSidebarSourceBadge: Sendable, Equatable {
    case appServer
    case cli
    case exec
    case vscode
    case custom(String)
    case subAgent(kind: String)
    case unknown

    public init(source: CodexAppServer.ThreadSource) {
        switch source {
        case .appServer:
            self = .appServer
        case .cli:
            self = .cli
        case .exec:
            self = .exec
        case .vscode:
            self = .vscode
        case let .custom(label):
            self = .custom(label)
        case let .subAgent(source):
            self = .subAgent(kind: source.kind.rawValue)
        case .unknown:
            self = .unknown
        }
    }
}

/// Renderer-neutral activity state for a thread row.
public enum ThreadSidebarActivityStatus: Sendable, Equatable {
    case active
    case idle
    case notLoaded
    case systemError
    case waitingOnApproval
    case waitingOnUserInput
    case closed
    case removed

    public init(thread: CodexAppServer.Library.ThreadSnapshot) {
        if thread.state == .removed {
            self = .removed
        } else if thread.isClosed {
            self = .closed
        } else if thread.status.activeFlags.contains(.waitingOnApproval) {
            self = .waitingOnApproval
        } else if thread.status.activeFlags.contains(.waitingOnUserInput) {
            self = .waitingOnUserInput
        } else {
            switch thread.status.type {
            case .active:
                self = .active
            case .idle:
                self = .idle
            case .notLoaded:
                self = .notLoaded
            case .systemError:
                self = .systemError
            }
        }
    }
}

/// User intent emitted by a thread sidebar renderer.
public enum ThreadSidebarIntent: Sendable, Equatable {
    case selectThread(id: String?)
    case openThread(id: String)
    case setThreadArchived(id: String, archived: Bool)
    case refreshUnarchivedThreads
    case refreshArchivedThreads
    case refreshSelectedWorktreeGitStatus
}
