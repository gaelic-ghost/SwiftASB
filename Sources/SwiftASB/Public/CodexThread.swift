import Foundation
import Observation

public struct CodexThread: Sendable {
    @MainActor
    @Observable
    public final class RecentTurns {
        public struct CachePolicy: Sendable, Equatable {
            public let fastScrollVelocityThreshold: Double
            public let jitterScrollVelocityThreshold: Double
            public let edgePrefetchThreshold: Int
            public let maximumResidentItemCost: Int?
            public let maxPrefetchPagesPerPass: Int
            public let maxResidentTurns: Int
            public let minimumResidentTurns: Int
            public let protectedRecentCompletedTurns: Int
            public let protectedTurnBuffer: Int
            public let veryFastScrollVelocityThreshold: Double

            public init(
                maxResidentTurns: Int,
                minimumResidentTurns: Int = 1,
                maximumResidentItemCost: Int? = nil,
                protectedTurnBuffer: Int = 2,
                protectedRecentCompletedTurns: Int = 2,
                edgePrefetchThreshold: Int = 1,
                jitterScrollVelocityThreshold: Double = 120,
                fastScrollVelocityThreshold: Double = 1_200,
                veryFastScrollVelocityThreshold: Double = 2_400,
                maxPrefetchPagesPerPass: Int = 3
            ) {
                let normalizedMaxResidentTurns = max(1, maxResidentTurns)
                let normalizedMinimumResidentTurns = min(
                    normalizedMaxResidentTurns,
                    max(1, minimumResidentTurns)
                )
                let normalizedProtectedRecentCompletedTurns = min(
                    normalizedMaxResidentTurns,
                    max(1, protectedRecentCompletedTurns)
                )
                self.maxResidentTurns = normalizedMaxResidentTurns
                self.minimumResidentTurns = normalizedMinimumResidentTurns
                self.maximumResidentItemCost = maximumResidentItemCost.map { max(1, $0) }
                self.protectedTurnBuffer = max(0, protectedTurnBuffer)
                self.edgePrefetchThreshold = max(0, edgePrefetchThreshold)
                self.protectedRecentCompletedTurns = normalizedProtectedRecentCompletedTurns
                self.jitterScrollVelocityThreshold = max(0, jitterScrollVelocityThreshold)
                self.fastScrollVelocityThreshold = max(0, fastScrollVelocityThreshold)
                self.veryFastScrollVelocityThreshold = max(
                    self.fastScrollVelocityThreshold,
                    veryFastScrollVelocityThreshold
                )
                self.maxPrefetchPagesPerPass = max(1, maxPrefetchPagesPerPass)
            }

            public static func automatic(pageSize: Int) -> Self {
                chatUI(pageSize: pageSize)
            }

            public static func chatUI(pageSize: Int = 12) -> Self {
                let normalizedPageSize = max(1, pageSize)
                return .init(
                    maxResidentTurns: max(normalizedPageSize * 3, normalizedPageSize + 8),
                    minimumResidentTurns: max(2, normalizedPageSize),
                    maximumResidentItemCost: max(normalizedPageSize * 12, 24),
                    protectedTurnBuffer: max(1, normalizedPageSize / 2),
                    protectedRecentCompletedTurns: 2,
                    edgePrefetchThreshold: max(1, min(2, normalizedPageSize)),
                    jitterScrollVelocityThreshold: 120,
                    fastScrollVelocityThreshold: 1_100,
                    veryFastScrollVelocityThreshold: 2_100,
                    maxPrefetchPagesPerPass: 3
                )
            }

            public static func inspector(pageSize: Int = 24) -> Self {
                let normalizedPageSize = max(1, pageSize)
                return .init(
                    maxResidentTurns: max(normalizedPageSize * 5, normalizedPageSize + 20),
                    minimumResidentTurns: max(4, normalizedPageSize),
                    maximumResidentItemCost: max(normalizedPageSize * 20, 64),
                    protectedTurnBuffer: max(2, normalizedPageSize / 3),
                    protectedRecentCompletedTurns: 3,
                    edgePrefetchThreshold: max(2, min(4, normalizedPageSize / 2)),
                    jitterScrollVelocityThreshold: 80,
                    fastScrollVelocityThreshold: 900,
                    veryFastScrollVelocityThreshold: 1_800,
                    maxPrefetchPagesPerPass: 4
                )
            }

            public static func historyRail(pageSize: Int = 8) -> Self {
                let normalizedPageSize = max(1, pageSize)
                return .init(
                    maxResidentTurns: max(normalizedPageSize * 2, normalizedPageSize + 6),
                    minimumResidentTurns: max(2, normalizedPageSize / 2),
                    maximumResidentItemCost: max(normalizedPageSize * 8, 16),
                    protectedTurnBuffer: 1,
                    protectedRecentCompletedTurns: 1,
                    edgePrefetchThreshold: 1,
                    jitterScrollVelocityThreshold: 140,
                    fastScrollVelocityThreshold: 1_250,
                    veryFastScrollVelocityThreshold: 2_500,
                    maxPrefetchPagesPerPass: 2
                )
            }
        }

        public enum ScrollActivityPhase: String, Sendable, Equatable {
            case idle
            case tracking
            case interacting
            case decelerating
            case animating
        }

        public struct TurnSnapshot: Sendable, Equatable, Identifiable {
            public struct Item: Sendable, Equatable, Identifiable {
                public let id: String
                public let isLowValueForResidency: Bool
                public let orderIndex: Int
                public let kind: String
                public let command: String?
                public let path: String?
                public let serverName: String?
                public let status: String?
                public let streamedText: String?
                public let text: String?
                public let toolName: String?
            }

            public struct TokenUsage: Sendable, Equatable {
                public let cachedInputTokens: Int?
                public let inputTokens: Int?
                public let outputTokens: Int?
                public let reasoningOutputTokens: Int?
                public let totalTokens: Int?
                public let modelContextWindow: Int?
            }

            public let id: String
            public let completedAt: Int?
            public let diff: String?
            public let durationMS: Int?
            public let errorMessage: String?
            public let isItemPayloadComplete: Bool
            public let items: [Item]
            public let omittedItemCount: Int
            public let orderIndex: Int
            public let startedAt: Int?
            public let status: String
            public let tokenUsage: TokenUsage?
        }

        public let cachePolicy: CachePolicy
        public let threadID: String
        public let residentLimit: Int
        public private(set) var isLoadingNewerTurns: Bool
        public private(set) var isLoadingOlderTurns: Bool
        public private(set) var lastLoadErrorDescription: String?
        public private(set) var nextNewerCursor: String?
        public private(set) var nextOlderCursor: String?
        public private(set) var residentItemCount: Int
        public private(set) var residentItemCost: Int
        public private(set) var scrollActivityPhase: ScrollActivityPhase
        public private(set) var scrollVelocityPointsPerSecond: Double?
        public private(set) var turns: [TurnSnapshot]
        public private(set) var visibleTurnIDs: [String]
        public var scrollPositionTurnID: String? {
            didSet {
                scheduleViewportMaintenance()
            }
        }

        @ObservationIgnored
        private let appServer: CodexAppServer

        @ObservationIgnored
        private var eventTask: Task<Void, Never>?

        @ObservationIgnored
        private var viewportTask: Task<Void, Never>?

        @ObservationIgnored
        private var unresolvedInteractiveTurnIDs: Set<String> = []

        internal init(
            cachePolicy: CachePolicy,
            threadID: String,
            residentLimit: Int,
            nextNewerCursor: String?,
            nextOlderCursor: String?,
            initialTurns: [TurnSnapshot],
            events: AsyncThrowingStream<CodexTurnEvent, Error>,
            appServer: CodexAppServer
        ) {
            self.cachePolicy = cachePolicy
            self.threadID = threadID
            self.residentLimit = residentLimit
            self.isLoadingNewerTurns = false
            self.isLoadingOlderTurns = false
            self.lastLoadErrorDescription = nil
            self.nextNewerCursor = nextNewerCursor
            self.nextOlderCursor = nextOlderCursor
            self.residentItemCount = initialTurns.reduce(0) { $0 + $1.items.count }
            self.residentItemCost = initialTurns.reduce(0) { partialResult, turn in
                partialResult + Self.turnResidentCost(turn)
            }
            self.scrollActivityPhase = .idle
            self.scrollVelocityPointsPerSecond = nil
            self.turns = initialTurns
            self.visibleTurnIDs = []
            self.scrollPositionTurnID = nil
            self.appServer = appServer
            trimResidentTurnsIfNeeded()

            eventTask = Task { [weak self] in
                guard let self else { return }

                do {
                    for try await event in events {
                        await self.apply(event)
                    }
                } catch is CancellationError {
                    return
                } catch {
                    return
                }
            }
        }

        deinit {
            eventTask?.cancel()
            viewportTask?.cancel()
        }

        public func loadOlderTurns(limit: Int? = nil) async throws {
            guard !isLoadingOlderTurns else { return }
            guard let oldestOrderIndex = turns.last?.orderIndex else { return }
            let pageLimit = limit ?? residentLimit
            isLoadingOlderTurns = true
            defer { isLoadingOlderTurns = false }

            do {
                let window = try await appServer.olderTurnWindow(
                    threadID: threadID,
                    olderThanOrderIndex: oldestOrderIndex,
                    cursor: nextOlderCursor,
                    limit: pageLimit
                )
                lastLoadErrorDescription = nil
                merge(window.turns.map(TurnSnapshot.init))
                nextOlderCursor = window.nextOlderCursor
                if let nextNewerCursor = window.nextNewerCursor {
                    self.nextNewerCursor = nextNewerCursor
                }
                trimResidentTurnsIfNeeded()
                scheduleViewportMaintenance()
            } catch {
                lastLoadErrorDescription = Self.describe(error)
                throw error
            }
        }

        public func loadNewerTurns(limit: Int? = nil) async throws {
            guard !isLoadingNewerTurns else { return }
            guard let newestOrderIndex = turns.first?.orderIndex else { return }
            let pageLimit = limit ?? residentLimit
            isLoadingNewerTurns = true
            defer { isLoadingNewerTurns = false }

            do {
                let window = try await appServer.newerTurnWindow(
                    threadID: threadID,
                    newerThanOrderIndex: newestOrderIndex,
                    cursor: nextNewerCursor,
                    limit: pageLimit
                )
                lastLoadErrorDescription = nil
                merge(window.turns.map(TurnSnapshot.init))
                if let nextOlderCursor = window.nextOlderCursor {
                    self.nextOlderCursor = nextOlderCursor
                }
                nextNewerCursor = window.nextNewerCursor
                trimResidentTurnsIfNeeded()
                scheduleViewportMaintenance()
            } catch {
                lastLoadErrorDescription = Self.describe(error)
                throw error
            }
        }

        public func updateVisibleTurnIDs(_ ids: [String]) {
            let deduplicatedIDs = Array(NSOrderedSet(array: ids)) as? [String] ?? ids
            visibleTurnIDs = deduplicatedIDs
            scheduleViewportMaintenance()
        }

        public func updateScrollActivity(
            phase: ScrollActivityPhase,
            verticalVelocityPointsPerSecond: Double? = nil
        ) {
            scrollActivityPhase = phase
            scrollVelocityPointsPerSecond = verticalVelocityPointsPerSecond
            scheduleViewportMaintenance()
        }

        private func apply(_ event: CodexTurnEvent) async {
            guard let turnID = Self.turnID(from: event) else { return }
            guard let snapshot = try? await appServer.turnSnapshot(threadID: threadID, turnID: turnID) else {
                return
            }

            merge([TurnSnapshot(snapshot)])
            trimResidentTurnsIfNeeded()
            scheduleViewportMaintenance()
        }

        private static func turnID(from event: CodexTurnEvent) -> String? {
            switch event {
            case let .started(started):
                started.turn.id
            case let .planUpdated(update):
                update.turnID
            case let .planDelta(delta):
                delta.turnID
            case let .diffUpdated(update):
                update.turnID
            case let .itemStarted(itemStarted):
                itemStarted.turnID
            case let .itemCompleted(itemCompleted):
                itemCompleted.turnID
            case let .agentMessageDelta(delta):
                delta.turnID
            case let .reasoningSummaryPartAdded(delta):
                delta.turnID
            case let .reasoningSummaryTextDelta(delta):
                delta.turnID
            case let .reasoningTextDelta(delta):
                delta.turnID
            case let .completed(completion):
                completion.turn.id
            case .approvalRequested, .elicitationRequested, .serverRequestResolved:
                nil
            }
        }

        private func merge(_ incoming: [TurnSnapshot]) {
            guard !incoming.isEmpty else { return }

            for snapshot in incoming {
                if let index = turns.firstIndex(where: { $0.id == snapshot.id }) {
                    turns[index] = snapshot
                } else {
                    turns.append(snapshot)
                }
            }

            turns.sort { $0.orderIndex > $1.orderIndex }
            refreshResidentMetrics()
        }

        private func scheduleViewportMaintenance() {
            viewportTask?.cancel()
            viewportTask = Task { [weak self] in
                guard let self else { return }
                await self.refreshProtectedTurnContext()
                await self.hydrateProtectedTurnsIfNeeded()
                self.trimResidentTurnsIfNeeded()
                await self.prefetchForViewportIfNeeded()
            }
        }

        private func prefetchForViewportIfNeeded() async {
            guard !turns.isEmpty else { return }
            guard scrollPositionTurnID != nil || !visibleTurnIDs.isEmpty else { return }
            guard !shouldSuppressPrefetchForCurrentScrollActivity() else { return }

            let focusIndices = focusIndices()
            let lowerEdgeThreshold = cachePolicy.edgePrefetchThreshold
            let upperEdgeThreshold = max(0, turns.count - 1 - cachePolicy.edgePrefetchThreshold)
            let pageCount = prefetchPageCount()

            if focusIndices.upperBound >= upperEdgeThreshold {
                for _ in 0..<pageCount {
                    let previousCount = turns.count
                    do {
                        try await loadOlderTurns()
                    } catch {
                        return
                    }
                    if turns.count == previousCount {
                        break
                    }
                }
            }

            if focusIndices.lowerBound <= lowerEdgeThreshold {
                for _ in 0..<pageCount {
                    let previousCount = turns.count
                    do {
                        try await loadNewerTurns()
                    } catch {
                        return
                    }
                    if turns.count == previousCount {
                        break
                    }
                }
            }
        }

        private func trimResidentTurnsIfNeeded() {
            let maxResidentTurns = cachePolicy.maxResidentTurns
            if turns.count > maxResidentTurns {
                let focusIndices = focusIndices()
                let focusLowerBound = max(0, focusIndices.lowerBound - cachePolicy.protectedTurnBuffer)
                let focusUpperBound = min(turns.count - 1, focusIndices.upperBound + cachePolicy.protectedTurnBuffer)

                var mandatoryIndices = Set<Int>(focusLowerBound...focusUpperBound)
                for (index, turn) in turns.enumerated() where !Self.isTerminalStatus(turn.status) {
                    mandatoryIndices.insert(index)
                }

                let retainedIndices: Set<Int>
                if mandatoryIndices.count >= maxResidentTurns {
                    retainedIndices = mandatoryIndices
                } else {
                    let supplementalIndices = turns.indices
                        .filter { !mandatoryIndices.contains($0) }
                        .sorted { lhs, rhs in
                            let lhsDistance = Self.distanceToRange(lhs, lowerBound: focusLowerBound, upperBound: focusUpperBound)
                            let rhsDistance = Self.distanceToRange(rhs, lowerBound: focusLowerBound, upperBound: focusUpperBound)
                            if lhsDistance != rhsDistance {
                                return lhsDistance < rhsDistance
                            }
                            return lhs < rhs
                        }

                    var selectedIndices = mandatoryIndices
                    for index in supplementalIndices.prefix(maxResidentTurns - mandatoryIndices.count) {
                        selectedIndices.insert(index)
                    }
                    retainedIndices = selectedIndices
                }

                turns = turns.enumerated()
                    .filter { retainedIndices.contains($0.offset) }
                    .map(\.element)
                refreshResidentMetrics()
            }

            trimResidentItemsIfNeeded()
        }

        private func trimResidentItemsIfNeeded() {
            guard let maximumResidentItemCost = cachePolicy.maximumResidentItemCost else {
                refreshResidentMetrics()
                return
            }

            refreshResidentMetrics()
            guard residentItemCost > maximumResidentItemCost else { return }

            let protectedTurnIDs = protectedTurnIDSet()
            slimResidentTurnsIfNeeded(protectedTurnIDs: protectedTurnIDs)
            while residentItemCost > maximumResidentItemCost, turns.count > cachePolicy.minimumResidentTurns {
                guard let evictableIndex = turns.indices.reversed().first(where: { index in
                    let turn = turns[index]
                    return Self.isTerminalStatus(turn.status) && !protectedTurnIDs.contains(turn.id)
                }) else {
                    break
                }

                turns.remove(at: evictableIndex)
                refreshResidentMetrics()
            }
        }

        private func slimResidentTurnsIfNeeded(protectedTurnIDs: Set<String>) {
            guard let maximumResidentItemCost = cachePolicy.maximumResidentItemCost else { return }

            for index in turns.indices.reversed() {
                guard residentItemCost > maximumResidentItemCost else { break }
                let turn = turns[index]
                guard Self.isTerminalStatus(turn.status) else { continue }
                guard !protectedTurnIDs.contains(turn.id) else { continue }
                guard turn.isItemPayloadComplete else { continue }
                let slimmedTurn = Self.slimmedSnapshot(from: turn)
                guard slimmedTurn != turn else { continue }
                turns[index] = slimmedTurn
                refreshResidentMetrics()
            }
        }

        private func protectedTurnIDSet() -> Set<String> {
            let focusIndices = focusIndices()
            let focusLowerBound = max(0, focusIndices.lowerBound - cachePolicy.protectedTurnBuffer)
            let focusUpperBound = min(turns.count - 1, focusIndices.upperBound + cachePolicy.protectedTurnBuffer)
            var protectedIDs = Set(turns[focusLowerBound...focusUpperBound].map(\.id))
            for turn in turns where !Self.isTerminalStatus(turn.status) {
                protectedIDs.insert(turn.id)
            }
            for turn in turns.prefix(cachePolicy.protectedRecentCompletedTurns) where Self.isTerminalStatus(turn.status) {
                protectedIDs.insert(turn.id)
            }
            protectedIDs.formUnion(unresolvedInteractiveTurnIDs)
            return protectedIDs
        }

        private func refreshResidentMetrics() {
            residentItemCount = turns.reduce(0) { $0 + $1.items.count }
            residentItemCost = turns.reduce(0) { $0 + Self.turnResidentCost($1) }
        }

        private func prefetchPageCount() -> Int {
            guard let velocity = scrollVelocityPointsPerSecond.map(abs) else { return 1 }
            if velocity >= cachePolicy.veryFastScrollVelocityThreshold {
                return cachePolicy.maxPrefetchPagesPerPass
            }
            if velocity >= cachePolicy.fastScrollVelocityThreshold {
                return min(2, cachePolicy.maxPrefetchPagesPerPass)
            }
            return 1
        }

        private func shouldSuppressPrefetchForCurrentScrollActivity() -> Bool {
            guard let velocity = scrollVelocityPointsPerSecond.map(abs) else { return false }
            return switch scrollActivityPhase {
            case .tracking, .interacting:
                velocity < cachePolicy.jitterScrollVelocityThreshold
            case .idle, .decelerating, .animating:
                false
            }
        }

        private func refreshProtectedTurnContext() async {
            unresolvedInteractiveTurnIDs = await appServer.unresolvedInteractiveTurnIDs(threadID: threadID)
        }

        private func hydrateProtectedTurnsIfNeeded() async {
            let protectedTurnIDs = protectedTurnIDSet()
            let slimmedProtectedTurnIDs: [String] = turns.compactMap { turn in
                guard protectedTurnIDs.contains(turn.id), !turn.isItemPayloadComplete else { return nil }
                return turn.id
            }

            guard !slimmedProtectedTurnIDs.isEmpty else { return }

            for turnID in slimmedProtectedTurnIDs {
                do {
                    guard let snapshot = try await appServer.turnSnapshot(threadID: threadID, turnID: turnID) else {
                        continue
                    }
                    merge([TurnSnapshot(snapshot)])
                    lastLoadErrorDescription = nil
                } catch {
                    lastLoadErrorDescription = Self.describe(error)
                }
            }
        }

        private func focusIndices() -> ClosedRange<Int> {
            let visibleIndexSet = Set(visibleTurnIDs.compactMap(index(forTurnID:)))
            if !visibleIndexSet.isEmpty {
                return visibleIndexSet.min()!...visibleIndexSet.max()!
            }

            if let scrollPositionTurnID, let index = index(forTurnID: scrollPositionTurnID) {
                return index...index
            }

            return 0...0
        }

        private func index(forTurnID turnID: String) -> Int? {
            turns.firstIndex { $0.id == turnID }
        }

        private static func distanceToRange(
            _ index: Int,
            lowerBound: Int,
            upperBound: Int
        ) -> Int {
            if index < lowerBound {
                return lowerBound - index
            }
            if index > upperBound {
                return index - upperBound
            }
            return 0
        }

        private static func isTerminalStatus(_ status: String) -> Bool {
            switch status {
            case CodexAppServer.TurnStatus.completed.rawValue,
                 CodexAppServer.TurnStatus.failed.rawValue,
                 CodexAppServer.TurnStatus.interrupted.rawValue:
                true
            default:
                false
            }
        }

        private static func describe(_ error: any Error) -> String {
            if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
                return description
            }
            return String(describing: error)
        }

        private static func slimmedSnapshot(from snapshot: TurnSnapshot) -> TurnSnapshot {
            let retainedItems = snapshot.items.filter { !$0.isLowValueForResidency }
            let omittedItemCount = snapshot.items.count - retainedItems.count
            guard omittedItemCount > 0 else { return snapshot }
            return .init(
                id: snapshot.id,
                completedAt: snapshot.completedAt,
                diff: snapshot.diff,
                durationMS: snapshot.durationMS,
                errorMessage: snapshot.errorMessage,
                isItemPayloadComplete: false,
                items: retainedItems,
                omittedItemCount: omittedItemCount,
                orderIndex: snapshot.orderIndex,
                startedAt: snapshot.startedAt,
                status: snapshot.status,
                tokenUsage: snapshot.tokenUsage
            )
        }

        private static func turnResidentCost(_ turn: TurnSnapshot) -> Int {
            turn.items.reduce(0) { $0 + itemResidentCost($1) }
        }

        private static func itemResidentCost(_ item: TurnSnapshot.Item) -> Int {
            let baseCost: Int
            if item.isLowValueForResidency {
                baseCost = 1
            } else {
                baseCost = 3
            }

            let textLength = (item.text ?? item.streamedText ?? "").count
            let textWeight: Int
            switch textLength {
            case 0..<80:
                textWeight = 0
            case 80..<240:
                textWeight = 1
            case 240..<800:
                textWeight = 2
            default:
                textWeight = 3
            }

            return baseCost + textWeight
        }

        nonisolated private static func isLowValueItemKind(_ kind: String) -> Bool {
            switch kind {
            case CodexTurnItem.Kind.commandExecution.rawValue,
                 CodexTurnItem.Kind.collabAgentToolCall.rawValue,
                 CodexTurnItem.Kind.contextCompaction.rawValue,
                 CodexTurnItem.Kind.dynamicToolCall.rawValue,
                 CodexTurnItem.Kind.enteredReviewMode.rawValue,
                 CodexTurnItem.Kind.exitedReviewMode.rawValue,
                 CodexTurnItem.Kind.fileChange.rawValue,
                 CodexTurnItem.Kind.hookPrompt.rawValue,
                 CodexTurnItem.Kind.imageGeneration.rawValue,
                 CodexTurnItem.Kind.imageView.rawValue,
                 CodexTurnItem.Kind.mcpToolCall.rawValue,
                 CodexTurnItem.Kind.webSearch.rawValue:
                true
            case CodexTurnItem.Kind.agentMessage.rawValue,
                 CodexTurnItem.Kind.plan.rawValue,
                 CodexTurnItem.Kind.reasoning.rawValue,
                 CodexTurnItem.Kind.userMessage.rawValue:
                false
            default:
                false
            }
        }
    }

    @MainActor
    @Observable
    public final class RecentFiles {
        public struct FileSnapshot: Sendable, Equatable, Identifiable {
            public enum Status: String, Sendable, Equatable {
                case completed
                case errored
                case inProgress
            }

            public let id: String
            public let itemID: String
            public private(set) var displayName: String
            public private(set) var latestStatusText: String?
            public private(set) var path: String?
            public private(set) var payloadText: String?
            public private(set) var status: Status
            public let turnID: String

            var itemOrderIndex: Int?
            var turnOrderIndex: Int?
            var turnStartedAt: Int?

            fileprivate mutating func apply(delta: String) {
                payloadText = (payloadText ?? "") + delta
                latestStatusText = latestStatusText ?? "Streaming file change"
                status = .inProgress
            }

            fileprivate mutating func apply(_ item: CodexTurnItem, status: Status) {
                displayName = Self.makeDisplayName(path: item.path)
                latestStatusText = item.status ?? item.text ?? latestStatusText
                path = item.path
                payloadText = item.text ?? payloadText
                self.status = status
            }

            fileprivate static func makeDisplayName(path: String?) -> String {
                guard let path, !path.isEmpty else { return "File edit" }
                return URL(fileURLWithPath: path).lastPathComponent
            }
        }

        public let residentLimit: Int
        public let threadID: String
        public private(set) var files: [FileSnapshot]
        public private(set) var isLoadingOlderFiles: Bool
        public private(set) var lastLoadErrorDescription: String?
        public private(set) var nextOlderCursor: String?

        @ObservationIgnored
        private let appServer: CodexAppServer

        @ObservationIgnored
        private var fileDeltaTask: Task<Void, Never>?

        @ObservationIgnored
        private var turnEventTask: Task<Void, Never>?

        internal init(
            threadID: String,
            residentLimit: Int,
            nextOlderCursor: String?,
            initialFiles: [FileSnapshot],
            turnEvents: AsyncThrowingStream<CodexTurnEvent, Error>,
            fileDeltaEvents: AsyncStream<CodexAppServer.FileChangeOutputDeltaEvent>,
            appServer: CodexAppServer
        ) {
            self.threadID = threadID
            self.residentLimit = residentLimit
            self.nextOlderCursor = nextOlderCursor
            self.files = initialFiles
            self.isLoadingOlderFiles = false
            self.lastLoadErrorDescription = nil
            self.appServer = appServer

            turnEventTask = Task { [weak self] in
                guard let self else { return }

                do {
                    for try await event in turnEvents {
                        await self.apply(event)
                    }
                } catch is CancellationError {
                    return
                } catch {
                    return
                }
            }

            fileDeltaTask = Task { [weak self] in
                guard let self else { return }

                for await event in fileDeltaEvents {
                    self.apply(event)
                }
            }
        }

        deinit {
            turnEventTask?.cancel()
            fileDeltaTask?.cancel()
        }

        public func loadOlderFiles(limit: Int? = nil) async throws {
            guard !isLoadingOlderFiles else { return }
            guard let oldestFile = files.last else { return }
            guard oldestFile.turnOrderIndex != nil, oldestFile.itemOrderIndex != nil else { return }

            isLoadingOlderFiles = true
            defer { isLoadingOlderFiles = false }

            do {
                let window = try await appServer.olderFileWindow(
                    threadID: threadID,
                    olderThan: oldestFile.appServerSnapshot,
                    cursor: nextOlderCursor,
                    limit: limit ?? residentLimit
                )
                mergeOlder(window.files.map(FileSnapshot.init))
                nextOlderCursor = window.nextOlderCursor
                lastLoadErrorDescription = nil
            } catch {
                lastLoadErrorDescription = error.localizedDescription
                throw error
            }
        }

        private func apply(_ event: CodexTurnEvent) async {
            switch event {
            case let .itemStarted(started):
                guard started.item.kind == .fileChange else { return }
                upsertLiveFile(from: started.item, turnID: started.turnID, status: .inProgress)
            case let .itemCompleted(completed):
                guard completed.item.kind == .fileChange else { return }
                upsertLiveFile(
                    from: completed.item,
                    turnID: completed.turnID,
                    status: completed.item.isErrored ? .errored : .completed
                )
            case let .completed(completion):
                await refreshFiles(for: completion.turn.id)
            default:
                return
            }
        }

        private func apply(_ event: CodexAppServer.FileChangeOutputDeltaEvent) {
            let fileID = Self.fileSnapshotID(turnID: event.turnID, itemID: event.itemID)
            guard let index = files.firstIndex(where: { $0.id == fileID }) else { return }
            files[index].apply(delta: event.delta)
        }

        private func refreshFiles(for turnID: String) async {
            guard let snapshot = try? await appServer.turnSnapshot(threadID: threadID, turnID: turnID) else {
                return
            }

            let refreshedFiles = snapshot.items
                .filter { $0.kind == CodexTurnItem.Kind.fileChange.rawValue }
                .sorted { $0.orderIndex > $1.orderIndex }
                .map { item in
                    FileSnapshot(
                        id: Self.fileSnapshotID(turnID: turnID, itemID: item.id),
                        itemID: item.id,
                        displayName: FileSnapshot.makeDisplayName(path: item.path),
                        latestStatusText: item.status ?? item.text,
                        path: item.path,
                        payloadText: item.streamedText ?? item.text,
                        status: Self.status(from: item.status),
                        turnID: turnID,
                        itemOrderIndex: item.orderIndex,
                        turnOrderIndex: snapshot.orderIndex,
                        turnStartedAt: snapshot.startedAt
                    )
                }

            mergeOrPrepend(refreshedFiles)
        }

        private func mergeOlder(_ incoming: [FileSnapshot]) {
            var existingIDs = Set(files.map(\.id))
            for file in incoming where !existingIDs.contains(file.id) {
                files.append(file)
                existingIDs.insert(file.id)
            }
        }

        private func mergeOrPrepend(_ incoming: [FileSnapshot]) {
            for file in incoming.reversed() {
                if let index = files.firstIndex(where: { $0.id == file.id }) {
                    files[index] = file
                } else {
                    files.insert(file, at: 0)
                }
            }

            if files.count > residentLimit {
                files = Array(files.prefix(residentLimit))
            }
        }

        private func upsertLiveFile(
            from item: CodexTurnItem,
            turnID: String,
            status: FileSnapshot.Status
        ) {
            let snapshotID = Self.fileSnapshotID(turnID: turnID, itemID: item.id)

            if let index = files.firstIndex(where: { $0.id == snapshotID }) {
                files[index].apply(item, status: status)
            } else {
                files.insert(
                    .init(
                        id: snapshotID,
                        itemID: item.id,
                        displayName: FileSnapshot.makeDisplayName(path: item.path),
                        latestStatusText: item.status ?? item.text,
                        path: item.path,
                        payloadText: item.text,
                        status: status,
                        turnID: turnID,
                        itemOrderIndex: nil,
                        turnOrderIndex: nil,
                        turnStartedAt: nil
                    ),
                    at: 0
                )
                if files.count > residentLimit {
                    files = Array(files.prefix(residentLimit))
                }
            }
        }

        private static func fileSnapshotID(turnID: String, itemID: String) -> String {
            "\(turnID):\(itemID)"
        }

        private static func status(from persistedStatus: String?) -> FileSnapshot.Status {
            guard let persistedStatus else { return .completed }
            switch persistedStatus.lowercased() {
            case "error", "errored", "failed", "interrupted":
                return .errored
            case "in_progress", "inprogress", "running":
                return .inProgress
            default:
                return .completed
            }
        }
    }

    @MainActor
    @Observable
    public final class Dashboard {
        public struct HookRun: Sendable, Equatable, Identifiable {
            public struct Entry: Sendable, Equatable {
                public enum Kind: String, Sendable, Equatable {
                    case context
                    case error
                    case feedback
                    case stop
                    case warning
                }

                public let kind: Kind
                public let text: String
            }

            public enum EventName: String, Sendable, Equatable {
                case postToolUse
                case preToolUse
                case sessionStart
                case stop
                case userPromptSubmit
            }

            public enum ExecutionMode: String, Sendable, Equatable {
                case async
                case sync
            }

            public enum HandlerType: String, Sendable, Equatable {
                case agent
                case command
                case prompt
            }

            public enum Scope: String, Sendable, Equatable {
                case thread
                case turn
            }

            public enum Status: String, Sendable, Equatable {
                case blocked
                case completed
                case failed
                case running
                case stopped
            }

            public let id: String
            public let completedAt: Int?
            public let displayOrder: Int
            public let durationMS: Int?
            public let entries: [Entry]
            public let eventName: EventName
            public let executionMode: ExecutionMode
            public let handlerType: HandlerType
            public let scope: Scope
            public let sourcePath: String
            public let startedAt: Int
            public let status: Status
            public let statusMessage: String?
            public let turnID: String?
        }

        public enum ActivityStatus: String, Sendable, Equatable {
            case errored
            case idle
            case inProgress
        }

        internal struct ActivityState: Sendable, Equatable {
            var activeMcpItemIDs: Set<String> = []
            var activeToolLikeItemIDs: Set<String> = []
            var hasMcpErrorResidue = false
            var hookRuns: [HookRun] = []
            var hasToolErrorResidue = false
            var isCompactingThreadContext = false
        }

        public let threadID: String
        public private(set) var isArchived: Bool
        public private(set) var isClosed: Bool
        public private(set) var isCompactingThreadContext: Bool
        public private(set) var latestTokenUsage: CodexThreadTokenUsageUpdated?
        public private(set) var mcpCallingStatus: ActivityStatus
        public private(set) var name: String?
        public private(set) var preview: String
        public private(set) var status: CodexAppServer.ThreadStatus
        public private(set) var toolCallingStatus: ActivityStatus
        public private(set) var hookRuns: [HookRun]

        @ObservationIgnored
        private var eventTask: Task<Void, Never>?

        @ObservationIgnored
        private var activityTask: Task<Void, Never>?

        @ObservationIgnored
        private var activityState: ActivityState

        internal init(
            threadID: String,
            initialInfo: CodexAppServer.ThreadInfo,
            events: AsyncThrowingStream<CodexThreadEvent, Error>,
            initialActivityState: ActivityState,
            activityUpdates: AsyncStream<ActivityState>
        ) {
            self.threadID = threadID
            self.isArchived = false
            self.isClosed = false
            self.latestTokenUsage = nil
            self.name = initialInfo.name
            self.preview = initialInfo.preview
            self.status = initialInfo.status
            self.activityState = initialActivityState
            self.hookRuns = initialActivityState.hookRuns
            self.isCompactingThreadContext = initialActivityState.isCompactingThreadContext
            self.mcpCallingStatus = Self.activityStatus(
                activeIDs: initialActivityState.activeMcpItemIDs,
                hasErrorResidue: initialActivityState.hasMcpErrorResidue
            )
            self.toolCallingStatus = Self.activityStatus(
                activeIDs: initialActivityState.activeToolLikeItemIDs,
                hasErrorResidue: initialActivityState.hasToolErrorResidue
            )

            eventTask = Task { [weak self] in
                guard let self else { return }

                do {
                    for try await event in events {
                        self.apply(event)
                    }
                } catch is CancellationError {
                    return
                } catch {
                    return
                }
            }

            activityTask = Task { [weak self] in
                guard let self else { return }

                for await state in activityUpdates {
                    self.apply(activityState: state)
                }
            }
        }

        deinit {
            eventTask?.cancel()
            activityTask?.cancel()
        }

        private func apply(_ event: CodexThreadEvent) {
            switch event {
            case let .started(started):
                name = started.thread.name
                preview = started.thread.preview
                status = started.thread.status
            case let .statusChanged(change):
                status = change.status
            case .approvalRequested:
                return
            case .elicitationRequested:
                return
            case .serverRequestResolved:
                return
            case .archived:
                isArchived = true
            case .unarchived:
                isArchived = false
            case .closed:
                isClosed = true
            case let .nameUpdated(update):
                name = update.threadName
            case let .tokenUsageUpdated(update):
                latestTokenUsage = update
            }
        }

        private func apply(activityState: ActivityState) {
            self.activityState = activityState
            syncActivityPresentation()
        }

        private func syncActivityPresentation() {
            hookRuns = activityState.hookRuns
            isCompactingThreadContext = activityState.isCompactingThreadContext
            toolCallingStatus = Self.activityStatus(
                activeIDs: activityState.activeToolLikeItemIDs,
                hasErrorResidue: activityState.hasToolErrorResidue
            )
            mcpCallingStatus = Self.activityStatus(
                activeIDs: activityState.activeMcpItemIDs,
                hasErrorResidue: activityState.hasMcpErrorResidue
            )
        }

        private static func activityStatus(
            activeIDs: Set<String>,
            hasErrorResidue: Bool
        ) -> ActivityStatus {
            if !activeIDs.isEmpty {
                return .inProgress
            }
            if hasErrorResidue {
                return .errored
            }
            return .idle
        }
    }

    public struct TurnRequest: Sendable, Equatable {
        public var approvalPolicy: CodexAppServer.ApprovalPolicy?
        public var approvalsReviewer: CodexAppServer.ApprovalsReviewer?
        public var currentDirectoryPath: String?
        public var effort: CodexAppServer.ReasoningEffort?
        public var input: [CodexAppServer.TurnInput]
        public var model: String?
        public var outputSchema: CodexAppServer.JSONValue?
        public var personality: CodexAppServer.Personality?
        public var serviceTier: CodexAppServer.ServiceTier?
        public var summary: CodexAppServer.ReasoningSummary?

        public init(
            input: [CodexAppServer.TurnInput],
            approvalPolicy: CodexAppServer.ApprovalPolicy? = nil,
            approvalsReviewer: CodexAppServer.ApprovalsReviewer? = nil,
            currentDirectoryPath: String? = nil,
            effort: CodexAppServer.ReasoningEffort? = nil,
            model: String? = nil,
            outputSchema: CodexAppServer.JSONValue? = nil,
            personality: CodexAppServer.Personality? = nil,
            serviceTier: CodexAppServer.ServiceTier? = nil,
            summary: CodexAppServer.ReasoningSummary? = nil
        ) {
            self.input = input
            self.approvalPolicy = approvalPolicy
            self.approvalsReviewer = approvalsReviewer
            self.currentDirectoryPath = currentDirectoryPath
            self.effort = effort
            self.model = model
            self.outputSchema = outputSchema
            self.personality = personality
            self.serviceTier = serviceTier
            self.summary = summary
        }
    }

    public let id: String
    public let info: CodexAppServer.ThreadInfo
    public let approvalPolicy: CodexAppServer.ApprovalPolicy
    public let approvalsReviewer: CodexAppServer.ApprovalsReviewer
    public let currentDirectoryPath: String
    public let instructionSources: [String]
    public let model: String
    public let modelProvider: String
    public let reasoningEffort: CodexAppServer.ReasoningEffort?
    public let sandboxPolicy: CodexAppServer.SandboxPolicy
    public let serviceTier: CodexAppServer.ServiceTier?
    public let events: AsyncThrowingStream<CodexThreadEvent, Error>

    private let appServer: CodexAppServer

    internal init(
        appServer: CodexAppServer,
        session: CodexAppServer.ThreadSession,
        events: AsyncThrowingStream<CodexThreadEvent, Error>
    ) {
        self.appServer = appServer
        self.id = session.thread.id
        self.info = session.thread
        self.approvalPolicy = session.approvalPolicy
        self.approvalsReviewer = session.approvalsReviewer
        self.currentDirectoryPath = session.currentDirectoryPath
        self.instructionSources = session.instructionSources
        self.model = session.model
        self.modelProvider = session.modelProvider
        self.reasoningEffort = session.reasoningEffort
        self.sandboxPolicy = session.sandboxPolicy
        self.serviceTier = session.serviceTier
        self.events = events
    }

    public func startTurn(_ request: TurnRequest) async throws -> CodexTurnHandle {
        try await appServer.startTurn(
            .init(
                threadID: id,
                input: request.input,
                approvalPolicy: request.approvalPolicy,
                approvalsReviewer: request.approvalsReviewer,
                currentDirectoryPath: request.currentDirectoryPath,
                effort: request.effort,
                model: request.model,
                outputSchema: request.outputSchema,
                personality: request.personality,
                serviceTier: request.serviceTier,
                summary: request.summary
            )
        )
    }

    public func startTextTurn(
        _ text: String,
        approvalPolicy: CodexAppServer.ApprovalPolicy? = nil,
        approvalsReviewer: CodexAppServer.ApprovalsReviewer? = nil,
        currentDirectoryPath: String? = nil,
        effort: CodexAppServer.ReasoningEffort? = nil,
        model: String? = nil,
        outputSchema: CodexAppServer.JSONValue? = nil,
        personality: CodexAppServer.Personality? = nil,
        serviceTier: CodexAppServer.ServiceTier? = nil,
        summary: CodexAppServer.ReasoningSummary? = nil
    ) async throws -> CodexTurnHandle {
        try await startTurn(
            .init(
                input: [.text(text)],
                approvalPolicy: approvalPolicy,
                approvalsReviewer: approvalsReviewer,
                currentDirectoryPath: currentDirectoryPath,
                effort: effort,
                model: model,
                outputSchema: outputSchema,
                personality: personality,
                serviceTier: serviceTier,
                summary: summary
            )
        )
    }

    @MainActor
    public func makeDashboard() async -> Dashboard {
        let events = await appServer.threadEventStream(threadID: id)
        let initialActivityState = await appServer.threadObservableActivityState(threadID: id)
        let activityUpdates = await appServer.threadObservableActivityStream(threadID: id)
        return Dashboard(
            threadID: id,
            initialInfo: info,
            events: events,
            initialActivityState: initialActivityState,
            activityUpdates: activityUpdates
        )
    }

    public func compactContext() async throws {
        try await appServer.compactThread(.init(threadID: id))
    }

    @MainActor
    public func makeRecentTurns(
        limit: Int = 12,
        cachePolicy: RecentTurns.CachePolicy? = nil
    ) async throws -> RecentTurns {
        let window = try await appServer.recentTurnWindow(threadID: id, limit: limit)
        let events = await appServer.threadTurnEventStream(threadID: id)
        return RecentTurns(
            cachePolicy: cachePolicy ?? .automatic(pageSize: limit),
            threadID: id,
            residentLimit: limit,
            nextNewerCursor: window.nextNewerCursor,
            nextOlderCursor: window.nextOlderCursor,
            initialTurns: window.turns.map(RecentTurns.TurnSnapshot.init),
            events: events,
            appServer: appServer
        )
    }

    @MainActor
    public func makeRecentFiles(limit: Int = 12) async throws -> RecentFiles {
        let window = try await appServer.recentFileWindow(threadID: id, limit: limit)
        let turnEvents = await appServer.threadTurnEventStream(threadID: id)
        let fileDeltaEvents = await appServer.threadFileChangeOutputDeltaStream(threadID: id)
        return RecentFiles(
            threadID: id,
            residentLimit: limit,
            nextOlderCursor: window.nextOlderCursor,
            initialFiles: window.files.map(RecentFiles.FileSnapshot.init),
            turnEvents: turnEvents,
            fileDeltaEvents: fileDeltaEvents,
            appServer: appServer
        )
    }

    public func respond(
        to request: CodexApprovalRequest,
        with response: CodexApprovalResponse
    ) async throws {
        try await appServer.respond(
            to: request,
            with: response,
            expectedThreadID: id,
            expectedTurnID: nil
        )
    }

    public func respond(
        to request: CodexElicitationRequest,
        with response: CodexElicitationResponse
    ) async throws {
        try await appServer.respond(
            to: request,
            with: response,
            expectedThreadID: id,
            expectedTurnID: nil
        )
    }

}

public enum CodexThreadEvent: Sendable, Equatable {
    case started(CodexThreadStarted)
    case statusChanged(CodexThreadStatusChanged)
    case approvalRequested(CodexApprovalRequest)
    case elicitationRequested(CodexElicitationRequest)
    case serverRequestResolved(CodexInteractiveRequestResolved)
    case archived(CodexThreadArchived)
    case unarchived(CodexThreadUnarchived)
    case closed(CodexThreadClosed)
    case nameUpdated(CodexThreadNameUpdated)
    case tokenUsageUpdated(CodexThreadTokenUsageUpdated)
}

public struct CodexThreadStarted: Sendable, Equatable {
    public let thread: CodexAppServer.ThreadInfo

    internal init(thread: CodexAppServer.ThreadInfo) {
        self.thread = thread
    }
}

public struct CodexThreadStatusChanged: Sendable, Equatable {
    public let threadID: String
    public let status: CodexAppServer.ThreadStatus

    internal init(
        threadID: String,
        status: CodexAppServer.ThreadStatus
    ) {
        self.threadID = threadID
        self.status = status
    }
}

public struct CodexThreadNameUpdated: Sendable, Equatable {
    public let threadID: String
    public let threadName: String?

    internal init(
        threadID: String,
        threadName: String?
    ) {
        self.threadID = threadID
        self.threadName = threadName
    }
}

public struct CodexThreadArchived: Sendable, Equatable {
    public let threadID: String

    internal init(threadID: String) {
        self.threadID = threadID
    }
}

public struct CodexThreadUnarchived: Sendable, Equatable {
    public let threadID: String

    internal init(threadID: String) {
        self.threadID = threadID
    }
}

public struct CodexThreadClosed: Sendable, Equatable {
    public let threadID: String

    internal init(threadID: String) {
        self.threadID = threadID
    }
}

public struct CodexThreadTokenUsageUpdated: Sendable, Equatable {
    public struct Usage: Sendable, Equatable {
        public let cachedInputTokens: Int
        public let inputTokens: Int
        public let outputTokens: Int
        public let reasoningOutputTokens: Int
        public let totalTokens: Int

        internal init(
            cachedInputTokens: Int,
            inputTokens: Int,
            outputTokens: Int,
            reasoningOutputTokens: Int,
            totalTokens: Int
        ) {
            self.cachedInputTokens = cachedInputTokens
            self.inputTokens = inputTokens
            self.outputTokens = outputTokens
            self.reasoningOutputTokens = reasoningOutputTokens
            self.totalTokens = totalTokens
        }
    }

    public let threadID: String
    public let turnID: String
    public let last: Usage
    public let modelContextWindow: Int?
    public let total: Usage

    internal init(
        threadID: String,
        turnID: String,
        last: Usage,
        modelContextWindow: Int?,
        total: Usage
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.last = last
        self.modelContextWindow = modelContextWindow
        self.total = total
    }
}

private extension CodexThread.RecentTurns.TurnSnapshot {
    init(_ snapshot: ThreadHistoryStore.ThreadSnapshot.TurnSnapshot) {
        self.init(
            id: snapshot.id,
            completedAt: snapshot.completedAt,
            diff: snapshot.diff,
            durationMS: snapshot.durationMS,
            errorMessage: snapshot.errorMessage,
            isItemPayloadComplete: true,
            items: snapshot.items.map {
                .init(
                    id: $0.id,
                    isLowValueForResidency: CodexThread.RecentTurns.isLowValueItemKind($0.kind),
                    orderIndex: $0.orderIndex,
                    kind: $0.kind,
                    command: $0.command,
                    path: $0.path,
                    serverName: $0.serverName,
                    status: $0.status,
                    streamedText: $0.streamedText,
                    text: $0.text,
                    toolName: $0.toolName
                )
            },
            omittedItemCount: 0,
            orderIndex: snapshot.orderIndex,
            startedAt: snapshot.startedAt,
            status: snapshot.status,
            tokenUsage: snapshot.tokenUsage.map {
                .init(
                    cachedInputTokens: $0.cachedInputTokens,
                    inputTokens: $0.inputTokens,
                    outputTokens: $0.outputTokens,
                    reasoningOutputTokens: $0.reasoningOutputTokens,
                    totalTokens: $0.totalTokens,
                    modelContextWindow: $0.modelContextWindow
                )
            }
        )
    }
}

private extension CodexThread.RecentFiles.FileSnapshot {
    init(_ snapshot: CodexAppServer.RecentFileSnapshot) {
        self.init(
            id: snapshot.id,
            itemID: snapshot.itemID,
            displayName: Self.makeDisplayName(path: snapshot.path),
            latestStatusText: snapshot.latestStatusText,
            path: snapshot.path,
            payloadText: snapshot.payloadText,
            status: Self.snapshotStatus(from: snapshot.status),
            turnID: snapshot.turnID,
            itemOrderIndex: snapshot.itemOrderIndex,
            turnOrderIndex: snapshot.turnOrderIndex,
            turnStartedAt: snapshot.turnStartedAt
        )
    }

    var appServerSnapshot: CodexAppServer.RecentFileSnapshot {
        .init(
            id: id,
            itemID: itemID,
            latestStatusText: latestStatusText,
            path: path,
            payloadText: payloadText,
            status: status.rawValue,
            threadID: "",
            turnID: turnID,
            turnOrderIndex: turnOrderIndex ?? 0,
            itemOrderIndex: itemOrderIndex ?? 0,
            turnStartedAt: turnStartedAt
        )
    }

    private static func snapshotStatus(from persistedStatus: String?) -> CodexThread.RecentFiles.FileSnapshot.Status {
        guard let persistedStatus else { return .completed }
        switch persistedStatus.lowercased() {
        case "error", "errored", "failed", "interrupted":
            return .errored
        case "in_progress", "inprogress", "running":
            return .inProgress
        default:
            return .completed
        }
    }
}
