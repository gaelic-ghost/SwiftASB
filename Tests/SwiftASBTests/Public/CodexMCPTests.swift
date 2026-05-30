import Foundation
import Testing
@testable import SwiftASB

extension CodexAppServerTests {
    @Test("MCP install writes a stdio server through config batch write")
    func mcpInstallWritesStdioServerThroughConfigBatchWrite() async throws {
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

        let result = try await client.mcp.install(
            .stdio(
                name: "docs",
                command: "/usr/bin/env",
                arguments: ["node", "/tmp/docs-server.js"],
                currentDirectoryPath: "/tmp/docs",
                environment: ["DOCS_MODE": "test"],
                inheritedEnvironmentVariables: ["OPENAI_API_KEY"],
                options: .init(
                    enabled: true,
                    required: false,
                    startupTimeoutSeconds: 5,
                    toolTimeoutSeconds: 30,
                    toolPolicy: .init(
                        enabledTools: ["search"],
                        defaultApprovalMode: .prompt,
                        toolApprovalModes: ["write": .approve]
                    )
                )
            )
        )

        #expect(result.configFilePath == "/Users/example/.codex/config.toml")
        #expect(result.status == .ok)
        #expect(result.version == "sha256:swiftasb-config-write")

        let payload = try #require(await transport.recordedRequestPayload(for: "config/batchWrite"))
        let request = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(request["method"] as? String == "config/batchWrite")

        let params = try #require(request["params"] as? [String: Any])
        #expect(params["reloadUserConfig"] as? Bool == true)
        let edits = try #require(params["edits"] as? [[String: Any]])
        #expect(edits.count == 1)
        #expect(edits[0]["keyPath"] as? String == "mcp_servers.docs")
        #expect(edits[0]["mergeStrategy"] as? String == "replace")

        let value = try #require(edits[0]["value"] as? [String: Any])
        #expect(value["command"] as? String == "/usr/bin/env")
        #expect(value["args"] as? [String] == ["node", "/tmp/docs-server.js"])
        #expect(value["cwd"] as? String == "/tmp/docs")
        #expect(value["enabled"] as? Bool == true)
        #expect(value["required"] as? Bool == false)
        #expect(value["startup_timeout_sec"] as? Double == 5)
        #expect(value["tool_timeout_sec"] as? Double == 30)
        #expect(value["enabled_tools"] as? [String] == ["search"])
        #expect(value["default_tools_approval_mode"] as? String == "prompt")
        #expect(value["env"] as? [String: String] == ["DOCS_MODE": "test"])
        #expect(value["env_vars"] as? [String] == ["OPENAI_API_KEY"])
        let tools = try #require(value["tools"] as? [String: [String: String]])
        #expect(tools["write"]?["approval_mode"] == "approve")

        await client.stop()
    }

    @Test("MCP install writes an HTTP server through config batch write")
    func mcpInstallWritesHTTPServerThroughConfigBatchWrite() async throws {
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

        try await client.mcp.install(
            .http(
                name: "search",
                url: try #require(URL(string: "https://example.com/mcp")),
                authorization: .bearerTokenEnvironmentVariable("SEARCH_MCP_TOKEN"),
                headers: ["X-Static": "yes"],
                environmentHeaders: ["Authorization": "SEARCH_MCP_AUTH_HEADER"],
                options: .init(
                    enabled: false,
                    toolPolicy: .deny(["delete"])
                )
            )
        )

        let payload = try #require(await transport.recordedRequestPayload(for: "config/batchWrite"))
        let request = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        let params = try #require(request["params"] as? [String: Any])
        let edits = try #require(params["edits"] as? [[String: Any]])
        #expect(edits[0]["keyPath"] as? String == "mcp_servers.search")

        let value = try #require(edits[0]["value"] as? [String: Any])
        #expect(value["url"] as? String == "https://example.com/mcp")
        #expect(value["enabled"] as? Bool == false)
        #expect(value["bearer_token_env_var"] as? String == "SEARCH_MCP_TOKEN")
        #expect(value["http_headers"] as? [String: String] == ["X-Static": "yes"])
        #expect(value["env_http_headers"] as? [String: String] == ["Authorization": "SEARCH_MCP_AUTH_HEADER"])
        #expect(value["disabled_tools"] as? [String] == ["delete"])

        await client.stop()
    }

    @Test("MCP install rejects names that cannot be used as config key paths")
    func mcpInstallRejectsUnsafeConfigKeyPathNames() async throws {
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

        await #expect(throws: CodexAppServerError.self) {
            try await client.mcp.install(
                .stdio(name: "bad.name", command: "/usr/bin/env")
            )
        }

        let payloads = await transport.requestPayloads(for: "config/batchWrite")
        #expect(payloads.isEmpty)

        await client.stop()
    }

    @Test("MCP surface exposes cached status and resource reads")
    func mcpSurfaceExposesStatusSnapshotAndResourceRead() async throws {
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

        let snapshot = await client.mcp.statusSnapshot()
        #expect(snapshot.servers.map(\.name) == ["calendar"])
        #expect(snapshot.servers.first?.resources.map(\.uri) == ["calendar://events/today"])
        #expect(snapshot.servers.first?.tools.keys.sorted() == ["list_events"])

        let resource = try await client.mcp.readResource(
            server: "calendar",
            uri: "calendar://events/today"
        )
        #expect(resource.contents.first?.uri == "calendar://events/today")
        #expect(resource.contents.first?.text == #"{"events":[]}"#)

        let payload = try #require(await transport.recordedRequestPayload(for: "mcpServer/resource/read"))
        let request = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(request["method"] as? String == "mcpServer/resource/read")

        await client.stop()
    }
}
