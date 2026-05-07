public extension CodexAppServer {
    /// Request used to read app-server MCP status snapshots.
    struct McpServerStatusListRequest: Sendable, Equatable {
        public enum Detail: String, Sendable, Equatable {
            case full
            case toolsAndAuthOnly
        }

        public var cursor: String?
        public var detail: Detail?
        public var limit: Int?

        /// Creates an MCP status-list request.
        ///
        /// Nil pagination and detail fields are omitted, which lets the
        /// app-server choose its default page and detail level.
        public init(
            cursor: String? = nil,
            limit: Int? = nil,
            detail: Detail? = nil
        ) {
            self.cursor = cursor
            self.detail = detail
            self.limit = limit
        }
    }

    /// Request used to read one advertised MCP resource.
    struct McpResourceReadRequest: Sendable, Equatable {
        public var server: String
        public var threadID: String?
        public var uri: String

        /// Creates an MCP resource-read request.
        ///
        /// `threadID` is optional because some MCP resources are app-wide while
        /// others may be scoped by Codex to an active thread context.
        public init(server: String, uri: String, threadID: String? = nil) {
            self.server = server
            self.uri = uri
            self.threadID = threadID
        }
    }

    /// Resource contents returned by an MCP server.
    struct McpResourceReadResult: Sendable, Equatable {
        public let contents: [McpResourceContent]
    }

    /// One text or blob payload returned from an MCP resource read.
    struct McpResourceContent: Sendable, Equatable {
        public let blob: String?
        public let metadata: JSONValue?
        public let mimeType: String?
        public let text: String?
        public let uri: String
    }

    /// One page of MCP server status results.
    struct McpServerStatusPage: Sendable, Equatable {
        public let nextCursor: String?
        public let servers: [McpServerStatus]
    }

    /// Capability snapshot for one configured MCP server.
    struct McpServerStatus: Sendable, Equatable, Identifiable {
        /// Authentication state reported for an MCP server.
        public enum AuthStatus: String, Sendable, Equatable {
            case bearerToken
            case notLoggedIn
            case oAuth
            case unsupported
        }

        public var id: String { name }
        public let authStatus: AuthStatus
        public let name: String
        public let resources: [McpResource]
        public let resourceTemplates: [McpResourceTemplate]
        public let tools: [String: McpTool]
    }

    /// MCP resource advertised by a server.
    struct McpResource: Sendable, Equatable {
        public let annotations: JSONValue?
        public let description: String?
        public let icons: [JSONValue]?
        public let metadata: JSONValue?
        public let mimeType: String?
        public let name: String
        public let size: Int?
        public let title: String?
        public let uri: String
    }

    /// MCP resource template advertised by a server.
    struct McpResourceTemplate: Sendable, Equatable {
        public let annotations: JSONValue?
        public let description: String?
        public let mimeType: String?
        public let name: String
        public let title: String?
        public let uriTemplate: String
    }

    /// MCP tool advertised by a server.
    struct McpTool: Sendable, Equatable {
        public let annotations: JSONValue?
        public let description: String?
        public let icons: [JSONValue]?
        public let inputSchema: JSONValue
        public let metadata: JSONValue?
        public let name: String
        public let outputSchema: JSONValue?
        public let title: String?
    }
}

extension CodexAppServer.McpServerStatusListRequest.Detail {
    var wireValue: CodexWireMCPServerStatusDetail {
        switch self {
        case .full:
            .full
        case .toolsAndAuthOnly:
            .toolsAndAuthOnly
        }
    }
}

extension CodexAppServer.McpServerStatus {
    init(wireValue: CodexWireMCPServerStatus) {
        self.init(
            authStatus: .init(wireValue: wireValue.authStatus),
            name: wireValue.name,
            resources: wireValue.resources.map(CodexAppServer.McpResource.init),
            resourceTemplates: wireValue.resourceTemplates.map(CodexAppServer.McpResourceTemplate.init),
            tools: wireValue.tools.mapValues(CodexAppServer.McpTool.init)
        )
    }
}

extension CodexAppServer.McpServerStatus.AuthStatus {
    init(wireValue: CodexWireMCPAuthStatus) {
        switch wireValue {
        case .bearerToken:
            self = .bearerToken
        case .notLoggedIn:
            self = .notLoggedIn
        case .oAuth:
            self = .oAuth
        case .unsupported:
            self = .unsupported
        }
    }
}

extension CodexAppServer.McpResourceReadResult {
    init(wireValue: CodexWireMCPResourceReadResponse) {
        self.init(contents: wireValue.contents.map(CodexAppServer.McpResourceContent.init))
    }
}

extension CodexAppServer.McpResourceContent {
    init(wireValue: CodexWireResourceContent) {
        self.init(
            blob: wireValue.blob,
            metadata: wireValue.meta.map(CodexAppServer.JSONValue.init(wireValue:)),
            mimeType: wireValue.mimeType,
            text: wireValue.text,
            uri: wireValue.uri
        )
    }
}

extension CodexAppServer.McpResource {
    init(wireValue: CodexWireResource) {
        self.init(
            annotations: wireValue.annotations.map(CodexAppServer.JSONValue.init(wireValue:)),
            description: wireValue.description,
            icons: wireValue.icons?.map(CodexAppServer.JSONValue.init(wireValue:)),
            metadata: wireValue.meta.map(CodexAppServer.JSONValue.init(wireValue:)),
            mimeType: wireValue.mimeType,
            name: wireValue.name,
            size: wireValue.size,
            title: wireValue.title,
            uri: wireValue.uri
        )
    }
}

extension CodexAppServer.McpResourceTemplate {
    init(wireValue: CodexWireResourceTemplate) {
        self.init(
            annotations: wireValue.annotations.map(CodexAppServer.JSONValue.init(wireValue:)),
            description: wireValue.description,
            mimeType: wireValue.mimeType,
            name: wireValue.name,
            title: wireValue.title,
            uriTemplate: wireValue.uriTemplate
        )
    }
}

extension CodexAppServer.McpTool {
    init(wireValue: CodexWireTool) {
        self.init(
            annotations: wireValue.annotations.map(CodexAppServer.JSONValue.init(wireValue:)),
            description: wireValue.description,
            icons: wireValue.icons?.map(CodexAppServer.JSONValue.init(wireValue:)),
            inputSchema: .init(wireValue: wireValue.inputSchema),
            metadata: wireValue.meta.map(CodexAppServer.JSONValue.init(wireValue:)),
            name: wireValue.name,
            outputSchema: wireValue.outputSchema.map(CodexAppServer.JSONValue.init(wireValue:)),
            title: wireValue.title
        )
    }
}
