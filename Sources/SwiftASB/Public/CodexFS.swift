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
