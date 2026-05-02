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

    struct McpServerStatusPage: Sendable, Equatable {
        public let nextCursor: String?
        public let servers: [McpServerStatus]
    }

    struct McpServerStatus: Sendable, Equatable, Identifiable {
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

    struct McpResourceTemplate: Sendable, Equatable {
        public let annotations: JSONValue?
        public let description: String?
        public let mimeType: String?
        public let name: String
        public let title: String?
        public let uriTemplate: String
    }

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
