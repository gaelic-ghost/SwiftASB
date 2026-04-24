import Foundation
import Observation

public struct CodexTurnHandle: Sendable {
    public struct ClosedTurn: Sendable, Equatable, Identifiable {
        public struct Item: Sendable, Equatable, Identifiable {
            public let id: String
            public let orderIndex: Int
            public let kind: String
            public let command: String?
            public let path: String?
            public let serverName: String?
            public let status: String?
            public let streamedText: String?
            public let text: String?
            public let toolName: String?
        }

        public struct TokenUsage: Sendable, Equatable {
            public let cachedInputTokens: Int?
            public let inputTokens: Int?
            public let outputTokens: Int?
            public let reasoningOutputTokens: Int?
            public let totalTokens: Int?
            public let modelContextWindow: Int?
        }

        public let id: String
        public let threadID: String
        public let completedAt: Int?
        public let diff: String?
        public let durationMS: Int?
        public let errorMessage: String?
        public let items: [Item]
        public let orderIndex: Int
        public let startedAt: Int?
        public let status: String
        public let tokenUsage: TokenUsage?
    }

    @MainActor
    @Observable
    public final class Minimap {
        public struct CallSnapshot: Sendable, Equatable, Identifiable {
            public enum Kind: String, Sendable, Equatable {
                case collabTool
                case command
                case dynamicTool
                case fileEdit
                case mcp
            }

            public enum Status: String, Sendable, Equatable {
                case completed
                case errored
                case inProgress
            }

            public let id: String
            public private(set) var displayName: String
            public private(set) var filePath: String?
            public let kind: Kind
            public private(set) var latestStatusText: String?
            public private(set) var serverName: String?
            public private(set) var status: Status
            public private(set) var toolName: String?

            fileprivate mutating func apply(_ item: CodexTurnItem, status: Status) {
                displayName = Self.makeDisplayName(from: item)
                filePath = item.path
                latestStatusText = item.status ?? item.text
                serverName = item.serverName
                self.status = status
                toolName = item.toolName
            }

            fileprivate init(item: CodexTurnItem, kind: Kind, status: Status) {
                self.id = item.id
                self.displayName = Self.makeDisplayName(from: item)
                self.filePath = item.path
                self.kind = kind
                self.latestStatusText = item.status ?? item.text
                self.serverName = item.serverName
                self.status = status
                self.toolName = item.toolName
            }

            private static func makeDisplayName(from item: CodexTurnItem) -> String {
                switch item.kind {
                case .commandExecution:
                    item.command ?? "Command"
                case .mcpToolCall:
                    if let toolName = item.toolName, let serverName = item.serverName {
                        "\(serverName).\(toolName)"
                    } else if let toolName = item.toolName {
                        toolName
                    } else {
                        "MCP tool call"
                    }
                case .dynamicToolCall:
                    item.toolName ?? "Dynamic tool call"
                case .collabAgentToolCall:
                    item.toolName ?? "Collab tool call"
                case .fileChange:
                    item.path ?? "File edit"
                default:
                    item.text ?? item.status ?? item.kind.rawValue
                }
            }
        }

        public let threadID: String
        public let turnID: String
        public private(set) var callSnapshots: [CallSnapshot]
        public private(set) var currentTurn: CodexAppServer.TurnInfo
        public private(set) var isCompactingThreadContext: Bool
        public private(set) var latestApprovalRequest: CodexApprovalRequest?
        public private(set) var latestAgentMessageDelta: CodexTurnAgentMessageDelta?
        public private(set) var latestCompletedItem: CodexTurnItemCompleted?
        public private(set) var latestCompletion: CodexTurnCompletion?
        public private(set) var latestDiffUpdate: CodexTurnDiffUpdate?
        public private(set) var latestElicitationRequest: CodexElicitationRequest?
        public private(set) var latestPlanDelta: CodexTurnPlanDelta?
        public private(set) var latestPlanUpdate: CodexTurnPlanUpdate?
        public private(set) var latestReasoningSummaryPartAdded: CodexTurnReasoningSummaryPartAdded?
        public private(set) var latestReasoningSummaryTextDelta: CodexTurnReasoningSummaryTextDelta?
        public private(set) var latestReasoningTextDelta: CodexTurnReasoningTextDelta?
        public private(set) var latestRequestResolution: CodexInteractiveRequestResolved?
        public private(set) var latestStartedItem: CodexTurnItemStarted?
        public private(set) var latestStartedTurn: CodexTurnStarted?

        @ObservationIgnored
        private var eventTask: Task<Void, Never>?

        internal init(
            threadID: String,
            initialTurn: CodexAppServer.TurnInfo,
            events: AsyncThrowingStream<CodexTurnEvent, Error>
        ) {
            self.threadID = threadID
            self.turnID = initialTurn.id
            self.callSnapshots = []
            self.currentTurn = initialTurn
            self.isCompactingThreadContext = false
            self.latestApprovalRequest = nil
            self.latestAgentMessageDelta = nil
            self.latestCompletedItem = nil
            self.latestCompletion = nil
            self.latestDiffUpdate = nil
            self.latestElicitationRequest = nil
            self.latestPlanDelta = nil
            self.latestPlanUpdate = nil
            self.latestReasoningSummaryPartAdded = nil
            self.latestReasoningSummaryTextDelta = nil
            self.latestReasoningTextDelta = nil
            self.latestRequestResolution = nil
            self.latestStartedItem = nil
            self.latestStartedTurn = nil

            eventTask = Task { [weak self] in
                guard let self else { return }

                do {
                    for try await event in events {
                        self.apply(event)
                    }
                } catch is CancellationError {
                    return
                } catch {
                    return
                }
            }
        }

        deinit {
            eventTask?.cancel()
        }

        private func apply(_ event: CodexTurnEvent) {
            switch event {
            case let .started(started):
                latestStartedTurn = started
                currentTurn = started.turn
            case let .planUpdated(update):
                latestPlanUpdate = update
            case let .planDelta(delta):
                latestPlanDelta = delta
            case let .diffUpdated(update):
                latestDiffUpdate = update
            case let .approvalRequested(request):
                latestApprovalRequest = request
            case let .elicitationRequested(request):
                latestElicitationRequest = request
            case let .serverRequestResolved(resolution):
                latestRequestResolution = resolution
                if latestApprovalRequest?.requestID == resolution.requestID {
                    latestApprovalRequest = nil
                }
                if latestElicitationRequest?.requestID == resolution.requestID {
                    latestElicitationRequest = nil
                }
            case let .itemStarted(itemStarted):
                latestStartedItem = itemStarted
                if itemStarted.item.kind == .contextCompaction {
                    isCompactingThreadContext = true
                    return
                }
                upsertCallSnapshot(from: itemStarted.item, status: .inProgress)
            case let .itemCompleted(itemCompleted):
                latestCompletedItem = itemCompleted
                if itemCompleted.item.kind == .contextCompaction {
                    isCompactingThreadContext = false
                    return
                }
                upsertCallSnapshot(
                    from: itemCompleted.item,
                    status: Self.callSnapshotStatus(for: itemCompleted.item)
                )
            case let .agentMessageDelta(delta):
                latestAgentMessageDelta = delta
            case let .reasoningSummaryPartAdded(partAdded):
                latestReasoningSummaryPartAdded = partAdded
            case let .reasoningSummaryTextDelta(delta):
                latestReasoningSummaryTextDelta = delta
            case let .reasoningTextDelta(delta):
                latestReasoningTextDelta = delta
            case let .completed(completion):
                latestCompletion = completion
                currentTurn = completion.turn
                isCompactingThreadContext = false
            }
        }

        private func upsertCallSnapshot(from item: CodexTurnItem, status: CallSnapshot.Status) {
            guard let kind = Self.callSnapshotKind(for: item.kind) else { return }

            if let index = callSnapshots.firstIndex(where: { $0.id == item.id }) {
                callSnapshots[index].apply(item, status: status)
            } else {
                callSnapshots.append(
                    .init(
                        item: item,
                        kind: kind,
                        status: status
                    )
                )
            }
        }

        private static func callSnapshotKind(for kind: CodexTurnItem.Kind) -> CallSnapshot.Kind? {
            switch kind {
            case .collabAgentToolCall:
                .collabTool
            case .commandExecution:
                .command
            case .dynamicToolCall:
                .dynamicTool
            case .fileChange:
                .fileEdit
            case .mcpToolCall:
                .mcp
            default:
                nil
            }
        }

        private static func callSnapshotStatus(for item: CodexTurnItem) -> CallSnapshot.Status {
            if item.isErrored {
                return .errored
            }
            return .completed
        }
    }

    private final class MinimapStorage: @unchecked Sendable {
        let minimap: Minimap

        init(minimap: Minimap) {
            self.minimap = minimap
        }
    }

    private let appServer: CodexAppServer
    private let minimapStorage: MinimapStorage
    public let threadID: String
    public let turn: CodexAppServer.TurnInfo
    public let events: AsyncThrowingStream<CodexTurnEvent, Error>

    internal init(
        appServer: CodexAppServer,
        threadID: String,
        turn: CodexAppServer.TurnInfo,
        events: AsyncThrowingStream<CodexTurnEvent, Error>,
        minimap: Minimap
    ) {
        self.appServer = appServer
        self.minimapStorage = MinimapStorage(minimap: minimap)
        self.threadID = threadID
        self.turn = turn
        self.events = events
    }

    @MainActor
    public var minimap: Minimap {
        minimapStorage.minimap
    }

    @MainActor
    public func makeMinimap() async -> Minimap {
        minimap
    }

    public func respond(
        to request: CodexApprovalRequest,
        with response: CodexApprovalResponse
    ) async throws {
        try await appServer.respond(
            to: request,
            with: response,
            expectedThreadID: threadID,
            expectedTurnID: turn.id
        )
    }

    public func respond(
        to request: CodexElicitationRequest,
        with response: CodexElicitationResponse
    ) async throws {
        try await appServer.respond(
            to: request,
            with: response,
            expectedThreadID: threadID,
            expectedTurnID: turn.id
        )
    }

    public func interrupt() async throws {
        try await appServer.interruptTurn(
            threadID: threadID,
            turnID: turn.id
        )
    }

    public func steer(_ input: [CodexAppServer.TurnInput]) async throws {
        try await appServer.steerTurn(
            threadID: threadID,
            turnID: turn.id,
            input: input
        )
    }

    public func steerText(_ text: String) async throws {
        try await steer([.text(text)])
    }

    @discardableResult
    public func close() async throws -> ClosedTurn {
        try await appServer.closedTurn(threadID: threadID, turnID: turn.id)
    }
}

public enum CodexTurnEvent: Sendable, Equatable {
    case started(CodexTurnStarted)
    case planUpdated(CodexTurnPlanUpdate)
    case planDelta(CodexTurnPlanDelta)
    case diffUpdated(CodexTurnDiffUpdate)
    case approvalRequested(CodexApprovalRequest)
    case elicitationRequested(CodexElicitationRequest)
    case serverRequestResolved(CodexInteractiveRequestResolved)
    case itemStarted(CodexTurnItemStarted)
    case itemCompleted(CodexTurnItemCompleted)
    case agentMessageDelta(CodexTurnAgentMessageDelta)
    case reasoningSummaryPartAdded(CodexTurnReasoningSummaryPartAdded)
    case reasoningSummaryTextDelta(CodexTurnReasoningSummaryTextDelta)
    case reasoningTextDelta(CodexTurnReasoningTextDelta)
    case completed(CodexTurnCompletion)
}

public struct CodexTurnStarted: Sendable, Equatable {
    public let threadID: String
    public let turn: CodexAppServer.TurnInfo

    internal init(
        threadID: String,
        turn: CodexAppServer.TurnInfo
    ) {
        self.threadID = threadID
        self.turn = turn
    }
}

public struct CodexTurnPlanUpdate: Sendable, Equatable {
    public struct Step: Sendable, Equatable {
        public enum Status: String, Sendable, Equatable {
            case completed
            case inProgress
            case pending
        }

        public let status: Status
        public let step: String

        internal init(
            status: Status,
            step: String
        ) {
            self.status = status
            self.step = step
        }
    }

    public let threadID: String
    public let turnID: String
    public let explanation: String?
    public let plan: [Step]

    internal init(
        threadID: String,
        turnID: String,
        explanation: String?,
        plan: [Step]
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.explanation = explanation
        self.plan = plan
    }
}

public struct CodexTurnPlanDelta: Sendable, Equatable {
    public let threadID: String
    public let turnID: String
    public let itemID: String
    public let delta: String

    internal init(
        threadID: String,
        turnID: String,
        itemID: String,
        delta: String
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.itemID = itemID
        self.delta = delta
    }
}

public struct CodexTurnDiffUpdate: Sendable, Equatable {
    public let threadID: String
    public let turnID: String
    public let diff: String

    internal init(
        threadID: String,
        turnID: String,
        diff: String
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.diff = diff
    }
}

public struct CodexTurnItem: Sendable, Equatable {
    public enum Kind: String, Sendable, Equatable {
        case agentMessage
        case collabAgentToolCall
        case commandExecution
        case contextCompaction
        case dynamicToolCall
        case enteredReviewMode
        case exitedReviewMode
        case fileChange
        case hookPrompt
        case imageGeneration
        case imageView
        case mcpToolCall
        case plan
        case reasoning
        case userMessage
        case webSearch
    }

    public let id: String
    public let kind: Kind
    public let command: String?
    public let path: String?
    public let serverName: String?
    public let text: String?
    public let status: String?
    public let toolName: String?

    internal init(
        id: String,
        kind: Kind,
        command: String?,
        path: String?,
        serverName: String?,
        text: String?,
        status: String?,
        toolName: String?
    ) {
        self.id = id
        self.kind = kind
        self.command = command
        self.path = path
        self.serverName = serverName
        self.text = text
        self.status = status
        self.toolName = toolName
    }

    var isErrored: Bool {
        guard let status else { return false }
        return switch status.lowercased() {
        case "error", "errored", "failed", "interrupted":
            true
        default:
            false
        }
    }
}

public struct CodexTurnItemStarted: Sendable, Equatable {
    public let threadID: String
    public let turnID: String
    public let item: CodexTurnItem

    internal init(
        threadID: String,
        turnID: String,
        item: CodexTurnItem
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.item = item
    }
}

public struct CodexTurnItemCompleted: Sendable, Equatable {
    public let threadID: String
    public let turnID: String
    public let item: CodexTurnItem

    internal init(
        threadID: String,
        turnID: String,
        item: CodexTurnItem
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.item = item
    }
}

public struct CodexTurnAgentMessageDelta: Sendable, Equatable {
    public let threadID: String
    public let turnID: String
    public let itemID: String
    public let delta: String

    internal init(
        threadID: String,
        turnID: String,
        itemID: String,
        delta: String
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.itemID = itemID
        self.delta = delta
    }
}

public struct CodexTurnReasoningSummaryPartAdded: Sendable, Equatable {
    public let threadID: String
    public let turnID: String
    public let itemID: String
    public let summaryIndex: Int

    internal init(
        threadID: String,
        turnID: String,
        itemID: String,
        summaryIndex: Int
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.itemID = itemID
        self.summaryIndex = summaryIndex
    }
}

public struct CodexTurnReasoningSummaryTextDelta: Sendable, Equatable {
    public let threadID: String
    public let turnID: String
    public let itemID: String
    public let summaryIndex: Int
    public let delta: String

    internal init(
        threadID: String,
        turnID: String,
        itemID: String,
        summaryIndex: Int,
        delta: String
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.itemID = itemID
        self.summaryIndex = summaryIndex
        self.delta = delta
    }
}

public struct CodexTurnReasoningTextDelta: Sendable, Equatable {
    public let threadID: String
    public let turnID: String
    public let itemID: String
    public let contentIndex: Int
    public let delta: String

    internal init(
        threadID: String,
        turnID: String,
        itemID: String,
        contentIndex: Int,
        delta: String
    ) {
        self.threadID = threadID
        self.turnID = turnID
        self.itemID = itemID
        self.contentIndex = contentIndex
        self.delta = delta
    }
}

public struct CodexTurnCompletion: Sendable, Equatable {
    public let threadID: String
    public let turn: CodexAppServer.TurnInfo

    internal init(
        threadID: String,
        turn: CodexAppServer.TurnInfo
    ) {
        self.threadID = threadID
        self.turn = turn
    }
}

internal extension CodexTurnHandle.ClosedTurn {
    init(threadID: String, snapshot: ThreadHistoryStore.ThreadSnapshot.TurnSnapshot) {
        self.init(
            id: snapshot.id,
            threadID: threadID,
            completedAt: snapshot.completedAt,
            diff: snapshot.diff,
            durationMS: snapshot.durationMS,
            errorMessage: snapshot.errorMessage,
            items: snapshot.items.map {
                .init(
                    id: $0.id,
                    orderIndex: $0.orderIndex,
                    kind: $0.kind,
                    command: $0.command,
                    path: $0.path,
                    serverName: $0.serverName,
                    status: $0.status,
                    streamedText: $0.streamedText,
                    text: $0.text,
                    toolName: $0.toolName
                )
            },
            orderIndex: snapshot.orderIndex,
            startedAt: snapshot.startedAt,
            status: snapshot.status,
            tokenUsage: snapshot.tokenUsage.map {
                .init(
                    cachedInputTokens: $0.cachedInputTokens,
                    inputTokens: $0.inputTokens,
                    outputTokens: $0.outputTokens,
                    reasoningOutputTokens: $0.reasoningOutputTokens,
                    totalTokens: $0.totalTokens,
                    modelContextWindow: $0.modelContextWindow
                )
            }
        )
    }
}
