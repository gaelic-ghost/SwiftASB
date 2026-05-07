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

        public var id: String { path }

        public let depth: Int
        public let fileName: String
        public let kind: Kind
        public let path: String
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
            let score = query.searchTerm.flatMap {
                fuzzyScore(query: $0, candidate: relativePath)
            }

            if query.includedKinds.contains(kind),
               query.searchTerm == nil || score != nil
            {
                hits.append(
                    .init(
                        depth: depth,
                        fileName: entry.fileName,
                        kind: kind,
                        path: childPath,
                        relativePath: relativePath,
                        score: score
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

    func fuzzyScore(query: String, candidate: String) -> Int? {
        let normalizedQuery = query.lowercased()
        let queryCharacters = Array(normalizedQuery)
        guard !queryCharacters.isEmpty else { return nil }

        let normalizedCandidate = candidate.lowercased()
        let baseName = URL(fileURLWithPath: candidate).lastPathComponent.lowercased()

        guard let pathScore = subsequenceScore(queryCharacters: queryCharacters, candidate: normalizedCandidate) else {
            return nil
        }

        var score = pathScore
        if let baseNameScore = subsequenceScore(queryCharacters: queryCharacters, candidate: baseName) {
            score = max(score, baseNameScore + 35)
        }

        if baseName == normalizedQuery {
            score += 120
        } else if baseName.hasPrefix(normalizedQuery) {
            score += 80
        } else if baseName.contains(normalizedQuery) {
            score += 60
        } else if normalizedCandidate.contains(normalizedQuery) {
            score += 25
        }

        if acronymMatches(query: normalizedQuery, candidate: baseName) {
            score += 35
        }

        return score - generatedPathPenalty(candidate: normalizedCandidate)
    }

    func subsequenceScore(queryCharacters: [Character], candidate: String) -> Int? {
        let candidateCharacters = Array(candidate)
        var queryIndex = 0
        var score = 0
        var previousMatchIndex: Int?

        for (candidateIndex, candidateCharacter) in candidateCharacters.enumerated() {
            guard candidateCharacter == queryCharacters[queryIndex] else { continue }

            score += 10
            if candidateIndex == 0 || isPathBoundary(candidateCharacters[candidateIndex - 1]) {
                score += 8
            }
            if let previousMatchIndex {
                score += max(0, 6 - (candidateIndex - previousMatchIndex - 1))
            }

            previousMatchIndex = candidateIndex
            queryIndex += 1

            if queryIndex == queryCharacters.count {
                return score - candidateCharacters.count
            }
        }

        return nil
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
