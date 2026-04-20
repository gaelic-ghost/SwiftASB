import Foundation

internal protocol CodexAppServerTransporting: Actor {
    func start() throws
    func stop()
    func send(_ requestPayload: Data, id: CodexRPCRequestID) async throws -> Data
    func sendResponse(_ responsePayload: Data, requestID: CodexRPCRequestID) throws
    func sendNotification(_ notificationPayload: Data, method: String) throws
    func serverEvents() -> AsyncStream<CodexRPCServerEvent>
    func executableResolution() -> CodexCLIExecutableResolver.Resolution?
}
