import Foundation
import Testing
@testable import SwiftASB

@Suite("CodexAppServerProtocol")
struct CodexAppServerProtocolTests {
    private let protocolLayer = CodexAppServerProtocol()

    @Test("encodes initialize requests with the expected method and params payload")
    func encodesInitializeRequest() throws {
        let payload = try protocolLayer.makeInitializeRequest(
            id: .string("init-1"),
            params: CodexWireInitializeParams(
                capabilities: CodexWireInitializeCapabilities(
                    experimentalAPI: true,
                    optOutNotificationMethods: ["thread/started"]
                ),
                clientInfo: CodexWireClientInfo(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["method"] as? String == "initialize")
        #expect(object["id"] as? String == "init-1")

        let params = try #require(object["params"] as? [String: Any])
        let clientInfo = try #require(params["clientInfo"] as? [String: Any])
        #expect(clientInfo["name"] as? String == "SwiftASBTests")
        #expect(clientInfo["title"] as? String == "SwiftASB Tests")
        #expect(clientInfo["version"] as? String == "0.1.0")

        let capabilities = try #require(params["capabilities"] as? [String: Any])
        #expect(capabilities["experimentalApi"] as? Bool == true)
        #expect(capabilities["optOutNotificationMethods"] as? [String] == ["thread/started"])
    }

    @Test("encodes initialized notifications without params")
    func encodesInitializedNotification() throws {
        let payload = try protocolLayer.makeInitializedNotification()

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["method"] as? String == "initialized")
        #expect(object["params"] == nil)
        #expect(object["id"] == nil)
    }

    @Test("encodes thread/start requests with the expected method and params payload")
    func encodesThreadStartRequest() throws {
        let payload = try protocolLayer.makeThreadStartRequest(
            id: .string("thread-1"),
            params: CodexWireThreadStartParams(
                approvalPolicy: .enumeration(.onRequest),
                approvalsReviewer: .user,
                baseInstructions: "Be concise.",
                config: ["temperature": .double(0.25)],
                cwd: "/tmp/project",
                developerInstructions: "Keep output structured.",
                ephemeral: true,
                model: "gpt-5.4",
                modelProvider: "openai",
                personality: .friendly,
                sandbox: .workspaceWrite,
                serviceName: "codex",
                serviceTier: .fast,
                sessionStartSource: .clear
            )
        )

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["method"] as? String == "thread/start")
        #expect(object["id"] as? String == "thread-1")

        let params = try #require(object["params"] as? [String: Any])
        #expect(params["baseInstructions"] as? String == "Be concise.")
        #expect(params["cwd"] as? String == "/tmp/project")
        #expect(params["ephemeral"] as? Bool == true)
        #expect(params["model"] as? String == "gpt-5.4")
        #expect(params["sandbox"] as? String == "workspace-write")
        #expect(params["serviceTier"] as? String == "fast")
        #expect(params["sessionStartSource"] as? String == "clear")

        let config = try #require(params["config"] as? [String: Any])
        #expect(config["temperature"] as? Double == 0.25)
    }

    @Test("encodes turn/start requests with the expected method and params payload")
    func encodesTurnStartRequest() throws {
        let payload = try protocolLayer.makeTurnStartRequest(
            id: .string("turn-1"),
            params: CodexWireTurnStartParams(
                approvalPolicy: .enumeration(.onFailure),
                approvalsReviewer: .guardianSubagent,
                cwd: "/tmp/project",
                effort: .medium,
                input: [
                    CodexWireUserInput(
                        text: "Hello from SwiftASB",
                        textElements: nil,
                        type: .text,
                        url: nil,
                        path: nil,
                        name: nil
                    )
                ],
                model: "gpt-5.4",
                outputSchema: .object(["type": .string("object")]),
                personality: .pragmatic,
                sandboxPolicy: nil,
                serviceTier: .flex,
                summary: .concise,
                threadID: "thread-123"
            )
        )

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["method"] as? String == "turn/start")
        #expect(object["id"] as? String == "turn-1")

        let params = try #require(object["params"] as? [String: Any])
        #expect(params["cwd"] as? String == "/tmp/project")
        #expect(params["effort"] as? String == "medium")
        #expect(params["model"] as? String == "gpt-5.4")
        #expect(params["personality"] as? String == "pragmatic")
        #expect(params["serviceTier"] as? String == "flex")
        #expect(params["summary"] as? String == "concise")
        #expect(params["threadId"] as? String == "thread-123")

        let input = try #require(params["input"] as? [[String: Any]])
        #expect(input.count == 1)
        #expect(input.first?["type"] as? String == "text")
        #expect(input.first?["text"] as? String == "Hello from SwiftASB")

        let outputSchema = try #require(params["outputSchema"] as? [String: Any])
        #expect(outputSchema["type"] as? String == "object")
    }

    @Test("decodes initialize responses and honors the expected request ID")
    func decodesInitializeResponse() throws {
        let payload = Data(
            #"{"id":"init-1","result":{"codexHome":"/Users/galew/.codex","platformFamily":"unix","platformOs":"macos","userAgent":"codex-cli/0.121.0"}}"#.utf8
        )

        let response = try protocolLayer.decodeInitializeResponse(payload, expectedID: .string("init-1"))

        #expect(response.codexHome == "/Users/galew/.codex")
        #expect(response.platformFamily == "unix")
        #expect(response.platformOS == "macos")
        #expect(response.userAgent == "codex-cli/0.121.0")
    }

    @Test("throws protocol errors when the server returns an RPC error response")
    func surfacesInitializeRPCError() throws {
        let payload = Data(
            #"{"id":"init-1","error":{"code":-32602,"message":"bad params","data":{"field":"clientInfo"}}}"#.utf8
        )

        #expect(throws: CodexProtocolError.self) {
            try protocolLayer.decodeInitializeResponse(payload, expectedID: .string("init-1"))
        }
    }

    @Test("throws protocol errors when the response ID does not match")
    func rejectsInitializeResponseIDMismatch() throws {
        let payload = Data(
            #"{"id":"init-2","result":{"codexHome":"/Users/galew/.codex","platformFamily":"unix","platformOs":"macos","userAgent":"codex-cli/0.121.0"}}"#.utf8
        )

        #expect(throws: CodexProtocolError.self) {
            try protocolLayer.decodeInitializeResponse(payload, expectedID: .string("init-1"))
        }
    }

    @Test("decodes thread/start responses and honors the expected request ID")
    func decodesThreadStartResponse() throws {
        let payload = Data(
            #"""
            {"id":"thread-1","result":{"approvalPolicy":"on-request","approvalsReviewer":"user","cwd":"/tmp/project","instructionSources":["AGENTS.md"],"model":"gpt-5.4","modelProvider":"openai","reasoningEffort":"medium","sandbox":{"type":"workspaceWrite","networkAccess":"enabled","writableRoots":["/tmp/project"]},"serviceTier":"fast","thread":{"cliVersion":"0.121.0","createdAt":1713350000,"cwd":"/tmp/project","ephemeral":false,"id":"thread-123","modelProvider":"openai","preview":"Hello","source":"cli","status":{"type":"active"},"turns":[],"updatedAt":1713350001}}}
            """#.utf8
        )

        let response = try protocolLayer.decodeThreadStartResponse(payload, expectedID: .string("thread-1"))

        #expect(response.cwd == "/tmp/project")
        #expect(response.model == "gpt-5.4")
        #expect(response.modelProvider == "openai")
        #expect(response.serviceTier == .fast)
        #expect(response.thread.id == "thread-123")
        #expect(response.thread.preview == "Hello")
        #expect(response.thread.turns.isEmpty)
    }

    @Test("decodes turn/start responses and honors the expected request ID")
    func decodesTurnStartResponse() throws {
        let payload = Data(
            #"""
            {"id":"turn-1","result":{"turn":{"completedAt":null,"durationMs":null,"error":null,"id":"turn-123","items":[],"startedAt":1713350002,"status":"inProgress"}}}
            """#.utf8
        )

        let response = try protocolLayer.decodeTurnStartResponse(payload, expectedID: .string("turn-1"))

        #expect(response.turn.id == "turn-123")
        #expect(response.turn.startedAt == 1713350002)
        #expect(response.turn.completedAt == nil)
        #expect(response.turn.items.isEmpty)
    }
}
