import Foundation
import Testing
@testable import SwiftASB

@Suite("CodexRPCEnvelope", .serialized)
struct CodexRPCEnvelopeTests {
    @Test("classifies JSON-RPC responses using string request IDs")
    func classifiesResponse() throws {
        let payload = #"{"id":"abc123","result":{"ok":true}}"#.data(using: .utf8)!

        let classified = try CodexRPCEnvelope.classifyInboundMessage(payload)

        #expect(classified == .response(id: .string("abc123"), payload: payload))
    }

    @Test("classifies JSON-RPC notifications without request IDs")
    func classifiesNotification() throws {
        let payload = #"{"method":"thread/started","params":{"threadId":"t_123"}}"#.data(using: .utf8)!
        let expectedParamsPayload = #"{"threadId":"t_123"}"#.data(using: .utf8)!

        let classified = try CodexRPCEnvelope.classifyInboundMessage(payload)

        #expect(classified == .serverEvent(.notification(method: "thread/started", payload: expectedParamsPayload)))
    }

    @Test("classifies server-originated JSON-RPC requests with integer IDs")
    func classifiesServerRequest() throws {
        let payload = #"{"id":7,"method":"approval/request","params":{"kind":"exec-command"}}"#.data(using: .utf8)!
        let expectedParamsPayload = #"{"kind":"exec-command"}"#.data(using: .utf8)!

        let classified = try CodexRPCEnvelope.classifyInboundMessage(payload)

        #expect(classified == .serverEvent(.request(id: .int(7), method: "approval/request", payload: expectedParamsPayload)))
    }

    @Test("rejects envelopes that have neither method nor ID")
    func rejectsMeaninglessEnvelope() throws {
        let payload = #"{"params":{"ok":true}}"#.data(using: .utf8)!

        #expect(throws: CodexTransportError.self) {
            try CodexRPCEnvelope.classifyInboundMessage(payload)
        }
    }
}
