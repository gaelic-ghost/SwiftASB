public extension CodexAppServer {
    struct ModelListRequest: Sendable, Equatable {
        public var cursor: String?
        public var includeHidden: Bool?
        public var limit: Int?

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
        public let upgrade: String?
        public let upgradeInfo: ModelUpgradeInfo?
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

    struct ModelUpgradeInfo: Sendable, Equatable {
        public let migrationMarkdown: String?
        public let model: String
        public let modelLink: String?
        public let upgradeCopy: String?
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
            supportsPersonality: wireValue.supportsPersonality,
            upgrade: wireValue.upgrade,
            upgradeInfo: wireValue.upgradeInfo.map(CodexAppServer.ModelUpgradeInfo.init)
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

extension CodexAppServer.ModelUpgradeInfo {
    init(wireValue: CodexWireModelUpgradeInfo) {
        self.init(
            migrationMarkdown: wireValue.migrationMarkdown,
            model: wireValue.model,
            modelLink: wireValue.modelLink,
            upgradeCopy: wireValue.upgradeCopy
        )
    }
}
