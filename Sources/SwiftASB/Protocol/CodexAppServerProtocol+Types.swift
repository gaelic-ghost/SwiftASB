//
//  CodexAppServerProtocol+Types.swift
//  SwiftASB
//
//  Created by Gale Williams on 4/19/26.
//

import Foundation

enum CodexAppServerProtocolEvent: Equatable, Sendable {
	case threadStarted(CodexWireThreadStartedNotification)
	case threadStatusChanged(CodexWireThreadStatusChangedNotification)
	case threadArchived(CodexWireThreadArchivedNotification)
	case threadUnarchived(CodexWireThreadUnarchivedNotification)
	case threadClosed(CodexWireThreadClosedNotification)
	case threadNameUpdated(CodexWireThreadNameUpdatedNotification)
	case threadTokenUsageUpdated(CodexWireThreadTokenUsageUpdatedNotification)
	case hookStarted(CodexWireHookStartedNotification)
	case hookCompleted(CodexWireHookCompletedNotification)
	case modelRerouted(CodexWireModelReroutedNotification)
	case turnStarted(CodexWireTurnStartedNotification)
	case turnDiffUpdated(CodexWireTurnDiffUpdatedNotification)
	case turnPlanUpdated(CodexWireTurnPlanUpdatedNotification)
	case turnCompleted(CodexWireTurnCompletedNotification)
	case itemStarted(CodexWireItemStartedNotification)
	case itemCompleted(CodexWireItemCompletedNotification)
	case agentMessageDelta(CodexWireAgentMessageDeltaNotification)
	case planDelta(CodexWirePlanDeltaNotification)
	case reasoningSummaryPartAdded(CodexWireReasoningSummaryPartAddedNotification)
	case reasoningSummaryTextDelta(CodexWireReasoningSummaryTextDeltaNotification)
	case reasoningTextDelta(CodexWireReasoningTextDeltaNotification)
	case commandExecutionApprovalRequested(CodexProtocolCommandExecutionApprovalRequest)
	case fileChangeApprovalRequested(CodexProtocolFileChangeApprovalRequest)
	case permissionsApprovalRequested(CodexProtocolPermissionsApprovalRequest)
	case toolUserInputRequested(CodexProtocolToolUserInputRequest)
	case mcpServerElicitationRequested(CodexProtocolMCPServerElicitationRequest)
	case serverRequestResolved(CodexWireServerRequestResolvedNotification)
}

struct CodexProtocolThreadCompactStartResponse: Decodable, Equatable, Sendable {}

struct CodexProtocolTurnInterruptParams: Encodable, Equatable, Sendable {
	let threadID: String
	let turnID: String

	enum CodingKeys: String, CodingKey {
		case threadID = "threadId"
		case turnID = "turnId"
	}
}

struct CodexProtocolThreadReadParams: Encodable, Equatable, Sendable {
    let includeTurns: Bool?
    let threadID: String

    enum CodingKeys: String, CodingKey {
        case includeTurns
        case threadID = "threadId"
    }
}

struct CodexProtocolThreadReadResponse: Decodable, Equatable, Sendable {
    let thread: CodexWireThread
}

struct CodexProtocolThreadResumeParams: Encodable, Equatable, Sendable {
    let approvalPolicy: CodexWireApprovalPolicyUnion?
    let approvalsReviewer: CodexWireApprovalsReviewer?
    let baseInstructions: String?
    let config: [String: CodexWireJSONValue]?
    let cwd: String?
    let developerInstructions: String?
    let model: String?
    let modelProvider: String?
    let personality: CodexWirePersonality?
    let sandbox: CodexWireSandboxMode?
    let serviceName: String?
    let serviceTier: CodexWireServiceTier?
    let threadID: String

    enum CodingKeys: String, CodingKey {
        case approvalPolicy
        case approvalsReviewer
        case baseInstructions
        case config
        case cwd
        case developerInstructions
        case model
        case modelProvider
        case personality
        case sandbox
        case serviceName
        case serviceTier
        case threadID = "threadId"
    }
}

struct CodexProtocolThreadForkParams: Encodable, Equatable, Sendable {
    let approvalPolicy: CodexWireApprovalPolicyUnion?
    let approvalsReviewer: CodexWireApprovalsReviewer?
    let baseInstructions: String?
    let config: [String: CodexWireJSONValue]?
    let cwd: String?
    let developerInstructions: String?
    let ephemeral: Bool?
    let model: String?
    let modelProvider: String?
    let personality: CodexWirePersonality?
    let sandbox: CodexWireSandboxMode?
    let serviceName: String?
    let serviceTier: CodexWireServiceTier?
    let threadID: String

    enum CodingKeys: String, CodingKey {
        case approvalPolicy
        case approvalsReviewer
        case baseInstructions
        case config
        case cwd
        case developerInstructions
        case ephemeral
        case model
        case modelProvider
        case personality
        case sandbox
        case serviceName
        case serviceTier
        case threadID = "threadId"
    }
}

struct CodexProtocolThreadListParams: Encodable, Equatable, Sendable {
    let archived: Bool?
    let cursor: String?
    let cwd: String?
    let limit: Int?
    let modelProviders: [String]?
    let searchTerm: String?
    let sortDirection: CodexProtocolThreadListSortDirection?
    let sortKey: CodexProtocolThreadListSortKey?
    let sourceKinds: [CodexProtocolThreadListSourceKind]?

    enum CodingKeys: String, CodingKey {
        case archived
        case cursor
        case cwd
        case limit
        case modelProviders
        case searchTerm
        case sortDirection
        case sortKey
        case sourceKinds
    }
}

enum CodexProtocolThreadListSortDirection: String, Codable, Equatable, Sendable {
    case asc
    case desc
}

enum CodexProtocolThreadListSortKey: String, Codable, Equatable, Sendable {
    case createdAt = "created_at"
    case updatedAt = "updated_at"
}

enum CodexProtocolThreadListSourceKind: String, Codable, Equatable, Sendable {
    case appServer = "appServer"
    case cli
    case exec
    case unknown
    case vscode
}

struct CodexProtocolThreadListResponse: Decodable, Equatable, Sendable {
    let data: [CodexWireThread]
    let nextCursor: String?
}

struct CodexProtocolThreadTurnsListParams: Encodable, Equatable, Sendable {
    let cursor: String?
    let limit: Int?
    let sortDirection: CodexProtocolThreadTurnsSortDirection?
    let threadID: String

    enum CodingKeys: String, CodingKey {
        case cursor
        case limit
        case sortDirection
        case threadID = "threadId"
    }
}

enum CodexProtocolThreadTurnsSortDirection: String, Codable, Equatable, Sendable {
    case asc
    case desc
}

struct CodexProtocolThreadTurnsListResponse: Decodable, Equatable, Sendable {
    let backwardsCursor: String?
    let data: [CodexWireTurn]
    let nextCursor: String?
}

struct CodexProtocolTurnSteerParams: Encodable, Equatable, Sendable {
	let expectedTurnID: String
	let input: [CodexWireUserInput]
	let threadID: String

	enum CodingKeys: String, CodingKey {
		case expectedTurnID = "expectedTurnId"
		case input
		case threadID = "threadId"
	}
}

struct CodexProtocolTurnSteerResponse: Decodable, Equatable, Sendable {
	let turnID: String

	enum CodingKeys: String, CodingKey {
		case turnID = "turnId"
	}
}

struct CodexProtocolTurnInterruptResponse: Decodable, Equatable, Sendable {}

struct CodexProtocolCommandExecutionApprovalRequest: Decodable, Equatable, Sendable {
	let approvalID: String?
	let command: String?
	let commandActions: [CodexProtocolCommandAction]?
	let cwd: String?
	let itemID: String
	let networkApprovalContext: CodexWireJSONValue?
	let proposedExecpolicyAmendment: [String]?
	let proposedNetworkPolicyAmendments: [CodexProtocolNetworkPolicyAmendment]?
	let reason: String?
	var requestID: CodexRPCRequestID = .string("unbound")
	let threadID: String
	let turnID: String

	enum CodingKeys: String, CodingKey {
		case approvalID = "approvalId"
		case command
		case commandActions
		case cwd
		case itemID = "itemId"
		case networkApprovalContext
		case proposedExecpolicyAmendment
		case proposedNetworkPolicyAmendments
		case reason
		case threadID = "threadId"
		case turnID = "turnId"
	}
}

struct CodexProtocolFileChangeApprovalRequest: Decodable, Equatable, Sendable {
	let grantRoot: String?
	let itemID: String
	let reason: String?
	var requestID: CodexRPCRequestID = .string("unbound")
	let threadID: String
	let turnID: String

	enum CodingKeys: String, CodingKey {
		case grantRoot
		case itemID = "itemId"
		case reason
		case threadID = "threadId"
		case turnID = "turnId"
	}
}

struct CodexProtocolPermissionsApprovalRequest: Decodable, Equatable, Sendable {
	let itemID: String
	let permissions: CodexProtocolPermissionProfile
	let reason: String?
	var requestID: CodexRPCRequestID = .string("unbound")
	let threadID: String
	let turnID: String

	enum CodingKeys: String, CodingKey {
		case itemID = "itemId"
		case permissions
		case reason
		case threadID = "threadId"
		case turnID = "turnId"
	}
}

struct CodexProtocolToolUserInputRequest: Decodable, Equatable, Sendable {
	let itemID: String
	let questions: [Question]
	var requestID: CodexRPCRequestID = .string("unbound")
	let threadID: String
	let turnID: String

	enum CodingKeys: String, CodingKey {
		case itemID = "itemId"
		case questions
		case threadID = "threadId"
		case turnID = "turnId"
	}

	struct Question: Decodable, Equatable, Sendable {
		let header: String
		let id: String
		let isOther: Bool
		let isSecret: Bool
		let options: [Option]?
		let question: String

		enum CodingKeys: String, CodingKey {
			case header
			case id
			case isOther
			case isSecret
			case options
			case question
		}

		struct Option: Decodable, Equatable, Sendable {
			let description: String
			let label: String
		}

		init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			header = try container.decode(String.self, forKey: .header)
			id = try container.decode(String.self, forKey: .id)
			isOther = try container.decodeIfPresent(Bool.self, forKey: .isOther) ?? false
			isSecret = try container.decodeIfPresent(Bool.self, forKey: .isSecret) ?? false
			options = try container.decodeIfPresent([Option].self, forKey: .options)
			question = try container.decode(String.self, forKey: .question)
		}
	}
}

struct CodexProtocolMCPServerElicitationRequest: Decodable, Equatable, Sendable {
	let mode: Mode
	let requestID: CodexRPCRequestID
	let serverName: String
	let threadID: String
	let turnID: String?

	enum CodingKeys: String, CodingKey {
		case serverName
		case threadID = "threadId"
		case turnID = "turnId"
		case mode
	}

	enum Mode: Equatable, Sendable {
		case form(Form)
		case url(URLPrompt)
	}

	struct Form: Decodable, Equatable, Sendable {
		let message: String
		let requestedSchema: CodexWireJSONValue

		enum CodingKeys: String, CodingKey {
			case message
			case requestedSchema
		}
	}

	struct URLPrompt: Decodable, Equatable, Sendable {
		let elicitationID: String
		let message: String
		let url: String

		enum CodingKeys: String, CodingKey {
			case elicitationID = "elicitationId"
			case message
			case url
		}
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		serverName = try container.decode(String.self, forKey: .serverName)
		threadID = try container.decode(String.self, forKey: .threadID)
		turnID = try container.decodeIfPresent(String.self, forKey: .turnID)
		requestID = .string("unbound")

		let modeValue = try container.decode(String.self, forKey: .mode)
		switch modeValue {
			case "form":
				mode = .form(try Form(from: decoder))
			case "url":
				mode = .url(try URLPrompt(from: decoder))
			default:
				throw DecodingError.dataCorruptedError(
					forKey: .mode,
					in: container,
					debugDescription: "Unsupported MCP elicitation mode \(modeValue)."
				)
		}
	}
}

enum CodexProtocolCommandAction: Decodable, Equatable, Sendable {
	case read(Read)
	case listFiles(ListFiles)
	case search(Search)
	case unknown(Unknown)

	struct Read: Decodable, Equatable, Sendable {
		let command: String
		let name: String
		let path: String

		enum CodingKeys: String, CodingKey {
			case command
			case name
			case path
		}
	}

	struct ListFiles: Decodable, Equatable, Sendable {
		let command: String
		let path: String?

		enum CodingKeys: String, CodingKey {
			case command
			case path
		}
	}

	struct Search: Decodable, Equatable, Sendable {
		let command: String
		let path: String?
		let query: String?

		enum CodingKeys: String, CodingKey {
			case command
			case path
			case query
		}
	}

	struct Unknown: Decodable, Equatable, Sendable {
		let command: String

		enum CodingKeys: String, CodingKey {
			case command
		}
	}

	private enum CodingKeys: String, CodingKey {
		case command
		case name
		case path
		case query
		case type
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let type = try container.decode(String.self, forKey: .type)

		switch type {
			case "read":
				self = .read(
					.init(
						command: try container.decode(String.self, forKey: .command),
						name: try container.decode(String.self, forKey: .name),
						path: try container.decode(String.self, forKey: .path)
					)
				)
			case "listFiles":
				self = .listFiles(
					.init(
						command: try container.decode(String.self, forKey: .command),
						path: try container.decodeIfPresent(String.self, forKey: .path)
					)
				)
			case "search":
				self = .search(
					.init(
						command: try container.decode(String.self, forKey: .command),
						path: try container.decodeIfPresent(String.self, forKey: .path),
						query: try container.decodeIfPresent(String.self, forKey: .query)
					)
				)
			case "unknown":
				self = .unknown(
					.init(command: try container.decode(String.self, forKey: .command))
				)
			default:
				throw DecodingError.dataCorruptedError(
					forKey: .type,
					in: container,
					debugDescription: "Unsupported command action type \(type)."
				)
		}
	}
}

struct CodexProtocolNetworkPolicyAmendment: Decodable, Equatable, Sendable {
	let action: String
	let host: String
}

struct CodexProtocolPermissionProfile: Decodable, Equatable, Sendable {
	let fileSystem: FileSystem?
	let network: Network?

	struct FileSystem: Decodable, Equatable, Sendable {
		let read: [String]?
		let write: [String]?
	}

	struct Network: Decodable, Equatable, Sendable {
		let enabled: Bool?
	}
}
