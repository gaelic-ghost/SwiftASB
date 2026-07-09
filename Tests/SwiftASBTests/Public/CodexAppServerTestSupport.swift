import Foundation
@testable import SwiftASB
import Testing

@MainActor
func waitForObservableState(
    maxAttempts: Int = 200,
    predicate: @MainActor () -> Bool
) async {
    for _ in 0..<maxAttempts {
        if predicate() {
            return
        }
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(1))
    }
}

func waitForCondition(
    maxAttempts: Int = 200,
    predicate: @Sendable () async throws -> Bool
) async throws {
    for _ in 0..<maxAttempts {
        if try await predicate() {
            return
        }
        await Task.yield()
    }
}

actor FakeCodexAppServerTransport: CodexAppServerTransporting {
    struct RecordedResponse: Equatable {
        let requestID: CodexRPCRequestID
        let payload: Data
    }

    private(set) var recordedResponses: [RecordedResponse] = []

    private var rawRecordedMethods: [String] = []
    private var recordedRequestPayloads: [String: [Data]] = [:]
    private var threadListResult: [String: Any]?
    private var threadListResultQueue: [[String: Any]]
    private var threadReadResult: [String: Any]?
    private var threadForkResult: [String: Any]?
    private var threadResumeResult: [String: Any]?
    private var threadStartIDQueue: [String]
    private var turnStartIDQueue: [String]
    private var threadTurnsListErrorMessage: String?
    private var threadTurnsListResult: [String: Any]?
    private var threadTurnsListResultQueue: [[String: Any]]
    private var threadTurnsItemsListResult: [String: Any]?
    private var commandExecResult: [String: Any]
    private var commandExecResultQueue: [[String: Any]]
    private var appSnapshotResponseDelayNanoseconds: UInt64 = 0
    private var appSnapshotFailureMethods: Set<String> = []
    private let resolvedExecutable: CodexCLIExecutableResolver.Resolution?
    private let startError: CodexTransportError?
    private var started = false
    private var initializedSeen = false
    private var serverEventContinuation: AsyncStream<CodexRPCServerEvent>.Continuation?

    var recordedMethods: [String] {
        rawRecordedMethods.filter { $0 != "mcpServerStatus/list" }
    }

    var isStarted: Bool {
        started
    }

    init(
        executableResolution: CodexCLIExecutableResolver.Resolution? = nil,
        startError: CodexTransportError? = nil,
        threadListResult: [String: Any]? = nil,
        threadListResultQueue: [[String: Any]] = [],
        threadReadResult: [String: Any]? = nil,
        threadForkResult: [String: Any]? = nil,
        threadResumeResult: [String: Any]? = nil,
        threadStartIDQueue: [String] = [],
        turnStartIDQueue: [String] = [],
        threadTurnsListErrorMessage: String? = nil,
        threadTurnsListResult: [String: Any]? = nil,
        threadTurnsListResultQueue: [[String: Any]] = [],
        threadTurnsItemsListResult: [String: Any]? = nil,
        commandExecResult: [String: Any] = [
            "exitCode": 0,
            "stderr": "",
            "stdout": "",
        ],
        commandExecResultQueue: [[String: Any]] = []
    ) {
        resolvedExecutable = executableResolution
        self.startError = startError
        self.threadListResult = threadListResult
        self.threadListResultQueue = threadListResultQueue
        self.threadReadResult = threadReadResult
        self.threadForkResult = threadForkResult
        self.threadResumeResult = threadResumeResult
        self.threadStartIDQueue = threadStartIDQueue
        self.turnStartIDQueue = turnStartIDQueue
        self.threadTurnsListErrorMessage = threadTurnsListErrorMessage
        self.threadTurnsListResult = threadTurnsListResult
        self.threadTurnsListResultQueue = threadTurnsListResultQueue
        self.threadTurnsItemsListResult = threadTurnsItemsListResult
        self.commandExecResult = commandExecResult
        self.commandExecResultQueue = commandExecResultQueue
    }

    private static func isAppSnapshotRequest(_ method: String) -> Bool {
        method == "modelProvider/capabilities/read"
            || method == "mcpServerStatus/list"
            || method == "hooks/list"
            || method == "app/list"
            || method == "skills/list"
            || method == "plugin/list"
            || method == "collaborationMode/list"
    }

    func setThreadListResult(_ result: [String: Any]?) {
        threadListResult = result
    }

    func setThreadListResultQueue(_ resultQueue: [[String: Any]]) {
        threadListResultQueue = resultQueue
    }

    func setAppSnapshotResponseDelay(nanoseconds: UInt64) {
        appSnapshotResponseDelayNanoseconds = nanoseconds
    }

    func setAppSnapshotFailureMethods(_ methods: Set<String>) {
        appSnapshotFailureMethods = methods
    }

    func requestPayloads(for method: String) -> [Data] {
        recordedRequestPayloads[method] ?? []
    }

    func start() throws {
        if let startError {
            throw startError
        }
        started = true
        initializedSeen = false
    }

    func stop() {
        started = false
        serverEventContinuation?.finish()
        serverEventContinuation = nil
    }

    func send(_ requestPayload: Data, id: CodexRPCRequestID) async throws -> Data {
        guard started else {
            throw CodexTransportError.notStarted
        }

        let method = try requestMethod(from: requestPayload)
        rawRecordedMethods.append(method)
        recordedRequestPayloads[method, default: []].append(requestPayload)

        if Self.isAppSnapshotRequest(method) {
            try await Task.sleep(nanoseconds: appSnapshotResponseDelayNanoseconds)
        }

        if appSnapshotFailureMethods.contains(method) {
            return errorPayload(
                id: id,
                code: -32000,
                message: "Injected \(method) failure for SwiftASB tests."
            )
        }

        switch method {
            case "initialize":
                return responsePayload(
                    id: id,
                    result: [
                        "codexHome": "/Users/galew/.codex",
                        "platformFamily": "unix",
                        "platformOs": "macos",
                        "userAgent": "codex-cli/0.128.0",
                    ]
                )
            case "model/list":
                return responsePayload(
                    id: id,
                    result: [
                        "data": [
                            [
                                "additionalSpeedTiers": ["fast", "flex"],
                                "availabilityNux": [
                                    "message": "Available for this workspace.",
                                ],
                                "defaultReasoningEffort": "medium",
                                "description": "Balanced general-purpose model.",
                                "displayName": "GPT-5.4",
                                "hidden": false,
                                "id": "gpt-5.4",
                                "inputModalities": ["text", "image"],
                                "isDefault": true,
                                "model": "gpt-5.4",
                                "supportedReasoningEfforts": [
                                    [
                                        "description": "Faster responses.",
                                        "reasoningEffort": "low",
                                    ],
                                    [
                                        "description": "Balanced responses.",
                                        "reasoningEffort": "medium",
                                    ],
                                    [
                                        "description": "Deeper reasoning.",
                                        "reasoningEffort": "high",
                                    ],
                                ],
                                "supportsPersonality": true,
                                "upgrade": NSNull(),
                                "upgradeInfo": NSNull(),
                            ],
                        ],
                        "nextCursor": "cursor-models-next",
                    ]
                )
            case "modelProvider/capabilities/read":
                return responsePayload(
                    id: id,
                    result: [
                        "imageGeneration": true,
                        "namespaceTools": false,
                        "webSearch": true,
                    ]
                )
            case "hooks/list":
                return responsePayload(
                    id: id,
                    result: [
                        "data": [
                            [
                                "cwd": "/tmp/project",
                                "errors": [
                                    [
                                        "message": "Hook script is not executable.",
                                        "path": "/tmp/project/.codex/hooks/post-tool-use.sh",
                                    ],
                                ],
                                "hooks": [
                                    [
                                        "command": "swift test",
                                        "displayOrder": 2,
                                        "enabled": true,
                                        "eventName": "postToolUse",
                                        "handlerType": "command",
                                        "isManaged": false,
                                        "key": "project-post-tool-use",
                                        "matcher": "swift",
                                        "pluginId": NSNull(),
                                        "source": "project",
                                        "sourcePath": "/tmp/project/.codex/hooks/post-tool-use.sh",
                                        "statusMessage": "Ready.",
                                        "timeoutSec": 30,
                                    ],
                                    [
                                        "command": "swift format",
                                        "displayOrder": 3,
                                        "enabled": false,
                                        "eventName": "preToolUse",
                                        "handlerType": "command",
                                        "isManaged": false,
                                        "key": "user-pre-tool-use",
                                        "matcher": "swift",
                                        "pluginId": NSNull(),
                                        "source": "user",
                                        "sourcePath": "/Users/example/.codex/hooks/pre-tool-use.sh",
                                        "statusMessage": "Disabled.",
                                        "timeoutSec": 10,
                                    ],
                                ],
                                "warnings": [
                                    "Ignoring disabled user hook user-pre-tool-use.",
                                ],
                            ],
                        ],
                    ]
                )
            case "mcpServerStatus/list":
                let includesThreadScopedServer = try requestParam("threadId", from: requestPayload) is String
                var servers: [[String: Any]] = [
                    [
                        "authStatus": "oAuth",
                        "name": "calendar",
                        "resources": [
                            [
                                "_meta": ["source": "fixture"],
                                "annotations": NSNull(),
                                "description": "Today's events.",
                                "icons": [],
                                "mimeType": "application/json",
                                "name": "today",
                                "size": 128,
                                "title": "Today",
                                "uri": "calendar://events/today",
                            ],
                        ],
                        "resourceTemplates": [
                            [
                                "annotations": NSNull(),
                                "description": "Events by date.",
                                "mimeType": "application/json",
                                "name": "events-by-date",
                                "title": "Events By Date",
                                "uriTemplate": "calendar://events/{date}",
                            ],
                        ],
                        "tools": [
                            "list_events": [
                                "_meta": ["source": "fixture"],
                                "annotations": NSNull(),
                                "description": "List calendar events.",
                                "icons": [],
                                "inputSchema": ["type": "object"],
                                "name": "list_events",
                                "outputSchema": ["type": "object"],
                                "title": "List Events",
                            ],
                        ],
                    ],
                ]

                if includesThreadScopedServer {
                    servers.append(
                        [
                            "authStatus": "unsupported",
                            "name": "thread_notes",
                            "resources": [],
                            "resourceTemplates": [],
                            "tools": [
                                "search_notes": [
                                    "_meta": ["source": "fixture"],
                                    "annotations": NSNull(),
                                    "description": "Search thread notes.",
                                    "icons": [],
                                    "inputSchema": ["type": "object"],
                                    "name": "search_notes",
                                    "outputSchema": NSNull(),
                                    "title": "Search Notes",
                                ],
                            ],
                        ]
                    )
                }

                return responsePayload(
                    id: id,
                    result: [
                        "data": servers,
                        "nextCursor": NSNull(),
                    ]
                )
            case "mcpServer/resource/read":
                return responsePayload(
                    id: id,
                    result: [
                        "contents": [
                            [
                                "_meta": ["source": "fixture"],
                                "blob": NSNull(),
                                "mimeType": "application/json",
                                "text": #"{"events":[]}"#,
                                "uri": "calendar://events/today",
                            ],
                        ],
                    ]
                )
            case "thread/archive":
                return responsePayload(id: id, result: [:])
            case "thread/approveGuardianDeniedAction":
                return responsePayload(id: id, result: [:])
            case "thread/unarchive":
                return responsePayload(
                    id: id,
                    result: [
                        "thread": [
                            "cliVersion": "0.128.0",
                            "createdAt": 1_713_350_000,
                            "cwd": "/tmp/project",
                            "ephemeral": false,
                            "id": "thread-123",
                            "modelProvider": "openai",
                            "name": "Hydrated Thread",
                            "preview": "Hydrated thread preview",
                            "source": "cli",
                            "status": ["type": "notLoaded"],
                            "turns": [],
                            "updatedAt": 1_713_350_005,
                        ],
                    ]
                )
            case "thread/name/set":
                return responsePayload(id: id, result: [:])
            case "thread/metadata/update":
                return responsePayload(
                    id: id,
                    result: [
                        "thread": [
                            "cliVersion": "0.128.0",
                            "createdAt": 1_713_350_000,
                            "cwd": "/tmp/project",
                            "ephemeral": false,
                            "gitInfo": [
                                "branch": "main",
                                "originUrl": NSNull(),
                                "sha": "abc123",
                            ],
                            "id": "thread-123",
                            "modelProvider": "openai",
                            "name": "Hydrated Thread",
                            "preview": "Hydrated thread preview",
                            "source": "cli",
                            "status": ["type": "active"],
                            "turns": [],
                            "updatedAt": 1_713_350_006,
                        ],
                    ]
                )
            case "thread/rollback":
                return responsePayload(
                    id: id,
                    result: [
                        "thread": [
                            "cliVersion": "0.128.0",
                            "createdAt": 1_713_350_000,
                            "cwd": "/tmp/project",
                            "ephemeral": false,
                            "id": "thread-123",
                            "modelProvider": "openai",
                            "name": "Hydrated Thread",
                            "preview": "Hydrated thread preview",
                            "source": "cli",
                            "status": ["type": "active"],
                            "turns": [
                                [
                                    "completedAt": 1_713_350_004,
                                    "durationMs": 2000,
                                    "error": NSNull(),
                                    "id": "turn-older",
                                    "items": [
                                        [
                                            "id": "item-older-user",
                                            "text": "Older prompt",
                                            "type": "userMessage",
                                        ],
                                    ],
                                    "startedAt": 1_713_350_002,
                                    "status": "completed",
                                ],
                            ],
                            "updatedAt": 1_713_350_010,
                        ],
                    ]
                )
            case "thread/start":
                if !initializedSeen {
                    return errorPayload(
                        id: id,
                        code: -32000,
                        message: "initialized notification missing"
                    )
                }

                let threadID = threadStartIDQueue.isEmpty ? "thread-123" : threadStartIDQueue.removeFirst()

                return responsePayload(
                    id: id,
                    result: [
                        "approvalPolicy": "on-request",
                        "approvalsReviewer": "user",
                        "cwd": "/tmp/project",
                        "instructionSources": ["AGENTS.md"],
                        "model": "gpt-5.4",
                        "modelProvider": "openai",
                        "activePermissionProfile": [
                            "id": ":workspace",
                            "extends": NSNull(),
                        ],
                        "permissionProfile": [
                            "type": "managed",
                            "fileSystem": [
                                "type": "restricted",
                                "globScanMaxDepth": 4,
                                "entries": [
                                    [
                                        "access": "write",
                                        "path": [
                                            "type": "special",
                                            "value": [
                                                "kind": "project_roots",
                                                "path": NSNull(),
                                                "subpath": NSNull(),
                                            ],
                                        ],
                                    ],
                                    [
                                        "access": "read",
                                        "path": [
                                            "type": "path",
                                            "path": "/tmp/project",
                                        ],
                                    ],
                                ],
                            ],
                            "network": [
                                "enabled": true,
                            ],
                        ],
                        "reasoningEffort": "medium",
                        "sandbox": [
                            "type": "workspaceWrite",
                            "networkAccess": "enabled",
                            "writableRoots": ["/tmp/project"],
                        ],
                        "serviceTier": "fast",
                        "thread": [
                            "cliVersion": "0.128.0",
                            "createdAt": 1_713_350_000,
                            "cwd": "/tmp/project",
                            "ephemeral": false,
                            "id": threadID,
                            "modelProvider": "openai",
                            "preview": "Hello from the fake app-server",
                            "source": "cli",
                            "status": ["type": "active"],
                            "turns": [],
                            "updatedAt": 1_713_350_001,
                        ],
                    ]
                )
            case "thread/list":
                let result: [String: Any]
                if !threadListResultQueue.isEmpty {
                    result = threadListResultQueue.removeFirst()
                } else {
                    result = threadListResult ?? [
                        "data": [
                            [
                                "cliVersion": "0.128.0",
                                "createdAt": 1_713_350_000,
                                "cwd": "/tmp/project",
                                "ephemeral": false,
                                "id": "thread-123",
                                "modelProvider": "openai",
                                "name": "Hydrated Thread",
                                "preview": "Hydrated thread preview",
                                "source": "cli",
                                "status": ["type": "notLoaded"],
                                "turns": [],
                                "updatedAt": 1_713_350_005,
                            ],
                        ],
                        "nextCursor": "cursor-next",
                    ]
                }
                return responsePayload(
                    id: id,
                    result: result
                )
            case "thread/loaded/list":
                return responsePayload(
                    id: id,
                    result: [
                        "data": ["thread-123", "thread-456"],
                        "nextCursor": "cursor-loaded-next",
                    ]
                )
            case "fs/getMetadata":
                return responsePayload(
                    id: id,
                    result: [
                        "createdAtMs": 1_713_350_000_000,
                        "isDirectory": true,
                        "isFile": false,
                        "isSymlink": false,
                        "modifiedAtMs": 1_713_350_005_000,
                    ]
                )
            case "fs/readDirectory":
                let path = try requestParam("path", from: requestPayload) as? String
                let entries: [[String: Any]] = switch path {
                    case "/tmp/project":
                        [
                            [
                                "fileName": "Sources",
                                "isDirectory": true,
                                "isFile": false,
                            ],
                            [
                                "fileName": "Package.swift",
                                "isDirectory": false,
                                "isFile": true,
                            ],
                            [
                                "fileName": ".build",
                                "isDirectory": true,
                                "isFile": false,
                            ],
                        ]
                    case "/tmp/project/Sources":
                        [
                            [
                                "fileName": "SwiftASB",
                                "isDirectory": true,
                                "isFile": false,
                            ],
                            [
                                "fileName": "SwiftASBTests.swift",
                                "isDirectory": false,
                                "isFile": true,
                            ],
                        ]
                    case "/tmp/project/Sources/SwiftASB":
                        [
                            [
                                "fileName": "CodexFS.swift",
                                "isDirectory": false,
                                "isFile": true,
                            ],
                            [
                                "fileName": "CodexAppServer.swift",
                                "isDirectory": false,
                                "isFile": true,
                            ],
                        ]
                    case "/tmp/project/.build":
                        [
                            [
                                "fileName": "debug",
                                "isDirectory": true,
                                "isFile": false,
                            ],
                            [
                                "fileName": "cache.log",
                                "isDirectory": false,
                                "isFile": true,
                            ],
                        ]
                    case "/tmp/project/.build/debug":
                        [
                            [
                                "fileName": "CodexFS.o",
                                "isDirectory": false,
                                "isFile": true,
                            ],
                        ]
                    default:
                        []
                }
                return responsePayload(
                    id: id,
                    result: [
                        "entries": entries,
                    ]
                )
            case "fs/readFile":
                return responsePayload(
                    id: id,
                    result: [
                        "dataBase64": Data("hello from CodexFS".utf8).base64EncodedString(),
                    ]
                )
            case "fs/watch":
                return responsePayload(
                    id: id,
                    result: [
                        "path": "/tmp/project",
                    ]
                )
            case "fs/unwatch":
                return responsePayload(
                    id: id,
                    result: [:]
                )
            case "config/read":
                return responsePayload(
                    id: id,
                    result: [
                        "config": [
                            "model": "gpt-5.2",
                            "sandbox_mode": "workspace-write",
                        ],
                        "layers": [
                            [
                                "config": [
                                    "model": "gpt-5.2",
                                ],
                                "name": [
                                    "type": "user",
                                    "file": "/Users/galew/.codex/config.toml",
                                ],
                                "version": "1",
                            ],
                            [
                                "config": [
                                    "sandbox_mode": "workspace-write",
                                ],
                                "disabledReason": "Project config is disabled for this fixture.",
                                "name": [
                                    "type": "project",
                                    "dotCodexFolder": "/tmp/project/.codex",
                                ],
                                "version": "2",
                            ],
                            [
                                "config": [
                                    "review_model": "gpt-5.5",
                                ],
                                "name": [
                                    "type": "enterpriseManaged",
                                    "id": "enterprise-layer-1",
                                    "name": "Admin Defaults",
                                ],
                                "version": "3",
                            ],
                        ],
                        "origins": [
                            "model": [
                                "name": [
                                    "type": "user",
                                    "file": "/Users/galew/.codex/config.toml",
                                ],
                                "version": "1",
                            ],
                            "sandbox_mode": [
                                "name": [
                                    "type": "project",
                                    "dotCodexFolder": "/tmp/project/.codex",
                                ],
                                "version": "2",
                            ],
                            "review_model": [
                                "name": [
                                    "type": "enterpriseManaged",
                                    "id": "enterprise-layer-1",
                                    "name": "Admin Defaults",
                                ],
                                "version": "3",
                            ],
                        ],
                    ]
                )
            case "config/batchWrite":
                return responsePayload(
                    id: id,
                    result: [
                        "filePath": "/Users/example/.codex/config.toml",
                        "overriddenMetadata": NSNull(),
                        "status": "ok",
                        "version": "sha256:swiftasb-config-write",
                    ]
                )
            case "configRequirements/read":
                return responsePayload(
                    id: id,
                    result: [
                        "requirements": [
                            "featureRequirements": [
                                "network_access": true,
                            ],
                        ],
                    ]
                )
            case "app/list":
                return responsePayload(
                    id: id,
                    result: [
                        "data": [
                            [
                                "branding": [
                                    "isDiscoverableApp": true,
                                    "developer": "OpenAI",
                                    "category": "developer-tools",
                                    "privacyPolicy": "https://example.com/privacy",
                                    "termsOfService": "https://example.com/terms",
                                    "website": "https://example.com/github",
                                ],
                                "appMetadata": [
                                    "categories": ["Developer Tools"],
                                    "developer": "OpenAI",
                                    "screenshots": [
                                        [
                                            "fileId": "screenshot-1",
                                            "url": "https://example.com/screenshot.png",
                                            "userPrompt": "Show repository issues.",
                                        ],
                                    ],
                                    "version": "1.2.3",
                                    "versionId": "version-123",
                                    "versionNotes": "Fixture metadata.",
                                ],
                                "description": "GitHub app fixture",
                                "distributionChannel": "curated",
                                "id": "github",
                                "installUrl": "https://example.com/install",
                                "isAccessible": true,
                                "isEnabled": true,
                                "labels": ["kind": "connector"],
                                "logoUrl": "https://example.com/logo-light.png",
                                "logoUrlDark": "https://example.com/logo-dark.png",
                                "name": "GitHub",
                                "pluginDisplayNames": ["GitHub"],
                            ],
                        ],
                        "nextCursor": "apps-next",
                    ]
                )
            case "skills/list":
                return responsePayload(
                    id: id,
                    result: [
                        "data": [
                            [
                                "cwd": "/tmp/project",
                                "errors": [
                                    [
                                        "message": "Skipped duplicate skill.",
                                        "path": "/tmp/skills/duplicate/SKILL.md",
                                    ],
                                ],
                                "skills": [
                                    [
                                        "description": "Build Swift packages.",
                                        "enabled": true,
                                        "interface": [
                                            "displayName": "Swift Package Workflow",
                                            "shortDescription": "SwiftPM workflow from interface",
                                        ],
                                        "name": "swift-package-build-run-workflow",
                                        "path": "/tmp/skills/swift-package-build-run-workflow/SKILL.md",
                                        "scope": "user",
                                        "shortDescription": "Legacy SwiftPM workflow",
                                    ],
                                ],
                            ],
                        ],
                    ]
                )
            case "plugin/list":
                return responsePayload(
                    id: id,
                    result: [
                        "featuredPluginIds": ["github"],
                        "marketplaceLoadErrors": [
                            [
                                "marketplacePath": "/tmp/bad-marketplace.json",
                                "message": "Fixture marketplace failed to load.",
                            ],
                        ],
                        "marketplaces": [
                            [
                                "interface": [
                                    "displayName": "Curated",
                                ],
                                "name": "openai-curated",
                                "plugins": [
                                    [
                                        "authPolicy": "ON_USE",
                                        "enabled": true,
                                        "id": "github",
                                        "installed": true,
                                        "installPolicy": "AVAILABLE",
                                        "interface": [
                                            "brandColor": "#111111",
                                            "capabilities": ["issues", "pull-requests"],
                                            "category": "developer-tools",
                                            "defaultPrompt": ["Review my PR."],
                                            "developerName": "OpenAI",
                                            "displayName": "GitHub",
                                            "longDescription": "GitHub plugin fixture.",
                                            "screenshots": [],
                                            "screenshotUrls": [],
                                            "shortDescription": "GitHub workflows.",
                                        ],
                                        "name": "GitHub",
                                        "source": [
                                            "type": "remote",
                                        ],
                                    ],
                                    [
                                        "authPolicy": "ON_INSTALL",
                                        "enabled": false,
                                        "id": "local-plugin",
                                        "installed": false,
                                        "installPolicy": "NOT_AVAILABLE",
                                        "name": "Local Plugin",
                                        "source": [
                                            "path": "/tmp/plugins/local-plugin",
                                            "type": "local",
                                        ],
                                    ],
                                ],
                            ],
                        ],
                    ]
                )
            case "plugin/read":
                return responsePayload(
                    id: id,
                    result: [
                        "plugin": [
                            "apps": [
                                [
                                    "category": "developer-tools",
                                    "description": "GitHub app summary",
                                    "id": "github",
                                    "installUrl": "https://example.com/install",
                                    "name": "GitHub",
                                ],
                            ],
                            "appTemplates": [],
                            "description": "GitHub plugin detail fixture.",
                            "hooks": [
                                [
                                    "eventName": "preToolUse",
                                    "key": "github-pre-tool-use",
                                ],
                                [
                                    "eventName": "postToolUse",
                                    "key": "github-post-tool-use",
                                ],
                            ],
                            "marketplaceName": "openai-curated",
                            "marketplacePath": "/tmp/marketplaces/openai-curated.json",
                            "mcpServers": [],
                            "skills": [
                                [
                                    "description": "Review pull requests.",
                                    "enabled": true,
                                    "interface": [
                                        "displayName": "PR Review",
                                        "shortDescription": "Review PRs.",
                                    ],
                                    "name": "review-pr",
                                    "path": "/tmp/plugins/github/skills/review-pr/SKILL.md",
                                    "shortDescription": "Legacy review PRs.",
                                ],
                            ],
                            "summary": [
                                "authPolicy": "ON_USE",
                                "enabled": true,
                                "id": "github",
                                "installed": true,
                                "installPolicy": "AVAILABLE",
                                "interface": [
                                    "brandColor": "#111111",
                                    "capabilities": ["issues", "pull-requests"],
                                    "category": "developer-tools",
                                    "defaultPrompt": ["Review my PR."],
                                    "developerName": "OpenAI",
                                    "displayName": "GitHub",
                                    "longDescription": "GitHub plugin fixture.",
                                    "screenshots": [],
                                    "screenshotUrls": [],
                                    "shortDescription": "GitHub workflows.",
                                ],
                                "name": "GitHub",
                                "source": [
                                    "refName": "main",
                                    "sha": "abc123",
                                    "type": "git",
                                    "url": "https://github.com/openai/github-plugin",
                                ],
                            ],
                        ],
                    ]
                )
            case "collaborationMode/list":
                return responsePayload(
                    id: id,
                    result: [
                        "data": [
                            [
                                "mode": "plan",
                                "model": "gpt-5.2",
                                "name": "Plan",
                                "reasoning_effort": "medium",
                            ],
                        ],
                    ]
                )
            case "thread/goal/get":
                return responsePayload(
                    id: id,
                    result: [
                        "goal": [
                            "createdAt": 1_713_350_000,
                            "objective": "Promote schemas",
                            "status": "active",
                            "threadId": "thread-123",
                            "timeUsedSeconds": 12,
                            "tokenBudget": 20000,
                            "tokensUsed": 400,
                            "updatedAt": 1_713_350_010,
                        ],
                    ]
                )
            case "thread/goal/set":
                return responsePayload(
                    id: id,
                    result: [
                        "goal": [
                            "createdAt": 1_713_350_000,
                            "objective": "Promote schemas",
                            "status": "budgetLimited",
                            "threadId": "thread-123",
                            "timeUsedSeconds": 12,
                            "tokenBudget": 30000,
                            "tokensUsed": 400,
                            "updatedAt": 1_713_350_020,
                        ],
                    ]
                )
            case "thread/goal/clear":
                return responsePayload(
                    id: id,
                    result: [
                        "cleared": true,
                    ]
                )
            case "thread/read":
                return responsePayload(
                    id: id,
                    result: threadReadResult ?? [
                        "thread": [
                            "cliVersion": "0.128.0",
                            "createdAt": 1_713_350_000,
                            "cwd": "/tmp/project",
                            "ephemeral": false,
                            "id": "thread-123",
                            "modelProvider": "openai",
                            "name": "Hydrated Thread",
                            "preview": "Hydrated thread preview",
                            "source": "cli",
                            "status": ["type": "notLoaded"],
                            "turns": [
                                [
                                    "completedAt": 1_713_350_005,
                                    "durationMs": 3000,
                                    "error": NSNull(),
                                    "id": "turn-hydrated-1",
                                    "items": [
                                        [
                                            "id": "item-user-1",
                                            "text": "Hydrated user prompt.",
                                            "type": "userMessage",
                                        ],
                                        [
                                            "id": "item-agent-1",
                                            "status": "completed",
                                            "text": "Hydrated reply from thread/read.",
                                            "type": "agentMessage",
                                        ],
                                    ],
                                    "startedAt": 1_713_350_002,
                                    "status": "completed",
                                ],
                            ],
                            "updatedAt": 1_713_350_005,
                        ],
                    ]
                )
            case "thread/compact/start":
                return responsePayload(
                    id: id,
                    result: [:]
                )
            case "thread/fork":
                return responsePayload(
                    id: id,
                    result: threadForkResult ?? [
                        "approvalPolicy": "on-request",
                        "approvalsReviewer": "user",
                        "cwd": "/tmp/project",
                        "instructionSources": ["AGENTS.md"],
                        "model": "gpt-5.4",
                        "modelProvider": "openai",
                        "reasoningEffort": "medium",
                        "sandbox": [
                            "type": "workspaceWrite",
                            "networkAccess": "enabled",
                            "writableRoots": ["/tmp/project"],
                        ],
                        "serviceTier": "fast",
                        "thread": [
                            "cliVersion": "0.128.0",
                            "createdAt": 1_713_350_010,
                            "cwd": "/tmp/project",
                            "ephemeral": false,
                            "forkedFromId": "thread-123",
                            "id": "thread-456",
                            "modelProvider": "openai",
                            "name": "Forked Thread",
                            "preview": "Hydrated fork preview",
                            "source": "cli",
                            "status": ["type": "idle"],
                            "turns": [
                                [
                                    "completedAt": 1_713_350_005,
                                    "durationMs": 3000,
                                    "error": NSNull(),
                                    "id": "turn-hydrated-1",
                                    "items": [
                                        [
                                            "id": "item-agent-1",
                                            "status": "completed",
                                            "text": "Forked reply from thread/fork.",
                                            "type": "agentMessage",
                                        ],
                                    ],
                                    "startedAt": 1_713_350_002,
                                    "status": "completed",
                                ],
                            ],
                            "updatedAt": 1_713_350_011,
                        ],
                    ]
                )
            case "thread/resume":
                return responsePayload(
                    id: id,
                    result: threadResumeResult ?? [
                        "approvalPolicy": "on-request",
                        "approvalsReviewer": "user",
                        "cwd": "/tmp/project",
                        "instructionSources": ["AGENTS.md"],
                        "model": "gpt-5.4",
                        "modelProvider": "openai",
                        "reasoningEffort": "medium",
                        "sandbox": [
                            "type": "workspaceWrite",
                            "networkAccess": "enabled",
                            "writableRoots": ["/tmp/project"],
                        ],
                        "serviceTier": "fast",
                        "thread": [
                            "cliVersion": "0.128.0",
                            "createdAt": 1_713_350_000,
                            "cwd": "/tmp/project",
                            "ephemeral": false,
                            "id": "thread-123",
                            "modelProvider": "openai",
                            "name": "Resumed Thread",
                            "preview": "Hydrated resume preview",
                            "source": "cli",
                            "status": ["type": "idle"],
                            "turns": [
                                [
                                    "completedAt": 1_713_350_005,
                                    "durationMs": 3000,
                                    "error": NSNull(),
                                    "id": "turn-hydrated-1",
                                    "items": [
                                        [
                                            "id": "item-agent-1",
                                            "status": "completed",
                                            "text": "Resumed reply from thread/resume.",
                                            "type": "agentMessage",
                                        ],
                                    ],
                                    "startedAt": 1_713_350_002,
                                    "status": "completed",
                                ],
                            ],
                            "updatedAt": 1_713_350_005,
                        ],
                    ]
                )
            case "thread/turns/list":
                if let threadTurnsListErrorMessage {
                    return errorPayload(
                        id: id,
                        code: -32600,
                        message: threadTurnsListErrorMessage
                    )
                }
                if !threadTurnsListResultQueue.isEmpty {
                    return responsePayload(
                        id: id,
                        result: threadTurnsListResultQueue.removeFirst()
                    )
                }
                return responsePayload(
                    id: id,
                    result: threadTurnsListResult ?? [
                        "backwardsCursor": "cursor-newer",
                        "data": [
                            [
                                "completedAt": 1_713_350_100,
                                "durationMs": 2500,
                                "error": NSNull(),
                                "id": "turn-newer",
                                "items": [],
                                "startedAt": 1_713_350_050,
                                "status": "completed",
                            ],
                            [
                                "completedAt": 1_713_350_005,
                                "durationMs": 3000,
                                "error": NSNull(),
                                "id": "turn-older",
                                "items": [],
                                "startedAt": 1_713_350_002,
                                "status": "completed",
                            ],
                        ],
                        "nextCursor": "cursor-older",
                    ]
                )
            case "thread/items/list":
                return responsePayload(
                    id: id,
                    result: threadTurnsItemsListResult ?? [
                        "backwardsCursor": "cursor-newer-items",
                        "data": [
                            [
                                "id": "item-command-1",
                                "command": "swift test",
                                "status": "completed",
                                "type": "commandExecution",
                            ],
                            [
                                "id": "item-agent-1",
                                "status": "completed",
                                "text": "Done.",
                                "type": "agentMessage",
                            ],
                        ],
                        "nextCursor": "cursor-older-items",
                    ]
                )
            case "command/exec":
                if !commandExecResultQueue.isEmpty {
                    return responsePayload(
                        id: id,
                        result: commandExecResultQueue.removeFirst()
                    )
                }
                return responsePayload(
                    id: id,
                    result: commandExecResult
                )
            case "thread/shellCommand":
                return responsePayload(
                    id: id,
                    result: [:]
                )
            case "review/start":
                let delivery = try requestParam("delivery", from: requestPayload) as? String
                let sourceThreadID = try #require(requestParam("threadId", from: requestPayload) as? String)
                let reviewThreadID = delivery == "detached" ? "review-thread-123" : sourceThreadID
                let turnID = turnStartIDQueue.isEmpty ? "review-turn-123" : turnStartIDQueue.removeFirst()
                return responsePayload(
                    id: id,
                    result: [
                        "reviewThreadId": reviewThreadID,
                        "turn": [
                            "completedAt": NSNull(),
                            "durationMs": NSNull(),
                            "error": NSNull(),
                            "id": turnID,
                            "items": [],
                            "startedAt": 1_713_350_003,
                            "status": "inProgress",
                        ],
                    ]
                )
            case "turn/start":
                let turnID = turnStartIDQueue.isEmpty ? "turn-123" : turnStartIDQueue.removeFirst()
                return responsePayload(
                    id: id,
                    result: [
                        "turn": [
                            "completedAt": NSNull(),
                            "durationMs": NSNull(),
                            "error": NSNull(),
                            "id": turnID,
                            "items": [],
                            "startedAt": 1_713_350_002,
                            "status": "inProgress",
                        ],
                    ]
                )
            case "turn/steer":
                return responsePayload(
                    id: id,
                    result: [
                        "turnId": "turn-123",
                    ]
                )
            case "turn/interrupt":
                return responsePayload(
                    id: id,
                    result: [:]
                )
            default:
                return errorPayload(
                    id: id,
                    code: -32601,
                    message: "unsupported method in fake transport"
                )
        }
    }

    func sendNotification(_ notificationPayload: Data, method: String) throws {
        guard started else {
            throw CodexTransportError.notStarted
        }

        rawRecordedMethods.append(method)

        if method == "initialized" {
            initializedSeen = true
        }
    }

    func sendResponse(_ responsePayload: Data, requestID: CodexRPCRequestID) throws {
        guard started else {
            throw CodexTransportError.notStarted
        }

        recordedResponses.append(.init(requestID: requestID, payload: responsePayload))
    }

    func serverEvents() -> AsyncStream<CodexRPCServerEvent> {
        AsyncStream { continuation in
            serverEventContinuation = continuation
            continuation.onTermination = { _ in
                Task {
                    await self.clearServerEventContinuation()
                }
            }
        }
    }

    func executableResolution() -> CodexCLIExecutableResolver.Resolution? {
        resolvedExecutable
    }

    func recordedRequestPayload(for method: String) -> Data? {
        recordedRequestPayloads[method]?.last
    }

    func emitTurnCompleted(
        threadID: String,
        turnID: String,
        completedAt: Int = 1_713_350_005
    ) {
        let payload = payloadObject([
            "threadId": threadID,
            "turn": [
                "completedAt": completedAt,
                "durationMs": 3000,
                "error": NSNull(),
                "id": turnID,
                "items": [],
                "startedAt": 1_713_350_002,
                "status": "completed",
            ],
        ])

        serverEventContinuation?.yield(
            .notification(method: "turn/completed", payload: payload)
        )
    }

    func emitCommandExecutionApprovalRequest(
        requestID: CodexRPCRequestID,
        threadID: String,
        turnID: String,
        itemID: String
    ) {
        let payload = payloadObject([
            "command": "git status",
            "commandActions": [
                [
                    "command": "git status",
                    "type": "unknown",
                ],
            ],
            "cwd": "/tmp/project",
            "itemId": itemID,
            "reason": "Needs approval to read repository state.",
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .request(
                id: requestID,
                method: "item/commandExecution/requestApproval",
                payload: payload
            )
        )
    }

    func emitGuardianAutoReviewStarted(
        threadID: String,
        turnID: String,
        reviewID: String,
        targetItemID: String?
    ) {
        let payload = payloadObject([
            "action": [
                "command": "git status",
                "cwd": "/tmp/project",
                "source": "shell",
                "type": "command",
            ],
            "review": [
                "rationale": "Read-only repository inspection.",
                "riskLevel": "low",
                "status": "inProgress",
                "userAuthorization": "medium",
            ],
            "reviewId": reviewID,
            "startedAtMs": 1_713_350_002_000,
            "targetItemId": (targetItemID as Any?) ?? NSNull(),
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "item/autoApprovalReview/started", payload: payload)
        )
    }

    func emitGuardianAutoReviewCompleted(
        threadID: String,
        turnID: String,
        reviewID: String,
        status: String,
        targetItemID: String?
    ) {
        let payload = payloadObject([
            "action": [
                "host": "api.example.com",
                "port": 443,
                "protocol": "https",
                "target": "https://api.example.com",
                "type": "networkAccess",
            ],
            "completedAtMs": 1_713_350_003_000,
            "decisionSource": "agent",
            "review": [
                "rationale": "Network access is limited to the requested host.",
                "riskLevel": "medium",
                "status": status,
                "userAuthorization": "high",
            ],
            "reviewId": reviewID,
            "startedAtMs": 1_713_350_002_000,
            "targetItemId": (targetItemID as Any?) ?? NSNull(),
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "item/autoApprovalReview/completed", payload: payload)
        )
    }

    func emitToolUserInputRequest(
        requestID: CodexRPCRequestID,
        threadID: String,
        turnID: String,
        itemID: String
    ) {
        let payload = payloadObject([
            "itemId": itemID,
            "questions": [
                [
                    "header": "Goal",
                    "id": "goal",
                    "options": [
                        [
                            "description": "Use the existing plan as-is.",
                            "label": "Ship it",
                        ],
                        [
                            "description": "Pause the implementation and revisit scope.",
                            "label": "Replan",
                        ],
                    ],
                    "question": "Which direction should we take?",
                ],
            ],
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .request(
                id: requestID,
                method: "item/tool/requestUserInput",
                payload: payload
            )
        )
    }

    func emitMcpServerElicitationRequest(
        requestID: CodexRPCRequestID,
        threadID: String,
        turnID: String?
    ) {
        var payload: [String: Any] = [
            "message": "Do you want to connect the calendar server?",
            "mode": "url",
            "serverName": "calendar",
            "threadId": threadID,
            "url": "https://example.com/authorize",
            "elicitationId": "elicitation-1",
        ]
        payload["turnId"] = turnID ?? NSNull()

        serverEventContinuation?.yield(
            .request(
                id: requestID,
                method: "mcpServer/elicitation/request",
                payload: payloadObject(payload)
            )
        )
    }

    func emitServerRequestResolved(
        threadID: String,
        requestID: CodexRPCRequestID
    ) {
        let jsonRequestID: Any
        switch requestID {
            case let .string(value):
                jsonRequestID = value
            case let .int(value):
                jsonRequestID = value
        }

        let payload = payloadObject([
            "requestId": jsonRequestID,
            "threadId": threadID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "serverRequest/resolved", payload: payload)
        )
    }

    func emitThreadStarted(threadID: String) {
        let payload = payloadObject([
            "thread": [
                "cliVersion": "0.128.0",
                "createdAt": 1_713_350_000,
                "cwd": "/tmp/project",
                "ephemeral": false,
                "id": threadID,
                "modelProvider": "openai",
                "preview": "Hello from thread/started",
                "source": "cli",
                "status": ["type": "active"],
                "turns": [],
                "updatedAt": 1_713_350_001,
            ],
        ])

        serverEventContinuation?.yield(
            .notification(method: "thread/started", payload: payload)
        )
    }

    func emitThreadStatusChanged(threadID: String) {
        let payload = payloadObject([
            "threadId": threadID,
            "status": [
                "type": "active",
                "activeFlags": ["waitingOnApproval"],
            ],
        ])

        serverEventContinuation?.yield(
            .notification(method: "thread/status/changed", payload: payload)
        )
    }

    func emitThreadNameUpdated(threadID: String, threadName: String? = "Planning Thread") {
        let payload = payloadObject([
            "threadId": threadID,
            "threadName": threadName ?? NSNull(),
        ])

        serverEventContinuation?.yield(
            .notification(method: "thread/name/updated", payload: payload)
        )
    }

    func emitThreadArchived(threadID: String) {
        let payload = payloadObject([
            "threadId": threadID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "thread/archived", payload: payload)
        )
    }

    func emitThreadUnarchived(threadID: String) {
        let payload = payloadObject([
            "threadId": threadID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "thread/unarchived", payload: payload)
        )
    }

    func emitThreadTokenUsageUpdated(threadID: String, turnID: String) {
        let payload = payloadObject([
            "threadId": threadID,
            "turnId": turnID,
            "tokenUsage": [
                "last": [
                    "cachedInputTokens": 10,
                    "inputTokens": 20,
                    "outputTokens": 30,
                    "reasoningOutputTokens": 5,
                    "totalTokens": 65,
                ],
                "modelContextWindow": 200_000,
                "total": [
                    "cachedInputTokens": 100,
                    "inputTokens": 200,
                    "outputTokens": 300,
                    "reasoningOutputTokens": 50,
                    "totalTokens": 650,
                ],
            ],
        ])

        serverEventContinuation?.yield(
            .notification(method: "thread/tokenUsage/updated", payload: payload)
        )
    }

    func emitThreadGoalUpdated(threadID: String, turnID: String? = "turn-goal") {
        let payload = payloadObject([
            "goal": [
                "createdAt": 1_713_350_000,
                "objective": "Promote schemas",
                "status": "complete",
                "threadId": threadID,
                "timeUsedSeconds": 20,
                "tokensUsed": 500,
                "updatedAt": 1_713_350_030,
            ],
            "threadId": threadID,
            "turnId": turnID ?? NSNull(),
        ])

        serverEventContinuation?.yield(
            .notification(method: "thread/goal/updated", payload: payload)
        )
    }

    func emitThreadGoalCleared(threadID: String) {
        let payload = payloadObject([
            "threadId": threadID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "thread/goal/cleared", payload: payload)
        )
    }

    func emitFSChanged(watchID: String, changedPaths: [String]) {
        let payload = payloadObject([
            "watchId": watchID,
            "changedPaths": changedPaths,
        ])

        serverEventContinuation?.yield(
            .notification(method: "fs/changed", payload: payload)
        )
    }

    func emitThreadClosed(threadID: String) {
        let payload = payloadObject([
            "threadId": threadID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "thread/closed", payload: payload)
        )
    }

    func emitHookStarted(
        threadID: String,
        turnID: String?,
        hookID: String = "hook-1",
        status: String = "running"
    ) {
        let payload = payloadObject([
            "run": [
                "displayOrder": 1,
                "entries": [],
                "eventName": "preToolUse",
                "executionMode": "sync",
                "handlerType": "command",
                "id": hookID,
                "scope": "turn",
                "sourcePath": "/tmp/project/.codex/hooks/pre-tool-use.sh",
                "startedAt": 1_713_350_003,
                "status": status,
                "statusMessage": NSNull(),
            ],
            "threadId": threadID,
            "turnId": turnID ?? NSNull(),
        ])

        serverEventContinuation?.yield(
            .notification(method: "hook/started", payload: payload)
        )
    }

    func emitHookCompleted(
        threadID: String,
        turnID: String?,
        hookID: String = "hook-1",
        status: String = "completed",
        statusMessage: String? = nil
    ) {
        let jsonStatusMessage: Any = statusMessage ?? NSNull()
        let payload = payloadObject([
            "run": [
                "completedAt": 1_713_350_004,
                "displayOrder": 1,
                "durationMs": 150,
                "entries": [
                    [
                        "kind": "feedback",
                        "text": "Hook finished.",
                    ],
                ],
                "eventName": "preToolUse",
                "executionMode": "sync",
                "handlerType": "command",
                "id": hookID,
                "scope": "turn",
                "sourcePath": "/tmp/project/.codex/hooks/pre-tool-use.sh",
                "startedAt": 1_713_350_003,
                "status": status,
                "statusMessage": jsonStatusMessage,
            ],
            "threadId": threadID,
            "turnId": turnID ?? NSNull(),
        ])

        serverEventContinuation?.yield(
            .notification(method: "hook/completed", payload: payload)
        )
    }

    func emitWarning(
        threadID: String?,
        message: String = "Runtime configuration is using a fallback."
    ) {
        let payload = payloadObject([
            "message": message,
            "threadId": threadID ?? NSNull(),
        ])

        serverEventContinuation?.yield(
            .notification(method: "warning", payload: payload)
        )
    }

    func emitGuardianWarning(
        threadID: String,
        message: String = "Guardian flagged this session for review."
    ) {
        let payload = payloadObject([
            "message": message,
            "threadId": threadID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "guardianWarning", payload: payload)
        )
    }

    func emitModelRerouted(
        threadID: String,
        turnID: String,
        fromModel: String = "gpt-5.4",
        toModel: String = "gpt-5.4-safe"
    ) {
        let payload = payloadObject([
            "fromModel": fromModel,
            "reason": "highRiskCyberActivity",
            "threadId": threadID,
            "toModel": toModel,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "model/rerouted", payload: payload)
        )
    }

    func emitModelVerification(
        threadID: String,
        turnID: String
    ) {
        let payload = payloadObject([
            "threadId": threadID,
            "turnId": turnID,
            "verifications": ["trustedAccessForCyber"],
        ])

        serverEventContinuation?.yield(
            .notification(method: "model/verification", payload: payload)
        )
    }

    func emitMalformedModelRerouted() {
        let payload = payloadObject([
            "fromModel": "gpt-5.4",
            "reason": "unexpectedFutureReason",
            "threadId": "thread-123",
            "toModel": "gpt-5.4-safe",
            "turnId": "turn-123",
        ])

        serverEventContinuation?.yield(
            .notification(method: "model/rerouted", payload: payload)
        )
    }

    func emitTurnStarted(threadID: String, turnID: String) {
        let payload = payloadObject([
            "threadId": threadID,
            "turn": [
                "completedAt": NSNull(),
                "durationMs": NSNull(),
                "error": NSNull(),
                "id": turnID,
                "items": [],
                "startedAt": 1_713_350_002,
                "status": "inProgress",
            ],
        ])

        serverEventContinuation?.yield(
            .notification(method: "turn/started", payload: payload)
        )
    }

    func emitTurnPlanUpdated(threadID: String, turnID: String) {
        let payload = payloadObject([
            "explanation": "Map richer progress notifications.",
            "plan": [
                [
                    "status": "inProgress",
                    "step": "Promote protocol events into CodexTurnEvent",
                ],
                [
                    "status": "pending",
                    "step": "Add consumer-facing stream tests",
                ],
            ],
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "turn/plan/updated", payload: payload)
        )
    }

    func emitItemStarted(
        threadID: String,
        turnID: String,
        itemID: String,
        item: [String: Any]? = nil
    ) {
        let payload = payloadObject([
            "item": item ?? [
                "id": itemID,
                "type": "plan",
            ],
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "item/started", payload: payload)
        )
    }

    func emitAgentMessageDelta(threadID: String, turnID: String, itemID: String) {
        let payload = payloadObject([
            "delta": "Working on it",
            "itemId": itemID,
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "item/agentMessage/delta", payload: payload)
        )
    }

    func emitFileChangeOutputDelta(
        threadID: String,
        turnID: String,
        itemID: String,
        delta: String
    ) {
        let payload = payloadObject([
            "delta": delta,
            "itemId": itemID,
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "item/fileChange/outputDelta", payload: payload)
        )
    }

    func emitFileChangePatchUpdated(
        threadID: String,
        turnID: String,
        itemID: String,
        path: String,
        diff: String,
        additionalChanges: [[String: String]] = []
    ) {
        let rawChanges = [["diff": diff, "path": path]] + additionalChanges
        let changes = rawChanges.map { change in
            [
                "diff": change["diff"] ?? "",
                "kind": [
                    "type": "update",
                ],
                "path": change["path"] ?? "",
            ] as [String: Any]
        }
        let payload = payloadObject([
            "changes": changes,
            "itemId": itemID,
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "item/fileChange/patchUpdated", payload: payload)
        )
    }

    func emitAppListUpdated() {
        let payload = payloadObject([
            "data": [],
        ])

        serverEventContinuation?.yield(
            .notification(method: "app/list/updated", payload: payload)
        )
    }

    func emitSkillsChanged() {
        let payload = payloadObject([:])

        serverEventContinuation?.yield(
            .notification(method: "skills/changed", payload: payload)
        )
    }

    func emitMcpServerStatusUpdated(
        name: String = "calendar",
        status: String = "ready",
        error: String? = nil,
        threadID: String? = nil
    ) {
        var payload: [String: Any] = [
            "error": error ?? NSNull(),
            "name": name,
            "status": status,
        ]
        if let threadID {
            payload["threadId"] = threadID
        }

        serverEventContinuation?.yield(
            .notification(method: "mcpServer/startupStatus/updated", payload: payloadObject(payload))
        )
    }

    func emitCommandExecutionOutputDelta(
        threadID: String,
        turnID: String,
        itemID: String,
        delta: String
    ) {
        let payload = payloadObject([
            "delta": delta,
            "itemId": itemID,
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "item/commandExecution/outputDelta", payload: payload)
        )
    }

    func emitPlanDelta(threadID: String, turnID: String, itemID: String) {
        let payload = payloadObject([
            "delta": "Stream partial plan text",
            "itemId": itemID,
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "item/plan/delta", payload: payload)
        )
    }

    func emitReasoningTextDelta(threadID: String, turnID: String, itemID: String) {
        let payload = payloadObject([
            "contentIndex": 0,
            "delta": "thinking...",
            "itemId": itemID,
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "item/reasoning/textDelta", payload: payload)
        )
    }

    func emitReasoningSummaryTextDelta(threadID: String, turnID: String, itemID: String) {
        let payload = payloadObject([
            "delta": "Summarizing the approach.",
            "itemId": itemID,
            "summaryIndex": 0,
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "item/reasoning/summaryTextDelta", payload: payload)
        )
    }

    func emitItemCompleted(
        threadID: String,
        turnID: String,
        itemID: String,
        item: [String: Any]? = nil
    ) {
        let payload = payloadObject([
            "item": item ?? [
                "id": itemID,
                "status": "completed",
                "text": "Done.",
                "type": "agentMessage",
            ],
            "threadId": threadID,
            "turnId": turnID,
        ])

        serverEventContinuation?.yield(
            .notification(method: "item/completed", payload: payload)
        )
    }

    private func requestMethod(from payload: Data) throws -> String {
        let object = try #require(
            try JSONSerialization.jsonObject(with: payload) as? [String: Any]
        )
        return try #require(object["method"] as? String)
    }

    private func requestParam(_ name: String, from payload: Data) throws -> Any? {
        let object = try #require(
            try JSONSerialization.jsonObject(with: payload) as? [String: Any]
        )
        let params = try #require(object["params"] as? [String: Any])
        return params[name]
    }

    private func responsePayload(id: CodexRPCRequestID, result: [String: Any]) -> Data {
        payloadObject([
            "id": id.jsonObjectValue,
            "result": result,
        ])
    }

    private func errorPayload(id: CodexRPCRequestID, code: Int, message: String) -> Data {
        payloadObject([
            "id": id.jsonObjectValue,
            "error": [
                "code": code,
                "message": message,
            ],
        ])
    }

    private func payloadObject(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }

    private func clearServerEventContinuation() {
        serverEventContinuation = nil
    }
}

func turnEvents(
    from stream: AsyncThrowingStream<CodexTurnEvent, Error>,
    count: Int
) async throws -> [CodexTurnEvent] {
    var iterator = stream.makeAsyncIterator()
    var events: [CodexTurnEvent] = []

    while events.count < count, let event = try await iterator.next() {
        events.append(event)
    }

    return events
}

func diagnosticEvents(
    from stream: AsyncThrowingStream<CodexDiagnosticEvent, Error>,
    count: Int
) async throws -> [CodexDiagnosticEvent] {
    var iterator = stream.makeAsyncIterator()
    var events: [CodexDiagnosticEvent] = []

    while events.count < count, let event = try await iterator.next() {
        events.append(event)
    }

    return events
}

func nextDiagnosticEventOrEnd(
    from stream: AsyncThrowingStream<CodexDiagnosticEvent, Error>,
    timeoutNanoseconds: UInt64 = 1_000_000_000
) async throws -> CodexDiagnosticEvent? {
    let iteratorTask = Task {
        var iterator = stream.makeAsyncIterator()
        return try await iterator.next()
    }

    let timeoutTask = Task {
        try await Task.sleep(nanoseconds: timeoutNanoseconds)
    }

    defer {
        iteratorTask.cancel()
        timeoutTask.cancel()
    }

    return try await withThrowingTaskGroup(of: CodexDiagnosticEvent?.self) { group in
        defer { group.cancelAll() }

        group.addTask {
            try await iteratorTask.value
        }
        group.addTask {
            try await timeoutTask.value
            throw TimeoutError()
        }

        let result = try await group.next()
        return try #require(result)
    }
}

func nextTurnEventOrEnd(
    from stream: AsyncThrowingStream<CodexTurnEvent, Error>,
    timeoutNanoseconds: UInt64 = 1_000_000_000
) async throws -> CodexTurnEvent? {
    let iteratorTask = Task {
        var iterator = stream.makeAsyncIterator()
        return try await iterator.next()
    }

    let timeoutTask = Task {
        try await Task.sleep(nanoseconds: timeoutNanoseconds)
    }

    defer {
        iteratorTask.cancel()
        timeoutTask.cancel()
    }

    return try await withThrowingTaskGroup(of: CodexTurnEvent?.self) { group in
        group.addTask {
            try await iteratorTask.value
        }
        group.addTask {
            try await timeoutTask.value
            throw TimeoutError()
        }

        let result = try await group.next()
        group.cancelAll()
        return try #require(result)
    }
}

func threadEvents(
    from stream: AsyncThrowingStream<CodexThreadEvent, Error>,
    count: Int
) async throws -> [CodexThreadEvent] {
    var iterator = stream.makeAsyncIterator()
    var events: [CodexThreadEvent] = []

    while events.count < count, let event = try await iterator.next() {
        events.append(event)
    }

    return events
}

func temporarySQLiteHistoryStore() throws -> (ThreadHistoryStore, URL) {
    let temporaryDirectory = FileManager.default
        .temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
        at: temporaryDirectory,
        withIntermediateDirectories: true
    )
    let historyStore = try ThreadHistoryStore(
        configuration: .init(
            inMemory: false,
            storeURL: temporaryDirectory.appendingPathComponent("ThreadHistory.sqlite")
        )
    )
    return (historyStore, temporaryDirectory)
}

func tearDownTemporarySQLiteHistoryStore(
    _ historyStore: ThreadHistoryStore,
    directory: URL
) async {
    try? await historyStore.detachPersistentStoresForTeardown()
    try? FileManager.default.removeItem(at: directory)
}

func settleObservableTeardown() async {
    await Task.yield()
    await Task.yield()
}

extension CodexRPCRequestID {
    var jsonObjectValue: Any {
        switch self {
            case let .string(value):
                value
            case let .int(value):
                value
        }
    }
}

struct TimeoutError: Error {}
