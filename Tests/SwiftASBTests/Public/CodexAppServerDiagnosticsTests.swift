import Foundation
@testable import SwiftASB
import Testing

extension CodexAppServerTests {
    @MainActor
    @Test("streams diagnostics through app, thread, and turn public surfaces")
    func streamsDiagnosticsThroughPublicSurfaces() async throws {
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

        let thread = try await client.startThread(
            .init(
                currentDirectoryPath: "/tmp/project",
                model: "gpt-5.4",
                modelProvider: "openai"
            )
        )
        let turnHandle = try await thread.startTextTurn("Trigger diagnostic surfaces.")
        let dashboard = await thread.makeDashboard()
        let minimap = turnHandle.minimap

        let appDiagnosticsTask = Task {
            try await diagnosticEvents(from: await client.diagnosticEvents(), count: 4)
        }
        let threadEventsTask = Task {
            try await threadEvents(from: thread.events, count: 4)
        }
        let turnEventsTask = Task {
            try await turnEvents(from: turnHandle.events, count: 2)
        }

        for _ in 0..<5 {
            await Task.yield()
        }

        await transport.emitWarning(threadID: thread.id)
        await transport.emitGuardianWarning(threadID: thread.id)
        await transport.emitModelRerouted(threadID: thread.id, turnID: turnHandle.turn.id)
        await transport.emitModelVerification(threadID: thread.id, turnID: turnHandle.turn.id)

        let appDiagnostics = try await appDiagnosticsTask.value
        #expect(appDiagnostics.count == 4)
        #expect(appDiagnostics.map(\.threadID) == [thread.id, thread.id, thread.id, thread.id])
        #expect(appDiagnostics.map(\.turnID) == [nil, nil, turnHandle.turn.id, turnHandle.turn.id])

        let receivedThreadEvents = try await threadEventsTask.value
        #expect(receivedThreadEvents.count == 4)
        guard receivedThreadEvents.count == 4 else {
            await client.stop()
            return
        }

        switch receivedThreadEvents[0] {
            case let .diagnostic(.warning(warning)):
                #expect(warning.threadID == thread.id)
                #expect(warning.message == "Runtime configuration is using a fallback.")
            default:
                Issue.record("Expected the first thread diagnostic to be a runtime warning.")
        }

        switch receivedThreadEvents[1] {
            case let .diagnostic(.guardianWarning(warning)):
                #expect(warning.threadID == thread.id)
                #expect(warning.message == "Guardian flagged this session for review.")
            default:
                Issue.record("Expected the second thread diagnostic to be a guardian warning.")
        }

        switch receivedThreadEvents[2] {
            case let .diagnostic(.modelRerouted(reroute)):
                #expect(reroute.threadID == thread.id)
                #expect(reroute.turnID == turnHandle.turn.id)
                #expect(reroute.fromModel == "gpt-5.4")
                #expect(reroute.toModel == "gpt-5.4-safe")
                #expect(reroute.reason == CodexModelReroute.Reason.highRiskCyberActivity)
            default:
                Issue.record("Expected the third thread diagnostic to be a model reroute.")
        }

        switch receivedThreadEvents[3] {
            case let .diagnostic(.modelVerification(verification)):
                #expect(verification.threadID == thread.id)
                #expect(verification.turnID == turnHandle.turn.id)
                #expect(verification.verifications == [CodexModelVerification.trustedAccessForCyber])
            default:
                Issue.record("Expected the fourth thread diagnostic to be a model verification.")
        }

        let receivedTurnEvents = try await turnEventsTask.value
        #expect(receivedTurnEvents.count == 2)
        guard receivedTurnEvents.count == 2 else {
            await client.stop()
            return
        }

        switch receivedTurnEvents[0] {
            case let .diagnostic(.modelRerouted(reroute)):
                #expect(reroute.threadID == thread.id)
                #expect(reroute.turnID == turnHandle.turn.id)
            default:
                Issue.record("Expected the first turn diagnostic to be a model reroute.")
        }

        switch receivedTurnEvents[1] {
            case let .diagnostic(.modelVerification(verification)):
                #expect(verification.threadID == thread.id)
                #expect(verification.turnID == turnHandle.turn.id)
                #expect(verification.verifications == [CodexModelVerification.trustedAccessForCyber])
            default:
                Issue.record("Expected the second turn diagnostic to be a model verification.")
        }

        await waitForObservableState {
            if case .modelVerification = dashboard.latestDiagnostic,
               case .modelVerification = minimap.latestDiagnostic {
                return dashboard.latestDiagnostic?.turnID == turnHandle.turn.id
                    && minimap.latestDiagnostic?.turnID == turnHandle.turn.id
            }
            return false
        }

        switch dashboard.latestDiagnostic {
            case let .modelVerification(verification):
                #expect(verification.threadID == thread.id)
                #expect(verification.turnID == turnHandle.turn.id)
            default:
                Issue.record("Expected the thread dashboard to retain the latest model verification diagnostic.")
        }

        switch minimap.latestDiagnostic {
            case let .modelVerification(verification):
                #expect(verification.threadID == thread.id)
                #expect(verification.turnID == turnHandle.turn.id)
            default:
                Issue.record("Expected the turn minimap to retain the latest model verification diagnostic.")
        }

        await client.stop()
    }

    @Test("streams app-wide diagnostics without a thread target")
    func streamsAppWideDiagnosticsWithoutThreadTarget() async throws {
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

        let appDiagnosticsTask = Task {
            try await diagnosticEvents(from: await client.diagnosticEvents(), count: 1)
        }

        for _ in 0..<5 {
            await Task.yield()
        }

        await transport.emitWarning(threadID: nil, message: "Global configuration warning.")

        let appDiagnostics = try await appDiagnosticsTask.value
        #expect(appDiagnostics.count == 1)

        switch appDiagnostics.first {
            case let .warning(warning):
                #expect(warning.threadID == nil)
                #expect(warning.message == "Global configuration warning.")
            default:
                Issue.record("Expected an app-wide runtime warning diagnostic.")
        }

        await client.stop()
    }

    @Test("keeps MCP status diagnostics app-wide even when the wire payload names a thread")
    func keepsMcpStatusDiagnosticsAppWideWhenWireNamesThread() async throws {
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

        let appDiagnosticsTask = Task {
            try await diagnosticEvents(from: await client.diagnosticEvents(), count: 1)
        }

        for _ in 0..<5 {
            await Task.yield()
        }

        await transport.emitMcpServerStatusUpdated(threadID: "thread-123")

        let appDiagnostics = try await appDiagnosticsTask.value
        #expect(appDiagnostics.count == 1)

        switch appDiagnostics.first {
            case let .mcpServerStatusChanged(diagnostic):
                #expect(diagnostic.name == "calendar")
                #expect(diagnostic.status == .ready)
                #expect(appDiagnostics.first?.threadID == nil)
                #expect(appDiagnostics.first?.turnID == nil)
            default:
                Issue.record("Expected an app-wide MCP server status diagnostic.")
        }

        await client.stop()
    }

    @Test("finishes diagnostics stream when server-event decoding fails")
    func finishesDiagnosticsStreamWhenServerEventDecodingFails() async throws {
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

        let nextDiagnosticTask = Task {
            try await nextDiagnosticEventOrEnd(from: await client.diagnosticEvents())
        }

        for _ in 0..<5 {
            await Task.yield()
        }

        await transport.emitMalformedModelRerouted()

        do {
            _ = try await nextDiagnosticTask.value
            Issue.record("Expected diagnostics stream to finish with a server-event decoding error.")
        } catch {
            #expect(String(describing: error).contains("server events"))
        }

        await client.stop()
    }
}
