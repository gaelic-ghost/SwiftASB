import Foundation
import Testing
@testable import SwiftASB

extension CodexAppServerTests {
    @Test("CodexFS routes read-only filesystem requests through the app-server")
    func codexFSRoutesReadOnlyRequestsThroughAppServer() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()
        _ = try await client.initialize(
            .init(
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        let metadata = try await client.fs.readMetadata(.init(path: "/tmp/project"))
        #expect(metadata.createdAtMilliseconds == 1_713_350_000_000)
        #expect(metadata.modifiedAtMilliseconds == 1_713_350_005_000)
        #expect(metadata.isDirectory)
        #expect(metadata.isFile == false)
        #expect(metadata.isSymbolicLink == false)

        let directory = try await client.fs.readDirectory(.init(path: "/tmp/project"))
        #expect(directory.entries.map(\.fileName) == ["Sources", "Package.swift", ".build"])
        #expect(directory.entries.map(\.kind) == [.directory, .file, .directory])

        let file = try await client.fs.readFile(.init(path: "/tmp/project/README.md"))
        #expect(String(data: file.data, encoding: .utf8) == "hello from CodexFS")

        let metadataRequest = try #require(await transport.recordedRequestPayload(for: "fs/getMetadata"))
        #expect(value(at: ["params", "path"], in: try decodedJSONObject(from: metadataRequest)) as? String == "/tmp/project")

        let directoryRequest = try #require(await transport.recordedRequestPayload(for: "fs/readDirectory"))
        #expect(value(at: ["params", "path"], in: try decodedJSONObject(from: directoryRequest)) as? String == "/tmp/project")

        let fileRequest = try #require(await transport.recordedRequestPayload(for: "fs/readFile"))
        #expect(value(at: ["params", "path"], in: try decodedJSONObject(from: fileRequest)) as? String == "/tmp/project/README.md")

        await client.stop()
    }

    @Test("CodexFS discovers files through app-server directory reads")
    func codexFSDiscoversFilesThroughAppServerDirectoryReads() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()
        _ = try await client.initialize(
            .init(
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        let descriptor = CodexFS.FileDiscoveryQD
            .files(under: "/tmp/project", matching: "cxfs", limit: 0, maximumDepth: 3)
            .limited(to: 2)

        #expect(descriptor.limit == 2)
        #expect(descriptor.searchTerm == "cxfs")
        #expect(descriptor.includedKinds == [.file])

        let result = try await client.fs.discoverFiles(descriptor)

        #expect(result.hits.map(\.relativePath) == ["Sources/SwiftASB/CodexFS.swift"])
        #expect(result.hits.first?.path == "/tmp/project/Sources/SwiftASB/CodexFS.swift")
        #expect(result.hits.first?.kind == .file)
        #expect(result.hits.first?.depth == 2)
        #expect(result.hits.first?.matchKind == .subsequence)
        #expect(result.hits.first?.matchedFileNameRanges == [
            .init(length: 1, start: 0),
            .init(length: 3, start: 4),
        ])
        #expect(result.hits.first?.matchedRelativePathRanges == [
            .init(length: 1, start: 4),
            .init(length: 3, start: 21),
        ])
        #expect(result.hits.first?.rankingReasons.map(\.kind).contains(.relativePathSubsequence) == true)
        #expect(result.hits.first?.rankingReasons.map(\.kind).contains(.fileNameSubsequence) == true)
        #expect(result.hits.first?.score != nil)

        let directoryRequests = await transport.requestPayloads(for: "fs/readDirectory")
        let directoryPaths = try directoryRequests.map {
            value(at: ["params", "path"], in: try decodedJSONObject(from: $0)) as? String
        }
        #expect(directoryPaths.contains("/tmp/project"))
        #expect(directoryPaths.contains("/tmp/project/Sources"))
        #expect(directoryPaths.contains("/tmp/project/Sources/SwiftASB"))
        #expect(directoryPaths.contains("/tmp/project/.build") == false)

        await client.stop()
    }

    @Test("CodexFS file discovery descriptors cover depth, hidden, and no-match cases")
    func codexFSFileDiscoveryDescriptorsCoverBoundaryCases() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()
        _ = try await client.initialize(
            .init(
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        let rootFiles = try await client.fs.discoverFiles(
            .files(under: "/tmp/project", limit: 0, maximumDepth: -1)
        )
        #expect(rootFiles.hits.map(\.relativePath) == ["Package.swift"])
        #expect(rootFiles.hits.first?.depth == 0)

        let visibleEntries = try await client.fs.discoverFiles(
            .entries(under: "/tmp/project", limit: 10, maximumDepth: 1)
        )
        #expect(visibleEntries.hits.map(\.relativePath) == [
            "Package.swift",
            "Sources",
            "Sources/SwiftASB",
            "Sources/SwiftASBTests.swift",
        ])
        #expect(visibleEntries.hits.map(\.kind) == [.file, .directory, .directory, .file])

        let hiddenEntries = try await client.fs.discoverFiles(
            CodexFS.FileDiscoveryQD
                .entries(under: "/tmp/project", matching: "cfs", limit: 10, maximumDepth: 3)
                .includingHiddenEntries()
        )
        #expect(hiddenEntries.hits.map(\.relativePath) == [
            "Sources/SwiftASB/CodexFS.swift",
            "Sources/SwiftASB",
            "Sources/SwiftASBTests.swift",
            "Sources/SwiftASB/CodexAppServer.swift",
            ".build/debug/CodexFS.o",
        ])
        #expect(hiddenEntries.hits.map(\.kind) == [.file, .directory, .file, .file, .file])
        #expect(hiddenEntries.hits.first?.matchKind == .subsequence)
        #expect(hiddenEntries.hits.first?.matchedFileNameRanges == [
            .init(length: 1, start: 0),
            .init(length: 2, start: 5),
        ])
        #expect(
            hiddenEntries.hits.last?.rankingReasons.contains(.init(kind: .generatedPathPenalty, value: -105)) == true
        )

        let noMatches = try await client.fs.discoverFiles(
            .files(under: "/tmp/project", matching: "definitely-not-here", limit: 10, maximumDepth: 3)
        )
        #expect(noMatches.hits.isEmpty)

        await client.stop()
    }

    @Test("lists app-server loaded thread ids")
    func listsAppServerLoadedThreadIDs() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()
        _ = try await client.initialize(
            .init(
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        let loaded = try await client.listLoadedThreads(.init(cursor: "loaded-cursor", limit: 2))
        #expect(loaded.threadIDs == ["thread-123", "thread-456"])
        #expect(loaded.nextCursor == "cursor-loaded-next")

        let requestPayload = try #require(await transport.recordedRequestPayload(for: "thread/loaded/list"))
        let request = try decodedJSONObject(from: requestPayload)
        #expect(value(at: ["params", "cursor"], in: request) as? String == "loaded-cursor")
        #expect(value(at: ["params", "limit"], in: request) as? Int == 2)

        await client.stop()
    }

    @Test("CodexFS streams filesystem watch notifications")
    func codexFSStreamsFilesystemWatchNotifications() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()
        _ = try await client.initialize(
            .init(
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        let watch = try await client.fs.watch(.init(path: "/tmp/project", watchID: "watch-123"))
        #expect(watch.path == "/tmp/project")
        #expect(watch.watchID == "watch-123")

        let watchRequest = try #require(await transport.recordedRequestPayload(for: "fs/watch"))
        let watchRequestJSON = try decodedJSONObject(from: watchRequest)
        #expect(value(at: ["params", "path"], in: watchRequestJSON) as? String == "/tmp/project")
        #expect(value(at: ["params", "watchId"], in: watchRequestJSON) as? String == "watch-123")

        let eventTask = Task {
            var iterator = watch.events.makeAsyncIterator()
            return await iterator.next()
        }

        await transport.emitFSChanged(watchID: "watch-123", changedPaths: ["/tmp/project/README.md"])
        let event = try #require(await eventTask.value)
        #expect(event.watchID == "watch-123")
        #expect(event.changedPaths == ["/tmp/project/README.md"])

        try await client.fs.unwatch(.init(watchID: "watch-123"))
        let unwatchRequest = try #require(await transport.recordedRequestPayload(for: "fs/unwatch"))
        #expect(value(at: ["params", "watchId"], in: try decodedJSONObject(from: unwatchRequest)) as? String == "watch-123")

        await client.stop()
    }

    @Test("CodexConfig reads effective config and requirements through the app-server")
    func codexConfigReadsEffectiveConfigAndRequirements() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()
        _ = try await client.initialize(
            .init(
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        let snapshot = try await client.config.read(.init(currentDirectoryPath: "/tmp/project", includeLayers: true))
        #expect(snapshot.config == .object(["model": .string("gpt-5.2"), "sandbox_mode": .string("workspace-write")]))
        #expect(snapshot.layers?.count == 3)
        #expect(snapshot.layers?.first?.name.kind == .user)
        #expect(snapshot.layers?[1].name.kind == .project)
        #expect(snapshot.layers?[1].name.dotCodexFolder == "/tmp/project/.codex")
        #expect(snapshot.layers?[1].disabledReason == "Project config is disabled for this fixture.")
        #expect(snapshot.layers?[2].name.kind == .enterpriseManaged)
        #expect(snapshot.layers?[2].name.id == "enterprise-layer-1")
        #expect(snapshot.layers?[2].name.name == "Admin Defaults")
        #expect(snapshot.origins["model"]?.name.file == "/Users/galew/.codex/config.toml")
        #expect(snapshot.origins["sandbox_mode"]?.name.kind == .project)
        #expect(snapshot.origins["review_model"]?.name.kind == .enterpriseManaged)
        #expect(snapshot.origins["review_model"]?.name.name == "Admin Defaults")

        let requirements = try await client.config.readRequirements()
        #expect(requirements.requirements == .object([
            "featureRequirements": .object([
                "network_access": .bool(true),
            ]),
        ]))

        let configRequest = try #require(await transport.recordedRequestPayload(for: "config/read"))
        let configRequestJSON = try decodedJSONObject(from: configRequest)
        #expect(value(at: ["params", "cwd"], in: configRequestJSON) as? String == "/tmp/project")
        #expect(value(at: ["params", "includeLayers"], in: configRequestJSON) as? Bool == true)

        let requirementsRequest = try #require(await transport.recordedRequestPayload(for: "configRequirements/read"))
        let requirementsRequestJSON = try decodedJSONObject(from: requirementsRequest)
        #expect(requirementsRequestJSON["params"] == nil)

        await client.stop()
    }

    @Test("CodexExtensions lists app-server extension inventory")
    func codexExtensionsListAppServerExtensionInventory() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()
        _ = try await client.initialize(
            .init(
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        let apps = try await client.extensions.apps.list(.init(cursor: "apps-cursor", limit: 1, forceRefetch: true, threadID: "thread-123"))
        #expect(apps.apps.map(\.name) == ["GitHub"])
        #expect(apps.apps.first?.branding?.isDiscoverableApp == true)
        #expect(apps.apps.first?.branding?.category == "developer-tools")
        #expect(apps.apps.first?.categories == ["Developer Tools"])
        #expect(apps.apps.first?.description == "GitHub app fixture")
        #expect(apps.apps.first?.installURL == "https://example.com/install")
        #expect(apps.apps.first?.labels == ["kind": "connector"])
        #expect(apps.apps.first?.screenshots?.first?.fileID == "screenshot-1")
        #expect(apps.apps.first?.versionID == "version-123")
        #expect(apps.nextCursor == "apps-next")

        let skills = try await client.extensions.skills.list(
            .init(
                currentDirectoryPaths: ["/tmp/project"],
                forceReload: true
            )
        )
        #expect(skills.entries.first?.errors.first?.message == "Skipped duplicate skill.")
        #expect(skills.entries.first?.skills.first?.scope == .user)
        #expect(skills.entries.first?.skills.first?.name == "swift-package-build-run-workflow")
        #expect(skills.entries.first?.skills.first?.displayName == "Swift Package Workflow")
        #expect(skills.entries.first?.skills.first?.shortDescription == "SwiftPM workflow from interface")

        let plugins = try await client.extensions.plugins.list(.init(currentDirectoryPaths: ["/tmp/project"]))
        #expect(plugins.featuredPluginIDs == ["github"])
        #expect(plugins.marketplaceLoadErrors.first?.marketplacePath == "/tmp/bad-marketplace.json")
        #expect(plugins.marketplaces.first?.displayName == "Curated")
        #expect(plugins.marketplaces.first?.plugins.first?.sourceKind == .remote)
        #expect(plugins.marketplaces.first?.plugins.first?.interface?.capabilities == ["issues", "pull-requests"])
        #expect(plugins.marketplaces.first?.plugins.first?.interface?.defaultPrompt == ["Review my PR."])
        #expect(plugins.marketplaces.first?.plugins.last?.sourceKind == .local)
        #expect(plugins.marketplaces.first?.plugins.last?.sourcePath == "/tmp/plugins/local-plugin")

        let plugin = try await client.extensions.plugins.read(.init(pluginName: "GitHub", remoteMarketplaceName: "openai-curated"))
        #expect(plugin.marketplaceName == "openai-curated")
        #expect(plugin.marketplacePath == "/tmp/marketplaces/openai-curated.json")
        #expect(plugin.description == "GitHub plugin detail fixture.")
        #expect(plugin.apps.first?.needsAuth == true)
        #expect(plugin.hooks.map(\.key) == ["github-pre-tool-use", "github-post-tool-use"])
        #expect(plugin.hooks.map(\.eventName) == [.preToolUse, .postToolUse])
        #expect(plugin.skills.first?.displayName == "PR Review")
        #expect(plugin.summary.name == "GitHub")
        #expect(plugin.summary.sourceKind == .git)
        #expect(plugin.summary.sourceRefName == "main")
        #expect(plugin.summary.sourceSHA == "abc123")
        #expect(plugin.summary.sourceURL == "https://github.com/openai/github-plugin")

        let modes = try await client.extensions.collaborationModes.list()
        #expect(modes.modes.first?.kind == .plan)
        #expect(modes.modes.first?.reasoningEffort == .medium)

        let appRequest = try #require(await transport.recordedRequestPayload(for: "app/list"))
        let appRequestJSON = try decodedJSONObject(from: appRequest)
        #expect(value(at: ["params", "cursor"], in: appRequestJSON) as? String == "apps-cursor")
        #expect(value(at: ["params", "threadId"], in: appRequestJSON) as? String == "thread-123")

        let skillsRequest = try #require(await transport.recordedRequestPayload(for: "skills/list"))
        let skillsRequestJSON = try decodedJSONObject(from: skillsRequest)
        #expect(value(at: ["params", "cwds"], in: skillsRequestJSON) as? [String] == ["/tmp/project"])
        #expect(value(at: ["params", "forceReload"], in: skillsRequestJSON) as? Bool == true)
        #expect(value(at: ["params", "perCwdExtraUserRoots"], in: skillsRequestJSON) == nil)

        let pluginsRequest = try #require(await transport.recordedRequestPayload(for: "plugin/list"))
        let pluginsRequestJSON = try decodedJSONObject(from: pluginsRequest)
        #expect(value(at: ["params", "cwds"], in: pluginsRequestJSON) as? [String] == ["/tmp/project"])

        let pluginReadRequest = try #require(await transport.recordedRequestPayload(for: "plugin/read"))
        let pluginReadJSON = try decodedJSONObject(from: pluginReadRequest)
        #expect(value(at: ["params", "pluginName"], in: pluginReadJSON) as? String == "GitHub")
        #expect(value(at: ["params", "remoteMarketplaceName"], in: pluginReadJSON) as? String == "openai-curated")

        let collaborationRequest = try #require(await transport.recordedRequestPayload(for: "collaborationMode/list"))
        #expect(value(at: ["params"], in: try decodedJSONObject(from: collaborationRequest)) as? [String: Any] != nil)

        await client.stop()
    }

    @Test("CodexExtensions upgrades configured marketplaces through command exec")
    func codexExtensionsUpgradesConfiguredMarketplacesThroughCommandExec() async throws {
        let transport = FakeCodexAppServerTransport(
            commandExecResult: [
                "exitCode": 0,
                "stderr": "",
                "stdout": "Marketplace openai-curated upgraded.\n",
            ]
        )
        let client = CodexAppServer(transport: transport)
        let operationStream = await client.featureOperationEvents()
        let operationTask = Task {
            var iterator = operationStream.makeAsyncIterator()
            return await iterator.next()
        }

        try await client.start()
        _ = try await client.initialize(
            .init(
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        let result = try await client.extensions.plugins.upgradeMarketplace(
            .init(
                marketplaceName: "openai-curated",
                currentDirectoryPaths: ["/tmp/project"],
                timeoutMilliseconds: 30_000
            )
        )

        #expect(result.marketplaceName == "openai-curated")
        #expect(result.exitCode == 0)
        #expect(result.status == .succeeded)
        #expect(result.stdout == "Marketplace openai-curated upgraded.\n")
        #expect(result.command == ["codex", "plugin", "marketplace", "upgrade", "openai-curated"])

        let methods = await transport.recordedMethods
        #expect(methods.contains("plugin/list"))
        #expect(methods.contains("command/exec"))
        #expect(!methods.contains("thread/start"))

        let pluginsRequest = try #require(await transport.recordedRequestPayload(for: "plugin/list"))
        #expect(value(at: ["params", "cwds"], in: try decodedJSONObject(from: pluginsRequest)) as? [String] == ["/tmp/project"])

        let commandRequest = try #require(await transport.recordedRequestPayload(for: "command/exec"))
        let commandJSON = try decodedJSONObject(from: commandRequest)
        #expect(value(at: ["params", "command"], in: commandJSON) as? [String] == result.command)
        #expect(value(at: ["params", "timeoutMs"], in: commandJSON) as? Int == 30_000)
        #expect(value(at: ["params", "permissionProfile"], in: commandJSON) == nil)
        #expect(value(at: ["params", "sandboxPolicy"], in: commandJSON) == nil)

        let operation = try #require(await operationTask.value)
        #expect(operation.categoryID == .extensionMaintenance)
        #expect(operation.operationID == result.operationID)
        #expect(operation.title == "Upgrade plugin marketplace")
        #expect(operation.status == .succeeded)
        #expect(operation.commands.first?.argv == result.command)
        #expect(operation.appServerMethod == "command/exec")
        #expect(operation.intentKind == "extensionMarketplaceUpgrade")
        #expect(operation.rollback.isAvailable == false)

        await client.stop()
    }

    @Test("CodexExtensions refuses marketplace upgrades when maintenance is disabled")
    func codexExtensionsRefusesMarketplaceUpgradesWhenMaintenanceIsDisabled() async throws {
        var featurePolicy = SwiftASBFeaturePolicy.defaults
        featurePolicy.setMode(.disabled, for: .extensionMaintenance)

        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport, featurePolicy: featurePolicy)

        try await client.start()
        _ = try await client.initialize(
            .init(
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        await #expect(throws: CodexAppServerError.self) {
            try await client.extensions.plugins.upgradeMarketplace(
                .init(marketplaceName: "openai-curated")
            )
        }

        let methods = await transport.recordedMethods
        #expect(!methods.contains("plugin/list"))
        #expect(!methods.contains("command/exec"))

        await client.stop()
    }

    @Test("CodexExtensions refuses marketplace upgrades when maintenance is read-only")
    func codexExtensionsRefusesMarketplaceUpgradesWhenMaintenanceIsReadOnly() async throws {
        var featurePolicy = SwiftASBFeaturePolicy.defaults
        featurePolicy.setMode(.readOnly, for: .extensionMaintenance)

        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport, featurePolicy: featurePolicy)

        try await client.start()
        _ = try await client.initialize(
            .init(
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        await #expect(throws: CodexAppServerError.self) {
            try await client.extensions.plugins.upgradeMarketplace(
                .init(marketplaceName: "openai-curated")
            )
        }

        let methods = await transport.recordedMethods
        #expect(!methods.contains("plugin/list"))
        #expect(!methods.contains("command/exec"))

        await client.stop()
    }

    @Test("CodexExtensions rejects removed per-cwd extra skill roots option")
    func codexExtensionsRejectsRemovedPerCwdExtraSkillRootsOption() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()
        _ = try await client.initialize(
            .init(
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        do {
            _ = try await client.extensions.skills.list(
                .init(
                    currentDirectoryPaths: ["/tmp/project"],
                    perCurrentDirectoryExtraUserRoots: [
                        .init(currentDirectoryPath: "/tmp/project", extraUserRoots: ["/tmp/extra-skills"]),
                    ]
                )
            )
            Issue.record("Expected per-cwd extra skill roots to be rejected for Codex CLI 0.130.0.")
        } catch let error as CodexAppServerError {
            guard case let .invalidState(reason) = error else {
                Issue.record("Expected removed per-cwd extra skill roots to throw an invalidState error.")
                await client.stop()
                return
            }

            #expect(
                reason
                    == "Codex CLI 0.130.0 removed per-cwd extra user roots from skills/list; pass currentDirectoryPaths and forceReload only."
            )
        }

        #expect(await transport.recordedRequestPayload(for: "skills/list") == nil)

        await client.stop()
    }

    @Test("CodexThread reads and updates app-server thread goals")
    func codexThreadReadsAndUpdatesAppServerThreadGoals() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()
        _ = try await client.initialize(
            .init(
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        let thread = try await client.startThread(
            .init(
                currentDirectoryPath: "/tmp/project",
                model: "gpt-5.2"
            )
        )

        let goal = try await thread.readGoal()
        #expect(goal?.objective == "Promote schemas")
        #expect(goal?.status == .active)

        let updated = try await thread.setGoal(.init(status: .budgetLimited, tokenBudget: 30_000))
        #expect(updated.status == .budgetLimited)
        #expect(updated.tokenBudget == 30_000)

        let cleared = try await thread.clearGoal()
        #expect(cleared)

        let goalSetRequest = try #require(await transport.recordedRequestPayload(for: "thread/goal/set"))
        let goalSetJSON = try decodedJSONObject(from: goalSetRequest)
        #expect(value(at: ["params", "threadId"], in: goalSetJSON) as? String == thread.id)
        #expect(value(at: ["params", "status"], in: goalSetJSON) as? String == "budgetLimited")
        #expect(value(at: ["params", "tokenBudget"], in: goalSetJSON) as? Int == 30_000)

        await client.stop()
    }
}

private func decodedJSONObject(from data: Data) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func value(
    at path: [String],
    in object: [String: Any]
) -> Any? {
    var current: Any = object
    for key in path {
        guard let dictionary = current as? [String: Any],
              let next = dictionary[key] else {
            return nil
        }
        current = next
    }
    return current
}
