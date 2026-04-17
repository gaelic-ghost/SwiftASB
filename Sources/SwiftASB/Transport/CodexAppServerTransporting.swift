import Foundation

internal protocol CodexAppServerTransporting: Actor {
    func start() throws
    func stop()
    func send(_ requestPayload: Data, id: CodexRPCRequestID) async throws -> Data
    func sendNotification(_ notificationPayload: Data, method: String) throws
}
