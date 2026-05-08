import Testing
@testable import SwiftASB

@Suite("Codex workspace facts")
struct CodexWorkspaceTests {
    @Test("worktree snapshot uses Codex-reported Git origin when available")
    func worktreeSnapshotUsesGitOriginWhenAvailable() {
        let repository = CodexWorkspace.RepositoryInfo(
            originURL: "https://github.com/gaelic-ghost/SwiftASB.git",
            branch: "workspace/git-facts",
            sha: "abcdef1234567890"
        )
        let snapshot = CodexWorkspace.WorktreeSnapshot(
            currentDirectoryPath: "/tmp/SwiftASB-wt",
            repository: repository
        )

        #expect(snapshot.id == "https://github.com/gaelic-ghost/SwiftASB.git")
        #expect(snapshot.identitySource == .gitOrigin)
        #expect(snapshot.displayName == "SwiftASB (github.com)")
        #expect(snapshot.currentDirectoryPath == "/tmp/SwiftASB-wt")
        #expect(snapshot.repository?.branch == "workspace/git-facts")
        #expect(snapshot.repository?.shortSHA == "abcdef123456")
        #expect(snapshot.hasRepositoryFacts)
    }

    @Test("worktree snapshot falls back to Codex-reported cwd without Git facts")
    func worktreeSnapshotFallsBackToCurrentDirectoryWithoutGitFacts() {
        let snapshot = CodexWorkspace.WorktreeSnapshot(
            currentDirectoryPath: "/tmp/standalone",
            repository: .init()
        )

        #expect(snapshot.id == "/tmp/standalone")
        #expect(snapshot.identitySource == .currentDirectory)
        #expect(snapshot.displayName == "/tmp/standalone")
        #expect(snapshot.repository == nil)
        #expect(!snapshot.hasRepositoryFacts)
    }
}
