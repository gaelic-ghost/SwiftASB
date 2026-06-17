public extension CodexAppServer {
    /// Request used to read the app-server's current model catalog.
    struct ModelListRequest: Sendable, Equatable {
        public var cursor: String?
        public var includeHidden: Bool?
        public var limit: Int?

        /// Creates a model-list request.
        ///
        /// Nil pagination and visibility fields are omitted, which lets the
        /// app-server choose its default catalog page and hidden-model policy.
        public init(
            cursor: String? = nil,
            limit: Int? = nil,
            includeHidden: Bool? = nil
        ) {
            self.cursor = cursor
            self.includeHidden = includeHidden
            self.limit = limit
        }
    }

    /// One page of app-server model catalog results.
    struct ModelListPage: Sendable, Equatable {
        public let models: [Model]
        public let nextCursor: String?
    }

    /// Feature gates reported by the current app-server model provider.
    struct ModelCapabilities: Sendable, Equatable {
        public let imageGeneration: Bool
        public let namespaceTools: Bool
        public let webSearch: Bool
    }

    /// Model option reported by the app-server for picker and capability UI.
    struct Model: Sendable, Equatable, Identifiable {
        public let additionalSpeedTiers: [String]?
        public let availabilityNux: ModelAvailabilityNux?
        public let defaultReasoningEffort: ReasoningEffort
        public let description: String
        public let displayName: String
        public let hidden: Bool
        public let id: String
        public let inputModalities: [InputModality]?
        public let isDefault: Bool
        public let model: String
        public let supportedReasoningEfforts: [ReasoningEffortOption]
        public let supportsPersonality: Bool?
    }

    /// App-server model-availability note shown to users when present.
    struct ModelAvailabilityNux: Sendable, Equatable {
        public let message: String
    }

    /// Input modality supported by a model.
    enum InputModality: String, Sendable, Equatable {
        case image
        case text
    }

    /// Reasoning-effort option advertised for a model.
    struct ReasoningEffortOption: Sendable, Equatable {
        public let description: String
        public let reasoningEffort: ReasoningEffort
    }
}

extension CodexAppServer.Model {
    init(wireValue: CodexWireModel) {
        self.init(
            additionalSpeedTiers: wireValue.additionalSpeedTiers,
            availabilityNux: wireValue.availabilityNux.map(CodexAppServer.ModelAvailabilityNux.init),
            defaultReasoningEffort: .init(wireValue: wireValue.defaultReasoningEffort),
            description: wireValue.description,
            displayName: wireValue.displayName,
            hidden: wireValue.hidden,
            id: wireValue.id,
            inputModalities: wireValue.inputModalities?.map(CodexAppServer.InputModality.init),
            isDefault: wireValue.isDefault,
            model: wireValue.model,
            supportedReasoningEfforts: wireValue.supportedReasoningEfforts.map(
                CodexAppServer.ReasoningEffortOption.init
            ),
            supportsPersonality: wireValue.supportsPersonality
        )
    }
}

extension CodexAppServer.ModelCapabilities {
    init(wireValue: CodexProtocolModelProviderCapabilitiesReadResponse) {
        self.init(
            imageGeneration: wireValue.imageGeneration,
            namespaceTools: wireValue.namespaceTools,
            webSearch: wireValue.webSearch
        )
    }
}

extension CodexAppServer.ModelAvailabilityNux {
    init(wireValue: CodexWireModelAvailabilityNux) {
        self.init(message: wireValue.message)
    }
}

extension CodexAppServer.InputModality {
    init(wireValue: CodexWireInputModality) {
        switch wireValue {
            case .image:
                self = .image
            case .text:
                self = .text
        }
    }
}

extension CodexAppServer.ReasoningEffortOption {
    init(wireValue: CodexWireReasoningEffortOption) {
        self.init(
            description: wireValue.description,
            reasoningEffort: .init(wireValue: wireValue.reasoningEffort)
        )
    }
}
