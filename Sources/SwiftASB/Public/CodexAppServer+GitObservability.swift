import Foundation

extension CodexAppServer {
    func refreshGitStatus(
        for worktree: CodexWorkspace.WorktreeSnapshot
    ) async throws -> CodexWorkspace.GitStatusSnapshot? {
        let cwd = worktree.currentDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cwd.isEmpty else { return nil }

        let commandFacts = try await (
            root: gitOutput(["rev-parse", "--show-toplevel"], cwd: cwd),
            sha: gitOutput(["rev-parse", "HEAD"], cwd: cwd),
            remotes: gitOutput(["remote", "-v"], cwd: cwd),
            status: gitOutput(["status", "--porcelain=v1", "--branch"], cwd: cwd)
        )

        let remotes = commandFacts.remotes.map(Self.parseGitRemotes) ?? []
        let status = commandFacts.status.map(Self.parseGitStatusSummary) ?? .init()
        let originURL = worktree.repository?.originURL
            ?? remotes.first { $0.name == "origin" && $0.purpose == .fetch }?.url
            ?? remotes.first { $0.name == "origin" }?.url
        let repository = CodexWorkspace.RepositoryInfo(
            originURL: originURL,
            branch: worktree.repository?.branch ?? status.branch,
            sha: worktree.repository?.sha ?? commandFacts.sha
        )
        let commandReturnedFacts = commandFacts.root != nil
            || commandFacts.sha != nil
            || commandFacts.remotes != nil
            || commandFacts.status != nil
        let source = Self.gitFactSource(
            hasAppServerFacts: worktree.hasRepositoryFacts,
            hasCommandExecFacts: commandReturnedFacts
        )

        return .init(
            worktreeID: worktree.id,
            currentDirectoryPath: cwd,
            repositoryRootPath: commandFacts.root,
            repository: repository,
            remotes: remotes,
            status: status,
            source: source
        )
    }

    private func gitOutput(_ arguments: [String], cwd: String) async throws -> String? {
        let result = try await executeCommand(
            .init(
                command: ["git", "-C", cwd] + arguments,
                outputBytesCap: 65536,
                timeoutMilliseconds: 5000
            )
        )
        guard result.exitCode == 0 else {
            return nil
        }

        return CodexWorkspace.RepositoryInfo.normalizedFact(result.stdout)
    }

    private static func gitFactSource(
        hasAppServerFacts: Bool,
        hasCommandExecFacts: Bool
    ) -> CodexWorkspace.GitFactSource {
        switch (hasAppServerFacts, hasCommandExecFacts) {
            case (true, true):
                return .appServerAndCommandExec
            case (true, false):
                return .appServer
            case (false, _):
                return .commandExec
        }
    }

    private static func parseGitRemotes(_ output: String) -> [CodexWorkspace.GitRemoteInfo] {
        var remotes: [CodexWorkspace.GitRemoteInfo] = []
        var seen: Set<String> = []

        for line in output.split(whereSeparator: \.isNewline) {
            let columns = line.split(whereSeparator: \.isWhitespace)
            guard columns.count >= 2 else { continue }

            let name = String(columns[0])
            let url = String(columns[1])
            let purpose = columns.dropFirst(2).first.map(String.init).map(Self.remotePurpose) ?? .unknown
            let key = "\(name)||\(url)||\(purpose.rawValue)"
            guard seen.insert(key).inserted else { continue }

            remotes.append(.init(name: name, url: url, purpose: purpose))
        }

        return remotes
    }

    private static func remotePurpose(_ marker: String) -> CodexWorkspace.GitRemoteInfo.Purpose {
        switch marker {
            case "(fetch)":
                return .fetch
            case "(push)":
                return .push
            default:
                return .unknown
        }
    }

    private static func parseGitStatusSummary(_ output: String) -> CodexWorkspace.GitStatusSummary {
        let lines = output.split(whereSeparator: \.isNewline).map(String.init)
        let branchLine = lines.first { $0.hasPrefix("## ") }
        let changedLines = lines.filter { !$0.hasPrefix("## ") && !$0.isEmpty }
        let untrackedCount = changedLines.filter { $0.hasPrefix("?? ") }.count
        let branchStatus = branchLine.map(parseGitBranchStatus)

        return .init(
            branch: branchStatus?.branch,
            upstream: branchStatus?.upstream,
            aheadCount: branchStatus?.aheadCount,
            behindCount: branchStatus?.behindCount,
            changedFileCount: changedLines.count,
            untrackedFileCount: untrackedCount
        )
    }

    private static func parseGitBranchStatus(
        _ line: String
    ) -> (
        branch: String?,
        upstream: String?,
        aheadCount: Int?,
        behindCount: Int?
    ) {
        let trimmed = String(line.dropFirst(3))
        let branchAndTracking = trimmed.split(separator: " ", maxSplits: 1).first.map(String.init) ?? trimmed
        let split = splitBranchAndUpstream(branchAndTracking)
        let branch = CodexWorkspace.RepositoryInfo.normalizedFact(split.branch)
        let upstream = CodexWorkspace.RepositoryInfo.normalizedFact(split.upstream)

        return (
            branch: branch == "HEAD" ? nil : branch,
            upstream: upstream,
            aheadCount: trackingCount(named: "ahead", in: trimmed),
            behindCount: trackingCount(named: "behind", in: trimmed)
        )
    }

    private static func trackingCount(named name: String, in text: String) -> Int? {
        guard let range = text.range(of: "\(name) ") else { return nil }

        let suffix = text[range.upperBound...]
        let digits = suffix.prefix { $0.isNumber }
        return digits.isEmpty ? nil : Int(digits)
    }

    private static func splitBranchAndUpstream(_ text: String) -> (branch: String?, upstream: String?) {
        guard let range = text.range(of: "...") else {
            return (text, nil)
        }

        return (
            String(text[..<range.lowerBound]),
            String(text[range.upperBound...])
        )
    }
}
