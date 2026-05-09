import Foundation
import Testing
@testable import SwiftASB

@Suite("CodexAppServerTransport subprocess edges", .serialized)
struct CodexAppServerTransportTests {
    @Test("rejects duplicate in-flight request IDs before writing a second request")
    func rejectsDuplicatePendingRequestIDs() async throws {
        let executableURL = try makeFakeCodexExecutable()
        defer { try? FileManager.default.removeItem(at: executableURL.deletingLastPathComponent()) }
        let transport = CodexAppServerTransport(
            configuration: .init(
                codexExecutableURL: executableURL,
                environment: ["SWIFTASB_FAKE_TRANSPORT_MODE": "hold-pending"]
            )
        )

        try await transport.start()
        let payload = requestPayload(id: "request-1")
        let firstRequest = Task {
            try await transport.send(payload, id: .string("request-1"))
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        do {
            _ = try await transport.send(payload, id: .string("request-1"))
            Issue.record("Expected duplicate in-flight request IDs to be rejected.")
        } catch let error as CodexTransportError {
            #expect(error == .duplicatePendingRequest(id: .string("request-1")))
            #expect(error.localizedDescription.contains("duplicate in-flight JSON-RPC request"))
        }

        await transport.stop()
        firstRequest.cancel()
        _ = try? await firstRequest.value
    }

    @Test("fails pending responses with process termination and retained stderr")
    func failsPendingResponsesWithProcessTerminationAndRecentStderr() async throws {
        let executableURL = try makeFakeCodexExecutable()
        defer { try? FileManager.default.removeItem(at: executableURL.deletingLastPathComponent()) }
        let transport = CodexAppServerTransport(
            configuration: .init(
                codexExecutableURL: executableURL,
                environment: ["SWIFTASB_FAKE_TRANSPORT_MODE": "exit-with-stderr"]
            )
        )

        try await transport.start()

        do {
            _ = try await withTransportTimeout(seconds: 3) {
                try await transport.send(
                    requestPayload(id: "request-1"),
                    id: .string("request-1")
                )
            }
            Issue.record("Expected the pending request to fail when the subprocess exits.")
        } catch let error as CodexTransportError {
            let recentStandardError: [String]
            switch error {
            case let .processTerminated(reason, status, standardError):
                #expect(reason == "exit")
                #expect(status == 42)
                recentStandardError = standardError
            case let .unexpectedEndOfStream(standardError):
                recentStandardError = standardError
            default:
                Issue.record("Expected process termination or stdout EOF, got \(String(describing: error)).")
                await transport.stop()
                return
            }

            let recentStandardErrorIndexes = recentStandardError.compactMap { line in
                Int(line.replacingOccurrences(of: "stderr-line-", with: ""))
            }
            #expect(recentStandardError.count <= 20)
            #expect(recentStandardError.isEmpty == false)
            #expect(recentStandardErrorIndexes.count == recentStandardError.count)
            #expect(recentStandardErrorIndexes.last == recentStandardErrorIndexes.max())
            #expect(error.localizedDescription.contains("Recent stderr"))
            #expect(error.localizedDescription.contains(recentStandardError.last ?? ""))
        }

        await transport.stop()
    }

    @Test("fails fast when malformed stdout is followed by a later valid response")
    func failsFastOnMalformedStdoutBeforeLaterValidResponse() async throws {
        let executableURL = try makeFakeCodexExecutable()
        defer { try? FileManager.default.removeItem(at: executableURL.deletingLastPathComponent()) }
        let transport = CodexAppServerTransport(
            configuration: .init(
                codexExecutableURL: executableURL,
                environment: ["SWIFTASB_FAKE_TRANSPORT_MODE": "malformed-then-valid"]
            )
        )

        try await transport.start()

        do {
            _ = try await withTransportTimeout(seconds: 3) {
                try await transport.send(
                    requestPayload(id: "request-1"),
                    id: .string("request-1")
                )
            }
            Issue.record("Expected malformed stdout to fail the transport before a later valid response.")
        } catch let error as CodexTransportError {
            guard case let .invalidJSONRPCEnvelope(reason) = error else {
                Issue.record("Expected invalidJSONRPCEnvelope, got \(String(describing: error)).")
                await transport.stop()
                return
            }

            #expect(reason.isEmpty == false)
            #expect(error.localizedDescription.contains("malformed JSON-RPC envelope"))
        }

        await transport.stop()
    }

    @Test("ignores late duplicate response lines after completing the pending request")
    func ignoresLateDuplicateResponseLines() async throws {
        let executableURL = try makeFakeCodexExecutable()
        defer { try? FileManager.default.removeItem(at: executableURL.deletingLastPathComponent()) }
        let transport = CodexAppServerTransport(
            configuration: .init(
                codexExecutableURL: executableURL,
                environment: ["SWIFTASB_FAKE_TRANSPORT_MODE": "duplicate-response-lines"]
            )
        )

        try await transport.start()

        let response = try await withTransportTimeout(seconds: 3) {
            try await transport.send(
                requestPayload(id: "request-1"),
                id: .string("request-1")
            )
        }
        let object = try #require(try JSONSerialization.jsonObject(with: response) as? [String: Any])
        let result = try #require(object["result"] as? [String: Any])
        #expect(result["value"] as? String == "first")

        try await Task.sleep(nanoseconds: 100_000_000)
        await transport.stop()
    }
}

private func makeFakeCodexExecutable() throws -> URL {
    let directoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("SwiftASB-FakeCodex-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

    let executableURL = directoryURL.appendingPathComponent("codex", isDirectory: false)
    try Data(fakeCodexScript.utf8).write(to: executableURL)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o755],
        ofItemAtPath: executableURL.path
    )
    return executableURL
}

private func requestPayload(id: String) -> Data {
    Data(#"{"id":"\#(id)","method":"initialize","params":{}}"#.utf8)
}

private func withTransportTimeout<T: Sendable>(
    seconds: Double,
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TransportTestTimeout()
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

private struct TransportTestTimeout: Error {}

private let fakeCodexScript = """
#!/bin/sh

if [ "$1" = "--version" ]; then
  printf '%s\\n' 'codex-cli 0.130.0'
  exit 0
fi

mode="${SWIFTASB_FAKE_TRANSPORT_MODE:-valid-response}"

case "$mode" in
  hold-pending)
    IFS= read -r _request
    sleep 10
    ;;
  exit-with-stderr)
    index=1
    while [ "$index" -le 25 ]; do
      printf 'stderr-line-%s\\n' "$index" >&2
      index=$((index + 1))
    done
    IFS= read -r _request
    exit 42
    ;;
  malformed-then-valid)
    IFS= read -r _request
    printf '%s\\n' 'not-json'
    printf '%s\\n' '{"id":"request-1","result":{"ok":true}}'
    sleep 1
    ;;
  duplicate-response-lines)
    IFS= read -r _request
    printf '%s\\n' '{"id":"request-1","result":{"value":"first"}}'
    printf '%s\\n' '{"id":"request-1","result":{"value":"second"}}'
    sleep 1
    ;;
  *)
    IFS= read -r _request
    printf '%s\\n' '{"id":"request-1","result":{"ok":true}}'
    sleep 1
    ;;
esac
"""
