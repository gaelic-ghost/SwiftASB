import Foundation

public extension CodexThread {
    /// Request used to list one directory under this thread's workspace root.
    struct WorkspaceFileListRequest: Sendable, Equatable {
        public var includeHidden: Bool
        public var path: String?

        /// Creates a workspace file-list request.
        ///
        /// Nil or empty `path` lists the workspace root. Relative paths are
        /// resolved under ``CodexThread/currentDirectoryPath``. Absolute paths
        /// are accepted only when they stay inside the same resolved workspace.
        public init(path: String? = nil, includeHidden: Bool = false) {
            self.includeHidden = includeHidden
            self.path = path
        }
    }

    /// Request used to read one UTF-8 text file under this thread's workspace root.
    struct WorkspaceFileReadRequest: Sendable, Equatable {
        public var maximumBytes: Int
        public var path: String

        /// Creates a workspace file-read request.
        ///
        /// `maximumBytes` is normalized to at least 1 byte. SwiftASB rejects
        /// larger files instead of truncating them so callers do not render
        /// incomplete source text as if it were complete.
        public init(path: String, maximumBytes: Int = 1_048_576) {
            self.maximumBytes = max(1, maximumBytes)
            self.path = path
        }
    }

    /// Directory listing rooted in this thread's workspace.
    struct WorkspaceFileList: Sendable, Equatable {
        public let directoryRelativePath: String
        public let entries: [WorkspaceFileEntry]
        public let workspacePath: String
    }

    /// One visible filesystem entry under this thread's workspace.
    struct WorkspaceFileEntry: Sendable, Equatable, Identifiable {
        /// Basic filesystem kind for a listed workspace entry.
        public enum Kind: String, Sendable, Equatable {
            case directory
            case file
            case other
            case symbolicLink
        }

        public var id: String { relativePath }

        public let byteCount: Int64?
        public let isHidden: Bool
        public let kind: Kind
        public let modifiedAt: Date?
        public let name: String
        public let relativePath: String
    }

    /// UTF-8 text contents read from a file under this thread's workspace.
    struct WorkspaceFileContents: Sendable, Equatable {
        public let byteCount: Int
        public let contents: String
        public let relativePath: String
        public let workspacePath: String
    }

    /// Error raised while resolving, listing, or reading workspace files.
    enum WorkspaceFileError: Error, Sendable, LocalizedError, Equatable {
        case fileSystemFailure(operation: String, path: String, reason: String)
        case fileTooLarge(path: String, byteCount: Int64, maximumBytes: Int)
        case missingPath(path: String)
        case missingWorkspaceRoot(path: String)
        case notDirectory(path: String)
        case notFile(path: String)
        case outsideWorkspace(path: String, workspacePath: String)
        case unsupportedTextEncoding(path: String)

        public var errorDescription: String? {
            switch self {
            case let .fileSystemFailure(operation, path, reason):
                return "Workspace file \(operation) failed for \(path): \(reason)"
            case let .fileTooLarge(path, byteCount, maximumBytes):
                return "Workspace file read rejected \(path) because it is \(byteCount) bytes, which exceeds the configured \(maximumBytes)-byte limit."
            case let .missingPath(path):
                return "Workspace file path does not exist: \(path)."
            case let .missingWorkspaceRoot(path):
                return "Workspace root does not exist or is not a directory: \(path)."
            case let .notDirectory(path):
                return "Workspace file listing requires a directory, but \(path) is not a directory."
            case let .notFile(path):
                return "Workspace file read requires a regular file, but \(path) is not a file."
            case let .outsideWorkspace(path, workspacePath):
                return "Workspace file path \(path) resolves outside the thread workspace root \(workspacePath)."
            case let .unsupportedTextEncoding(path):
                return "Workspace file read supports UTF-8 text files, but \(path) could not be decoded as UTF-8."
            }
        }
    }

    /// Lists one workspace directory without asking the app-server to run a command.
    func listWorkspaceFiles(_ request: WorkspaceFileListRequest = .init()) throws -> WorkspaceFileList {
        let root = try resolvedWorkspaceRoot()
        let directory = try resolveWorkspacePath(request.path, root: root)

        guard FileManager.default.fileExists(atPath: directory.url.path) else {
            throw WorkspaceFileError.missingPath(path: directory.url.path)
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw WorkspaceFileError.notDirectory(path: directory.url.path)
        }

        let properties: Set<URLResourceKey> = [
            .contentModificationDateKey,
            .fileSizeKey,
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey,
        ]
        let options: FileManager.DirectoryEnumerationOptions = request.includeHidden ? [] : [.skipsHiddenFiles]
        let urls: [URL]
        do {
            urls = try FileManager.default.contentsOfDirectory(
                at: directory.url,
                includingPropertiesForKeys: Array(properties),
                options: options
            )
        } catch {
            throw WorkspaceFileError.fileSystemFailure(
                operation: "listing",
                path: directory.url.path,
                reason: error.localizedDescription
            )
        }

        let entries: [WorkspaceFileEntry]
        do {
            entries = try urls.map { url in
                try WorkspaceFileEntry(url: url, root: root)
            }
            .sorted()
        } catch let workspaceError as WorkspaceFileError {
            throw workspaceError
        } catch {
            throw WorkspaceFileError.fileSystemFailure(
                operation: "reading listed entry metadata",
                path: directory.url.path,
                reason: error.localizedDescription
            )
        }

        return .init(
            directoryRelativePath: directory.relativePath,
            entries: entries,
            workspacePath: root.url.path
        )
    }

    /// Reads one UTF-8 workspace file without asking the app-server to run a command.
    func readWorkspaceFile(_ request: WorkspaceFileReadRequest) throws -> WorkspaceFileContents {
        let root = try resolvedWorkspaceRoot()
        let file = try resolveWorkspacePath(request.path, root: root)

        guard FileManager.default.fileExists(atPath: file.url.path) else {
            throw WorkspaceFileError.missingPath(path: file.url.path)
        }

        let values: URLResourceValues
        do {
            values = try file.url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        } catch {
            throw WorkspaceFileError.fileSystemFailure(
                operation: "reading metadata",
                path: file.url.path,
                reason: error.localizedDescription
            )
        }
        guard values.isRegularFile == true else {
            throw WorkspaceFileError.notFile(path: file.url.path)
        }

        let byteCount = Int64(values.fileSize ?? 0)
        guard byteCount <= Int64(request.maximumBytes) else {
            throw WorkspaceFileError.fileTooLarge(
                path: file.url.path,
                byteCount: byteCount,
                maximumBytes: request.maximumBytes
            )
        }

        let data: Data
        do {
            data = try Data(contentsOf: file.url)
        } catch {
            throw WorkspaceFileError.fileSystemFailure(
                operation: "reading contents",
                path: file.url.path,
                reason: error.localizedDescription
            )
        }
        guard let contents = String(data: data, encoding: .utf8) else {
            throw WorkspaceFileError.unsupportedTextEncoding(path: file.url.path)
        }

        return .init(
            byteCount: data.count,
            contents: contents,
            relativePath: file.relativePath,
            workspacePath: root.url.path
        )
    }
}

private struct ResolvedWorkspacePath {
    let relativePath: String
    let url: URL
}

private extension CodexThread {
    func resolvedWorkspaceRoot() throws -> ResolvedWorkspacePath {
        let rootURL = URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)
            .standardizedFileURL
            .resolvingSymlinksInPath()

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw WorkspaceFileError.missingWorkspaceRoot(path: currentDirectoryPath)
        }

        return .init(relativePath: ".", url: rootURL)
    }

    func resolveWorkspacePath(_ path: String?, root: ResolvedWorkspacePath) throws -> ResolvedWorkspacePath {
        let requestedPath = normalizedRequestedPath(path)
        let rawURL: URL
        if requestedPath.hasPrefix("/") {
            rawURL = URL(fileURLWithPath: requestedPath)
        } else {
            rawURL = root.url.appendingPathComponent(requestedPath)
        }

        let resolvedURL = rawURL
            .standardizedFileURL
            .resolvingSymlinksInPath()
        guard resolvedURL.isContained(in: root.url) else {
            throw WorkspaceFileError.outsideWorkspace(
                path: rawURL.standardizedFileURL.path,
                workspacePath: root.url.path
            )
        }

        return .init(
            relativePath: resolvedURL.workspaceRelativePath(from: root.url),
            url: resolvedURL
        )
    }

    func normalizedRequestedPath(_ path: String?) -> String {
        guard let path else { return "." }
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "." : trimmed
    }
}

private extension CodexThread.WorkspaceFileEntry {
    init(url: URL, root: ResolvedWorkspacePath) throws {
        let values = try url.resourceValues(forKeys: [
            .contentModificationDateKey,
            .fileSizeKey,
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey,
        ])
        let kind: Kind
        if values.isSymbolicLink == true {
            kind = .symbolicLink
        } else if values.isDirectory == true {
            kind = .directory
        } else if values.isRegularFile == true {
            kind = .file
        } else {
            kind = .other
        }

        self.init(
            byteCount: kind == .file ? Int64(values.fileSize ?? 0) : nil,
            isHidden: url.lastPathComponent.hasPrefix("."),
            kind: kind,
            modifiedAt: values.contentModificationDate,
            name: url.lastPathComponent,
            relativePath: url.standardizedFileURL.workspaceRelativePath(from: root.url)
        )
    }
}

private extension Array where Element == CodexThread.WorkspaceFileEntry {
    func sorted() -> Self {
        sorted { lhs, rhs in
            if lhs.kind == .directory, rhs.kind != .directory {
                return true
            }
            if lhs.kind != .directory, rhs.kind == .directory {
                return false
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}

private extension URL {
    func isContained(in root: URL) -> Bool {
        let path = path
        let rootPath = root.path
        return path == rootPath || path.hasPrefix(rootPath + "/")
    }

    func workspaceRelativePath(from root: URL) -> String {
        let path = path
        let rootPath = root.path
        guard path != rootPath else { return "." }
        return String(path.dropFirst(rootPath.count + 1))
    }
}
