import Foundation
import Observation

extension CodexThread {
    @MainActor
    @Observable
    public final class RecentFiles {
        public struct CachePolicy: Sendable, Equatable {
            public let maxResidentFiles: Int
            public let minimumResidentFiles: Int
            public let maximumResidentPayloadCost: Int?
            public let protectedFileBuffer: Int
            public let protectedRecentCompletedFiles: Int

            /// Creates a recent-file residency policy.
            ///
            /// Numeric inputs are normalized to safe minimums. Omitting
            /// `maximumResidentPayloadCost` disables payload-cost trimming and
            /// keeps residency bounded only by file counts.
            public init(
                maxResidentFiles: Int,
                minimumResidentFiles: Int = 1,
                maximumResidentPayloadCost: Int? = nil,
                protectedFileBuffer: Int = 1,
                protectedRecentCompletedFiles: Int = 1
            ) {
                self.maxResidentFiles = max(1, maxResidentFiles)
                self.minimumResidentFiles = max(1, min(minimumResidentFiles, self.maxResidentFiles))
                self.maximumResidentPayloadCost = maximumResidentPayloadCost
                self.protectedFileBuffer = max(0, protectedFileBuffer)
                self.protectedRecentCompletedFiles = max(0, protectedRecentCompletedFiles)
            }

            /// Creates the default recent-file cache policy for a page size.
            public static func automatic(pageSize: Int) -> Self {
                let normalizedPageSize = max(1, pageSize)
                return .init(
                    maxResidentFiles: max(normalizedPageSize * 3, 12),
                    minimumResidentFiles: max(normalizedPageSize, 2),
                    maximumResidentPayloadCost: max(normalizedPageSize * 12, 24),
                    protectedFileBuffer: 1,
                    protectedRecentCompletedFiles: 1
                )
            }
        }

        public struct FileSnapshot: Sendable, Equatable, Identifiable {
            fileprivate struct PayloadMetrics: Sendable, Equatable {
                let additions: Int
                let characterCount: Int
                let deletions: Int
                let hunkCount: Int
                let nonEmptyLineCount: Int

                var hasStructuredDiffSignal: Bool {
                    additions > 0 || deletions > 0 || hunkCount > 0
                }
            }

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
            public private(set) var isPayloadComplete: Bool
            public private(set) var omittedPayloadCharacterCount: Int
            public private(set) var status: Status
            public let turnID: String

            var itemOrderIndex: Int?
            var turnOrderIndex: Int?
            var turnStartedAt: Int?

            fileprivate mutating func apply(delta: String) {
                payloadText = (payloadText ?? "") + delta
                latestStatusText = latestStatusText ?? "Streaming file change"
                status = .inProgress
                isPayloadComplete = false
            }

            fileprivate mutating func apply(_ item: CodexTurnItem, status: Status) {
                displayName = Self.makeDisplayName(path: item.path)
                latestStatusText = Self.makeStatusSummary(status: item.status, text: item.text) ?? latestStatusText
                path = item.path
                self.status = status
                if let text = item.text, !text.isEmpty {
                    payloadText = text
                    isPayloadComplete = status != .inProgress
                    omittedPayloadCharacterCount = 0
                } else if status != .inProgress {
                    isPayloadComplete = payloadText?.isEmpty == false
                }
            }

            fileprivate mutating func slimPayload() {
                guard let payloadText, !payloadText.isEmpty else { return }
                omittedPayloadCharacterCount = payloadText.count
                self.payloadText = nil
                isPayloadComplete = false
            }

            fileprivate mutating func hydratePayload(
                text: String?,
                latestStatusText: String?,
                status: Status
            ) {
                if let text, !text.isEmpty {
                    payloadText = text
                }
                self.latestStatusText = latestStatusText ?? self.latestStatusText
                self.status = status
                if payloadText != nil {
                    isPayloadComplete = true
                    omittedPayloadCharacterCount = 0
                } else {
                    isPayloadComplete = false
                }
            }

            fileprivate mutating func mergeNewerSnapshot(_ snapshot: Self) {
                let existingPayloadText = payloadText
                let existingPayloadComplete = isPayloadComplete
                let existingOmittedPayloadCharacterCount = omittedPayloadCharacterCount

                self = snapshot

                if (payloadText == nil || payloadText?.isEmpty == true),
                   let existingPayloadText,
                   !existingPayloadText.isEmpty
                {
                    payloadText = existingPayloadText
                    isPayloadComplete = existingPayloadComplete
                    omittedPayloadCharacterCount = existingOmittedPayloadCharacterCount
                }
            }

            fileprivate static func makeDisplayName(path: String?) -> String {
                guard let path, !path.isEmpty else { return "File edit" }
                return URL(fileURLWithPath: path).lastPathComponent
            }

            fileprivate static func makeStatusSummary(status: String?, text: String?) -> String? {
                let normalizedStatus = status?.trimmingCharacters(in: .whitespacesAndNewlines)
                let lowercasedStatus = normalizedStatus?.lowercased()

                if lowercasedStatus == "completed", let payloadSummary = makePayloadSummary(text: text) {
                    return payloadSummary
                }

                if let normalizedStatus, !normalizedStatus.isEmpty {
                    return normalizedStatus
                }

                return makePayloadSummary(text: text)
            }

            fileprivate static func makePayloadSummary(text: String?) -> String? {
                guard let text, !text.isEmpty else { return nil }
                let metrics = payloadMetrics(text: text)
                if metrics.hasStructuredDiffSignal {
                    var parts: [String] = []
                    if metrics.additions > 0 {
                        parts.append("\(metrics.additions) additions")
                    }
                    if metrics.deletions > 0 {
                        parts.append("\(metrics.deletions) deletions")
                    }
                    if metrics.hunkCount > 1 {
                        parts.append("\(metrics.hunkCount) hunks")
                    }
                    if !parts.isEmpty {
                        return parts.joined(separator: ", ")
                    }
                }

                if metrics.nonEmptyLineCount > 1 {
                    return "\(metrics.nonEmptyLineCount) lines changed"
                }

                let firstLine = text.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? text
                return String(firstLine.prefix(160))
            }

            fileprivate static func payloadMetrics(text: String) -> PayloadMetrics {
                var additions = 0
                var deletions = 0
                var hunkCount = 0
                var nonEmptyLineCount = 0

                for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                    let lineString = String(line)
                    if !lineString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        nonEmptyLineCount += 1
                    }

                    if lineString.hasPrefix("@@") {
                        hunkCount += 1
                    } else if lineString.hasPrefix("+"), !lineString.hasPrefix("+++") {
                        additions += 1
                    } else if lineString.hasPrefix("-"), !lineString.hasPrefix("---") {
                        deletions += 1
                    }
                }

                return .init(
                    additions: additions,
                    characterCount: text.count,
                    deletions: deletions,
                    hunkCount: hunkCount,
                    nonEmptyLineCount: nonEmptyLineCount
                )
            }
        }

        public let cachePolicy: CachePolicy
        public let residentLimit: Int
        public let threadID: String
        public private(set) var files: [FileSnapshot]
        public private(set) var isLoadingOlderFiles: Bool
        public private(set) var lastLoadErrorDescription: String?
        public private(set) var nextOlderCursor: String?
        public private(set) var residentPayloadCost: Int
        public private(set) var visibleFileIDs: [String]
        public var selectedFileID: String? {
            didSet {
                scheduleResidencyMaintenance()
            }
        }

        @ObservationIgnored
        private let appServer: CodexAppServer

        @ObservationIgnored
        private var fileDeltaTask: Task<Void, Never>?

        @ObservationIgnored
        private var turnEventTask: Task<Void, Never>?

        @ObservationIgnored
        private var residencyTask: Task<Void, Never>?

        internal init(
            cachePolicy: CachePolicy,
            threadID: String,
            residentLimit: Int,
            nextOlderCursor: String?,
            initialFiles: [FileSnapshot],
            turnEvents: AsyncThrowingStream<CodexTurnEvent, Error>,
            fileDeltaEvents: AsyncStream<CodexAppServer.FileChangeOutputDeltaEvent>,
            appServer: CodexAppServer
        ) {
            self.cachePolicy = cachePolicy
            self.threadID = threadID
            self.residentLimit = residentLimit
            self.nextOlderCursor = nextOlderCursor
            self.files = initialFiles
            self.isLoadingOlderFiles = false
            self.lastLoadErrorDescription = nil
            self.residentPayloadCost = initialFiles.reduce(0) { $0 + Self.fileResidentCost($1) }
            self.visibleFileIDs = []
            self.selectedFileID = nil
            self.appServer = appServer
            trimResidentFilesIfNeeded()

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
            residencyTask?.cancel()
        }

        /// Loads files older than the current resident window.
        ///
        /// Omitting `limit` uses this companion's resident page limit.
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
                trimResidentFilesIfNeeded()
                scheduleResidencyMaintenance()
            } catch {
                lastLoadErrorDescription = error.localizedDescription
                throw error
            }
        }

        public func updateVisibleFileIDs(_ ids: [String]) {
            let deduplicatedIDs = Array(NSOrderedSet(array: ids)) as? [String] ?? ids
            visibleFileIDs = deduplicatedIDs
            scheduleResidencyMaintenance()
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

            trimResidentFilesIfNeeded()
            scheduleResidencyMaintenance()
        }

        private func apply(_ event: CodexAppServer.FileChangeOutputDeltaEvent) {
            let fileID = Self.fileSnapshotID(turnID: event.turnID, itemID: event.itemID)
            guard let index = files.firstIndex(where: { $0.id == fileID }) else { return }
            files[index].apply(delta: event.delta)
            refreshResidentMetrics()
            trimResidentFilesIfNeeded()
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
                        latestStatusText: FileSnapshot.makeStatusSummary(
                            status: item.status,
                            text: item.streamedText ?? item.text
                        ),
                        path: item.path,
                        payloadText: item.streamedText ?? item.text,
                        isPayloadComplete: true,
                        omittedPayloadCharacterCount: 0,
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
            refreshResidentMetrics()
        }

        private func mergeOrPrepend(_ incoming: [FileSnapshot]) {
            for file in incoming.reversed() {
                if let index = files.firstIndex(where: { $0.id == file.id }) {
                    files[index].mergeNewerSnapshot(file)
                } else {
                    files.insert(file, at: 0)
                }
            }

            trimResidentFilesIfNeeded()
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
                        latestStatusText: FileSnapshot.makeStatusSummary(status: item.status, text: item.text),
                        path: item.path,
                        payloadText: item.text,
                        isPayloadComplete: status != .inProgress && item.text != nil,
                        omittedPayloadCharacterCount: 0,
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
                await self.hydrateProtectedFilesIfNeeded()
                self.trimResidentFilesIfNeeded()
            }
        }

        private func hydrateProtectedFilesIfNeeded() async {
            let protectedIDs = protectedFileIDSet()
            let slimmedProtectedIDs = files.compactMap { file -> String? in
                guard protectedIDs.contains(file.id), !file.isPayloadComplete else { return nil }
                return file.id
            }

            guard !slimmedProtectedIDs.isEmpty else { return }

            for fileID in slimmedProtectedIDs {
                do {
                    guard let index = files.firstIndex(where: { $0.id == fileID }) else { continue }
                    let file = files[index]
                    guard let snapshot = try await appServer.turnSnapshot(threadID: threadID, turnID: file.turnID) else {
                        continue
                    }
                    guard let item = snapshot.items.first(where: { $0.id == file.itemID }) else {
                        continue
                    }
                    files[index].hydratePayload(
                        text: item.streamedText ?? item.text,
                        latestStatusText: FileSnapshot.makeStatusSummary(
                            status: item.status,
                            text: item.streamedText ?? item.text
                        ),
                        status: Self.status(from: item.status)
                    )
                    files[index].itemOrderIndex = item.orderIndex
                    files[index].turnOrderIndex = snapshot.orderIndex
                    files[index].turnStartedAt = snapshot.startedAt
                    lastLoadErrorDescription = nil
                } catch {
                    lastLoadErrorDescription = error.localizedDescription
                }
            }

            refreshResidentMetrics()
        }

        private func trimResidentFilesIfNeeded() {
            let maxResidentFiles = cachePolicy.maxResidentFiles
            if files.count > maxResidentFiles {
                let focusIndices = focusIndices()
                let focusLowerBound = max(0, focusIndices.lowerBound - cachePolicy.protectedFileBuffer)
                let focusUpperBound = min(files.count - 1, focusIndices.upperBound + cachePolicy.protectedFileBuffer)

                var mandatoryIndices = Set<Int>(focusLowerBound...focusUpperBound)
                for (index, file) in files.enumerated() where file.status == .inProgress {
                    mandatoryIndices.insert(index)
                }
                for index in files.indices.prefix(cachePolicy.protectedRecentCompletedFiles)
                where files[index].status != .inProgress {
                    mandatoryIndices.insert(index)
                }

                let retainedIndices: Set<Int>
                if mandatoryIndices.count >= maxResidentFiles {
                    retainedIndices = mandatoryIndices
                } else {
                    let supplementalIndices = files.indices
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
                    for index in supplementalIndices.prefix(maxResidentFiles - mandatoryIndices.count) {
                        selectedIndices.insert(index)
                    }
                    retainedIndices = selectedIndices
                }

                files = files.enumerated()
                    .filter { retainedIndices.contains($0.offset) }
                    .map(\.element)
            }

            trimResidentPayloadIfNeeded()
        }

        private func trimResidentPayloadIfNeeded() {
            guard let maximumResidentPayloadCost = cachePolicy.maximumResidentPayloadCost else {
                refreshResidentMetrics()
                return
            }

            refreshResidentMetrics()
            guard residentPayloadCost > maximumResidentPayloadCost else { return }

            let protectedIDs = protectedFileIDSet()
            for index in files.indices.reversed() {
                guard residentPayloadCost > maximumResidentPayloadCost else { break }
                let file = files[index]
                guard file.status != .inProgress else { continue }
                guard !protectedIDs.contains(file.id) else { continue }
                guard file.isPayloadComplete else { continue }
                files[index].slimPayload()
                refreshResidentMetrics()
            }

            while residentPayloadCost > maximumResidentPayloadCost, files.count > cachePolicy.minimumResidentFiles {
                guard let evictableIndex = files.indices.reversed().first(where: { index in
                    let file = files[index]
                    return file.status != .inProgress && !protectedIDs.contains(file.id)
                }) else {
                    break
                }

                files.remove(at: evictableIndex)
                refreshResidentMetrics()
            }
        }

        private func protectedFileIDSet() -> Set<String> {
            guard !files.isEmpty else { return [] }

            let focusIndices = focusIndices()
            let focusLowerBound = max(0, focusIndices.lowerBound - cachePolicy.protectedFileBuffer)
            let focusUpperBound = min(files.count - 1, focusIndices.upperBound + cachePolicy.protectedFileBuffer)
            var protectedIDs = Set(files[focusLowerBound...focusUpperBound].map(\.id))
            if let selectedFileID {
                protectedIDs.insert(selectedFileID)
            }
            protectedIDs.formUnion(visibleFileIDs)
            for file in files where file.status == .inProgress {
                protectedIDs.insert(file.id)
            }
            for file in files.prefix(cachePolicy.protectedRecentCompletedFiles) where file.status != .inProgress {
                protectedIDs.insert(file.id)
            }
            return protectedIDs
        }

        private func focusIndices() -> ClosedRange<Int> {
            guard !files.isEmpty else { return 0...0 }

            let visibleIndexSet = Set(visibleFileIDs.compactMap(index(forFileID:)))
            if !visibleIndexSet.isEmpty {
                return visibleIndexSet.min()!...visibleIndexSet.max()!
            }

            if let selectedFileID, let index = index(forFileID: selectedFileID) {
                return index...index
            }

            return 0...0
        }

        private func index(forFileID fileID: String) -> Int? {
            files.firstIndex { $0.id == fileID }
        }

        private func refreshResidentMetrics() {
            residentPayloadCost = files.reduce(0) { $0 + Self.fileResidentCost($1) }
        }

        private static func fileSnapshotID(turnID: String, itemID: String) -> String {
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

        private static func fileResidentCost(_ file: FileSnapshot) -> Int {
            let baseCost = file.status == .inProgress ? 3 : 1
            guard let payloadText = file.payloadText, !payloadText.isEmpty else {
                return baseCost
            }

            let metrics = FileSnapshot.payloadMetrics(text: payloadText)
            let characterCost = max(1, Int(ceil(Double(metrics.characterCount) / 320.0)))
            let lineCost = max(1, Int(ceil(Double(metrics.nonEmptyLineCount) / 12.0)))
            let diffSignalCost = min(metrics.additions + metrics.deletions, 10)
            let hunkCost = min(metrics.hunkCount, 4)
            let payloadCost = min(
                characterCost + lineCost + diffSignalCost + hunkCost,
                file.isPayloadComplete ? 20 : 10
            )
            return baseCost + payloadCost
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


}

extension CodexThread.RecentFiles.FileSnapshot {
    init(_ snapshot: CodexAppServer.RecentFileSnapshot) {
        self.init(
            id: snapshot.id,
            itemID: snapshot.itemID,
            displayName: Self.makeDisplayName(path: snapshot.path),
            latestStatusText: snapshot.latestStatusText,
            path: snapshot.path,
            payloadText: snapshot.payloadText,
            isPayloadComplete: true,
            omittedPayloadCharacterCount: 0,
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
