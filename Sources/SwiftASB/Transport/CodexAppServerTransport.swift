import Foundation

internal actor CodexAppServerTransport: CodexAppServerTransporting {
    internal struct Configuration: Equatable, Sendable {
        internal var codexExecutableURL: URL?
        internal var arguments: [String]
        internal var currentDirectoryURL: URL?
        internal var environment: [String: String]?

        internal init(
            codexExecutableURL: URL? = nil,
            arguments: [String] = ["app-server", "--listen", "stdio://"],
            currentDirectoryURL: URL? = nil,
            environment: [String: String]? = nil
        ) {
            self.codexExecutableURL = codexExecutableURL
            self.arguments = arguments
            self.currentDirectoryURL = currentDirectoryURL
            self.environment = environment
        }
    }

    private let configuration: Configuration

    private var process: Process?
    private var standardInputHandle: FileHandle?
    private var standardOutputTask: Task<Void, Never>?
    private var standardErrorTask: Task<Void, Never>?
    private var pendingResponses: [CodexRPCRequestID: CheckedContinuation<Data, Error>] = [:]
    private var serverEventContinuations: [UUID: AsyncStream<CodexRPCServerEvent>.Continuation] = [:]
    private var recentStandardErrorLines: [String] = []
    private var hasFinished = false

    internal init(configuration: Configuration = .init()) {
        self.configuration = configuration
    }

    internal func start() throws {
        guard process == nil else {
            throw CodexTransportError.alreadyStarted
        }

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let process = Process()

        if let explicitExecutableURL = configuration.codexExecutableURL {
            process.executableURL = explicitExecutableURL
            process.arguments = configuration.arguments
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["codex"] + configuration.arguments
        }

        process.currentDirectoryURL = configuration.currentDirectoryURL
        process.environment = configuration.environment
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.terminationHandler = { [weak self] process in
            Task {
                await self?.handleProcessTermination(process)
            }
        }

        do {
            try process.run()
        } catch {
            throw CodexTransportError.failedToLaunch(
                executable: process.executableURL?.path ?? "codex",
                reason: String(describing: error)
            )
        }

        self.process = process
        standardInputHandle = inputPipe.fileHandleForWriting
        hasFinished = false
        recentStandardErrorLines = []
        startStandardOutputLoop(fileHandle: outputPipe.fileHandleForReading)
        startStandardErrorLoop(fileHandle: errorPipe.fileHandleForReading)
    }

    internal func stop() {
        guard let process else { return }

        if process.isRunning {
            process.terminate()
        } else {
            finishTransport(
                with: .processTerminated(
                    reason: "stop() was called after the Codex app-server process had already exited.",
                    status: process.terminationStatus,
                    recentStandardError: recentStandardErrorLines
                )
            )
        }
    }

    internal func send(_ requestPayload: Data, id: CodexRPCRequestID) async throws -> Data {
        guard process != nil, let standardInputHandle else {
            throw CodexTransportError.notStarted
        }

        if pendingResponses[id] != nil {
            throw CodexTransportError.duplicatePendingRequest(id: id)
        }

        return try await withCheckedThrowingContinuation { continuation in
            pendingResponses[id] = continuation

            do {
                try writeFramedPayload(requestPayload, to: standardInputHandle)
            } catch {
                pendingResponses.removeValue(forKey: id)
                continuation.resume(
                    throwing: CodexTransportError.failedToWriteRequest(
                        id: id,
                        reason: String(describing: error)
                    )
                )
            }
        }
    }

    internal func sendNotification(_ notificationPayload: Data, method: String) throws {
        guard process != nil, let standardInputHandle else {
            throw CodexTransportError.notStarted
        }

        do {
            try writeFramedPayload(notificationPayload, to: standardInputHandle)
        } catch {
            throw CodexTransportError.failedToWriteNotification(
                method: method,
                reason: String(describing: error)
            )
        }
    }

    internal func serverEvents() -> AsyncStream<CodexRPCServerEvent> {
        let streamID = UUID()
        return AsyncStream { continuation in
            self.registerServerEventContinuation(continuation, id: streamID)
            continuation.onTermination = { _ in
                Task {
                    await self.removeServerEventContinuation(id: streamID)
                }
            }
        }
    }

    private func registerServerEventContinuation(
        _ continuation: AsyncStream<CodexRPCServerEvent>.Continuation,
        id: UUID
    ) {
        serverEventContinuations[id] = continuation
    }

    private func removeServerEventContinuation(id: UUID) {
        serverEventContinuations.removeValue(forKey: id)
    }

    private func startStandardOutputLoop(fileHandle: FileHandle) {
        standardOutputTask = Task {
            var bufferedLine = Data()
            do {
                for try await byte in fileHandle.bytes {
                    if byte == 0x0A {
                        handleStandardOutputDataLine(bufferedLine)
                        bufferedLine.removeAll(keepingCapacity: true)
                        continue
                    }

                    if byte == 0x0D {
                        continue
                    }

                    bufferedLine.append(byte)
                }

                if !bufferedLine.isEmpty {
                    handleStandardOutputDataLine(bufferedLine)
                }

                handleStandardOutputEOF()
            } catch {
                await finishTransport(
                    with: .processTerminated(
                        reason: "Reading Codex app-server stdout failed: \(String(describing: error))",
                        status: process?.terminationStatus,
                        recentStandardError: recentStandardErrorLines
                    )
                )
            }
        }
    }

    private func startStandardErrorLoop(fileHandle: FileHandle) {
        standardErrorTask = Task {
            var bufferedLine = Data()
            do {
                for try await byte in fileHandle.bytes {
                    if byte == 0x0A {
                        appendStandardErrorDataLine(bufferedLine)
                        bufferedLine.removeAll(keepingCapacity: true)
                        continue
                    }

                    if byte == 0x0D {
                        continue
                    }

                    bufferedLine.append(byte)
                }

                if !bufferedLine.isEmpty {
                    appendStandardErrorDataLine(bufferedLine)
                }
            } catch {
                appendStandardErrorLine(
                    "Reading Codex app-server stderr failed: \(String(describing: error))"
                )
            }
        }
    }

    private func handleStandardOutputLine(_ line: String) {
        let payload = Data(line.utf8)

        do {
            switch try CodexRPCEnvelope.classifyInboundMessage(payload) {
            case let .response(id, responsePayload):
                guard let continuation = pendingResponses.removeValue(forKey: id) else {
                    return
                }
                continuation.resume(returning: responsePayload)
            case let .serverEvent(event):
                broadcastServerEvent(event)
            }
        } catch let error as CodexTransportError {
            finishTransport(with: error)
        } catch {
            finishTransport(
                with: .invalidJSONRPCEnvelope(reason: String(describing: error))
            )
        }
    }

    private func handleStandardOutputDataLine(_ lineData: Data) {
        let line = String(decoding: lineData, as: UTF8.self)
        handleStandardOutputLine(line)
    }

    private func handleStandardOutputEOF() {
        guard !hasFinished else { return }
        finishTransport(with: .unexpectedEndOfStream(recentStandardError: recentStandardErrorLines))
    }

    private func appendStandardErrorLine(_ line: String) {
        recentStandardErrorLines.append(line)
        if recentStandardErrorLines.count > 20 {
            recentStandardErrorLines.removeFirst(recentStandardErrorLines.count - 20)
        }
    }

    private func appendStandardErrorDataLine(_ lineData: Data) {
        let line = String(decoding: lineData, as: UTF8.self)
        appendStandardErrorLine(line)
    }

    private func writeFramedPayload(_ payload: Data, to handle: FileHandle) throws {
        var framedPayload = payload
        framedPayload.append(0x0A)
        try handle.write(contentsOf: framedPayload)
    }

    private func broadcastServerEvent(_ event: CodexRPCServerEvent) {
        for continuation in serverEventContinuations.values {
            continuation.yield(event)
        }
    }

    private func handleProcessTermination(_ process: Process) {
        let reasonDescription: String
        switch process.terminationReason {
        case .exit:
            reasonDescription = "exit"
        case .uncaughtSignal:
            reasonDescription = "uncaught-signal"
        @unknown default:
            reasonDescription = "unknown"
        }

        finishTransport(
            with: .processTerminated(
                reason: reasonDescription,
                status: process.terminationStatus,
                recentStandardError: recentStandardErrorLines
            )
        )
    }

    private func finishTransport(with error: CodexTransportError) {
        guard !hasFinished else { return }
        hasFinished = true

        standardOutputTask?.cancel()
        standardErrorTask?.cancel()
        standardOutputTask = nil
        standardErrorTask = nil

        try? standardInputHandle?.close()
        standardInputHandle = nil

        process = nil

        let pending = pendingResponses.values
        pendingResponses.removeAll()
        for continuation in pending {
            continuation.resume(throwing: error)
        }

        for continuation in serverEventContinuations.values {
            continuation.finish()
        }
        serverEventContinuations.removeAll()
    }
}
