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
        #expect(directory.entries.map(\.fileName) == ["Sources", "Package.swift"])
        #expect(directory.entries.map(\.kind) == [.directory, .file])

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
        #expect(snapshot.layers?.count == 1)
        #expect(snapshot.layers?.first?.name.kind == .user)
        #expect(snapshot.origins["model"]?.name.file == "/Users/galew/.codex/config.toml")

        let requirements = try await client.config.readRequirements()
        #expect(requirements.requirements != nil)

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

        let apps = try await client.extensions.listApps(.init(cursor: "apps-cursor", limit: 1, forceRefetch: true, threadID: "thread-123"))
        #expect(apps.apps.map(\.name) == ["GitHub"])
        #expect(apps.apps.first?.branding?.isDiscoverableApp == true)
        #expect(apps.nextCursor == "apps-next")

        let skills = try await client.extensions.listSkills(.init(currentDirectoryPaths: ["/tmp/project"], forceReload: true))
        #expect(skills.entries.first?.skills.first?.scope == .user)
        #expect(skills.entries.first?.skills.first?.name == "swift-package-build-run-workflow")

        let plugins = try await client.extensions.listPlugins(.init(currentDirectoryPaths: ["/tmp/project"]))
        #expect(plugins.featuredPluginIDs == ["github"])
        #expect(plugins.marketplaces.first?.plugins.first?.sourceKind == .remote)

        let plugin = try await client.extensions.readPlugin(.init(pluginName: "GitHub", remoteMarketplaceName: "openai-curated"))
        #expect(plugin.marketplaceName == "openai-curated")
        #expect(plugin.summary.name == "GitHub")

        let modes = try await client.extensions.listCollaborationModes()
        #expect(modes.modes.first?.kind == .plan)
        #expect(modes.modes.first?.reasoningEffort == .medium)

        let appRequest = try #require(await transport.recordedRequestPayload(for: "app/list"))
        let appRequestJSON = try decodedJSONObject(from: appRequest)
        #expect(value(at: ["params", "cursor"], in: appRequestJSON) as? String == "apps-cursor")
        #expect(value(at: ["params", "threadId"], in: appRequestJSON) as? String == "thread-123")

        let collaborationRequest = try #require(await transport.recordedRequestPayload(for: "collaborationMode/list"))
        #expect(value(at: ["params"], in: try decodedJSONObject(from: collaborationRequest)) as? [String: Any] != nil)

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
