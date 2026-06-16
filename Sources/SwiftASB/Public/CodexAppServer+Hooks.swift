public extension CodexAppServer {
    /// Request used to read configured hook diagnostics for one or more working directories.
    struct HookListRequest: Sendable, Equatable {
        public var currentDirectoryPaths: [String]?

        /// Creates a hook-list request.
        ///
        /// Nil `currentDirectoryPaths` omits `cwds`, which lets the app-server
        /// use its current session working directory. Passing an empty array
        /// sends an empty `cwds` list, which the app-server treats the same way.
        public init(currentDirectoryPaths: [String]? = nil) {
            self.currentDirectoryPaths = currentDirectoryPaths
        }
    }

    /// Current configured hook diagnostics grouped by working directory.
    struct HookListSnapshot: Sendable, Equatable {
        public let entries: [HookListEntry]

        /// Returns the diagnostics entry for a working directory path.
        public func entry(forCurrentDirectoryPath path: String) -> HookListEntry? {
            entries.first { $0.currentDirectoryPath == path }
        }

        /// True when any working directory reported a hook warning or error.
        public var hasDiagnostics: Bool {
            entries.contains { $0.hasDiagnostics }
        }
    }

    /// Configured hook diagnostics for one working directory.
    struct HookListEntry: Sendable, Equatable, Identifiable {
        public let currentDirectoryPath: String
        public let errors: [HookError]
        public let hooks: [HookMetadata]
        public let warnings: [String]

        public var id: String { currentDirectoryPath }

        /// Hook warnings and errors combined into one list for diagnostics UI.
        public var diagnostics: [HookDiagnostic] {
            let errorDiagnostics = errors.enumerated().map { offset, error in
                HookDiagnostic(
                    id: "error:\(offset):\(error.path):\(error.message)",
                    severity: .error,
                    message: error.message,
                    path: error.path
                )
            }
            let warningDiagnostics = warnings.enumerated().map { offset, warning in
                HookDiagnostic(
                    id: "warning:\(offset):\(warning)",
                    severity: .warning,
                    message: warning,
                    path: nil
                )
            }
            return errorDiagnostics + warningDiagnostics
        }

        /// True when this working directory reported at least one hook warning or error.
        public var hasDiagnostics: Bool {
            errors.isEmpty == false || warnings.isEmpty == false
        }

        /// Configured hooks that are enabled for this working directory.
        public var enabledHooks: [HookMetadata] {
            hooks.filter(\.enabled)
        }

        /// Configured hooks that are present but disabled for this working directory.
        public var disabledHooks: [HookMetadata] {
            hooks.filter { !$0.enabled }
        }
    }

    /// Hook load or configuration error reported by the app-server.
    struct HookError: Sendable, Equatable {
        public let message: String
        public let path: String
    }

    /// Display-ready hook diagnostic derived from warnings and load errors.
    struct HookDiagnostic: Sendable, Equatable, Identifiable {
        /// Severity of a hook diagnostic.
        public enum Severity: String, Sendable, Equatable {
            case error
            case warning
        }

        public let id: String
        public let severity: Severity
        public let message: String
        public let path: String?
    }

    /// Metadata for one configured hook.
    struct HookMetadata: Sendable, Equatable, Identifiable {
        /// Hook event that triggers this configured hook.
        public enum EventName: String, Sendable, Equatable {
            case permissionRequest
            case postCompact
            case postToolUse
            case preCompact
            case preToolUse
            case sessionStart
            case stop
            case subagentStart
            case subagentStop
            case userPromptSubmit
        }

        /// Handler shape used by this configured hook.
        public enum HandlerType: String, Sendable, Equatable {
            case agent
            case command
            case prompt
        }

        /// Configuration source that provided this hook.
        public enum Source: String, Sendable, Equatable {
            case cloudRequirements
            case legacyManagedConfigFile
            case legacyManagedConfigMdm
            case mdm
            case plugin
            case project
            case sessionFlags
            case system
            case unknown
            case user
        }

        public let command: String?
        public let displayOrder: Int
        public let enabled: Bool
        public let eventName: EventName
        public let handlerType: HandlerType
        public let isManaged: Bool
        public let key: String
        public let matcher: String?
        public let pluginID: String?
        public let source: Source
        public let sourcePath: String
        public let statusMessage: String?
        public let timeoutSeconds: UInt64

        public var id: String { key }
    }
}

extension CodexAppServer.HookListEntry {
    init(protocolValue: CodexProtocolHooksListResponse.Entry) {
        self.init(
            currentDirectoryPath: protocolValue.cwd,
            errors: protocolValue.errors.map(CodexAppServer.HookError.init),
            hooks: protocolValue.hooks.map(CodexAppServer.HookMetadata.init),
            warnings: protocolValue.warnings
        )
    }
}

extension CodexAppServer.HookError {
    init(protocolValue: CodexProtocolHooksListResponse.ErrorInfo) {
        self.init(
            message: protocolValue.message,
            path: protocolValue.path
        )
    }
}

extension CodexAppServer.HookMetadata {
    init(protocolValue: CodexProtocolHooksListResponse.HookMetadata) {
        self.init(
            command: protocolValue.command,
            displayOrder: protocolValue.displayOrder,
            enabled: protocolValue.enabled,
            eventName: .init(protocolValue: protocolValue.eventName),
            handlerType: .init(protocolValue: protocolValue.handlerType),
            isManaged: protocolValue.isManaged,
            key: protocolValue.key,
            matcher: protocolValue.matcher,
            pluginID: protocolValue.pluginID,
            source: .init(protocolValue: protocolValue.source),
            sourcePath: protocolValue.sourcePath,
            statusMessage: protocolValue.statusMessage,
            timeoutSeconds: protocolValue.timeoutSeconds
        )
    }
}

extension CodexAppServer.HookMetadata.EventName {
    init(protocolValue: CodexProtocolHooksListResponse.EventName) {
        switch protocolValue {
            case .permissionRequest:
                self = .permissionRequest
            case .postCompact:
                self = .postCompact
            case .postToolUse:
                self = .postToolUse
            case .preCompact:
                self = .preCompact
            case .preToolUse:
                self = .preToolUse
            case .sessionStart:
                self = .sessionStart
            case .stop:
                self = .stop
            case .userPromptSubmit:
                self = .userPromptSubmit
        }
    }
}

extension CodexAppServer.HookMetadata.HandlerType {
    init(protocolValue: CodexProtocolHooksListResponse.HandlerType) {
        switch protocolValue {
            case .agent:
                self = .agent
            case .command:
                self = .command
            case .prompt:
                self = .prompt
        }
    }
}

extension CodexAppServer.HookMetadata.Source {
    init(protocolValue: CodexProtocolHooksListResponse.Source) {
        switch protocolValue {
            case .cloudRequirements:
                self = .cloudRequirements
            case .legacyManagedConfigFile:
                self = .legacyManagedConfigFile
            case .legacyManagedConfigMdm:
                self = .legacyManagedConfigMdm
            case .mdm:
                self = .mdm
            case .plugin:
                self = .plugin
            case .project:
                self = .project
            case .sessionFlags:
                self = .sessionFlags
            case .system:
                self = .system
            case .unknown:
                self = .unknown
            case .user:
                self = .user
        }
    }
}
