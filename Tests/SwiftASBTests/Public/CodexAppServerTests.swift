import Foundation
import Testing
@testable import SwiftASB

@Suite("CodexAppServer", .serialized)
struct CodexAppServerTests {
    @Test("describes public app-server errors with operation context")
    func describesPublicAppServerErrorsWithOperationContext() {
        let invalidState = CodexAppServerError.invalidState(reason: "Initialize the app-server before starting a thread.")
        #expect(invalidState.errorDescription == "Initialize the app-server before starting a thread.")

        let transportFailure = CodexAppServerError.transportFailure(
            operation: "thread/start",
            reason: "Codex app-server transport has not been started yet."
        )
        #expect(
            transportFailure.errorDescription
                == "Codex app-server transport failed during thread/start: Codex app-server transport has not been started yet."
        )

        let protocolFailure = CodexAppServerError.protocolFailure(
            operation: "turn/start",
            reason: "Failed to decode Codex app-server response for turn/start: missing turn id"
        )
        #expect(
            protocolFailure.errorDescription
                == "Codex app-server protocol handling failed during turn/start: Failed to decode Codex app-server response for turn/start: missing turn id"
        )
    }

    @Test("wraps internal transport and protocol failures as public app-server errors")
    func wrapsInternalFailuresAsPublicAppServerErrors() {
        let existing = CodexAppServerError.invalidState(reason: "already public")
        #expect(CodexAppServerError.wrap(existing, operation: "initialize") == existing)

        let transportWrapped = CodexAppServerError.wrap(
            CodexTransportError.notStarted,
            operation: "thread/start"
        )
        #expect(
            transportWrapped
                == .transportFailure(
                    operation: "thread/start",
                    reason: "Codex app-server transport has not been started yet."
                )
        )

        let protocolWrapped = CodexAppServerError.wrap(
            CodexProtocolError.responseDecodingFailed(
                context: "turn/start",
                reason: "missing turn id"
            ),
            operation: "turn/start"
        )
        #expect(
            protocolWrapped
                == .protocolFailure(
                    operation: "turn/start",
                    reason: "Failed to decode Codex app-server response for turn/start: missing turn id"
                )
        )
    }

    @Test("requires initialize before starting a thread")
    func requiresInitializeBeforeStartingThread() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()

        await #expect(throws: CodexAppServerError.self) {
            try await client.startThread()
        }

        await client.stop()
    }

    @Test("surfaces Codex CLI diagnostics after start")
    func surfacesCodexCLIDiagnosticsAfterStart() async throws {
        let transport = FakeCodexAppServerTransport(
            executableResolution: .init(
                launchExecutableURL: URL(fileURLWithPath: "/opt/homebrew/bin/codex"),
                launchArgumentsPrefix: [],
                resolvedExecutableURL: URL(fileURLWithPath: "/opt/homebrew/bin/codex"),
                source: .homebrewAppleSilicon,
                versionString: "codex-cli 0.128.0",
                compatibility: .supported(documentedWindow: "0.128.x")
            )
        )
        let client = CodexAppServer(transport: transport)

        try await client.start()

        let diagnostics = try await client.cliExecutableDiagnostics()
        #expect(diagnostics.source == .homebrewAppleSilicon)
        #expect(diagnostics.resolvedExecutablePath == "/opt/homebrew/bin/codex")
        #expect(diagnostics.versionString == "codex-cli 0.128.0")
        #expect(diagnostics.compatibility == .supported(documentedWindow: "0.128.x"))

        await client.stop()
    }

    @Test("lists app-wide models through the public client")
    func listsAppWideModels() async throws {
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

        let page = try await client.listModels(
            .init(cursor: "cursor-start", limit: 2, includeHidden: true)
        )

        #expect(page.nextCursor == "cursor-models-next")
        #expect(page.models.count == 1)
        #expect(page.models[0].id == "gpt-5.4")
        #expect(page.models[0].displayName == "GPT-5.4")
        #expect(page.models[0].defaultReasoningEffort == .medium)
        #expect(page.models[0].supportedReasoningEfforts.map(\.reasoningEffort) == [.low, .medium, .high])
        #expect(page.models[0].inputModalities == [.text, .image])

        let requestPayload = try #require(await transport.recordedRequestPayload(for: "model/list"))
        let request = try #require(try JSONSerialization.jsonObject(with: requestPayload) as? [String: Any])
        let params = try #require(request["params"] as? [String: Any])
        #expect(params["cursor"] as? String == "cursor-start")
        #expect(params["limit"] as? Int == 2)
        #expect(params["includeHidden"] as? Bool == true)

        await client.stop()
    }

    @Test("lists app-wide MCP server status through the public client")
    func listsAppWideMcpServerStatus() async throws {
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

        let page = try await client.listMcpServerStatuses(
            .init(cursor: "cursor-start", limit: 4, detail: .toolsAndAuthOnly)
        )

        #expect(page.nextCursor == nil)
        #expect(page.servers.count == 1)
        #expect(page.servers[0].name == "calendar")
        #expect(page.servers[0].authStatus == .oAuth)
        #expect(page.servers[0].resources[0].uri == "calendar://events/today")
        #expect(page.servers[0].resourceTemplates[0].uriTemplate == "calendar://events/{date}")
        #expect(page.servers[0].tools["list_events"]?.title == "List Events")
        #expect(page.servers[0].tools["list_events"]?.inputSchema == .object(["type": .string("object")]))

        let requestPayload = try #require(await transport.recordedRequestPayload(for: "mcpServerStatus/list"))
        let request = try #require(try JSONSerialization.jsonObject(with: requestPayload) as? [String: Any])
        let params = try #require(request["params"] as? [String: Any])
        #expect(params["cursor"] as? String == "cursor-start")
        #expect(params["limit"] as? Int == 4)
        #expect(params["detail"] as? String == "toolsAndAuthOnly")

        await client.stop()
    }

}
