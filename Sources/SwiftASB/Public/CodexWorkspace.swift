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

    /// Thread-session workspace snapshot built from app-server-owned facts.
    public struct SessionSnapshot: Sendable, Equatable {
        public let activePermissionProfile: ActivePermissionProfile?
        public let currentDirectoryPath: String
        public let gitInfo: CodexAppServer.GitInfo?
        public let instructionSources: [String]
        public let permissionProfile: PermissionProfile?
        public let sandboxPolicy: CodexAppServer.SandboxPolicy
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

extension CodexWorkspace.SessionSnapshot {
    init(session: CodexAppServer.ThreadSession) {
        self.init(
            activePermissionProfile: session.activePermissionProfile,
            currentDirectoryPath: session.currentDirectoryPath,
            gitInfo: session.thread.gitInfo,
            instructionSources: session.instructionSources,
            permissionProfile: session.permissionProfile,
            sandboxPolicy: session.sandboxPolicy
        )
    }
}
