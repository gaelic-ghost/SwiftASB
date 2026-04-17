import Foundation
import Testing
@testable import SwiftASB

@Suite("CodexAppServer")
struct CodexAppServerTests {
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

    @Test("runs initialize, thread/start, and turn/start through the public client")
    func runsInitializeAndFirstLifecycleRequests() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()

        let initializeSession = try await client.initialize(
            .init(
                capabilities: .init(
                    experimentalAPI: true,
                    optOutNotificationMethods: ["turn/completed"]
                ),
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        #expect(initializeSession.codexHome == "/Users/galew/.codex")
        #expect(initializeSession.platformFamily == "unix")
        #expect(initializeSession.platformOS == "macos")
        #expect(initializeSession.userAgent == "codex-cli/0.121.0")

        let thread = try await client.startThread(
            .init(
                approvalPolicy: .onRequest,
                currentDirectoryPath: "/tmp/project",
                ephemeral: false,
                model: "gpt-5.4",
                modelProvider: "openai",
                sandboxMode: .workspaceWrite,
                serviceTier: .fast,
                sessionStartSource: .clear
            )
        )

        #expect(thread.model == "gpt-5.4")
        #expect(thread.modelProvider == "openai")
        #expect(thread.currentDirectoryPath == "/tmp/project")
        #expect(thread.serviceTier == .fast)
        #expect(thread.id == "thread-123")
        #expect(thread.info.status.type == .active)
        #expect(thread.info.preview == "Hello from the fake app-server")

        let turnHandle = try await thread.startTextTurn(
            "Hello from SwiftASB",
            effort: .medium,
            model: "gpt-5.4",
            summary: .concise
        )

        #expect(turnHandle.threadID == thread.id)
        #expect(turnHandle.turn.id == "turn-123")
        #expect(turnHandle.turn.status == .inProgress)
        #expect(turnHandle.turn.startedAt == 1713350002)

        let firstEventTask = Task {
            try await firstTurnEvent(from: turnHandle.events)
        }

        await transport.emitTurnCompleted(
            threadID: thread.id,
            turnID: turnHandle.turn.id
        )

        let firstEventResult = try await firstEventTask.value
        let turnEvent = try #require(firstEventResult)

        switch turnEvent {
        case let .completed(completion):
            #expect(completion.threadID == thread.id)
            #expect(completion.turn.id == turnHandle.turn.id)
            #expect(completion.turn.status == CodexAppServer.TurnStatus.completed)
            #expect(completion.turn.completedAt == 1713350005)
        }

        let recordedMethods = await transport.recordedMethods
        #expect(recordedMethods == ["initialize", "initialized", "thread/start", "turn/start"])

        await client.stop()
    }
}

private actor FakeCodexAppServerTransport: CodexAppServerTransporting {
    private(set) var recordedMethods: [String] = []
    private var started = false
    private var initializedSeen = false
    private var serverEventContinuation: AsyncStream<CodexRPCServerEvent>.Continuation?

    func start() throws {
        started = true
        initializedSeen = false
    }

    func stop() {
        started = false
        serverEventContinuation?.finish()
        serverEventContinuation = nil
    }

    func send(_ requestPayload: Data, id: CodexRPCRequestID) async throws -> Data {
        guard started else {
            throw CodexTransportError.notStarted
        }

        let method = try requestMethod(from: requestPayload)
        recordedMethods.append(method)

        switch method {
        case "initialize":
            return responsePayload(
                id: id,
                result: [
                    "codexHome": "/Users/galew/.codex",
                    "platformFamily": "unix",
                    "platformOs": "macos",
                    "userAgent": "codex-cli/0.121.0",
                ]
            )
        case "thread/start":
            if !initializedSeen {
                return errorPayload(
                    id: id,
                    code: -32000,
                    message: "initialized notification missing"
                )
            }

            return responsePayload(
                id: id,
                result: [
                    "approvalPolicy": "on-request",
                    "approvalsReviewer": "user",
                    "cwd": "/tmp/project",
                    "instructionSources": ["AGENTS.md"],
                    "model": "gpt-5.4",
                    "modelProvider": "openai",
                    "reasoningEffort": "medium",
                    "sandbox": [
                        "type": "workspaceWrite",
                        "networkAccess": "enabled",
                        "writableRoots": ["/tmp/project"],
                    ],
                    "serviceTier": "fast",
                    "thread": [
                        "cliVersion": "0.121.0",
                        "createdAt": 1713350000,
                        "cwd": "/tmp/project",
                        "ephemeral": false,
                        "id": "thread-123",
                        "modelProvider": "openai",
                        "preview": "Hello from the fake app-server",
                        "source": "cli",
                        "status": ["type": "active"],
                        "turns": [],
                        "updatedAt": 1713350001,
                    ],
                ]
            )
        case "turn/start":
            return responsePayload(
                id: id,
                result: [
                    "turn": [
                        "completedAt": NSNull(),
                        "durationMs": NSNull(),
                        "error": NSNull(),
                        "id": "turn-123",
                        "items": [],
                        "startedAt": 1713350002,
                        "status": "inProgress",
                    ],
                ]
            )
        default:
            return errorPayload(
                id: id,
                code: -32601,
                message: "unsupported method in fake transport"
            )
        }
    }

    func sendNotification(_ notificationPayload: Data, method: String) throws {
        guard started else {
            throw CodexTransportError.notStarted
        }

        recordedMethods.append(method)

        if method == "initialized" {
            initializedSeen = true
        }
    }

    func serverEvents() -> AsyncStream<CodexRPCServerEvent> {
        AsyncStream { continuation in
            serverEventContinuation = continuation
            continuation.onTermination = { _ in
                Task {
                    await self.clearServerEventContinuation()
                }
            }
        }
    }

    func emitTurnCompleted(threadID: String, turnID: String) {
        let payload = payloadObject([
            "threadId": threadID,
            "turn": [
                "completedAt": 1713350005,
                "durationMs": 3000,
                "error": NSNull(),
                "id": turnID,
                "items": [],
                "startedAt": 1713350002,
                "status": "completed",
            ],
        ])

        serverEventContinuation?.yield(
            .notification(method: "turn/completed", payload: payload)
        )
    }

    private func requestMethod(from payload: Data) throws -> String {
        let object = try #require(
            try JSONSerialization.jsonObject(with: payload) as? [String: Any]
        )
        return try #require(object["method"] as? String)
    }

    private func responsePayload(id: CodexRPCRequestID, result: [String: Any]) -> Data {
        payloadObject([
            "id": id.jsonObjectValue,
            "result": result,
        ])
    }

    private func errorPayload(id: CodexRPCRequestID, code: Int, message: String) -> Data {
        payloadObject([
            "id": id.jsonObjectValue,
            "error": [
                "code": code,
                "message": message,
            ],
        ])
    }

    private func payloadObject(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }

    private func clearServerEventContinuation() {
        serverEventContinuation = nil
    }
}

private func firstTurnEvent(
    from stream: AsyncThrowingStream<CodexTurnEvent, Error>
) async throws -> CodexTurnEvent? {
    var iterator = stream.makeAsyncIterator()
    return try await iterator.next()
}

private extension CodexRPCRequestID {
    var jsonObjectValue: Any {
        switch self {
        case let .string(value):
            value
        case let .int(value):
            value
        }
    }
}
