public extension CodexAppServer {
    /// Request used to set a stored thread name.
    struct ThreadSetNameRequest: Sendable, Equatable {
        public var name: String
        public var threadID: String

        /// Creates a thread-name update request.
        public init(threadID: String, name: String) {
            self.threadID = threadID
            self.name = name
        }
    }

    /// Request used to archive or unarchive a stored thread.
    struct ThreadArchiveRequest: Sendable, Equatable {
        public var threadID: String

        /// Creates a thread archive-state request.
        public init(threadID: String) {
            self.threadID = threadID
        }
    }

    /// Request used to roll back trailing turns from a stored thread.
    struct ThreadRollbackRequest: Sendable, Equatable {
        public var numberOfTurns: Int
        public var threadID: String

        /// Creates a thread-rollback request.
        public init(threadID: String, numberOfTurns: Int) {
            self.threadID = threadID
            self.numberOfTurns = numberOfTurns
        }
    }

    /// Request used to patch stored thread metadata.
    struct ThreadMetadataUpdateRequest: Sendable, Equatable {
        public var gitInfo: ThreadMetadataGitInfoUpdate?
        public var threadID: String

        /// Creates a thread-metadata update request.
        ///
        /// Omitting `gitInfo` sends no Git metadata patch.
        public init(
            threadID: String,
            gitInfo: ThreadMetadataGitInfoUpdate? = nil
        ) {
            self.threadID = threadID
            self.gitInfo = gitInfo
        }
    }

    /// Git metadata patch for a stored thread.
    struct ThreadMetadataGitInfoUpdate: Sendable, Equatable {
        public var branch: ThreadMetadataFieldUpdate
        public var originURL: ThreadMetadataFieldUpdate
        public var sha: ThreadMetadataFieldUpdate

        /// Creates a Git metadata patch.
        ///
        /// Each field defaults to `.unchanged`, so callers only need to set the
        /// metadata fields they want Codex to replace or clear.
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

    /// Patch operation for one stored thread metadata field.
    enum ThreadMetadataFieldUpdate: Sendable, Equatable {
        case unchanged
        case clear
        case replace(String)
    }

    /// Stored Git metadata reported for a thread.
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
