import Foundation

extension CodexAppServer {
    /// Diagnostics for the local Codex executable selected at startup.
    public struct CLIExecutableDiagnostics: Sendable, Equatable {
        /// Local install location SwiftASB used to find the Codex executable.
        public enum Source: Sendable, Equatable {
            case explicit
            case path
            case homebrewAppleSilicon
            case homebrewIntel
            case npmGlobal(prefix: String)
        }

        /// Compatibility result for the selected Codex CLI version.
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

    /// Runtime configuration used when SwiftASB launches the local Codex app-server.
    public struct Configuration: Sendable, Equatable {
        public var codexExecutableURL: URL?
        public var arguments: [String]
        public var currentDirectoryURL: URL?
        public var environment: [String: String]?

        /// Creates launch configuration for the app-server subprocess.
        ///
        /// Omitting `codexExecutableURL` lets SwiftASB discover `codex` from the
        /// supported local install locations. Omitting `arguments` starts the
        /// standard stdio app-server command. Omitting `currentDirectoryURL` or
        /// `environment` lets the launched process inherit the caller's current
        /// process defaults.
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

    /// Client handshake payload sent to Codex after the app-server process starts.
    public struct InitializeRequest: Sendable, Equatable {
        public var capabilities: InitializeCapabilities
        public var clientInfo: ClientInfo

        /// Creates an initialize request.
        ///
        /// Omitting `capabilities` sends an empty capability set, leaving Codex
        /// to use its default notification behavior.
        public init(
            capabilities: InitializeCapabilities = .init(),
            clientInfo: ClientInfo
        ) {
            self.capabilities = capabilities
            self.clientInfo = clientInfo
        }
    }

    /// Optional client capabilities advertised during initialization.
    public struct InitializeCapabilities: Sendable, Equatable {
        public var experimentalAPI: Bool?
        public var optOutNotificationMethods: [String]?

        /// Creates capability settings for the initialize handshake.
        ///
        /// Nil properties are omitted from the app-server request, so the Codex
        /// app-server keeps ownership of its default capability behavior.
        public init(
            experimentalAPI: Bool? = nil,
            optOutNotificationMethods: [String]? = nil
        ) {
            self.experimentalAPI = experimentalAPI
            self.optOutNotificationMethods = optOutNotificationMethods
        }
    }

    /// Identifies the SwiftASB consumer during initialization.
    public struct ClientInfo: Sendable, Equatable {
        public var name: String
        public var title: String?
        public var version: String

        /// Creates client metadata for the initialize handshake.
        ///
        /// Omitting `title` sends only the required client name and version.
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

    /// Session metadata returned by the app-server after initialization.
    public struct InitializeSession: Sendable, Equatable {
        public let codexHome: String
        public let platformFamily: String
        public let platformOS: String
        public let userAgent: String
    }

}
