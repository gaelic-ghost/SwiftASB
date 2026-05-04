import Foundation
import Testing
@testable import SwiftASB

extension CodexAppServerTests {
    @Test("lists workspace files under the thread current directory")
    func listsWorkspaceFilesUnderThreadCurrentDirectory() throws {
        let workspaceURL = try makeTemporaryWorkspace()
        defer { try? FileManager.default.removeItem(at: workspaceURL) }

        let sourcesURL = workspaceURL.appendingPathComponent("Sources", isDirectory: true)
        try FileManager.default.createDirectory(at: sourcesURL, withIntermediateDirectories: true)
        try Data("Hello\n".utf8).write(to: workspaceURL.appendingPathComponent("README.md"))
        try Data("secret\n".utf8).write(to: workspaceURL.appendingPathComponent(".hidden"))

        let thread = makeWorkspaceThread(workspaceURL: workspaceURL)
        let listing = try thread.listWorkspaceFiles()

        #expect(listing.workspacePath == workspaceURL.resolvingSymlinksInPath().path)
        #expect(listing.directoryRelativePath == ".")
        #expect(listing.entries.map(\.relativePath) == ["Sources", "README.md"])
        #expect(listing.entries[0].kind == .directory)
        #expect(listing.entries[1].kind == .file)
        #expect(listing.entries[1].byteCount == 6)
    }

    @Test("reads UTF-8 workspace files by relative and absolute path")
    func readsWorkspaceFilesByRelativeAndAbsolutePath() throws {
        let workspaceURL = try makeTemporaryWorkspace()
        defer { try? FileManager.default.removeItem(at: workspaceURL) }

        let readmeURL = workspaceURL.appendingPathComponent("README.md")
        try Data("Hello, workspace.\n".utf8).write(to: readmeURL)

        let thread = makeWorkspaceThread(workspaceURL: workspaceURL)
        let relativeRead = try thread.readWorkspaceFile(.init(path: "README.md"))
        let absoluteRead = try thread.readWorkspaceFile(.init(path: readmeURL.path))

        #expect(relativeRead.relativePath == "README.md")
        #expect(relativeRead.contents == "Hello, workspace.\n")
        #expect(relativeRead.byteCount == 18)
        #expect(absoluteRead == relativeRead)
    }

    @Test("rejects workspace file paths that escape the thread root")
    func rejectsWorkspaceFilePathsThatEscapeThreadRoot() throws {
        let workspaceURL = try makeTemporaryWorkspace()
        let outsideURL = try makeTemporaryWorkspace()
        defer {
            try? FileManager.default.removeItem(at: workspaceURL)
            try? FileManager.default.removeItem(at: outsideURL)
        }

        let outsideFileURL = outsideURL.appendingPathComponent("outside.txt")
        try Data("outside\n".utf8).write(to: outsideFileURL)
        try FileManager.default.createSymbolicLink(
            at: workspaceURL.appendingPathComponent("outside-link.txt"),
            withDestinationURL: outsideFileURL
        )

        let thread = makeWorkspaceThread(workspaceURL: workspaceURL)

        #expect(throws: CodexThread.WorkspaceFileError.self) {
            try thread.readWorkspaceFile(.init(path: "../outside.txt"))
        }
        #expect(throws: CodexThread.WorkspaceFileError.self) {
            try thread.readWorkspaceFile(.init(path: "outside-link.txt"))
        }
    }

    @Test("rejects non-text and oversized workspace file reads")
    func rejectsNonTextAndOversizedWorkspaceFileReads() throws {
        let workspaceURL = try makeTemporaryWorkspace()
        defer { try? FileManager.default.removeItem(at: workspaceURL) }

        try Data([0xff, 0xfe, 0xfd]).write(to: workspaceURL.appendingPathComponent("binary.dat"))
        try Data("too big\n".utf8).write(to: workspaceURL.appendingPathComponent("large.txt"))

        let thread = makeWorkspaceThread(workspaceURL: workspaceURL)

        #expect(throws: CodexThread.WorkspaceFileError.self) {
            try thread.readWorkspaceFile(.init(path: "binary.dat"))
        }
        #expect(throws: CodexThread.WorkspaceFileError.self) {
            try thread.readWorkspaceFile(.init(path: "large.txt", maximumBytes: 2))
        }
    }

    @Test("assigns unique hook diagnostic IDs when messages repeat")
    func assignsUniqueHookDiagnosticIDsWhenMessagesRepeat() {
        let entry = CodexAppServer.HookListEntry(
            currentDirectoryPath: "/tmp/project",
            errors: [
                .init(message: "Hook failed.", path: "/tmp/project/hook.sh"),
                .init(message: "Hook failed.", path: "/tmp/project/hook.sh"),
            ],
            hooks: [],
            warnings: [
                "Hook warning.",
                "Hook warning.",
            ]
        )

        #expect(Set(entry.diagnostics.map(\.id)).count == 4)
    }
}

private func makeTemporaryWorkspace() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makeWorkspaceThread(workspaceURL: URL) -> CodexThread {
    let workspacePath = workspaceURL.resolvingSymlinksInPath().path
    return CodexThread(
        appServer: CodexAppServer(transport: FakeCodexAppServerTransport()),
        session: .init(
            approvalPolicy: .onRequest,
            approvalsReviewer: .user,
            currentDirectoryPath: workspacePath,
            instructionSources: [],
            model: "gpt-5.4",
            modelProvider: "openai",
            reasoningEffort: .medium,
            sandboxPolicy: .init(
                type: .workspaceWrite,
                networkAccess: .enabled,
                excludeSlashTmp: nil,
                excludeTmpdirEnvVar: nil,
                writableRoots: [workspacePath]
            ),
            serviceTier: .fast,
            thread: .init(
                id: "thread-workspace-files",
                cliVersion: "0.128.0",
                createdAt: 1,
                currentDirectoryPath: workspacePath,
                ephemeral: false,
                forkedFromThreadID: nil,
                gitInfo: nil,
                modelProvider: "openai",
                name: nil,
                preview: "",
                status: .init(type: .idle, activeFlags: []),
                updatedAt: 1
            )
        ),
        events: AsyncThrowingStream { continuation in
            continuation.finish()
        }
    )
}
