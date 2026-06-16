import AppKit
import ASBPresentation

/// AppKit sidebar view backed by a framework-neutral thread-sidebar snapshot.
@MainActor
public final class ASBThreadSidebarView: NSView {
    public typealias IntentHandler = @MainActor (ThreadSidebarIntent) -> Void

    public private(set) var snapshot: ThreadSidebarSnapshot
    public var onIntent: IntentHandler?

    private let scrollView: NSScrollView
    private let outlineView: NSOutlineView
    private let adapter = ASBThreadSidebarAdapter()
    private var suppressSelectionIntent = false

    public init(
        snapshot: ThreadSidebarSnapshot = .init(),
        onIntent: IntentHandler? = nil
    ) {
        self.snapshot = snapshot
        self.onIntent = onIntent
        scrollView = NSScrollView()
        outlineView = NSOutlineView()
        super.init(frame: .zero)
        configureViewHierarchy()
        apply(snapshot)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ASBThreadSidebarView does not support Interface Builder initialization.")
    }

    public func apply(_ snapshot: ThreadSidebarSnapshot) {
        self.snapshot = snapshot
        adapter.apply(snapshot)

        suppressSelectionIntent = true
        outlineView.reloadData()
        restoreExpandedSections()
        restoreSelection()
        suppressSelectionIntent = false
    }

    public func refreshUnarchivedThreads() {
        onIntent?(.refreshUnarchivedThreads)
    }

    public func refreshArchivedThreads() {
        onIntent?(.refreshArchivedThreads)
    }

    public func refreshSelectedWorktreeGitStatus() {
        onIntent?(.refreshSelectedWorktreeGitStatus)
    }

    private func configureViewHierarchy() {
        translatesAutoresizingMaskIntoConstraints = false

        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.headerView = nil
        outlineView.rowSizeStyle = .default
        outlineView.style = .sourceList
        outlineView.usesAutomaticRowHeights = false
        outlineView.target = self
        outlineView.doubleAction = #selector(openSelectedThread)

        let column = NSTableColumn(identifier: ASBThreadSidebarAdapter.columnIdentifier)
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func restoreExpandedSections() {
        for section in adapter.sections {
            outlineView.expandItem(section)
        }
    }

    private func restoreSelection() {
        guard let selectedThreadID = snapshot.selection.selectedThreadID,
              let row = adapter.row(forThreadID: selectedThreadID)
        else {
            outlineView.deselectAll(nil)
            return
        }

        let rowIndex = outlineView.row(forItem: row)
        guard rowIndex >= 0 else { return }

        outlineView.selectRowIndexes(IndexSet(integer: rowIndex), byExtendingSelection: false)
    }

    @objc private func openSelectedThread() {
        let selectedRow = outlineView.selectedRow
        guard selectedRow >= 0,
              let row = outlineView.item(atRow: selectedRow) as? ASBThreadSidebarRow,
              let item = row.threadItem
        else { return }

        onIntent?(.openThread(id: item.id))
    }
}

@MainActor
extension ASBThreadSidebarView: NSOutlineViewDataSource {
    public func outlineView(
        _ outlineView: NSOutlineView,
        numberOfChildrenOfItem item: Any?
    ) -> Int {
        adapter.numberOfChildren(of: item)
    }

    public func outlineView(
        _ outlineView: NSOutlineView,
        child index: Int,
        ofItem item: Any?
    ) -> Any {
        adapter.child(index, of: item)
    }

    public func outlineView(
        _ outlineView: NSOutlineView,
        isItemExpandable item: Any
    ) -> Bool {
        adapter.isExpandable(item)
    }
}

@MainActor
extension ASBThreadSidebarView: NSOutlineViewDelegate {
    public func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !suppressSelectionIntent else { return }

        let selectedRow = outlineView.selectedRow
        guard selectedRow >= 0,
              let row = outlineView.item(atRow: selectedRow) as? ASBThreadSidebarRow,
              let item = row.threadItem
        else {
            onIntent?(.selectThread(id: nil))
            return
        }

        onIntent?(.selectThread(id: item.id))
    }

    public func outlineView(
        _ outlineView: NSOutlineView,
        viewFor tableColumn: NSTableColumn?,
        item: Any
    ) -> NSView? {
        guard let row = item as? ASBThreadSidebarRow else { return nil }

        let cell = outlineView.makeView(
            withIdentifier: ASBThreadSidebarRowView.identifier,
            owner: self
        ) as? ASBThreadSidebarRowView ?? ASBThreadSidebarRowView()
        cell.configure(row)
        return cell
    }

    public func outlineView(
        _ outlineView: NSOutlineView,
        shouldSelectItem item: Any
    ) -> Bool {
        (item as? ASBThreadSidebarRow)?.threadItem != nil
    }

    public func outlineView(
        _ outlineView: NSOutlineView,
        heightOfRowByItem item: Any
    ) -> CGFloat {
        guard let row = item as? ASBThreadSidebarRow else { return 28 }

        switch row.kind {
            case .section:
                return 24
            case .thread:
                return 44
        }
    }
}

/// Snapshot adapter that owns AppKit tree mechanics for the sidebar.
@MainActor
final class ASBThreadSidebarAdapter {
    static let columnIdentifier = NSUserInterfaceItemIdentifier("ASBThreadSidebarColumn")

    private(set) var sections: [ASBThreadSidebarRow] = []

    var flattenedRows: [ASBThreadSidebarRow] {
        sections.flatMap { [$0] + $0.children }
    }

    init(snapshot: ThreadSidebarSnapshot = .init()) {
        apply(snapshot)
    }

    func apply(_ snapshot: ThreadSidebarSnapshot) {
        sections = snapshot.sections.map(ASBThreadSidebarRow.init(section:))
    }

    func row(forThreadID threadID: String) -> ASBThreadSidebarRow? {
        sections.lazy
            .flatMap(\.children)
            .first { $0.threadItem?.id == threadID }
    }

    func numberOfChildren(of item: Any?) -> Int {
        guard let row = item as? ASBThreadSidebarRow else {
            return sections.count
        }

        return row.children.count
    }

    func child(_ index: Int, of item: Any?) -> ASBThreadSidebarRow {
        guard let row = item as? ASBThreadSidebarRow else {
            return sections[index]
        }

        return row.children[index]
    }

    func isExpandable(_ item: Any) -> Bool {
        guard let row = item as? ASBThreadSidebarRow else { return false }

        return !row.children.isEmpty
    }
}

/// One AppKit outline row derived from a presentation snapshot.
@MainActor
final class ASBThreadSidebarRow: NSObject, Identifiable {
    enum Kind: Equatable {
        case section
        case thread
    }

    let id: String
    let kind: Kind
    let title: String
    let subtitle: String?
    let threadItem: ThreadSidebarItem?
    let children: [ASBThreadSidebarRow]

    init(section: ThreadSidebarSection) {
        id = "section:\(section.id)"
        kind = .section
        title = section.title
        subtitle = nil
        threadItem = nil
        children = section.items.map(ASBThreadSidebarRow.init(item:))
        super.init()
    }

    init(item: ThreadSidebarItem) {
        id = "thread:\(item.id)"
        kind = .thread
        title = item.title
        subtitle = Self.subtitle(for: item)
        threadItem = item
        children = []
        super.init()
    }

    private static func subtitle(for item: ThreadSidebarItem) -> String? {
        if !item.preview.isEmpty {
            return item.preview
        }
        if item.worktreeTitle != item.projectTitle {
            return item.worktreeTitle
        }
        return nil
    }
}

private final class ASBThreadSidebarRowView: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier("ASBThreadSidebarRowView")

    private let titleField = NSTextField(labelWithString: "")
    private let subtitleField = NSTextField(labelWithString: "")
    private let stackView = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = Self.identifier
        configureHierarchy()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ASBThreadSidebarRowView does not support Interface Builder initialization.")
    }

    func configure(_ row: ASBThreadSidebarRow) {
        titleField.stringValue = row.title
        subtitleField.stringValue = row.subtitle ?? ""
        subtitleField.isHidden = row.subtitle?.isEmpty ?? true
        titleField.font = row.kind == .section
            ? NSFont.preferredFont(forTextStyle: .subheadline).withSymbolicTraits(.bold)
            : NSFont.preferredFont(forTextStyle: .body)
    }

    private func configureHierarchy() {
        titleField.lineBreakMode = .byTruncatingTail
        subtitleField.lineBreakMode = .byTruncatingTail
        subtitleField.textColor = .secondaryLabelColor
        subtitleField.font = .preferredFont(forTextStyle: .caption1)

        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 2
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(titleField)
        stackView.addArrangedSubview(subtitleField)

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}

private extension NSFont {
    func withSymbolicTraits(_ traits: NSFontDescriptor.SymbolicTraits) -> NSFont {
        let descriptor = fontDescriptor.withSymbolicTraits(traits)
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }
}
