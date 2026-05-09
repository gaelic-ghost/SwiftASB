import Foundation

struct CodexAppServerProtocol {
    enum Method: String, Sendable, Codable {
        case initialize = "initialize"
        case initialized = "initialized"
        case threadCompactStart = "thread/compact/start"
        case threadArchive = "thread/archive"
        case threadFork = "thread/fork"
        case threadList = "thread/list"
        case threadRead = "thread/read"
        case threadResume = "thread/resume"
        case threadRollback = "thread/rollback"
        case threadSetName = "thread/name/set"
        case threadStart = "thread/start"
        case threadMetadataUpdate = "thread/metadata/update"
        case threadTurnsList = "thread/turns/list"
        case threadTurnsItemsList = "thread/turns/items/list"
        case threadLoadedList = "thread/loaded/list"
        case threadUnarchive = "thread/unarchive"
        case threadGoalGet = "thread/goal/get"
        case threadGoalSet = "thread/goal/set"
        case threadGoalClear = "thread/goal/clear"
        case turnStart = "turn/start"
        case turnSteer = "turn/steer"
        case turnInterrupt = "turn/interrupt"
        case fsGetMetadata = "fs/getMetadata"
        case fsReadDirectory = "fs/readDirectory"
        case fsReadFile = "fs/readFile"
        case fsWatch = "fs/watch"
        case fsUnwatch = "fs/unwatch"
        case appList = "app/list"
        case collaborationModeList = "collaborationMode/list"
        case configRead = "config/read"
        case configRequirementsRead = "configRequirements/read"
        case hooksList = "hooks/list"
        case modelList = "model/list"
        case modelProviderCapabilitiesRead = "modelProvider/capabilities/read"
        case mcpServerStatusList = "mcpServerStatus/list"
        case mcpResourceRead = "mcpServer/resource/read"
        case pluginList = "plugin/list"
        case pluginRead = "plugin/read"
        case skillsList = "skills/list"
    }

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.encoder = encoder
        self.decoder = decoder
    }

    func makeInitializeRequest(
        id: CodexRPCRequestID,
        params: CodexWireInitializeParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .initialize, params: params),
            method: .initialize
        )
    }

    func makeInitializedNotification() throws -> Data {
        try encodeNotification(
            JSONRPCNotificationEnvelope(method: .initialized),
            method: .initialized
        )
    }

    func makeThreadStartRequest(
        id: CodexRPCRequestID,
        params: CodexWireThreadStartParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .threadStart, params: params),
            method: .threadStart
        )
    }

    func makeThreadCompactStartRequest(
        id: CodexRPCRequestID,
        params: CodexWireThreadCompactStartParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .threadCompactStart, params: params),
            method: .threadCompactStart
        )
    }

    func makeThreadRollbackRequest(
        id: CodexRPCRequestID,
        params: CodexWireThreadRollbackParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .threadRollback, params: params),
            method: .threadRollback
        )
    }

    func makeThreadArchiveRequest(
        id: CodexRPCRequestID,
        params: CodexWireThreadArchiveParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .threadArchive, params: params),
            method: .threadArchive
        )
    }

    func makeThreadUnarchiveRequest(
        id: CodexRPCRequestID,
        params: CodexWireThreadUnarchiveParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .threadUnarchive, params: params),
            method: .threadUnarchive
        )
    }

    func makeThreadSetNameRequest(
        id: CodexRPCRequestID,
        params: CodexWireThreadSetNameParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .threadSetName, params: params),
            method: .threadSetName
        )
    }

    func makeThreadMetadataUpdateRequest(
        id: CodexRPCRequestID,
        params: CodexProtocolThreadMetadataUpdateParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .threadMetadataUpdate, params: params),
            method: .threadMetadataUpdate
        )
    }

    func makeThreadReadRequest(
        id: CodexRPCRequestID,
        params: CodexProtocolThreadReadParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .threadRead, params: params),
            method: .threadRead
        )
    }

    func makeThreadResumeRequest(
        id: CodexRPCRequestID,
        params: CodexProtocolThreadResumeParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .threadResume, params: params),
            method: .threadResume
        )
    }

    func makeThreadForkRequest(
        id: CodexRPCRequestID,
        params: CodexProtocolThreadForkParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .threadFork, params: params),
            method: .threadFork
        )
    }

    func makeThreadListRequest(
        id: CodexRPCRequestID,
        params: CodexProtocolThreadListParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .threadList, params: params),
            method: .threadList
        )
    }

    func makeThreadTurnsListRequest(
        id: CodexRPCRequestID,
        params: CodexProtocolThreadTurnsListParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .threadTurnsList, params: params),
            method: .threadTurnsList
        )
    }

    func makeThreadTurnsItemsListRequest(
        id: CodexRPCRequestID,
        params: CodexWireThreadTurnsItemsListParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .threadTurnsItemsList, params: params),
            method: .threadTurnsItemsList
        )
    }

    func makeThreadLoadedListRequest(
        id: CodexRPCRequestID,
        params: CodexWireThreadLoadedListParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .threadLoadedList, params: params),
            method: .threadLoadedList
        )
    }

    func makeThreadGoalGetRequest(
        id: CodexRPCRequestID,
        params: CodexWireThreadGoalGetParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .threadGoalGet, params: params),
            method: .threadGoalGet
        )
    }

    func makeThreadGoalSetRequest(
        id: CodexRPCRequestID,
        params: CodexWireThreadGoalSetParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .threadGoalSet, params: params),
            method: .threadGoalSet
        )
    }

    func makeThreadGoalClearRequest(
        id: CodexRPCRequestID,
        params: CodexWireThreadGoalClearParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .threadGoalClear, params: params),
            method: .threadGoalClear
        )
    }

    func makeFSGetMetadataRequest(
        id: CodexRPCRequestID,
        params: CodexWireFSGetMetadataParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .fsGetMetadata, params: params),
            method: .fsGetMetadata
        )
    }

    func makeFSWatchRequest(
        id: CodexRPCRequestID,
        params: CodexWireFSWatchParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .fsWatch, params: params),
            method: .fsWatch
        )
    }

    func makeFSUnwatchRequest(
        id: CodexRPCRequestID,
        params: CodexWireFSUnwatchParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .fsUnwatch, params: params),
            method: .fsUnwatch
        )
    }

    func makeConfigReadRequest(
        id: CodexRPCRequestID,
        params: CodexWireConfigReadParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .configRead, params: params),
            method: .configRead
        )
    }

    func makeConfigRequirementsReadRequest(id: CodexRPCRequestID) throws -> Data {
        try encodeRequestWithoutParams(
            JSONRPCRequestEnvelopeWithoutParams(id: id, method: .configRequirementsRead),
            method: .configRequirementsRead
        )
    }

    func makeAppListRequest(
        id: CodexRPCRequestID,
        params: CodexWireAppsListParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .appList, params: params),
            method: .appList
        )
    }

    func makeSkillsListRequest(
        id: CodexRPCRequestID,
        params: CodexWireSkillsListParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .skillsList, params: params),
            method: .skillsList
        )
    }

    func makePluginListRequest(
        id: CodexRPCRequestID,
        params: CodexWirePluginListParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .pluginList, params: params),
            method: .pluginList
        )
    }

    func makePluginReadRequest(
        id: CodexRPCRequestID,
        params: CodexWirePluginReadParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .pluginRead, params: params),
            method: .pluginRead
        )
    }

    func makeCollaborationModeListRequest(
        id: CodexRPCRequestID,
        params: CodexProtocolCollaborationModeListParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .collaborationModeList, params: params),
            method: .collaborationModeList
        )
    }

    func makeFSReadDirectoryRequest(
        id: CodexRPCRequestID,
        params: CodexWireFSReadDirectoryParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .fsReadDirectory, params: params),
            method: .fsReadDirectory
        )
    }

    func makeFSReadFileRequest(
        id: CodexRPCRequestID,
        params: CodexWireFSReadFileParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .fsReadFile, params: params),
            method: .fsReadFile
        )
    }

    func makeTurnStartRequest(
        id: CodexRPCRequestID,
        params: CodexWireTurnStartParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .turnStart, params: params),
            method: .turnStart
        )
    }

    func makeTurnInterruptRequest(
        id: CodexRPCRequestID,
        params: CodexProtocolTurnInterruptParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .turnInterrupt, params: params),
            method: .turnInterrupt
        )
    }

    func makeModelListRequest(
        id: CodexRPCRequestID,
        params: CodexWireModelListParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .modelList, params: params),
            method: .modelList
        )
    }

    func makeModelProviderCapabilitiesReadRequest(
        id: CodexRPCRequestID,
        params: CodexProtocolModelProviderCapabilitiesReadParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .modelProviderCapabilitiesRead, params: params),
            method: .modelProviderCapabilitiesRead
        )
    }

    func makeHooksListRequest(
        id: CodexRPCRequestID,
        params: CodexProtocolHooksListParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .hooksList, params: params),
            method: .hooksList
        )
    }

    func makeMcpServerStatusListRequest(
        id: CodexRPCRequestID,
        params: CodexWireListMCPServerStatusParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .mcpServerStatusList, params: params),
            method: .mcpServerStatusList
        )
    }

    func makeMcpResourceReadRequest(
        id: CodexRPCRequestID,
        params: CodexWireMCPResourceReadParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .mcpResourceRead, params: params),
            method: .mcpResourceRead
        )
    }

    func makeTurnSteerRequest(
        id: CodexRPCRequestID,
        params: CodexProtocolTurnSteerParams
    ) throws -> Data {
        try encodeRequest(
            JSONRPCRequestEnvelope(id: id, method: .turnSteer, params: params),
            method: .turnSteer
        )
    }

    func makeServerResponse<Result: Encodable>(
        id: CodexRPCRequestID,
        result: Result
    ) throws -> Data {
        do {
            return try encoder.encode(JSONRPCResultEnvelope(id: id, result: result))
        } catch {
            throw CodexProtocolError.requestEncodingFailed(
                method: "server request response",
                reason: String(describing: error)
            )
        }
    }

    func decodeInitializeResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireInitializeResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .initialize,
            resultType: CodexWireInitializeResponse.self
        )
    }

    func decodeThreadStartResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireThreadStartResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .threadStart,
            resultType: CodexWireThreadStartResponse.self
        )
    }

    func decodeThreadArchiveResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexProtocolThreadArchiveResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .threadArchive,
            resultType: CodexProtocolThreadArchiveResponse.self
        )
    }

    func decodeThreadUnarchiveResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireThreadUnarchiveResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .threadUnarchive,
            resultType: CodexWireThreadUnarchiveResponse.self
        )
    }

    func decodeThreadCompactStartResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexProtocolThreadCompactStartResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .threadCompactStart,
            resultType: CodexProtocolThreadCompactStartResponse.self
        )
    }

    func decodeThreadRollbackResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireThreadRollbackResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .threadRollback,
            resultType: CodexWireThreadRollbackResponse.self
        )
    }

    func decodeThreadSetNameResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexProtocolThreadSetNameResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .threadSetName,
            resultType: CodexProtocolThreadSetNameResponse.self
        )
    }

    func decodeThreadMetadataUpdateResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireThreadMetadataUpdateResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .threadMetadataUpdate,
            resultType: CodexWireThreadMetadataUpdateResponse.self
        )
    }

    func decodeTurnStartResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireTurnStartResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .turnStart,
            resultType: CodexWireTurnStartResponse.self
        )
    }

    func decodeThreadReadResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexProtocolThreadReadResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .threadRead,
            resultType: CodexProtocolThreadReadResponse.self
        )
    }

    func decodeThreadResumeResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireThreadStartResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .threadResume,
            resultType: CodexWireThreadStartResponse.self
        )
    }

    func decodeThreadForkResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireThreadStartResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .threadFork,
            resultType: CodexWireThreadStartResponse.self
        )
    }

    func decodeThreadListResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexProtocolThreadListResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .threadList,
            resultType: CodexProtocolThreadListResponse.self
        )
    }

    func decodeThreadTurnsListResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexProtocolThreadTurnsListResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .threadTurnsList,
            resultType: CodexProtocolThreadTurnsListResponse.self
        )
    }

    func decodeThreadTurnsItemsListResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireThreadTurnsItemsListResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .threadTurnsItemsList,
            resultType: CodexWireThreadTurnsItemsListResponse.self
        )
    }

    func decodeThreadLoadedListResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireThreadLoadedListResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .threadLoadedList,
            resultType: CodexWireThreadLoadedListResponse.self
        )
    }

    func decodeThreadGoalGetResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireThreadGoalGetResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .threadGoalGet,
            resultType: CodexWireThreadGoalGetResponse.self
        )
    }

    func decodeThreadGoalSetResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireThreadGoalSetResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .threadGoalSet,
            resultType: CodexWireThreadGoalSetResponse.self
        )
    }

    func decodeThreadGoalClearResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireThreadGoalClearResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .threadGoalClear,
            resultType: CodexWireThreadGoalClearResponse.self
        )
    }

    func decodeFSGetMetadataResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireFSGetMetadataResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .fsGetMetadata,
            resultType: CodexWireFSGetMetadataResponse.self
        )
    }

    func decodeFSWatchResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireFSWatchResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .fsWatch,
            resultType: CodexWireFSWatchResponse.self
        )
    }

    func decodeFSUnwatchResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> [String: CodexWireJSONValue] {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .fsUnwatch,
            resultType: [String: CodexWireJSONValue].self
        )
    }

    func decodeConfigReadResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireConfigReadResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .configRead,
            resultType: CodexWireConfigReadResponse.self
        )
    }

    func decodeConfigRequirementsReadResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireConfigRequirementsReadResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .configRequirementsRead,
            resultType: CodexWireConfigRequirementsReadResponse.self
        )
    }

    func decodeAppListResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireAppsListResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .appList,
            resultType: CodexWireAppsListResponse.self
        )
    }

    func decodeSkillsListResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireSkillsListResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .skillsList,
            resultType: CodexWireSkillsListResponse.self
        )
    }

    func decodePluginListResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWirePluginListResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .pluginList,
            resultType: CodexWirePluginListResponse.self
        )
    }

    func decodePluginReadResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWirePluginReadResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .pluginRead,
            resultType: CodexWirePluginReadResponse.self
        )
    }

    func decodeCollaborationModeListResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireCollaborationModeListResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .collaborationModeList,
            resultType: CodexWireCollaborationModeListResponse.self
        )
    }

    func decodeFSReadDirectoryResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireFSReadDirectoryResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .fsReadDirectory,
            resultType: CodexWireFSReadDirectoryResponse.self
        )
    }

    func decodeFSReadFileResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireFSReadFileResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .fsReadFile,
            resultType: CodexWireFSReadFileResponse.self
        )
    }

    func decodeTurnInterruptResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexProtocolTurnInterruptResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .turnInterrupt,
            resultType: CodexProtocolTurnInterruptResponse.self
        )
    }

    func decodeTurnSteerResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexProtocolTurnSteerResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .turnSteer,
            resultType: CodexProtocolTurnSteerResponse.self
        )
    }

    func decodeModelListResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireModelListResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .modelList,
            resultType: CodexWireModelListResponse.self
        )
    }

    func decodeModelProviderCapabilitiesReadResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexProtocolModelProviderCapabilitiesReadResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .modelProviderCapabilitiesRead,
            resultType: CodexProtocolModelProviderCapabilitiesReadResponse.self
        )
    }

    func decodeHooksListResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexProtocolHooksListResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .hooksList,
            resultType: CodexProtocolHooksListResponse.self
        )
    }

    func decodeMcpServerStatusListResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireListMCPServerStatusResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .mcpServerStatusList,
            resultType: CodexWireListMCPServerStatusResponse.self
        )
    }

    func decodeMcpResourceReadResponse(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID
    ) throws -> CodexWireMCPResourceReadResponse {
        try decodeResponse(
            responsePayload,
            expectedID: expectedID,
            method: .mcpResourceRead,
            resultType: CodexWireMCPResourceReadResponse.self
        )
    }

    func decodeServerEvent(
        _ serverEvent: CodexRPCServerEvent
    ) throws -> CodexAppServerProtocolEvent? {
        switch serverEvent {
        case let .request(id, method, payload):
            switch method {
            case "item/commandExecution/requestApproval":
                return .commandExecutionApprovalRequested(
                    try decodeServerRequest(
                        payload,
                        method: method,
                        id: id,
                        requestType: CodexProtocolCommandExecutionApprovalRequest.self
                    )
                )
            case "item/fileChange/requestApproval":
                return .fileChangeApprovalRequested(
                    try decodeServerRequest(
                        payload,
                        method: method,
                        id: id,
                        requestType: CodexProtocolFileChangeApprovalRequest.self
                    )
                )
            case "item/permissions/requestApproval":
                return .permissionsApprovalRequested(
                    try decodeServerRequest(
                        payload,
                        method: method,
                        id: id,
                        requestType: CodexProtocolPermissionsApprovalRequest.self
                    )
                )
            case "item/tool/requestUserInput":
                return .toolUserInputRequested(
                    try decodeServerRequest(
                        payload,
                        method: method,
                        id: id,
                        requestType: CodexProtocolToolUserInputRequest.self
                    )
                )
            case "mcpServer/elicitation/request":
                return .mcpServerElicitationRequested(
                    try decodeMCPServerElicitationRequest(
                        payload,
                        method: method,
                        id: id
                    )
                )
            default:
                return nil
            }
        case let .notification(method, payload):
            switch method {
            case "app/list/updated":
                return .appListUpdated(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireAppListUpdatedNotification.self
                    )
                )
            case "skills/changed":
                return .skillsChanged(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: [String: CodexWireJSONValue].self
                    )
                )
            case "mcpServer/status/updated":
                return .mcpServerStatusUpdated(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireMCPServerStatusUpdatedNotification.self
                    )
                )
            case "config/warning":
                return .configWarning(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireConfigWarningNotification.self
                    )
                )
            case "deprecation/notice":
                return .deprecationNotice(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireDeprecationNoticeNotification.self
                    )
                )
            case "remoteControl/status/changed":
                return .remoteControlStatusChanged(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireRemoteControlStatusChangedNotification.self
                    )
                )
            case "thread/started":
                return .threadStarted(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireThreadStartedNotification.self
                    )
                )
            case "thread/status/changed":
                return .threadStatusChanged(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireThreadStatusChangedNotification.self
                    )
                )
            case "thread/archived":
                return .threadArchived(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireThreadArchivedNotification.self
                    )
                )
            case "thread/unarchived":
                return .threadUnarchived(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireThreadUnarchivedNotification.self
                    )
                )
            case "thread/closed":
                return .threadClosed(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireThreadClosedNotification.self
                    )
                )
            case "thread/name/updated":
                return .threadNameUpdated(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireThreadNameUpdatedNotification.self
                    )
                )
            case "thread/tokenUsage/updated":
                return .threadTokenUsageUpdated(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireThreadTokenUsageUpdatedNotification.self
                    )
                )
            case "thread/goal/updated":
                return .threadGoalUpdated(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireThreadGoalUpdatedNotification.self
                    )
                )
            case "thread/goal/cleared":
                return .threadGoalCleared(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireThreadGoalClearedNotification.self
                    )
                )
            case "fs/changed":
                return .fsChanged(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireFSChangedNotification.self
                    )
                )
            case "hook/started":
                return .hookStarted(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireHookStartedNotification.self
                    )
                )
            case "hook/completed":
                return .hookCompleted(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireHookCompletedNotification.self
                    )
                )
            case "warning":
                return .warning(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireWarningNotification.self
                    )
                )
            case "guardianWarning":
                return .guardianWarning(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireGuardianWarningNotification.self
                    )
                )
            case "model/rerouted":
                return .modelRerouted(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireModelReroutedNotification.self
                    )
                )
            case "model/verification":
                return .modelVerification(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireModelVerificationNotification.self
                    )
                )
            case "turn/started":
                return .turnStarted(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireTurnStartedNotification.self
                    )
                )
            case "turn/diff/updated":
                return .turnDiffUpdated(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireTurnDiffUpdatedNotification.self
                    )
                )
            case "turn/plan/updated":
                return .turnPlanUpdated(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireTurnPlanUpdatedNotification.self
                    )
                )
            case "turn/completed":
                return .turnCompleted(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireTurnCompletedNotification.self
                    )
                )
            case "item/started":
                return .itemStarted(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireItemStartedNotification.self
                    )
                )
            case "item/completed":
                return .itemCompleted(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireItemCompletedNotification.self
                    )
                )
            case "item/commandExecution/outputDelta":
                return .commandExecutionOutputDelta(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireCommandExecutionOutputDeltaNotification.self
                    )
                )
            case "item/fileChange/outputDelta":
                return .fileChangeOutputDelta(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireFileChangeOutputDeltaNotification.self
                    )
                )
            case "item/fileChange/patchUpdated":
                return .fileChangePatchUpdated(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireFileChangePatchUpdatedNotification.self
                    )
                )
            case "item/agentMessage/delta":
                return .agentMessageDelta(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireAgentMessageDeltaNotification.self
                    )
                )
            case "item/plan/delta":
                return .planDelta(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWirePlanDeltaNotification.self
                    )
                )
            case "item/reasoning/summaryPartAdded":
                return .reasoningSummaryPartAdded(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireReasoningSummaryPartAddedNotification.self
                    )
                )
            case "item/reasoning/summaryTextDelta":
                return .reasoningSummaryTextDelta(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireReasoningSummaryTextDeltaNotification.self
                    )
                )
            case "item/reasoning/textDelta":
                return .reasoningTextDelta(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireReasoningTextDeltaNotification.self
                    )
                )
            case "serverRequest/resolved":
                return .serverRequestResolved(
                    try decodeNotification(
                        payload,
                        method: method,
                        resultType: CodexWireServerRequestResolvedNotification.self
                    )
                )
            default:
                return nil
            }
        }
    }

    private func encodeRequest<Params: Encodable>(
        _ request: JSONRPCRequestEnvelope<Params>,
        method: Method
    ) throws -> Data {
        do {
            return try encoder.encode(request)
        } catch {
            throw CodexProtocolError.requestEncodingFailed(
                method: method.rawValue,
                reason: String(describing: error)
            )
        }
    }

    private func encodeRequestWithoutParams(
        _ request: JSONRPCRequestEnvelopeWithoutParams,
        method: Method
    ) throws -> Data {
        do {
            return try encoder.encode(request)
        } catch {
            throw CodexProtocolError.requestEncodingFailed(
                method: method.rawValue,
                reason: String(describing: error)
            )
        }
    }

    private func encodeNotification(
        _ notification: JSONRPCNotificationEnvelope,
        method: Method
    ) throws -> Data {
        do {
            return try encoder.encode(notification)
        } catch {
            throw CodexProtocolError.requestEncodingFailed(
                method: method.rawValue,
                reason: String(describing: error)
            )
        }
    }

    private func decodeResponse<Result: Decodable>(
        _ responsePayload: Data,
        expectedID: CodexRPCRequestID,
        method: Method,
        resultType: Result.Type
    ) throws -> Result {
        let successfulResponse: JSONRPCResponseEnvelope<Result>
        do {
            successfulResponse = try decoder.decode(
                JSONRPCResponseEnvelope<Result>.self,
                from: responsePayload
            )
        } catch {
            if let rpcError = try? decoder.decode(JSONRPCErrorEnvelope.self, from: responsePayload) {
                throw CodexProtocolError.rpcError(
                    id: rpcError.id,
                    code: rpcError.error.code,
                    message: rpcError.error.message,
                    data: rpcError.error.data
                )
            }

            throw CodexProtocolError.responseDecodingFailed(
                context: method.rawValue,
                reason: String(describing: error)
            )
        }

        guard successfulResponse.id == expectedID else {
            throw CodexProtocolError.responseIDMismatch(
                expected: expectedID,
                actual: successfulResponse.id
            )
        }

        return successfulResponse.result
    }

    private func decodeNotification<Result: Decodable>(
        _ payload: Data,
        method: String,
        resultType: Result.Type
    ) throws -> Result {
        do {
            return try decoder.decode(resultType, from: payload)
        } catch {
            throw CodexProtocolError.eventDecodingFailed(
                method: method,
                reason: String(describing: error)
            )
        }
    }

    private func decodeServerRequest<Request: Decodable & RequestIDBindable>(
        _ payload: Data,
        method: String,
        id: CodexRPCRequestID,
        requestType: Request.Type
    ) throws -> Request {
        do {
            let decoded = try decoder.decode(requestType, from: payload)
            return decoded.settingRequestID(id)
        } catch {
            throw CodexProtocolError.eventDecodingFailed(
                method: method,
                reason: String(describing: error)
            )
        }
    }

    private func decodeMCPServerElicitationRequest(
        _ payload: Data,
        method: String,
        id: CodexRPCRequestID
    ) throws -> CodexProtocolMCPServerElicitationRequest {
        do {
            let decoded = try decoder.decode(CodexProtocolMCPServerElicitationRequest.self, from: payload)
            return decoded.settingRequestID(id)
        } catch {
            throw CodexProtocolError.eventDecodingFailed(
                method: method,
                reason: String(describing: error)
            )
        }
    }
}

private protocol RequestIDBindable {
    func settingRequestID(_ requestID: CodexRPCRequestID) -> Self
}

extension CodexProtocolCommandExecutionApprovalRequest: RequestIDBindable {
    fileprivate func settingRequestID(_ requestID: CodexRPCRequestID) -> Self {
        var copy = self
        copy.requestID = requestID
        return copy
    }
}

extension CodexProtocolFileChangeApprovalRequest: RequestIDBindable {
    fileprivate func settingRequestID(_ requestID: CodexRPCRequestID) -> Self {
        var copy = self
        copy.requestID = requestID
        return copy
    }
}

extension CodexProtocolPermissionsApprovalRequest: RequestIDBindable {
    fileprivate func settingRequestID(_ requestID: CodexRPCRequestID) -> Self {
        var copy = self
        copy.requestID = requestID
        return copy
    }
}

extension CodexProtocolToolUserInputRequest: RequestIDBindable {
    fileprivate func settingRequestID(_ requestID: CodexRPCRequestID) -> Self {
        var copy = self
        copy.requestID = requestID
        return copy
    }
}

extension CodexProtocolMCPServerElicitationRequest {
    fileprivate func settingRequestID(_ requestID: CodexRPCRequestID) -> Self {
        .init(
            mode: mode,
            requestID: requestID,
            serverName: serverName,
            threadID: threadID,
            turnID: turnID
        )
    }

    fileprivate init(
        mode: Mode,
        requestID: CodexRPCRequestID,
        serverName: String,
        threadID: String,
        turnID: String?
    ) {
        self.mode = mode
        self.requestID = requestID
        self.serverName = serverName
        self.threadID = threadID
        self.turnID = turnID
    }
}

private struct JSONRPCRequestEnvelope<Params: Encodable>: Encodable {
    let id: CodexRPCRequestID
    let method: CodexAppServerProtocol.Method
    let params: Params
}

private struct JSONRPCRequestEnvelopeWithoutParams: Encodable {
    let id: CodexRPCRequestID
    let method: CodexAppServerProtocol.Method
}

private struct JSONRPCNotificationEnvelope: Encodable {
    let method: CodexAppServerProtocol.Method
}

private struct JSONRPCResponseEnvelope<Result: Decodable>: Decodable {
    let id: CodexRPCRequestID
    let result: Result
}

private struct JSONRPCResultEnvelope<Result: Encodable>: Encodable {
    let id: CodexRPCRequestID
    let result: Result
}

private struct JSONRPCErrorEnvelope: Decodable {
    let error: JSONRPCErrorBody
    let id: CodexRPCRequestID
}

private struct JSONRPCErrorBody: Decodable {
    let code: Int
    let data: CodexWireJSONValue?
    let message: String
}
