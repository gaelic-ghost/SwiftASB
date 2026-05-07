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

    @Test("reads app-wide model capabilities through the public client")
    func readsAppWideModelCapabilities() async throws {
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

        let capabilities = try await client.readModelCapabilities()

        #expect(capabilities.imageGeneration == true)
        #expect(capabilities.namespaceTools == false)
        #expect(capabilities.webSearch == true)

        let requestPayload = try #require(
            await transport.recordedRequestPayload(for: "modelProvider/capabilities/read")
        )
        let request = try #require(try JSONSerialization.jsonObject(with: requestPayload) as? [String: Any])
        #expect(request["method"] as? String == "modelProvider/capabilities/read")
        let params = try #require(request["params"] as? [String: Any])
        #expect(params.isEmpty)

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

    @Test("reads MCP resources through the public client")
    func readsMcpResource() async throws {
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

        let result = try await client.readMcpResource(
            .init(server: "calendar", uri: "calendar://events/today", threadID: "thread-123")
        )

        #expect(result.contents.count == 1)
        #expect(result.contents[0].uri == "calendar://events/today")
        #expect(result.contents[0].mimeType == "application/json")
        #expect(result.contents[0].text == #"{"events":[]}"#)
        #expect(result.contents[0].metadata == .object(["source": .string("fixture")]))

        let requestPayload = try #require(await transport.recordedRequestPayload(for: "mcpServer/resource/read"))
        let request = try #require(try JSONSerialization.jsonObject(with: requestPayload) as? [String: Any])
        let params = try #require(request["params"] as? [String: Any])
        #expect(params["server"] as? String == "calendar")
        #expect(params["uri"] as? String == "calendar://events/today")
        #expect(params["threadId"] as? String == "thread-123")

        await client.stop()
    }

    @Test("lists app-wide hook diagnostics through the public client")
    func listsAppWideHookDiagnostics() async throws {
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

        let snapshot = try await client.listHooks(
            .init(currentDirectoryPaths: ["/tmp/project", "/tmp/second-project"])
        )

        let entry = try #require(snapshot.entry(forCurrentDirectoryPath: "/tmp/project"))

        #expect(snapshot.entries.count == 1)
        #expect(snapshot.hasDiagnostics)
        #expect(snapshot.entry(forCurrentDirectoryPath: "/tmp/second-project") == nil)
        #expect(entry.currentDirectoryPath == "/tmp/project")
        #expect(entry.hasDiagnostics)
        #expect(entry.warnings == ["Ignoring disabled user hook user-pre-tool-use."])
        #expect(entry.errors[0].message == "Hook script is not executable.")
        #expect(entry.errors[0].path == "/tmp/project/.codex/hooks/post-tool-use.sh")
        #expect(entry.diagnostics.map(\.severity) == [.error, .warning])
        #expect(entry.diagnostics.map(\.message) == [
            "Hook script is not executable.",
            "Ignoring disabled user hook user-pre-tool-use.",
        ])
        #expect(entry.diagnostics[0].path == "/tmp/project/.codex/hooks/post-tool-use.sh")
        #expect(entry.diagnostics[1].path == nil)
        #expect(entry.enabledHooks.map(\.key) == ["project-post-tool-use"])
        #expect(entry.disabledHooks.map(\.key) == ["user-pre-tool-use"])
        #expect(entry.hooks[0].key == "project-post-tool-use")
        #expect(entry.hooks[0].command == "swift test")
        #expect(entry.hooks[0].displayOrder == 2)
        #expect(entry.hooks[0].enabled)
        #expect(entry.hooks[0].eventName == .postToolUse)
        #expect(entry.hooks[0].handlerType == .command)
        #expect(entry.hooks[0].source == .project)
        #expect(entry.hooks[0].sourcePath == "/tmp/project/.codex/hooks/post-tool-use.sh")
        #expect(entry.hooks[0].timeoutSeconds == 30)

        let requestPayload = try #require(await transport.recordedRequestPayload(for: "hooks/list"))
        let request = try #require(try JSONSerialization.jsonObject(with: requestPayload) as? [String: Any])
        let params = try #require(request["params"] as? [String: Any])
        #expect(params["cwds"] as? [String] == ["/tmp/project", "/tmp/second-project"])

        await client.stop()
    }

}
