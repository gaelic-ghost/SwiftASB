import Foundation

/// App-server-owned extension, MCP, app, skill, plugin, and collaboration-mode surface.
public struct CodexExtensions: Sendable {
    let appServer: CodexAppServer

    init(appServer: CodexAppServer) {
        self.appServer = appServer
    }

    /// Install intent for one Codex extension family.
    public enum InstallRequest: Sendable, Equatable {
        case mcp(MCP.ServerDefinition)
    }

    /// Result returned after installing one Codex extension family item.
    public enum InstallResult: Sendable, Equatable {
        case mcp(MCP.InstallResult)
    }

    /// Installs one extension-family item through SwiftASB's preferred unified install surface.
    @discardableResult
    public func install(_ request: InstallRequest) async throws -> InstallResult {
        switch request {
        case let .mcp(definition):
            return .mcp(try await mcp.install(definition))
        }
    }

    /// App and connector inventory family.
    public struct Apps: Sendable {
        private let appServer: CodexAppServer

        init(appServer: CodexAppServer) {
            self.appServer = appServer
        }

        public func list(_ request: AppListRequest = .init()) async throws -> AppListPage {
            try await appServer.listExtensionApps(request)
        }
    }

    /// Skill inventory family.
    public struct Skills: Sendable {
        private let appServer: CodexAppServer

        init(appServer: CodexAppServer) {
            self.appServer = appServer
        }

        public func list(_ request: SkillListRequest = .init()) async throws -> SkillListSnapshot {
            try await appServer.listExtensionSkills(request)
        }
    }

    /// Plugin and marketplace inventory and maintenance family.
    public struct Plugins: Sendable {
        private let appServer: CodexAppServer

        init(appServer: CodexAppServer) {
            self.appServer = appServer
        }

        public func list(_ request: PluginListRequest = .init()) async throws -> PluginListSnapshot {
            try await appServer.listExtensionPlugins(request)
        }

        public func read(_ request: PluginReadRequest) async throws -> PluginDetail {
            try await appServer.readExtensionPlugin(request)
        }

        public func upgradeMarketplace(
            _ request: MarketplaceUpgradeRequest
        ) async throws -> MarketplaceUpgradeResult {
            try await appServer.upgradeExtensionMarketplace(request)
        }
    }

    /// Collaboration-mode inventory family.
    public struct CollaborationModes: Sendable {
        private let appServer: CodexAppServer

        init(appServer: CodexAppServer) {
            self.appServer = appServer
        }

        public func list() async throws -> CollaborationModeList {
            try await appServer.listExtensionCollaborationModes()
        }
    }

    /// MCP server configuration, status, and resource family.
    public var mcp: MCP {
        MCP(appServer: appServer)
    }

    /// App and connector inventory family.
    public var apps: Apps {
        Apps(appServer: appServer)
    }

    /// Skill inventory family.
    public var skills: Skills {
        Skills(appServer: appServer)
    }

    /// Plugin and marketplace inventory and maintenance family.
    public var plugins: Plugins {
        Plugins(appServer: appServer)
    }

    /// Collaboration-mode inventory family.
    public var collaborationModes: CollaborationModes {
        CollaborationModes(appServer: appServer)
    }

    /// Request used to list available apps and connectors.
    public struct AppListRequest: Sendable, Equatable {
        public var cursor: String?
        public var forceRefetch: Bool?
        public var limit: Int?
        public var threadID: String?

        public init(
            cursor: String? = nil,
            limit: Int? = nil,
            forceRefetch: Bool? = nil,
            threadID: String? = nil
        ) {
            self.cursor = cursor
            self.forceRefetch = forceRefetch
            self.limit = limit
            self.threadID = threadID
        }
    }

    /// One page of app or connector metadata.
    public struct AppListPage: Sendable, Equatable {
        public let apps: [AppInfo]
        public let nextCursor: String?
    }

    /// App or connector metadata returned by the app-server.
    public struct AppInfo: Sendable, Equatable, Identifiable {
        public let branding: AppBranding?
        public let categories: [String]?
        public let description: String?
        public let developer: String?
        public let distributionChannel: String?
        public let id: String
        public let installURL: String?
        public let isAccessible: Bool?
        public let isEnabled: Bool?
        public let labels: [String: String]?
        public let logoURL: String?
        public let logoURLDark: String?
        public let name: String
        public let pluginDisplayNames: [String]?
        public let screenshots: [AppScreenshot]?
        public let version: String?
        public let versionID: String?
        public let versionNotes: String?
    }

    public struct AppBranding: Sendable, Equatable {
        public let category: String?
        public let developer: String?
        public let isDiscoverableApp: Bool
        public let privacyPolicy: String?
        public let termsOfService: String?
        public let website: String?
    }

    public struct AppScreenshot: Sendable, Equatable {
        public let fileID: String?
        public let url: String?
        public let userPrompt: String
    }

    /// Request used to list skills visible from one or more working directories.
    public struct SkillListRequest: Sendable, Equatable {
        public struct ExtraUserRootsForCurrentDirectory: Sendable, Equatable {
            public var currentDirectoryPath: String
            public var extraUserRoots: [String]

            public init(currentDirectoryPath: String, extraUserRoots: [String]) {
                self.currentDirectoryPath = currentDirectoryPath
                self.extraUserRoots = extraUserRoots
            }
        }

        public var currentDirectoryPaths: [String]?
        public var forceReload: Bool?
        /// Deprecated by Codex CLI 0.130.0. The app-server no longer accepts
        /// per-cwd extra skill roots on `skills/list`.
        public var perCurrentDirectoryExtraUserRoots: [ExtraUserRootsForCurrentDirectory]?

        public init(
            currentDirectoryPaths: [String]? = nil,
            forceReload: Bool? = nil,
            perCurrentDirectoryExtraUserRoots: [ExtraUserRootsForCurrentDirectory]? = nil
        ) {
            self.currentDirectoryPaths = currentDirectoryPaths
            self.forceReload = forceReload
            self.perCurrentDirectoryExtraUserRoots = perCurrentDirectoryExtraUserRoots
        }
    }

    public struct SkillListSnapshot: Sendable, Equatable {
        public let entries: [SkillListEntry]
    }

    public struct SkillListEntry: Sendable, Equatable, Identifiable {
        public var id: String { currentDirectoryPath }

        public let currentDirectoryPath: String
        public let errors: [SkillError]
        public let skills: [SkillMetadata]
    }

    public struct SkillError: Sendable, Equatable {
        public let message: String
        public let path: String
    }

    public struct SkillMetadata: Sendable, Equatable, Identifiable {
        public enum Scope: String, Sendable, Equatable {
            case admin, repo, system, user
        }

        public var id: String { path }

        public let description: String
        public let displayName: String?
        public let enabled: Bool
        public let name: String
        public let path: String
        public let scope: Scope
        public let shortDescription: String?
    }

    public struct PluginListRequest: Sendable, Equatable {
        public var currentDirectoryPaths: [String]?

        public init(currentDirectoryPaths: [String]? = nil) {
            self.currentDirectoryPaths = currentDirectoryPaths
        }
    }

    public struct PluginListSnapshot: Sendable, Equatable {
        public let featuredPluginIDs: [String]
        public let marketplaceLoadErrors: [MarketplaceLoadError]
        public let marketplaces: [PluginMarketplace]
    }

    public struct MarketplaceLoadError: Sendable, Equatable {
        public let marketplacePath: String
        public let message: String
    }

    public struct PluginMarketplace: Sendable, Equatable, Identifiable {
        public var id: String { path ?? name }

        public let displayName: String?
        public let name: String
        public let path: String?
        public let plugins: [PluginSummary]
    }

    public struct PluginSummary: Sendable, Equatable, Identifiable {
        public enum AuthPolicy: String, Sendable, Equatable {
            case onInstall
            case onUse
        }

        public enum InstallPolicy: String, Sendable, Equatable {
            case available
            case installedByDefault
            case notAvailable
        }

        public enum SourceKind: String, Sendable, Equatable {
            case git
            case local
            case remote
        }

        public let authPolicy: AuthPolicy
        public let enabled: Bool
        public let id: String
        public let installed: Bool
        public let installPolicy: InstallPolicy
        public let interface: PluginInterface?
        public let name: String
        public let sourceKind: SourceKind
        public let sourcePath: String?
        public let sourceRefName: String?
        public let sourceSHA: String?
        public let sourceURL: String?
    }

    public struct PluginInterface: Sendable, Equatable {
        public let brandColor: String?
        public let capabilities: [String]
        public let category: String?
        public let defaultPrompt: [String]?
        public let developerName: String?
        public let displayName: String?
        public let longDescription: String?
        public let shortDescription: String?
    }

    public struct PluginReadRequest: Sendable, Equatable {
        public var marketplacePath: String?
        public var pluginName: String
        public var remoteMarketplaceName: String?

        public init(
            pluginName: String,
            marketplacePath: String? = nil,
            remoteMarketplaceName: String? = nil
        ) {
            self.marketplacePath = marketplacePath
            self.pluginName = pluginName
            self.remoteMarketplaceName = remoteMarketplaceName
        }
    }

    public struct MarketplaceUpgradeRequest: Sendable, Equatable {
        public var currentDirectoryPaths: [String]?
        public var marketplaceName: String
        public var timeoutMilliseconds: Int

        public init(
            marketplaceName: String,
            currentDirectoryPaths: [String]? = nil,
            timeoutMilliseconds: Int = 120_000
        ) {
            self.marketplaceName = marketplaceName
            self.currentDirectoryPaths = currentDirectoryPaths
            self.timeoutMilliseconds = max(1_000, timeoutMilliseconds)
        }
    }

    public struct MarketplaceUpgradeResult: Sendable, Equatable {
        public let command: [String]
        public let exitCode: Int
        public let marketplaceName: String
        public let operationID: String
        public let status: SwiftASBFeatureOperationEvent.Status
        public let stderr: String
        public let stdout: String
    }

    public struct PluginDetail: Sendable, Equatable {
        public let apps: [AppSummary]
        public let description: String?
        public let hooks: [PluginHookSummary]
        public let marketplaceName: String
        public let marketplacePath: String?
        public let mcpServers: [String]
        public let skills: [SkillSummary]
        public let summary: PluginSummary
    }

    public struct PluginHookSummary: Sendable, Equatable, Identifiable {
        public var id: String { key }

        public let eventName: CodexAppServer.HookMetadata.EventName
        public let key: String
    }

    public struct AppSummary: Sendable, Equatable, Identifiable {
        public let description: String?
        public let id: String
        public let installURL: String?
        public let name: String
        public let needsAuth: Bool
    }

    public struct SkillSummary: Sendable, Equatable, Identifiable {
        public var id: String { path ?? name }

        public let description: String
        public let displayName: String?
        public let enabled: Bool
        public let name: String
        public let path: String?
        public let shortDescription: String?
    }

    public struct CollaborationModeList: Sendable, Equatable {
        public let modes: [CollaborationMode]
    }

    public struct CollaborationMode: Sendable, Equatable, Identifiable {
        public enum Kind: String, Sendable, Equatable {
            case defaultMode = "default"
            case plan
        }

        public var id: String { name }

        public let kind: Kind?
        public let model: String?
        public let name: String
        public let reasoningEffort: CodexAppServer.ReasoningEffort?
    }

    @available(*, deprecated, message: "Use appServer.extensions.apps.list(...) instead.")
    public func listApps(_ request: AppListRequest = .init()) async throws -> AppListPage {
        try await apps.list(request)
    }

    @available(*, deprecated, message: "Use appServer.extensions.skills.list(...) instead.")
    public func listSkills(_ request: SkillListRequest = .init()) async throws -> SkillListSnapshot {
        try await skills.list(request)
    }

    @available(*, deprecated, message: "Use appServer.extensions.plugins.list(...) instead.")
    public func listPlugins(_ request: PluginListRequest = .init()) async throws -> PluginListSnapshot {
        try await plugins.list(request)
    }

    @available(*, deprecated, message: "Use appServer.extensions.plugins.read(...) instead.")
    public func readPlugin(_ request: PluginReadRequest) async throws -> PluginDetail {
        try await plugins.read(request)
    }

    /// Upgrades an already-configured plugin marketplace through Codex.
    ///
    /// SwiftASB preflights the marketplace through `plugin/list`, runs the
    /// installed Codex CLI's `plugin marketplace upgrade` command through
    /// app-server `command/exec`, and emits a feature-operation event. New
    /// marketplace installs and marketplace removals remain separate,
    /// stricter mutation categories.
    @available(*, deprecated, message: "Use appServer.extensions.plugins.upgradeMarketplace(...) instead.")
    public func upgradeMarketplace(
        _ request: MarketplaceUpgradeRequest
    ) async throws -> MarketplaceUpgradeResult {
        try await plugins.upgradeMarketplace(request)
    }

    @available(*, deprecated, message: "Use appServer.extensions.collaborationModes.list() instead.")
    public func listCollaborationModes() async throws -> CollaborationModeList {
        try await collaborationModes.list()
    }
}

public extension CodexAppServer {
    /// App-server-owned extension inventory surface.
    var extensions: SwiftASB.CodexExtensions {
        SwiftASB.CodexExtensions(appServer: self)
    }

    @available(*, deprecated, renamed: "CodexExtensions")
    typealias CodexExtensions = SwiftASB.CodexExtensions
}

extension CodexAppServer {
    func upgradeExtensionMarketplace(
        _ request: SwiftASB.CodexExtensions.MarketplaceUpgradeRequest
    ) async throws -> SwiftASB.CodexExtensions.MarketplaceUpgradeResult {
        try requireFeatureEnabled(.extensionMaintenance, for: "plugin marketplace upgrade")

        let marketplaceName = request.marketplaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !marketplaceName.isEmpty else {
            throw CodexAppServerError.invalidState(
                reason: "SwiftASB cannot upgrade a plugin marketplace without a marketplace name."
            )
        }

        let pluginSnapshot = try await listExtensionPlugins(
            .init(currentDirectoryPaths: request.currentDirectoryPaths)
        )
        guard let marketplace = pluginSnapshot.marketplaces.first(where: { $0.name == marketplaceName }) else {
            throw CodexAppServerError.invalidState(
                reason: """
                SwiftASB cannot upgrade plugin marketplace \(marketplaceName) because plugin/list did not report an existing marketplace with that name. \
                Refresh extension inventory and choose a configured marketplace before requesting maintenance.
                """
            )
        }

        let startedAt = Date()
        let operationID = "extension-maintenance:marketplace-upgrade:\(marketplaceName):\(UUID().uuidString)"
        let command = [
            await codexCommandExecutablePath(),
            "plugin",
            "marketplace",
            "upgrade",
            marketplaceName,
        ]
        let result = try await executeCommand(
            .init(
                command: command,
                outputBytesCap: 32_768,
                timeoutMilliseconds: request.timeoutMilliseconds
            )
        )
        let completedAt = Date()
        let status: SwiftASBFeatureOperationEvent.Status =
            result.exitCode == 0 ? .succeeded : .failed
        let affectedPaths = marketplace.path.map { [$0] } ?? []
        let summary: String
        if result.exitCode == 0 {
            summary = "Upgraded plugin marketplace \(marketplaceName)."
        } else {
            summary = "Plugin marketplace \(marketplaceName) upgrade exited with code \(result.exitCode)."
        }

        publishFeatureOperationEvent(
            .init(
                categoryID: .extensionMaintenance,
                operationID: operationID,
                title: "Upgrade plugin marketplace",
                summary: summary,
                reason: "Extension maintenance is enabled for already-configured plugin marketplaces.",
                startedAt: startedAt,
                completedAt: completedAt,
                affectedPaths: affectedPaths,
                commands: [
                    .init(argv: command)
                ],
                appServerMethod: "command/exec",
                intentKind: "extensionMarketplaceUpgrade",
                status: status,
                rollback: .unavailable,
                diagnosticText: result.exitCode == 0 ? nil : Self.commandDiagnosticText(result)
            )
        )

        return .init(
            command: command,
            exitCode: result.exitCode,
            marketplaceName: marketplaceName,
            operationID: operationID,
            status: status,
            stderr: result.stderr,
            stdout: result.stdout
        )
    }

    private static func commandDiagnosticText(_ result: CommandExecResult) -> String {
        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stderr.isEmpty {
            return stderr
        }

        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stdout.isEmpty {
            return stdout
        }

        return "The command exited with code \(result.exitCode) and did not report output."
    }
}

extension CodexExtensions.AppListPage {
    init(wireValue: CodexWireAppsListResponse) {
        self.init(
            apps: wireValue.data.map(CodexExtensions.AppInfo.init(wireValue:)),
            nextCursor: wireValue.nextCursor
        )
    }
}

extension CodexExtensions.AppInfo {
    init(wireValue: CodexWireAppInfo) {
        self.init(
            branding: wireValue.branding.map(CodexExtensions.AppBranding.init),
            categories: wireValue.appMetadata?.categories,
            description: wireValue.description,
            developer: wireValue.appMetadata?.developer,
            distributionChannel: wireValue.distributionChannel,
            id: wireValue.id,
            installURL: wireValue.installURL,
            isAccessible: wireValue.isAccessible,
            isEnabled: wireValue.isEnabled,
            labels: wireValue.labels,
            logoURL: wireValue.logoURL,
            logoURLDark: wireValue.logoURLDark,
            name: wireValue.name,
            pluginDisplayNames: wireValue.pluginDisplayNames,
            screenshots: wireValue.appMetadata?.screenshots?.map(CodexExtensions.AppScreenshot.init),
            version: wireValue.appMetadata?.version,
            versionID: wireValue.appMetadata?.versionID,
            versionNotes: wireValue.appMetadata?.versionNotes
        )
    }
}

extension CodexExtensions.AppBranding {
    init(wireValue: CodexWireAppBranding) {
        self.init(
            category: wireValue.category,
            developer: wireValue.developer,
            isDiscoverableApp: wireValue.isDiscoverableApp,
            privacyPolicy: wireValue.privacyPolicy,
            termsOfService: wireValue.termsOfService,
            website: wireValue.website
        )
    }
}

extension CodexExtensions.AppScreenshot {
    init(wireValue: CodexWireAppScreenshot) {
        self.init(fileID: wireValue.fileID, url: wireValue.url, userPrompt: wireValue.userPrompt)
    }
}

extension CodexExtensions.SkillListSnapshot {
    init(wireValue: CodexWireSkillsListResponse) {
        self.init(entries: wireValue.data.map(CodexExtensions.SkillListEntry.init))
    }
}

extension CodexExtensions.SkillListEntry {
    init(wireValue: CodexWireSkillsListEntry) {
        self.init(
            currentDirectoryPath: wireValue.cwd,
            errors: wireValue.errors.map(CodexExtensions.SkillError.init),
            skills: wireValue.skills.map(CodexExtensions.SkillMetadata.init)
        )
    }
}

extension CodexExtensions.SkillError {
    init(wireValue: CodexWireSkillErrorInfo) {
        self.init(message: wireValue.message, path: wireValue.path)
    }
}

extension CodexExtensions.SkillMetadata {
    init(wireValue: CodexWireSkillMetadata) {
        self.init(
            description: wireValue.description,
            displayName: wireValue.interface?.displayName,
            enabled: wireValue.enabled,
            name: wireValue.name,
            path: wireValue.path,
            scope: .init(wireValue: wireValue.scope),
            shortDescription: wireValue.interface?.shortDescription ?? wireValue.shortDescription
        )
    }
}

extension CodexExtensions.SkillMetadata.Scope {
    init(wireValue: CodexWireSkillScope) {
        switch wireValue {
        case .admin:
            self = .admin
        case .repo:
            self = .repo
        case .system:
            self = .system
        case .user:
            self = .user
        }
    }
}

extension CodexExtensions.PluginListSnapshot {
    init(wireValue: CodexWirePluginListResponse) {
        self.init(
            featuredPluginIDs: wireValue.featuredPluginIDS ?? [],
            marketplaceLoadErrors: (wireValue.marketplaceLoadErrors ?? []).map(
                CodexExtensions.MarketplaceLoadError.init
            ),
            marketplaces: wireValue.marketplaces.map(CodexExtensions.PluginMarketplace.init)
        )
    }
}

extension CodexExtensions.MarketplaceLoadError {
    init(wireValue: CodexWireMarketplaceLoadErrorInfo) {
        self.init(marketplacePath: wireValue.marketplacePath, message: wireValue.message)
    }
}

extension CodexExtensions.PluginMarketplace {
    init(wireValue: CodexWirePluginMarketplaceEntry) {
        self.init(
            displayName: wireValue.interface?.displayName,
            name: wireValue.name,
            path: wireValue.path,
            plugins: wireValue.plugins.map(CodexExtensions.PluginSummary.init)
        )
    }
}

extension CodexExtensions.PluginSummary {
    init(wireValue: CodexWirePluginSummary) {
        self.init(
            authPolicy: .init(wireValue: wireValue.authPolicy),
            enabled: wireValue.enabled,
            id: wireValue.id,
            installed: wireValue.installed,
            installPolicy: .init(wireValue: wireValue.installPolicy),
            interface: wireValue.interface.map(CodexExtensions.PluginInterface.init),
            name: wireValue.name,
            sourceKind: .init(wireValue: wireValue.source.type),
            sourcePath: wireValue.source.path,
            sourceRefName: wireValue.source.refName,
            sourceSHA: wireValue.source.sha,
            sourceURL: wireValue.source.url
        )
    }
}

extension CodexExtensions.PluginSummary.AuthPolicy {
    init(wireValue: CodexWirePluginAuthPolicy) {
        switch wireValue {
        case .onInstall:
            self = .onInstall
        case .onUse:
            self = .onUse
        }
    }
}

extension CodexExtensions.PluginSummary.InstallPolicy {
    init(wireValue: CodexWirePluginInstallPolicy) {
        switch wireValue {
        case .available:
            self = .available
        case .installedByDefault:
            self = .installedByDefault
        case .notAvailable:
            self = .notAvailable
        }
    }
}

extension CodexExtensions.PluginSummary.SourceKind {
    init(wireValue: CodexWirePluginSourceType) {
        switch wireValue {
        case .git:
            self = .git
        case .local:
            self = .local
        case .remote:
            self = .remote
        }
    }
}

extension CodexExtensions.PluginInterface {
    init(wireValue: CodexWirePluginInterface) {
        self.init(
            brandColor: wireValue.brandColor,
            capabilities: wireValue.capabilities,
            category: wireValue.category,
            defaultPrompt: wireValue.defaultPrompt,
            developerName: wireValue.developerName,
            displayName: wireValue.displayName,
            longDescription: wireValue.longDescription,
            shortDescription: wireValue.shortDescription
        )
    }
}

extension CodexExtensions.PluginDetail {
    init(wireValue: CodexWirePluginDetail) {
        self.init(
            apps: wireValue.apps.map(CodexExtensions.AppSummary.init),
            description: wireValue.description,
            hooks: wireValue.hooks.map(CodexExtensions.PluginHookSummary.init),
            marketplaceName: wireValue.marketplaceName,
            marketplacePath: wireValue.marketplacePath,
            mcpServers: wireValue.mcpServers,
            skills: wireValue.skills.map(CodexExtensions.SkillSummary.init),
            summary: .init(wireValue: wireValue.summary)
        )
    }
}

extension CodexExtensions.PluginHookSummary {
    init(wireValue: CodexWirePluginHookSummary) {
        self.init(
            eventName: .init(wireValue: wireValue.eventName),
            key: wireValue.key
        )
    }
}

extension CodexAppServer.HookMetadata.EventName {
    init(wireValue: CodexWireHookEventName) {
        switch wireValue {
        case .permissionRequest:
            self = .permissionRequest
        case .postCompact:
            self = .postCompact
        case .postToolUse:
            self = .postToolUse
        case .preCompact:
            self = .preCompact
        case .preToolUse:
            self = .preToolUse
        case .sessionStart:
            self = .sessionStart
        case .stop:
            self = .stop
        case .subagentStart:
            self = .subagentStart
        case .subagentStop:
            self = .subagentStop
        case .userPromptSubmit:
            self = .userPromptSubmit
        }
    }
}

extension CodexExtensions.AppSummary {
    init(wireValue: CodexWireAppSummary) {
        self.init(
            description: wireValue.description,
            id: wireValue.id,
            installURL: wireValue.installURL,
            name: wireValue.name,
            needsAuth: wireValue.needsAuth
        )
    }
}

extension CodexExtensions.SkillSummary {
    init(wireValue: CodexWireSkillSummary) {
        self.init(
            description: wireValue.description,
            displayName: wireValue.interface?.displayName,
            enabled: wireValue.enabled,
            name: wireValue.name,
            path: wireValue.path,
            shortDescription: wireValue.interface?.shortDescription ?? wireValue.shortDescription
        )
    }
}

extension CodexExtensions.CollaborationModeList {
    init(wireValue: CodexWireCollaborationModeListResponse) {
        self.init(modes: wireValue.data.map(CodexExtensions.CollaborationMode.init))
    }
}

extension CodexExtensions.CollaborationMode {
    init(wireValue: CodexWireCollaborationModeMask) {
        self.init(
            kind: wireValue.mode.map(Kind.init),
            model: wireValue.model,
            name: wireValue.name,
            reasoningEffort: wireValue.reasoningEffort.map {
                CodexAppServer.ReasoningEffort(wireValue: $0)
            }
        )
    }
}

extension CodexExtensions.CollaborationMode.Kind {
    init(wireValue: CodexWireModeKind) {
        switch wireValue {
        case .modeKindDefault:
            self = .defaultMode
        case .plan:
            self = .plan
        }
    }
}
