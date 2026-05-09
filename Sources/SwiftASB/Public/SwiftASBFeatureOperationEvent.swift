import Foundation

/// A human-readable record of a SwiftASB-owned feature operation.
///
/// SwiftASB emits these events for feature-category operations that can mutate
/// local state. Routine read-only refreshes stay quiet.
public struct SwiftASBFeatureOperationEvent: Sendable, Equatable, Identifiable {
    public let id: String
    public let categoryID: SwiftASBFeatureCategory.ID
    public let operationID: String
    public let title: String
    public let summary: String
    public let reason: String
    public let startedAt: Date
    public let completedAt: Date?
    public let affectedPaths: [String]
    public let commands: [Command]
    public let appServerMethod: String?
    public let intentKind: String?
    public let status: Status
    public let rollback: Rollback
    public let diagnosticText: String?

    init(
        categoryID: SwiftASBFeatureCategory.ID,
        operationID: String,
        title: String,
        summary: String,
        reason: String,
        startedAt: Date,
        completedAt: Date? = nil,
        affectedPaths: [String] = [],
        commands: [Command] = [],
        appServerMethod: String? = nil,
        intentKind: String? = nil,
        status: Status,
        rollback: Rollback = .unavailable,
        diagnosticText: String? = nil
    ) {
        self.id = operationID
        self.categoryID = categoryID
        self.operationID = operationID
        self.title = title
        self.summary = summary
        self.reason = reason
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.affectedPaths = affectedPaths
        self.commands = commands
        self.appServerMethod = appServerMethod
        self.intentKind = intentKind
        self.status = status
        self.rollback = rollback
        self.diagnosticText = diagnosticText
    }
}

extension SwiftASBFeatureOperationEvent {
    /// The current result state for a feature operation.
    public enum Status: String, Sendable, Equatable {
        case started, succeeded, failed, cancelled, skipped
    }

    /// One command SwiftASB ran as part of a feature operation.
    public struct Command: Sendable, Equatable {
        public let argv: [String]
        public let currentDirectoryPath: String?

        init(
            argv: [String],
            currentDirectoryPath: String? = nil
        ) {
            self.argv = argv
            self.currentDirectoryPath = currentDirectoryPath
        }
    }

    /// Rollback metadata for a feature operation.
    public struct Rollback: Sendable, Equatable {
        public let isAvailable: Bool
        public let handle: String?
        public let summary: String?

        init(
            isAvailable: Bool,
            handle: String? = nil,
            summary: String? = nil
        ) {
            self.isAvailable = isAvailable
            self.handle = handle
            self.summary = summary
        }

        static var unavailable: Self {
            .init(isAvailable: false)
        }
    }
}
