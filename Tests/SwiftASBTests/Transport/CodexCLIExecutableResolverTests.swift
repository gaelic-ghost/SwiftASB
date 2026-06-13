import Foundation
import Testing
@testable import SwiftASB

@Suite("CodexCLIExecutableResolver", .serialized)
struct CodexCLIExecutableResolverTests {
    @Test("prefers an explicit executable URL when configured")
    func prefersExplicitExecutableURL() throws {
        let explicitURL = URL(fileURLWithPath: "/tmp/codex-explicit")
        let recorder = CommandRecorder()

        let resolver = CodexCLIExecutableResolver(
            explicitExecutableURL: explicitURL,
            environment: nil,
            currentDirectoryURL: nil,
            runCommand: recorder.run,
            isExecutableFile: { $0 == explicitURL.path }
        )

        let resolution = try resolver.resolve()

        #expect(resolution.source == .explicit)
        #expect(resolution.launchExecutableURL == explicitURL)
        #expect(resolution.launchArgumentsPrefix.isEmpty)
        #expect(resolution.resolvedExecutableURL == explicitURL)
        #expect(resolution.versionString == "codex-cli 0.139.0")
        #expect(resolution.compatibility == .supported(documentedWindow: "0.139.x"))
        #expect(recorder.recordedInvocations == [
            .init(executablePath: explicitURL.path, arguments: ["--version"])
        ])
    }

    @Test("prefers PATH discovery before Homebrew and npm fallbacks")
    func prefersPathDiscovery() throws {
        let recorder = CommandRecorder()

        let resolver = CodexCLIExecutableResolver(
            explicitExecutableURL: nil,
            environment: nil,
            currentDirectoryURL: nil,
            runCommand: recorder.run,
            isExecutableFile: { _ in false }
        )

        let resolution = try resolver.resolve()

        #expect(resolution.source == .path)
        #expect(resolution.launchExecutableURL.path == "/usr/bin/env")
        #expect(resolution.launchArgumentsPrefix == ["codex"])
        #expect(resolution.resolvedExecutableURL == nil)
        #expect(resolution.compatibility == .supported(documentedWindow: "0.139.x"))
        #expect(recorder.recordedInvocations == [
            .init(executablePath: "/usr/bin/env", arguments: ["codex", "--version"])
        ])
    }

    @Test("falls back to the Apple Silicon Homebrew install path on macOS")
    func fallsBackToHomebrewAppleSiliconPath() throws {
        let recorder = CommandRecorder(
            pathVersionTerminationStatus: 1,
            pathVersionStandardError: "env: codex: No such file or directory"
        )
        let homebrewPath = "/opt/homebrew/bin/codex"

        let resolver = CodexCLIExecutableResolver(
            explicitExecutableURL: nil,
            environment: nil,
            currentDirectoryURL: nil,
            runCommand: recorder.run,
            isExecutableFile: { $0 == homebrewPath }
        )

        let resolution = try resolver.resolve()

        #expect(resolution.source == .homebrewAppleSilicon)
        #expect(resolution.launchExecutableURL.path == homebrewPath)
        #expect(resolution.launchArgumentsPrefix.isEmpty)
        #expect(resolution.resolvedExecutableURL?.path == homebrewPath)
        #expect(resolution.compatibility == .supported(documentedWindow: "0.139.x"))
        #expect(recorder.recordedInvocations == [
            .init(executablePath: "/usr/bin/env", arguments: ["codex", "--version"]),
            .init(executablePath: homebrewPath, arguments: ["--version"])
        ])
    }

    @Test("falls back to the npm global prefix when PATH and Homebrew are unavailable")
    func fallsBackToNPMGlobalPrefix() throws {
        let recorder = CommandRecorder(
            pathVersionTerminationStatus: 1,
            pathVersionStandardError: "env: codex: No such file or directory",
            npmPrefixOutput: "/Users/galew/.npm-global"
        )
        let npmCodexPath = "/Users/galew/.npm-global/bin/codex"

        let resolver = CodexCLIExecutableResolver(
            explicitExecutableURL: nil,
            environment: nil,
            currentDirectoryURL: nil,
            runCommand: recorder.run,
            isExecutableFile: { $0 == npmCodexPath }
        )

        let resolution = try resolver.resolve()

        #expect(resolution.source == .npmGlobal(prefix: "/Users/galew/.npm-global"))
        #expect(resolution.launchExecutableURL.path == npmCodexPath)
        #expect(resolution.launchArgumentsPrefix.isEmpty)
        #expect(resolution.resolvedExecutableURL?.path == npmCodexPath)
        #expect(resolution.compatibility == .supported(documentedWindow: "0.139.x"))
        #expect(recorder.recordedInvocations == [
            .init(executablePath: "/usr/bin/env", arguments: ["codex", "--version"]),
            .init(executablePath: "/usr/bin/env", arguments: ["npm", "prefix", "-g"]),
            .init(executablePath: npmCodexPath, arguments: ["--version"])
        ])
    }

    @Test("throws a descriptive discovery failure when no supported install path is usable")
    func throwsDescriptiveDiscoveryFailure() throws {
        let recorder = CommandRecorder(
            pathVersionTerminationStatus: 1,
            pathVersionStandardError: "env: codex: No such file or directory",
            npmPrefixTerminationStatus: 1,
            npmPrefixStandardError: "env: npm: No such file or directory"
        )

        let resolver = CodexCLIExecutableResolver(
            explicitExecutableURL: nil,
            environment: nil,
            currentDirectoryURL: nil,
            runCommand: recorder.run,
            isExecutableFile: { _ in false }
        )

        #expect(throws: CodexTransportError.self) {
            try resolver.resolve()
        }
    }

    @Test("marks supported versions inside the documented support window")
    func marksSupportedVersionsInsideSupportWindow() throws {
        let explicitURL = URL(fileURLWithPath: "/tmp/codex-explicit")
        let recorder = CommandRecorder(pathVersionStandardOutput: "codex-cli 0.139.3")

        let resolver = CodexCLIExecutableResolver(
            explicitExecutableURL: explicitURL,
            environment: nil,
            currentDirectoryURL: nil,
            runCommand: recorder.run,
            isExecutableFile: { $0 == explicitURL.path }
        )

        let resolution = try resolver.resolve()
        #expect(resolution.compatibility == .supported(documentedWindow: "0.139.x"))
    }

    @Test("marks older minor versions outside the documented support window")
    func marksOlderMinorVersionsOutsideSupportWindow() throws {
        let explicitURL = URL(fileURLWithPath: "/tmp/codex-explicit")
        let recorder = CommandRecorder(pathVersionStandardOutput: "codex-cli 0.128.9")

        let resolver = CodexCLIExecutableResolver(
            explicitExecutableURL: explicitURL,
            environment: nil,
            currentDirectoryURL: nil,
            runCommand: recorder.run,
            isExecutableFile: { $0 == explicitURL.path }
        )

        let resolution = try resolver.resolve()
        #expect(resolution.compatibility == .outsideDocumentedWindow(documentedWindow: "0.139.x"))
    }

    @Test("marks unparseable version strings as unknown format")
    func marksUnparseableVersionStringsAsUnknownFormat() throws {
        let explicitURL = URL(fileURLWithPath: "/tmp/codex-explicit")
        let recorder = CommandRecorder(pathVersionStandardOutput: "codex dev build")

        let resolver = CodexCLIExecutableResolver(
            explicitExecutableURL: explicitURL,
            environment: nil,
            currentDirectoryURL: nil,
            runCommand: recorder.run,
            isExecutableFile: { $0 == explicitURL.path }
        )

        let resolution = try resolver.resolve()
        #expect(resolution.compatibility == .unknownVersionFormat(documentedWindow: "0.139.x"))
    }
}

private final class CommandRecorder: @unchecked Sendable {
    struct Invocation: Equatable {
        let executablePath: String
        let arguments: [String]
    }

    private(set) var recordedInvocations: [Invocation] = []
    private let pathVersionTerminationStatus: Int32
    private let pathVersionStandardOutput: String
    private let pathVersionStandardError: String
    private let npmPrefixTerminationStatus: Int32
    private let npmPrefixOutput: String
    private let npmPrefixStandardError: String

    init(
        pathVersionTerminationStatus: Int32 = 0,
        pathVersionStandardOutput: String = "codex-cli 0.139.0",
        pathVersionStandardError: String = "",
        npmPrefixTerminationStatus: Int32 = 0,
        npmPrefixOutput: String = "/Users/galew/.npm-global",
        npmPrefixStandardError: String = ""
    ) {
        self.pathVersionTerminationStatus = pathVersionTerminationStatus
        self.pathVersionStandardOutput = pathVersionStandardOutput
        self.pathVersionStandardError = pathVersionStandardError
        self.npmPrefixTerminationStatus = npmPrefixTerminationStatus
        self.npmPrefixOutput = npmPrefixOutput
        self.npmPrefixStandardError = npmPrefixStandardError
    }

    func run(
        executableURL: URL,
        arguments: [String],
        environment _: [String: String]?,
        currentDirectoryURL _: URL?
    ) throws -> CodexCLIExecutableResolver.CommandResult {
        recordedInvocations.append(
            .init(
                executablePath: executableURL.path,
                arguments: arguments
            )
        )

        if executableURL.path == "/usr/bin/env", arguments == ["codex", "--version"] {
            return .init(
                terminationStatus: pathVersionTerminationStatus,
                standardOutput: pathVersionStandardOutput,
                standardError: pathVersionStandardError
            )
        }

        if executableURL.path == "/usr/bin/env", arguments == ["npm", "prefix", "-g"] {
            return .init(
                terminationStatus: npmPrefixTerminationStatus,
                standardOutput: npmPrefixOutput,
                standardError: npmPrefixStandardError
            )
        }

        return .init(
            terminationStatus: 0,
            standardOutput: pathVersionStandardOutput,
            standardError: pathVersionStandardError
        )
    }
}
