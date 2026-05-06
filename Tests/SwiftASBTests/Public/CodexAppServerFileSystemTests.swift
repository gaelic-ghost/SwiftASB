import Foundation
import Testing
@testable import SwiftASB

extension CodexAppServerTests {
    @Test("CodexFS routes read-only filesystem requests through the app-server")
    func codexFSRoutesReadOnlyRequestsThroughAppServer() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()
        _ = try await client.initialize(
            .init(
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        let metadata = try await client.fs.readMetadata(.init(path: "/tmp/project"))
        #expect(metadata.createdAtMilliseconds == 1_713_350_000_000)
        #expect(metadata.modifiedAtMilliseconds == 1_713_350_005_000)
        #expect(metadata.isDirectory)
        #expect(metadata.isFile == false)
        #expect(metadata.isSymbolicLink == false)

        let directory = try await client.fs.readDirectory(.init(path: "/tmp/project"))
        #expect(directory.entries.map(\.fileName) == ["Sources", "Package.swift"])
        #expect(directory.entries.map(\.kind) == [.directory, .file])

        let file = try await client.fs.readFile(.init(path: "/tmp/project/README.md"))
        #expect(String(data: file.data, encoding: .utf8) == "hello from CodexFS")

        let metadataRequest = try #require(await transport.recordedRequestPayload(for: "fs/getMetadata"))
        #expect(value(at: ["params", "path"], in: try decodedJSONObject(from: metadataRequest)) as? String == "/tmp/project")

        let directoryRequest = try #require(await transport.recordedRequestPayload(for: "fs/readDirectory"))
        #expect(value(at: ["params", "path"], in: try decodedJSONObject(from: directoryRequest)) as? String == "/tmp/project")

        let fileRequest = try #require(await transport.recordedRequestPayload(for: "fs/readFile"))
        #expect(value(at: ["params", "path"], in: try decodedJSONObject(from: fileRequest)) as? String == "/tmp/project/README.md")

        await client.stop()
    }

    @Test("lists app-server loaded thread ids")
    func listsAppServerLoadedThreadIDs() async throws {
        let transport = FakeCodexAppServerTransport()
        let client = CodexAppServer(transport: transport)

        try await client.start()
        _ = try await client.initialize(
            .init(
                clientInfo: .init(
                    name: "SwiftASBTests",
                    title: "SwiftASB Tests",
                    version: "0.1.0"
                )
            )
        )

        let loaded = try await client.listLoadedThreads(.init(cursor: "loaded-cursor", limit: 2))
        #expect(loaded.threadIDs == ["thread-123", "thread-456"])
        #expect(loaded.nextCursor == "cursor-loaded-next")

        let requestPayload = try #require(await transport.recordedRequestPayload(for: "thread/loaded/list"))
        let request = try decodedJSONObject(from: requestPayload)
        #expect(value(at: ["params", "cursor"], in: request) as? String == "loaded-cursor")
        #expect(value(at: ["params", "limit"], in: request) as? Int == 2)

        await client.stop()
    }
}

private func decodedJSONObject(from data: Data) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func value(
    at path: [String],
    in object: [String: Any]
) -> Any? {
    var current: Any = object
    for key in path {
        guard let dictionary = current as? [String: Any],
              let next = dictionary[key] else {
            return nil
        }
        current = next
    }
    return current
}
