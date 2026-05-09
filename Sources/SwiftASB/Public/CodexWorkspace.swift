import Foundation

/// App-server-owned workspace and permission facts.
///
/// `CodexWorkspace` contains the workspace-shaped values that Codex reports or
/// accepts through thread and turn APIs. It does not inspect local disk; callers
/// get cwd, Git, and sandbox/permission facts only from app-server payloads.
public enum CodexWorkspace {
    /// Named permissions profile selection for thread and turn requests.
    public struct PermissionSelection: Sendable, Equatable {
        public var id: String
        public var modifications: [PermissionSelectionModification]

        /// Creates a named permissions profile selection.
        ///
        /// `modifications` defaults to no bounded permission changes on top of
        /// the selected app-server profile.
        public init(
            id: String,
            modifications: [PermissionSelectionModification] = []
        ) {
            self.id = id
            self.modifications = modifications
        }

        /// Built-in workspace profile selection.
        public static var workspace: Self {
            .init(id: ":workspace")
        }
    }

    /// Bounded modification for a selected permissions profile.
    public struct PermissionSelectionModification: Sendable, Equatable {
        public let path: String

        /// Adds a concrete writable root to the selected profile.
        public init(additionalWritableRoot path: String) {
            self.path = path
        }
    }

    /// Named profile and bounded modifications currently active for a session.
    public struct ActivePermissionProfile: Sendable, Equatable {
        public let id: String
        public let extends: String?
        public let modifications: [ActivePermissionModification]
    }

    /// Bounded runtime modification applied to the active profile.
    public struct ActivePermissionModification: Sendable, Equatable {
        /// Runtime modification kind reported by Codex.
        public enum Kind: String, Sendable, Equatable {
            case additionalWritableRoot
            case unknown
        }

        public let kind: Kind
        public let path: String
    }

    /// Full runtime permissions profile reported for a thread session.
    public struct PermissionProfile: Sendable, Equatable {
        /// Runtime profile family reported by Codex.
        public enum Kind: String, Sendable, Equatable {
            case disabled
            case external
            case managed
        }

        public let fileSystem: FileSystemPermissions?
        public let kind: Kind
        public let network: NetworkPermissions?
    }

    /// Filesystem permissions attached to a runtime profile.
    public struct FileSystemPermissions: Sendable, Equatable {
        /// Filesystem permission family reported by Codex.
        public enum Kind: String, Sendable, Equatable {
            case restricted
            case unrestricted
        }

        public let entries: [FileSystemSandboxEntry]
        public let globScanMaxDepth: Int?
        public let kind: Kind
    }

    /// One filesystem sandbox entry in a runtime profile.
    public struct FileSystemSandboxEntry: Sendable, Equatable {
        public let access: FileSystemAccessMode
        public let path: FileSystemPath
    }

    /// Access mode for a filesystem sandbox entry.
    public enum FileSystemAccessMode: String, Sendable, Equatable {
        case none
        case read
        case write
    }

    /// Path selector for a filesystem sandbox entry.
    public enum FileSystemPath: Sendable, Equatable {
        case path(String)
        case globPattern(String)
        case special(FileSystemSpecialPath)
        case unknown
    }

    /// App-server special path selector.
    public struct FileSystemSpecialPath: Sendable, Equatable {
        /// Special path family reported by Codex.
        public enum Kind: String, Sendable, Equatable {
            case minimal
            case projectRoots
            case root
            case slashTmp
            case tmpdir
            case unknown
        }

        public let kind: Kind
        public let path: String?
        public let subpath: String?
    }

    /// Network permissions attached to a runtime profile.
    public struct NetworkPermissions: Sendable, Equatable {
        public let enabled: Bool
    }

    /// App-server-owned project identity for a thread or library group.
    public struct ProjectInfo: Sendable, Equatable, Identifiable {
        /// Fact SwiftASB used to identify the project.
        public enum IdentitySource: String, Sendable, Equatable {
            /// The project identity comes from Codex-reported Git origin metadata.
            case gitOrigin
            /// The project identity falls back to the app-server current working directory.
            case currentDirectory
        }

        public let id: String
        public let identitySource: IdentitySource
        public let displayName: String
        public let currentDirectoryPath: String
        public let repository: RepositoryInfo?
        public let worktree: WorktreeSnapshot

        /// Creates project identity from app-server-owned cwd and optional Git metadata.
        public init(
            currentDirectoryPath: String,
            repository: RepositoryInfo? = nil
        ) {
            let worktree = WorktreeSnapshot(
                currentDirectoryPath: currentDirectoryPath,
                repository: repository
            )
            self.id = worktree.id
            self.identitySource = worktree.identitySource
            self.displayName = worktree.displayName
            self.currentDirectoryPath = worktree.currentDirectoryPath
            self.repository = worktree.repository
            self.worktree = worktree
        }
    }

    /// Codex-reported workspace plus optional Git facts for one thread worktree.
    ///
    /// This value is intentionally a snapshot of app-server payloads. It does
    /// not infer a repository root, run Git commands, or inspect local disk.
    public struct WorktreeSnapshot: Sendable, Equatable, Identifiable {
        public let id: String
        public let identitySource: ProjectInfo.IdentitySource
        public let displayName: String
        public let currentDirectoryPath: String
        public let repository: RepositoryInfo?

        /// Creates a worktree snapshot from an app-server cwd and optional Git facts.
        public init(
            currentDirectoryPath: String,
            repository: RepositoryInfo? = nil
        ) {
            self.currentDirectoryPath = currentDirectoryPath
            self.repository = repository?.normalized

            if let originURL = self.repository?.originURL, !originURL.isEmpty {
                self.id = originURL
                self.identitySource = .gitOrigin
                self.displayName = Self.displayName(forGitOriginURL: originURL)
            } else {
                self.id = currentDirectoryPath
                self.identitySource = .currentDirectory
                self.displayName = currentDirectoryPath.isEmpty ? "Unknown Project" : currentDirectoryPath
            }
        }

        /// True when the app-server reported any Git metadata for this worktree.
        public var hasRepositoryFacts: Bool {
            repository?.hasFacts == true
        }

        private static func displayName(forGitOriginURL originURL: String) -> String {
            guard let url = URL(string: originURL),
                  let host = url.host,
                  let lastPathComponent = url.pathComponents.last else {
                return originURL
            }

            let repositoryName = lastPathComponent.hasSuffix(".git")
                ? String(lastPathComponent.dropLast(4))
                : lastPathComponent
            return repositoryName.isEmpty ? host : "\(repositoryName) (\(host))"
        }
    }

    /// Codex-reported Git facts for a project or thread.
    public struct RepositoryInfo: Sendable, Equatable {
        public let originURL: String?
        public let branch: String?
        public let sha: String?

        /// Creates repository facts reported by Codex.
        public init(
            originURL: String? = nil,
            branch: String? = nil,
            sha: String? = nil
        ) {
            self.originURL = Self.normalizedFact(originURL)
            self.branch = Self.normalizedFact(branch)
            self.sha = Self.normalizedFact(sha)
        }

        /// True when Codex reported at least one Git fact for this thread.
        public var hasFacts: Bool {
            !isEmpty
        }

        /// Short display form for the reported commit SHA.
        public var shortSHA: String? {
            guard let sha, !sha.isEmpty else { return nil }
            return String(sha.prefix(12))
        }

        internal var isEmpty: Bool {
            originURL == nil && branch == nil && sha == nil
        }

        internal var normalized: Self? {
            isEmpty ? nil : self
        }

        private static func normalizedFact(_ value: String?) -> String? {
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty else {
                return nil
            }
            return trimmed
        }
    }

    /// Thread-session workspace snapshot built from app-server-owned facts.
    public struct SessionSnapshot: Sendable, Equatable {
        public let activePermissionProfile: ActivePermissionProfile?
        public let currentDirectoryPath: String
        public let instructionSources: [String]
        public let permissionProfile: PermissionProfile?
        public let projectInfo: ProjectInfo
        public let sandboxPolicy: CodexAppServer.SandboxPolicy
        public let worktree: WorktreeSnapshot
    }
}

extension CodexWorkspace.PermissionSelection {
    var wireValue: CodexWirePermissionProfileSelectionParams {
        .init(
            id: id,
            modifications: modifications.isEmpty ? nil : modifications.map(\.wireValue),
            type: .profile
        )
    }
}

extension CodexWorkspace.PermissionSelectionModification {
    var wireValue: CodexWirePermissionProfileModificationParams {
        .init(path: path, type: .additionalWritableRoot)
    }
}

extension CodexWorkspace.ActivePermissionProfile {
    init(wireValue: CodexWireActivePermissionProfile) {
        self.init(
            id: wireValue.id,
            extends: wireValue.extends,
            modifications: (wireValue.modifications ?? []).map(
                CodexWorkspace.ActivePermissionModification.init(wireValue:)
            )
        )
    }
}

extension CodexWorkspace.ActivePermissionModification {
    init(wireValue: CodexWireActivePermissionProfileModification) {
        self.init(
            kind: .init(wireValue.type),
            path: wireValue.path
        )
    }
}

extension CodexWorkspace.ActivePermissionModification.Kind {
    init(_ wireValue: CodexWireAdditionalWritableRootType) {
        switch wireValue {
        case .additionalWritableRoot:
            self = .additionalWritableRoot
        }
    }
}

extension CodexWorkspace.PermissionProfile {
    init(wireValue: CodexWirePermissionProfile) {
        self.init(
            fileSystem: wireValue.fileSystem.map(CodexWorkspace.FileSystemPermissions.init(wireValue:)),
            kind: .init(wireValue.type),
            network: wireValue.network.map(CodexWorkspace.NetworkPermissions.init(wireValue:))
        )
    }
}

extension CodexWorkspace.PermissionProfile.Kind {
    init(_ wireValue: CodexWirePermissionProfileType) {
        switch wireValue {
        case .disabled:
            self = .disabled
        case .external:
            self = .external
        case .managed:
            self = .managed
        }
    }
}

extension CodexWorkspace.FileSystemPermissions {
    init(wireValue: CodexWirePermissionProfileFileSystemPermissions) {
        self.init(
            entries: (wireValue.entries ?? []).map(CodexWorkspace.FileSystemSandboxEntry.init(wireValue:)),
            globScanMaxDepth: wireValue.globScanMaxDepth,
            kind: .init(wireValue.type)
        )
    }
}

extension CodexWorkspace.FileSystemPermissions.Kind {
    init(_ wireValue: CodexWireRestrictedPermissionProfileFileSystemPermissionsType) {
        switch wireValue {
        case .restricted:
            self = .restricted
        case .unrestricted:
            self = .unrestricted
        }
    }
}

extension CodexWorkspace.FileSystemSandboxEntry {
    init(wireValue: CodexWireFileSystemSandboxEntry) {
        self.init(
            access: .init(wireValue.access),
            path: .init(wireValue.path)
        )
    }
}

extension CodexWorkspace.FileSystemAccessMode {
    init(_ wireValue: CodexWireFileSystemAccessMode) {
        switch wireValue {
        case .none:
            self = .none
        case .read:
            self = .read
        case .write:
            self = .write
        }
    }
}

extension CodexWorkspace.FileSystemPath {
    init(_ wireValue: CodexWireFileSystemPath) {
        switch wireValue.type {
        case .globPattern:
            self = wireValue.pattern.map(Self.globPattern) ?? .unknown
        case .path:
            self = wireValue.path.map(Self.path) ?? .unknown
        case .special:
            self = wireValue.value.map(CodexWorkspace.FileSystemSpecialPath.init(wireValue:)).map(Self.special) ?? .unknown
        }
    }
}

extension CodexWorkspace.FileSystemSpecialPath {
    init(wireValue: CodexWireFileSystemSpecialPath) {
        self.init(
            kind: .init(wireValue.kind),
            path: wireValue.path,
            subpath: wireValue.subpath
        )
    }
}

extension CodexWorkspace.FileSystemSpecialPath.Kind {
    init(_ wireValue: CodexWireKind) {
        switch wireValue {
        case .minimal:
            self = .minimal
        case .projectRoots:
            self = .projectRoots
        case .root:
            self = .root
        case .slashTmp:
            self = .slashTmp
        case .tmpdir:
            self = .tmpdir
        case .unknown:
            self = .unknown
        }
    }
}

extension CodexWorkspace.NetworkPermissions {
    init(wireValue: CodexWirePermissionProfileNetworkPermissions) {
        self.init(enabled: wireValue.enabled)
    }
}

extension CodexWorkspace.RepositoryInfo {
    init(wireValue: CodexWireGitInfo) {
        self.init(
            originURL: wireValue.originURL,
            branch: wireValue.branch,
            sha: wireValue.sha
        )
    }
}

extension CodexWorkspace.SessionSnapshot {
    init(session: CodexAppServer.ThreadSession) {
        self.init(
            activePermissionProfile: session.activePermissionProfile,
            currentDirectoryPath: session.currentDirectoryPath,
            instructionSources: session.instructionSources,
            permissionProfile: session.permissionProfile,
            projectInfo: session.thread.projectInfo,
            sandboxPolicy: session.sandboxPolicy,
            worktree: session.thread.projectInfo.worktree
        )
    }
}
