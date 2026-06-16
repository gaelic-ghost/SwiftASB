import Foundation
import Observation

public extension CodexThread {
    @MainActor
    @Observable
    final class RecentTurns {
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

            /// Creates a recent-turn residency policy.
            ///
            /// Numeric inputs are normalized to safe minimums. Omitting
            /// `maximumResidentItemCost` disables item-cost trimming and keeps
            /// residency bounded only by turn counts.
            public init(
                maxResidentTurns: Int,
                minimumResidentTurns: Int = 1,
                maximumResidentItemCost: Int? = nil,
                protectedTurnBuffer: Int = 2,
                protectedRecentCompletedTurns: Int = 2,
                edgePrefetchThreshold: Int = 1,
                jitterScrollVelocityThreshold: Double = 120,
                fastScrollVelocityThreshold: Double = 1200,
                veryFastScrollVelocityThreshold: Double = 2400,
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

            /// Creates the default recent-turn cache policy for a page size.
            public static func automatic(pageSize: Int) -> Self {
                chatUI(pageSize: pageSize)
            }

            /// Creates a balanced cache policy for a chat-style timeline.
            ///
            /// The default `pageSize` of 12 matches
            /// `CodexThread.makeRecentTurns(limit:)`.
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
                    fastScrollVelocityThreshold: 1100,
                    veryFastScrollVelocityThreshold: 2100,
                    maxPrefetchPagesPerPass: 3
                )
            }

            /// Creates a larger cache policy for an inspector or detail view.
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
                    veryFastScrollVelocityThreshold: 1800,
                    maxPrefetchPagesPerPass: 4
                )
            }

            /// Creates a smaller cache policy for a narrow history rail.
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
                    fastScrollVelocityThreshold: 1250,
                    veryFastScrollVelocityThreshold: 2500,
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

        init(
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
            isLoadingNewerTurns = false
            isLoadingOlderTurns = false
            lastLoadErrorDescription = nil
            self.nextNewerCursor = nextNewerCursor
            self.nextOlderCursor = nextOlderCursor
            residentItemCount = initialTurns.reduce(0) { $0 + $1.items.count }
            residentItemCost = initialTurns.reduce(0) { partialResult, turn in
                partialResult + Self.turnResidentCost(turn)
            }
            scrollActivityPhase = .idle
            scrollVelocityPointsPerSecond = nil
            turns = initialTurns
            visibleTurnIDs = []
            scrollPositionTurnID = nil
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
                case let .diagnostic(diagnostic):
                    diagnostic.turnID
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

        private nonisolated static func isLowValueItemKind(_ kind: String) -> Bool {
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

        /// Loads turns older than the current resident window.
        ///
        /// Omitting `limit` uses this companion's resident page limit.
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

        /// Loads turns newer than the current resident window.
        ///
        /// Omitting `limit` uses this companion's resident page limit.
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
    }
}

extension CodexThread.RecentTurns.TurnSnapshot {
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
