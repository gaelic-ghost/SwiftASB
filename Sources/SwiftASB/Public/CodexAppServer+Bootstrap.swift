import Foundation

extension CodexAppServer {
    public struct CLIExecutableDiagnostics: Sendable, Equatable {
        public enum Source: Sendable, Equatable {
            case explicit
            case path
            case homebrewAppleSilicon
            case homebrewIntel
            case npmGlobal(prefix: String)
        }

        public enum Compatibility: Sendable, Equatable {
            case supported(documentedWindow: String)
            case outsideDocumentedWindow(documentedWindow: String)
            case unknownVersionFormat(documentedWindow: String)
        }

        public let source: Source
        public let resolvedExecutablePath: String?
        public let versionString: String
        public let compatibility: Compatibility
    }

    public struct Configuration: Sendable, Equatable {
        public var codexExecutableURL: URL?
        public var arguments: [String]
        public var currentDirectoryURL: URL?
        public var environment: [String: String]?

        public init(
            codexExecutableURL: URL? = nil,
            arguments: [String] = ["app-server", "--listen", "stdio://"],
            currentDirectoryURL: URL? = nil,
            environment: [String: String]? = nil
        ) {
            self.codexExecutableURL = codexExecutableURL
            self.arguments = arguments
            self.currentDirectoryURL = currentDirectoryURL
            self.environment = environment
        }
    }

    public struct InitializeRequest: Sendable, Equatable {
        public var capabilities: InitializeCapabilities
        public var clientInfo: ClientInfo

        public init(
            capabilities: InitializeCapabilities = .init(),
            clientInfo: ClientInfo
        ) {
            self.capabilities = capabilities
            self.clientInfo = clientInfo
        }
    }

    public struct InitializeCapabilities: Sendable, Equatable {
        public var experimentalAPI: Bool?
        public var optOutNotificationMethods: [String]?

        public init(
            experimentalAPI: Bool? = nil,
            optOutNotificationMethods: [String]? = nil
        ) {
            self.experimentalAPI = experimentalAPI
            self.optOutNotificationMethods = optOutNotificationMethods
        }
    }

    public struct ClientInfo: Sendable, Equatable {
        public var name: String
        public var title: String?
        public var version: String

        public init(
            name: String,
            title: String? = nil,
            version: String
        ) {
            self.name = name
            self.title = title
            self.version = version
        }
    }

    public struct InitializeSession: Sendable, Equatable {
        public let codexHome: String
        public let platformFamily: String
        public let platformOS: String
        public let userAgent: String
    }

}
