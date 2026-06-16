import ASBPresentation
import Testing

struct ThreadSidebarPresentationTests {
    @Test("items keep stable thread identity")
    func itemIdentityIsStableThreadID() {
        let original = item(
            id: "thread-1",
            title: "Initial title",
            preview: "First preview",
            updatedAt: 10
        )
        let renamed = item(
            id: "thread-1",
            title: "Renamed thread",
            preview: "New preview",
            updatedAt: 20
        )

        #expect(original.id == "thread-1")
        #expect(renamed.id == original.id)
        #expect(renamed.title != original.title)
        #expect(renamed.updatedAt != original.updatedAt)
    }

    @Test("sections are grouping-ready without renderer concepts")
    func sectionsCarryGroupingIdentityAndItems() {
        let worktreeItem = item(
            id: "thread-worktree",
            title: "Worktree thread",
            projectID: "repo://swiftasb",
            projectTitle: "SwiftASB",
            worktreeID: "worktree://swiftasb-main",
            worktreeTitle: "SwiftASB main",
            repositoryID: "https://github.com/gaelic-ghost/SwiftASB"
        )
        let section = ThreadSidebarSection(
            id: "repo://swiftasb",
            title: "SwiftASB",
            projectID: "repo://swiftasb",
            worktreeID: "worktree://swiftasb-main",
            repositoryID: "https://github.com/gaelic-ghost/SwiftASB",
            items: [worktreeItem]
        )
        let snapshot = ThreadSidebarSnapshot(sections: [section])

        #expect(snapshot.sections.map(\.id) == ["repo://swiftasb"])
        #expect(snapshot.items.map(\.id) == ["thread-worktree"])
        #expect(snapshot.sections[0].worktreeID == "worktree://swiftasb-main")
        #expect(snapshot.sections[0].repositoryID == "https://github.com/gaelic-ghost/SwiftASB")
    }

    @Test("selection state identifies the selected thread row")
    func selectionStateMarksSelectedItem() {
        let selected = item(id: "selected-thread", title: "Selected")
        let other = item(id: "other-thread", title: "Other")
        let state = ThreadSelectionState().selectingThread(selected)

        #expect(state.selectedThreadID == "selected-thread")
        #expect(state.selectedWorktreeID == selected.worktreeID)
        #expect(state.selectedRepositoryID == selected.repositoryID)
        #expect(state.isSelected(selected))
        #expect(!state.isSelected(other))
    }

    @Test("snapshot exposes loading, empty, flattened items, and errors")
    func snapshotExposesListState() {
        let first = item(id: "first", title: "First")
        let second = item(id: "second", title: "Second")
        let snapshot = ThreadSidebarSnapshot(
            sections: [
                .init(id: "recent", title: "Recent", items: [first]),
                .init(id: "archived", title: "Archived", items: [second]),
            ],
            selection: .init(selectedThreadID: "second"),
            isLoading: true,
            errorDescription: "Library refresh failed while reading local thread history."
        )

        #expect(snapshot.items.map(\.id) == ["first", "second"])
        #expect(!snapshot.isEmpty)
        #expect(snapshot.isLoading)
        #expect(snapshot.errorDescription == "Library refresh failed while reading local thread history.")
        #expect(snapshot.selection.selectedThreadID == "second")
    }

    @Test("intent values are narrow and renderer-neutral")
    func sidebarIntentsCarryRuntimeCommands() {
        let intents: [ThreadSidebarIntent] = [
            .selectThread(id: "thread-1"),
            .openThread(id: "thread-1"),
            .setThreadArchived(id: "thread-1", archived: true),
            .refreshUnarchivedThreads,
            .refreshArchivedThreads,
            .refreshSelectedWorktreeGitStatus,
        ]

        #expect(intents.contains(.selectThread(id: "thread-1")))
        #expect(intents.contains(.setThreadArchived(id: "thread-1", archived: true)))
        #expect(intents.contains(.refreshSelectedWorktreeGitStatus))
    }

    private func item(
        id: String,
        title: String,
        preview: String = "",
        sourceBadge: ThreadSidebarSourceBadge = .cli,
        activityStatus: ThreadSidebarActivityStatus = .idle,
        isArchived: Bool = false,
        isClosed: Bool = false,
        projectID: String = "project://default",
        projectTitle: String = "Default Project",
        worktreeID: String = "worktree://default",
        worktreeTitle: String = "Default Worktree",
        repositoryID: String? = "https://github.com/gaelic-ghost/SwiftASB",
        updatedAt: Int = 1,
        lastCompletedTurnAt: Int? = nil
    ) -> ThreadSidebarItem {
        ThreadSidebarItem(
            id: id,
            title: title,
            preview: preview,
            sourceBadge: sourceBadge,
            activityStatus: activityStatus,
            isArchived: isArchived,
            isClosed: isClosed,
            projectID: projectID,
            projectTitle: projectTitle,
            worktreeID: worktreeID,
            worktreeTitle: worktreeTitle,
            repositoryID: repositoryID,
            updatedAt: updatedAt,
            lastCompletedTurnAt: lastCompletedTurnAt
        )
    }
}
