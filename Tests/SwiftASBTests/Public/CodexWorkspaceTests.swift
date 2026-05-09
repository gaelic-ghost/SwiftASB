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

    @Test("worktree snapshot ignores blank Git facts")
    func worktreeSnapshotIgnoresBlankGitFacts() {
        let snapshot = CodexWorkspace.WorktreeSnapshot(
            currentDirectoryPath: "/tmp/blank-git",
            repository: .init(
                originURL: "   ",
                branch: "\n\t",
                sha: ""
            )
        )

        #expect(snapshot.id == "/tmp/blank-git")
        #expect(snapshot.identitySource == .currentDirectory)
        #expect(snapshot.repository == nil)
        #expect(!snapshot.hasRepositoryFacts)
    }

    @Test("Git status snapshot preserves root remotes and dirty summary")
    func gitStatusSnapshotPreservesRootRemotesAndDirtySummary() {
        let snapshot = CodexWorkspace.GitStatusSnapshot(
            worktreeID: "https://github.com/gaelic-ghost/SwiftASB.git",
            currentDirectoryPath: "/tmp/SwiftASB",
            repositoryRootPath: "/tmp/SwiftASB",
            repository: .init(
                originURL: "https://github.com/gaelic-ghost/SwiftASB.git",
                branch: "docs/feature-permission-plan",
                sha: "abcdef1234567890"
            ),
            remotes: [
                .init(
                    name: "origin",
                    url: "https://github.com/gaelic-ghost/SwiftASB.git",
                    purpose: .fetch
                ),
            ],
            status: .init(
                branch: "docs/feature-permission-plan",
                upstream: "origin/docs/feature-permission-plan",
                aheadCount: 1,
                changedFileCount: 2,
                untrackedFileCount: 1
            ),
            source: .appServerAndCommandExec
        )

        #expect(snapshot.id == "https://github.com/gaelic-ghost/SwiftASB.git")
        #expect(snapshot.repositoryRootPath == "/tmp/SwiftASB")
        #expect(snapshot.repository?.shortSHA == "abcdef123456")
        #expect(snapshot.remotes.map(\.name) == ["origin"])
        #expect(snapshot.status.upstream == "origin/docs/feature-permission-plan")
        #expect(snapshot.status.aheadCount == 1)
        #expect(snapshot.status.changedFileCount == 2)
        #expect(snapshot.status.untrackedFileCount == 1)
        #expect(snapshot.isDirty)
        #expect(snapshot.source == .appServerAndCommandExec)
    }

    @Test("Git status summary treats untracked-only worktrees as dirty")
    func gitStatusSummaryTreatsUntrackedOnlyWorktreesAsDirty() {
        let status = CodexWorkspace.GitStatusSummary(
            branch: "main",
            changedFileCount: 0,
            untrackedFileCount: 2
        )

        #expect(status.isDirty)
    }
}
