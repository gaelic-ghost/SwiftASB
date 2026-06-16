import Foundation

@available(*, deprecated, renamed: "CodexExtensions.MCP")
public typealias CodexMCP = CodexExtensions.MCP

public extension CodexExtensions {
    /// App-server-owned MCP configuration surface.
    ///
    /// `CodexExtensions.MCP` exposes opinionated MCP server installation without
    /// exposing the app-server's raw config editing API.
    struct MCP: Sendable {
        /// Transport-specific MCP server definition to install into Codex config.
        public enum ServerDefinition: Sendable, Equatable {
            case stdio(StdioServer)
            case http(HTTPServer)

            public var name: String {
                switch self {
                    case let .stdio(server):
                        server.name
                    case let .http(server):
                        server.name
                }
            }

            /// Creates a stdio MCP server definition.
            public static func stdio(
                name: String,
                command: String,
                arguments: [String] = [],
                currentDirectoryPath: String? = nil,
                environment: [String: String] = [:],
                inheritedEnvironmentVariables: [String] = [],
                options: InstallOptions = .init()
            ) -> Self {
                .stdio(
                    .init(
                        name: name,
                        command: command,
                        arguments: arguments,
                        currentDirectoryPath: currentDirectoryPath,
                        environment: environment,
                        inheritedEnvironmentVariables: inheritedEnvironmentVariables,
                        options: options
                    )
                )
            }

            /// Creates a streamable HTTP MCP server definition.
            public static func http(
                name: String,
                url: URL,
                authorization: HTTPAuthorization? = nil,
                headers: [String: String] = [:],
                environmentHeaders: [String: String] = [:],
                options: InstallOptions = .init()
            ) -> Self {
                .http(
                    .init(
                        name: name,
                        url: url,
                        authorization: authorization,
                        headers: headers,
                        environmentHeaders: environmentHeaders,
                        options: options
                    )
                )
            }
        }

        /// Stdio MCP server launch definition.
        public struct StdioServer: Sendable, Equatable {
            public var name: String
            public var command: String
            public var arguments: [String]
            public var currentDirectoryPath: String?
            public var environment: [String: String]
            public var inheritedEnvironmentVariables: [String]
            public var options: InstallOptions

            public init(
                name: String,
                command: String,
                arguments: [String] = [],
                currentDirectoryPath: String? = nil,
                environment: [String: String] = [:],
                inheritedEnvironmentVariables: [String] = [],
                options: InstallOptions = .init()
            ) {
                self.name = name
                self.command = command
                self.arguments = arguments
                self.currentDirectoryPath = currentDirectoryPath
                self.environment = environment
                self.inheritedEnvironmentVariables = inheritedEnvironmentVariables
                self.options = options
            }
        }

        /// Streamable HTTP MCP server definition.
        public struct HTTPServer: Sendable, Equatable {
            public var name: String
            public var url: URL
            public var authorization: HTTPAuthorization?
            public var headers: [String: String]
            public var environmentHeaders: [String: String]
            public var options: InstallOptions

            public init(
                name: String,
                url: URL,
                authorization: HTTPAuthorization? = nil,
                headers: [String: String] = [:],
                environmentHeaders: [String: String] = [:],
                options: InstallOptions = .init()
            ) {
                self.name = name
                self.url = url
                self.authorization = authorization
                self.headers = headers
                self.environmentHeaders = environmentHeaders
                self.options = options
            }
        }

        /// HTTP authorization source for an MCP server.
        public enum HTTPAuthorization: Sendable, Equatable {
            case bearerTokenEnvironmentVariable(String)
        }

        /// Shared install options for stdio and HTTP MCP servers.
        public struct InstallOptions: Sendable, Equatable {
            public var enabled: Bool
            public var required: Bool?
            public var startupTimeoutSeconds: Double?
            public var toolTimeoutSeconds: Double?
            public var toolPolicy: ToolPolicy

            public init(
                enabled: Bool = true,
                required: Bool? = nil,
                startupTimeoutSeconds: Double? = nil,
                toolTimeoutSeconds: Double? = nil,
                toolPolicy: ToolPolicy = .automatic
            ) {
                self.enabled = enabled
                self.required = required
                self.startupTimeoutSeconds = startupTimeoutSeconds
                self.toolTimeoutSeconds = toolTimeoutSeconds
                self.toolPolicy = toolPolicy
            }
        }

        /// Tool exposure and approval policy for one MCP server.
        public struct ToolPolicy: Sendable, Equatable {
            public var enabledTools: [String]?
            public var disabledTools: [String]?
            public var defaultApprovalMode: ToolApprovalMode?
            public var toolApprovalModes: [String: ToolApprovalMode]

            public init(
                enabledTools: [String]? = nil,
                disabledTools: [String]? = nil,
                defaultApprovalMode: ToolApprovalMode? = nil,
                toolApprovalModes: [String: ToolApprovalMode] = [:]
            ) {
                self.enabledTools = enabledTools
                self.disabledTools = disabledTools
                self.defaultApprovalMode = defaultApprovalMode
                self.toolApprovalModes = toolApprovalModes
            }

            public static let automatic = Self()

            public static func allowOnly(_ toolNames: [String]) -> Self {
                .init(enabledTools: toolNames)
            }

            public static func deny(_ toolNames: [String]) -> Self {
                .init(disabledTools: toolNames)
            }

            public static func defaultApproval(_ mode: ToolApprovalMode) -> Self {
                .init(defaultApprovalMode: mode)
            }
        }

        /// Approval behavior for MCP tools.
        public enum ToolApprovalMode: String, Sendable, Equatable {
            case automatic = "auto"
            case prompt
            case approve
        }

        /// Result returned after installing an MCP server definition.
        public struct InstallResult: Sendable, Equatable {
            public enum WriteStatus: String, Sendable, Equatable {
                case ok
                case okOverridden
            }

            public let configFilePath: String
            public let server: CodexAppServer.McpServerSummary?
            public let status: WriteStatus
            public let version: String
        }

        private let appServer: CodexAppServer

        init(appServer: CodexAppServer) {
            self.appServer = appServer
        }

        /// Installs an MCP server into user-level Codex configuration.
        @discardableResult
        public func install(_ definition: ServerDefinition) async throws -> InstallResult {
            try await appServer.installMCPServer(definition)
        }

        /// Returns SwiftASB's latest full global MCP server status snapshot.
        public func statusSnapshot() async -> CodexAppServer.McpServerStatusPage {
            await appServer.mcpServerStatusSnapshot()
        }

        /// Reads one advertised MCP resource.
        public func readResource(
            _ request: CodexAppServer.McpResourceReadRequest
        ) async throws -> CodexAppServer.McpResourceReadResult {
            try await appServer.readMcpResource(request)
        }

        /// Reads one advertised MCP resource by server name and URI.
        public func readResource(
            server: String,
            uri: String,
            threadID: String? = nil
        ) async throws -> CodexAppServer.McpResourceReadResult {
            try await readResource(
                .init(server: server, uri: uri, threadID: threadID)
            )
        }
    }
}

public extension CodexAppServer {
    /// App-server-owned MCP configuration surface.
    @available(*, deprecated, message: "Use appServer.extensions.mcp or appServer.extensions.install(.mcp(...)) instead.")
    var mcp: SwiftASB.CodexExtensions.MCP {
        SwiftASB.CodexExtensions.MCP(appServer: self)
    }
}

extension CodexExtensions.MCP.ServerDefinition {
    var configValue: CodexAppServer.JSONValue {
        switch self {
            case let .stdio(server):
                server.configValue
            case let .http(server):
                server.configValue
        }
    }
}

extension CodexExtensions.MCP.StdioServer {
    var configValue: CodexAppServer.JSONValue {
        var object: [String: CodexAppServer.JSONValue] = [
            "command": .string(command),
            "enabled": .bool(options.enabled),
        ]

        if arguments.isEmpty == false {
            object["args"] = .array(arguments.map(CodexAppServer.JSONValue.string))
        }
        if let currentDirectoryPath {
            object["cwd"] = .string(currentDirectoryPath)
        }
        if environment.isEmpty == false {
            object["env"] = .object(environment.mapValues(CodexAppServer.JSONValue.string))
        }
        if inheritedEnvironmentVariables.isEmpty == false {
            object["env_vars"] = .array(inheritedEnvironmentVariables.map(CodexAppServer.JSONValue.string))
        }

        options.addConfigFields(to: &object)
        return .object(object)
    }
}

extension CodexExtensions.MCP.HTTPServer {
    var configValue: CodexAppServer.JSONValue {
        var object: [String: CodexAppServer.JSONValue] = [
            "enabled": .bool(options.enabled),
            "url": .string(url.absoluteString),
        ]

        switch authorization {
            case let .bearerTokenEnvironmentVariable(environmentVariable)?:
                object["bearer_token_env_var"] = .string(environmentVariable)
            case nil:
                break
        }

        if headers.isEmpty == false {
            object["http_headers"] = .object(headers.mapValues(CodexAppServer.JSONValue.string))
        }
        if environmentHeaders.isEmpty == false {
            object["env_http_headers"] = .object(environmentHeaders.mapValues(CodexAppServer.JSONValue.string))
        }

        options.addConfigFields(to: &object)
        return .object(object)
    }
}

extension CodexExtensions.MCP.InstallOptions {
    func addConfigFields(to object: inout [String: CodexAppServer.JSONValue]) {
        if let required {
            object["required"] = .bool(required)
        }
        if let startupTimeoutSeconds {
            object["startup_timeout_sec"] = .double(startupTimeoutSeconds)
        }
        if let toolTimeoutSeconds {
            object["tool_timeout_sec"] = .double(toolTimeoutSeconds)
        }
        toolPolicy.addConfigFields(to: &object)
    }
}

extension CodexExtensions.MCP.ToolPolicy {
    func addConfigFields(to object: inout [String: CodexAppServer.JSONValue]) {
        if let enabledTools {
            object["enabled_tools"] = .array(enabledTools.map(CodexAppServer.JSONValue.string))
        }
        if let disabledTools {
            object["disabled_tools"] = .array(disabledTools.map(CodexAppServer.JSONValue.string))
        }
        if let defaultApprovalMode {
            object["default_tools_approval_mode"] = .string(defaultApprovalMode.rawValue)
        }
        if toolApprovalModes.isEmpty == false {
            object["tools"] = .object(
                toolApprovalModes.mapValues { approvalMode in
                    .object(["approval_mode": .string(approvalMode.rawValue)])
                }
            )
        }
    }
}

extension CodexExtensions.MCP.InstallResult.WriteStatus {
    init(protocolValue: CodexProtocolConfigWriteStatus) {
        switch protocolValue {
            case .ok:
                self = .ok
            case .okOverridden:
                self = .okOverridden
        }
    }
}
