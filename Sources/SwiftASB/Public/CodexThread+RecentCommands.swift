import Foundation
import Observation

public extension CodexThread {
    @MainActor
    @Observable
    final class RecentCommands {
        public struct CachePolicy: Sendable, Equatable {
            public let maxResidentCommands: Int
            public let minimumResidentCommands: Int
            public let maximumResidentOutputCost: Int?
            public let protectedCommandBuffer: Int
            public let protectedRecentCompletedCommands: Int

            /// Creates a recent-command residency policy.
            ///
            /// Numeric inputs are normalized to safe minimums. Omitting
            /// `maximumResidentOutputCost` disables output-cost trimming and
            /// keeps residency bounded only by command counts.
            public init(
                maxResidentCommands: Int,
                minimumResidentCommands: Int = 1,
                maximumResidentOutputCost: Int? = nil,
                protectedCommandBuffer: Int = 1,
                protectedRecentCompletedCommands: Int = 1
            ) {
                self.maxResidentCommands = max(1, maxResidentCommands)
                self.minimumResidentCommands = max(1, min(minimumResidentCommands, self.maxResidentCommands))
                self.maximumResidentOutputCost = maximumResidentOutputCost.map { max(1, $0) }
                self.protectedCommandBuffer = max(0, protectedCommandBuffer)
                self.protectedRecentCompletedCommands = max(0, protectedRecentCompletedCommands)
            }

            /// Creates the default recent-command cache policy for a page size.
            public static func automatic(pageSize: Int) -> Self {
                let normalizedPageSize = max(1, pageSize)
                return .init(
                    maxResidentCommands: max(normalizedPageSize * 3, 12),
                    minimumResidentCommands: max(normalizedPageSize, 2),
                    maximumResidentOutputCost: max(normalizedPageSize * 16, 32),
                    protectedCommandBuffer: 1,
                    protectedRecentCompletedCommands: 1
                )
            }
        }

        public struct CommandSnapshot: Sendable, Equatable, Identifiable {
            public enum Status: String, Sendable, Equatable {
                case completed
                case errored
                case inProgress
            }

            public let id: String
            public let itemID: String
            public private(set) var command: String?
            public private(set) var displayName: String
            public private(set) var latestStatusText: String?
            public private(set) var outputText: String?
            public private(set) var isOutputComplete: Bool
            public private(set) var omittedOutputCharacterCount: Int
            public private(set) var status: Status
            public let turnID: String

            public internal(set) var itemOrderIndex: Int?
            public internal(set) var turnOrderIndex: Int?
            public internal(set) var turnStartedAt: Int?

            fileprivate static func makeDisplayName(command: String?) -> String {
                guard let command, !command.isEmpty else { return "Command" }

                return command
            }

            fileprivate static func makeStatusSummary(
                command: String?,
                status: String?,
                text: String?
            ) -> String? {
                let normalizedStatus = status?.trimmingCharacters(in: .whitespacesAndNewlines)
                let lowercasedStatus = normalizedStatus?.lowercased()

                if lowercasedStatus == "completed", let outputSummary = makeOutputSummary(text: text) {
                    return outputSummary
                }

                if let normalizedStatus, !normalizedStatus.isEmpty {
                    return normalizedStatus
                }

                if let outputSummary = makeOutputSummary(text: text) {
                    return outputSummary
                }

                return command
            }

            fileprivate static func makeOutputSummary(text: String?) -> String? {
                guard let text, !text.isEmpty else { return nil }

                let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

                if nonEmptyLines.count > 1 {
                    return "\(nonEmptyLines.count) output lines"
                }

                guard let firstNonEmptyLine = nonEmptyLines.first else {
                    return nil
                }

                return String(firstNonEmptyLine.prefix(160))
            }

            fileprivate mutating func apply(delta: String) {
                outputText = (outputText ?? "") + delta
                latestStatusText = latestStatusText ?? "Streaming command output"
                status = .inProgress
                isOutputComplete = false
            }

            fileprivate mutating func apply(_ item: CodexTurnItem, status: Status) {
                command = item.command
                displayName = Self.makeDisplayName(command: item.command)
                latestStatusText = Self.makeStatusSummary(
                    command: item.command,
                    status: item.status,
                    text: item.text
                ) ?? latestStatusText
                self.status = status
                if let text = item.text, !text.isEmpty {
                    outputText = text
                    isOutputComplete = status != .inProgress
                    omittedOutputCharacterCount = 0
                } else if status != .inProgress {
                    isOutputComplete = outputText?.isEmpty == false
                }
            }

            fileprivate mutating func slimOutput() {
                guard let outputText, !outputText.isEmpty else { return }

                omittedOutputCharacterCount = outputText.count
                self.outputText = nil
                isOutputComplete = false
            }

            fileprivate mutating func hydrateOutput(
                command: String?,
                text: String?,
                latestStatusText: String?,
                status: Status
            ) {
                self.command = command
                displayName = Self.makeDisplayName(command: command)
                if let text, !text.isEmpty {
                    outputText = text
                }
                self.latestStatusText = latestStatusText ?? self.latestStatusText
                self.status = status
                if outputText != nil {
                    isOutputComplete = true
                    omittedOutputCharacterCount = 0
                } else {
                    isOutputComplete = false
                }
            }

            fileprivate mutating func mergeNewerSnapshot(_ snapshot: Self) {
                let existingOutputText = outputText
                let existingOutputComplete = isOutputComplete
                let existingOmittedOutputCharacterCount = omittedOutputCharacterCount

                self = snapshot

                if outputText == nil || outputText?.isEmpty == true,
                   let existingOutputText,
                   !existingOutputText.isEmpty {
                    outputText = existingOutputText
                    isOutputComplete = existingOutputComplete
                    omittedOutputCharacterCount = existingOmittedOutputCharacterCount
                }
            }
        }

        public let cachePolicy: CachePolicy
        public let residentLimit: Int
        public let threadID: String
        public private(set) var commands: [CommandSnapshot]
        public private(set) var isLoadingOlderCommands: Bool
        public private(set) var lastLoadErrorDescription: String?
        public private(set) var nextOlderCursor: String?
        public private(set) var residentOutputCost: Int
        public private(set) var visibleCommandIDs: [String]
        public var selectedCommandID: String? {
            didSet {
                scheduleResidencyMaintenance()
            }
        }

        @ObservationIgnored
        private let appServer: CodexAppServer

        @ObservationIgnored
        private var commandDeltaTask: Task<Void, Never>?

        @ObservationIgnored
        private var turnEventTask: Task<Void, Never>?

        @ObservationIgnored
        private var residencyTask: Task<Void, Never>?

        init(
            cachePolicy: CachePolicy,
            threadID: String,
            residentLimit: Int,
            nextOlderCursor: String?,
            initialCommands: [CommandSnapshot],
            turnEvents: AsyncThrowingStream<CodexTurnEvent, Error>,
            commandDeltaEvents: AsyncStream<CodexAppServer.CommandExecutionOutputDeltaEvent>,
            appServer: CodexAppServer
        ) {
            self.cachePolicy = cachePolicy
            self.threadID = threadID
            self.residentLimit = residentLimit
            self.nextOlderCursor = nextOlderCursor
            commands = initialCommands
            isLoadingOlderCommands = false
            lastLoadErrorDescription = nil
            residentOutputCost = initialCommands.reduce(0) { $0 + Self.commandResidentCost($1) }
            visibleCommandIDs = []
            selectedCommandID = nil
            self.appServer = appServer
            trimResidentCommandsIfNeeded()

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

            commandDeltaTask = Task { [weak self] in
                guard let self else { return }

                for await event in commandDeltaEvents {
                    self.apply(event)
                }
            }
        }

        deinit {
            turnEventTask?.cancel()
            commandDeltaTask?.cancel()
            residencyTask?.cancel()
        }

        private static func commandSnapshotID(turnID: String, itemID: String) -> String {
            "\(turnID):\(itemID)"
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

        private static func commandResidentCost(_ command: CommandSnapshot) -> Int {
            let baseCost = command.status == .inProgress ? 3 : 1
            guard let outputText = command.outputText, !outputText.isEmpty else {
                return baseCost
            }

            let lines = outputText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            let nonEmptyLineCount = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
            let characterCost = max(1, Int(ceil(Double(outputText.count) / 480.0)))
            let lineCost = max(1, Int(ceil(Double(nonEmptyLineCount) / 20.0)))
            let payloadCost = min(characterCost + lineCost, command.isOutputComplete ? 18 : 9)
            return baseCost + payloadCost
        }

        private static func status(from persistedStatus: String?) -> CommandSnapshot.Status {
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

        /// Loads commands older than the current resident window.
        ///
        /// Omitting `limit` uses this companion's resident page limit.
        public func loadOlderCommands(limit: Int? = nil) async throws {
            guard !isLoadingOlderCommands else { return }
            guard let oldestCommand = commands.last else { return }
            guard oldestCommand.turnOrderIndex != nil, oldestCommand.itemOrderIndex != nil else { return }

            isLoadingOlderCommands = true
            defer { isLoadingOlderCommands = false }

            do {
                let window = try await appServer.olderCommandWindow(
                    threadID: threadID,
                    olderThan: oldestCommand.appServerSnapshot,
                    cursor: nextOlderCursor,
                    limit: limit ?? residentLimit
                )
                mergeOlder(window.commands.map(CommandSnapshot.init))
                nextOlderCursor = window.nextOlderCursor
                lastLoadErrorDescription = nil
                trimResidentCommandsIfNeeded()
                scheduleResidencyMaintenance()
            } catch {
                lastLoadErrorDescription = error.localizedDescription
                throw error
            }
        }

        public func updateVisibleCommandIDs(_ ids: [String]) {
            let deduplicatedIDs = Array(NSOrderedSet(array: ids)) as? [String] ?? ids
            visibleCommandIDs = deduplicatedIDs
            scheduleResidencyMaintenance()
        }

        private func apply(_ event: CodexTurnEvent) async {
            switch event {
                case let .itemStarted(started):
                    guard started.item.kind == .commandExecution else { return }

                    upsertLiveCommand(from: started.item, turnID: started.turnID, status: .inProgress)
                case let .itemCompleted(completed):
                    guard completed.item.kind == .commandExecution else { return }

                    upsertLiveCommand(
                        from: completed.item,
                        turnID: completed.turnID,
                        status: completed.item.isErrored ? .errored : .completed
                    )
                case let .completed(completion):
                    await refreshCommands(for: completion.turn.id)
                default:
                    return
            }

            trimResidentCommandsIfNeeded()
            scheduleResidencyMaintenance()
        }

        private func apply(_ event: CodexAppServer.CommandExecutionOutputDeltaEvent) {
            let commandID = Self.commandSnapshotID(turnID: event.turnID, itemID: event.itemID)
            guard let index = commands.firstIndex(where: { $0.id == commandID }) else { return }

            commands[index].apply(delta: event.delta)
            refreshResidentMetrics()
            trimResidentCommandsIfNeeded()
        }

        private func refreshCommands(for turnID: String) async {
            guard let snapshot = try? await appServer.turnSnapshot(threadID: threadID, turnID: turnID) else {
                return
            }

            let refreshedCommands = snapshot.items
                .filter { $0.kind == CodexTurnItem.Kind.commandExecution.rawValue }
                .sorted { $0.orderIndex > $1.orderIndex }
                .map { item in
                    CommandSnapshot(
                        id: Self.commandSnapshotID(turnID: turnID, itemID: item.id),
                        itemID: item.id,
                        command: item.command,
                        displayName: CommandSnapshot.makeDisplayName(command: item.command),
                        latestStatusText: CommandSnapshot.makeStatusSummary(
                            command: item.command,
                            status: item.status,
                            text: item.streamedText ?? item.text
                        ),
                        outputText: item.streamedText ?? item.text,
                        isOutputComplete: true,
                        omittedOutputCharacterCount: 0,
                        status: Self.status(from: item.status),
                        turnID: turnID,
                        itemOrderIndex: item.orderIndex,
                        turnOrderIndex: snapshot.orderIndex,
                        turnStartedAt: snapshot.startedAt
                    )
                }

            mergeOrPrepend(refreshedCommands)
        }

        private func mergeOlder(_ incoming: [CommandSnapshot]) {
            var existingIDs = Set(commands.map(\.id))
            for command in incoming where !existingIDs.contains(command.id) {
                commands.append(command)
                existingIDs.insert(command.id)
            }
            refreshResidentMetrics()
        }

        private func mergeOrPrepend(_ incoming: [CommandSnapshot]) {
            for command in incoming.reversed() {
                if let index = commands.firstIndex(where: { $0.id == command.id }) {
                    commands[index].mergeNewerSnapshot(command)
                } else {
                    commands.insert(command, at: 0)
                }
            }

            trimResidentCommandsIfNeeded()
        }

        private func upsertLiveCommand(
            from item: CodexTurnItem,
            turnID: String,
            status: CommandSnapshot.Status
        ) {
            let snapshotID = Self.commandSnapshotID(turnID: turnID, itemID: item.id)

            if let index = commands.firstIndex(where: { $0.id == snapshotID }) {
                commands[index].apply(item, status: status)
            } else {
                commands.insert(
                    .init(
                        id: snapshotID,
                        itemID: item.id,
                        command: item.command,
                        displayName: CommandSnapshot.makeDisplayName(command: item.command),
                        latestStatusText: CommandSnapshot.makeStatusSummary(
                            command: item.command,
                            status: item.status,
                            text: item.text
                        ),
                        outputText: item.text,
                        isOutputComplete: status != .inProgress && item.text != nil,
                        omittedOutputCharacterCount: 0,
                        status: status,
                        turnID: turnID,
                        itemOrderIndex: nil,
                        turnOrderIndex: nil,
                        turnStartedAt: nil
                    ),
                    at: 0
                )
            }
        }

        private func scheduleResidencyMaintenance() {
            residencyTask?.cancel()
            residencyTask = Task { [weak self] in
                guard let self else { return }

                await self.hydrateProtectedCommandsIfNeeded()
                self.trimResidentCommandsIfNeeded()
            }
        }

        private func hydrateProtectedCommandsIfNeeded() async {
            let protectedIDs = protectedCommandIDSet()
            let slimmedProtectedIDs = commands.compactMap { command -> String? in
                guard protectedIDs.contains(command.id), !command.isOutputComplete else { return nil }

                return command.id
            }

            guard !slimmedProtectedIDs.isEmpty else { return }

            for commandID in slimmedProtectedIDs {
                do {
                    guard let index = commands.firstIndex(where: { $0.id == commandID }) else { continue }

                    let command = commands[index]
                    guard let snapshot = try await appServer.turnSnapshot(threadID: threadID, turnID: command.turnID) else {
                        continue
                    }
                    guard let item = snapshot.items.first(where: { $0.id == command.itemID }) else {
                        continue
                    }

                    commands[index].hydrateOutput(
                        command: item.command,
                        text: item.streamedText ?? item.text,
                        latestStatusText: CommandSnapshot.makeStatusSummary(
                            command: item.command,
                            status: item.status,
                            text: item.streamedText ?? item.text
                        ),
                        status: Self.status(from: item.status)
                    )
                    commands[index].itemOrderIndex = item.orderIndex
                    commands[index].turnOrderIndex = snapshot.orderIndex
                    commands[index].turnStartedAt = snapshot.startedAt
                    lastLoadErrorDescription = nil
                } catch {
                    lastLoadErrorDescription = error.localizedDescription
                }
            }

            refreshResidentMetrics()
        }

        private func trimResidentCommandsIfNeeded() {
            let maxResidentCommands = cachePolicy.maxResidentCommands
            if commands.count > maxResidentCommands {
                let focusIndices = focusIndices()
                let focusLowerBound = max(0, focusIndices.lowerBound - cachePolicy.protectedCommandBuffer)
                let focusUpperBound = min(commands.count - 1, focusIndices.upperBound + cachePolicy.protectedCommandBuffer)

                var mandatoryIndices = Set<Int>(focusLowerBound...focusUpperBound)
                for (index, command) in commands.enumerated() where command.status == .inProgress {
                    mandatoryIndices.insert(index)
                }
                for index in commands.indices.prefix(cachePolicy.protectedRecentCompletedCommands)
                    where commands[index].status != .inProgress {
                    mandatoryIndices.insert(index)
                }

                let retainedIndices: Set<Int>
                if mandatoryIndices.count >= maxResidentCommands {
                    retainedIndices = mandatoryIndices
                } else {
                    let supplementalIndices = commands.indices
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
                    for index in supplementalIndices.prefix(maxResidentCommands - mandatoryIndices.count) {
                        selectedIndices.insert(index)
                    }
                    retainedIndices = selectedIndices
                }

                commands = commands.enumerated()
                    .filter { retainedIndices.contains($0.offset) }
                    .map(\.element)
            }

            trimResidentOutputIfNeeded()
        }

        private func trimResidentOutputIfNeeded() {
            guard let maximumResidentOutputCost = cachePolicy.maximumResidentOutputCost else {
                refreshResidentMetrics()
                return
            }

            refreshResidentMetrics()
            guard residentOutputCost > maximumResidentOutputCost else { return }

            let protectedIDs = protectedCommandIDSet()
            for index in commands.indices.reversed() {
                guard residentOutputCost > maximumResidentOutputCost else { break }

                let command = commands[index]
                guard command.status != .inProgress else { continue }
                guard !protectedIDs.contains(command.id) else { continue }
                guard command.isOutputComplete else { continue }

                commands[index].slimOutput()
                refreshResidentMetrics()
            }

            while residentOutputCost > maximumResidentOutputCost, commands.count > cachePolicy.minimumResidentCommands {
                guard let evictableIndex = commands.indices.reversed().first(where: { index in
                    let command = commands[index]
                    return command.status != .inProgress && !protectedIDs.contains(command.id)
                }) else {
                    break
                }

                commands.remove(at: evictableIndex)
                refreshResidentMetrics()
            }
        }

        private func protectedCommandIDSet() -> Set<String> {
            guard !commands.isEmpty else { return [] }

            let focusIndices = focusIndices()
            let focusLowerBound = max(0, focusIndices.lowerBound - cachePolicy.protectedCommandBuffer)
            let focusUpperBound = min(commands.count - 1, focusIndices.upperBound + cachePolicy.protectedCommandBuffer)
            var protectedIDs = Set(commands[focusLowerBound...focusUpperBound].map(\.id))
            if let selectedCommandID {
                protectedIDs.insert(selectedCommandID)
            }
            protectedIDs.formUnion(visibleCommandIDs)
            for command in commands where command.status == .inProgress {
                protectedIDs.insert(command.id)
            }
            for command in commands.prefix(cachePolicy.protectedRecentCompletedCommands) where command.status != .inProgress {
                protectedIDs.insert(command.id)
            }
            return protectedIDs
        }

        private func focusIndices() -> ClosedRange<Int> {
            guard !commands.isEmpty else { return 0...0 }

            let visibleIndexSet = Set(visibleCommandIDs.compactMap(index(forCommandID:)))
            if !visibleIndexSet.isEmpty {
                return visibleIndexSet.min()!...visibleIndexSet.max()!
            }

            if let selectedCommandID, let index = index(forCommandID: selectedCommandID) {
                return index...index
            }

            return 0...0
        }

        private func index(forCommandID commandID: String) -> Int? {
            commands.firstIndex { $0.id == commandID }
        }

        private func refreshResidentMetrics() {
            residentOutputCost = commands.reduce(0) { $0 + Self.commandResidentCost($1) }
        }
    }
}

extension CodexThread.RecentCommands.CommandSnapshot {
    init(_ snapshot: CodexAppServer.RecentCommandSnapshot) {
        self.init(
            id: snapshot.id,
            itemID: snapshot.itemID,
            command: snapshot.command,
            displayName: Self.makeDisplayName(command: snapshot.command),
            latestStatusText: snapshot.latestStatusText,
            outputText: snapshot.outputText,
            isOutputComplete: true,
            omittedOutputCharacterCount: 0,
            status: Self.snapshotStatus(from: snapshot.status),
            turnID: snapshot.turnID,
            itemOrderIndex: snapshot.itemOrderIndex,
            turnOrderIndex: snapshot.turnOrderIndex,
            turnStartedAt: snapshot.turnStartedAt
        )
    }

    var appServerSnapshot: CodexAppServer.RecentCommandSnapshot {
        .init(
            id: id,
            itemID: itemID,
            command: command,
            latestStatusText: latestStatusText,
            outputText: outputText,
            status: status.rawValue,
            threadID: "",
            turnID: turnID,
            turnOrderIndex: turnOrderIndex ?? 0,
            itemOrderIndex: itemOrderIndex ?? 0,
            turnStartedAt: turnStartedAt
        )
    }

    private static func snapshotStatus(from persistedStatus: String?) -> CodexThread.RecentCommands.CommandSnapshot.Status {
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
