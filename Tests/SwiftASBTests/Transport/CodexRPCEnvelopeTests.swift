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

    @Test("tolerates versioned JSON-RPC envelopes even though app-server omits the version field")
    func toleratesVersionedEnvelope() throws {
        let payload = #"{"jsonrpc":"2.0","id":"abc123","result":{"ok":true}}"#.data(using: .utf8)!

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

    @Test("classifies notifications without params as empty payloads")
    func classifiesNotificationWithoutParams() throws {
        let payload = #"{"method":"initialized"}"#.data(using: .utf8)!
        let expectedParamsPayload = #"{}"#.data(using: .utf8)!

        let classified = try CodexRPCEnvelope.classifyInboundMessage(payload)

        #expect(classified == .serverEvent(.notification(method: "initialized", payload: expectedParamsPayload)))
    }

    @Test("classifies server-originated JSON-RPC requests with integer IDs")
    func classifiesServerRequest() throws {
        let payload = #"{"id":7,"method":"approval/request","params":{"kind":"exec-command"}}"#.data(using: .utf8)!
        let expectedParamsPayload = #"{"kind":"exec-command"}"#.data(using: .utf8)!

        let classified = try CodexRPCEnvelope.classifyInboundMessage(payload)

        #expect(classified == .serverEvent(.request(id: .int(7), method: "approval/request", payload: expectedParamsPayload)))
    }

    @Test("classifies zero as an integer request ID instead of a boolean")
    func classifiesZeroRequestID() throws {
        let payload = #"{"id":0,"method":"item/commandExecution/requestApproval","params":{"threadId":"thread-123"}}"#.data(using: .utf8)!
        let expectedParamsPayload = #"{"threadId":"thread-123"}"#.data(using: .utf8)!

        let classified = try CodexRPCEnvelope.classifyInboundMessage(payload)

        #expect(
            classified == .serverEvent(
                .request(
                    id: .int(0),
                    method: "item/commandExecution/requestApproval",
                    payload: expectedParamsPayload
                )
            )
        )
    }

    @Test("preserves numeric request IDs at the Swift Int boundary")
    func preservesNumericRequestIDAtIntBoundary() throws {
        let payload = Data(#"{"id":\#(Int.max),"result":{"ok":true}}"#.utf8)

        let classified = try CodexRPCEnvelope.classifyInboundMessage(payload)

        #expect(classified == .response(id: .int(Int.max), payload: payload))
    }

    @Test("rejects envelopes that have neither method nor ID")
    func rejectsMeaninglessEnvelope() throws {
        let payload = #"{"params":{"ok":true}}"#.data(using: .utf8)!

        #expect(throws: CodexTransportError.self) {
            try CodexRPCEnvelope.classifyInboundMessage(payload)
        }
    }

    @Test("rejects boolean request IDs")
    func rejectsBooleanRequestID() throws {
        let payload = #"{"id":true,"result":{"ok":true}}"#.data(using: .utf8)!

        #expect(throws: CodexTransportError.self) {
            try CodexRPCEnvelope.classifyInboundMessage(payload)
        }
    }

    @Test("rejects fractional numeric request IDs")
    func rejectsFractionalRequestID() throws {
        let payload = #"{"id":1.5,"result":{"ok":true}}"#.data(using: .utf8)!

        #expect(throws: CodexTransportError.self) {
            try CodexRPCEnvelope.classifyInboundMessage(payload)
        }
    }

    @Test("rejects numeric request IDs beyond the Swift Int range")
    func rejectsOutOfRangeRequestID() throws {
        let payload = #"{"id":9223372036854775808,"result":{"ok":true}}"#.data(using: .utf8)!

        #expect(throws: CodexTransportError.self) {
            try CodexRPCEnvelope.classifyInboundMessage(payload)
        }
    }

    @Test("rejects object request IDs")
    func rejectsObjectRequestID() throws {
        let payload = #"{"id":{"nested":1},"result":{"ok":true}}"#.data(using: .utf8)!

        #expect(throws: CodexTransportError.self) {
            try CodexRPCEnvelope.classifyInboundMessage(payload)
        }
    }
}
