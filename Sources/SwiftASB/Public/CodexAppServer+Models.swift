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

    struct ModelListPage: Sendable, Equatable {
        public let models: [Model]
        public let nextCursor: String?
    }

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

    struct ModelAvailabilityNux: Sendable, Equatable {
        public let message: String
    }

    enum InputModality: String, Sendable, Equatable {
        case image
        case text
    }

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
