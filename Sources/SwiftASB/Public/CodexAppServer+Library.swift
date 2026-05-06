import Foundation
import Observation

private func snapshotResult<Value: Sendable>(
    _ operation: @Sendable () async throws -> Value
) async -> Result<Value, Error> {
    do {
        return .success(try await operation())
    } catch {
        return .failure(error)
    }
}

extension CodexAppServer {
    internal enum LibraryEvent: Sendable, Equatable {
        case threadChanged(threadID: String)
        case turnCompleted(threadID: String)
    }
}

public extension CodexAppServer {
    /// Repeatable thread-list query intent for app-wide libraries and stored-thread reads.
    ///
    /// `ThreadListQD` is a SwiftASB-owned descriptor. It lets callers describe
    /// the list they want in package terms, then SwiftASB can apply the same
    /// intent to local history snapshots, app-server `thread/list` pages, or
    /// observable library loading without exposing Core Data fetch requests or
    /// generated wire values.
    struct ThreadListQD: Sendable, Equatable {
        public var archived: Bool?
        public var currentDirectoryPath: String?
        public var limit: Int
        public var modelProviders: [String]?
        public var searchTerm: String?
        public var sortedBy: Library.SortedBy

        /// Creates a thread-list query descriptor.
        ///
        /// `limit` is normalized to at least `1`. Nil filters are left
        /// unspecified so app-server reads can use Codex defaults and local
        /// library reads can preserve all matching snapshots.
        public init(
            archived: Bool? = nil,
            currentDirectoryPath: String? = nil,
            limit: Int = 50,
            modelProviders: [String]? = nil,
            searchTerm: String? = nil,
            sortedBy: Library.SortedBy = .updatedNewestFirst
        ) {
            self.archived = archived
            self.currentDirectoryPath = currentDirectoryPath
            self.limit = max(1, limit)
            self.modelProviders = modelProviders
            self.searchTerm = Self.normalizedSearchTerm(searchTerm)
            self.sortedBy = sortedBy
        }

        /// All locally known or remotely listed threads that match the sort policy.
        public static func all(
            limit: Int = 50,
            sortedBy: Library.SortedBy = .updatedNewestFirst
        ) -> Self {
            .init(limit: limit, sortedBy: sortedBy)
        }

        /// Unarchived threads only.
        public static func unarchived(
            limit: Int = 50,
            sortedBy: Library.SortedBy = .updatedNewestFirst
        ) -> Self {
            .init(archived: false, limit: limit, sortedBy: sortedBy)
        }

        /// Archived threads only.
        public static func archived(
            limit: Int = 50,
            sortedBy: Library.SortedBy = .updatedNewestFirst
        ) -> Self {
            .init(archived: true, limit: limit, sortedBy: sortedBy)
        }

        /// Threads whose app-server current working directory exactly matches `currentDirectoryPath`.
        ///
        /// This is an app-server `cwd` match, not repository-root derivation.
        public static func cwd(
            _ currentDirectoryPath: String,
            archived: Bool? = nil,
            limit: Int = 50,
            sortedBy: Library.SortedBy = .updatedNewestFirst
        ) -> Self {
            .init(
                archived: archived,
                currentDirectoryPath: currentDirectoryPath,
                limit: limit,
                modelProviders: nil,
                searchTerm: nil,
                sortedBy: sortedBy
            )
        }

        /// Threads matching a search term across the app-server/local list fields SwiftASB knows how to search.
        public static func search(
            _ searchTerm: String,
            archived: Bool? = nil,
            limit: Int = 50,
            sortedBy: Library.SortedBy = .updatedNewestFirst
        ) -> Self {
            .init(
                archived: archived,
                limit: limit,
                searchTerm: searchTerm,
                sortedBy: sortedBy
            )
        }

        /// Returns the same query with a normalized page or local result limit.
        public func limited(to limit: Int) -> Self {
            .init(
                archived: archived,
                currentDirectoryPath: currentDirectoryPath,
                limit: limit,
                modelProviders: modelProviders,
                searchTerm: searchTerm,
                sortedBy: sortedBy
            )
        }

        /// Returns the same query with a different SwiftASB-visible sort policy.
        public func sorted(by sortedBy: Library.SortedBy) -> Self {
            .init(
                archived: archived,
                currentDirectoryPath: currentDirectoryPath,
                limit: limit,
                modelProviders: modelProviders,
                searchTerm: searchTerm,
                sortedBy: sortedBy
            )
        }

        /// Returns the same query with an archive-state filter.
        public func filteringArchived(_ archived: Bool?) -> Self {
            .init(
                archived: archived,
                currentDirectoryPath: currentDirectoryPath,
                limit: limit,
                modelProviders: modelProviders,
                searchTerm: searchTerm,
                sortedBy: sortedBy
            )
        }

        /// Returns the same query with an exact app-server current-working-directory filter.
        public func filteringCurrentDirectoryPath(_ currentDirectoryPath: String?) -> Self {
            .init(
                archived: archived,
                currentDirectoryPath: currentDirectoryPath,
                limit: limit,
                modelProviders: modelProviders,
                searchTerm: searchTerm,
                sortedBy: sortedBy
            )
        }

        /// Returns the same query with app-server model-provider filtering.
        public func filteringModelProviders(_ modelProviders: [String]?) -> Self {
            .init(
                archived: archived,
                currentDirectoryPath: currentDirectoryPath,
                limit: limit,
                modelProviders: modelProviders,
                searchTerm: searchTerm,
                sortedBy: sortedBy
            )
        }

        /// Returns the same query with a normalized search term.
        public func searching(_ searchTerm: String?) -> Self {
            .init(
                archived: archived,
                currentDirectoryPath: currentDirectoryPath,
                limit: limit,
                modelProviders: modelProviders,
                searchTerm: searchTerm,
                sortedBy: sortedBy
            )
        }

        /// Builds a stored-thread request for a direct app-server read.
        ///
        /// Use this when a caller wants the remote `thread/list` page for the
        /// same query intent. Observable libraries use the descriptor directly
        /// so they can also apply it to local history snapshots.
        public func threadListRequest(cursor: String? = nil) -> CodexAppServer.ThreadListRequest {
            .init(
                cursor: cursor,
                limit: limit,
                sortKey: sortedBy.appServerSort.key,
                sortDirection: sortedBy.appServerSort.direction,
                modelProviders: modelProviders,
                archived: archived,
                currentDirectoryPath: currentDirectoryPath,
                searchTerm: searchTerm
            )
        }

        internal func threadListRequest(
            archived archiveFilter: Bool,
            cursor: String? = nil
        ) -> CodexAppServer.ThreadListRequest {
            .init(
                cursor: cursor,
                limit: limit,
                sortKey: sortedBy.appServerSort.key,
                sortDirection: sortedBy.appServerSort.direction,
                modelProviders: modelProviders,
                archived: archiveFilter,
                currentDirectoryPath: currentDirectoryPath,
                searchTerm: searchTerm
            )
        }

        private static func normalizedSearchTerm(_ searchTerm: String?) -> String? {
            guard let searchTerm else { return nil }
            let trimmed = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }
}

public extension CodexAppServer {
    @MainActor
    @Observable
    final class Library {
        public struct Configuration: Sendable, Equatable {
            public var groupedBy: GroupedBy
            public var hookListCurrentDirectoryPaths: [String]?
            public var loadsAppSnapshotsOnCreation: Bool
            public var maxPagesPerArchiveState: Int
            public var mcpServerStatusRequest: CodexAppServer.McpServerStatusListRequest
            public var pageSize: Int
            public var query: CodexAppServer.ThreadListQD
            public var reconcilesOnCreation: Bool
            public var sortedBy: SortedBy

            public init(
                pageSize: Int = 50,
                maxPagesPerArchiveState: Int = 1,
                sortedBy: SortedBy = .updatedNewestFirst,
                groupedBy: GroupedBy = .cwd,
                query: CodexAppServer.ThreadListQD = .init(),
                reconcilesOnCreation: Bool = true,
                loadsAppSnapshotsOnCreation: Bool = true,
                hookListCurrentDirectoryPaths: [String]? = nil,
                mcpServerStatusRequest: CodexAppServer.McpServerStatusListRequest = .init()
            ) {
                let normalizedPageSize = max(1, pageSize)
                self.pageSize = normalizedPageSize
                self.maxPagesPerArchiveState = max(1, maxPagesPerArchiveState)
                self.sortedBy = sortedBy
                self.groupedBy = groupedBy
                self.loadsAppSnapshotsOnCreation = loadsAppSnapshotsOnCreation
                self.hookListCurrentDirectoryPaths = hookListCurrentDirectoryPaths
                self.mcpServerStatusRequest = mcpServerStatusRequest
                self.query = .init(
                    archived: query.archived,
                    currentDirectoryPath: query.currentDirectoryPath,
                    limit: normalizedPageSize,
                    modelProviders: query.modelProviders,
                    searchTerm: query.searchTerm,
                    sortedBy: sortedBy
                )
                self.reconcilesOnCreation = reconcilesOnCreation
            }
        }

        public enum GroupedBy: String, Sendable, Equatable {
            case none
            case cwd
            case repository
        }

        public enum ReconciliationPhase: String, Sendable, Equatable {
            case idle
            case loadingLocalSnapshot
            case reconcilingUnarchived
            case reconcilingArchived
        }

        public enum SnapshotPhase: String, Sendable, Equatable {
            case idle
            case loading
        }

        public enum SortedBy: String, Sendable, Equatable {
            case updatedNewestFirst
            case updatedOldestFirst
            case createdNewestFirst
            case createdOldestFirst
            case selectedNewestFirst
            case turnFinishedNewestFirst
            case turnFinishedOldestFirst
            case nameAscending
            case nameDescending

            internal var appServerSort: (
                key: CodexAppServer.ThreadListSortKey,
                direction: CodexAppServer.ThreadListSortDirection
            ) {
                switch self {
                case .createdNewestFirst:
                    (.createdAt, .desc)
                case .createdOldestFirst:
                    (.createdAt, .asc)
                case .updatedNewestFirst,
                     .selectedNewestFirst,
                     .turnFinishedNewestFirst,
                     .turnFinishedOldestFirst,
                     .nameAscending,
                     .nameDescending:
                    (.updatedAt, .desc)
                case .updatedOldestFirst:
                    (.updatedAt, .asc)
                }
            }
        }

        public struct ThreadSnapshot: Sendable, Equatable, Identifiable {
            public let id: String
            public let cliVersion: String
            public let createdAt: Int
            public let currentDirectoryPath: String
            public let ephemeral: Bool
            public let forkedFromThreadID: String?
            public let currentGitBranch: String?
            public let currentGitOriginURL: String?
            public let isArchived: Bool
            public let isClosed: Bool
            public let lastCompletedTurnAt: Int?
            public let modelProvider: String
            public let name: String?
            public let preview: String
            public let status: CodexAppServer.ThreadStatus
            public let updatedAt: Int
        }

        public struct ThreadGroup: Sendable, Equatable, Identifiable {
            public let id: String
            public let title: String
            public let threads: [ThreadSnapshot]
        }

        public private(set) var archivedThreads: [ThreadSnapshot]
        public private(set) var groups: [ThreadGroup]
        public private(set) var hookListSnapshot: CodexAppServer.HookListSnapshot?
        public private(set) var lastReconciledAt: Date?
        public private(set) var lastSnapshotsReadAt: Date?
        public private(set) var latestSnapshotErrorDescription: String?
        public private(set) var latestErrorDescription: String?
        public private(set) var mcpServers: [CodexAppServer.McpServerStatus]
        public private(set) var mcpServerNextCursor: String?
        public private(set) var modelCapabilities: CodexAppServer.ModelCapabilities?
        public private(set) var phase: ReconciliationPhase
        public var selectedThreadID: String? {
            didSet {
                guard selectedThreadID != oldValue else { return }
                if let selectedThreadID {
                    recordSelection(threadID: selectedThreadID)
                }
                applyVisibleState()
            }
        }
        public var groupedBy: GroupedBy {
            didSet {
                applyVisibleState()
            }
        }
        public var sortedBy: SortedBy {
            didSet {
                query.sortedBy = sortedBy
                applyVisibleState()
            }
        }
        public private(set) var unarchivedThreads: [ThreadSnapshot]
        public private(set) var snapshotCurrentDirectoryPaths: [String]?
        public private(set) var snapshotPhase: SnapshotPhase

        public var isLoadingLocalSnapshot: Bool {
            phase == .loadingLocalSnapshot
        }

        public var isReconciling: Bool {
            phase == .reconcilingUnarchived || phase == .reconcilingArchived
        }

        public var isLoadingAppSnapshots: Bool {
            snapshotPhase == .loading
        }

        public var selectedThread: ThreadSnapshot? {
            guard let selectedThreadID else { return nil }
            return allThreads.first { $0.id == selectedThreadID }
        }

        @ObservationIgnored
        private let appServer: CodexAppServer

        @ObservationIgnored
        private var allThreads: [ThreadSnapshot]

        @ObservationIgnored
        private let maxPagesPerArchiveState: Int

        @ObservationIgnored
        private let configuredHookListCurrentDirectoryPaths: [String]?

        @ObservationIgnored
        private let mcpServerStatusRequest: CodexAppServer.McpServerStatusListRequest

        @ObservationIgnored
        private var pendingEventReload = false

        @ObservationIgnored
        private var selectionOrderByThreadID: [String: Int] = [:]

        @ObservationIgnored
        private var selectionSequence = 0

        @ObservationIgnored
        private var query: CodexAppServer.ThreadListQD

        @ObservationIgnored
        private var eventTask: Task<Void, Never>?

        @ObservationIgnored
        private var refreshTask: Task<Void, Never>?

        @ObservationIgnored
        private var snapshotTask: Task<Void, Never>?

        internal init(
            appServer: CodexAppServer,
            configuration: Configuration,
            initialThreads: [ThreadSnapshot]
        ) {
            self.appServer = appServer
            self.allThreads = initialThreads
            self.archivedThreads = []
            self.configuredHookListCurrentDirectoryPaths = configuration.hookListCurrentDirectoryPaths
            self.groups = []
            self.groupedBy = configuration.groupedBy
            self.hookListSnapshot = nil
            self.lastReconciledAt = nil
            self.lastSnapshotsReadAt = nil
            self.latestSnapshotErrorDescription = nil
            self.latestErrorDescription = nil
            self.maxPagesPerArchiveState = configuration.maxPagesPerArchiveState
            self.mcpServers = []
            self.mcpServerNextCursor = nil
            self.mcpServerStatusRequest = configuration.mcpServerStatusRequest
            self.modelCapabilities = nil
            self.phase = .idle
            self.query = configuration.query
            self.selectedThreadID = nil
            self.snapshotCurrentDirectoryPaths = nil
            self.snapshotPhase = .idle
            self.sortedBy = configuration.sortedBy
            self.unarchivedThreads = []
            applyVisibleState()

            if configuration.reconcilesOnCreation {
                refreshTask = Task { [weak self] in await self?.refreshAll() }
            }
            if configuration.loadsAppSnapshotsOnCreation {
                snapshotTask = Task { [weak self] in await self?.refreshAppSnapshots() }
            }
            startEventTask()
        }

        deinit {
            eventTask?.cancel()
            refreshTask?.cancel()
            snapshotTask?.cancel()
        }

        public func refresh() async {
            await refreshAll()
        }

        public func refreshAll() async {
            if isReconciling || isLoadingLocalSnapshot {
                return
            }

            await reloadLocalSnapshot(phase: .loadingLocalSnapshot)

            do {
                try await reconcileArchiveScope(false)

                try Task.checkCancellation()
                await Task.yield()

                try await reconcileArchiveScope(true)

                lastReconciledAt = Date()
                latestErrorDescription = nil
            } catch is CancellationError {
                return
            } catch {
                latestErrorDescription = error.localizedDescription
            }

            if pendingEventReload {
                pendingEventReload = false
                await reloadLocalSnapshot(phase: .loadingLocalSnapshot)
            }
            phase = .idle
        }

        public func refreshUnarchived() async {
            await refreshArchiveScope(false)
        }

        public func refreshArchived() async {
            await refreshArchiveScope(true)
        }

        public func reload() async {
            await reloadLocalSnapshot(phase: .loadingLocalSnapshot)
            phase = .idle
        }

        public func refreshAppSnapshots() async {
            if isLoadingAppSnapshots {
                return
            }

            snapshotPhase = .loading
            latestSnapshotErrorDescription = nil

            let hookCurrentDirectoryPaths = resolvedHookListCurrentDirectoryPaths()
            snapshotCurrentDirectoryPaths = hookCurrentDirectoryPaths

            async let capabilitiesResult = snapshotResult {
                try await appServer.readModelCapabilities()
            }
            async let mcpResult = snapshotResult {
                try await appServer.listMcpServerStatuses(mcpServerStatusRequest)
            }
            async let hooksResult = snapshotResult {
                try await appServer.listHooks(
                    .init(currentDirectoryPaths: hookCurrentDirectoryPaths)
                )
            }

            let results = await (
                capabilities: capabilitiesResult,
                mcp: mcpResult,
                hooks: hooksResult
            )

            var errorDescriptions: [String] = []
            switch results.capabilities {
            case let .success(capabilities):
                modelCapabilities = capabilities
            case let .failure(error):
                errorDescriptions.append(error.localizedDescription)
            }

            switch results.mcp {
            case let .success(page):
                mcpServers = page.servers
                mcpServerNextCursor = page.nextCursor
            case let .failure(error):
                errorDescriptions.append(error.localizedDescription)
            }

            switch results.hooks {
            case let .success(snapshot):
                hookListSnapshot = snapshot
            case let .failure(error):
                errorDescriptions.append(error.localizedDescription)
            }

            lastSnapshotsReadAt = errorDescriptions.isEmpty ? Date() : lastSnapshotsReadAt
            latestSnapshotErrorDescription = errorDescriptions.isEmpty
                ? nil
                : errorDescriptions.joined(separator: "\n")
            snapshotPhase = .idle
        }

        public func selectThread(_ threadID: String?) {
            selectedThreadID = threadID
        }

        public func selectThread(_ thread: ThreadSnapshot) {
            selectThread(thread.id)
        }

        public func clearSelection() {
            selectThread(nil)
        }

        private func refreshArchiveScope(_ archived: Bool) async {
            if isReconciling || isLoadingLocalSnapshot {
                return
            }

            await reloadLocalSnapshot(phase: .loadingLocalSnapshot)

            do {
                try await reconcileArchiveScope(archived)
                lastReconciledAt = Date()
                latestErrorDescription = nil
            } catch is CancellationError {
                return
            } catch {
                latestErrorDescription = error.localizedDescription
            }

            if pendingEventReload {
                pendingEventReload = false
                await reloadLocalSnapshot(phase: .loadingLocalSnapshot)
            }
            phase = .idle
        }

        private func reconcileArchiveScope(_ archived: Bool) async throws {
            phase = archived ? .reconcilingArchived : .reconcilingUnarchived
            try await appServer.reconcileLibraryThreads(
                query: query,
                archived: archived,
                maxPages: maxPagesPerArchiveState
            )
            await reloadLocalSnapshot(phase: archived ? .reconcilingArchived : .reconcilingUnarchived)
        }

        private func startEventTask() {
            eventTask = Task { [weak self] in
                guard let self else { return }
                let events = await appServer.libraryEvents()
                for await _ in events {
                    if Task.isCancelled {
                        return
                    }
                    if isReconciling || isLoadingLocalSnapshot {
                        pendingEventReload = true
                        continue
                    }
                    await reloadLocalSnapshot(phase: .loadingLocalSnapshot)
                    phase = .idle
                }
            }
        }

        private func reloadLocalSnapshot(phase: ReconciliationPhase) async {
            self.phase = phase
            do {
                allThreads = try await appServer.libraryThreadSnapshots(query: query)
                clearSelectionIfThreadDisappeared()
                applyVisibleState()
            } catch {
                latestErrorDescription = error.localizedDescription
            }
        }

        private func applyVisibleState() {
            let sortedThreads = Self.sort(
                allThreads,
                by: sortedBy,
                selectionOrderByThreadID: selectionOrderByThreadID
            )
            unarchivedThreads = sortedThreads.filter { !$0.isArchived }
            archivedThreads = sortedThreads.filter(\.isArchived)
            groups = Self.groups(
                from: unarchivedThreads,
                groupedBy: groupedBy
            )
        }

        private func recordSelection(threadID: String) {
            selectionSequence += 1
            selectionOrderByThreadID[threadID] = selectionSequence
        }

        private func clearSelectionIfThreadDisappeared() {
            guard let selectedThreadID else { return }
            if !allThreads.contains(where: { $0.id == selectedThreadID }) {
                self.selectedThreadID = nil
            }
        }

        private func resolvedHookListCurrentDirectoryPaths() -> [String]? {
            if let configuredHookListCurrentDirectoryPaths {
                return configuredHookListCurrentDirectoryPaths
            }

            let currentDirectoryPaths = allThreads
                .map(\.currentDirectoryPath)
                .filter { !$0.isEmpty }
            let uniquePaths = Array(Set(currentDirectoryPaths))
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            return uniquePaths.isEmpty ? nil : uniquePaths
        }

        private static func sort(
            _ threads: [ThreadSnapshot],
            by sortedBy: SortedBy,
            selectionOrderByThreadID: [String: Int]
        ) -> [ThreadSnapshot] {
            threads.sorted { lhs, rhs in
                switch sortedBy {
                case .updatedNewestFirst:
                    newest(lhs.updatedAt, rhs.updatedAt, lhs.id, rhs.id)
                case .updatedOldestFirst:
                    oldest(lhs.updatedAt, rhs.updatedAt, lhs.id, rhs.id)
                case .createdNewestFirst:
                    newest(lhs.createdAt, rhs.createdAt, lhs.id, rhs.id)
                case .createdOldestFirst:
                    oldest(lhs.createdAt, rhs.createdAt, lhs.id, rhs.id)
                case .selectedNewestFirst:
                    compareSelection(
                        lhs,
                        rhs,
                        selectionOrderByThreadID: selectionOrderByThreadID
                    )
                case .turnFinishedNewestFirst:
                    newest(
                        lhs.lastCompletedTurnAt ?? Int.min,
                        rhs.lastCompletedTurnAt ?? Int.min,
                        lhs.id,
                        rhs.id
                    )
                case .turnFinishedOldestFirst:
                    oldest(
                        lhs.lastCompletedTurnAt ?? Int.max,
                        rhs.lastCompletedTurnAt ?? Int.max,
                        lhs.id,
                        rhs.id
                    )
                case .nameAscending:
                    compareNames(lhs, rhs, ascending: true)
                case .nameDescending:
                    compareNames(lhs, rhs, ascending: false)
                }
            }
        }

        private static func groups(
            from threads: [ThreadSnapshot],
            groupedBy: GroupedBy
        ) -> [ThreadGroup] {
            guard groupedBy != .none else {
                return []
            }

            let grouped = Dictionary(grouping: threads) { thread in
                switch groupedBy {
                case .none:
                    ""
                case .cwd:
                    thread.currentDirectoryPath
                case .repository:
                    thread.currentGitOriginURL ?? thread.currentDirectoryPath
                }
            }

            return grouped
                .map { key, threads in
                    ThreadGroup(
                        id: key,
                        title: title(forGroupID: key, groupedBy: groupedBy),
                        threads: threads
                    )
                }
                .sorted { lhs, rhs in
                    lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }
        }

        private static func title(
            forGroupID id: String,
            groupedBy: GroupedBy
        ) -> String {
            guard !id.isEmpty else {
                return "Unknown Project"
            }

            guard groupedBy == .repository else {
                return id
            }

            guard let url = URL(string: id),
                  let host = url.host,
                  let lastPathComponent = url.pathComponents.last else {
                return id
            }

            let repoName = lastPathComponent.hasSuffix(".git")
                ? String(lastPathComponent.dropLast(4))
                : lastPathComponent
            return repoName.isEmpty ? host : "\(repoName) (\(host))"
        }

        private static func newest(
            _ lhsValue: Int,
            _ rhsValue: Int,
            _ lhsID: String,
            _ rhsID: String
        ) -> Bool {
            if lhsValue == rhsValue {
                lhsID < rhsID
            } else {
                lhsValue > rhsValue
            }
        }

        private static func oldest(
            _ lhsValue: Int,
            _ rhsValue: Int,
            _ lhsID: String,
            _ rhsID: String
        ) -> Bool {
            if lhsValue == rhsValue {
                lhsID < rhsID
            } else {
                lhsValue < rhsValue
            }
        }

        private static func compareNames(
            _ lhs: ThreadSnapshot,
            _ rhs: ThreadSnapshot,
            ascending: Bool
        ) -> Bool {
            let lhsName = lhs.name ?? lhs.preview
            let rhsName = rhs.name ?? rhs.preview
            let comparison = lhsName.localizedStandardCompare(rhsName)
            if comparison == .orderedSame {
                return newest(lhs.updatedAt, rhs.updatedAt, lhs.id, rhs.id)
            }
            return ascending
                ? comparison == .orderedAscending
                : comparison == .orderedDescending
        }

        private static func compareSelection(
            _ lhs: ThreadSnapshot,
            _ rhs: ThreadSnapshot,
            selectionOrderByThreadID: [String: Int]
        ) -> Bool {
            let lhsOrder = selectionOrderByThreadID[lhs.id]
            let rhsOrder = selectionOrderByThreadID[rhs.id]

            switch (lhsOrder, rhsOrder) {
            case let (lhsOrder?, rhsOrder?):
                if lhsOrder == rhsOrder {
                    return newest(lhs.updatedAt, rhs.updatedAt, lhs.id, rhs.id)
                }
                return lhsOrder > rhsOrder
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return newest(lhs.updatedAt, rhs.updatedAt, lhs.id, rhs.id)
            }
        }
    }
}

public extension CodexAppServer {
    @MainActor
    func makeLibrary(
        configuration: Library.Configuration = .init()
    ) async throws -> Library {
        let initialThreads = try await libraryThreadSnapshots(query: configuration.query)
        return Library(
            appServer: self,
            configuration: configuration,
            initialThreads: initialThreads
        )
    }
}

extension CodexAppServer.Library.ThreadSnapshot {
    init(_ snapshot: ThreadHistoryStore.ThreadListSnapshot) {
        self.init(
            id: snapshot.id,
            cliVersion: snapshot.cliVersion,
            createdAt: snapshot.createdAt,
            currentDirectoryPath: snapshot.currentDirectoryPath,
            ephemeral: snapshot.ephemeral,
            forkedFromThreadID: snapshot.forkedFromThreadID,
            currentGitBranch: snapshot.gitBranch,
            currentGitOriginURL: snapshot.gitOriginURL,
            isArchived: snapshot.isArchived,
            isClosed: snapshot.isClosed,
            lastCompletedTurnAt: snapshot.lastCompletedTurnAt,
            modelProvider: snapshot.modelProvider,
            name: snapshot.name,
            preview: snapshot.preview,
            status: .init(
                type: .init(rawValue: snapshot.statusType) ?? .notLoaded,
                activeFlags: snapshot.statusFlags.compactMap(CodexAppServer.ThreadActiveFlag.init(rawValue:))
            ),
            updatedAt: snapshot.updatedAt
        )
    }
}
