import Foundation
import Observation

private func snapshotResult<Value: Sendable>(
    _ operation: @Sendable () async throws -> Value
) async -> Result<Value, Error> {
    do {
        return .success(try await operation())
    } catch {
        return .failure(error)
    }
}

extension CodexAppServer {
    internal struct AppInventoryReadRequest: Sendable, Equatable {
        var appListLimit: Int?
        var extensionCurrentDirectoryPaths: [String]?
        var hookListCurrentDirectoryPaths: [String]?
        var includesExtensions: Bool

        init(
            appListLimit: Int? = nil,
            extensionCurrentDirectoryPaths: [String]? = nil,
            hookListCurrentDirectoryPaths: [String]? = nil,
            includesExtensions: Bool = true
        ) {
            self.appListLimit = appListLimit.map { max(1, $0) }
            self.extensionCurrentDirectoryPaths = extensionCurrentDirectoryPaths
            self.hookListCurrentDirectoryPaths = hookListCurrentDirectoryPaths
            self.includesExtensions = includesExtensions
        }
    }

    internal struct AppInventorySnapshot: Sendable, Equatable {
        var appListPage: SwiftASB.CodexExtensions.AppListPage?
        var collaborationModes: SwiftASB.CodexExtensions.CollaborationModeList?
        var errorDescriptions: [String] = []
        var hookListSnapshot: HookListSnapshot?
        var mcpServerStatusPage: McpServerStatusPage?
        var modelCapabilities: ModelCapabilities?
        var pluginListSnapshot: SwiftASB.CodexExtensions.PluginListSnapshot?
        var skillListSnapshot: SwiftASB.CodexExtensions.SkillListSnapshot?

        var succeededCompletely: Bool {
            errorDescriptions.isEmpty
        }
    }

    internal func readAppInventorySnapshot(
        _ request: AppInventoryReadRequest
    ) async -> AppInventorySnapshot {
        async let capabilitiesResult = snapshotResult {
            try await readModelCapabilities()
        }
        async let mcpResult = snapshotResult {
            try await refreshGlobalMcpServerStatusSnapshot()
        }
        async let hooksResult = snapshotResult {
            try await listHooks(
                .init(currentDirectoryPaths: request.hookListCurrentDirectoryPaths)
            )
        }
        async let appsResult = request.includesExtensions
            ? snapshotResult {
                try await listExtensionApps(
                    .init(limit: request.appListLimit)
                )
            }
            : .success(nil)
        async let skillsResult = request.includesExtensions
            ? snapshotResult {
                try await listExtensionSkills(
                    .init(currentDirectoryPaths: request.extensionCurrentDirectoryPaths)
                )
            }
            : .success(nil)
        async let pluginsResult = request.includesExtensions
            ? snapshotResult {
                try await listExtensionPlugins(
                    .init(currentDirectoryPaths: request.extensionCurrentDirectoryPaths)
                )
            }
            : .success(nil)
        async let modesResult = request.includesExtensions
            ? snapshotResult {
                try await listExtensionCollaborationModes()
            }
            : .success(nil)

        let results = await (
            capabilities: capabilitiesResult,
            mcp: mcpResult,
            hooks: hooksResult,
            apps: appsResult,
            skills: skillsResult,
            plugins: pluginsResult,
            modes: modesResult
        )

        var snapshot = AppInventorySnapshot()
        snapshot.apply(results.capabilities, to: \.modelCapabilities)
        snapshot.apply(results.mcp, to: \.mcpServerStatusPage)
        snapshot.apply(results.hooks, to: \.hookListSnapshot)
        snapshot.apply(results.apps, to: \.appListPage)
        snapshot.apply(results.skills, to: \.skillListSnapshot)
        snapshot.apply(results.plugins, to: \.pluginListSnapshot)
        snapshot.apply(results.modes, to: \.collaborationModes)
        return snapshot
    }
}

private extension CodexAppServer.AppInventorySnapshot {
    mutating func apply<Value>(
        _ result: Result<Value, Error>,
        to keyPath: WritableKeyPath<Self, Value?>
    ) {
        switch result {
        case let .success(value):
            self[keyPath: keyPath] = value
        case let .failure(error):
            errorDescriptions.append(error.localizedDescription)
        }
    }

    mutating func apply<Value>(
        _ result: Result<Value?, Error>,
        to keyPath: WritableKeyPath<Self, Value?>
    ) {
        switch result {
        case let .success(value):
            self[keyPath: keyPath] = value
        case let .failure(error):
            errorDescriptions.append(error.localizedDescription)
        }
    }
}

public extension CodexExtensions {
    @MainActor
    @Observable
    final class Inventory {
        public struct Configuration: Sendable, Equatable {
            public var appListLimit: Int?
            public var extensionCurrentDirectoryPaths: [String]?
            public var hookListCurrentDirectoryPaths: [String]?
            public var loadsOnCreation: Bool

            public init(
                loadsOnCreation: Bool = true,
                hookListCurrentDirectoryPaths: [String]? = nil,
                extensionCurrentDirectoryPaths: [String]? = nil,
                appListLimit: Int? = nil
            ) {
                self.loadsOnCreation = loadsOnCreation
                self.hookListCurrentDirectoryPaths = hookListCurrentDirectoryPaths
                self.extensionCurrentDirectoryPaths = extensionCurrentDirectoryPaths
                self.appListLimit = appListLimit.map { max(1, $0) }
            }
        }

        public enum Phase: String, Sendable, Equatable {
            case idle
            case loading
        }

        public private(set) var appListPage: SwiftASB.CodexExtensions.AppListPage?
        public private(set) var collaborationModes: SwiftASB.CodexExtensions.CollaborationModeList?
        public private(set) var hookListSnapshot: CodexAppServer.HookListSnapshot?
        public private(set) var lastRefreshedAt: Date?
        public private(set) var latestErrorDescription: String?
        public private(set) var mcpServerNextCursor: String?
        public private(set) var mcpServers: [CodexAppServer.McpServerSummary]
        public private(set) var modelCapabilities: CodexAppServer.ModelCapabilities?
        public private(set) var phase: Phase
        public private(set) var pluginListSnapshot: SwiftASB.CodexExtensions.PluginListSnapshot?
        public private(set) var skillListSnapshot: SwiftASB.CodexExtensions.SkillListSnapshot?

        public var apps: [SwiftASB.CodexExtensions.AppInfo] {
            appListPage?.apps ?? []
        }

        public var skillEntries: [SwiftASB.CodexExtensions.SkillListEntry] {
            skillListSnapshot?.entries ?? []
        }

        public var skills: [SwiftASB.CodexExtensions.SkillMetadata] {
            skillEntries.flatMap(\.skills)
        }

        public var pluginMarketplaces: [SwiftASB.CodexExtensions.PluginMarketplace] {
            pluginListSnapshot?.marketplaces ?? []
        }

        public var collaborationModeEntries: [SwiftASB.CodexExtensions.CollaborationMode] {
            collaborationModes?.modes ?? []
        }

        @ObservationIgnored
        private let appServer: CodexAppServer

        @ObservationIgnored
        private let configuration: Configuration

        @ObservationIgnored
        private var eventTask: Task<Void, Never>?

        @ObservationIgnored
        private var refreshTask: Task<Void, Never>?

        @ObservationIgnored
        private var pendingRefresh = false

        internal init(
            appServer: CodexAppServer,
            configuration: Configuration
        ) {
            self.appServer = appServer
            self.configuration = configuration
            self.appListPage = nil
            self.collaborationModes = nil
            self.hookListSnapshot = nil
            self.lastRefreshedAt = nil
            self.latestErrorDescription = nil
            self.mcpServerNextCursor = nil
            self.mcpServers = []
            self.modelCapabilities = nil
            self.phase = .idle
            self.pluginListSnapshot = nil
            self.skillListSnapshot = nil

            if configuration.loadsOnCreation {
                refreshTask = Task { [weak self] in await self?.refresh() }
            }
            startEventTask()
        }

        deinit {
            eventTask?.cancel()
            refreshTask?.cancel()
        }

        public func refresh() async {
            if phase == .loading {
                pendingRefresh = true
                return
            }

            repeat {
                pendingRefresh = false
                await loadOnce()
            } while pendingRefresh
        }

        private func loadOnce() async {
            phase = .loading
            latestErrorDescription = nil

            let snapshot = await appServer.readAppInventorySnapshot(
                .init(
                    appListLimit: configuration.appListLimit,
                    extensionCurrentDirectoryPaths: configuration.extensionCurrentDirectoryPaths,
                    hookListCurrentDirectoryPaths: configuration.hookListCurrentDirectoryPaths,
                    includesExtensions: true
                )
            )

            if let modelCapabilities = snapshot.modelCapabilities {
                self.modelCapabilities = modelCapabilities
            }
            if let page = snapshot.mcpServerStatusPage {
                mcpServers = page.servers.map { status in
                    .init(status: status, scope: .global)
                }
                mcpServerNextCursor = page.nextCursor
            }
            if let hookListSnapshot = snapshot.hookListSnapshot {
                self.hookListSnapshot = hookListSnapshot
            }
            if let appListPage = snapshot.appListPage {
                self.appListPage = appListPage
            }
            if let skillListSnapshot = snapshot.skillListSnapshot {
                self.skillListSnapshot = skillListSnapshot
            }
            if let pluginListSnapshot = snapshot.pluginListSnapshot {
                self.pluginListSnapshot = pluginListSnapshot
            }
            if let collaborationModes = snapshot.collaborationModes {
                self.collaborationModes = collaborationModes
            }

            if snapshot.succeededCompletely {
                lastRefreshedAt = Date()
                latestErrorDescription = nil
            } else {
                latestErrorDescription = snapshot.errorDescriptions.joined(separator: "\n")
            }

            phase = .idle
        }

        private func startEventTask() {
            eventTask = Task { [weak self] in
                guard let self else { return }
                let events = await appServer.libraryEvents()
                for await event in events {
                    if Task.isCancelled {
                        return
                    }
                    if event == .appSnapshotsChanged {
                        await refresh()
                    }
                }
            }
        }
    }

    @MainActor
    func makeInventory(
        configuration: Inventory.Configuration = .init()
    ) async throws -> Inventory {
        Inventory(appServer: appServer, configuration: configuration)
    }
}

public extension CodexAppServer {
    @available(*, deprecated, renamed: "CodexExtensions.Inventory")
    typealias Inventory = SwiftASB.CodexExtensions.Inventory

    @available(*, deprecated, message: "Use appServer.extensions.makeInventory(configuration:) instead.")
    @MainActor
    func makeInventory(
        configuration: Inventory.Configuration = .init()
    ) async throws -> Inventory {
        try await extensions.makeInventory(configuration: configuration)
    }
}
