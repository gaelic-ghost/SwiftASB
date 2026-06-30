import Foundation
@testable import SwiftASB
import Testing

@Suite(.serialized)
struct CodexAppServerProtocolTests {
    private let protocolLayer = CodexAppServerProtocol()

    @Test("encodes initialize requests with the expected method and params payload")
    func encodesInitializeRequest() throws {
        let payload = try protocolLayer.makeInitializeRequest(
            id: .string("init-1"),
            params: CodexWireInitializeParams(
                capabilities: CodexWireInitializeCapabilities(
                    experimentalAPI: true,
                    mcpServerOpenaiFormElicitation: nil,
                    optOutNotificationMethods: ["thread/started"],
                    requestAttestation: nil
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

    @Test("encodes command/exec without permission or sandbox overrides by default")
    func encodesCommandExecWithConfiguredPermissionDefaults() throws {
        let payload = try protocolLayer.makeCommandExecRequest(
            id: .string("command-exec-1"),
            params: .init(
                command: ["git", "status", "--short"],
                cwd: "/tmp/project",
                disableOutputCap: nil,
                disableTimeout: nil,
                env: nil,
                outputBytesCap: 16384,
                permissionProfile: nil,
                processID: nil,
                sandboxPolicy: nil,
                size: nil,
                streamStdin: nil,
                streamStdoutStderr: nil,
                timeoutMS: 5000,
                tty: nil
            )
        )

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["jsonrpc"] == nil)
        #expect(object["method"] as? String == "command/exec")
        #expect(object["id"] as? String == "command-exec-1")

        let params = try #require(object["params"] as? [String: Any])
        #expect(params["command"] as? [String] == ["git", "status", "--short"])
        #expect(params["cwd"] as? String == "/tmp/project")
        #expect(params["outputBytesCap"] as? Int == 16384)
        #expect(params["timeoutMs"] as? Int == 5000)
        #expect(params["permissionProfile"] == nil)
        #expect(params["sandboxPolicy"] == nil)
        #expect(params["processId"] == nil)
        #expect(params["streamStdoutStderr"] == nil)
    }

    @Test("decodes command/exec output as connection-scoped command output")
    func decodesCommandExecOutputAsConnectionScopedOutput() throws {
        let payload = try #require(
            #"{"capReached":false,"deltaBase64":"aGVsbG8K","processId":"swiftasb-command-1","stream":"stdout"}"#
                .data(using: .utf8)
        )

        let event = try protocolLayer.decodeServerEvent(
            .notification(method: "command/exec/outputDelta", payload: payload)
        )

        guard case let .commandExecOutputDelta(notification) = event else {
            Issue.record("Expected command/exec output to decode separately from thread command-execution output.")
            return
        }

        #expect(notification.processID == "swiftasb-command-1")
        #expect(notification.deltaBase64 == "aGVsbG8K")
        #expect(notification.stream == .stdout)
        #expect(notification.capReached == false)
    }

    @Test("encodes thread/shellCommand as a thread-scoped shell string")
    func encodesThreadShellCommandAsThreadScopedShellString() throws {
        let payload = try protocolLayer.makeThreadShellCommandRequest(
            id: .string("thread-shell-1"),
            params: .init(
                command: "printf 'hi' | tee output.txt",
                threadID: "thread-123"
            )
        )

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["jsonrpc"] == nil)
        #expect(object["method"] as? String == "thread/shellCommand")
        #expect(object["id"] as? String == "thread-shell-1")

        let params = try #require(object["params"] as? [String: Any])
        #expect(params["command"] as? String == "printf 'hi' | tee output.txt")
        #expect(params["threadId"] as? String == "thread-123")
    }

    @Test("encodes thread guardian denied-action approval requests")
    func encodesThreadGuardianDeniedActionApprovalRequest() throws {
        let payload = try protocolLayer.makeThreadApproveGuardianDeniedActionRequest(
            id: .string("guardian-approval-1"),
            params: .init(
                event: .object([
                    "assessmentId": .string("assessment-123"),
                    "status": .string("denied"),
                ]),
                threadID: "thread-123"
            )
        )

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["jsonrpc"] == nil)
        #expect(object["method"] as? String == "thread/approveGuardianDeniedAction")
        #expect(object["id"] as? String == "guardian-approval-1")

        let params = try #require(object["params"] as? [String: Any])
        #expect(params["threadId"] as? String == "thread-123")
        let event = try #require(params["event"] as? [String: Any])
        #expect(event["assessmentId"] as? String == "assessment-123")
        #expect(event["status"] as? String == "denied")

        let responsePayload = #"{"id":"guardian-approval-1","result":{}}"#.data(using: .utf8)!
        #expect(
            try protocolLayer.decodeThreadApproveGuardianDeniedActionResponse(
                responsePayload,
                expectedID: .string("guardian-approval-1")
            ) == .init()
        )
    }

    @Test("encodes review/start with subject and placement")
    func encodesReviewStartWithSubjectAndPlacement() throws {
        let payload = try protocolLayer.makeReviewStartRequest(
            id: .string("review-start-1"),
            params: .init(
                delivery: .detached,
                target: .init(
                    type: .baseBranch,
                    branch: "main",
                    sha: nil,
                    title: nil,
                    instructions: nil
                ),
                threadID: "thread-123"
            )
        )

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["jsonrpc"] == nil)
        #expect(object["method"] as? String == "review/start")
        #expect(object["id"] as? String == "review-start-1")

        let params = try #require(object["params"] as? [String: Any])
        #expect(params["delivery"] as? String == "detached")
        #expect(params["threadId"] as? String == "thread-123")

        let target = try #require(params["target"] as? [String: Any])
        #expect(target["type"] as? String == "baseBranch")
        #expect(target["branch"] as? String == "main")
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
                dynamicTools: nil,
                environments: nil,
                ephemeral: true,
                experimentalRawEvents: nil,
                mockExperimentalField: nil,
                model: "gpt-5.4",
                modelProvider: "openai",
                multiAgentMode: nil,
                permissions: ":workspace",
                personality: .friendly,
                runtimeWorkspaceRoots: nil,
                sandbox: .workspaceWrite,
                selectedCapabilityRoots: nil,
                serviceName: "codex",
                serviceTier: "fast",
                sessionStartSource: .clear,
                threadSource: nil
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

        #expect(params["permissions"] as? String == ":workspace")
    }

    @Test("encodes thread/list requests with the expected method and params payload")
    func encodesThreadListRequest() throws {
        let payload = try protocolLayer.makeThreadListRequest(
            id: .string("thread-list-1"),
            params: .init(
                archived: false,
                cursor: "cursor-older",
                cwd: "/tmp/project",
                limit: 25,
                modelProviders: ["openai", "azure"],
                searchTerm: "release work",
                sortDirection: .asc,
                sortKey: .updatedAt,
                sourceKinds: [.cli, .vscode]
            )
        )

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["jsonrpc"] == nil)
        #expect(object["method"] as? String == "thread/list")
        #expect(object["id"] as? String == "thread-list-1")

        let params = try #require(object["params"] as? [String: Any])
        #expect(params["archived"] as? Bool == false)
        #expect(params["cursor"] as? String == "cursor-older")
        #expect(params["cwd"] as? String == "/tmp/project")
        #expect(params["limit"] as? Int == 25)
        #expect(params["modelProviders"] as? [String] == ["openai", "azure"])
        #expect(params["searchTerm"] as? String == "release work")
        #expect(params["sortDirection"] as? String == "asc")
        #expect(params["sortKey"] as? String == "updated_at")
        #expect(params["sourceKinds"] as? [String] == ["cli", "vscode"])
    }

    @Test("encodes read-only fs requests with app-server method names")
    func encodesReadOnlyFSRequests() throws {
        let metadataPayload = try protocolLayer.makeFSGetMetadataRequest(
            id: .string("metadata-1"),
            params: .init(path: "/tmp/project")
        )
        let metadataRequest = try #require(try JSONSerialization.jsonObject(with: metadataPayload) as? [String: Any])
        #expect(metadataRequest["method"] as? String == "fs/getMetadata")
        #expect((metadataRequest["params"] as? [String: Any])?["path"] as? String == "/tmp/project")

        let directoryPayload = try protocolLayer.makeFSReadDirectoryRequest(
            id: .string("directory-1"),
            params: .init(path: "/tmp/project/Sources")
        )
        let directoryRequest = try #require(try JSONSerialization.jsonObject(with: directoryPayload) as? [String: Any])
        #expect(directoryRequest["method"] as? String == "fs/readDirectory")
        #expect((directoryRequest["params"] as? [String: Any])?["path"] as? String == "/tmp/project/Sources")

        let filePayload = try protocolLayer.makeFSReadFileRequest(
            id: .string("file-1"),
            params: .init(path: "/tmp/project/README.md")
        )
        let fileRequest = try #require(try JSONSerialization.jsonObject(with: filePayload) as? [String: Any])
        #expect(fileRequest["method"] as? String == "fs/readFile")
        #expect((fileRequest["params"] as? [String: Any])?["path"] as? String == "/tmp/project/README.md")

        let watchPayload = try protocolLayer.makeFSWatchRequest(
            id: .string("watch-1"),
            params: .init(path: "/tmp/project", watchID: "watch-123")
        )
        let watchRequest = try #require(try JSONSerialization.jsonObject(with: watchPayload) as? [String: Any])
        #expect(watchRequest["method"] as? String == "fs/watch")
        #expect((watchRequest["params"] as? [String: Any])?["watchId"] as? String == "watch-123")

        let unwatchPayload = try protocolLayer.makeFSUnwatchRequest(
            id: .string("unwatch-1"),
            params: .init(watchID: "watch-123")
        )
        let unwatchRequest = try #require(try JSONSerialization.jsonObject(with: unwatchPayload) as? [String: Any])
        #expect(unwatchRequest["method"] as? String == "fs/unwatch")
        #expect((unwatchRequest["params"] as? [String: Any])?["watchId"] as? String == "watch-123")
    }

    @Test("encodes internal fs mutation requests with app-server method names")
    func encodesInternalFSMutationRequests() throws {
        let writePayload = try protocolLayer.makeFSWriteFileRequest(
            id: .string("write-file-1"),
            params: .init(
                dataBase64: Data("Hello".utf8).base64EncodedString(),
                path: "/tmp/project/README.md"
            )
        )
        let writeRequest = try #require(try JSONSerialization.jsonObject(with: writePayload) as? [String: Any])
        #expect(writeRequest["method"] as? String == "fs/writeFile")
        let writeParams = try #require(writeRequest["params"] as? [String: Any])
        #expect(writeParams["dataBase64"] as? String == "SGVsbG8=")
        #expect(writeParams["path"] as? String == "/tmp/project/README.md")

        let createDirectoryPayload = try protocolLayer.makeFSCreateDirectoryRequest(
            id: .string("create-directory-1"),
            params: .init(path: "/tmp/project/Sources/New", recursive: true)
        )
        let createDirectoryRequest = try #require(
            try JSONSerialization.jsonObject(with: createDirectoryPayload) as? [String: Any]
        )
        #expect(createDirectoryRequest["method"] as? String == "fs/createDirectory")
        let createDirectoryParams = try #require(createDirectoryRequest["params"] as? [String: Any])
        #expect(createDirectoryParams["path"] as? String == "/tmp/project/Sources/New")
        #expect(createDirectoryParams["recursive"] as? Bool == true)

        let removePayload = try protocolLayer.makeFSRemoveRequest(
            id: .string("remove-1"),
            params: .init(force: false, path: "/tmp/project/obsolete.txt", recursive: false)
        )
        let removeRequest = try #require(try JSONSerialization.jsonObject(with: removePayload) as? [String: Any])
        #expect(removeRequest["method"] as? String == "fs/remove")
        let removeParams = try #require(removeRequest["params"] as? [String: Any])
        #expect(removeParams["force"] as? Bool == false)
        #expect(removeParams["path"] as? String == "/tmp/project/obsolete.txt")
        #expect(removeParams["recursive"] as? Bool == false)

        let copyPayload = try protocolLayer.makeFSCopyRequest(
            id: .string("copy-1"),
            params: .init(
                destinationPath: "/tmp/project/copy.txt",
                recursive: nil,
                sourcePath: "/tmp/project/source.txt"
            )
        )
        let copyRequest = try #require(try JSONSerialization.jsonObject(with: copyPayload) as? [String: Any])
        #expect(copyRequest["method"] as? String == "fs/copy")
        let copyParams = try #require(copyRequest["params"] as? [String: Any])
        #expect(copyParams["destinationPath"] as? String == "/tmp/project/copy.txt")
        #expect(copyParams["recursive"] == nil)
        #expect(copyParams["sourcePath"] as? String == "/tmp/project/source.txt")
    }

    @Test("decodes internal fs mutation responses")
    func decodesInternalFSMutationResponses() throws {
        let writePayload = #"{"id":"write-file-1","result":{}}"#.data(using: .utf8)!
        let createDirectoryPayload = #"{"id":"create-directory-1","result":{}}"#.data(using: .utf8)!
        let removePayload = #"{"id":"remove-1","result":{}}"#.data(using: .utf8)!
        let copyPayload = #"{"id":"copy-1","result":{}}"#.data(using: .utf8)!

        #expect(
            try protocolLayer.decodeFSWriteFileResponse(
                writePayload,
                expectedID: .string("write-file-1")
            ) == .init()
        )
        #expect(
            try protocolLayer.decodeFSCreateDirectoryResponse(
                createDirectoryPayload,
                expectedID: .string("create-directory-1")
            ) == .init()
        )
        #expect(
            try protocolLayer.decodeFSRemoveResponse(
                removePayload,
                expectedID: .string("remove-1")
            ) == .init()
        )
        #expect(
            try protocolLayer.decodeFSCopyResponse(
                copyPayload,
                expectedID: .string("copy-1")
            ) == .init()
        )
    }

    @Test("encodes loaded-thread list requests")
    func encodesLoadedThreadListRequest() throws {
        let payload = try protocolLayer.makeThreadLoadedListRequest(
            id: .string("loaded-1"),
            params: .init(cursor: "cursor-loaded", limit: 3)
        )

        let request = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(request["method"] as? String == "thread/loaded/list")
        let params = try #require(request["params"] as? [String: Any])
        #expect(params["cursor"] as? String == "cursor-loaded")
        #expect(params["limit"] as? Int == 3)
    }

    @Test("encodes thread goal requests")
    func encodesThreadGoalRequests() throws {
        let getPayload = try protocolLayer.makeThreadGoalGetRequest(
            id: .string("goal-get-1"),
            params: .init(threadID: "thread-123")
        )
        let getRequest = try #require(try JSONSerialization.jsonObject(with: getPayload) as? [String: Any])
        #expect(getRequest["method"] as? String == "thread/goal/get")
        #expect((getRequest["params"] as? [String: Any])?["threadId"] as? String == "thread-123")

        let setPayload = try protocolLayer.makeThreadGoalSetRequest(
            id: .string("goal-set-1"),
            params: .init(
                objective: "Ship schema promotion",
                status: .active,
                threadID: "thread-123",
                tokenBudget: 20000
            )
        )
        let setRequest = try #require(try JSONSerialization.jsonObject(with: setPayload) as? [String: Any])
        #expect(setRequest["method"] as? String == "thread/goal/set")
        #expect((setRequest["params"] as? [String: Any])?["status"] as? String == "active")

        let clearPayload = try protocolLayer.makeThreadGoalClearRequest(
            id: .string("goal-clear-1"),
            params: .init(threadID: "thread-123")
        )
        let clearRequest = try #require(try JSONSerialization.jsonObject(with: clearPayload) as? [String: Any])
        #expect(clearRequest["method"] as? String == "thread/goal/clear")
        #expect((clearRequest["params"] as? [String: Any])?["threadId"] as? String == "thread-123")
    }

    @Test("encodes thread/read requests with the expected method and params payload")
    func encodesThreadReadRequest() throws {
        let payload = try protocolLayer.makeThreadReadRequest(
            id: .string("thread-read-1"),
            params: .init(
                includeTurns: true,
                threadID: "thread-123"
            )
        )

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["jsonrpc"] == nil)
        #expect(object["method"] as? String == "thread/read")
        #expect(object["id"] as? String == "thread-read-1")

        let params = try #require(object["params"] as? [String: Any])
        #expect(params["includeTurns"] as? Bool == true)
        #expect(params["threadId"] as? String == "thread-123")
    }

    @Test("encodes thread/resume requests with the expected method and params payload")
    func encodesThreadResumeRequest() throws {
        let payload = try protocolLayer.makeThreadResumeRequest(
            id: .string("thread-resume-1"),
            params: .init(
                approvalPolicy: .enumeration(.onFailure),
                approvalsReviewer: .guardianSubagent,
                baseInstructions: "Carry forward the working style.",
                config: ["temperature": .double(0.15)],
                cwd: "/tmp/project",
                developerInstructions: "Keep the answer concise.",
                excludeTurns: true,
                model: "gpt-5.4",
                modelProvider: "openai",
                permissions: nil,
                personality: .friendly,
                sandbox: .workspaceWrite,
                serviceName: "codex",
                serviceTier: "fast",
                threadID: "thread-123"
            )
        )

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["jsonrpc"] == nil)
        #expect(object["method"] as? String == "thread/resume")
        #expect(object["id"] as? String == "thread-resume-1")

        let params = try #require(object["params"] as? [String: Any])
        #expect(params["threadId"] as? String == "thread-123")
        #expect(params["cwd"] as? String == "/tmp/project")
        #expect(params["model"] as? String == "gpt-5.4")
        #expect(params["modelProvider"] as? String == "openai")
        #expect(params["personality"] as? String == "friendly")
        #expect(params["serviceTier"] as? String == "fast")
        #expect(params["excludeTurns"] as? Bool == true)

        let config = try #require(params["config"] as? [String: Any])
        #expect(config["temperature"] as? Double == 0.15)
    }

    @Test("encodes thread/fork requests with the expected method and params payload")
    func encodesThreadForkRequest() throws {
        let payload = try protocolLayer.makeThreadForkRequest(
            id: .string("thread-fork-1"),
            params: .init(
                approvalPolicy: .enumeration(.onRequest),
                approvalsReviewer: .user,
                baseInstructions: "Branch from the existing work.",
                config: ["temperature": .double(0.2)],
                cwd: "/tmp/project",
                developerInstructions: "Keep the fork focused.",
                ephemeral: true,
                excludeTurns: true,
                model: "gpt-5.4",
                modelProvider: "openai",
                permissions: nil,
                personality: .pragmatic,
                sandbox: .workspaceWrite,
                serviceName: "codex",
                serviceTier: "fast",
                threadID: "thread-123"
            )
        )

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["jsonrpc"] == nil)
        #expect(object["method"] as? String == "thread/fork")
        #expect(object["id"] as? String == "thread-fork-1")

        let params = try #require(object["params"] as? [String: Any])
        #expect(params["threadId"] as? String == "thread-123")
        #expect(params["cwd"] as? String == "/tmp/project")
        #expect(params["ephemeral"] as? Bool == true)
        #expect(params["excludeTurns"] as? Bool == true)
        #expect(params["model"] as? String == "gpt-5.4")
        #expect(params["personality"] as? String == "pragmatic")
        #expect(params["serviceTier"] as? String == "fast")

        let config = try #require(params["config"] as? [String: Any])
        #expect(config["temperature"] as? Double == 0.2)
    }

    @Test("encodes thread/turns/list requests with the expected method and params payload")
    func encodesThreadTurnsListRequest() throws {
        let payload = try protocolLayer.makeThreadTurnsListRequest(
            id: .string("thread-turns-list-1"),
            params: .init(
                cursor: "cursor-newer",
                itemsView: .full,
                limit: 10,
                sortDirection: .desc,
                threadID: "thread-123"
            )
        )

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["jsonrpc"] == nil)
        #expect(object["method"] as? String == "thread/turns/list")
        #expect(object["id"] as? String == "thread-turns-list-1")

        let params = try #require(object["params"] as? [String: Any])
        #expect(params["cursor"] as? String == "cursor-newer")
        #expect(params["itemsView"] as? String == "full")
        #expect(params["limit"] as? Int == 10)
        #expect(params["sortDirection"] as? String == "desc")
        #expect(params["threadId"] as? String == "thread-123")
    }

    @Test("encodes thread/turns/items/list requests with the expected method and params payload")
    func encodesThreadTurnsItemsListRequest() throws {
        let payload = try protocolLayer.makeThreadTurnsItemsListRequest(
            id: .string("thread-turns-items-list-1"),
            params: .init(
                cursor: "cursor-items",
                limit: 20,
                sortDirection: .asc,
                threadID: "thread-123",
                turnID: "turn-456"
            )
        )

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["jsonrpc"] == nil)
        #expect(object["method"] as? String == "thread/turns/items/list")
        #expect(object["id"] as? String == "thread-turns-items-list-1")

        let params = try #require(object["params"] as? [String: Any])
        #expect(params["cursor"] as? String == "cursor-items")
        #expect(params["limit"] as? Int == 20)
        #expect(params["sortDirection"] as? String == "asc")
        #expect(params["threadId"] as? String == "thread-123")
        #expect(params["turnId"] as? String == "turn-456")
    }

    @Test("encodes thread/compact/start requests with the expected method and params payload")
    func encodesThreadCompactStartRequest() throws {
        let payload = try protocolLayer.makeThreadCompactStartRequest(
            id: .string("thread-compact-1"),
            params: .init(threadID: "thread-123")
        )

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["jsonrpc"] == nil)
        #expect(object["method"] as? String == "thread/compact/start")
        #expect(object["id"] as? String == "thread-compact-1")

        let params = try #require(object["params"] as? [String: Any])
        #expect(params["threadId"] as? String == "thread-123")
    }

    @Test("encodes thread/rollback requests with the expected method and params payload")
    func encodesThreadRollbackRequest() throws {
        let payload = try protocolLayer.makeThreadRollbackRequest(
            id: .string("thread-rollback-1"),
            params: .init(numTurns: 2, threadID: "thread-123")
        )

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["jsonrpc"] == nil)
        #expect(object["method"] as? String == "thread/rollback")
        #expect(object["id"] as? String == "thread-rollback-1")

        let params = try #require(object["params"] as? [String: Any])
        #expect(params["threadId"] as? String == "thread-123")
        #expect(params["numTurns"] as? Int == 2)
    }

    @Test("encodes thread archive-state requests with the expected method and params payload")
    func encodesThreadArchiveStateRequests() throws {
        let archivePayload = try protocolLayer.makeThreadArchiveRequest(
            id: .string("thread-archive-1"),
            params: .init(threadID: "thread-123")
        )
        let unarchivePayload = try protocolLayer.makeThreadUnarchiveRequest(
            id: .string("thread-unarchive-1"),
            params: .init(threadID: "thread-123")
        )

        let archive = try #require(try JSONSerialization.jsonObject(with: archivePayload) as? [String: Any])
        #expect(archive["method"] as? String == "thread/archive")
        #expect(archive["id"] as? String == "thread-archive-1")
        let archiveParams = try #require(archive["params"] as? [String: Any])
        #expect(archiveParams["threadId"] as? String == "thread-123")

        let unarchive = try #require(try JSONSerialization.jsonObject(with: unarchivePayload) as? [String: Any])
        #expect(unarchive["method"] as? String == "thread/unarchive")
        #expect(unarchive["id"] as? String == "thread-unarchive-1")
        let unarchiveParams = try #require(unarchive["params"] as? [String: Any])
        #expect(unarchiveParams["threadId"] as? String == "thread-123")
    }

    @Test("encodes thread/name/set requests with the expected method and params payload")
    func encodesThreadSetNameRequest() throws {
        let payload = try protocolLayer.makeThreadSetNameRequest(
            id: .string("thread-name-1"),
            params: .init(name: "Planning Thread", threadID: "thread-123")
        )

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["jsonrpc"] == nil)
        #expect(object["method"] as? String == "thread/name/set")
        #expect(object["id"] as? String == "thread-name-1")

        let params = try #require(object["params"] as? [String: Any])
        #expect(params["threadId"] as? String == "thread-123")
        #expect(params["name"] as? String == "Planning Thread")
    }

    @Test("encodes thread/metadata/update requests with replace, clear, and unchanged fields")
    func encodesThreadMetadataUpdateRequest() throws {
        let payload = try protocolLayer.makeThreadMetadataUpdateRequest(
            id: .string("thread-metadata-1"),
            params: .init(
                gitInfo: .init(
                    branch: .replace("main"),
                    originURL: .clear,
                    sha: .unchanged
                ),
                threadID: "thread-123"
            )
        )

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["jsonrpc"] == nil)
        #expect(object["method"] as? String == "thread/metadata/update")
        #expect(object["id"] as? String == "thread-metadata-1")

        let params = try #require(object["params"] as? [String: Any])
        #expect(params["threadId"] as? String == "thread-123")

        let gitInfo = try #require(params["gitInfo"] as? [String: Any])
        #expect(gitInfo["branch"] as? String == "main")
        #expect(gitInfo["originUrl"] is NSNull)
        #expect(gitInfo["sha"] == nil)
    }

    @Test("encodes model/list requests with the expected method and params payload")
    func encodesModelListRequest() throws {
        let payload = try protocolLayer.makeModelListRequest(
            id: .string("model-list-1"),
            params: .init(
                cursor: "cursor-start",
                includeHidden: true,
                limit: 10
            )
        )

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["jsonrpc"] == nil)
        #expect(object["method"] as? String == "model/list")
        #expect(object["id"] as? String == "model-list-1")

        let params = try #require(object["params"] as? [String: Any])
        #expect(params["cursor"] as? String == "cursor-start")
        #expect(params["includeHidden"] as? Bool == true)
        #expect(params["limit"] as? Int == 10)
    }

    @Test("encodes modelProvider/capabilities/read requests with empty params")
    func encodesModelProviderCapabilitiesReadRequest() throws {
        let payload = try protocolLayer.makeModelProviderCapabilitiesReadRequest(
            id: .string("model-capabilities-1"),
            params: .init()
        )

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["jsonrpc"] == nil)
        #expect(object["method"] as? String == "modelProvider/capabilities/read")
        #expect(object["id"] as? String == "model-capabilities-1")
        let params = try #require(object["params"] as? [String: Any])
        #expect(params.isEmpty)
    }

    @Test("encodes mcpServerStatus/list requests with the expected method and params payload")
    func encodesMcpServerStatusListRequest() throws {
        let payload = try protocolLayer.makeMcpServerStatusListRequest(
            id: .string("mcp-status-1"),
            params: .init(
                cursor: "cursor-start",
                detail: .toolsAndAuthOnly,
                limit: 10,
                threadID: nil
            )
        )

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["jsonrpc"] == nil)
        #expect(object["method"] as? String == "mcpServerStatus/list")
        #expect(object["id"] as? String == "mcp-status-1")

        let params = try #require(object["params"] as? [String: Any])
        #expect(params["cursor"] as? String == "cursor-start")
        #expect(params["detail"] as? String == "toolsAndAuthOnly")
        #expect(params["limit"] as? Int == 10)
    }

    @Test("encodes mcpServer/resource/read requests with the expected method and params payload")
    func encodesMcpResourceReadRequest() throws {
        let payload = try protocolLayer.makeMcpResourceReadRequest(
            id: .string("mcp-resource-1"),
            params: .init(
                server: "calendar",
                threadID: "thread-123",
                uri: "calendar://events/today"
            )
        )

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["jsonrpc"] == nil)
        #expect(object["method"] as? String == "mcpServer/resource/read")
        #expect(object["id"] as? String == "mcp-resource-1")

        let params = try #require(object["params"] as? [String: Any])
        #expect(params["server"] as? String == "calendar")
        #expect(params["threadId"] as? String == "thread-123")
        #expect(params["uri"] as? String == "calendar://events/today")
    }

    @Test("encodes hooks/list requests with the expected method and params payload")
    func encodesHooksListRequest() throws {
        let payload = try protocolLayer.makeHooksListRequest(
            id: .string("hooks-list-1"),
            params: .init(cwds: ["/tmp/project", "/tmp/second-project"])
        )

        let object = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["jsonrpc"] == nil)
        #expect(object["method"] as? String == "hooks/list")
        #expect(object["id"] as? String == "hooks-list-1")

        let params = try #require(object["params"] as? [String: Any])
        #expect(params["cwds"] as? [String] == ["/tmp/project", "/tmp/second-project"])
    }

    @Test("encodes config and extension inventory requests")
    func encodesConfigAndExtensionInventoryRequests() throws {
        let configPayload = try protocolLayer.makeConfigReadRequest(
            id: .string("config-read-1"),
            params: .init(cwd: "/tmp/project", includeLayers: true)
        )
        let configRequest = try #require(try JSONSerialization.jsonObject(with: configPayload) as? [String: Any])
        #expect(configRequest["method"] as? String == "config/read")
        #expect((configRequest["params"] as? [String: Any])?["cwd"] as? String == "/tmp/project")

        let configWritePayload = try protocolLayer.makeConfigBatchWriteRequest(
            id: .string("config-write-1"),
            params: .init(
                edits: [
                    .init(
                        keyPath: "mcp_servers.docs",
                        mergeStrategy: .replace,
                        value: .object([
                            "args": .array([.string("server.js")]),
                            "command": .string("node"),
                            "enabled": .bool(true),
                        ])
                    ),
                ],
                expectedVersion: nil,
                filePath: nil,
                reloadUserConfig: true
            )
        )
        let configWriteRequest = try #require(
            try JSONSerialization.jsonObject(with: configWritePayload) as? [String: Any]
        )
        #expect(configWriteRequest["method"] as? String == "config/batchWrite")
        let configWriteParams = try #require(configWriteRequest["params"] as? [String: Any])
        #expect(configWriteParams["reloadUserConfig"] as? Bool == true)
        let edits = try #require(configWriteParams["edits"] as? [[String: Any]])
        #expect(edits.first?["keyPath"] as? String == "mcp_servers.docs")
        #expect(edits.first?["mergeStrategy"] as? String == "replace")
        let editValue = try #require(edits.first?["value"] as? [String: Any])
        #expect(editValue["command"] as? String == "node")
        #expect(editValue["args"] as? [String] == ["server.js"])
        #expect(editValue["enabled"] as? Bool == true)

        let requirementsPayload = try protocolLayer.makeConfigRequirementsReadRequest(id: .string("requirements-read-1"))
        let requirementsRequest = try #require(try JSONSerialization.jsonObject(with: requirementsPayload) as? [String: Any])
        #expect(requirementsRequest["method"] as? String == "configRequirements/read")
        #expect(requirementsRequest["params"] == nil)

        let appPayload = try protocolLayer.makeAppListRequest(
            id: .string("app-list-1"),
            params: .init(cursor: "cursor", forceRefetch: true, limit: 2, threadID: "thread-123")
        )
        let appRequest = try #require(try JSONSerialization.jsonObject(with: appPayload) as? [String: Any])
        #expect(appRequest["method"] as? String == "app/list")
        #expect((appRequest["params"] as? [String: Any])?["threadId"] as? String == "thread-123")

        let skillsPayload = try protocolLayer.makeSkillsListRequest(
            id: .string("skills-list-1"),
            params: .init(cwds: ["/tmp/project"], forceReload: true)
        )
        let skillsRequest = try #require(try JSONSerialization.jsonObject(with: skillsPayload) as? [String: Any])
        #expect(skillsRequest["method"] as? String == "skills/list")
        #expect((skillsRequest["params"] as? [String: Any])?["cwds"] as? [String] == ["/tmp/project"])

        let pluginPayload = try protocolLayer.makePluginListRequest(
            id: .string("plugin-list-1"),
            params: .init(cwds: ["/tmp/project"], marketplaceKinds: nil)
        )
        let pluginRequest = try #require(try JSONSerialization.jsonObject(with: pluginPayload) as? [String: Any])
        #expect(pluginRequest["method"] as? String == "plugin/list")

        let pluginReadPayload = try protocolLayer.makePluginReadRequest(
            id: .string("plugin-read-1"),
            params: .init(marketplacePath: nil, pluginName: "GitHub", remoteMarketplaceName: "openai-curated")
        )
        let pluginReadRequest = try #require(try JSONSerialization.jsonObject(with: pluginReadPayload) as? [String: Any])
        #expect(pluginReadRequest["method"] as? String == "plugin/read")
        #expect((pluginReadRequest["params"] as? [String: Any])?["pluginName"] as? String == "GitHub")

        let collaborationPayload = try protocolLayer.makeCollaborationModeListRequest(
            id: .string("collaboration-list-1"),
            params: .init()
        )
        let collaborationRequest = try #require(try JSONSerialization.jsonObject(with: collaborationPayload) as? [String: Any])
        #expect(collaborationRequest["method"] as? String == "collaborationMode/list")
        #expect(collaborationRequest["params"] as? [String: Any] != nil)
    }

    @Test("encodes turn/start requests with the expected method and params payload")
    func encodesTurnStartRequest() throws {
        let payload = try protocolLayer.makeTurnStartRequest(
            id: .string("turn-1"),
            params: CodexWireTurnStartParams(
                additionalContext: nil,
                approvalPolicy: .enumeration(.onFailure),
                approvalsReviewer: .guardianSubagent,
                clientUserMessageID: nil,
                collaborationMode: .init(
                    mode: .plan,
                    settings: .init(
                        developerInstructions: nil,
                        model: "gpt-5.4",
                        reasoningEffort: "medium"
                    )
                ),
                cwd: "/tmp/project",
                effort: "medium",
                environments: nil,
                input: [
                    CodexWireUserInput(
                        text: "Hello from SwiftASB",
                        textElements: nil,
                        type: .text,
                        detail: nil,
                        url: nil,
                        path: nil,
                        name: nil
                    ),
                ],
                model: "gpt-5.4",
                multiAgentMode: nil,
                outputSchema: .object(["type": .string("object")]),
                permissions: nil,
                personality: .pragmatic,
                responsesapiClientMetadata: nil,
                runtimeWorkspaceRoots: nil,
                sandboxPolicy: nil,
                serviceTier: "flex",
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

        let collaborationMode = try #require(params["collaborationMode"] as? [String: Any])
        #expect(collaborationMode["mode"] as? String == "plan")
        let settings = try #require(collaborationMode["settings"] as? [String: Any])
        #expect(settings["model"] as? String == "gpt-5.4")
        #expect(settings["reasoning_effort"] as? String == "medium")
        #expect(settings["developer_instructions"] == nil)

        let input = try #require(params["input"] as? [[String: Any]])
        #expect(input.count == 1)
        let inputRow = try #require(input.first)
        #expect(inputRow["type"] as? String == "text")
        #expect(inputRow["text"] as? String == "Hello from SwiftASB")

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
                        detail: nil,
                        url: nil,
                        path: nil,
                        name: nil
                    ),
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
            #"{"id":"init-1","result":{"codexHome":"/Users/galew/.codex","platformFamily":"unix","platformOs":"macos","userAgent":"codex-cli/0.128.0"}}"#.utf8
        )

        let response = try protocolLayer.decodeInitializeResponse(payload, expectedID: .string("init-1"))

        #expect(response.codexHome == "/Users/galew/.codex")
        #expect(response.platformFamily == "unix")
        #expect(response.platformOS == "macos")
        #expect(response.userAgent == "codex-cli/0.128.0")
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
            #"{"id":"init-2","result":{"codexHome":"/Users/galew/.codex","platformFamily":"unix","platformOs":"macos","userAgent":"codex-cli/0.128.0"}}"#.utf8
        )

        #expect(throws: CodexProtocolError.self) {
            try protocolLayer.decodeInitializeResponse(payload, expectedID: .string("init-1"))
        }
    }

    @Test("decodes thread/start responses and honors the expected request ID")
    func decodesThreadStartResponse() throws {
        let payload = Data(
            #"""
            {"id":"thread-1","result":{"approvalPolicy":"on-request","approvalsReviewer":"user","cwd":"/tmp/project","instructionSources":["AGENTS.md"],"model":"gpt-5.4","modelProvider":"openai","reasoningEffort":"medium","sandbox":{"type":"workspaceWrite","networkAccess":"enabled","writableRoots":["/tmp/project"]},"serviceTier":"fast","thread":{"cliVersion":"0.128.0","createdAt":1713350000,"cwd":"/tmp/project","ephemeral":false,"id":"thread-123","modelProvider":"openai","preview":"Hello","source":"cli","status":{"type":"active"},"turns":[],"updatedAt":1713350001}}}
            """#.utf8
        )

        let response = try protocolLayer.decodeThreadStartResponse(payload, expectedID: .string("thread-1"))

        #expect(response.cwd == "/tmp/project")
        #expect(response.model == "gpt-5.4")
        #expect(response.modelProvider == "openai")
        #expect(response.serviceTier == "fast")
        #expect(response.thread.id == "thread-123")
        #expect(response.thread.preview == "Hello")
        #expect(response.thread.turns.isEmpty)
    }

    @Test("decodes thread/compact/start responses and honors the expected request ID")
    func decodesThreadCompactStartResponse() throws {
        let payload = Data(
            #"{"id":"thread-compact-1","result":{}}"#.utf8
        )

        let response = try protocolLayer.decodeThreadCompactStartResponse(
            payload,
            expectedID: .string("thread-compact-1")
        )

        #expect(response == .init())
    }

    @Test("decodes thread/list responses and honors the expected request ID")
    func decodesThreadListResponse() throws {
        let payload = Data(
            #"""
            {"id":"thread-list-1","result":{"data":[{"cliVersion":"0.128.0","createdAt":1713350000,"cwd":"/tmp/project","ephemeral":false,"id":"thread-123","modelProvider":"openai","name":"Release prep","preview":"Summarize the release notes","source":"cli","status":{"type":"notLoaded"},"turns":[],"updatedAt":1713350005}],"nextCursor":"cursor-next"}}
            """#.utf8
        )

        let response = try protocolLayer.decodeThreadListResponse(payload, expectedID: .string("thread-list-1"))

        #expect(response.data.count == 1)
        #expect(response.data[0].id == "thread-123")
        #expect(response.data[0].name == "Release prep")
        #expect(response.nextCursor == "cursor-next")
    }

    @Test("decodes thread/resume responses and honors the expected request ID")
    func decodesThreadResumeResponse() throws {
        let payload = Data(
            #"""
            {"id":"thread-resume-1","result":{"approvalPolicy":"on-request","approvalsReviewer":"user","cwd":"/tmp/project","instructionSources":["AGENTS.md"],"model":"gpt-5.4","modelProvider":"openai","reasoningEffort":"medium","sandbox":{"type":"workspaceWrite","networkAccess":"enabled","writableRoots":["/tmp/project"]},"serviceTier":"fast","thread":{"cliVersion":"0.128.0","createdAt":1713350000,"cwd":"/tmp/project","ephemeral":false,"id":"thread-123","modelProvider":"openai","name":"Resumed Thread","preview":"Hydrated resume preview","source":"cli","status":{"type":"idle"},"turns":[{"completedAt":1713350005,"durationMs":3000,"error":null,"id":"turn-hydrated-1","items":[{"id":"item-agent-1","status":"completed","text":"Resumed reply.","type":"agentMessage"}],"startedAt":1713350002,"status":"completed"}],"updatedAt":1713350005}}}
            """#.utf8
        )

        let response = try protocolLayer.decodeThreadResumeResponse(payload, expectedID: .string("thread-resume-1"))

        #expect(response.thread.id == "thread-123")
        #expect(response.thread.name == "Resumed Thread")
        #expect(response.thread.turns.count == 1)
        #expect(response.thread.turns[0].items.count == 1)
    }

    @Test("decodes thread/fork responses and honors the expected request ID")
    func decodesThreadForkResponse() throws {
        let payload = Data(
            #"""
            {"id":"thread-fork-1","result":{"approvalPolicy":"on-request","approvalsReviewer":"user","cwd":"/tmp/project","instructionSources":["AGENTS.md"],"model":"gpt-5.4","modelProvider":"openai","reasoningEffort":"medium","sandbox":{"type":"workspaceWrite","networkAccess":"enabled","writableRoots":["/tmp/project"]},"serviceTier":"fast","thread":{"cliVersion":"0.128.0","createdAt":1713350000,"cwd":"/tmp/project","ephemeral":true,"forkedFromId":"thread-123","id":"thread-456","modelProvider":"openai","name":"Forked Thread","preview":"Hydrated fork preview","source":"cli","status":{"type":"idle"},"turns":[{"completedAt":1713350005,"durationMs":3000,"error":null,"id":"turn-hydrated-1","items":[{"id":"item-agent-1","status":"completed","text":"Forked reply.","type":"agentMessage"}],"startedAt":1713350002,"status":"completed"}],"updatedAt":1713350005}}}
            """#.utf8
        )

        let response = try protocolLayer.decodeThreadForkResponse(payload, expectedID: .string("thread-fork-1"))

        #expect(response.thread.id == "thread-456")
        #expect(response.thread.forkedFromID == "thread-123")
        #expect(response.thread.ephemeral == true)
        #expect(response.thread.turns.count == 1)
        #expect(response.thread.turns[0].items.count == 1)
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
        #expect(response.turn.startedAt == 1_713_350_002)
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
                #expect(notification.turn.completedAt == 1_713_350_005)
            default:
                Issue.record("Expected turn/completed to decode into .turnCompleted.")
        }
    }

    @Test("decodes thread lifecycle notifications into typed protocol events")
    func decodesThreadLifecycleNotifications() throws {
        let threadStartedPayload = Data(
            #"""
            {"thread":{"cliVersion":"0.128.0","createdAt":1713350000,"cwd":"/tmp/project","ephemeral":false,"id":"thread-123","modelProvider":"openai","preview":"Hello","source":"cli","status":{"type":"active"},"turns":[],"updatedAt":1713350001}}
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

    @Test("decodes app-wide schema notifications into typed protocol events")
    func decodesAppWideSchemaNotifications() throws {
        let configWarningEvent = try #require(
            try decodeEvent(
                method: "config/warning",
                payload: Data(
                    #"{"details":"Unknown key.","path":"/tmp/config.toml","range":{"start":{"line":2,"column":1},"end":{"line":2,"column":8}},"summary":"Config key is ignored."}"#.utf8
                )
            )
        )
        switch configWarningEvent {
            case let .configWarning(notification):
                #expect(notification.summary == "Config key is ignored.")
                #expect(notification.range?.start.line == 2)
            default:
                Issue.record("Expected config/warning to decode into .configWarning.")
        }

        let mcpStatusEvent = try #require(
            try decodeEvent(
                method: "mcpServer/startupStatus/updated",
                payload: Data(#"{"error":null,"name":"calendar","status":"ready"}"#.utf8)
            )
        )
        switch mcpStatusEvent {
            case let .mcpServerStatusUpdated(notification):
                #expect(notification.name == "calendar")
                #expect(notification.status == .ready)
            default:
                Issue.record("Expected mcpServer/startupStatus/updated to decode into .mcpServerStatusUpdated.")
        }

        let remoteStatusEvent = try #require(
            try decodeEvent(
                method: "remoteControl/status/changed",
                payload: Data(#"{"environmentId":"env-123","installationId":"install-123","serverName":"desktop","status":"connected"}"#.utf8)
            )
        )
        switch remoteStatusEvent {
            case let .remoteControlStatusChanged(notification):
                #expect(notification.environmentID == "env-123")
                #expect(notification.installationID == "install-123")
                #expect(notification.serverName == "desktop")
                #expect(notification.status == .connected)
            default:
                Issue.record("Expected remoteControl/status/changed to decode into .remoteControlStatusChanged.")
        }

        let deprecationEvent = try #require(
            try decodeEvent(
                method: "deprecation/notice",
                payload: Data(#"{"details":"Use the new notification.","summary":"Old notification is deprecated."}"#.utf8)
            )
        )
        switch deprecationEvent {
            case let .deprecationNotice(notification):
                #expect(notification.summary == "Old notification is deprecated.")
            default:
                Issue.record("Expected deprecation/notice to decode into .deprecationNotice.")
        }

        let skillsEvent = try #require(
            try decodeEvent(method: "skills/changed", payload: Data(#"{}"#.utf8))
        )
        switch skillsEvent {
            case let .skillsChanged(payload):
                #expect(payload.isEmpty)
            default:
                Issue.record("Expected skills/changed to decode into .skillsChanged.")
        }

        let appListEvent = try #require(
            try decodeEvent(method: "app/list/updated", payload: Data(#"{"data":[]}"#.utf8))
        )
        switch appListEvent {
            case let .appListUpdated(notification):
                #expect(notification.data.isEmpty)
            default:
                Issue.record("Expected app/list/updated to decode into .appListUpdated.")
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

        let autoReviewStartedPayload = Data(
            #"""
            {"action":{"command":"git status","cwd":"/tmp/project","source":"shell","type":"command"},"review":{"rationale":"Read-only repository inspection.","riskLevel":"low","status":"inProgress","userAuthorization":"medium"},"reviewId":"review-123","startedAtMs":1713350002000,"targetItemId":"item-command-1","threadId":"thread-123","turnId":"turn-123"}
            """#.utf8
        )

        let autoReviewStartedEvent = try #require(
            try decodeEvent(method: "item/autoApprovalReview/started", payload: autoReviewStartedPayload)
        )

        switch autoReviewStartedEvent {
            case let .itemGuardianApprovalReviewStarted(notification):
                #expect(notification.threadID == "thread-123")
                #expect(notification.turnID == "turn-123")
                #expect(notification.targetItemID == "item-command-1")
                #expect(notification.reviewID == "review-123")
                #expect(notification.startedAtMS == 1_713_350_002_000)
                #expect(notification.action.type == .command)
                #expect(notification.action.command == "git status")
                #expect(notification.action.source == .shell)
                #expect(notification.review.status == .inProgress)
                #expect(notification.review.riskLevel == .low)
            default:
                Issue.record("Expected item/autoApprovalReview/started to decode into .itemGuardianApprovalReviewStarted.")
        }

        let autoReviewCompletedPayload = Data(
            #"""
            {"action":{"host":"api.example.com","port":443,"protocol":"https","target":"https://api.example.com","type":"networkAccess"},"completedAtMs":1713350003000,"decisionSource":"agent","review":{"rationale":"Network access is limited to the requested host.","riskLevel":"medium","status":"approved","userAuthorization":"high"},"reviewId":"review-124","startedAtMs":1713350002000,"targetItemId":null,"threadId":"thread-123","turnId":"turn-123"}
            """#.utf8
        )

        let autoReviewCompletedEvent = try #require(
            try decodeEvent(method: "item/autoApprovalReview/completed", payload: autoReviewCompletedPayload)
        )

        switch autoReviewCompletedEvent {
            case let .itemGuardianApprovalReviewCompleted(completion):
                let notification = completion.notification
                #expect(notification.threadID == "thread-123")
                #expect(notification.turnID == "turn-123")
                #expect(notification.targetItemID == nil)
                #expect(notification.reviewID == "review-124")
                #expect(notification.startedAtMS == 1_713_350_002_000)
                #expect(notification.completedAtMS == 1_713_350_003_000)
                #expect(notification.decisionSource == .agent)
                #expect(notification.action.type == .networkAccess)
                #expect(notification.action.host == "api.example.com")
                #expect(notification.action.guardianApprovalReviewActionProtocol == .https)
                #expect(notification.review.status == .approved)
                #expect(notification.review.userAuthorization == .high)
            default:
                Issue.record("Expected item/autoApprovalReview/completed to decode into .itemGuardianApprovalReviewCompleted.")
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

        let fileChangeDeltaPayload = Data(
            #"{"delta":"@@ -1 +1 @@\n-Hello\n+Hello, world\n","itemId":"item-file-1","threadId":"thread-123","turnId":"turn-123"}"#.utf8
        )

        let fileChangeDeltaEvent = try #require(
            try decodeEvent(method: "item/fileChange/outputDelta", payload: fileChangeDeltaPayload)
        )

        switch fileChangeDeltaEvent {
            case let .fileChangeOutputDelta(notification):
                #expect(notification.delta.contains("+Hello, world"))
                #expect(notification.itemID == "item-file-1")
                #expect(notification.threadID == "thread-123")
                #expect(notification.turnID == "turn-123")
            default:
                Issue.record("Expected item/fileChange/outputDelta to decode into .fileChangeOutputDelta.")
        }

        let fileChangePatchPayload = Data(
            #"""
            {"changes":[{"diff":"@@ -1 +1 @@\n-Hello\n+Hello, world\n","kind":{"type":"update"},"path":"Sources/SwiftASB/File.swift"}],"itemId":"item-file-1","threadId":"thread-123","turnId":"turn-123"}
            """#.utf8
        )

        let fileChangePatchEvent = try #require(
            try decodeEvent(method: "item/fileChange/patchUpdated", payload: fileChangePatchPayload)
        )

        switch fileChangePatchEvent {
            case let .fileChangePatchUpdated(notification):
                #expect(notification.changes[0].path == "Sources/SwiftASB/File.swift")
                #expect(notification.changes[0].kind.type == .update)
                #expect(notification.itemID == "item-file-1")
            default:
                Issue.record("Expected item/fileChange/patchUpdated to decode into .fileChangePatchUpdated.")
        }

        let commandDeltaPayload = Data(
            #"{"delta":"Cloning into 'SwiftASB'...\n","itemId":"item-command-1","threadId":"thread-123","turnId":"turn-123"}"#.utf8
        )

        let commandDeltaEvent = try #require(
            try decodeEvent(method: "item/commandExecution/outputDelta", payload: commandDeltaPayload)
        )

        switch commandDeltaEvent {
            case let .commandExecutionOutputDelta(notification):
                #expect(notification.delta.contains("Cloning into"))
                #expect(notification.itemID == "item-command-1")
                #expect(notification.threadID == "thread-123")
                #expect(notification.turnID == "turn-123")
            default:
                Issue.record("Expected item/commandExecution/outputDelta to decode into .commandExecutionOutputDelta.")
        }
    }

    @Test("decodes diagnostic notifications into typed protocol events")
    func decodesDiagnosticNotifications() throws {
        let warningPayload = Data(
            #"{"message":"Runtime configuration is using a fallback.","threadId":"thread-123"}"#.utf8
        )

        let warningEvent = try #require(
            try decodeEvent(method: "warning", payload: warningPayload)
        )

        switch warningEvent {
            case let .warning(notification):
                #expect(notification.threadID == "thread-123")
                #expect(notification.message == "Runtime configuration is using a fallback.")
            default:
                Issue.record("Expected warning to decode into .warning.")
        }

        let guardianWarningPayload = Data(
            #"{"message":"Guardian flagged this session for review.","threadId":"thread-123"}"#.utf8
        )

        let guardianWarningEvent = try #require(
            try decodeEvent(method: "guardianWarning", payload: guardianWarningPayload)
        )

        switch guardianWarningEvent {
            case let .guardianWarning(notification):
                #expect(notification.threadID == "thread-123")
                #expect(notification.message == "Guardian flagged this session for review.")
            default:
                Issue.record("Expected guardianWarning to decode into .guardianWarning.")
        }

        let modelReroutedPayload = Data(
            #"{"fromModel":"gpt-5.4","reason":"highRiskCyberActivity","threadId":"thread-123","toModel":"gpt-5.4-safe","turnId":"turn-123"}"#.utf8
        )

        let modelReroutedEvent = try #require(
            try decodeEvent(method: "model/rerouted", payload: modelReroutedPayload)
        )

        switch modelReroutedEvent {
            case let .modelRerouted(notification):
                #expect(notification.threadID == "thread-123")
                #expect(notification.turnID == "turn-123")
                #expect(notification.fromModel == "gpt-5.4")
                #expect(notification.toModel == "gpt-5.4-safe")
                #expect(notification.reason == .highRiskCyberActivity)
            default:
                Issue.record("Expected model/rerouted to decode into .modelRerouted.")
        }

        let modelVerificationPayload = Data(
            #"{"threadId":"thread-123","turnId":"turn-123","verifications":["trustedAccessForCyber"]}"#.utf8
        )

        let modelVerificationEvent = try #require(
            try decodeEvent(method: "model/verification", payload: modelVerificationPayload)
        )

        switch modelVerificationEvent {
            case let .modelVerification(notification):
                #expect(notification.threadID == "thread-123")
                #expect(notification.turnID == "turn-123")
                #expect(notification.verifications == [.trustedAccessForCyber])
            default:
                Issue.record("Expected model/verification to decode into .modelVerification.")
        }
    }

    @Test("decodes server-originated approval and elicitation requests into typed protocol events")
    func decodesServerRequests() throws {
        let commandApprovalPayload = Data(
            #"""
            {"command":"git status","commandActions":[{"command":"git status","type":"unknown"}],"cwd":"/tmp/project","itemId":"item-command-1","proposedNetworkPolicyAmendments":[{"action":"audit","host":"example.com"}],"reason":"Needs approval to inspect repository state.","threadId":"thread-123","turnId":"turn-123"}
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
                let amendment = try #require(request.proposedNetworkPolicyAmendments?.first)
                #expect(amendment.publicValue.action == .unknown("audit"))
                #expect(amendment.publicValue.host == "example.com")
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

    @Test("ignores unknown server-originated request methods")
    func ignoresUnknownServerRequestMethods() throws {
        let payload = Data(#"{"threadId":"thread-123"}"#.utf8)

        let event = try protocolLayer.decodeServerEvent(
            .request(
                id: .string("unknown-1"),
                method: "unknown/request",
                payload: payload
            )
        )

        #expect(event == nil)
    }

    @Test("throws protocol errors for malformed server-originated request payloads")
    func rejectsMalformedServerRequestPayloads() throws {
        let malformedRequests: [(method: String, payload: Data)] = [
            (
                "item/commandExecution/requestApproval",
                Data(#"{"itemId":"item-command-1"}"#.utf8)
            ),
            (
                "item/fileChange/requestApproval",
                Data(#"{"itemId":"item-file-1","threadId":"thread-123"}"#.utf8)
            ),
            (
                "item/permissions/requestApproval",
                Data(#"{"itemId":"item-permissions-1","threadId":"thread-123","turnId":"turn-123"}"#.utf8)
            ),
            (
                "item/tool/requestUserInput",
                Data(#"{"itemId":"item-input-1","questions":[{"id":"goal"}],"threadId":"thread-123","turnId":"turn-123"}"#.utf8)
            ),
            (
                "mcpServer/elicitation/request",
                Data(#"{"message":"Authorize the calendar server.","mode":"url","threadId":"thread-123","url":"https://example.com/authorize"}"#.utf8)
            ),
        ]

        for malformedRequest in malformedRequests {
            #expect(throws: CodexProtocolError.self) {
                try protocolLayer.decodeServerEvent(
                    .request(
                        id: .string("malformed-1"),
                        method: malformedRequest.method,
                        payload: malformedRequest.payload
                    )
                )
            }
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

    @Test("decodes promoted generated-wire fixture payloads for drift guardrails")
    func decodesPromotedGeneratedWireFixturePayloads() throws {
        let decoder = JSONDecoder()
        let threadReadPayload = Data(
            #"""
            {
              "thread": {
                "agentNickname": null,
                "agentRole": null,
                "cliVersion": "0.128.0",
                "createdAt": 1713350000,
                "cwd": "/tmp/project",
                "ephemeral": false,
                "forkedFromId": null,
                "gitInfo": null,
                "id": "thread-fixture",
                "modelProvider": "openai",
                "name": "Fixture Thread",
                "path": "/tmp/codex/thread-fixture.jsonl",
                "preview": "Fixture preview",
                "source": "appServer",
                "status": {
                  "type": "active",
                  "activeFlags": ["waitingOnApproval"]
                },
                "turns": [
                  {
                    "completedAt": 1713350002,
                    "durationMs": 2000,
                    "error": null,
                    "id": "turn-fixture",
                    "items": [
                      {
                        "content": null,
                        "id": "item-command-fixture",
                        "type": "commandExecution",
                        "fragments": null,
                        "memoryCitation": null,
                        "phase": null,
                        "text": null,
                        "summary": null,
                        "aggregatedOutput": "42\n",
                        "command": "printf 42",
                        "commandActions": [],
                        "cwd": "/tmp/project",
                        "durationMs": 10,
                        "exitCode": 0,
                        "processId": null,
                        "source": "agent",
                        "status": "completed",
                        "changes": null,
                        "arguments": null,
                        "error": null,
                        "mcpAppResourceURI": null,
                        "result": null,
                        "server": null,
                        "tool": null,
                        "contentItems": null,
                        "namespace": null,
                        "success": null,
                        "agentsStates": null,
                        "model": null,
                        "prompt": null,
                        "reasoningEffort": null,
                        "receiverThreadIds": null,
                        "senderThreadId": null,
                        "action": null,
                        "query": null,
                        "path": null,
                        "revisedPrompt": null,
                        "savedPath": null,
                        "review": null
                      }
                    ],
                    "startedAt": 1713350001,
                    "status": "completed"
                  }
                ],
                "updatedAt": 1713350003,
                "futureAdditiveField": {
                  "keptForFixture": true
                }
              }
            }
            """#.utf8
        )

        let threadRead = try decoder.decode(CodexProtocolThreadReadResponse.self, from: threadReadPayload)
        #expect(threadRead.thread.id == "thread-fixture")
        #expect(threadRead.thread.status.activeFlags == [.waitingOnApproval])
        #expect(threadRead.thread.turns.first?.items.first?.type == .commandExecution)

        let turnsListPayload = Data(
            #"""
            {
              "backwardsCursor": "cursor-previous",
              "data": [
                {
                  "completedAt": 1713350002,
                  "durationMs": 2000,
                  "error": null,
                  "id": "turn-fixture",
                  "items": [],
                  "startedAt": 1713350001,
                  "status": "completed"
                }
              ],
              "nextCursor": "cursor-next"
            }
            """#.utf8
        )

        let turnsList = try decoder.decode(CodexProtocolThreadTurnsListResponse.self, from: turnsListPayload)
        #expect(turnsList.backwardsCursor == "cursor-previous")
        #expect(turnsList.data.map(\.id) == ["turn-fixture"])
        #expect(turnsList.nextCursor == "cursor-next")

        let resolvedPayload = Data(
            #"""
            {
              "requestId": 0,
              "threadId": "thread-fixture"
            }
            """#.utf8
        )

        let resolved = try decoder.decode(CodexWireServerRequestResolvedNotification.self, from: resolvedPayload)
        #expect(resolved.requestID == .integer(0))
        #expect(resolved.threadID == "thread-fixture")
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
