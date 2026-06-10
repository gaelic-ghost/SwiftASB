@testable import ASBAppKit
import ASBPresentation
import Testing

@Suite("ASBThreadSidebarView")
@MainActor
struct ASBThreadSidebarViewTests {
    @Test("adapter maps presentation sections into outline rows")
    func adapterBuildsOutlineRows() {
        let adapter = ASBThreadSidebarAdapter(snapshot: snapshot())

        #expect(adapter.sections.map(\.id) == ["section:recent", "section:archived"])
        #expect(adapter.numberOfChildren(of: nil) == 2)
        #expect(adapter.numberOfChildren(of: adapter.sections[0]) == 2)
        #expect(adapter.child(0, of: nil).title == "Recent")
        #expect(adapter.child(1, of: adapter.sections[0]).threadItem?.id == "thread-2")
        #expect(adapter.isExpandable(adapter.sections[0]))
        #expect(!adapter.isExpandable(adapter.sections[0].children[0]))
    }

    @Test("adapter preserves stable thread row identity")
    func adapterFindsRowsByThreadID() {
        let adapter = ASBThreadSidebarAdapter(snapshot: snapshot())

        let row = adapter.row(forThreadID: "thread-2")

        #expect(row?.id == "thread:thread-2")
        #expect(row?.title == "Second")
        #expect(row?.threadItem?.worktreeID == "worktree-1")
    }

    @Test("adapter updates row tree when snapshot changes")
    func adapterReplacesRowsOnSnapshotUpdate() {
        let adapter = ASBThreadSidebarAdapter(snapshot: snapshot())
        let updated = ThreadSidebarSnapshot(
            sections: [
                .init(id: "recent", title: "Recent", items: [
                    item(id: "thread-3", title: "Third"),
                ]),
            ],
            selection: .init(selectedThreadID: "thread-3")
        )

        adapter.apply(updated)

        #expect(adapter.sections.map(\.id) == ["section:recent"])
        #expect(adapter.flattenedRows.map(\.id) == ["section:recent", "thread:thread-3"])
        #expect(adapter.row(forThreadID: "thread-1") == nil)
        #expect(adapter.row(forThreadID: "thread-3")?.title == "Third")
    }

    @Test("view exposes refresh commands as presentation intents")
    func viewEmitsRefreshIntents() {
        var intents: [ThreadSidebarIntent] = []
        let view = ASBThreadSidebarView(snapshot: snapshot()) {
            intents.append($0)
        }

        view.refreshUnarchivedThreads()
        view.refreshArchivedThreads()
        view.refreshSelectedWorktreeGitStatus()

        #expect(intents == [
            .refreshUnarchivedThreads,
            .refreshArchivedThreads,
            .refreshSelectedWorktreeGitStatus,
        ])
    }

    private func snapshot() -> ThreadSidebarSnapshot {
        ThreadSidebarSnapshot(
            sections: [
                .init(id: "recent", title: "Recent", items: [
                    item(id: "thread-1", title: "First", preview: "First preview"),
                    item(id: "thread-2", title: "Second", preview: "Second preview"),
                ]),
                .init(id: "archived", title: "Archived", items: [
                    item(id: "thread-archived", title: "Archived", isArchived: true),
                ]),
            ],
            selection: .init(selectedThreadID: "thread-2")
        )
    }

    private func item(
        id: String,
        title: String,
        preview: String = "",
        isArchived: Bool = false
    ) -> ThreadSidebarItem {
        ThreadSidebarItem(
            id: id,
            title: title,
            preview: preview,
            sourceBadge: .cli,
            activityStatus: .idle,
            isArchived: isArchived,
            projectID: "project-1",
            projectTitle: "Project",
            worktreeID: "worktree-1",
            worktreeTitle: "Worktree",
            repositoryID: "https://github.com/gaelic-ghost/SwiftASB",
            updatedAt: 1
        )
    }
}
