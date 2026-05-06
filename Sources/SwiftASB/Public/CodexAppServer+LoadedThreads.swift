public extension CodexAppServer {
    /// Request used to list thread ids currently loaded in the app-server runtime.
    struct LoadedThreadListRequest: Sendable, Equatable {
        public var cursor: String?
        public var limit: Int?

        /// Creates a loaded-thread list request.
        ///
        /// Nil values are omitted so the app-server can choose its default page.
        public init(cursor: String? = nil, limit: Int? = nil) {
            self.cursor = cursor
            self.limit = limit
        }
    }

    /// One page of thread ids currently loaded in the app-server runtime.
    struct LoadedThreadListPage: Sendable, Equatable {
        public let nextCursor: String?
        public let threadIDs: [String]
    }
}
