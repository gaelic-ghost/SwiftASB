import Foundation

public extension CodexAppServer {
    /// App-server-owned extension inventory for apps, skills, plugins, and collaboration modes.
    struct CodexExtensions: Sendable {
        private let appServer: CodexAppServer

        init(appServer: CodexAppServer) {
            self.appServer = appServer
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

            public let eventName: HookMetadata.EventName
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
            public let reasoningEffort: ReasoningEffort?
        }

        public func listApps(_ request: AppListRequest = .init()) async throws -> AppListPage {
            try await appServer.listExtensionApps(request)
        }

        public func listSkills(_ request: SkillListRequest = .init()) async throws -> SkillListSnapshot {
            try await appServer.listExtensionSkills(request)
        }

        public func listPlugins(_ request: PluginListRequest = .init()) async throws -> PluginListSnapshot {
            try await appServer.listExtensionPlugins(request)
        }

        public func readPlugin(_ request: PluginReadRequest) async throws -> PluginDetail {
            try await appServer.readExtensionPlugin(request)
        }

        /// Upgrades an already-configured plugin marketplace through Codex.
        ///
        /// SwiftASB preflights the marketplace through `plugin/list`, runs the
        /// installed Codex CLI's `plugin marketplace upgrade` command through
        /// app-server `command/exec`, and emits a feature-operation event. New
        /// marketplace installs and marketplace removals remain separate,
        /// stricter mutation categories.
        public func upgradeMarketplace(
            _ request: MarketplaceUpgradeRequest
        ) async throws -> MarketplaceUpgradeResult {
            try await appServer.upgradeExtensionMarketplace(request)
        }

        public func listCollaborationModes() async throws -> CollaborationModeList {
            try await appServer.listExtensionCollaborationModes()
        }
    }

    /// App-server-owned extension inventory surface.
    var extensions: CodexExtensions {
        CodexExtensions(appServer: self)
    }
}

extension CodexAppServer {
    func upgradeExtensionMarketplace(
        _ request: CodexExtensions.MarketplaceUpgradeRequest
    ) async throws -> CodexExtensions.MarketplaceUpgradeResult {
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

extension CodexAppServer.CodexExtensions.AppListPage {
    init(wireValue: CodexWireAppsListResponse) {
        self.init(
            apps: wireValue.data.map(CodexAppServer.CodexExtensions.AppInfo.init(wireValue:)),
            nextCursor: wireValue.nextCursor
        )
    }
}

extension CodexAppServer.CodexExtensions.AppInfo {
    init(wireValue: CodexWireAppInfo) {
        self.init(
            branding: wireValue.branding.map(CodexAppServer.CodexExtensions.AppBranding.init),
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
            screenshots: wireValue.appMetadata?.screenshots?.map(CodexAppServer.CodexExtensions.AppScreenshot.init),
            version: wireValue.appMetadata?.version,
            versionID: wireValue.appMetadata?.versionID,
            versionNotes: wireValue.appMetadata?.versionNotes
        )
    }
}

extension CodexAppServer.CodexExtensions.AppBranding {
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

extension CodexAppServer.CodexExtensions.AppScreenshot {
    init(wireValue: CodexWireAppScreenshot) {
        self.init(fileID: wireValue.fileID, url: wireValue.url, userPrompt: wireValue.userPrompt)
    }
}

extension CodexAppServer.CodexExtensions.SkillListSnapshot {
    init(wireValue: CodexWireSkillsListResponse) {
        self.init(entries: wireValue.data.map(CodexAppServer.CodexExtensions.SkillListEntry.init))
    }
}

extension CodexAppServer.CodexExtensions.SkillListEntry {
    init(wireValue: CodexWireSkillsListEntry) {
        self.init(
            currentDirectoryPath: wireValue.cwd,
            errors: wireValue.errors.map(CodexAppServer.CodexExtensions.SkillError.init),
            skills: wireValue.skills.map(CodexAppServer.CodexExtensions.SkillMetadata.init)
        )
    }
}

extension CodexAppServer.CodexExtensions.SkillError {
    init(wireValue: CodexWireSkillErrorInfo) {
        self.init(message: wireValue.message, path: wireValue.path)
    }
}

extension CodexAppServer.CodexExtensions.SkillMetadata {
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

extension CodexAppServer.CodexExtensions.SkillMetadata.Scope {
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

extension CodexAppServer.CodexExtensions.PluginListSnapshot {
    init(wireValue: CodexWirePluginListResponse) {
        self.init(
            featuredPluginIDs: wireValue.featuredPluginIDS ?? [],
            marketplaceLoadErrors: (wireValue.marketplaceLoadErrors ?? []).map(
                CodexAppServer.CodexExtensions.MarketplaceLoadError.init
            ),
            marketplaces: wireValue.marketplaces.map(CodexAppServer.CodexExtensions.PluginMarketplace.init)
        )
    }
}

extension CodexAppServer.CodexExtensions.MarketplaceLoadError {
    init(wireValue: CodexWireMarketplaceLoadErrorInfo) {
        self.init(marketplacePath: wireValue.marketplacePath, message: wireValue.message)
    }
}

extension CodexAppServer.CodexExtensions.PluginMarketplace {
    init(wireValue: CodexWirePluginMarketplaceEntry) {
        self.init(
            displayName: wireValue.interface?.displayName,
            name: wireValue.name,
            path: wireValue.path,
            plugins: wireValue.plugins.map(CodexAppServer.CodexExtensions.PluginSummary.init)
        )
    }
}

extension CodexAppServer.CodexExtensions.PluginSummary {
    init(wireValue: CodexWirePluginSummary) {
        self.init(
            authPolicy: .init(wireValue: wireValue.authPolicy),
            enabled: wireValue.enabled,
            id: wireValue.id,
            installed: wireValue.installed,
            installPolicy: .init(wireValue: wireValue.installPolicy),
            interface: wireValue.interface.map(CodexAppServer.CodexExtensions.PluginInterface.init),
            name: wireValue.name,
            sourceKind: .init(wireValue: wireValue.source.type),
            sourcePath: wireValue.source.path,
            sourceRefName: wireValue.source.refName,
            sourceSHA: wireValue.source.sha,
            sourceURL: wireValue.source.url
        )
    }
}

extension CodexAppServer.CodexExtensions.PluginSummary.AuthPolicy {
    init(wireValue: CodexWirePluginAuthPolicy) {
        switch wireValue {
        case .onInstall:
            self = .onInstall
        case .onUse:
            self = .onUse
        }
    }
}

extension CodexAppServer.CodexExtensions.PluginSummary.InstallPolicy {
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

extension CodexAppServer.CodexExtensions.PluginSummary.SourceKind {
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

extension CodexAppServer.CodexExtensions.PluginInterface {
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

extension CodexAppServer.CodexExtensions.PluginDetail {
    init(wireValue: CodexWirePluginDetail) {
        self.init(
            apps: wireValue.apps.map(CodexAppServer.CodexExtensions.AppSummary.init),
            description: wireValue.description,
            hooks: wireValue.hooks.map(CodexAppServer.CodexExtensions.PluginHookSummary.init),
            marketplaceName: wireValue.marketplaceName,
            marketplacePath: wireValue.marketplacePath,
            mcpServers: wireValue.mcpServers,
            skills: wireValue.skills.map(CodexAppServer.CodexExtensions.SkillSummary.init),
            summary: .init(wireValue: wireValue.summary)
        )
    }
}

extension CodexAppServer.CodexExtensions.PluginHookSummary {
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

extension CodexAppServer.CodexExtensions.AppSummary {
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

extension CodexAppServer.CodexExtensions.SkillSummary {
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

extension CodexAppServer.CodexExtensions.CollaborationModeList {
    init(wireValue: CodexWireCollaborationModeListResponse) {
        self.init(modes: wireValue.data.map(CodexAppServer.CodexExtensions.CollaborationMode.init))
    }
}

extension CodexAppServer.CodexExtensions.CollaborationMode {
    init(wireValue: CodexWireCollaborationModeMask) {
        self.init(
            kind: wireValue.mode.map(Kind.init),
            model: wireValue.model,
            name: wireValue.name,
            reasoningEffort: wireValue.reasoningEffort.map(CodexAppServer.ReasoningEffort.init)
        )
    }
}

extension CodexAppServer.CodexExtensions.CollaborationMode.Kind {
    init(wireValue: CodexWireModeKind) {
        switch wireValue {
        case .modeKindDefault:
            self = .defaultMode
        case .plan:
            self = .plan
        }
    }
}
