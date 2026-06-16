import Foundation
@testable import SwiftASB
import Testing

extension CodexAppServerTests {
    @MainActor
    @Test("inventory loads app-wide snapshots on creation")
    func inventoryLoadsSnapshotsOnCreation() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()
        _ = try await client.initialize(
            .init(clientInfo: .init(name: "SwiftASBTests", title: "SwiftASB Tests", version: "0.1.0"))
        )

        let inventory = try await client.extensions.makeInventory(
            configuration: .init(
                hookListCurrentDirectoryPaths: ["/tmp/project"],
                extensionCurrentDirectoryPaths: ["/tmp/project"],
                appListLimit: 1
            )
        )

        try await waitForCondition(maxAttempts: 2000) {
            await MainActor.run {
                inventory.appListPage != nil
                    && inventory.skillListSnapshot != nil
                    && inventory.pluginListSnapshot != nil
                    && inventory.collaborationModes != nil
            }
        }

        #expect(inventory.modelCapabilities?.webSearch == true)
        #expect(inventory.modelCapabilities?.imageGeneration == true)
        #expect(inventory.mcpServers.map(\.name) == ["calendar"])
        #expect(inventory.mcpServers.map(\.scope) == [.global])
        #expect(inventory.mcpServers.map(\.resourceCount) == [1])
        #expect(inventory.hookListSnapshot?.entry(forCurrentDirectoryPath: "/tmp/project")?.hasDiagnostics == true)
        #expect(inventory.appListPage?.apps.map(\.name) == ["GitHub"])
        #expect(inventory.skillListSnapshot?.entries.first?.skills.first?.name == "swift-package-build-run-workflow")
        #expect(inventory.pluginListSnapshot?.marketplaces.first?.plugins.first?.name == "GitHub")
        #expect(inventory.collaborationModes?.modes.first?.kind == .plan)
        #expect(inventory.apps.map(\.name) == ["GitHub"])
        #expect(inventory.skillEntries.map(\.currentDirectoryPath) == ["/tmp/project"])
        #expect(inventory.skills.map(\.name) == ["swift-package-build-run-workflow"])
        #expect(inventory.pluginMarketplaces.map(\.name) == ["openai-curated"])
        #expect(inventory.collaborationModeEntries.map(\.name) == ["Plan"])
        #expect(inventory.lastRefreshedAt != nil)
        #expect(inventory.latestErrorDescription == nil)
        #expect(inventory.phase == .idle)

        let appRequest = try #require(await transport.recordedRequestPayload(for: "app/list"))
        let appRequestJSON = try decodedInventoryJSONObject(from: appRequest)
        #expect(inventoryValue(at: ["params", "limit"], in: appRequestJSON) as? Int == 1)

        let skillsRequest = try #require(await transport.recordedRequestPayload(for: "skills/list"))
        let skillsRequestJSON = try decodedInventoryJSONObject(from: skillsRequest)
        #expect(inventoryValue(at: ["params", "cwds"], in: skillsRequestJSON) as? [String] == ["/tmp/project"])

        let hooksRequest = try #require(await transport.recordedRequestPayload(for: "hooks/list"))
        let hooksRequestJSON = try decodedInventoryJSONObject(from: hooksRequest)
        #expect(inventoryValue(at: ["params", "cwds"], in: hooksRequestJSON) as? [String] == ["/tmp/project"])

        await client.stop()
    }

    @MainActor
    @Test("inventory can wait for explicit manual refresh")
    func inventorySupportsManualRefresh() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()
        _ = try await client.initialize(
            .init(clientInfo: .init(name: "SwiftASBTests", title: "SwiftASB Tests", version: "0.1.0"))
        )

        let inventory = try await client.extensions.makeInventory(
            configuration: .init(loadsOnCreation: false)
        )

        #expect(inventory.appListPage == nil)
        #expect(await transport.requestPayloads(for: "app/list").isEmpty)

        await inventory.refresh()

        #expect(inventory.appListPage?.apps.map(\.id) == ["github"])
        #expect(inventory.skillListSnapshot?.entries.first?.currentDirectoryPath == "/tmp/project")
        #expect(inventory.pluginListSnapshot?.featuredPluginIDs == ["github"])
        #expect(inventory.collaborationModes?.modes.first?.name == "Plan")
        #expect(inventory.latestErrorDescription == nil)

        await client.stop()
    }

    @MainActor
    @Test("inventory refreshes when app-server inventory notifications arrive")
    func inventoryRefreshesFromAppServerNotifications() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()
        _ = try await client.initialize(
            .init(clientInfo: .init(name: "SwiftASBTests", title: "SwiftASB Tests", version: "0.1.0"))
        )

        let inventory = try await client.extensions.makeInventory(
            configuration: .init(loadsOnCreation: false)
        )
        await inventory.refresh()

        let initialAppRequests = await transport.requestPayloads(for: "app/list")
        #expect(initialAppRequests.count == 1)

        await transport.emitAppListUpdated()
        try await waitForCondition {
            await transport.requestPayloads(for: "app/list").count >= 2
        }

        await transport.emitSkillsChanged()
        try await waitForCondition {
            await transport.requestPayloads(for: "skills/list").count >= 3
        }

        await transport.emitMcpServerStatusUpdated()
        try await waitForCondition {
            await transport.requestPayloads(for: "app/list").count >= 4
        }
        try await waitForCondition {
            await MainActor.run {
                inventory.phase == .idle
            }
        }

        #expect(inventory.appListPage?.apps.first?.name == "GitHub")
        #expect(inventory.phase == .idle)

        await client.stop()
    }

    @MainActor
    @Test("inventory keeps previous snapshots when one family fails")
    func inventoryKeepsPreviousSnapshotsAfterPartialFailure() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()
        _ = try await client.initialize(
            .init(clientInfo: .init(name: "SwiftASBTests", title: "SwiftASB Tests", version: "0.1.0"))
        )

        let inventory = try await client.extensions.makeInventory(
            configuration: .init(loadsOnCreation: false)
        )

        await inventory.refresh()
        let firstRefreshDate = try #require(inventory.lastRefreshedAt)
        let previousSkillName = inventory.skillListSnapshot?.entries.first?.skills.first?.name
        #expect(previousSkillName == "swift-package-build-run-workflow")

        await transport.setAppSnapshotFailureMethods(["skills/list"])
        await inventory.refresh()

        #expect(inventory.appListPage?.apps.map(\.name) == ["GitHub"])
        #expect(inventory.skillListSnapshot?.entries.first?.skills.first?.name == previousSkillName)
        #expect(inventory.pluginListSnapshot?.marketplaces.first?.plugins.first?.name == "GitHub")
        #expect(inventory.latestErrorDescription?.contains("skills/list") == true)
        #expect(inventory.lastRefreshedAt == firstRefreshDate)
        #expect(inventory.phase == .idle)

        await client.stop()
    }
}

private func decodedInventoryJSONObject(from data: Data) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func inventoryValue(
    at path: [String],
    in object: [String: Any]
) -> Any? {
    var current: Any? = object
    for component in path {
        current = (current as? [String: Any])?[component]
    }
    return current
}
