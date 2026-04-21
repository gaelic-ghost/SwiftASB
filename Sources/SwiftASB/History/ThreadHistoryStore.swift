@preconcurrency import CoreData
import Foundation

actor ThreadHistoryStore {
    enum Completeness: String, Sendable {
        case partial
        case serverParity
        case richerThanServer
    }

    struct Configuration: Sendable {
        let inMemory: Bool
        let storeURL: URL

        static func live() -> Self {
            let baseURL = URL.applicationSupportDirectory
                .appendingPathComponent("SwiftASB", isDirectory: true)
                .appendingPathComponent("History", isDirectory: true)
            return .init(
                inMemory: false,
                storeURL: baseURL.appendingPathComponent("ThreadHistory.sqlite", isDirectory: false)
            )
        }

        static func inMemory() -> Self {
            .init(inMemory: true, storeURL: URL(fileURLWithPath: "/dev/null"))
        }
    }

    struct ThreadSnapshot: Sendable, Equatable {
        struct DefaultsSnapshot: Sendable, Equatable {
            let approvalPolicy: String
            let approvalsReviewer: String
            let currentDirectoryPath: String
            let instructionSources: [String]
            let model: String
            let modelProvider: String
            let reasoningEffort: String?
            let sandboxPolicy: SandboxPolicySnapshot
            let serviceTier: String?
        }

        struct StateSnapshot: Sendable, Equatable {
            let completeness: String
        }

        struct TurnSnapshot: Sendable, Equatable {
            struct TokenUsageSnapshot: Codable, Sendable, Equatable {
                let cachedInputTokens: Int?
                let inputTokens: Int?
                let outputTokens: Int?
                let reasoningOutputTokens: Int?
                let totalTokens: Int?
                let modelContextWindow: Int?
            }

            struct ItemSnapshot: Sendable, Equatable {
                let id: String
                let orderIndex: Int
                let kind: String
                let command: String?
                let path: String?
                let serverName: String?
                let status: String?
                let streamedText: String?
                let text: String?
                let toolName: String?
            }

            let id: String
            let completedAt: Int?
            let diff: String?
            let durationMS: Int?
            let errorMessage: String?
            let items: [ItemSnapshot]
            let orderIndex: Int
            let startedAt: Int?
            let status: String
            let tokenUsage: TokenUsageSnapshot?
        }

        let id: String
        let cliVersion: String
        let createdAt: Int
        let currentDirectoryPath: String
        let defaults: DefaultsSnapshot
        let ephemeral: Bool
        let isArchived: Bool
        let isClosed: Bool
        let modelProvider: String
        let name: String?
        let preview: String
        let state: StateSnapshot
        let statusFlags: [String]
        let statusType: String
        let turns: [TurnSnapshot]
        let updatedAt: Int
    }

    struct SandboxPolicySnapshot: Codable, Sendable, Equatable {
        struct ReadOnlyAccessSnapshot: Codable, Sendable, Equatable {
            let includePlatformDefaults: Bool?
            let readableRoots: [String]
            let type: String
        }

        enum NetworkAccessSnapshot: Codable, Sendable, Equatable {
            case explicit(Bool)
            case enabled
            case restricted
        }

        let type: String
        let access: ReadOnlyAccessSnapshot?
        let networkAccess: NetworkAccessSnapshot?
        let excludeSlashTmp: Bool?
        let excludeTmpdirEnvVar: Bool?
        let readOnlyAccess: ReadOnlyAccessSnapshot?
        let writableRoots: [String]
    }

    private struct ActiveTurnBuilder: Sendable {
        struct ActiveItem: Sendable {
            let orderIndex: Int
            var latestItem: CodexTurnItem
            var streamedText: String
        }

        let threadID: String
        var diff: String?
        var items: [String: ActiveItem]
        var nextItemOrderIndex: Int
        let orderIndex: Int
        var turn: CodexAppServer.TurnInfo
    }

    struct HydratedTurn: Sendable {
        let turn: CodexAppServer.TurnInfo
        let items: [CodexTurnItem]
    }

    private struct HydrationMergeOutcome: Sendable {
        let preservedRicherLocalDetail: Bool
    }

    private let container: NSPersistentContainer
    private var activeTurns: [String: ActiveTurnBuilder] = [:]
    private var nextTurnOrderByThreadID: [String: Int] = [:]
    private static let sharedManagedObjectModel: NSManagedObjectModel = makeManagedObjectModel()

    init(configuration: Configuration = .live()) throws {
        self.container = try Self.makePersistentContainer(configuration: configuration)
    }

    func recordThreadStarted(session: CodexAppServer.ThreadSession) throws {
        let context = container.newBackgroundContext()
        try context.performAndWaitReturning {
            let thread = try Self.fetchOrInsertThread(id: session.thread.id, in: context)
            Self.applyThreadInfo(session.thread, to: thread)
            thread.isArchived = false

            let defaults = thread.defaults ?? HistoryThreadDefaults(context: context)
            Self.applyThreadDefaults(session, to: defaults)
            defaults.thread = thread
            thread.defaults = defaults

            let state = thread.state ?? HistoryThreadState(context: context)
            state.completeness = Completeness.partial.rawValue
            state.thread = thread
            thread.state = state

            try context.saveIfChanged()
        }
    }

    func recordThreadResumed(
        session: CodexAppServer.ThreadSession,
        turns: [HydratedTurn]
    ) throws {
        let context = container.newBackgroundContext()
        try context.performAndWaitReturning {
            let thread = try Self.fetchOrInsertThread(id: session.thread.id, in: context)
            Self.applyThreadInfo(session.thread, to: thread)

            let defaults = thread.defaults ?? HistoryThreadDefaults(context: context)
            Self.applyThreadDefaults(session, to: defaults)
            defaults.thread = thread
            thread.defaults = defaults

            let state = thread.state ?? HistoryThreadState(context: context)
            state.thread = thread
            thread.state = state

            if turns.isEmpty {
                if state.completeness.isEmpty {
                    state.completeness = Completeness.partial.rawValue
                }
            } else {
                let outcome = try Self.upsertHydratedTurns(
                    turns,
                    for: thread,
                    in: context
                )
                state.completeness = outcome.preservedRicherLocalDetail
                    ? Completeness.richerThanServer.rawValue
                    : Completeness.serverParity.rawValue
            }

            try context.saveIfChanged()
        }

        if let maxOrderIndex = try snapshot(threadID: session.thread.id)?.turns.map(\.orderIndex).max() {
            nextTurnOrderByThreadID[session.thread.id] = maxOrderIndex + 1
        }
    }

    func recordThreadMetadataUpdated(_ threadInfo: CodexAppServer.ThreadInfo) throws {
        let context = container.newBackgroundContext()
        try context.performAndWaitReturning {
            let thread = try Self.fetchOrInsertThread(id: threadInfo.id, in: context)
            Self.applyThreadInfo(threadInfo, to: thread)
            if let state = thread.state {
                state.completeness = state.completeness.isEmpty ? Completeness.partial.rawValue : state.completeness
            } else {
                let state = HistoryThreadState(context: context)
                state.completeness = Completeness.partial.rawValue
                state.thread = thread
                thread.state = state
            }
            try context.saveIfChanged()
        }
    }

    func reconcileThreadListPage(
        _ threads: [CodexAppServer.ThreadInfo],
        archived: Bool?
    ) throws {
        guard !threads.isEmpty else { return }

        let context = container.newBackgroundContext()
        try context.performAndWaitReturning {
            for threadInfo in threads {
                let thread = try Self.fetchOrInsertThread(id: threadInfo.id, in: context)
                Self.applyThreadInfo(threadInfo, to: thread)
                Self.ensureThreadPersistenceScaffolding(for: thread, in: context)
                if let archived {
                    thread.isArchived = archived
                }
            }
            try context.saveIfChanged()
        }
    }

    func recordThreadStatusChanged(
        threadID: String,
        status: CodexAppServer.ThreadStatus
    ) throws {
        let context = container.newBackgroundContext()
        try context.performAndWaitReturning {
            guard let thread = try Self.fetchThread(id: threadID, in: context) else { return }
            thread.statusType = status.type.rawValue
            thread.statusFlagsData = try Self.encode(status.activeFlags.map(\.rawValue))
            try context.saveIfChanged()
        }
    }

    func recordThreadArchived(threadID: String, isArchived: Bool) throws {
        let context = container.newBackgroundContext()
        try context.performAndWaitReturning {
            guard let thread = try Self.fetchThread(id: threadID, in: context) else { return }
            thread.isArchived = isArchived
            try context.saveIfChanged()
        }
    }

    func recordThreadNameUpdated(threadID: String, name: String?) throws {
        let context = container.newBackgroundContext()
        try context.performAndWaitReturning {
            guard let thread = try Self.fetchThread(id: threadID, in: context) else { return }
            thread.name = name
            try context.saveIfChanged()
        }
    }

    func recordThreadClosed(threadID: String) throws {
        let context = container.newBackgroundContext()
        try context.performAndWaitReturning {
            guard let thread = try Self.fetchThread(id: threadID, in: context) else { return }
            thread.isClosed = true
            try context.saveIfChanged()
        }
    }

    func recordTurnStarted(threadID: String, turn: CodexAppServer.TurnInfo) throws {
        let orderIndex: Int
        if var existingBuilder = activeTurns[turn.id] {
            existingBuilder.turn = turn
            activeTurns[turn.id] = existingBuilder
            orderIndex = existingBuilder.orderIndex
        } else {
            orderIndex = nextTurnOrderByThreadID[threadID] ?? 0
            nextTurnOrderByThreadID[threadID] = orderIndex + 1
            activeTurns[turn.id] = .init(
                threadID: threadID,
                diff: nil,
                items: [:],
                nextItemOrderIndex: 0,
                orderIndex: orderIndex,
                turn: turn
            )
        }

        let context = container.newBackgroundContext()
        try context.performAndWaitReturning {
            guard let thread = try Self.fetchThread(id: threadID, in: context) else {
                throw ThreadHistoryStoreError.missingThread(
                    "Cannot record turn \(turn.id) because thread \(threadID) is missing from the local history store."
                )
            }
            let turnObject = try Self.fetchOrInsertTurn(id: turn.id, in: context)
            Self.applyTurnInfo(turn, orderIndex: orderIndex, to: turnObject)
            turnObject.thread = thread
            try context.saveIfChanged()
        }
    }

    func recordTurnDiffUpdated(turnID: String, diff: String) throws {
        guard var builder = activeTurns[turnID] else { return }
        builder.diff = diff
        activeTurns[turnID] = builder

        let context = container.newBackgroundContext()
        try context.performAndWaitReturning {
            guard let turn = try Self.fetchTurn(id: turnID, in: context) else { return }
            turn.diff = diff
            try context.saveIfChanged()
        }
    }

    func recordItemStarted(
        threadID: String,
        turnID: String,
        item: CodexTurnItem
    ) throws {
        guard var builder = activeTurns[turnID] else { return }
        let orderIndex = builder.nextItemOrderIndex
        builder.nextItemOrderIndex += 1
        builder.items[item.id] = .init(
            orderIndex: orderIndex,
            latestItem: item,
            streamedText: item.text ?? ""
        )
        activeTurns[turnID] = builder

        let stableID = Self.stableItemID(turnID: turnID, itemID: item.id)
        let streamedText = builder.items[item.id]?.streamedText

        let context = container.newBackgroundContext()
        try context.performAndWaitReturning {
            guard let turn = try Self.fetchTurn(id: turnID, in: context) else {
                throw ThreadHistoryStoreError.missingTurn(
                    "Cannot record item \(item.id) because turn \(turnID) is missing from the local history store."
                )
            }
            let persistedItem = try Self.fetchOrInsertItem(stableID: stableID, in: context)
            Self.applyItem(item, stableID: stableID, orderIndex: orderIndex, streamedText: streamedText, to: persistedItem)
            persistedItem.turn = turn
            try context.saveIfChanged()
        }
    }

    func recordItemDelta(turnID: String, itemID: String, delta: String) throws {
        guard var builder = activeTurns[turnID], var activeItem = builder.items[itemID] else { return }
        activeItem.streamedText += delta
        builder.items[itemID] = activeItem
        activeTurns[turnID] = builder

        let stableID = Self.stableItemID(turnID: turnID, itemID: itemID)
        let streamedText = activeItem.streamedText

        let context = container.newBackgroundContext()
        try context.performAndWaitReturning {
            guard let item = try Self.fetchItem(stableID: stableID, in: context) else { return }
            item.streamedText = streamedText
            try context.saveIfChanged()
        }
    }

    func recordItemCompleted(
        threadID: String,
        turnID: String,
        item: CodexTurnItem
    ) throws {
        guard var builder = activeTurns[turnID], var activeItem = builder.items[item.id] else { return }
        activeItem.latestItem = item
        if activeItem.streamedText.isEmpty, let text = item.text {
            activeItem.streamedText = text
        }
        builder.items[item.id] = activeItem
        activeTurns[turnID] = builder

        let stableID = Self.stableItemID(turnID: turnID, itemID: item.id)
        let orderIndex = activeItem.orderIndex
        let streamedText = activeItem.streamedText

        let context = container.newBackgroundContext()
        try context.performAndWaitReturning {
            guard let persistedItem = try Self.fetchItem(stableID: stableID, in: context) else { return }
            Self.applyItem(item, stableID: stableID, orderIndex: orderIndex, streamedText: streamedText, to: persistedItem)
            try context.saveIfChanged()
        }
    }

    func recordTurnTokenUsageUpdated(
        threadID: String,
        turnID: String,
        usage: CodexThreadTokenUsageUpdated.Usage,
        modelContextWindow: Int?
    ) throws {
        let snapshot = ThreadSnapshot.TurnSnapshot.TokenUsageSnapshot(
            cachedInputTokens: usage.cachedInputTokens,
            inputTokens: usage.inputTokens,
            outputTokens: usage.outputTokens,
            reasoningOutputTokens: usage.reasoningOutputTokens,
            totalTokens: usage.totalTokens,
            modelContextWindow: modelContextWindow
        )

        let context = container.newBackgroundContext()
        try context.performAndWaitReturning {
            guard let turn = try Self.fetchTurn(id: turnID, in: context) else { return }
            turn.tokenUsageData = try Self.encode(snapshot)
            if turn.thread == nil, let thread = try Self.fetchThread(id: threadID, in: context) {
                turn.thread = thread
            }
            try context.saveIfChanged()
        }
    }

    func recordTurnCompleted(
        threadID: String,
        turn: CodexAppServer.TurnInfo
    ) throws {
        let builder = activeTurns.removeValue(forKey: turn.id)

        let context = container.newBackgroundContext()
        try context.performAndWaitReturning {
            guard let turnObject = try Self.fetchTurn(id: turn.id, in: context) else { return }
            Self.applyTurnInfo(turn, orderIndex: Int(turnObject.orderIndex), to: turnObject)
            if let builder {
                turnObject.diff = builder.diff
            }
            if turnObject.thread == nil, let thread = try Self.fetchThread(id: threadID, in: context) {
                turnObject.thread = thread
            }
            try context.saveIfChanged()
        }
    }

    func snapshot(threadID: String) throws -> ThreadSnapshot? {
        let context = container.newBackgroundContext()
        return try context.performAndWaitReturning {
            guard let thread = try Self.fetchThread(id: threadID, in: context) else {
                return nil
            }
            guard let defaults = thread.defaults, let state = thread.state else {
                return nil
            }

            let instructionSources = try Self.decode([String].self, from: defaults.instructionSourcesData) ?? []
            let sandboxPolicy = try Self.decode(SandboxPolicySnapshot.self, from: defaults.sandboxPolicyData)
                ?? .init(
                    type: "",
                    access: nil,
                    networkAccess: nil,
                    excludeSlashTmp: nil,
                    excludeTmpdirEnvVar: nil,
                    readOnlyAccess: nil,
                    writableRoots: []
                )
            let turnRequest = HistoryTurn.fetchRequest()
            turnRequest.predicate = NSPredicate(format: "thread == %@", thread)
            let turns = try context.fetch(turnRequest)
                .sorted { $0.orderIndex < $1.orderIndex }
                .map { turn -> ThreadSnapshot.TurnSnapshot in
                    let itemRequest = HistoryItem.fetchRequest()
                    itemRequest.predicate = NSPredicate(format: "turn == %@", turn)
                    let items = (try context.fetch(itemRequest))
                        .sorted { $0.orderIndex < $1.orderIndex }
                        .map {
                            ThreadSnapshot.TurnSnapshot.ItemSnapshot(
                                id: $0.itemID,
                                orderIndex: Int($0.orderIndex),
                                kind: $0.kind,
                                command: $0.command,
                                path: $0.path,
                                serverName: $0.serverName,
                                status: $0.status,
                                streamedText: $0.streamedText,
                                text: $0.text,
                                toolName: $0.toolName
                            )
                        }
                    let tokenUsage = try Self.decode(
                        ThreadSnapshot.TurnSnapshot.TokenUsageSnapshot.self,
                        from: turn.tokenUsageData
                    )
                    return .init(
                        id: turn.id,
                        completedAt: turn.completedAt == 0 ? nil : Int(turn.completedAt),
                        diff: turn.diff,
                        durationMS: turn.durationMS == 0 ? nil : Int(turn.durationMS),
                        errorMessage: turn.errorMessage,
                        items: items,
                        orderIndex: Int(turn.orderIndex),
                        startedAt: turn.startedAt == 0 ? nil : Int(turn.startedAt),
                        status: turn.status,
                        tokenUsage: tokenUsage
                    )
                }

            return .init(
                id: thread.id,
                cliVersion: thread.cliVersion,
                createdAt: Int(thread.createdAt),
                currentDirectoryPath: thread.currentDirectoryPath,
                defaults: .init(
                    approvalPolicy: defaults.approvalPolicy,
                    approvalsReviewer: defaults.approvalsReviewer,
                    currentDirectoryPath: defaults.currentDirectoryPath,
                    instructionSources: instructionSources,
                    model: defaults.model,
                    modelProvider: defaults.modelProvider,
                    reasoningEffort: defaults.reasoningEffort,
                    sandboxPolicy: sandboxPolicy,
                    serviceTier: defaults.serviceTier
                ),
                ephemeral: thread.ephemeral,
                isArchived: thread.isArchived,
                isClosed: thread.isClosed,
                modelProvider: thread.modelProvider,
                name: thread.name,
                preview: thread.preview,
                state: .init(completeness: state.completeness),
                statusFlags: (try Self.decode([String].self, from: thread.statusFlagsData)) ?? [],
                statusType: thread.statusType,
                turns: turns,
                updatedAt: Int(thread.updatedAt)
            )
        }
    }

    func hydrateThreadRead(
        thread: CodexAppServer.ThreadInfo,
        turns: [HydratedTurn]
    ) throws {
        let context = container.newBackgroundContext()
        try context.performAndWaitReturning {
            let threadObject = try Self.fetchOrInsertThread(id: thread.id, in: context)
            Self.applyThreadInfo(thread, to: threadObject)
            Self.ensureThreadPersistenceScaffolding(for: threadObject, in: context)
            let outcome = try Self.upsertHydratedTurns(
                turns,
                for: threadObject,
                in: context
            )
            threadObject.state?.completeness = outcome.preservedRicherLocalDetail
                ? Completeness.richerThanServer.rawValue
                : Completeness.serverParity.rawValue
            try context.saveIfChanged()
        }

        if let maxOrderIndex = try snapshot(threadID: thread.id)?.turns.map(\.orderIndex).max() {
            nextTurnOrderByThreadID[thread.id] = maxOrderIndex + 1
        }
    }

    func hydrateHistoricalTurns(
        threadID: String,
        turns: [HydratedTurn]
    ) throws {
        let context = container.newBackgroundContext()
        try context.performAndWaitReturning {
            let thread = try Self.fetchOrInsertThread(id: threadID, in: context)
            Self.ensureThreadPersistenceScaffolding(for: thread, in: context)
            let outcome = try Self.upsertHydratedTurns(
                turns,
                for: thread,
                in: context
            )
            if let state = thread.state, state.completeness != Completeness.richerThanServer.rawValue {
                if outcome.preservedRicherLocalDetail {
                    state.completeness = Completeness.richerThanServer.rawValue
                } else if state.completeness.isEmpty {
                    state.completeness = Completeness.partial.rawValue
                }
            }
            try context.saveIfChanged()
        }

        if let maxOrderIndex = try snapshot(threadID: threadID)?.turns.map(\.orderIndex).max() {
            nextTurnOrderByThreadID[threadID] = maxOrderIndex + 1
        }
    }

    private static func stableItemID(turnID: String, itemID: String) -> String {
        "\(turnID)::\(itemID)"
    }

    private static func applyThreadInfo(_ info: CodexAppServer.ThreadInfo, to thread: HistoryThread) {
        thread.id = info.id
        thread.cliVersion = info.cliVersion
        thread.createdAt = Int64(info.createdAt)
        thread.currentDirectoryPath = info.currentDirectoryPath
        thread.ephemeral = info.ephemeral
        thread.modelProvider = info.modelProvider
        thread.name = info.name
        thread.preview = info.preview
        thread.statusType = info.status.type.rawValue
        thread.statusFlagsData = try? encode(info.status.activeFlags.map(\.rawValue))
        thread.updatedAt = Int64(info.updatedAt)
    }

    private static func ensureThreadPersistenceScaffolding(
        for thread: HistoryThread,
        in context: NSManagedObjectContext
    ) {
        if thread.defaults == nil {
            let defaults = HistoryThreadDefaults(context: context)
            defaults.approvalPolicy = ""
            defaults.approvalsReviewer = ""
            defaults.currentDirectoryPath = thread.currentDirectoryPath
            defaults.model = ""
            defaults.modelProvider = thread.modelProvider
            defaults.thread = thread
            thread.defaults = defaults
        }

        if thread.state == nil {
            let state = HistoryThreadState(context: context)
            state.completeness = Completeness.partial.rawValue
            state.thread = thread
            thread.state = state
        }
    }

    private static func upsertHydratedTurns(
        _ hydratedTurns: [HydratedTurn],
        for thread: HistoryThread,
        in context: NSManagedObjectContext
    ) throws -> HydrationMergeOutcome {
        guard !hydratedTurns.isEmpty else {
            return .init(preservedRicherLocalDetail: false)
        }

        var preservedRicherLocalDetail = false

        for hydratedTurn in hydratedTurns {
            let turnObject = try fetchOrInsertTurn(id: hydratedTurn.turn.id, in: context)
            preservedRicherLocalDetail = Self.mergeHydratedTurnInfo(
                hydratedTurn.turn,
                into: turnObject
            ) || preservedRicherLocalDetail
            turnObject.thread = thread

            let existingTurnItems = ((turnObject.items as? Set<HistoryItem>) ?? [])
            let incomingItemIDs = Set(hydratedTurn.items.map(\.id))
            if existingTurnItems.contains(where: { !incomingItemIDs.contains($0.itemID) }) {
                preservedRicherLocalDetail = true
            }

            for (itemIndex, item) in hydratedTurn.items.enumerated() {
                let stableID = stableItemID(turnID: hydratedTurn.turn.id, itemID: item.id)
                let itemObject = try fetchOrInsertItem(stableID: stableID, in: context)
                preservedRicherLocalDetail = Self.mergeHydratedItem(
                    item,
                    stableID: stableID,
                    orderIndex: itemIndex,
                    into: itemObject
                ) || preservedRicherLocalDetail
                itemObject.turn = turnObject
            }
        }

        let turnRequest = HistoryTurn.fetchRequest()
        turnRequest.predicate = NSPredicate(format: "thread == %@", thread)
        let persistedTurns = try context.fetch(turnRequest)
            .sorted {
                let lhsStartedAt = $0.startedAt
                let rhsStartedAt = $1.startedAt
                if lhsStartedAt == rhsStartedAt {
                    return $0.id < $1.id
                }
                return lhsStartedAt < rhsStartedAt
            }

        for (turnIndex, turn) in persistedTurns.enumerated() {
            turn.orderIndex = Int64(turnIndex)
        }

        return .init(preservedRicherLocalDetail: preservedRicherLocalDetail)
    }

    private static func applyThreadDefaults(
        _ session: CodexAppServer.ThreadSession,
        to defaults: HistoryThreadDefaults
    ) {
        defaults.approvalPolicy = session.approvalPolicy.persistedLabel
        defaults.approvalsReviewer = session.approvalsReviewer.rawValue
        defaults.currentDirectoryPath = session.currentDirectoryPath
        defaults.instructionSourcesData = try? encode(session.instructionSources)
        defaults.model = session.model
        defaults.modelProvider = session.modelProvider
        defaults.reasoningEffort = session.reasoningEffort?.rawValue
        defaults.sandboxPolicyData = try? encode(SandboxPolicySnapshot(session.sandboxPolicy))
        defaults.serviceTier = session.serviceTier?.rawValue
    }

    private static func applyTurnInfo(
        _ info: CodexAppServer.TurnInfo,
        orderIndex: Int,
        to turn: HistoryTurn
    ) {
        turn.id = info.id
        turn.completedAt = Int64(info.completedAt ?? 0)
        turn.durationMS = Int64(info.durationMS ?? 0)
        turn.errorMessage = info.errorMessage
        turn.orderIndex = Int64(orderIndex)
        turn.startedAt = Int64(info.startedAt ?? 0)
        turn.status = info.status.rawValue
    }

    private static func mergeHydratedTurnInfo(
        _ info: CodexAppServer.TurnInfo,
        into turn: HistoryTurn
    ) -> Bool {
        var preservedRicherLocalDetail = false
        turn.id = info.id
        if let completedAt = info.completedAt {
            turn.completedAt = Int64(completedAt)
        } else if turn.completedAt != 0 {
            preservedRicherLocalDetail = true
        }
        if let durationMS = info.durationMS {
            turn.durationMS = Int64(durationMS)
        } else if turn.durationMS != 0 {
            preservedRicherLocalDetail = true
        }
        if let errorMessage = info.errorMessage, !errorMessage.isEmpty {
            turn.errorMessage = errorMessage
        } else if let existingErrorMessage = turn.errorMessage, !existingErrorMessage.isEmpty {
            preservedRicherLocalDetail = true
        }
        if let startedAt = info.startedAt {
            turn.startedAt = Int64(startedAt)
        } else if turn.startedAt != 0 {
            preservedRicherLocalDetail = true
        }
        let mergedStatus = mergedTurnStatus(existing: turn.status, incoming: info.status.rawValue)
        if mergedStatus == turn.status && mergedStatus != info.status.rawValue {
            preservedRicherLocalDetail = true
        }
        turn.status = mergedStatus
        return preservedRicherLocalDetail
    }

    private static func applyItem(
        _ item: CodexTurnItem,
        stableID: String,
        orderIndex: Int,
        streamedText: String?,
        to persistedItem: HistoryItem
    ) {
        persistedItem.id = stableID
        persistedItem.itemID = item.id
        persistedItem.command = item.command
        persistedItem.kind = item.kind.rawValue
        persistedItem.orderIndex = Int64(orderIndex)
        persistedItem.path = item.path
        persistedItem.serverName = item.serverName
        persistedItem.status = item.status
        persistedItem.streamedText = streamedText
        persistedItem.text = item.text
        persistedItem.toolName = item.toolName
    }

    private static func mergeHydratedItem(
        _ item: CodexTurnItem,
        stableID: String,
        orderIndex: Int,
        into persistedItem: HistoryItem
    ) -> Bool {
        var preservedRicherLocalDetail = false
        persistedItem.id = stableID
        persistedItem.itemID = item.id
        persistedItem.kind = item.kind.rawValue
        persistedItem.orderIndex = Int64(orderIndex)
        let mergedCommand = mergeIncomingPreferredString(existing: persistedItem.command, incoming: item.command)
        preservedRicherLocalDetail = preservedRicherLocalDetail || mergedCommand.preservedExistingDetail
        persistedItem.command = mergedCommand.value
        let mergedPath = mergeIncomingPreferredString(existing: persistedItem.path, incoming: item.path)
        preservedRicherLocalDetail = preservedRicherLocalDetail || mergedPath.preservedExistingDetail
        persistedItem.path = mergedPath.value
        let mergedServerName = mergeIncomingPreferredString(existing: persistedItem.serverName, incoming: item.serverName)
        preservedRicherLocalDetail = preservedRicherLocalDetail || mergedServerName.preservedExistingDetail
        persistedItem.serverName = mergedServerName.value
        let mergedStatus = mergeItemStatus(existing: persistedItem.status, incoming: item.status)
        preservedRicherLocalDetail = preservedRicherLocalDetail || mergedStatus.preservedExistingDetail
        persistedItem.status = mergedStatus.value
        let mergedStreamedText = mergeStreamedText(existing: persistedItem.streamedText, incoming: item.text)
        preservedRicherLocalDetail = preservedRicherLocalDetail || mergedStreamedText.preservedExistingDetail
        persistedItem.streamedText = mergedStreamedText.value
        let mergedText = mergeCanonicalText(existing: persistedItem.text, incoming: item.text)
        preservedRicherLocalDetail = preservedRicherLocalDetail || mergedText.preservedExistingDetail
        persistedItem.text = mergedText.value
        let mergedToolName = mergeIncomingPreferredString(existing: persistedItem.toolName, incoming: item.toolName)
        preservedRicherLocalDetail = preservedRicherLocalDetail || mergedToolName.preservedExistingDetail
        persistedItem.toolName = mergedToolName.value
        return preservedRicherLocalDetail
    }

    private struct MergedString: Sendable {
        let value: String?
        let preservedExistingDetail: Bool
    }

    private static func mergeIncomingPreferredString(existing: String?, incoming: String?) -> MergedString {
        let existing = normalizedMeaningfulString(existing)
        let incoming = normalizedMeaningfulString(incoming)

        switch (existing, incoming) {
        case let (nil, incoming):
            return .init(value: incoming, preservedExistingDetail: false)
        case let (existing, nil):
            return .init(value: existing, preservedExistingDetail: existing != nil)
        case let (.some(_), .some(incoming)):
            return .init(value: incoming, preservedExistingDetail: false)
        }
    }

    private static func mergeCanonicalText(existing: String?, incoming: String?) -> MergedString {
        let existing = normalizedMeaningfulString(existing)
        let incoming = normalizedMeaningfulString(incoming)

        switch (existing, incoming) {
        case let (nil, incoming):
            return .init(value: incoming, preservedExistingDetail: false)
        case let (existing, nil):
            return .init(value: existing, preservedExistingDetail: existing != nil)
        case let (.some(existing), .some(incoming)):
            if incoming == existing {
                return .init(value: incoming, preservedExistingDetail: false)
            }
            if existing.hasPrefix(incoming) {
                return .init(value: existing, preservedExistingDetail: true)
            }
            return .init(value: incoming, preservedExistingDetail: false)
        }
    }

    private static func mergeStreamedText(existing: String?, incoming: String?) -> MergedString {
        let existing = normalizedMeaningfulString(existing)
        let incoming = normalizedMeaningfulString(incoming)

        switch (existing, incoming) {
        case let (nil, incoming):
            return .init(value: incoming, preservedExistingDetail: false)
        case let (existing, nil):
            return .init(value: existing, preservedExistingDetail: existing != nil)
        case let (.some(existing), .some(incoming)):
            if incoming == existing {
                return .init(value: incoming, preservedExistingDetail: false)
            }
            if incoming.hasPrefix(existing) {
                return .init(value: incoming, preservedExistingDetail: false)
            }
            return .init(value: existing, preservedExistingDetail: true)
        }
    }

    private static func mergeItemStatus(existing: String?, incoming: String?) -> MergedString {
        let existing = normalizedMeaningfulString(existing)
        let incoming = normalizedMeaningfulString(incoming)

        switch (existing, incoming) {
        case let (nil, incoming):
            return .init(value: incoming, preservedExistingDetail: false)
        case let (existing, nil):
            return .init(value: existing, preservedExistingDetail: existing != nil)
        case let (.some(existing), .some(incoming)):
            let normalizedExisting = existing.lowercased()
            let normalizedIncoming = incoming.lowercased()
            let incomingTerminal = isTerminalItemStatus(normalizedIncoming)
            let existingTerminal = isTerminalItemStatus(normalizedExisting)

            if incomingTerminal {
                return .init(value: incoming, preservedExistingDetail: false)
            }
            if existingTerminal {
                return .init(value: existing, preservedExistingDetail: normalizedIncoming != normalizedExisting)
            }
            return .init(value: incoming, preservedExistingDetail: false)
        }
    }

    private static func normalizedMeaningfulString(_ value: String?) -> String? {
        guard let value else { return nil }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : value
    }

    private static func mergedTurnStatus(existing: String, incoming: String) -> String {
        let incomingTerminal = isTerminalTurnStatus(incoming)
        let existingTerminal = isTerminalTurnStatus(existing)

        if incomingTerminal {
            return incoming
        }
        if existingTerminal {
            return existing
        }
        return incoming
    }

    private static func isTerminalTurnStatus(_ status: String) -> Bool {
        switch status {
        case CodexAppServer.TurnStatus.completed.rawValue,
             CodexAppServer.TurnStatus.failed.rawValue,
             CodexAppServer.TurnStatus.interrupted.rawValue:
            true
        default:
            false
        }
    }

    private static func isTerminalItemStatus(_ status: String) -> Bool {
        switch status {
        case "completed", "failed", "error", "errored", "interrupted", "cancelled", "canceled":
            true
        default:
            false
        }
    }

    private static func fetchOrInsertThread(id: String, in context: NSManagedObjectContext) throws -> HistoryThread {
        if let existing = try fetchThread(id: id, in: context) {
            return existing
        }
        let thread = HistoryThread(context: context)
        thread.id = id
        thread.cliVersion = ""
        thread.createdAt = 0
        thread.currentDirectoryPath = ""
        thread.ephemeral = false
        thread.isArchived = false
        thread.isClosed = false
        thread.modelProvider = ""
        thread.preview = ""
        thread.statusType = CodexAppServer.ThreadStatusType.notLoaded.rawValue
        thread.updatedAt = 0
        return thread
    }

    private static func fetchThread(id: String, in context: NSManagedObjectContext) throws -> HistoryThread? {
        let request = HistoryThread.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id)
        return try context.fetch(request).first
    }

    private static func fetchOrInsertTurn(id: String, in context: NSManagedObjectContext) throws -> HistoryTurn {
        if let existing = try fetchTurn(id: id, in: context) {
            return existing
        }
        let turn = HistoryTurn(context: context)
        turn.id = id
        return turn
    }

    private static func fetchTurn(id: String, in context: NSManagedObjectContext) throws -> HistoryTurn? {
        let request = HistoryTurn.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id)
        return try context.fetch(request).first
    }

    private static func fetchOrInsertItem(stableID: String, in context: NSManagedObjectContext) throws -> HistoryItem {
        if let existing = try fetchItem(stableID: stableID, in: context) {
            return existing
        }
        let item = HistoryItem(context: context)
        item.id = stableID
        item.itemID = stableID
        return item
    }

    private static func fetchItem(stableID: String, in context: NSManagedObjectContext) throws -> HistoryItem? {
        let request = HistoryItem.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", stableID)
        return try context.fetch(request).first
    }

    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        try JSONEncoder().encode(value)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data?) throws -> T? {
        guard let data else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }

    private static func makePersistentContainer(configuration: Configuration) throws -> NSPersistentContainer {
        let model = sharedManagedObjectModel
        let container = NSPersistentContainer(name: "ThreadHistoryStore", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: configuration.storeURL)
        description.type = configuration.inMemory ? NSInMemoryStoreType : NSSQLiteStoreType
        description.shouldAddStoreAsynchronously = false

        if !configuration.inMemory {
            try FileManager.default.createDirectory(
                at: configuration.storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }

        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }

    private static func makeManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let threadEntity = NSEntityDescription()
        threadEntity.name = "HistoryThread"
        threadEntity.managedObjectClassName = NSStringFromClass(HistoryThread.self)
        threadEntity.properties = [
            attribute("id", .stringAttributeType, isOptional: false),
            attribute("cliVersion", .stringAttributeType, isOptional: false),
            attribute("createdAt", .integer64AttributeType, isOptional: false),
            attribute("currentDirectoryPath", .stringAttributeType, isOptional: false),
            attribute("ephemeral", .booleanAttributeType, isOptional: false),
            attribute("modelProvider", .stringAttributeType, isOptional: false),
            attribute("name", .stringAttributeType, isOptional: true),
            attribute("preview", .stringAttributeType, isOptional: false),
            attribute("statusType", .stringAttributeType, isOptional: false),
            attribute("statusFlagsData", .binaryDataAttributeType, isOptional: true),
            attribute("updatedAt", .integer64AttributeType, isOptional: false),
            attribute("isArchived", .booleanAttributeType, isOptional: false),
            attribute("isClosed", .booleanAttributeType, isOptional: false),
        ]
        threadEntity.uniquenessConstraints = [["id"]]

        let defaultsEntity = NSEntityDescription()
        defaultsEntity.name = "HistoryThreadDefaults"
        defaultsEntity.managedObjectClassName = NSStringFromClass(HistoryThreadDefaults.self)
        defaultsEntity.properties = [
            attribute("approvalPolicy", .stringAttributeType, isOptional: false),
            attribute("approvalsReviewer", .stringAttributeType, isOptional: false),
            attribute("currentDirectoryPath", .stringAttributeType, isOptional: false),
            attribute("instructionSourcesData", .binaryDataAttributeType, isOptional: true),
            attribute("model", .stringAttributeType, isOptional: false),
            attribute("modelProvider", .stringAttributeType, isOptional: false),
            attribute("reasoningEffort", .stringAttributeType, isOptional: true),
            attribute("sandboxPolicyData", .binaryDataAttributeType, isOptional: true),
            attribute("serviceTier", .stringAttributeType, isOptional: true),
        ]

        let stateEntity = NSEntityDescription()
        stateEntity.name = "HistoryThreadState"
        stateEntity.managedObjectClassName = NSStringFromClass(HistoryThreadState.self)
        stateEntity.properties = [
            attribute("completeness", .stringAttributeType, isOptional: false),
        ]

        let turnEntity = NSEntityDescription()
        turnEntity.name = "HistoryTurn"
        turnEntity.managedObjectClassName = NSStringFromClass(HistoryTurn.self)
        turnEntity.properties = [
            attribute("id", .stringAttributeType, isOptional: false),
            attribute("completedAt", .integer64AttributeType, isOptional: false),
            attribute("diff", .stringAttributeType, isOptional: true),
            attribute("durationMS", .integer64AttributeType, isOptional: false),
            attribute("errorMessage", .stringAttributeType, isOptional: true),
            attribute("orderIndex", .integer64AttributeType, isOptional: false),
            attribute("startedAt", .integer64AttributeType, isOptional: false),
            attribute("status", .stringAttributeType, isOptional: false),
            attribute("tokenUsageData", .binaryDataAttributeType, isOptional: true),
        ]
        turnEntity.uniquenessConstraints = [["id"]]

        let itemEntity = NSEntityDescription()
        itemEntity.name = "HistoryItem"
        itemEntity.managedObjectClassName = NSStringFromClass(HistoryItem.self)
        itemEntity.properties = [
            attribute("id", .stringAttributeType, isOptional: false),
            attribute("itemID", .stringAttributeType, isOptional: false),
            attribute("command", .stringAttributeType, isOptional: true),
            attribute("kind", .stringAttributeType, isOptional: false),
            attribute("orderIndex", .integer64AttributeType, isOptional: false),
            attribute("path", .stringAttributeType, isOptional: true),
            attribute("serverName", .stringAttributeType, isOptional: true),
            attribute("status", .stringAttributeType, isOptional: true),
            attribute("streamedText", .stringAttributeType, isOptional: true),
            attribute("text", .stringAttributeType, isOptional: true),
            attribute("toolName", .stringAttributeType, isOptional: true),
        ]
        itemEntity.uniquenessConstraints = [["id"]]

        let threadToDefaults = relationship(name: "defaults", destination: defaultsEntity, minCount: 0, maxCount: 1, deleteRule: .cascadeDeleteRule)
        let defaultsToThread = relationship(name: "thread", destination: threadEntity, minCount: 0, maxCount: 1, deleteRule: .nullifyDeleteRule)
        threadToDefaults.inverseRelationship = defaultsToThread
        defaultsToThread.inverseRelationship = threadToDefaults

        let threadToState = relationship(name: "state", destination: stateEntity, minCount: 0, maxCount: 1, deleteRule: .cascadeDeleteRule)
        let stateToThread = relationship(name: "thread", destination: threadEntity, minCount: 0, maxCount: 1, deleteRule: .nullifyDeleteRule)
        threadToState.inverseRelationship = stateToThread
        stateToThread.inverseRelationship = threadToState

        let threadToTurns = relationship(name: "turns", destination: turnEntity, minCount: 0, maxCount: 0, deleteRule: .cascadeDeleteRule)
        let turnToThread = relationship(name: "thread", destination: threadEntity, minCount: 0, maxCount: 1, deleteRule: .nullifyDeleteRule)
        threadToTurns.inverseRelationship = turnToThread
        turnToThread.inverseRelationship = threadToTurns

        let turnToItems = relationship(name: "items", destination: itemEntity, minCount: 0, maxCount: 0, deleteRule: .cascadeDeleteRule)
        let itemToTurn = relationship(name: "turn", destination: turnEntity, minCount: 0, maxCount: 1, deleteRule: .nullifyDeleteRule)
        turnToItems.inverseRelationship = itemToTurn
        itemToTurn.inverseRelationship = turnToItems

        threadEntity.properties.append(contentsOf: [threadToDefaults, threadToState, threadToTurns])
        defaultsEntity.properties.append(defaultsToThread)
        stateEntity.properties.append(stateToThread)
        turnEntity.properties.append(contentsOf: [turnToThread, turnToItems])
        itemEntity.properties.append(itemToTurn)

        model.entities = [threadEntity, defaultsEntity, stateEntity, turnEntity, itemEntity]
        return model
    }
}

private enum ThreadHistoryStoreError: Error {
    case contextExecutionFailed(String)
    case missingThread(String)
    case missingTurn(String)
}

private extension ThreadHistoryStore {
    static func attribute(_ name: String, _ type: NSAttributeType, isOptional: Bool) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = isOptional
        return attribute
    }

    static func relationship(
        name: String,
        destination: NSEntityDescription,
        minCount: Int,
        maxCount: Int,
        deleteRule: NSDeleteRule
    ) -> NSRelationshipDescription {
        let relationship = NSRelationshipDescription()
        relationship.name = name
        relationship.destinationEntity = destination
        relationship.minCount = minCount
        relationship.maxCount = maxCount
        relationship.deleteRule = deleteRule
        relationship.isOptional = minCount == 0
        return relationship
    }
}

private extension NSManagedObjectContext {
    func performAndWaitReturning<T: Sendable>(_ block: @Sendable () throws -> T) throws -> T {
        let box = ManagedObjectContextResultBox<T>()
        performAndWait {
            box.outcome = Result { try block() }
        }
        guard let outcome = box.outcome else {
            throw ThreadHistoryStoreError.contextExecutionFailed(
                "Core Data did not produce a result while synchronously executing work on the managed object context."
            )
        }
        return try outcome.get()
    }

    func saveIfChanged() throws {
        if hasChanges {
            try save()
        }
    }
}

private final class ManagedObjectContextResultBox<T: Sendable>: @unchecked Sendable {
    var outcome: Result<T, Error>?
}

private extension CodexAppServer.ApprovalPolicy {
    var persistedLabel: String {
        switch self {
        case .never:
            "never"
        case .onFailure:
            "onFailure"
        case .onRequest:
            "onRequest"
        case .untrusted:
            "untrusted"
        case .granular:
            "granular"
        }
    }
}

private extension ThreadHistoryStore.SandboxPolicySnapshot {
    init(_ policy: CodexAppServer.SandboxPolicy) {
        self.init(
            type: policy.type.rawValue,
            access: policy.access.map(Self.ReadOnlyAccessSnapshot.init),
            networkAccess: policy.networkAccess.map(Self.NetworkAccessSnapshot.init),
            excludeSlashTmp: policy.excludeSlashTmp,
            excludeTmpdirEnvVar: policy.excludeTmpdirEnvVar,
            readOnlyAccess: policy.readOnlyAccess.map(Self.ReadOnlyAccessSnapshot.init),
            writableRoots: policy.writableRoots
        )
    }
}

private extension ThreadHistoryStore.SandboxPolicySnapshot.ReadOnlyAccessSnapshot {
    init(_ access: CodexAppServer.ReadOnlyAccess) {
        self.init(
            includePlatformDefaults: access.includePlatformDefaults,
            readableRoots: access.readableRoots,
            type: access.type.rawValue
        )
    }
}

private extension ThreadHistoryStore.SandboxPolicySnapshot.NetworkAccessSnapshot {
    init(_ access: CodexAppServer.NetworkAccess) {
        switch access {
        case let .explicit(value):
            self = .explicit(value)
        case .enabled:
            self = .enabled
        case .restricted:
            self = .restricted
        }
    }
}

@objc(HistoryThread)
final class HistoryThread: NSManagedObject {
    @NSManaged var cliVersion: String
    @NSManaged var createdAt: Int64
    @NSManaged var currentDirectoryPath: String
    @NSManaged var defaults: HistoryThreadDefaults?
    @NSManaged var ephemeral: Bool
    @NSManaged var id: String
    @NSManaged var isArchived: Bool
    @NSManaged var isClosed: Bool
    @NSManaged var modelProvider: String
    @NSManaged var name: String?
    @NSManaged var preview: String
    @NSManaged var state: HistoryThreadState?
    @NSManaged var statusFlagsData: Data?
    @NSManaged var statusType: String
    @NSManaged var turns: NSSet?
    @NSManaged var updatedAt: Int64
}

@objc(HistoryThreadDefaults)
final class HistoryThreadDefaults: NSManagedObject {
    @NSManaged var approvalPolicy: String
    @NSManaged var approvalsReviewer: String
    @NSManaged var currentDirectoryPath: String
    @NSManaged var instructionSourcesData: Data?
    @NSManaged var model: String
    @NSManaged var modelProvider: String
    @NSManaged var reasoningEffort: String?
    @NSManaged var sandboxPolicyData: Data?
    @NSManaged var serviceTier: String?
    @NSManaged var thread: HistoryThread?
}

@objc(HistoryThreadState)
final class HistoryThreadState: NSManagedObject {
    @NSManaged var completeness: String
    @NSManaged var thread: HistoryThread?
}

@objc(HistoryTurn)
final class HistoryTurn: NSManagedObject {
    @NSManaged var completedAt: Int64
    @NSManaged var diff: String?
    @NSManaged var durationMS: Int64
    @NSManaged var errorMessage: String?
    @NSManaged var id: String
    @NSManaged var items: NSSet?
    @NSManaged var orderIndex: Int64
    @NSManaged var startedAt: Int64
    @NSManaged var status: String
    @NSManaged var thread: HistoryThread?
    @NSManaged var tokenUsageData: Data?
}

@objc(HistoryItem)
final class HistoryItem: NSManagedObject {
    @NSManaged var command: String?
    @NSManaged var id: String
    @NSManaged var itemID: String
    @NSManaged var kind: String
    @NSManaged var orderIndex: Int64
    @NSManaged var path: String?
    @NSManaged var serverName: String?
    @NSManaged var status: String?
    @NSManaged var streamedText: String?
    @NSManaged var text: String?
    @NSManaged var toolName: String?
    @NSManaged var turn: HistoryTurn?
}

private extension HistoryThread {
    @nonobjc static func fetchRequest() -> NSFetchRequest<HistoryThread> {
        NSFetchRequest<HistoryThread>(entityName: "HistoryThread")
    }
}

private extension HistoryTurn {
    @nonobjc static func fetchRequest() -> NSFetchRequest<HistoryTurn> {
        NSFetchRequest<HistoryTurn>(entityName: "HistoryTurn")
    }
}

private extension HistoryItem {
    @nonobjc static func fetchRequest() -> NSFetchRequest<HistoryItem> {
        NSFetchRequest<HistoryItem>(entityName: "HistoryItem")
    }
}
