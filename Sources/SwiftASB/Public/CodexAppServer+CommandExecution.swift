import Foundation

extension CodexAppServer {
    struct CommandExecRequest: Sendable, Equatable {
        var command: [String]
        var currentDirectoryPath: String?
        var environment: [String: String?]
        var outputBytesCap: Int?
        var timeoutMilliseconds: Int?

        init(
            command: [String],
            currentDirectoryPath: String? = nil,
            environment: [String: String?] = [:],
            outputBytesCap: Int? = nil,
            timeoutMilliseconds: Int? = nil
        ) {
            self.command = command
            self.currentDirectoryPath = currentDirectoryPath
            self.environment = environment
            self.outputBytesCap = outputBytesCap
            self.timeoutMilliseconds = timeoutMilliseconds
        }
    }

    struct CommandExecResult: Sendable, Equatable {
        var exitCode: Int
        var stdout: String
        var stderr: String
    }

}
