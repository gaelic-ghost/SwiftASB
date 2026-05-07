import Foundation

/// App-server-owned filesystem access surface.
///
/// `CodexFS` routes filesystem reads through the Codex app-server instead of
/// reading local disk from the Swift client process. That keeps sandboxed apps
/// dependent on Codex-owned permissions and path handling.
public struct CodexFS: Sendable {
    private let appServer: CodexAppServer

    init(appServer: CodexAppServer) {
        self.appServer = appServer
    }

    /// Request used to inspect app-server-owned filesystem metadata for an absolute path.
    public struct MetadataRequest: Sendable, Equatable {
        public var path: String

        /// Creates a metadata request for an absolute path known to Codex.
        public init(path: String) {
            self.path = path
        }
    }

    /// Metadata returned by the app-server for one filesystem path.
    public struct Metadata: Sendable, Equatable {
        public let createdAtMilliseconds: Int
        public let isDirectory: Bool
        public let isFile: Bool
        public let isSymbolicLink: Bool
        public let modifiedAtMilliseconds: Int
    }

    /// Request used to list direct children for an absolute directory path.
    public struct DirectoryReadRequest: Sendable, Equatable {
        public var path: String

        /// Creates a directory-read request for an absolute path known to Codex.
        public init(path: String) {
            self.path = path
        }
    }

    /// Direct child entries for one directory.
    public struct DirectoryReadResult: Sendable, Equatable {
        public let entries: [DirectoryEntry]
    }

    /// One direct child returned by the app-server for a directory read.
    public struct DirectoryEntry: Sendable, Equatable, Identifiable {
        /// Basic filesystem kind reported for the entry.
        public enum Kind: String, Sendable, Equatable {
            case directory
            case file
            case other
        }

        public var id: String { fileName }

        public let fileName: String
        public let kind: Kind
    }

    /// Request used to read file bytes through the app-server.
    public struct FileReadRequest: Sendable, Equatable {
        public var path: String

        /// Creates a file-read request for an absolute path known to Codex.
        public init(path: String) {
            self.path = path
        }
    }

    /// File bytes returned by the app-server.
    public struct FileReadResult: Sendable, Equatable {
        public let data: Data
    }

    /// Request used to subscribe to app-server filesystem change notifications.
    public struct WatchRequest: Sendable, Equatable {
        public var path: String
        public var watchID: String?

        /// Creates a watch request for an absolute file or directory path.
        ///
        /// Nil `watchID` lets SwiftASB generate a connection-scoped identifier.
        public init(path: String, watchID: String? = nil) {
            self.path = path
            self.watchID = watchID
        }
    }

    /// Request used to stop a filesystem watch.
    public struct UnwatchRequest: Sendable, Equatable {
        public var watchID: String

        /// Creates an unwatch request for an existing app-server watch id.
        public init(watchID: String) {
            self.watchID = watchID
        }
    }

    /// Active filesystem watch returned by the app-server.
    public struct Watch: Sendable {
        public let events: AsyncStream<ChangeEvent>
        public let path: String
        public let watchID: String
    }

    /// Filesystem paths changed for one active watch.
    public struct ChangeEvent: Sendable, Equatable {
        public let watchID: String
        public let changedPaths: [String]
    }

    /// Repeatable file-discovery intent for app-server-owned directory reads.
    ///
    /// `FileDiscoveryQD` lets sandboxed clients describe a bounded file-picker
    /// or fuzzy file search without reading local disk directly. SwiftASB walks
    /// directories through `fs/readDirectory`, then applies local filtering and
    /// ranking to entries returned by the app-server.
    public struct FileDiscoveryQD: Sendable, Equatable {
        public var includedKinds: Set<FileDiscoveryHit.Kind>
        public var includesHiddenEntries: Bool
        public var limit: Int
        public var maximumDepth: Int
        public var rootPath: String
        public var searchTerm: String?

        /// Creates a file-discovery query descriptor.
        ///
        /// Numeric inputs are normalized to useful lower bounds. `maximumDepth`
        /// counts child-directory hops below `rootPath`, so `0` means only the
        /// root directory's direct entries.
        public init(
            rootPath: String,
            searchTerm: String? = nil,
            limit: Int = 50,
            maximumDepth: Int = 6,
            includedKinds: Set<FileDiscoveryHit.Kind> = [.file],
            includesHiddenEntries: Bool = false
        ) {
            self.rootPath = rootPath
            self.searchTerm = Self.normalizedSearchTerm(searchTerm)
            self.limit = max(1, limit)
            self.maximumDepth = max(0, maximumDepth)
            self.includedKinds = includedKinds.isEmpty ? [.file] : includedKinds
            self.includesHiddenEntries = includesHiddenEntries
        }

        /// File entries below `rootPath`, optionally ranked by fuzzy search term.
        public static func files(
            under rootPath: String,
            matching searchTerm: String? = nil,
            limit: Int = 50,
            maximumDepth: Int = 6
        ) -> Self {
            .init(
                rootPath: rootPath,
                searchTerm: searchTerm,
                limit: limit,
                maximumDepth: maximumDepth,
                includedKinds: [.file]
            )
        }

        /// File and directory entries below `rootPath`, optionally ranked by fuzzy search term.
        public static func entries(
            under rootPath: String,
            matching searchTerm: String? = nil,
            limit: Int = 50,
            maximumDepth: Int = 6
        ) -> Self {
            .init(
                rootPath: rootPath,
                searchTerm: searchTerm,
                limit: limit,
                maximumDepth: maximumDepth,
                includedKinds: [.directory, .file, .other]
            )
        }

        /// Returns the same query with a normalized result limit.
        public func limited(to limit: Int) -> Self {
            .init(
                rootPath: rootPath,
                searchTerm: searchTerm,
                limit: limit,
                maximumDepth: maximumDepth,
                includedKinds: includedKinds,
                includesHiddenEntries: includesHiddenEntries
            )
        }

        /// Returns the same query with a normalized maximum traversal depth.
        public func limitedDepth(to maximumDepth: Int) -> Self {
            .init(
                rootPath: rootPath,
                searchTerm: searchTerm,
                limit: limit,
                maximumDepth: maximumDepth,
                includedKinds: includedKinds,
                includesHiddenEntries: includesHiddenEntries
            )
        }

        /// Returns the same query with a normalized fuzzy search term.
        public func searching(_ searchTerm: String?) -> Self {
            .init(
                rootPath: rootPath,
                searchTerm: searchTerm,
                limit: limit,
                maximumDepth: maximumDepth,
                includedKinds: includedKinds,
                includesHiddenEntries: includesHiddenEntries
            )
        }

        /// Returns the same query with hidden entries included or excluded.
        public func includingHiddenEntries(_ includesHiddenEntries: Bool = true) -> Self {
            .init(
                rootPath: rootPath,
                searchTerm: searchTerm,
                limit: limit,
                maximumDepth: maximumDepth,
                includedKinds: includedKinds,
                includesHiddenEntries: includesHiddenEntries
            )
        }

        private static func normalizedSearchTerm(_ searchTerm: String?) -> String? {
            let normalized = searchTerm?.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized?.isEmpty == false ? normalized : nil
        }
    }

    /// Results returned by a file-discovery query.
    public struct FileDiscoveryResult: Sendable, Equatable {
        public let hits: [FileDiscoveryHit]
    }

    /// One file-discovery hit returned from an app-server directory walk.
    public struct FileDiscoveryHit: Sendable, Equatable, Identifiable {
        /// Filesystem kind reported by the app-server.
        public enum Kind: String, Sendable, Equatable, Hashable {
            case directory
            case file
            case other
        }

        /// Search match shape that best explains why a hit ranked.
        public enum MatchKind: String, Sendable, Equatable {
            /// The normalized file name exactly equals the normalized search term.
            case exactFileName
            /// The normalized file name starts with the normalized search term.
            case fileNamePrefix
            /// The normalized file name contains the normalized search term.
            case fileNameContains
            /// The normalized relative path contains the normalized search term.
            case relativePathContains
            /// Word initials in the file name match the normalized search term.
            case acronym
            /// Search characters matched in order without a stronger contiguous match.
            case subsequence
        }

        /// Character-offset range for highlighting matched text.
        public struct MatchRange: Sendable, Equatable {
            /// Number of matched characters in this contiguous range.
            public let length: Int
            /// Zero-based character offset where the match range begins.
            public let start: Int
        }

        /// Ranking signal that contributed to a fuzzy file-discovery score.
        public struct RankingReason: Sendable, Equatable {
            /// Stable reason category for UI explanations.
            public enum Kind: String, Sendable, Equatable {
                /// File-name initials matched the search term.
                case acronymMatch
                /// File name exactly matched the search term.
                case exactFileName
                /// File name contained the search term.
                case fileNameContains
                /// File name started with the search term.
                case fileNamePrefix
                /// File name matched the search term as an ordered subsequence.
                case fileNameSubsequence
                /// Generated or build-output path components lowered the score.
                case generatedPathPenalty
                /// A matched character landed at a path, word, or punctuation boundary.
                case pathBoundaryMatch
                /// Relative path contained the search term.
                case relativePathContains
                /// Relative path matched the search term as an ordered subsequence.
                case relativePathSubsequence
            }

            /// Stable reason category for the ranking signal.
            public let kind: Kind
            /// Score contribution for the signal. Penalties use negative values.
            public let value: Int
        }

        public var id: String { path }

        public let depth: Int
        public let fileName: String
        public let kind: Kind
        /// Strongest search match shape for this hit, or nil when no search term was used.
        public let matchKind: MatchKind?
        /// Character ranges in `fileName` that matched the search term.
        public let matchedFileNameRanges: [MatchRange]
        /// Character ranges in `relativePath` that matched the search term.
        public let matchedRelativePathRanges: [MatchRange]
        public let path: String
        /// Stable ranking signals that explain the fuzzy score.
        public let rankingReasons: [RankingReason]
        public let relativePath: String
        public let score: Int?
    }

    /// Reads app-server-owned filesystem metadata for an absolute path.
    public func readMetadata(_ request: MetadataRequest) async throws -> Metadata {
        try await appServer.readFSMetadata(request)
    }

    /// Lists direct child entries for an absolute directory path through the app-server.
    public func readDirectory(_ request: DirectoryReadRequest) async throws -> DirectoryReadResult {
        try await appServer.readFSDirectory(request)
    }

    /// Reads file bytes through the app-server.
    public func readFile(_ request: FileReadRequest) async throws -> FileReadResult {
        try await appServer.readFSFile(request)
    }

    /// Starts filesystem watch notifications for an absolute path.
    public func watch(_ request: WatchRequest) async throws -> Watch {
        try await appServer.watchFSChanges(request)
    }

    /// Stops filesystem watch notifications for a prior watch.
    public func unwatch(_ request: UnwatchRequest) async throws {
        try await appServer.unwatchFSChanges(request)
    }

    /// Discovers files or directories through app-server directory reads.
    ///
    /// The filesystem traversal is bounded by `maximumDepth` and `limit`.
    /// Fuzzy matching is applied only to app-server-returned entry names and
    /// relative paths; SwiftASB does not inspect local disk directly.
    public func discoverFiles(_ query: FileDiscoveryQD) async throws -> FileDiscoveryResult {
        var hits: [FileDiscoveryHit] = []
        try await collectDiscoveryHits(
            query: query,
            directoryPath: query.rootPath,
            relativeDirectoryPath: "",
            depth: 0,
            hits: &hits
        )

        let sortedHits = hits.sorted { lhs, rhs in
            switch (lhs.score, rhs.score) {
            case let (left?, right?) where left != right:
                return left > right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                if lhs.depth != rhs.depth {
                    return lhs.depth < rhs.depth
                }
                return lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
            }
        }

        return .init(hits: Array(sortedHits.prefix(query.limit)))
    }
}

public extension CodexAppServer {
    /// App-server-owned filesystem access surface.
    var fs: CodexFS {
        CodexFS(appServer: self)
    }
}

extension CodexFS.Metadata {
    init(wireValue: CodexWireFSGetMetadataResponse) {
        self.init(
            createdAtMilliseconds: wireValue.createdAtMS,
            isDirectory: wireValue.isDirectory,
            isFile: wireValue.isFile,
            isSymbolicLink: wireValue.isSymlink,
            modifiedAtMilliseconds: wireValue.modifiedAtMS
        )
    }
}

extension CodexFS.DirectoryReadResult {
    init(wireValue: CodexWireFSReadDirectoryResponse) {
        self.init(entries: wireValue.entries.map(CodexFS.DirectoryEntry.init(wireValue:)))
    }
}

extension CodexFS.DirectoryEntry {
    init(wireValue: CodexWireFSReadDirectoryEntry) {
        self.init(
            fileName: wireValue.fileName,
            kind: .init(isDirectory: wireValue.isDirectory, isFile: wireValue.isFile)
        )
    }
}

extension CodexFS.DirectoryEntry.Kind {
    init(isDirectory: Bool, isFile: Bool) {
        if isDirectory {
            self = .directory
        } else if isFile {
            self = .file
        } else {
            self = .other
        }
    }
}

private extension CodexFS {
    func collectDiscoveryHits(
        query: FileDiscoveryQD,
        directoryPath: String,
        relativeDirectoryPath: String,
        depth: Int,
        hits: inout [FileDiscoveryHit]
    ) async throws {
        guard depth <= query.maximumDepth else { return }

        let directory = try await readDirectory(.init(path: directoryPath))

        for entry in directory.entries {
            guard query.includesHiddenEntries || !entry.fileName.hasPrefix(".") else {
                continue
            }

            let childPath = appendingPathComponent(entry.fileName, to: directoryPath)
            let relativePath = appendingPathComponent(entry.fileName, to: relativeDirectoryPath)
            let kind = CodexFS.FileDiscoveryHit.Kind(entry.kind)
            let match = query.searchTerm.flatMap {
                fuzzyMatch(query: $0, relativePath: relativePath)
            }

            if query.includedKinds.contains(kind),
               query.searchTerm == nil || match != nil
            {
                hits.append(
                    .init(
                        depth: depth,
                        fileName: entry.fileName,
                        kind: kind,
                        matchKind: match?.kind,
                        matchedFileNameRanges: match?.fileNameRanges ?? [],
                        matchedRelativePathRanges: match?.relativePathRanges ?? [],
                        path: childPath,
                        rankingReasons: match?.rankingReasons ?? [],
                        relativePath: relativePath,
                        score: match?.score
                    )
                )
            }

            if entry.kind == .directory,
               depth < query.maximumDepth
            {
                try await collectDiscoveryHits(
                    query: query,
                    directoryPath: childPath,
                    relativeDirectoryPath: relativePath,
                    depth: depth + 1,
                    hits: &hits
                )
            }
        }
    }

    func appendingPathComponent(_ component: String, to path: String) -> String {
        guard !path.isEmpty else { return component }
        return path.hasSuffix("/") ? path + component : path + "/" + component
    }

    func fuzzyMatch(query: String, relativePath: String) -> FileDiscoveryMatch? {
        let normalizedQuery = query.lowercased()
        let queryCharacters = Array(normalizedQuery)
        guard !queryCharacters.isEmpty else { return nil }

        let normalizedRelativePath = relativePath.lowercased()
        let fileName = URL(fileURLWithPath: relativePath).lastPathComponent
        let normalizedFileName = fileName.lowercased()

        guard let pathMatch = subsequenceScore(queryCharacters: queryCharacters, candidate: normalizedRelativePath) else {
            return nil
        }

        var score = pathMatch.score
        var kind = CodexFS.FileDiscoveryHit.MatchKind.subsequence
        var fileNameRanges: [CodexFS.FileDiscoveryHit.MatchRange] = []
        var reasons: [CodexFS.FileDiscoveryHit.RankingReason] = [
            .init(kind: .relativePathSubsequence, value: pathMatch.score),
        ]

        if pathMatch.hasBoundaryMatch {
            reasons.append(.init(kind: .pathBoundaryMatch, value: 8))
        }

        if let fileNameMatch = subsequenceScore(queryCharacters: queryCharacters, candidate: normalizedFileName) {
            let fileNameScore = fileNameMatch.score + 35
            score = max(score, fileNameScore)
            fileNameRanges = fileNameMatch.ranges
            reasons.append(.init(kind: .fileNameSubsequence, value: fileNameScore))
            if fileNameMatch.hasBoundaryMatch {
                reasons.append(.init(kind: .pathBoundaryMatch, value: 8))
            }
        }

        if normalizedFileName == normalizedQuery {
            score += 120
            kind = .exactFileName
            reasons.append(.init(kind: .exactFileName, value: 120))
        } else if normalizedFileName.hasPrefix(normalizedQuery) {
            score += 80
            kind = .fileNamePrefix
            reasons.append(.init(kind: .fileNamePrefix, value: 80))
        } else if normalizedFileName.contains(normalizedQuery) {
            score += 60
            kind = .fileNameContains
            reasons.append(.init(kind: .fileNameContains, value: 60))
        } else if normalizedRelativePath.contains(normalizedQuery) {
            score += 25
            kind = .relativePathContains
            reasons.append(.init(kind: .relativePathContains, value: 25))
        }

        if acronymMatches(query: normalizedQuery, candidate: normalizedFileName) {
            score += 35
            if kind == .subsequence {
                kind = .acronym
            }
            reasons.append(.init(kind: .acronymMatch, value: 35))
        }

        let penalty = generatedPathPenalty(candidate: normalizedRelativePath)
        if penalty > 0 {
            reasons.append(.init(kind: .generatedPathPenalty, value: -penalty))
        }

        return .init(
            fileNameRanges: fileNameRanges,
            kind: kind,
            rankingReasons: reasons,
            relativePathRanges: pathMatch.ranges,
            score: score - penalty
        )
    }

    func subsequenceScore(queryCharacters: [Character], candidate: String) -> SubsequenceMatch? {
        let candidateCharacters = Array(candidate)
        var queryIndex = 0
        var score = 0
        var matchedOffsets: [Int] = []
        var hasBoundaryMatch = false
        var previousMatchIndex: Int?

        for (candidateIndex, candidateCharacter) in candidateCharacters.enumerated() {
            guard candidateCharacter == queryCharacters[queryIndex] else { continue }

            score += 10
            if candidateIndex == 0 || isPathBoundary(candidateCharacters[candidateIndex - 1]) {
                score += 8
                hasBoundaryMatch = true
            }
            if let previousMatchIndex {
                score += max(0, 6 - (candidateIndex - previousMatchIndex - 1))
            }

            matchedOffsets.append(candidateIndex)
            previousMatchIndex = candidateIndex
            queryIndex += 1

            if queryIndex == queryCharacters.count {
                return .init(
                    hasBoundaryMatch: hasBoundaryMatch,
                    ranges: matchRanges(from: matchedOffsets),
                    score: score - candidateCharacters.count
                )
            }
        }

        return nil
    }

    func matchRanges(from offsets: [Int]) -> [CodexFS.FileDiscoveryHit.MatchRange] {
        guard let firstOffset = offsets.first else { return [] }

        var ranges: [CodexFS.FileDiscoveryHit.MatchRange] = []
        var rangeStart = firstOffset
        var previousOffset = firstOffset

        for offset in offsets.dropFirst() {
            if offset == previousOffset + 1 {
                previousOffset = offset
                continue
            }

            ranges.append(.init(length: previousOffset - rangeStart + 1, start: rangeStart))
            rangeStart = offset
            previousOffset = offset
        }

        ranges.append(.init(length: previousOffset - rangeStart + 1, start: rangeStart))
        return ranges
    }

    func acronymMatches(query: String, candidate: String) -> Bool {
        let words = candidate.split { character in
            isPathBoundary(character)
        }
        let initials = words.compactMap(\.first)
        guard !initials.isEmpty else { return false }
        return String(initials).lowercased().hasPrefix(query)
    }

    func generatedPathPenalty(candidate: String) -> Int {
        let components = candidate.split(separator: "/").map(String.init)
        var penalty = 0
        for component in components {
            switch component {
            case ".build", "build", "deriveddata", ".swiftpm":
                penalty += 80
            case "debug", "release", "checkouts", "artifacts":
                penalty += 25
            default:
                continue
            }
        }
        return penalty
    }

    func isPathBoundary(_ character: Character) -> Bool {
        character == "/" || character == "-" || character == "_" || character == "." || character == " "
    }

    struct FileDiscoveryMatch {
        var fileNameRanges: [FileDiscoveryHit.MatchRange]
        var kind: FileDiscoveryHit.MatchKind
        var rankingReasons: [FileDiscoveryHit.RankingReason]
        var relativePathRanges: [FileDiscoveryHit.MatchRange]
        var score: Int
    }

    struct SubsequenceMatch {
        var hasBoundaryMatch: Bool
        var ranges: [FileDiscoveryHit.MatchRange]
        var score: Int
    }
}

private extension CodexFS.FileDiscoveryHit.Kind {
    init(_ entryKind: CodexFS.DirectoryEntry.Kind) {
        switch entryKind {
        case .directory:
            self = .directory
        case .file:
            self = .file
        case .other:
            self = .other
        }
    }
}
