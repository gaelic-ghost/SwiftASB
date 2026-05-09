import Foundation

/// App-wide SwiftASB feature-category policy.
///
/// `SwiftASBFeaturePolicy` gates SwiftASB-owned convenience features such as
/// Git observability, extension maintenance, and trusted repo-guidance sync. It
/// does not replace Codex app-server sandboxing or interactive approval
/// requests.
public struct SwiftASBFeaturePolicy: Sendable, Equatable {
    public var categoryModes: [SwiftASBFeatureCategory.ID: SwiftASBFeatureMode]
    public var hostAccess: SwiftASBHostAccess

    /// Creates a feature policy.
    ///
    /// Any category omitted from `categoryModes` falls back to its descriptor's
    /// default mode.
    public init(
        categoryModes: [SwiftASBFeatureCategory.ID: SwiftASBFeatureMode] = [:],
        hostAccess: SwiftASBHostAccess = .unknown
    ) {
        self.categoryModes = categoryModes
        self.hostAccess = hostAccess
    }

    /// Built-in defaults for SwiftASB feature categories.
    public static var defaults: Self {
        var modes: [SwiftASBFeatureCategory.ID: SwiftASBFeatureMode] = [:]
        for category in SwiftASBFeatureCategory.builtIn {
            modes[category.id] = category.defaultMode
        }
        return .init(categoryModes: modes)
    }

    /// Returns the current mode for a category.
    public func mode(for categoryID: SwiftASBFeatureCategory.ID) -> SwiftASBFeatureMode {
        categoryModes[categoryID]
            ?? SwiftASBFeatureCategory.builtInCategory(id: categoryID)?.defaultMode
            ?? .disabled
    }

    /// Updates the mode for one feature category.
    public mutating func setMode(
        _ mode: SwiftASBFeatureMode,
        for categoryID: SwiftASBFeatureCategory.ID
    ) {
        categoryModes[categoryID] = mode
    }
}

/// One SwiftASB feature category a consuming app can describe and configure.
public struct SwiftASBFeatureCategory: Sendable, Equatable, Identifiable {
    public struct ID: RawRepresentable, Sendable, Equatable, Hashable, ExpressibleByStringLiteral {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(stringLiteral value: String) {
            self.rawValue = value
        }

        public static let gitObservability: Self = "gitObservability"
        public static let extensionInventory: Self = "extensionInventory"
        public static let extensionMaintenance: Self = "extensionMaintenance"
        public static let swiftRepoGuidanceSync: Self = "swiftRepoGuidanceSync"
        public static let gitActions: Self = "gitActions"
        public static let configMutation: Self = "configMutation"
        public static let extensionMutation: Self = "extensionMutation"
        public static let worktreeAutomation: Self = "worktreeAutomation"
    }

    public let id: ID
    public let displayName: String
    public let description: String
    public let permissionReason: String
    public let defaultMode: SwiftASBFeatureMode
    public let sensitivity: SwiftASBFeatureSensitivity
    public let eventPolicy: SwiftASBFeatureEventPolicy

    /// Creates a feature category descriptor.
    public init(
        id: ID,
        displayName: String,
        description: String,
        permissionReason: String,
        defaultMode: SwiftASBFeatureMode,
        sensitivity: SwiftASBFeatureSensitivity,
        eventPolicy: SwiftASBFeatureEventPolicy
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.permissionReason = permissionReason
        self.defaultMode = defaultMode
        self.sensitivity = sensitivity
        self.eventPolicy = eventPolicy
    }

    /// Built-in SwiftASB feature categories.
    public static let builtIn: [Self] = [
        .init(
            id: .gitObservability,
            displayName: "Git Observability",
            description: "Read branch, SHA, remotes, status summaries, repository identity, and Git availability.",
            permissionReason: "SwiftASB refreshes Git facts so developer tools can show current repository state without each UI running its own probes.",
            defaultMode: .enabled,
            sensitivity: .readOnly,
            eventPolicy: .quietReads
        ),
        .init(
            id: .extensionInventory,
            displayName: "Extension Inventory",
            description: "List installed apps, skills, plugins, marketplaces, collaboration modes, and update availability.",
            permissionReason: "SwiftASB reads installed extension state so consuming apps can show available capabilities and updates.",
            defaultMode: .enabled,
            sensitivity: .readOnly,
            eventPolicy: .quietReads
        ),
        .init(
            id: .extensionMaintenance,
            displayName: "Extension Maintenance",
            description: "Upgrade already-installed extensions, plugins, skills, or marketplace entries.",
            permissionReason: "SwiftASB can keep existing trusted extension installs current while reporting any maintenance write it performs.",
            defaultMode: .enabled,
            sensitivity: .maintenance,
            eventPolicy: .notifyOnMutation
        ),
        .init(
            id: .swiftRepoGuidanceSync,
            displayName: "Swift Repo Guidance Sync",
            description: "Apply trusted, idempotent Apple and Swift repository guidance updates inside detected Git repositories.",
            permissionReason: "SwiftASB writes repo guidance only after this category is enabled, and reports touched files plus rollback details.",
            defaultMode: .disabled,
            sensitivity: .mutation,
            eventPolicy: .notifyOnMutation
        ),
        .init(
            id: .gitActions,
            displayName: "Git Actions",
            description: "Run bounded typed Git intents such as branch creation, staging, commit preparation, or local rollback helpers.",
            permissionReason: "SwiftASB uses typed Git intents instead of arbitrary command strings and reports mutation results.",
            defaultMode: .disabled,
            sensitivity: .mutation,
            eventPolicy: .notifyOnMutation
        ),
        .init(
            id: .configMutation,
            displayName: "Config Mutation",
            description: "Write Codex or SwiftASB configuration values through stable app-server configuration surfaces.",
            permissionReason: "SwiftASB changes configuration only after this category is enabled and reports the setting it changed.",
            defaultMode: .disabled,
            sensitivity: .mutation,
            eventPolicy: .notifyOnMutation
        ),
        .init(
            id: .extensionMutation,
            displayName: "Extension Mutation",
            description: "Install new extensions, uninstall extensions, change extension config, or mutate extension sharing settings.",
            permissionReason: "SwiftASB treats new extension installs, removals, and sharing changes as explicit extension mutations.",
            defaultMode: .disabled,
            sensitivity: .highImpact,
            eventPolicy: .notifyOnMutation
        ),
        .init(
            id: .worktreeAutomation,
            displayName: "Worktree Automation",
            description: "Create, update, or clean worktrees after workspace and Git facts are explicit.",
            permissionReason: "SwiftASB reports worktree changes because they alter repository checkout state on disk.",
            defaultMode: .disabled,
            sensitivity: .mutation,
            eventPolicy: .notifyOnMutation
        ),
    ]

    /// Returns a built-in category by id.
    public static func builtInCategory(id: ID) -> Self? {
        builtIn.first { $0.id == id }
    }
}

/// Feature-category mode selected by the consuming app or SwiftASB defaults.
public enum SwiftASBFeatureMode: String, Sendable, Equatable {
    case disabled, enabled, readOnly
}

/// Feature sensitivity used by consuming apps when presenting category toggles.
public enum SwiftASBFeatureSensitivity: String, Sendable, Equatable {
    case readOnly, maintenance, mutation, highImpact
}

/// Event behavior SwiftASB should use for work in a feature category.
public enum SwiftASBFeatureEventPolicy: String, Sendable, Equatable {
    case quietReads, notifyOnMutation, requireExplicitAction
}

/// Host filesystem access declared by a consuming app.
public struct SwiftASBHostAccess: Sendable, Equatable {
    public var homeDirectoryReadWriteGranted: Bool
    public var homeDirectoryURL: URL?
    public var accessSource: AccessSource

    /// Creates a host access declaration.
    public init(
        homeDirectoryReadWriteGranted: Bool = false,
        homeDirectoryURL: URL? = nil,
        accessSource: AccessSource = .unknown
    ) {
        self.homeDirectoryReadWriteGranted = homeDirectoryReadWriteGranted
        self.homeDirectoryURL = homeDirectoryURL
        self.accessSource = accessSource
    }

    public static var unknown: Self {
        .init()
    }

    /// Declares an unsandboxed host application.
    public static func unsandboxed(homeDirectoryURL: URL? = nil) -> Self {
        .init(
            homeDirectoryReadWriteGranted: true,
            homeDirectoryURL: homeDirectoryURL,
            accessSource: .unsandboxed
        )
    }

    /// Declares broad user-granted home-directory access.
    public static func homeDirectoryReadWrite(
        url: URL,
        source: AccessSource
    ) -> Self {
        .init(
            homeDirectoryReadWriteGranted: true,
            homeDirectoryURL: url,
            accessSource: source
        )
    }

    /// Where the consuming app says its broad host access came from.
    public enum AccessSource: String, Sendable, Equatable {
        case declaredByHostApp
        case fullDiskAccess
        case securityScopedBookmark
        case unknown
        case unsandboxed
        case userSelectedDirectory
    }
}
