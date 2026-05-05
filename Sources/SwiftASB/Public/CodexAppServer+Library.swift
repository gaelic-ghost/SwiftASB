import Foundation
import Observation

extension CodexAppServer {
    internal enum LibraryEvent: Sendable, Equatable {
        case threadChanged(threadID: String)
        case turnCompleted(threadID: String)
    }
}

public extension CodexAppServer {
    struct ThreadListQD: Sendable, Equatable {
        public var archived: Bool?
        public var currentDirectoryPath: String?
        public var limit: Int
        public var searchTerm: String?
        public var sortedBy: Library.SortedBy

        public init(
            archived: Bool? = nil,
            currentDirectoryPath: String? = nil,
            limit: Int = 50,
            searchTerm: String? = nil,
            sortedBy: Library.SortedBy = .updatedNewestFirst
        ) {
            self.archived = archived
            self.currentDirectoryPath = currentDirectoryPath
            self.limit = max(1, limit)
            self.searchTerm = searchTerm
            self.sortedBy = sortedBy
        }

        public static func all(
            limit: Int = 50,
            sortedBy: Library.SortedBy = .updatedNewestFirst
        ) -> Self {
            .init(limit: limit, sortedBy: sortedBy)
        }

        public static func unarchived(
            limit: Int = 50,
            sortedBy: Library.SortedBy = .updatedNewestFirst
        ) -> Self {
            .init(archived: false, limit: limit, sortedBy: sortedBy)
        }

        public static func archived(
            limit: Int = 50,
            sortedBy: Library.SortedBy = .updatedNewestFirst
        ) -> Self {
            .init(archived: true, limit: limit, sortedBy: sortedBy)
        }

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
                sortedBy: sortedBy
            )
        }

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

        public func limited(to limit: Int) -> Self {
            .init(
                archived: archived,
                currentDirectoryPath: currentDirectoryPath,
                limit: limit,
                searchTerm: searchTerm,
                sortedBy: sortedBy
            )
        }

        public func sorted(by sortedBy: Library.SortedBy) -> Self {
            .init(
                archived: archived,
                currentDirectoryPath: currentDirectoryPath,
                limit: limit,
                searchTerm: searchTerm,
                sortedBy: sortedBy
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
                archived: archiveFilter,
                currentDirectoryPath: currentDirectoryPath,
                searchTerm: searchTerm
            )
        }
    }
}

public extension CodexAppServer {
    @MainActor
    @Observable
    final class Library {
        public struct Configuration: Sendable, Equatable {
            public var groupedBy: GroupedBy
            public var maxPagesPerArchiveState: Int
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
                reconcilesOnCreation: Bool = true
            ) {
                let normalizedPageSize = max(1, pageSize)
                self.pageSize = normalizedPageSize
                self.maxPagesPerArchiveState = max(1, maxPagesPerArchiveState)
                self.sortedBy = sortedBy
                self.groupedBy = groupedBy
                self.query = .init(
                    archived: query.archived,
                    currentDirectoryPath: query.currentDirectoryPath,
                    limit: normalizedPageSize,
                    searchTerm: query.searchTerm,
                    sortedBy: sortedBy
                )
                self.reconcilesOnCreation = reconcilesOnCreation
            }
        }

        public enum GroupedBy: String, Sendable, Equatable {
            case none
            case cwd
        }

        public enum ReconciliationPhase: String, Sendable, Equatable {
            case idle
            case loadingLocalSnapshot
            case reconcilingUnarchived
            case reconcilingArchived
        }

        public enum SortedBy: String, Sendable, Equatable {
            case updatedNewestFirst
            case updatedOldestFirst
            case createdNewestFirst
            case createdOldestFirst
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
        public private(set) var lastReconciledAt: Date?
        public private(set) var latestErrorDescription: String?
        public private(set) var phase: ReconciliationPhase
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

        public var isLoadingLocalSnapshot: Bool {
            phase == .loadingLocalSnapshot
        }

        public var isReconciling: Bool {
            phase == .reconcilingUnarchived || phase == .reconcilingArchived
        }

        @ObservationIgnored
        private let appServer: CodexAppServer

        @ObservationIgnored
        private var allThreads: [ThreadSnapshot]

        @ObservationIgnored
        private let maxPagesPerArchiveState: Int

        @ObservationIgnored
        private var pendingEventReload = false

        @ObservationIgnored
        private var query: CodexAppServer.ThreadListQD

        @ObservationIgnored
        private var eventTask: Task<Void, Never>?

        @ObservationIgnored
        private var refreshTask: Task<Void, Never>?

        internal init(
            appServer: CodexAppServer,
            configuration: Configuration,
            initialThreads: [ThreadSnapshot]
        ) {
            self.appServer = appServer
            self.allThreads = initialThreads
            self.archivedThreads = []
            self.groups = []
            self.groupedBy = configuration.groupedBy
            self.lastReconciledAt = nil
            self.latestErrorDescription = nil
            self.maxPagesPerArchiveState = configuration.maxPagesPerArchiveState
            self.phase = .idle
            self.query = configuration.query
            self.sortedBy = configuration.sortedBy
            self.unarchivedThreads = []
            applyVisibleState()

            if configuration.reconcilesOnCreation {
                refreshTask = Task { [weak self] in await self?.refreshAll() }
            }
            startEventTask()
        }

        deinit {
            eventTask?.cancel()
            refreshTask?.cancel()
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
                applyVisibleState()
            } catch {
                latestErrorDescription = error.localizedDescription
            }
        }

        private func applyVisibleState() {
            let sortedThreads = Self.sort(allThreads, by: sortedBy)
            unarchivedThreads = sortedThreads.filter { !$0.isArchived }
            archivedThreads = sortedThreads.filter(\.isArchived)
            groups = Self.groups(
                from: unarchivedThreads,
                groupedBy: groupedBy
            )
        }

        private static func sort(
            _ threads: [ThreadSnapshot],
            by sortedBy: SortedBy
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
                }
            }

            return grouped
                .map { key, threads in
                    ThreadGroup(
                        id: key,
                        title: key.isEmpty ? "Unknown Project" : key,
                        threads: threads
                    )
                }
                .sorted { lhs, rhs in
                    lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }
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
