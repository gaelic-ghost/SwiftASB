import Foundation
import CryptoKit
import Testing
@testable import SwiftASB

final class LiveCodexHarness {
    let rootDirectoryURL: URL
    let codexHomeURL: URL
    let codexConfigSummary: LiveApprovalProbeReport.CodexConfig?
    let threadAWorkspace: URL
    let threadBWorkspace: URL
    let approvalProbeWorkspace: URL
    let fileScenarioWorkspace: URL
    let rollbackWorkspace: URL
    let sameThreadWorkspace: URL
    let codexExecutableURL: URL

    enum ConfigMode {
        case standard
        case approvalProbe
        case mockResponses(baseURL: String, requestPermissionsTool: Bool = false)
        case mockResponsesWithMcpElicitation(baseURL: String)
        case mockResponsesWithAppConnectorMcpElicitation(baseURL: String, appsBaseURL: String)
    }

    init(configMode: ConfigMode = .standard, fileManager: FileManager = .default) throws {
        let rootDirectoryURL = fileManager.temporaryDirectory
            .appendingPathComponent("SwiftASB-LiveCodex-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: rootDirectoryURL, withIntermediateDirectories: true)

        self.rootDirectoryURL = rootDirectoryURL
        self.codexHomeURL = rootDirectoryURL.appendingPathComponent(".codex", isDirectory: true)
        self.codexConfigSummary = Self.makeCodexConfigSummary(
            configMode: configMode,
            projectRootURL: rootDirectoryURL
        )
        self.threadAWorkspace = rootDirectoryURL.appendingPathComponent("thread-a", isDirectory: true)
        self.threadBWorkspace = rootDirectoryURL.appendingPathComponent("thread-b", isDirectory: true)
        self.approvalProbeWorkspace = rootDirectoryURL.appendingPathComponent("approval-probe", isDirectory: true)
        self.fileScenarioWorkspace = rootDirectoryURL.appendingPathComponent("file-scenario", isDirectory: true)
        self.rollbackWorkspace = rootDirectoryURL.appendingPathComponent("rollback", isDirectory: true)
        self.sameThreadWorkspace = rootDirectoryURL.appendingPathComponent("same-thread", isDirectory: true)
        self.codexExecutableURL = try Self.resolveCodexExecutableURL()

        try fileManager.createDirectory(at: codexHomeURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: threadAWorkspace, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: threadBWorkspace, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: approvalProbeWorkspace, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: fileScenarioWorkspace, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: rollbackWorkspace, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: sameThreadWorkspace, withIntermediateDirectories: true)
        let mcpElicitationServerScriptURL = rootDirectoryURL
            .appendingPathComponent("swiftasb_mcp_elicitation_server.py", isDirectory: false)
        if case .mockResponsesWithMcpElicitation = configMode {
            try Data(Self.mcpElicitationServerPythonScript.utf8).write(to: mcpElicitationServerScriptURL)
        }
        try Self.seedIsolatedCodexHome(
            at: codexHomeURL,
            configMode: configMode,
            projectRootURL: rootDirectoryURL,
            mcpElicitationServerScriptURL: mcpElicitationServerScriptURL,
            fileManager: fileManager
        )
    }

    var configuration: CodexAppServer.Configuration {
        .init(
            codexExecutableURL: codexExecutableURL,
            currentDirectoryURL: rootDirectoryURL,
            environment: Self.makeCodexEnvironment(codexHomeURL: codexHomeURL)
        )
    }

    func cleanup(fileManager: FileManager = .default) {
        if ProcessInfo.processInfo.environment["SWIFTASB_LIVE_CODEX_KEEP_WORKSPACES"] == "1" {
            return
        }
        try? fileManager.removeItem(at: rootDirectoryURL)
    }

    func writeReport<T: Encodable>(
        _ report: T,
        fileName: String,
        fileManager: FileManager = .default
    ) throws {
        guard let reportDirectoryPath = ProcessInfo.processInfo.environment["SWIFTASB_LIVE_CODEX_REPORT_DIR"],
              reportDirectoryPath.isEmpty == false else {
            return
        }

        let reportDirectoryURL = URL(fileURLWithPath: reportDirectoryPath, isDirectory: true)
        try fileManager.createDirectory(at: reportDirectoryURL, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let reportData = try encoder.encode(report)
        try reportData.write(to: reportDirectoryURL.appendingPathComponent(fileName))
    }

    private static func resolveCodexExecutableURL() throws -> URL {
        if let overridePath = ProcessInfo.processInfo.environment["SWIFTASB_LIVE_CODEX_BIN"],
           overridePath.isEmpty == false {
            return URL(fileURLWithPath: overridePath)
        }

        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "command -v codex"]
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()
        process.waitUntilExit()

        let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let errorData = standardError.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let errorText = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw LiveIntegrationError.executableResolutionFailed(
                reason: errorText.isEmpty ? "zsh could not locate a `codex` executable on PATH." : errorText
            )
        }

        let outputText = String(decoding: outputData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard outputText.isEmpty == false else {
            throw LiveIntegrationError.executableResolutionFailed(
                reason: "`command -v codex` returned an empty result."
            )
        }

        return URL(fileURLWithPath: outputText)
    }

    private static func makeCodexEnvironment(codexHomeURL: URL) -> [String: String] {
        let environment = ProcessInfo.processInfo.environment
        let allowedKeys = [
            "HOME",
            "LANG",
            "LC_ALL",
            "LOGNAME",
            "PATH",
            "SHELL",
            "TERM",
            "TMPDIR",
            "USER",
        ]

        var isolatedEnvironment = environment.reduce(into: [String: String]()) { partialResult, entry in
            guard allowedKeys.contains(entry.key) else {
                return
            }
            partialResult[entry.key] = entry.value
        }

        isolatedEnvironment["CODEX_HOME"] = codexHomeURL.path
        return isolatedEnvironment
    }

    private static func seedIsolatedCodexHome(
        at codexHomeURL: URL,
        configMode: ConfigMode,
        projectRootURL: URL,
        mcpElicitationServerScriptURL: URL,
        fileManager: FileManager
    ) throws {
        let sourceCodexHomeURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
        let sourceAuthURL = sourceCodexHomeURL.appendingPathComponent("auth.json")
        let destinationAuthURL = codexHomeURL.appendingPathComponent("auth.json")

        if fileManager.fileExists(atPath: sourceAuthURL.path) {
            try fileManager.copyItem(at: sourceAuthURL, to: destinationAuthURL)
        }

        let configURL = codexHomeURL.appendingPathComponent("config.toml")
        let isolatedConfig: String
        switch configMode {
        case .standard:
            isolatedConfig = """
            model = "gpt-5.4"

            [features]
            apps = false

            [apps._default]
            enabled = false
            """
        case .approvalProbe:
            isolatedConfig = """
            model = "gpt-5.4"
            approval_policy = "untrusted"
            approvals_reviewer = "user"
            sandbox_mode = "workspace-write"

            [auto_review]
            policy = ""

            [features]
            apps = false

            [apps._default]
            enabled = false

            [projects.\(tomlQuotedString(projectRootURL.path))]
            trust_level = "untrusted"
            """
        case let .mockResponses(baseURL, requestPermissionsTool):
            isolatedConfig = """
            model = "mock-model"
            approval_policy = "untrusted"
            approvals_reviewer = "user"
            sandbox_mode = "read-only"
            model_provider = "mock_provider"
            suppress_unstable_features_warning = true

            [features]
            apps = false
            exec_permission_approvals = true
            request_permissions_tool = \(requestPermissionsTool)

            [apps._default]
            enabled = false

            [model_providers.mock_provider]
            name = "SwiftASB Mock Responses Provider"
            base_url = "\(baseURL)/v1"
            wire_api = "responses"
            request_max_retries = 0
            stream_max_retries = 0
            supports_websockets = false

            [projects.\(tomlQuotedString(projectRootURL.path))]
            trust_level = "untrusted"
            """
        case let .mockResponsesWithMcpElicitation(baseURL):
            isolatedConfig = """
            model = "mock-model"
            approval_policy = "untrusted"
            approvals_reviewer = "user"
            sandbox_mode = "read-only"
            model_provider = "mock_provider"
            suppress_unstable_features_warning = true

            [features]
            apps = false
            exec_permission_approvals = true

            [apps._default]
            enabled = false

            [model_providers.mock_provider]
            name = "SwiftASB Mock Responses Provider"
            base_url = "\(baseURL)/v1"
            wire_api = "responses"
            request_max_retries = 0
            stream_max_retries = 0
            supports_websockets = false

            [mcp_servers.swiftasb_elicitation]
            command = "/usr/bin/env"
            args = ["python3", "\(tomlEscapedString(mcpElicitationServerScriptURL.path))"]
            startup_timeout_sec = 5
            enabled = true

            [mcp_servers.swiftasb_elicitation.tools.ask]
            approval_mode = "approve"

            [projects.\(tomlQuotedString(projectRootURL.path))]
            trust_level = "trusted"
            """
        case let .mockResponsesWithAppConnectorMcpElicitation(baseURL, appsBaseURL):
            try writeFakeChatGPTAuth(to: codexHomeURL)
            isolatedConfig = """
            model = "mock-model"
            approval_policy = "on-request"
            approvals_reviewer = "user"
            sandbox_mode = "read-only"
            model_provider = "mock_provider"
            chatgpt_base_url = "\(appsBaseURL)"
            mcp_oauth_credentials_store = "file"
            suppress_unstable_features_warning = true

            [features]
            apps = true
            exec_permission_approvals = true

            [model_providers.mock_provider]
            name = "SwiftASB Mock Responses Provider"
            base_url = "\(baseURL)/v1"
            wire_api = "responses"
            request_max_retries = 0
            stream_max_retries = 0
            supports_websockets = false

            [projects.\(tomlQuotedString(projectRootURL.path))]
            trust_level = "untrusted"
            """
        }
        try Data(isolatedConfig.utf8).write(to: configURL)
    }

    private static func makeCodexConfigSummary(
        configMode: ConfigMode,
        projectRootURL: URL
    ) -> LiveApprovalProbeReport.CodexConfig? {
        switch configMode {
        case .standard, .mockResponses, .mockResponsesWithMcpElicitation, .mockResponsesWithAppConnectorMcpElicitation:
            nil
        case .approvalProbe:
            .init(
                approvalPolicy: "untrusted",
                approvalsReviewer: "user",
                autoReviewPolicy: "",
                projectTrustLevel: "untrusted",
                sandboxMode: "workspace-write"
            )
        }
    }

    private static func tomlQuotedString(_ value: String) -> String {
        let escapedValue = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escapedValue)\""
    }

    private static func tomlEscapedString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func writeFakeChatGPTAuth(to codexHomeURL: URL) throws {
        let idToken = try fakeChatGPTIDToken(
            accountID: "account-123",
            userID: "user-123"
        )
        let authObject: [String: Any] = [
            "auth_mode": "chatgpt",
            "tokens": [
                "id_token": idToken,
                "access_token": "chatgpt-token",
                "refresh_token": "refresh-token",
                "account_id": "account-123",
            ],
            "last_refresh": "2026-05-03T00:00:00Z",
        ]
        let authData = try JSONSerialization.data(
            withJSONObject: authObject,
            options: [.prettyPrinted, .sortedKeys]
        )
        try authData.write(to: codexHomeURL.appendingPathComponent("auth.json"))
    }

    private static func fakeChatGPTIDToken(accountID: String, userID: String) throws -> String {
        let header = try jsonBase64URLString([
            "alg": "none",
            "typ": "JWT",
        ])
        let payload = try jsonBase64URLString([
            "https://api.openai.com/auth": [
                "chatgpt_account_id": accountID,
                "chatgpt_user_id": userID,
            ],
        ])
        let signature = Data("signature".utf8).base64URLEncodedString()
        return "\(header).\(payload).\(signature)"
    }

    private static func jsonBase64URLString(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return data.base64URLEncodedString()
    }

    private static let mcpElicitationServerPythonScript = """
    import json
    import sys

    def send(message):
        sys.stdout.write(json.dumps(message, separators=(",", ":")) + "\\n")
        sys.stdout.flush()

    def success(request_id, result):
        send({"jsonrpc": "2.0", "id": request_id, "result": result})

    def error(request_id, code, message):
        send({"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}})

    for line in sys.stdin:
        if not line.strip():
            continue
        request = json.loads(line)
        request_id = request.get("id")
        method = request.get("method")

        if method == "initialize":
            params = request.get("params", {})
            success(request_id, {
                "protocolVersion": params.get("protocolVersion", "2025-06-18"),
                "capabilities": {
                    "tools": {},
                    "elicitation": {}
                },
                "serverInfo": {
                    "name": "swiftasb-elicitation",
                    "version": "0.1.0"
                }
            })
        elif method == "notifications/initialized":
            continue
        elif method == "tools/list":
            success(request_id, {
                "tools": [{
                    "name": "ask",
                    "description": "Ask for deterministic SwiftASB MCP elicitation input.",
                    "inputSchema": {
                        "type": "object",
                        "properties": {},
                        "additionalProperties": False
                    }
                }]
            })
        elif method == "tools/call":
            elicitation_id = "swiftasb-elicitation-request"
            send({
                "jsonrpc": "2.0",
                "id": elicitation_id,
                "method": "elicitation/create",
                "params": {
                    "message": "Confirm deterministic SwiftASB MCP elicitation.",
                    "requestedSchema": {
                        "type": "object",
                        "properties": {
                            "confirmed": {
                                "type": "boolean",
                                "title": "Confirmed"
                            }
                        },
                        "required": ["confirmed"]
                    }
                }
            })
            while True:
                response_line = sys.stdin.readline()
                if not response_line:
                    sys.exit(0)
                response = json.loads(response_line)
                if response.get("id") == elicitation_id:
                    break
            success(request_id, {
                "content": [{
                    "type": "text",
                    "text": "MCP elicitation completed."
                }]
            })
        elif request_id is not None:
            error(request_id, -32601, f"Unsupported method: {method}")
    """
}

enum LiveApprovalPathOutcome {
    case approvalRequested(CodexApprovalRequest)
    case completedWithoutApproval(CodexAppServer.TurnStatus, String?)
}

enum LiveTurnStartOutcome {
    case started(CodexTurnHandle)
    case failed(String)
}

struct LiveScenarioTurnResult {
    let completion: CodexTurnCompletion
    let acceptedApprovalKinds: [String]
    let callSnapshots: [CodexTurnHandle.Minimap.CallSnapshot]
    let latestCompletedItemText: String?

    func reportTurn(label: String) -> LiveFileMutationScenarioReport.Turn {
        LiveFileMutationScenarioReport.Turn(
            label: label,
            id: completion.turn.id,
            status: completion.turn.status.rawValue,
            acceptedApprovalKinds: acceptedApprovalKinds,
            callKinds: callSnapshots.map(\.kind.rawValue),
            callDisplayNames: callSnapshots.map(\.displayName)
        )
    }
}

struct LiveApprovalProbeCase {
    let label: String
    let prompt: String
    let expectedFinalText: String
    let inspectedPath: URL
}

struct LiveBehaviorMatrixCase {
    let label: String
    let approvalPolicy: CodexAppServer.ApprovalPolicy
    let sandboxMode: CodexAppServer.SandboxMode
    let prompt: String
    let expectedFinalText: String
    let inspectedPath: URL?
}

struct LiveApprovalProbeReport: Codable, Equatable {
    struct CodexConfig: Codable, Equatable {
        let approvalPolicy: String
        let approvalsReviewer: String
        let autoReviewPolicy: String
        let projectTrustLevel: String
        let sandboxMode: String
    }

    struct Result: Codable, Equatable {
        let label: String
        let threadID: String
        let turnID: String
        let status: String
        let acceptedApprovalKinds: [String]
        let callKinds: [String]
        let callDisplayNames: [String]
        let latestCompletedItemText: String?
        let inspectedFile: InspectedFile
        let errorDescription: String?

        init(
            _ probeCase: LiveApprovalProbeCase,
            thread: CodexThread,
            result: LiveScenarioTurnResult
        ) {
            self.label = probeCase.label
            self.threadID = thread.id
            self.turnID = result.completion.turn.id
            self.status = result.completion.turn.status.rawValue
            self.acceptedApprovalKinds = result.acceptedApprovalKinds
            self.callKinds = result.callSnapshots.map(\.kind.rawValue)
            self.callDisplayNames = result.callSnapshots.map(\.displayName)
            self.latestCompletedItemText = result.latestCompletedItemText
            self.inspectedFile = .init(url: probeCase.inspectedPath)
            self.errorDescription = nil
        }

        init(
            _ probeCase: LiveApprovalProbeCase,
            thread: CodexThread,
            turnID: String,
            status: String,
            callSnapshots: [CodexTurnHandle.Minimap.CallSnapshot],
            latestCompletedItemText: String?,
            error: Error
        ) {
            self.label = probeCase.label
            self.threadID = thread.id
            self.turnID = turnID
            self.status = status
            self.acceptedApprovalKinds = []
            self.callKinds = callSnapshots.map(\.kind.rawValue)
            self.callDisplayNames = callSnapshots.map(\.displayName)
            self.latestCompletedItemText = latestCompletedItemText
            self.inspectedFile = .init(url: probeCase.inspectedPath)
            self.errorDescription = String(describing: error)
        }

        init(_ probeCase: LiveApprovalProbeCase, error: Error) {
            self.label = probeCase.label
            self.threadID = ""
            self.turnID = ""
            self.status = "failed"
            self.acceptedApprovalKinds = []
            self.callKinds = []
            self.callDisplayNames = []
            self.latestCompletedItemText = nil
            self.inspectedFile = .init(url: probeCase.inspectedPath)
            self.errorDescription = String(describing: error)
        }
    }

    struct InspectedFile: Codable, Equatable {
        let path: String
        let exists: Bool
        let contents: String?

        init(url: URL) {
            self.path = url.lastPathComponent
            self.exists = FileManager.default.fileExists(atPath: url.path)
            self.contents = try? String(contentsOf: url, encoding: .utf8)
        }
    }

    let threadID: String
    let readOnlyThreadID: String
    let codexConfig: CodexConfig?
    let workspacePath: String
    let results: [Result]
}

struct LiveBehaviorMatrixReport: Codable, Equatable {
    struct PolicySandboxResult: Codable, Equatable {
        let label: String
        let approvalPolicy: String
        let sandboxMode: String
        let threadID: String
        let turnID: String
        let status: String
        let acceptedApprovalKinds: [String]
        let callKinds: [String]
        let callDisplayNames: [String]
        let latestCompletedItemText: String?
        let inspectedFile: LiveApprovalProbeReport.InspectedFile?
        let matchedExpectedFinalText: Bool
        let errorDescription: String?
    }

    struct HistoryResult: Codable, Equatable {
        let ephemeralThreadID: String?
        let ephemeralRecentTurns: Int?
        let storedThreadID: String?
        let storedRecentTurnsBeforeMaterialization: Int?
        let errorDescription: String?
    }

    struct SameThreadResult: Codable, Equatable {
        let threadID: String
        let firstTurnID: String
        let outcome: String
        let errorDescription: String?
        let firstTurnStatus: String?
    }

    struct CLIDiagnosticsResult: Codable, Equatable {
        let resolvedExecutablePath: String?
        let versionString: String
        let compatibility: String
        let errorDescription: String?
    }

    let codexConfig: LiveApprovalProbeReport.CodexConfig?
    let workspacePath: String
    let policySandboxResults: [PolicySandboxResult]
    let history: HistoryResult
    let sameThread: SameThreadResult
    let cliDiagnostics: CLIDiagnosticsResult
}

struct LiveServerRequestFamilyCoverageReport: Codable, Equatable {
    struct Family: Codable, Equatable {
        let family: String
        let publicSurface: String
        let deterministicFakeTransportCoverage: Bool
        let liveProbeCoverage: Bool
        let liveProbeScript: String?
        let status: String
        let notes: String
    }

    let codexConfig: LiveApprovalProbeReport.CodexConfig?
    let families: [Family]
    let sourceNotes: [String]
}

struct LiveFileMutationScenarioReport: Codable, Equatable {
    struct Turn: Codable, Equatable {
        let label: String
        let id: String
        let status: String
        let acceptedApprovalKinds: [String]
        let callKinds: [String]
        let callDisplayNames: [String]
    }

    struct FinalFile: Codable, Equatable {
        let path: String
        let exists: Bool
        let contents: String?
    }

    struct RecentFile: Codable, Equatable {
        let path: String?
        let status: String
        let latestStatusText: String?

        init(_ snapshot: CodexThread.RecentFiles.FileSnapshot) {
            self.path = snapshot.path
            self.status = snapshot.status.rawValue
            self.latestStatusText = snapshot.latestStatusText
        }
    }

    struct RecentCommand: Codable, Equatable {
        let command: String?
        let status: String
        let latestStatusText: String?

        init(_ snapshot: CodexThread.RecentCommands.CommandSnapshot) {
            self.command = snapshot.command
            self.status = snapshot.status.rawValue
            self.latestStatusText = snapshot.latestStatusText
        }
    }

    let threadID: String
    let workspacePath: String
    let turns: [Turn]
    let finalFiles: [FinalFile]
    let recentFiles: [RecentFile]
    let recentCommands: [RecentCommand]
}

final class MockResponsesServer: @unchecked Sendable {
    private let process: Process
    private let rootDirectoryURL: URL
    private let requestCountFileURL: URL

    let baseURL: URL

    var requestCount: Int {
        guard let text = try? String(contentsOf: requestCountFileURL, encoding: .utf8) else {
            return 0
        }
        return Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    init(responses: [MockResponsesEventStream]) async throws {
        let fileManager = FileManager.default
        self.rootDirectoryURL = fileManager.temporaryDirectory
            .appendingPathComponent("SwiftASB-MockResponses-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: rootDirectoryURL, withIntermediateDirectories: true)

        let responsesFileURL = rootDirectoryURL.appendingPathComponent("responses.json")
        self.requestCountFileURL = rootDirectoryURL.appendingPathComponent("request-count.txt")
        let portFileURL = rootDirectoryURL.appendingPathComponent("port.txt")
        let scriptURL = rootDirectoryURL.appendingPathComponent("mock_responses_server.py")

        let responseData = try JSONEncoder().encode(responses.map(\.body))
        try responseData.write(to: responsesFileURL)
        try Data("0\n".utf8).write(to: requestCountFileURL)
        try Data(Self.pythonScript.utf8).write(to: scriptURL)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "python3",
            scriptURL.path,
            responsesFileURL.path,
            portFileURL.path,
            requestCountFileURL.path,
        ]
        self.process = process
        try process.run()

        let port = try await Self.waitForPortFile(portFileURL)
        self.baseURL = URL(string: "http://127.0.0.1:\(port)")!
    }

    func stop() {
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }
        try? FileManager.default.removeItem(at: rootDirectoryURL)
    }

    fileprivate static func waitForPortFile(_ portFileURL: URL) async throws -> Int {
        let deadline = ContinuousClock.now + .seconds(5)
        while ContinuousClock.now < deadline {
            if let text = try? String(contentsOf: portFileURL, encoding: .utf8),
               let port = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return port
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        throw LiveIntegrationError.timedOut(
            operation: "waiting for the local mock Responses server to report its port",
            seconds: 5
        )
    }

    private static let pythonScript = """
    import json
    import sys
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

    responses_path, port_path, count_path = sys.argv[1:4]
    with open(responses_path, "r", encoding="utf-8") as handle:
        responses = json.load(handle)

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, format, *args):
            return

        def do_GET(self):
            body = json.dumps({"models": []}).encode("utf-8")
            self.send_response(200)
            self.send_header("content-type", "application/json")
            self.send_header("content-length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_POST(self):
            length = int(self.headers.get("content-length", "0"))
            if length:
                self.rfile.read(length)

            try:
                with open(count_path, "r", encoding="utf-8") as handle:
                    count = int(handle.read().strip() or "0")
            except FileNotFoundError:
                count = 0
            with open(count_path, "w", encoding="utf-8") as handle:
                handle.write(f"{count + 1}\\n")

            if responses:
                body = responses.pop(0).encode("utf-8")
            else:
                body = (
                    "event: response.created\\n"
                    "data: {\\\"type\\\":\\\"response.created\\\",\\\"response\\\":{\\\"id\\\":\\\"fallback\\\"}}\\n\\n"
                    "event: response.completed\\n"
                    "data: {\\\"type\\\":\\\"response.completed\\\",\\\"response\\\":{\\\"id\\\":\\\"fallback\\\",\\\"usage\\\":{\\\"input_tokens\\\":0,\\\"input_tokens_details\\\":null,\\\"output_tokens\\\":0,\\\"output_tokens_details\\\":null,\\\"total_tokens\\\":0}}}\\n\\n"
                ).encode("utf-8")

            self.send_response(200)
            self.send_header("content-type", "text/event-stream")
            self.send_header("cache-control", "no-cache")
            self.send_header("content-length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    with open(port_path, "w", encoding="utf-8") as handle:
        handle.write(f"{server.server_address[1]}\\n")
    server.serve_forever()
    """
}

final class MockAppConnectorMcpServer: @unchecked Sendable {
    private let process: Process
    private let rootDirectoryURL: URL
    private let directoryRequestCountFileURL: URL
    private let toolCallRequestCountFileURL: URL
    private let debugLogFileURL: URL

    let baseURL: URL

    var directoryRequestCount: Int {
        Self.readCount(from: directoryRequestCountFileURL)
    }

    var toolCallRequestCount: Int {
        Self.readCount(from: toolCallRequestCountFileURL)
    }

    var debugLog: String {
        (try? String(contentsOf: debugLogFileURL, encoding: .utf8)) ?? ""
    }

    init() async throws {
        let fileManager = FileManager.default
        self.rootDirectoryURL = fileManager.temporaryDirectory
            .appendingPathComponent("SwiftASB-MockAppConnectorMCP-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: rootDirectoryURL, withIntermediateDirectories: true)

        let portFileURL = rootDirectoryURL.appendingPathComponent("port.txt")
        self.directoryRequestCountFileURL = rootDirectoryURL.appendingPathComponent("directory-request-count.txt")
        self.toolCallRequestCountFileURL = rootDirectoryURL.appendingPathComponent("tool-call-request-count.txt")
        self.debugLogFileURL = rootDirectoryURL.appendingPathComponent("debug.log")
        let scriptURL = rootDirectoryURL.appendingPathComponent("mock_app_connector_mcp_server.py")

        try Data("0\n".utf8).write(to: directoryRequestCountFileURL)
        try Data("0\n".utf8).write(to: toolCallRequestCountFileURL)
        try Data().write(to: debugLogFileURL)
        try Data(Self.pythonScript.utf8).write(to: scriptURL)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "python3",
            scriptURL.path,
            portFileURL.path,
            directoryRequestCountFileURL.path,
            toolCallRequestCountFileURL.path,
            debugLogFileURL.path,
        ]
        self.process = process
        try process.run()

        let port = try await MockResponsesServer.waitForPortFile(portFileURL)
        self.baseURL = URL(string: "http://127.0.0.1:\(port)")!
    }

    func stop() {
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }
        try? FileManager.default.removeItem(at: rootDirectoryURL)
    }

    private static func readCount(from url: URL) -> Int {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return 0
        }
        return Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private static let pythonScript = """
    import json
    import sys
    import threading
    import time
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

    port_path, directory_count_path, tool_call_count_path, debug_log_path = sys.argv[1:5]
    pending_elicitation_response = None
    pending_condition = threading.Condition()
    event_stream = None
    event_stream_lock = threading.Lock()

    def log(message):
        with open(debug_log_path, "a", encoding="utf-8") as handle:
            handle.write(message + "\\n")

    def read_count(path):
        try:
            with open(path, "r", encoding="utf-8") as handle:
                return int((handle.read().strip() or "0"))
        except FileNotFoundError:
            return 0

    def increment_count(path):
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(f"{read_count(path) + 1}\\n")

    def json_bytes(value):
        return json.dumps(value, separators=(",", ":")).encode("utf-8")

    def sse_message(value):
        return b"event: message\\n" + b"data: " + json_bytes(value) + b"\\n\\n"

    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, format, *args):
            return

        def do_GET(self):
            log(f"GET {self.path}")
            if self.path.startswith("/connectors/directory/list"):
                self.handle_directory_list()
            elif self.path.startswith("/connectors/directory/list_workspace"):
                self.handle_directory_list()
            elif self.path.startswith("/api/codex/apps"):
                self.handle_event_stream()
            else:
                self.send_response(404)
                self.send_header("content-length", "0")
                self.end_headers()

        def do_POST(self):
            log(f"POST {self.path}")
            if not self.path.startswith("/api/codex/apps"):
                self.send_response(404)
                self.send_header("content-length", "0")
                self.end_headers()
                return

            length = int(self.headers.get("content-length", "0"))
            body = self.rfile.read(length) if length else b"{}"
            try:
                message = json.loads(body.decode("utf-8"))
                log(f"POST body {message}")
            except Exception as error:
                self.send_json({
                    "jsonrpc": "2.0",
                    "id": None,
                    "error": {"code": -32700, "message": f"Invalid JSON: {error}"},
                }, status=400)
                return

            if isinstance(message, list):
                self.send_json([self.response_for_request(item) for item in message if "id" in item])
                return

            if "method" not in message and message.get("id") == 3:
                self.handle_elicitation_response(message)
                return

            method = message.get("method")
            if method == "initialize":
                self.send_json({
                    "jsonrpc": "2.0",
                    "id": message.get("id"),
                    "result": {
                        "protocolVersion": "2025-06-18",
                        "capabilities": {"tools": {}},
                        "serverInfo": {"name": "codex-apps", "version": "0.1.0"},
                    },
                }, session_id="swiftasb-app-connector-session")
            elif method == "notifications/initialized":
                self.send_accepted()
            elif method == "tools/list":
                self.send_json(self.tools_list_response(message.get("id")))
            elif method == "tools/call":
                self.handle_tool_call(message)
            elif "id" in message:
                self.send_json({
                    "jsonrpc": "2.0",
                    "id": message.get("id"),
                    "error": {"code": -32601, "message": f"Unsupported method: {method}"},
                })
            else:
                self.send_accepted()

        def handle_directory_list(self):
            increment_count(directory_count_path)
            bearer_ok = self.headers.get("authorization") == "Bearer chatgpt-token"
            account_ok = self.headers.get("chatgpt-account-id") == "account-123"
            external_logos_ok = "external_logos=true" in self.path
            if not bearer_ok or not account_ok:
                self.send_response(401)
                self.send_header("content-length", "0")
                self.end_headers()
                return
            if not external_logos_ok:
                self.send_response(400)
                self.send_header("content-length", "0")
                self.end_headers()
                return
            self.send_json({
                "apps": [{
                    "id": "calendar",
                    "name": "Calendar",
                    "description": "Calendar connector",
                    "logo_url": None,
                    "logo_url_dark": None,
                    "distribution_channel": None,
                    "branding": None,
                    "app_metadata": None,
                    "labels": None,
                    "install_url": None,
                    "is_accessible": False,
                    "is_enabled": True,
                }],
                "next_token": None,
            })

        def response_for_request(self, message):
            method = message.get("method")
            if method == "tools/list":
                return self.tools_list_response(message.get("id"))
            return {
                "jsonrpc": "2.0",
                "id": message.get("id"),
                "error": {"code": -32601, "message": f"Unsupported batch method: {method}"},
            }

        def tools_list_response(self, request_id):
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "tools": [{
                        "name": "calendar_confirm_action",
                        "description": "Confirm a calendar action.",
                        "inputSchema": {
                            "type": "object",
                            "additionalProperties": False,
                        },
                        "annotations": {
                            "readOnlyHint": True,
                        },
                        "_meta": {
                            "connector_id": "calendar",
                            "connector_name": "Calendar",
                        },
                    }],
                    "nextCursor": None,
                    "_meta": None,
                },
            }

        def handle_elicitation_response(self, message):
            global pending_elicitation_response
            log(f"elicitation response {message}")
            with pending_condition:
                pending_elicitation_response = message
                pending_condition.notify_all()
            self.send_accepted()

        def handle_event_stream(self):
            global event_stream
            log("opening app connector MCP event stream")
            self.send_response(200)
            self.send_header("content-type", "text/event-stream")
            self.send_header("cache-control", "no-cache")
            self.send_header("connection", "keep-alive")
            self.end_headers()
            with event_stream_lock:
                event_stream = self
            try:
                while True:
                    time.sleep(0.25)
            except Exception as error:
                log(f"event stream closed {error}")
            finally:
                with event_stream_lock:
                    if event_stream is self:
                        event_stream = None

        def handle_tool_call(self, message):
            increment_count(tool_call_count_path)
            log(f"tool call {message}")
            request_id = message.get("id")
            self.send_response(200)
            self.send_header("content-type", "text/event-stream")
            self.send_header("cache-control", "no-cache")
            self.send_header("connection", "close")
            self.end_headers()

            elicitation_request = {
                "jsonrpc": "2.0",
                "id": 3,
                "method": "elicitation/create",
                "params": {
                    "message": "Allow this request?",
                    "requestedSchema": {
                        "type": "object",
                        "properties": {
                            "confirmed": {
                                "type": "boolean",
                                "title": "Confirmed",
                            },
                        },
                        "required": ["confirmed"],
                    },
                },
            }
            self.wfile.write(sse_message(elicitation_request))
            self.wfile.flush()
            log(f"sent elicitation request {elicitation_request}")

            deadline = time.time() + 10
            with pending_condition:
                while pending_elicitation_response is None and time.time() < deadline:
                    pending_condition.wait(timeout=0.1)
                response = pending_elicitation_response
            log(f"elicitation wait result {response}")

            output_text = "accepted"
            if isinstance(response, dict):
                result = response.get("result", {})
                action = result.get("action")
                if action == "decline":
                    output_text = "declined"
                elif action == "cancel":
                    output_text = "cancelled"

            tool_response = {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "content": [{
                        "type": "text",
                        "text": output_text,
                    }],
                },
            }
            self.wfile.write(sse_message(tool_response))
            self.wfile.flush()
            log(f"sent tool response {tool_response}")

        def send_json(self, value, status=200, session_id=None):
            body = json_bytes(value)
            self.send_response(status)
            self.send_header("content-type", "application/json")
            self.send_header("content-length", str(len(body)))
            if session_id is not None:
                self.send_header("mcp-session-id", session_id)
            self.end_headers()
            self.wfile.write(body)

        def send_accepted(self):
            self.send_response(202)
            self.send_header("content-length", "0")
            self.end_headers()

    class QuietThreadingHTTPServer(ThreadingHTTPServer):
        def handle_error(self, request, client_address):
            log(f"suppressed request handling error from {client_address}")

    server = QuietThreadingHTTPServer(("127.0.0.1", 0), Handler)
    with open(port_path, "w", encoding="utf-8") as handle:
        handle.write(f"{server.server_address[1]}\\n")
    server.serve_forever()
    """
}

struct MockResponsesEventStream: Encodable, Equatable {
    let body: String

    static func shellCommand(callID: String, command: String) throws -> Self {
        let arguments = try jsonString([
            "command": command,
            "workdir": Optional<String>.none,
            "timeout_ms": 5_000,
        ] as [String: Any?])
        return try .init(events: [
            responseCreated(id: "resp-shell"),
            functionCall(callID: callID, name: "shell_command", arguments: arguments),
            responseCompleted(id: "resp-shell"),
        ])
    }

    static func requestPermissions(
        callID: String,
        reason: String,
        writePaths: [String]
    ) throws -> Self {
        let arguments = try jsonString([
            "reason": reason,
            "permissions": [
                "file_system": [
                    "write": writePaths,
                ],
            ],
        ])
        return try .init(events: [
            responseCreated(id: "resp-permissions"),
            functionCall(callID: callID, name: "request_permissions", arguments: arguments),
            responseCompleted(id: "resp-permissions"),
        ])
    }

    static func requestUserInput(callID: String) throws -> Self {
        let arguments = try jsonString([
            "questions": [
                [
                    "header": "Direction",
                    "id": "direction",
                    "question": "Which deterministic path should the live test choose?",
                    "options": [
                        [
                            "label": "Continue (Recommended)",
                            "description": "Complete the deterministic server-request probe.",
                        ],
                        [
                            "label": "Stop",
                            "description": "Stop before completing the deterministic probe.",
                        ],
                    ],
                ],
            ],
        ])
        return try .init(events: [
            responseCreated(id: "resp-tool-input"),
            functionCall(callID: callID, name: "request_user_input", arguments: arguments),
            responseCompleted(id: "resp-tool-input"),
        ])
    }

    static func mcpElicitationToolCall(callID: String) throws -> Self {
        try .init(events: [
            responseCreated(id: "resp-mcp-elicitation"),
            functionCall(
                callID: callID,
                name: "ask",
                namespace: "mcp__swiftasb_elicitation__",
                arguments: "{}"
            ),
            responseCompleted(id: "resp-mcp-elicitation"),
        ])
    }

    static func appConnectorMcpElicitationToolCall(callID: String) throws -> Self {
        try .init(events: [
            responseCreated(id: "resp-app-connector-mcp-elicitation"),
            functionCall(
                callID: callID,
                name: "_confirm_action",
                namespace: "mcp__codex_apps__calendar",
                arguments: "{}"
            ),
            responseCompleted(id: "resp-app-connector-mcp-elicitation"),
        ])
    }

    static func assistantMessage(_ message: String) throws -> Self {
        try .init(events: [
            responseCreated(id: "resp-final"),
            [
                "type": "response.output_item.done",
                "item": [
                    "type": "message",
                    "role": "assistant",
                    "id": "msg-final",
                    "content": [
                        [
                            "type": "output_text",
                            "text": message,
                        ],
                    ],
                ],
            ],
            responseCompleted(id: "resp-final"),
        ])
    }

    private init(events: [[String: Any]]) throws {
        var body = ""
        for event in events {
            guard let eventType = event["type"] as? String else {
                continue
            }
            body += "event: \(eventType)\n"
            let data = try JSONSerialization.data(withJSONObject: event, options: [.sortedKeys])
            body += "data: \(String(decoding: data, as: UTF8.self))\n\n"
        }
        self.body = body
    }

    private static func responseCreated(id: String) -> [String: Any] {
        [
            "type": "response.created",
            "response": [
                "id": id,
            ],
        ]
    }

    private static func responseCompleted(id: String) -> [String: Any] {
        [
            "type": "response.completed",
            "response": [
                "id": id,
                "usage": [
                    "input_tokens": 0,
                    "input_tokens_details": NSNull(),
                    "output_tokens": 0,
                    "output_tokens_details": NSNull(),
                    "total_tokens": 0,
                ],
            ],
        ]
    }

    private static func functionCall(
        callID: String,
        name: String,
        namespace: String? = nil,
        arguments: String
    ) -> [String: Any] {
        var item: [String: Any] = [
            "type": "function_call",
            "call_id": callID,
            "name": name,
            "arguments": arguments,
        ]
        if let namespace {
            item["namespace"] = namespace
        }

        return [
            "type": "response.output_item.done",
            "item": item,
        ]
    }

    private static func jsonString(_ object: [String: Any?]) throws -> String {
        let normalized = object.reduce(into: [String: Any]()) { partialResult, entry in
            partialResult[entry.key] = entry.value ?? NSNull()
        }
        let data = try JSONSerialization.data(withJSONObject: normalized, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }
}

enum LiveIntegrationError: Error, LocalizedError {
    case timedOut(operation: String, seconds: Double)
    case eventStreamEnded(operation: String)
    case executableResolutionFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case let .timedOut(operation, seconds):
            return "The live Codex integration test timed out after \(seconds) seconds while \(operation)."
        case let .eventStreamEnded(operation):
            return "The live Codex integration test lost the expected event stream while \(operation)."
        case let .executableResolutionFailed(reason):
            return "The live Codex integration test could not resolve the local `codex` executable: \(reason)"
        }
    }
}

func startThread(
    on client: CodexAppServer,
    workspacePath: String,
    label: String,
    approvalPolicy: CodexAppServer.ApprovalPolicy = .never,
    approvalsReviewer: CodexAppServer.ApprovalsReviewer? = nil,
    ephemeral: Bool = true,
    sandboxMode: CodexAppServer.SandboxMode = .workspaceWrite,
    developerInstructions: String = """
    You are running inside a SwiftASB live integration test.
    Do not call tools.
    Do not edit files.
    Do not ask follow-up questions.
    Reply only with the exact text requested by the user message.
    """
) async throws -> CodexThread {
    return try await withTimeout(seconds: 15, operation: "starting the \(label) thread") {
        try await client.startThread(
            .init(
                approvalPolicy: approvalPolicy,
                approvalsReviewer: approvalsReviewer,
                currentDirectoryPath: workspacePath,
                developerInstructions: developerInstructions,
                ephemeral: ephemeral,
                sandboxMode: sandboxMode
            )
        )
    }
}

func startTurn(
    on thread: CodexThread,
    prompt: String,
    approvalPolicy: CodexAppServer.ApprovalPolicy = .never,
    approvalsReviewer: CodexAppServer.ApprovalsReviewer? = nil
) async throws -> CodexTurnHandle {
    return try await withTimeout(seconds: 20, operation: "starting a live turn on thread \(thread.id)") {
        try await thread.startTextTurn(
            prompt,
            approvalPolicy: approvalPolicy,
            approvalsReviewer: approvalsReviewer,
            summary: CodexAppServer.ReasoningSummary.none
        )
    }
}

func startSecondSameThreadTurn(
    on thread: CodexThread,
    prompt: String
) async -> LiveTurnStartOutcome {
    do {
        let turnHandle = try await startTurn(on: thread, prompt: prompt)
        return .started(turnHandle)
    } catch {
        return .failed(String(describing: error))
    }
}

func runApprovalProbeCaseReport(
    _ probeCase: LiveApprovalProbeCase,
    on thread: CodexThread
) async throws -> LiveApprovalProbeReport.Result {
    let turn: CodexTurnHandle
    do {
        turn = try await startTurn(
            on: thread,
            prompt: probeCase.prompt,
            approvalPolicy: .untrusted,
            approvalsReviewer: .user
        )
    } catch {
        return .init(
            probeCase,
            thread: thread,
            turnID: "",
            status: "failed",
            callSnapshots: [],
            latestCompletedItemText: nil,
            error: error
        )
    }

    let minimap = await turn.minimap
    do {
        let result = try await completeLiveTurnAcceptingApprovals(
            turn,
            timeoutSeconds: 90,
            operation: "waiting for the \(probeCase.label) approval probe to complete"
        )
        return .init(probeCase, thread: thread, result: result)
    } catch {
        let snapshots = await MainActor.run(body: { minimap.callSnapshots })
        let completedText = await MainActor.run(body: { minimap.latestCompletedItem?.item.text })
        let status = await MainActor.run(body: { minimap.latestCompletion?.turn.status.rawValue })
        return .init(
            probeCase,
            thread: thread,
            turnID: turn.turn.id,
            status: status ?? "failed",
            callSnapshots: snapshots,
            latestCompletedItemText: completedText,
            error: error
        )
    }
}

func runBehaviorMatrixCase(
    _ matrixCase: LiveBehaviorMatrixCase,
    on client: CodexAppServer,
    harness: LiveCodexHarness
) async -> LiveBehaviorMatrixReport.PolicySandboxResult {
    do {
        let thread = try await startThread(
            on: client,
            workspacePath: harness.approvalProbeWorkspace.path,
            label: "behavior-matrix-\(matrixCase.label)",
            approvalPolicy: matrixCase.approvalPolicy,
            approvalsReviewer: matrixCase.approvalPolicy.requiresUserReviewer ? .user : nil,
            ephemeral: false,
            sandboxMode: matrixCase.sandboxMode,
            developerInstructions: """
            You are running inside a SwiftASB live behavior-matrix probe.
            Perform only the exact requested action.
            If approval is requested, wait for the test harness to answer it.
            Do not ask follow-up questions.
            Reply only with the exact text requested by the user message.
            """
        )
        let turn = try await startTurn(
            on: thread,
            prompt: matrixCase.prompt,
            approvalPolicy: matrixCase.approvalPolicy,
            approvalsReviewer: matrixCase.approvalPolicy.requiresUserReviewer ? .user : nil
        )
        let result = try await completeLiveTurnAcceptingApprovals(
            turn,
            timeoutSeconds: 90,
            operation: "waiting for the \(matrixCase.label) behavior-matrix case to complete"
        )
        return .init(
            label: matrixCase.label,
            approvalPolicy: matrixCase.approvalPolicy.reportLabel,
            sandboxMode: matrixCase.sandboxMode.rawValue,
            threadID: thread.id,
            turnID: result.completion.turn.id,
            status: result.completion.turn.status.rawValue,
            acceptedApprovalKinds: result.acceptedApprovalKinds,
            callKinds: result.callSnapshots.map(\.kind.rawValue),
            callDisplayNames: result.callSnapshots.map(\.displayName),
            latestCompletedItemText: result.latestCompletedItemText,
            inspectedFile: matrixCase.inspectedPath.map(LiveApprovalProbeReport.InspectedFile.init),
            matchedExpectedFinalText: result.latestCompletedItemText == matrixCase.expectedFinalText,
            errorDescription: nil
        )
    } catch {
        return .init(
            label: matrixCase.label,
            approvalPolicy: matrixCase.approvalPolicy.reportLabel,
            sandboxMode: matrixCase.sandboxMode.rawValue,
            threadID: "",
            turnID: "",
            status: "failed",
            acceptedApprovalKinds: [],
            callKinds: [],
            callDisplayNames: [],
            latestCompletedItemText: nil,
            inspectedFile: matrixCase.inspectedPath.map(LiveApprovalProbeReport.InspectedFile.init),
            matchedExpectedFinalText: false,
            errorDescription: String(describing: error)
        )
    }
}

func probeLiveHistoryMatrix(
    on client: CodexAppServer,
    harness: LiveCodexHarness
) async -> LiveBehaviorMatrixReport.HistoryResult {
    do {
        let ephemeralThread = try await startThread(
            on: client,
            workspacePath: harness.threadAWorkspace.path,
            label: "behavior-matrix-ephemeral-history",
            ephemeral: true
        )
        let ephemeralRecentTurns = try await ephemeralThread.makeRecentTurns(limit: 5)
        let ephemeralCount = await MainActor.run { ephemeralRecentTurns.turns.count }

        let storedThread = try await startThread(
            on: client,
            workspacePath: harness.threadBWorkspace.path,
            label: "behavior-matrix-stored-history",
            ephemeral: false
        )
        let storedRecentTurns = try await storedThread.makeRecentTurns(limit: 5)
        let storedCount = await MainActor.run { storedRecentTurns.turns.count }

        return .init(
            ephemeralThreadID: ephemeralThread.id,
            ephemeralRecentTurns: ephemeralCount,
            storedThreadID: storedThread.id,
            storedRecentTurnsBeforeMaterialization: storedCount,
            errorDescription: nil
        )
    } catch {
        return .init(
            ephemeralThreadID: nil,
            ephemeralRecentTurns: nil,
            storedThreadID: nil,
            storedRecentTurnsBeforeMaterialization: nil,
            errorDescription: String(describing: error)
        )
    }
}

func probeLiveSameThreadMatrix(
    on client: CodexAppServer,
    harness: LiveCodexHarness
) async -> LiveBehaviorMatrixReport.SameThreadResult {
    do {
        let thread = try await startThread(
            on: client,
            workspacePath: harness.sameThreadWorkspace.path,
            label: "behavior-matrix-same-thread"
        )
        let firstTurn = try await startTurn(
            on: thread,
            prompt: prompt(label: "BEHAVIOR_MATRIX_SAME_THREAD_FIRST_DONE")
        )
        let outcome = await startSecondSameThreadTurn(
            on: thread,
            prompt: prompt(label: "BEHAVIOR_MATRIX_SAME_THREAD_SECOND_DONE")
        )

        switch outcome {
        case let .failed(errorDescription):
            let completion = try? await awaitCompletion(
                of: firstTurn,
                timeoutSeconds: 45,
                operation: "waiting for the first behavior-matrix same-thread turn to complete"
            )
            return .init(
                threadID: thread.id,
                firstTurnID: firstTurn.turn.id,
                outcome: "rejected",
                errorDescription: errorDescription,
                firstTurnStatus: completion?.turn.status.rawValue
            )
        case .started:
            return .init(
                threadID: thread.id,
                firstTurnID: firstTurn.turn.id,
                outcome: "unexpectedly-started",
                errorDescription: nil,
                firstTurnStatus: nil
            )
        }
    } catch {
        return .init(
            threadID: "",
            firstTurnID: "",
            outcome: "failed",
            errorDescription: String(describing: error),
            firstTurnStatus: nil
        )
    }
}

func probeLiveCLIDiagnosticsMatrix(
    on client: CodexAppServer
) async -> LiveBehaviorMatrixReport.CLIDiagnosticsResult {
    do {
        let diagnostics = try await client.cliExecutableDiagnostics()
        return .init(
            resolvedExecutablePath: diagnostics.resolvedExecutablePath,
            versionString: diagnostics.versionString,
            compatibility: String(describing: diagnostics.compatibility),
            errorDescription: nil
        )
    } catch {
        return .init(
            resolvedExecutablePath: nil,
            versionString: "",
            compatibility: "",
            errorDescription: String(describing: error)
        )
    }
}

func startApprovalProbeThread(
    on client: CodexAppServer,
    harness: LiveCodexHarness,
    label: String,
    sandboxMode: CodexAppServer.SandboxMode
) async throws -> CodexThread {
    try await startThread(
        on: client,
        workspacePath: harness.approvalProbeWorkspace.path,
        label: label,
        approvalPolicy: .untrusted,
        approvalsReviewer: .user,
        ephemeral: false,
        sandboxMode: sandboxMode,
        developerInstructions: """
        You are running inside a SwiftASB live integration test.
        Perform only the exact requested action.
        If approval is requested, wait for the test harness to answer it.
        Do not ask follow-up questions.
        Reply only with the exact text requested by the user message.
        """
    )
}

func awaitCompletion(
    of turnHandle: CodexTurnHandle,
    timeoutSeconds: Double,
    operation: String
) async throws -> CodexTurnCompletion {
    try await withTimeout(seconds: timeoutSeconds, operation: operation) {
        for try await event in turnHandle.events {
            if case let .completed(completion) = event {
                return completion
            }
        }

        throw LiveIntegrationError.eventStreamEnded(operation: operation)
    }
}

func awaitApprovalPathOutcome(
    in minimap: CodexTurnHandle.Minimap,
    timeoutSeconds: Double,
    operation: String
) async throws -> LiveApprovalPathOutcome {
    let deadline = ContinuousClock.now + .seconds(timeoutSeconds)
    while ContinuousClock.now < deadline {
        if let request = await MainActor.run(body: { minimap.latestApprovalRequest }) {
            return .approvalRequested(request)
        }
        if let completion = await MainActor.run(body: { minimap.latestCompletion }) {
            let completedItem = await MainActor.run(body: { minimap.latestCompletedItem?.item.text })
            return .completedWithoutApproval(completion.turn.status, completedItem)
        }
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    throw LiveIntegrationError.timedOut(operation: operation, seconds: timeoutSeconds)
}

func awaitRequestResolution(
    in minimap: CodexTurnHandle.Minimap,
    expectedKind: CodexInteractiveRequestKind,
    timeoutSeconds: Double,
    operation: String
) async throws -> CodexInteractiveRequestResolved {
    let deadline = ContinuousClock.now + .seconds(timeoutSeconds)
    while ContinuousClock.now < deadline {
        if let resolution = await MainActor.run(body: { minimap.latestRequestResolution }),
           resolution.kind == expectedKind {
            return resolution
        }
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    throw LiveIntegrationError.timedOut(operation: operation, seconds: timeoutSeconds)
}

func completeLiveTurnAcceptingApprovals(
    _ turnHandle: CodexTurnHandle,
    timeoutSeconds: Double,
    operation: String
) async throws -> LiveScenarioTurnResult {
    let minimap = await turnHandle.minimap
    let deadline = ContinuousClock.now + .seconds(timeoutSeconds)
    var answeredRequestIDs = Set<CodexRPCRequestID>()
    var acceptedApprovalKinds: [String] = []

    while ContinuousClock.now < deadline {
        if let request = await MainActor.run(body: { minimap.latestApprovalRequest }),
           answeredRequestIDs.contains(request.requestID) == false {
            answeredRequestIDs.insert(request.requestID)
            acceptedApprovalKinds.append(request.kind.rawValue)
            try await turnHandle.respond(
                to: request,
                with: acceptanceResponse(for: request)
            )
        }

        if let completion = await MainActor.run(body: { minimap.latestCompletion }) {
            let snapshots = await MainActor.run(body: { minimap.callSnapshots })
            let completedText = await MainActor.run(body: { minimap.latestCompletedItem?.item.text })
            return LiveScenarioTurnResult(
                completion: completion,
                acceptedApprovalKinds: acceptedApprovalKinds,
                callSnapshots: snapshots,
                latestCompletedItemText: completedText
            )
        }

        try await Task.sleep(nanoseconds: 100_000_000)
    }

    throw LiveIntegrationError.timedOut(operation: operation, seconds: timeoutSeconds)
}

struct RawCommandApprovalResult: Equatable, Sendable {
    let completion: CodexWireTurnCompletedNotification
    let threadID: String
    let turnID: String
    let sawCommandItem: Bool
    let sawApprovalRequest: Bool
    let sawServerRequestResolved: Bool
    let sawWaitingOnApproval: Bool
}

struct RawPermissionsApprovalResult: Equatable, Sendable {
    let completion: CodexWireTurnCompletedNotification
    let threadID: String
    let turnID: String
    let requestedWritePaths: [String]?
    let requestReason: String?
    let sawApprovalRequest: Bool
    let sawServerRequestResolved: Bool
    let sawWaitingOnApproval: Bool
}

struct RawToolUserInputResult: Equatable, Sendable {
    let completion: CodexWireTurnCompletedNotification
    let threadID: String
    let turnID: String
    let questionIDs: [String]
    let sawElicitationRequest: Bool
    let sawServerRequestResolved: Bool
}

struct RawMcpElicitationResult: Equatable, Sendable {
    let completion: CodexWireTurnCompletedNotification
    let threadID: String
    let turnID: String
    let serverName: String?
    let toolName: String?
    let itemStatus: String?
    let itemErrorDescription: String?
    let sawMcpToolCall: Bool
    let sawElicitationRequest: Bool
    let sawServerRequestResolved: Bool
}

func awaitRawCommandApprovalCompletion(
    eventIterator: inout AsyncStream<CodexRPCServerEvent>.Iterator,
    protocolLayer: CodexAppServerProtocol,
    transport: CodexAppServerTransport,
    threadID: String,
    turnID: String,
    operation: String
) async throws -> RawCommandApprovalResult {
    var sawCommandItem = false
    var sawApprovalRequest = false
    var sawServerRequestResolved = false
    var observedEvents: [String] = []

    while let serverEvent = await eventIterator.next() {
        guard let decodedEvent = try protocolLayer.decodeServerEvent(serverEvent) else {
            continue
        }
        observedEvents.append(String(describing: decodedEvent))

        switch decodedEvent {
        case let .itemStarted(started)
            where started.threadID == threadID
                && started.turnID == turnID
                && started.item.type == .commandExecution:
            sawCommandItem = true
        case let .threadStatusChanged(status)
            where status.threadID == threadID
                && status.status.activeFlags?.contains(.waitingOnApproval) == true:
            continue
        case let .commandExecutionApprovalRequested(request)
            where request.threadID == threadID && request.turnID == turnID:
            sawApprovalRequest = true
            let responsePayload = try protocolLayer.makeServerResponse(
                id: request.requestID,
                result: RawCommandExecutionApprovalResponse(decision: "accept")
            )
            try await transport.sendResponse(responsePayload, requestID: request.requestID)
        case let .serverRequestResolved(notification)
            where notification.threadID == threadID:
            sawServerRequestResolved = true
        case let .turnCompleted(completed)
            where completed.threadID == threadID && completed.turn.id == turnID:
            return .init(
                completion: completed,
                threadID: threadID,
                turnID: turnID,
                sawCommandItem: sawCommandItem,
                sawApprovalRequest: sawApprovalRequest,
                sawServerRequestResolved: sawServerRequestResolved,
                sawWaitingOnApproval: observedEvents.contains { $0.contains("waitingOnApproval") }
            )
        default:
            continue
        }
    }

    throw LiveIntegrationError.eventStreamEnded(operation: "\(operation): observedEvents=\(observedEvents)")
}

func awaitRawPermissionsApprovalCompletion(
    eventIterator: inout AsyncStream<CodexRPCServerEvent>.Iterator,
    protocolLayer: CodexAppServerProtocol,
    transport: CodexAppServerTransport,
    threadID: String,
    turnID: String,
    operation: String
) async throws -> RawPermissionsApprovalResult {
    var requestedWritePaths: [String]?
    var requestReason: String?
    var sawApprovalRequest = false
    var sawServerRequestResolved = false
    var observedEvents: [String] = []

    while let serverEvent = await eventIterator.next() {
        guard let decodedEvent = try protocolLayer.decodeServerEvent(serverEvent) else {
            continue
        }
        observedEvents.append(String(describing: decodedEvent))

        switch decodedEvent {
        case let .threadStatusChanged(status)
            where status.threadID == threadID
                && status.status.activeFlags?.contains(.waitingOnApproval) == true:
            continue
        case let .permissionsApprovalRequested(request)
            where request.threadID == threadID && request.turnID == turnID:
            sawApprovalRequest = true
            requestedWritePaths = request.permissions.fileSystem?.write
            requestReason = request.reason
            let responsePayload = try protocolLayer.makeServerResponse(
                id: request.requestID,
                result: RawPermissionsApprovalResponse(
                    permissions: .init(
                        fileSystem: .init(read: nil, write: request.permissions.fileSystem?.write),
                        network: request.permissions.network.map { .init(enabled: $0.enabled) }
                    ),
                    scope: "turn"
                )
            )
            try await transport.sendResponse(responsePayload, requestID: request.requestID)
        case let .serverRequestResolved(notification)
            where notification.threadID == threadID:
            sawServerRequestResolved = true
        case let .turnCompleted(completed)
            where completed.threadID == threadID && completed.turn.id == turnID:
            return .init(
                completion: completed,
                threadID: threadID,
                turnID: turnID,
                requestedWritePaths: requestedWritePaths,
                requestReason: requestReason,
                sawApprovalRequest: sawApprovalRequest,
                sawServerRequestResolved: sawServerRequestResolved,
                sawWaitingOnApproval: observedEvents.contains { $0.contains("waitingOnApproval") }
            )
        default:
            continue
        }
    }

    throw LiveIntegrationError.eventStreamEnded(operation: "\(operation): observedEvents=\(observedEvents)")
}

func awaitRawToolUserInputCompletion(
    eventIterator: inout AsyncStream<CodexRPCServerEvent>.Iterator,
    protocolLayer: CodexAppServerProtocol,
    transport: CodexAppServerTransport,
    threadID: String,
    turnID: String,
    operation: String
) async throws -> RawToolUserInputResult {
    var questionIDs: [String] = []
    var sawElicitationRequest = false
    var sawServerRequestResolved = false
    var observedEvents: [String] = []

    while let serverEvent = await eventIterator.next() {
        guard let decodedEvent = try protocolLayer.decodeServerEvent(serverEvent) else {
            continue
        }
        observedEvents.append(String(describing: decodedEvent))

        switch decodedEvent {
        case let .toolUserInputRequested(request)
            where request.threadID == threadID && request.turnID == turnID:
            sawElicitationRequest = true
            questionIDs = request.questions.map(\.id)
            let responsePayload = try protocolLayer.makeServerResponse(
                id: request.requestID,
                result: RawToolUserInputResponse(
                    answers: [
                        "direction": .init(answers: ["Continue (Recommended)"]),
                    ]
                )
            )
            try await transport.sendResponse(responsePayload, requestID: request.requestID)
        case let .serverRequestResolved(notification)
            where notification.threadID == threadID:
            sawServerRequestResolved = true
        case let .turnCompleted(completed)
            where completed.threadID == threadID && completed.turn.id == turnID:
            guard sawElicitationRequest else {
                throw LiveIntegrationError.eventStreamEnded(operation: "\(operation): observedEvents=\(observedEvents)")
            }
            return .init(
                completion: completed,
                threadID: threadID,
                turnID: turnID,
                questionIDs: questionIDs,
                sawElicitationRequest: sawElicitationRequest,
                sawServerRequestResolved: sawServerRequestResolved
            )
        default:
            continue
        }
    }

    throw LiveIntegrationError.eventStreamEnded(operation: "\(operation): observedEvents=\(observedEvents)")
}

func awaitRawMcpElicitationCompletion(
    eventIterator: inout AsyncStream<CodexRPCServerEvent>.Iterator,
    protocolLayer: CodexAppServerProtocol,
    transport: CodexAppServerTransport,
    threadID: String,
    turnID: String,
    operation: String
) async throws -> RawMcpElicitationResult {
    var serverName: String?
    var toolName: String?
    var itemStatus: String?
    var itemErrorDescription: String?
    var sawMcpToolCall = false
    var sawElicitationRequest = false
    var sawServerRequestResolved = false
    var observedEvents: [String] = []

    while let serverEvent = await eventIterator.next() {
        guard let decodedEvent = try protocolLayer.decodeServerEvent(serverEvent) else {
            continue
        }
        observedEvents.append(String(describing: decodedEvent))

        switch decodedEvent {
        case let .itemStarted(started)
            where started.threadID == threadID
                && started.turnID == turnID
                && started.item.type == .mcpToolCall:
            sawMcpToolCall = true
            serverName = started.item.server
            toolName = started.item.tool
            itemStatus = started.item.status
        case let .itemCompleted(completed)
            where completed.threadID == threadID
                && completed.turnID == turnID
                && completed.item.type == .mcpToolCall:
            sawMcpToolCall = true
            serverName = completed.item.server
            toolName = completed.item.tool
            itemStatus = completed.item.status
            itemErrorDescription = completed.item.error.map { String(describing: $0) }
        case let .mcpServerElicitationRequested(request)
            where request.threadID == threadID && (request.turnID == nil || request.turnID == turnID):
            sawElicitationRequest = true
            serverName = request.serverName
            let responsePayload = try protocolLayer.makeServerResponse(
                id: request.requestID,
                result: RawMcpServerElicitationResponse(
                    action: "accept",
                    content: ["confirmed": true],
                    meta: nil
                )
            )
            try await transport.sendResponse(responsePayload, requestID: request.requestID)
        case let .serverRequestResolved(notification)
            where notification.threadID == threadID:
            sawServerRequestResolved = true
        case let .turnCompleted(completed)
            where completed.threadID == threadID && completed.turn.id == turnID:
            return .init(
                completion: completed,
                threadID: threadID,
                turnID: turnID,
                serverName: serverName,
                toolName: toolName,
                itemStatus: itemStatus,
                itemErrorDescription: itemErrorDescription,
                sawMcpToolCall: sawMcpToolCall,
                sawElicitationRequest: sawElicitationRequest,
                sawServerRequestResolved: sawServerRequestResolved
            )
        default:
            continue
        }
    }

    throw LiveIntegrationError.eventStreamEnded(operation: "\(operation): observedEvents=\(observedEvents)")
}

func awaitRawTurnCompletion(
    eventIterator: inout AsyncStream<CodexRPCServerEvent>.Iterator,
    protocolLayer: CodexAppServerProtocol,
    threadID: String,
    turnID: String,
    operation: String
) async throws -> CodexWireTurnCompletedNotification {
    var observedEvents: [String] = []

    while let serverEvent = await eventIterator.next() {
        guard let decodedEvent = try protocolLayer.decodeServerEvent(serverEvent) else {
            continue
        }
        observedEvents.append(String(describing: decodedEvent))

        if case let .turnCompleted(completed) = decodedEvent,
           completed.threadID == threadID,
           completed.turn.id == turnID {
            return completed
        }
    }

    throw LiveIntegrationError.eventStreamEnded(operation: "\(operation): observedEvents=\(observedEvents)")
}

struct RawCommandExecutionApprovalResponse: Encodable {
    let decision: String
}

struct RawPermissionsApprovalResponse: Encodable {
    let permissions: RawPermissionProfile
    let scope: String
}

struct RawPermissionProfile: Encodable {
    let fileSystem: FileSystem?
    let network: Network?

    struct FileSystem: Encodable {
        let read: [String]?
        let write: [String]?
    }

    struct Network: Encodable {
        let enabled: Bool?
    }
}

struct RawToolUserInputResponse: Encodable {
    let answers: [String: Answer]

    struct Answer: Encodable {
        let answers: [String]
    }
}

struct RawMcpServerElicitationResponse: Encodable {
    let action: String
    let content: [String: Bool]?
    let meta: [String: String]?

    enum CodingKeys: String, CodingKey {
        case action
        case content
        case meta = "_meta"
    }
}

func acceptanceResponse(for request: CodexApprovalRequest) -> CodexApprovalResponse {
    switch request {
    case .commandExecution:
        return .commandExecution(.accept)
    case .fileChange:
        return .fileChange(.accept)
    case let .permissions(permissionsRequest):
        return .permissions(
            .init(
                permissions: permissionsRequest.permissions,
                scope: .turn
            )
        )
    }
}

func withTimeout<T: Sendable>(
    seconds: Double,
    operation: String,
    body: @escaping @Sendable () async throws -> T
) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await body()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw LiveIntegrationError.timedOut(operation: operation, seconds: seconds)
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

func prompt(label: String) -> String {
    """
    This is a live SwiftASB integration test.
    Do not call tools.
    Do not edit files.
    Do not ask questions.
    Reply with exactly this text and nothing else: \(label)
    """
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension CodexAppServer.TurnStatus {
    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .interrupted:
            return true
        case .inProgress:
            return false
        }
    }
}

extension CodexAppServer.ApprovalPolicy {
    var reportLabel: String {
        switch self {
        case .never:
            return "never"
        case .onFailure:
            return "onFailure"
        case .onRequest:
            return "onRequest"
        case .untrusted:
            return "untrusted"
        case let .granular(policy):
            return """
            granular(mcpElicitations:\(policy.mcpElicitations),requestPermissions:\(String(describing: policy.requestPermissions)),rules:\(policy.rules),sandboxApproval:\(policy.sandboxApproval),skillApproval:\(String(describing: policy.skillApproval)))
            """
        }
    }

    var requiresUserReviewer: Bool {
        switch self {
        case .never:
            return false
        case .onFailure, .onRequest, .untrusted, .granular:
            return true
        }
    }
}

func makeInitializedLiveClient(
    using harness: LiveCodexHarness,
    experimentalAPI: Bool? = nil
) async throws -> CodexAppServer {
    let client = CodexAppServer(configuration: harness.configuration)
    try await client.start()

    do {
        _ = try await withTimeout(seconds: 15, operation: "initializing the live Codex app-server") {
            try await client.initialize(
                .init(
                    capabilities: .init(
                        experimentalAPI: experimentalAPI,
                        optOutNotificationMethods: [
                            "account/rateLimits/updated",
                            "hook/completed",
                            "hook/started",
                            "mcpServer/startupStatus/updated",
                        ]
                    ),
                    clientInfo: .init(
                        name: "SwiftASBLiveTests",
                        title: "SwiftASB Live Integration Tests",
                        version: "0.1.0"
                    )
                )
            )
        }
        return client
    } catch {
        await client.stop()
        throw error
    }
}
