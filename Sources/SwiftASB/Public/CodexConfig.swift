import Foundation

/// App-server-owned configuration read surface.
///
/// `CodexConfig` reads effective Codex configuration through the app-server so
/// sandboxed clients do not need to inspect config files directly.
public struct CodexConfig: Sendable {
    private let appServer: CodexAppServer

    init(appServer: CodexAppServer) {
        self.appServer = appServer
    }

    /// Request used to read effective app-server configuration.
    public struct ReadRequest: Sendable, Equatable {
        public var currentDirectoryPath: String?
        public var includeLayers: Bool?

        /// Creates a config-read request.
        ///
        /// Nil values let the app-server choose its current working directory
        /// and whether to include source layers.
        public init(
            currentDirectoryPath: String? = nil,
            includeLayers: Bool? = nil
        ) {
            self.currentDirectoryPath = currentDirectoryPath
            self.includeLayers = includeLayers
        }
    }

    /// Effective configuration plus source metadata returned by the app-server.
    public struct Snapshot: Sendable, Equatable {
        public let config: CodexAppServer.JSONValue
        public let layers: [Layer]?
        public let origins: [String: LayerMetadata]
    }

    /// One config layer contributing to an effective configuration.
    public struct Layer: Sendable, Equatable {
        public let config: CodexAppServer.JSONValue
        public let disabledReason: String?
        public let name: LayerSource
        public let version: String
    }

    /// Metadata describing the source that provided a config value.
    public struct LayerMetadata: Sendable, Equatable {
        public let name: LayerSource
        public let version: String
    }

    /// Source identity for a config layer.
    public struct LayerSource: Sendable, Equatable {
        public enum Kind: String, Sendable, Equatable {
            case legacyManagedConfigTomlFromFile
            case legacyManagedConfigTomlFromMdm
            case mdm
            case project
            case sessionFlags
            case system
            case user
        }

        public let dotCodexFolder: String?
        public let domain: String?
        public let file: String?
        public let key: String?
        public let kind: Kind
    }

    /// Requirements policy currently visible to the app-server.
    public struct RequirementsSnapshot: Sendable, Equatable {
        public let requirements: CodexAppServer.JSONValue?
    }

    /// Reads effective app-server configuration.
    public func read(_ request: ReadRequest = .init()) async throws -> Snapshot {
        try await appServer.readConfig(request)
    }

    /// Reads app-server configuration requirements, when configured.
    public func readRequirements() async throws -> RequirementsSnapshot {
        try await appServer.readConfigRequirements()
    }
}

public extension CodexAppServer {
    /// App-server-owned configuration read surface.
    var config: CodexConfig {
        CodexConfig(appServer: self)
    }
}

extension CodexConfig.Snapshot {
    init(wireValue: CodexWireConfigReadResponse) throws {
        self.init(
            config: try CodexConfig.jsonValue(from: wireValue.config),
            layers: try wireValue.layers?.map(CodexConfig.Layer.init(wireValue:)),
            origins: Dictionary(
                uniqueKeysWithValues: try wireValue.origins.map { key, value in
                    try (key, CodexConfig.LayerMetadata(wireValue: value))
                }
            )
        )
    }
}

extension CodexConfig.Layer {
    init(wireValue: CodexWireConfigLayer) throws {
        self.init(
            config: try CodexConfig.jsonValue(from: wireValue.config),
            disabledReason: wireValue.disabledReason,
            name: .init(wireValue: wireValue.name),
            version: wireValue.version
        )
    }
}

extension CodexConfig.LayerMetadata {
    init(wireValue: CodexWireConfigLayerMetadata) throws {
        self.init(
            name: .init(wireValue: wireValue.name),
            version: wireValue.version
        )
    }
}

extension CodexConfig.LayerSource {
    init(wireValue: CodexWireConfigLayerSource) {
        self.init(
            dotCodexFolder: wireValue.dotCodexFolder,
            domain: wireValue.domain,
            file: wireValue.file,
            key: wireValue.key,
            kind: .init(wireValue: wireValue.type)
        )
    }
}

extension CodexConfig.LayerSource.Kind {
    init(wireValue: CodexWireConfigLayerSourceType) {
        switch wireValue {
        case .legacyManagedConfigTomlFromFile:
            self = .legacyManagedConfigTomlFromFile
        case .legacyManagedConfigTomlFromMdm:
            self = .legacyManagedConfigTomlFromMdm
        case .mdm:
            self = .mdm
        case .project:
            self = .project
        case .sessionFlags:
            self = .sessionFlags
        case .system:
            self = .system
        case .user:
            self = .user
        }
    }
}

extension CodexConfig.RequirementsSnapshot {
    init(wireValue: CodexWireConfigRequirementsReadResponse) throws {
        self.init(requirements: try wireValue.requirements.map(CodexConfig.jsonValue(from:)))
    }
}

extension CodexConfig {
    static func jsonValue<T: Encodable>(from value: T) throws -> CodexAppServer.JSONValue {
        let data = try JSONEncoder().encode(value)
        let object = try JSONSerialization.jsonObject(with: data)
        return try CodexAppServer.JSONValue(jsonObject: object)
    }
}

extension CodexAppServer.JSONValue {
    init(jsonObject: Any) throws {
        switch jsonObject {
        case is NSNull:
            self = .null
        case let value as Bool:
            self = .bool(value)
        case let value as Int:
            self = .integer(value)
        case let value as NSNumber:
            let doubleValue = value.doubleValue
            let integerValue = value.int64Value
            if doubleValue.rounded(.towardZero) == doubleValue, let exactInteger = Int(exactly: integerValue) {
                self = .integer(exactInteger)
            } else {
                self = .double(doubleValue)
            }
        case let value as String:
            self = .string(value)
        case let value as [Any]:
            self = .array(try value.map(Self.init(jsonObject:)))
        case let value as [String: Any]:
            self = .object(try value.mapValues(Self.init(jsonObject:)))
        default:
            throw CodexAppServerError.protocolFailure(
                operation: "config/read",
                reason: "The app-server returned a config value that SwiftASB could not represent as JSON."
            )
        }
    }
}
