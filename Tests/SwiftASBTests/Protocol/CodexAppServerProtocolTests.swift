import Foundation
import Testing
@testable import SwiftASB

@Suite("CodexAppServerProtocol", .serialized)
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
        #expect(object["jsonrpc"] == nil)
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
        #expect(object["jsonrpc"] == nil)
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
        #expect(object["jsonrpc"] == nil)
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
        #expect(object["jsonrpc"] == nil)
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

    @Test("encodes turn/interrupt requests with the expected method and params payload")
    func encodesTurnInterruptRequest() throws {
        let payload = try protocolLayer.makeTurnInterruptRequest(
            id: .string("interrupt-1"),
            params: .init(threadID: "thread-123", turnID: "turn-123")
        )

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["jsonrpc"] == nil)
        #expect(object["method"] as? String == "turn/interrupt")
        #expect(object["id"] as? String == "interrupt-1")

        let params = try #require(object["params"] as? [String: Any])
        #expect(params["threadId"] as? String == "thread-123")
        #expect(params["turnId"] as? String == "turn-123")
    }

    @Test("encodes turn/steer requests with the expected method and params payload")
    func encodesTurnSteerRequest() throws {
        let payload = try protocolLayer.makeTurnSteerRequest(
            id: .string("steer-1"),
            params: .init(
                expectedTurnID: "turn-123",
                input: [
                    CodexWireUserInput(
                        text: "Please summarize the answer more briefly.",
                        textElements: nil,
                        type: .text,
                        url: nil,
                        path: nil,
                        name: nil
                    )
                ],
                threadID: "thread-123"
            )
        )

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["jsonrpc"] == nil)
        #expect(object["method"] as? String == "turn/steer")
        #expect(object["id"] as? String == "steer-1")

        let params = try #require(object["params"] as? [String: Any])
        #expect(params["threadId"] as? String == "thread-123")
        #expect(params["expectedTurnId"] as? String == "turn-123")

        let input = try #require(params["input"] as? [[String: Any]])
        #expect(input.count == 1)
        #expect(input.first?["type"] as? String == "text")
        #expect(input.first?["text"] as? String == "Please summarize the answer more briefly.")
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

    @Test("decodes turn/interrupt responses and honors the expected request ID")
    func decodesTurnInterruptResponse() throws {
        let payload = Data(#"{"id":"interrupt-1","result":{}}"#.utf8)

        _ = try protocolLayer.decodeTurnInterruptResponse(
            payload,
            expectedID: .string("interrupt-1")
        )
    }

    @Test("decodes turn/steer responses and honors the expected request ID")
    func decodesTurnSteerResponse() throws {
        let payload = Data(#"{"id":"steer-1","result":{"turnId":"turn-123"}}"#.utf8)

        let response = try protocolLayer.decodeTurnSteerResponse(
            payload,
            expectedID: .string("steer-1")
        )

        #expect(response.turnID == "turn-123")
    }

    @Test("decodes turn/completed notifications into typed protocol events")
    func decodesTurnCompletedNotification() throws {
        let payload = Data(
            #"""
            {"threadId":"thread-123","turn":{"completedAt":1713350005,"durationMs":3000,"error":null,"id":"turn-123","items":[],"startedAt":1713350002,"status":"completed"}}
            """#.utf8
        )

        let event = try protocolLayer.decodeServerEvent(
            .notification(method: "turn/completed", payload: payload)
        )

        let decodedEvent = try #require(event)

        switch decodedEvent {
        case let .turnCompleted(notification):
            #expect(notification.threadID == "thread-123")
            #expect(notification.turn.id == "turn-123")
            #expect(notification.turn.status == .completed)
            #expect(notification.turn.completedAt == 1713350005)
        default:
            Issue.record("Expected turn/completed to decode into .turnCompleted.")
        }
    }

    @Test("decodes thread lifecycle notifications into typed protocol events")
    func decodesThreadLifecycleNotifications() throws {
        let threadStartedPayload = Data(
            #"""
            {"thread":{"cliVersion":"0.121.0","createdAt":1713350000,"cwd":"/tmp/project","ephemeral":false,"id":"thread-123","modelProvider":"openai","preview":"Hello","source":"cli","status":{"type":"active"},"turns":[],"updatedAt":1713350001}}
            """#.utf8
        )

        let threadStartedEvent = try #require(
            try decodeEvent(method: "thread/started", payload: threadStartedPayload)
        )

        switch threadStartedEvent {
        case let .threadStarted(notification):
            #expect(notification.thread.id == "thread-123")
            #expect(notification.thread.preview == "Hello")
            #expect(notification.thread.status.type == .active)
        default:
            Issue.record("Expected thread/started to decode into .threadStarted.")
        }

        let statusChangedPayload = Data(
            #"{"threadId":"thread-123","status":{"type":"active","activeFlags":["waitingOnApproval"]}}"#.utf8
        )

        let statusChangedEvent = try #require(
            try decodeEvent(method: "thread/status/changed", payload: statusChangedPayload)
        )

        switch statusChangedEvent {
        case let .threadStatusChanged(notification):
            #expect(notification.threadID == "thread-123")
            #expect(notification.status.type == .active)
            #expect(notification.status.activeFlags == [.waitingOnApproval])
        default:
            Issue.record("Expected thread/status/changed to decode into .threadStatusChanged.")
        }

        let archivedPayload = Data(#"{"threadId":"thread-123"}"#.utf8)
        let archivedEvent = try #require(
            try decodeEvent(method: "thread/archived", payload: archivedPayload)
        )

        switch archivedEvent {
        case let .threadArchived(notification):
            #expect(notification.threadID == "thread-123")
        default:
            Issue.record("Expected thread/archived to decode into .threadArchived.")
        }

        let unarchivedPayload = Data(#"{"threadId":"thread-123"}"#.utf8)
        let unarchivedEvent = try #require(
            try decodeEvent(method: "thread/unarchived", payload: unarchivedPayload)
        )

        switch unarchivedEvent {
        case let .threadUnarchived(notification):
            #expect(notification.threadID == "thread-123")
        default:
            Issue.record("Expected thread/unarchived to decode into .threadUnarchived.")
        }

        let closedPayload = Data(#"{"threadId":"thread-123"}"#.utf8)
        let closedEvent = try #require(
            try decodeEvent(method: "thread/closed", payload: closedPayload)
        )

        switch closedEvent {
        case let .threadClosed(notification):
            #expect(notification.threadID == "thread-123")
        default:
            Issue.record("Expected thread/closed to decode into .threadClosed.")
        }

        let nameUpdatedPayload = Data(
            #"{"threadId":"thread-123","threadName":"Planning Thread"}"#.utf8
        )

        let nameUpdatedEvent = try #require(
            try decodeEvent(method: "thread/name/updated", payload: nameUpdatedPayload)
        )

        switch nameUpdatedEvent {
        case let .threadNameUpdated(notification):
            #expect(notification.threadID == "thread-123")
            #expect(notification.threadName == "Planning Thread")
        default:
            Issue.record("Expected thread/name/updated to decode into .threadNameUpdated.")
        }

        let tokenUsageUpdatedPayload = Data(
            #"""
            {"threadId":"thread-123","turnId":"turn-123","tokenUsage":{"last":{"cachedInputTokens":10,"inputTokens":20,"outputTokens":30,"reasoningOutputTokens":5,"totalTokens":65},"modelContextWindow":200000,"total":{"cachedInputTokens":100,"inputTokens":200,"outputTokens":300,"reasoningOutputTokens":50,"totalTokens":650}}}
            """#.utf8
        )

        let tokenUsageUpdatedEvent = try #require(
            try decodeEvent(method: "thread/tokenUsage/updated", payload: tokenUsageUpdatedPayload)
        )

        switch tokenUsageUpdatedEvent {
        case let .threadTokenUsageUpdated(notification):
            #expect(notification.threadID == "thread-123")
            #expect(notification.turnID == "turn-123")
            #expect(notification.tokenUsage.last.totalTokens == 65)
            #expect(notification.tokenUsage.total.totalTokens == 650)
        default:
            Issue.record("Expected thread/tokenUsage/updated to decode into .threadTokenUsageUpdated.")
        }
    }

    @Test("decodes turn progress notifications into typed protocol events")
    func decodesTurnProgressNotifications() throws {
        let turnStartedPayload = Data(
            #"""
            {"threadId":"thread-123","turn":{"completedAt":null,"durationMs":null,"error":null,"id":"turn-123","items":[],"startedAt":1713350002,"status":"inProgress"}}
            """#.utf8
        )

        let turnStartedEvent = try #require(
            try decodeEvent(method: "turn/started", payload: turnStartedPayload)
        )

        switch turnStartedEvent {
        case let .turnStarted(notification):
            #expect(notification.threadID == "thread-123")
            #expect(notification.turn.id == "turn-123")
            #expect(notification.turn.status == .inProgress)
        default:
            Issue.record("Expected turn/started to decode into .turnStarted.")
        }

        let turnDiffUpdatedPayload = Data(
            #"{"diff":"diff --git a/file.txt b/file.txt","threadId":"thread-123","turnId":"turn-123"}"#.utf8
        )

        let turnDiffUpdatedEvent = try #require(
            try decodeEvent(method: "turn/diff/updated", payload: turnDiffUpdatedPayload)
        )

        switch turnDiffUpdatedEvent {
        case let .turnDiffUpdated(notification):
            #expect(notification.threadID == "thread-123")
            #expect(notification.turnID == "turn-123")
            #expect(notification.diff == "diff --git a/file.txt b/file.txt")
        default:
            Issue.record("Expected turn/diff/updated to decode into .turnDiffUpdated.")
        }

        let turnPlanUpdatedPayload = Data(
            #"""
            {"explanation":"Investigating protocol mapping.","plan":[{"status":"inProgress","step":"Decode additional notifications"},{"status":"pending","step":"Promote them publicly"}],"threadId":"thread-123","turnId":"turn-123"}
            """#.utf8
        )

        let turnPlanUpdatedEvent = try #require(
            try decodeEvent(method: "turn/plan/updated", payload: turnPlanUpdatedPayload)
        )

        switch turnPlanUpdatedEvent {
        case let .turnPlanUpdated(notification):
            #expect(notification.threadID == "thread-123")
            #expect(notification.turnID == "turn-123")
            #expect(notification.explanation == "Investigating protocol mapping.")
            #expect(notification.plan.count == 2)
            #expect(notification.plan.first?.status == .inProgress)
            #expect(notification.plan.last?.status == .pending)
        default:
            Issue.record("Expected turn/plan/updated to decode into .turnPlanUpdated.")
        }
    }

    @Test("decodes item lifecycle and delta notifications into typed protocol events")
    func decodesItemNotifications() throws {
        let itemStartedPayload = Data(
            #"{"item":{"id":"item-123","type":"plan"},"threadId":"thread-123","turnId":"turn-123"}"#.utf8
        )

        let itemStartedEvent = try #require(
            try decodeEvent(method: "item/started", payload: itemStartedPayload)
        )

        switch itemStartedEvent {
        case let .itemStarted(notification):
            #expect(notification.threadID == "thread-123")
            #expect(notification.turnID == "turn-123")
            #expect(notification.item.id == "item-123")
            #expect(notification.item.type == .plan)
        default:
            Issue.record("Expected item/started to decode into .itemStarted.")
        }

        let itemCompletedPayload = Data(
            #"{"item":{"id":"item-123","type":"agentMessage","text":"Done."},"threadId":"thread-123","turnId":"turn-123"}"#.utf8
        )

        let itemCompletedEvent = try #require(
            try decodeEvent(method: "item/completed", payload: itemCompletedPayload)
        )

        switch itemCompletedEvent {
        case let .itemCompleted(notification):
            #expect(notification.threadID == "thread-123")
            #expect(notification.turnID == "turn-123")
            #expect(notification.item.type == .agentMessage)
            #expect(notification.item.text == "Done.")
        default:
            Issue.record("Expected item/completed to decode into .itemCompleted.")
        }

        let agentMessageDeltaPayload = Data(
            #"{"delta":"Hello there","itemId":"item-123","threadId":"thread-123","turnId":"turn-123"}"#.utf8
        )

        let agentMessageDeltaEvent = try #require(
            try decodeEvent(method: "item/agentMessage/delta", payload: agentMessageDeltaPayload)
        )

        switch agentMessageDeltaEvent {
        case let .agentMessageDelta(notification):
            #expect(notification.delta == "Hello there")
            #expect(notification.itemID == "item-123")
            #expect(notification.threadID == "thread-123")
            #expect(notification.turnID == "turn-123")
        default:
            Issue.record("Expected item/agentMessage/delta to decode into .agentMessageDelta.")
        }

        let planDeltaPayload = Data(
            #"{"delta":"Decode protocol events","itemId":"item-456","threadId":"thread-123","turnId":"turn-123"}"#.utf8
        )

        let planDeltaEvent = try #require(
            try decodeEvent(method: "item/plan/delta", payload: planDeltaPayload)
        )

        switch planDeltaEvent {
        case let .planDelta(notification):
            #expect(notification.delta == "Decode protocol events")
            #expect(notification.itemID == "item-456")
            #expect(notification.threadID == "thread-123")
            #expect(notification.turnID == "turn-123")
        default:
            Issue.record("Expected item/plan/delta to decode into .planDelta.")
        }
    }

    @Test("decodes server-originated approval and elicitation requests into typed protocol events")
    func decodesServerRequests() throws {
        let commandApprovalPayload = Data(
            #"""
            {"command":"git status","commandActions":[{"command":"git status","type":"unknown"}],"cwd":"/tmp/project","itemId":"item-command-1","reason":"Needs approval to inspect repository state.","threadId":"thread-123","turnId":"turn-123"}
            """#.utf8
        )

        let commandApprovalEvent = try #require(
            try protocolLayer.decodeServerEvent(
                .request(
                    id: .string("approval-1"),
                    method: "item/commandExecution/requestApproval",
                    payload: commandApprovalPayload
                )
            )
        )

        switch commandApprovalEvent {
        case let .commandExecutionApprovalRequested(request):
            #expect(request.requestID == .string("approval-1"))
            #expect(request.threadID == "thread-123")
            #expect(request.turnID == "turn-123")
            #expect(request.itemID == "item-command-1")
            #expect(request.command == "git status")
        default:
            Issue.record("Expected command approval server request to decode into .commandExecutionApprovalRequested.")
        }

        let toolInputPayload = Data(
            #"""
            {"itemId":"item-input-1","questions":[{"header":"Goal","id":"goal","question":"What should we do next?"}],"threadId":"thread-123","turnId":"turn-123"}
            """#.utf8
        )

        let toolInputEvent = try #require(
            try protocolLayer.decodeServerEvent(
                .request(
                    id: .string("input-1"),
                    method: "item/tool/requestUserInput",
                    payload: toolInputPayload
                )
            )
        )

        switch toolInputEvent {
        case let .toolUserInputRequested(request):
            #expect(request.requestID == .string("input-1"))
            #expect(request.questions.count == 1)
            #expect(request.questions[0].isOther == false)
            #expect(request.questions[0].isSecret == false)
        default:
            Issue.record("Expected tool user input server request to decode into .toolUserInputRequested.")
        }

        let mcpPayload = Data(
            #"""
            {"message":"Authorize the calendar server.","mode":"url","serverName":"calendar","threadId":"thread-123","turnId":null,"url":"https://example.com/authorize","elicitationId":"elicitation-1"}
            """#.utf8
        )

        let mcpEvent = try #require(
            try protocolLayer.decodeServerEvent(
                .request(
                    id: .string("mcp-1"),
                    method: "mcpServer/elicitation/request",
                    payload: mcpPayload
                )
            )
        )

        switch mcpEvent {
        case let .mcpServerElicitationRequested(request):
            #expect(request.requestID == .string("mcp-1"))
            #expect(request.serverName == "calendar")
            #expect(request.threadID == "thread-123")
            #expect(request.turnID == nil)
        default:
            Issue.record("Expected MCP elicitation server request to decode into .mcpServerElicitationRequested.")
        }
    }

    @Test("encodes JSON-RPC server request responses with the expected id and result payload")
    func encodesServerResponses() throws {
        struct ResultPayload: Encodable {
            let decision: String
        }

        let payload = try protocolLayer.makeServerResponse(
            id: .string("approval-1"),
            result: ResultPayload(decision: "accept")
        )

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["jsonrpc"] == nil)
        #expect(object["id"] as? String == "approval-1")
        let result = try #require(object["result"] as? [String: Any])
        #expect(result["decision"] as? String == "accept")
    }

    @Test("decodes reasoning notifications into typed protocol events")
    func decodesReasoningNotifications() throws {
        let summaryPartAddedPayload = Data(
            #"{"itemId":"item-123","summaryIndex":1,"threadId":"thread-123","turnId":"turn-123"}"#.utf8
        )

        let summaryPartAddedEvent = try #require(
            try decodeEvent(method: "item/reasoning/summaryPartAdded", payload: summaryPartAddedPayload)
        )

        switch summaryPartAddedEvent {
        case let .reasoningSummaryPartAdded(notification):
            #expect(notification.itemID == "item-123")
            #expect(notification.summaryIndex == 1)
            #expect(notification.threadID == "thread-123")
            #expect(notification.turnID == "turn-123")
        default:
            Issue.record("Expected item/reasoning/summaryPartAdded to decode into .reasoningSummaryPartAdded.")
        }

        let summaryTextDeltaPayload = Data(
            #"{"delta":"refining the plan","itemId":"item-123","summaryIndex":1,"threadId":"thread-123","turnId":"turn-123"}"#.utf8
        )

        let summaryTextDeltaEvent = try #require(
            try decodeEvent(method: "item/reasoning/summaryTextDelta", payload: summaryTextDeltaPayload)
        )

        switch summaryTextDeltaEvent {
        case let .reasoningSummaryTextDelta(notification):
            #expect(notification.delta == "refining the plan")
            #expect(notification.itemID == "item-123")
            #expect(notification.summaryIndex == 1)
        default:
            Issue.record("Expected item/reasoning/summaryTextDelta to decode into .reasoningSummaryTextDelta.")
        }

        let reasoningTextDeltaPayload = Data(
            #"{"contentIndex":0,"delta":"thinking...","itemId":"item-123","threadId":"thread-123","turnId":"turn-123"}"#.utf8
        )

        let reasoningTextDeltaEvent = try #require(
            try decodeEvent(method: "item/reasoning/textDelta", payload: reasoningTextDeltaPayload)
        )

        switch reasoningTextDeltaEvent {
        case let .reasoningTextDelta(notification):
            #expect(notification.contentIndex == 0)
            #expect(notification.delta == "thinking...")
            #expect(notification.itemID == "item-123")
            #expect(notification.threadID == "thread-123")
            #expect(notification.turnID == "turn-123")
        default:
            Issue.record("Expected item/reasoning/textDelta to decode into .reasoningTextDelta.")
        }
    }

    private func decodeEvent(
        method: String,
        payload: Data
    ) throws -> CodexAppServerProtocolEvent? {
        try protocolLayer.decodeServerEvent(.notification(method: method, payload: payload))
    }
}
