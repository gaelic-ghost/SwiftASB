import Foundation

internal struct CodexCLIExecutableResolver {
    internal struct Resolution: Sendable, Equatable {
        internal let launchExecutableURL: URL
        internal let launchArgumentsPrefix: [String]
        internal let resolvedExecutableURL: URL?
        internal let source: Source
        internal let versionString: String
        internal let compatibility: Compatibility
    }

    internal enum Source: Sendable, Equatable {
        case explicit
        case path
        case homebrewAppleSilicon
        case homebrewIntel
        case npmGlobal(prefix: String)
    }

    internal enum Compatibility: Sendable, Equatable {
        case supported(documentedWindow: String)
        case outsideDocumentedWindow(documentedWindow: String)
        case unknownVersionFormat(documentedWindow: String)
    }

    internal struct Version: Sendable, Equatable {
        internal let major: Int
        internal let minor: Int
        internal let patch: Int

        private static let regex = try! NSRegularExpression(pattern: #"(\d+)\.(\d+)\.(\d+)"#)
        internal static let latestSupportedPublicRelease = Version(major: 0, minor: 128, patch: 0)

        internal static var documentedWindowDescription: String {
            let latest = latestSupportedPublicRelease
            return "\(latest.major).\(latest.minor).x"
        }

        internal static func parse(from text: String) -> Version? {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges == 4 else {
                return nil
            }

            guard
                let majorRange = Range(match.range(at: 1), in: text),
                let minorRange = Range(match.range(at: 2), in: text),
                let patchRange = Range(match.range(at: 3), in: text),
                let major = Int(text[majorRange]),
                let minor = Int(text[minorRange]),
                let patch = Int(text[patchRange])
            else {
                return nil
            }

            return Version(major: major, minor: minor, patch: patch)
        }
    }

    internal struct CommandResult: Sendable, Equatable {
        internal let terminationStatus: Int32
        internal let standardOutput: String
        internal let standardError: String
    }

    internal typealias CommandRunner = @Sendable (
        _ executableURL: URL,
        _ arguments: [String],
        _ environment: [String: String]?,
        _ currentDirectoryURL: URL?
    ) throws -> CommandResult

    internal typealias ExecutableFileChecker = @Sendable (_ path: String) -> Bool

    private let explicitExecutableURL: URL?
    private let environment: [String: String]?
    private let currentDirectoryURL: URL?
    private let runCommand: CommandRunner
    private let isExecutableFile: ExecutableFileChecker

    internal init(
        explicitExecutableURL: URL?,
        environment: [String: String]?,
        currentDirectoryURL: URL?,
        runCommand: @escaping CommandRunner = Self.runProcess,
        isExecutableFile: @escaping ExecutableFileChecker = { FileManager.default.isExecutableFile(atPath: $0) }
    ) {
        self.explicitExecutableURL = explicitExecutableURL
        self.environment = environment
        self.currentDirectoryURL = currentDirectoryURL
        self.runCommand = runCommand
        self.isExecutableFile = isExecutableFile
    }

    internal func resolve() throws -> Resolution {
        if let explicitExecutableURL {
            return try resolveExplicitExecutable(at: explicitExecutableURL)
        }

        if let pathResolution = try resolvePathExecutable() {
            return pathResolution
        }

        if let homebrewAppleSiliconResolution = try resolveDirectExecutable(
            atPath: "/opt/homebrew/bin/codex",
            source: .homebrewAppleSilicon
        ) {
            return homebrewAppleSiliconResolution
        }

        if let homebrewIntelResolution = try resolveDirectExecutable(
            atPath: "/usr/local/bin/codex",
            source: .homebrewIntel
        ) {
            return homebrewIntelResolution
        }

        if let npmGlobalResolution = try resolveNPMGlobalExecutable() {
            return npmGlobalResolution
        }

        throw CodexTransportError.executableDiscoveryFailed(
            reason: """
            SwiftASB could not locate a usable `codex` executable. Checked the \
            configured executable URL, PATH via `codex --version`, Homebrew \
            install locations `/opt/homebrew/bin/codex` and \
            `/usr/local/bin/codex`, and the npm global prefix reported by \
            `npm prefix -g`.
            """
        )
    }

    private func resolveExplicitExecutable(at executableURL: URL) throws -> Resolution {
        guard isExecutableFile(executableURL.path) else {
            throw CodexTransportError.executableDiscoveryFailed(
                reason: """
                SwiftASB was configured to use the Codex executable at \
                \(executableURL.path), but that path does not exist or is not \
                executable.
                """
            )
        }

        let versionString = try probeVersion(
            launchExecutableURL: executableURL,
            launchArgumentsPrefix: [],
            description: executableURL.path
        )

        return Resolution(
            launchExecutableURL: executableURL,
            launchArgumentsPrefix: [],
            resolvedExecutableURL: executableURL,
            source: .explicit,
            versionString: versionString,
            compatibility: compatibility(for: versionString)
        )
    }

    private func resolvePathExecutable() throws -> Resolution? {
        let envURL = URL(fileURLWithPath: "/usr/bin/env")

        do {
            let versionString = try probeVersion(
                launchExecutableURL: envURL,
                launchArgumentsPrefix: ["codex"],
                description: "PATH lookup via /usr/bin/env codex"
            )

            return Resolution(
                launchExecutableURL: envURL,
                launchArgumentsPrefix: ["codex"],
                resolvedExecutableURL: nil,
                source: .path,
                versionString: versionString,
                compatibility: compatibility(for: versionString)
            )
        } catch let error as CodexTransportError {
            switch error {
            case .executableDiscoveryFailed:
                return nil
            default:
                throw error
            }
        }
    }

    private func resolveDirectExecutable(
        atPath path: String,
        source: Source
    ) throws -> Resolution? {
        guard isExecutableFile(path) else {
            return nil
        }

        let executableURL = URL(fileURLWithPath: path)
        let versionString = try probeVersion(
            launchExecutableURL: executableURL,
            launchArgumentsPrefix: [],
            description: path
        )

        return Resolution(
            launchExecutableURL: executableURL,
            launchArgumentsPrefix: [],
            resolvedExecutableURL: executableURL,
            source: source,
            versionString: versionString,
            compatibility: compatibility(for: versionString)
        )
    }

    private func resolveNPMGlobalExecutable() throws -> Resolution? {
        let envURL = URL(fileURLWithPath: "/usr/bin/env")
        let npmResult: CommandResult

        do {
            npmResult = try runCommand(
                envURL,
                ["npm", "prefix", "-g"],
                environment,
                currentDirectoryURL
            )
        } catch {
            return nil
        }

        guard npmResult.terminationStatus == 0 else {
            return nil
        }

        let prefix = npmResult.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard prefix.isEmpty == false else {
            return nil
        }

        let executablePath = URL(fileURLWithPath: prefix)
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("codex", isDirectory: false)
            .path

        guard let resolution = try resolveDirectExecutable(
            atPath: executablePath,
            source: .npmGlobal(prefix: prefix)
        ) else {
            return nil
        }

        return resolution
    }

    private func probeVersion(
        launchExecutableURL: URL,
        launchArgumentsPrefix: [String],
        description: String
    ) throws -> String {
        let commandResult: CommandResult

        do {
            commandResult = try runCommand(
                launchExecutableURL,
                launchArgumentsPrefix + ["--version"],
                environment,
                currentDirectoryURL
            )
        } catch {
            throw CodexTransportError.executableDiscoveryFailed(
                reason: "SwiftASB could not run `\(description) --version`: \(error)"
            )
        }

        guard commandResult.terminationStatus == 0 else {
            let errorText = commandResult.standardError
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let reason = errorText.isEmpty
                ? "`\(description) --version` exited with status \(commandResult.terminationStatus)."
                : errorText
            throw CodexTransportError.executableDiscoveryFailed(
                reason: "SwiftASB could not verify the Codex executable at \(description): \(reason)"
            )
        }

        let versionString = commandResult.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard versionString.isEmpty == false else {
            throw CodexTransportError.executableDiscoveryFailed(
                reason: "SwiftASB ran `\(description) --version`, but it returned an empty version string."
            )
        }

        return versionString
    }

    private func compatibility(for versionString: String) -> Compatibility {
        let documentedWindow = Version.documentedWindowDescription
        guard let parsedVersion = Version.parse(from: versionString) else {
            return .unknownVersionFormat(documentedWindow: documentedWindow)
        }

        let latest = Version.latestSupportedPublicRelease

        guard parsedVersion.major == latest.major else {
            return .outsideDocumentedWindow(documentedWindow: documentedWindow)
        }

        if parsedVersion.minor == latest.minor {
            return .supported(documentedWindow: documentedWindow)
        }

        return .outsideDocumentedWindow(documentedWindow: documentedWindow)
    }

    private static func runProcess(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?,
        currentDirectoryURL: URL?
    ) throws -> CommandResult {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()

        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = environment
        process.currentDirectoryURL = currentDirectoryURL
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()
        process.waitUntilExit()

        let output = String(
            decoding: standardOutput.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )
        let error = String(
            decoding: standardError.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )

        return CommandResult(
            terminationStatus: process.terminationStatus,
            standardOutput: output,
            standardError: error
        )
    }
}
