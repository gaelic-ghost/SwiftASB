public extension CodexAppServer {
    struct ThreadSetNameRequest: Sendable, Equatable {
        public var name: String
        public var threadID: String

        public init(threadID: String, name: String) {
            self.threadID = threadID
            self.name = name
        }
    }

    struct ThreadMetadataUpdateRequest: Sendable, Equatable {
        public var gitInfo: ThreadMetadataGitInfoUpdate?
        public var threadID: String

        public init(
            threadID: String,
            gitInfo: ThreadMetadataGitInfoUpdate? = nil
        ) {
            self.threadID = threadID
            self.gitInfo = gitInfo
        }
    }

    struct ThreadMetadataGitInfoUpdate: Sendable, Equatable {
        public var branch: ThreadMetadataFieldUpdate
        public var originURL: ThreadMetadataFieldUpdate
        public var sha: ThreadMetadataFieldUpdate

        public init(
            branch: ThreadMetadataFieldUpdate = .unchanged,
            originURL: ThreadMetadataFieldUpdate = .unchanged,
            sha: ThreadMetadataFieldUpdate = .unchanged
        ) {
            self.branch = branch
            self.originURL = originURL
            self.sha = sha
        }
    }

    enum ThreadMetadataFieldUpdate: Sendable, Equatable {
        case unchanged
        case clear
        case replace(String)
    }

    struct GitInfo: Sendable, Equatable {
        public let branch: String?
        public let originURL: String?
        public let sha: String?
    }
}

extension CodexAppServer.ThreadMetadataUpdateRequest {
    var protocolValue: CodexProtocolThreadMetadataUpdateParams {
        .init(
            gitInfo: gitInfo.map(CodexProtocolThreadMetadataUpdateParams.GitInfo.init),
            threadID: threadID
        )
    }
}

extension CodexProtocolThreadMetadataUpdateParams.GitInfo {
    init(_ update: CodexAppServer.ThreadMetadataGitInfoUpdate) {
        self.init(
            branch: .init(update.branch),
            originURL: .init(update.originURL),
            sha: .init(update.sha)
        )
    }
}

extension CodexProtocolThreadMetadataUpdateParams.FieldUpdate {
    init(_ update: CodexAppServer.ThreadMetadataFieldUpdate) {
        switch update {
        case .unchanged:
            self = .unchanged
        case .clear:
            self = .clear
        case let .replace(value):
            self = .replace(value)
        }
    }
}

extension CodexAppServer.GitInfo {
    init(wireValue: CodexWireGitInfo) {
        self.init(
            branch: wireValue.branch,
            originURL: wireValue.originURL,
            sha: wireValue.sha
        )
    }
}
