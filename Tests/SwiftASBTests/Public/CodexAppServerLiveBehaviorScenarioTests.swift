import Foundation
import CryptoKit
import Testing
@testable import SwiftASB

extension CodexAppServerLiveIntegrationTests {
    @Test(
        "records live approval, sandbox, history, and diagnostics behavior matrix",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_BEHAVIOR_MATRIX_TESTS"] == "1",
            "Requires explicit opt-in because this test launches the local Codex CLI and records observational runtime behavior."
        ),
        .timeLimit(.minutes(8))
    )
    func recordsLiveBehaviorMatrix() async throws {
        let harness = try LiveCodexHarness(configMode: .approvalProbe)
        defer { harness.cleanup() }

        let readFixtureURL = harness.approvalProbeWorkspace
            .appendingPathComponent("behavior-matrix-read.txt", isDirectory: false)
        let readFixtureText = "behavior-matrix-\(UUID().uuidString)\n"
        try Data(readFixtureText.utf8).write(to: readFixtureURL)
        let expectedDigest = Data(SHA256.hash(data: Data(readFixtureText.utf8))).map {
            String(format: "%02x", $0)
        }.joined()

        let untrustedCreateURL = harness.approvalProbeWorkspace
            .appendingPathComponent("behavior-matrix-untrusted-create.txt", isDirectory: false)
        let granularCreateURL = harness.approvalProbeWorkspace
            .appendingPathComponent("behavior-matrix-granular-create.txt", isDirectory: false)

        let client = try await makeInitializedLiveClient(using: harness, experimentalAPI: true)
        do {
            let cases = [
                LiveBehaviorMatrixCase(
                    label: "never-text-only",
                    approvalPolicy: .never,
                    sandboxMode: .workspaceWrite,
                    prompt: prompt(label: "BEHAVIOR_MATRIX_NEVER_DONE"),
                    expectedFinalText: "BEHAVIOR_MATRIX_NEVER_DONE",
                    inspectedPath: nil
                ),
                LiveBehaviorMatrixCase(
                    label: "on-request-command-read",
                    approvalPolicy: .onRequest,
                    sandboxMode: .workspaceWrite,
                    prompt: """
                    Use a shell command to print the SHA-256 digest of behavior-matrix-read.txt in the
                    current working directory, then reply with exactly this text and nothing else:
                    \(expectedDigest)
                    """,
                    expectedFinalText: expectedDigest,
                    inspectedPath: readFixtureURL
                ),
                LiveBehaviorMatrixCase(
                    label: "untrusted-file-create",
                    approvalPolicy: .untrusted,
                    sandboxMode: .workspaceWrite,
                    prompt: """
                    Create behavior-matrix-untrusted-create.txt with exactly this content:
                    created by behavior matrix

                    Then reply with exactly BEHAVIOR_MATRIX_UNTRUSTED_CREATE_DONE and nothing else.
                    """,
                    expectedFinalText: "BEHAVIOR_MATRIX_UNTRUSTED_CREATE_DONE",
                    inspectedPath: untrustedCreateURL
                ),
                LiveBehaviorMatrixCase(
                    label: "granular-read-only-write-candidate",
                    approvalPolicy: .granular(
                        .init(
                            mcpElicitations: false,
                            requestPermissions: true,
                            rules: true,
                            sandboxApproval: true
                        )
                    ),
                    sandboxMode: .readOnly,
                    prompt: """
                    Create behavior-matrix-granular-create.txt with exactly this content:
                    created from read-only granular behavior matrix

                    Then reply with exactly BEHAVIOR_MATRIX_GRANULAR_CREATE_DONE and nothing else.
                    """,
                    expectedFinalText: "BEHAVIOR_MATRIX_GRANULAR_CREATE_DONE",
                    inspectedPath: granularCreateURL
                ),
            ]

            var caseResults: [LiveBehaviorMatrixReport.PolicySandboxResult] = []
            for matrixCase in cases {
                caseResults.append(
                    await runBehaviorMatrixCase(
                        matrixCase,
                        on: client,
                        harness: harness
                    )
                )
            }

            let history = await probeLiveHistoryMatrix(on: client, harness: harness)
            let sameThread = await probeLiveSameThreadMatrix(on: client, harness: harness)
            let diagnostics = await probeLiveCLIDiagnosticsMatrix(on: client)
            let report = LiveBehaviorMatrixReport(
                codexConfig: harness.codexConfigSummary,
                workspacePath: harness.approvalProbeWorkspace.path,
                policySandboxResults: caseResults,
                history: history,
                sameThread: sameThread,
                cliDiagnostics: diagnostics
            )
            try harness.writeReport(report, fileName: "live-behavior-matrix.json")

            #expect(caseResults.map(\.label) == cases.map(\.label))
            #expect(history.ephemeralRecentTurns != nil || history.errorDescription != nil)
            #expect(sameThread.outcome.isEmpty == false)
            #expect(diagnostics.versionString.isEmpty == false || diagnostics.errorDescription != nil)

            await client.stop()
        } catch {
            await client.stop()
            throw error
        }
    }

    @Test(
        "records live server-request family coverage status",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_SERVER_REQUEST_TESTS"] == "1",
            "Requires explicit opt-in because this test records live Codex server-request coverage status."
        )
    )
    func recordsLiveServerRequestFamilyCoverageStatus() throws {
        let harness = try LiveCodexHarness(configMode: .approvalProbe)
        defer { harness.cleanup() }

        let report = LiveServerRequestFamilyCoverageReport(
            codexConfig: harness.codexConfigSummary,
            families: [
                .init(
                    family: "commandExecutionApproval",
                    publicSurface: "CodexTurnHandle.respond(to:with:)",
                    deterministicFakeTransportCoverage: true,
                    liveProbeCoverage: true,
                    liveProbeScript: "scripts/run-live-codex-approval-probe.sh",
                    status: "covered",
                    notes: "The focused approval probe drives the real app-server with a mock Responses shell_command call and asserts request delivery, response, serverRequest/resolved, command completion, and terminal turn completion."
                ),
                .init(
                    family: "permissionsApproval",
                    publicSurface: "CodexTurnHandle.respond(to:with:)",
                    deterministicFakeTransportCoverage: true,
                    liveProbeCoverage: true,
                    liveProbeScript: "scripts/run-live-codex-approval-probe.sh",
                    status: "covered",
                    notes: "The focused approval probe drives the real app-server with request_permissions_tool enabled and asserts the permissions request, response, serverRequest/resolved, and terminal turn completion."
                ),
                .init(
                    family: "toolUserInput",
                    publicSurface: "CodexTurnHandle.respond(to:with:)",
                    deterministicFakeTransportCoverage: true,
                    liveProbeCoverage: true,
                    liveProbeScript: "scripts/run-live-codex-server-request-probes.sh",
                    status: "covered",
                    notes: "The focused server-request probe drives the real app-server with a mock Responses request_user_input call in plan collaboration mode and asserts request delivery, response, serverRequest/resolved, and terminal turn completion."
                ),
                .init(
                    family: "mcpServerElicitation",
                    publicSurface: "CodexThread.respond(to:with:) when turnId is null; CodexTurnHandle.respond(to:with:) when turn-routed",
                    deterministicFakeTransportCoverage: true,
                    liveProbeCoverage: true,
                    liveProbeScript: "scripts/run-live-codex-server-request-probes.sh",
                    status: "covered",
                    notes: "The focused server-request probe drives an app-connector MCP fixture through the real app-server and asserts MCP tool-call delivery, mcpServer/elicitation/request delivery, SwiftASB's JSON-RPC response, serverRequest/resolved, and terminal turn completion. The regular stdio fixture remains available as an explicitly opted-in observational probe, but app-connector MCP is the deterministic elicitation path."
                ),
            ],
            sourceNotes: [
                "OpenAI app-server docs describe item/tool/requestUserInput as a server-originated request that resolves with serverRequest/resolved.",
                "OpenAI app-server docs describe mcpServer/elicitation/request as an MCP-server-originated structured input request that resolves with serverRequest/resolved.",
            ]
        )

        try harness.writeReport(report, fileName: "live-server-request-family-coverage.json")
        #expect(report.families.count == 4)
        #expect(report.families.filter(\.liveProbeCoverage).map(\.family) == [
            "commandExecutionApproval",
            "permissionsApproval",
            "toolUserInput",
            "mcpServerElicitation",
        ])
    }

    @Test(
        "runs a multi-turn live file mutation scenario",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_FILE_SCENARIO_TESTS"] == "1",
            "Requires explicit opt-in because this test launches the local Codex CLI and asks it to mutate files."
        ),
        .timeLimit(.minutes(5))
    )
    func runsMultiTurnLiveFileMutationScenario() async throws {
        let harness = try LiveCodexHarness()
        defer { harness.cleanup() }

        let scratchURL = harness.fileScenarioWorkspace.appendingPathComponent("scratch.txt")
        let auditURL = harness.fileScenarioWorkspace.appendingPathComponent("audit.txt")

        let client = try await makeInitializedLiveClient(using: harness)
        do {
            let thread = try await startThread(
                on: client,
                workspacePath: harness.fileScenarioWorkspace.path,
                label: "file-mutation-scenario",
                approvalPolicy: .onRequest,
                approvalsReviewer: .user,
                ephemeral: false,
                developerInstructions: """
                You are running inside a SwiftASB live integration test.
                Make only the exact filesystem change requested by the user.
                Stay inside the current working directory.
                If approval is requested, wait for the test harness to answer it.
                Do not ask follow-up questions.
                After the requested filesystem change succeeds, reply with exactly FILE_SCENARIO_DONE and nothing else.
                """
            )

            let createTurn = try await startTurn(
                on: thread,
                prompt: """
                Create scratch.txt with exactly this content:
                alpha

                Then reply with exactly FILE_SCENARIO_DONE and nothing else.
                """,
                approvalPolicy: .onRequest,
                approvalsReviewer: .user
            )
            let createResult = try await completeLiveTurnAcceptingApprovals(
                createTurn,
                timeoutSeconds: 90,
                operation: "waiting for the live file scenario create turn to complete"
            )
            #expect(createResult.completion.turn.status == .completed)
            #expect(FileManager.default.fileExists(atPath: scratchURL.path))

            let recentFiles = try await thread.makeRecentFiles(limit: 10)
            let recentCommands = try await thread.makeRecentCommands(limit: 10)

            let editTurn = try await startTurn(
                on: thread,
                prompt: """
                Replace scratch.txt with exactly this content:
                alpha
                beta

                Then reply with exactly FILE_SCENARIO_DONE and nothing else.
                """,
                approvalPolicy: .onRequest,
                approvalsReviewer: .user
            )
            let editResult = try await completeLiveTurnAcceptingApprovals(
                editTurn,
                timeoutSeconds: 90,
                operation: "waiting for the live file scenario edit turn to complete"
            )
            #expect(editResult.completion.turn.status == .completed)
            #expect(FileManager.default.fileExists(atPath: scratchURL.path))

            let deleteTurn = try await startTurn(
                on: thread,
                prompt: """
                Delete scratch.txt.
                Create audit.txt with exactly this content:
                deleted scratch.txt

                Then reply with exactly FILE_SCENARIO_DONE and nothing else.
                """,
                approvalPolicy: .onRequest,
                approvalsReviewer: .user
            )
            let deleteResult = try await completeLiveTurnAcceptingApprovals(
                deleteTurn,
                timeoutSeconds: 90,
                operation: "waiting for the live file scenario delete turn to complete"
            )
            #expect(deleteResult.completion.turn.status == .completed)
            #expect(FileManager.default.fileExists(atPath: scratchURL.path) == false)
            #expect(try String(contentsOf: auditURL, encoding: .utf8) == "deleted scratch.txt\n")

            let observedCalls = createResult.callSnapshots + editResult.callSnapshots + deleteResult.callSnapshots
            #expect(observedCalls.contains { $0.kind == .fileEdit || $0.kind == .command })

            let fileSnapshots = await MainActor.run { recentFiles.files }
            let commandSnapshots = await MainActor.run { recentCommands.commands }
            #expect(fileSnapshots.isEmpty == false || commandSnapshots.isEmpty == false)

            let report = LiveFileMutationScenarioReport(
                threadID: thread.id,
                workspacePath: harness.fileScenarioWorkspace.path,
                turns: [
                    createResult.reportTurn(label: "create"),
                    editResult.reportTurn(label: "edit"),
                    deleteResult.reportTurn(label: "delete"),
                ],
                finalFiles: [
                    .init(
                        path: scratchURL.lastPathComponent,
                        exists: FileManager.default.fileExists(atPath: scratchURL.path),
                        contents: nil
                    ),
                    .init(
                        path: auditURL.lastPathComponent,
                        exists: FileManager.default.fileExists(atPath: auditURL.path),
                        contents: try String(contentsOf: auditURL, encoding: .utf8)
                    ),
                ],
                recentFiles: fileSnapshots.map(LiveFileMutationScenarioReport.RecentFile.init),
                recentCommands: commandSnapshots.map(LiveFileMutationScenarioReport.RecentCommand.init)
            )
            #expect(report.turns.allSatisfy { $0.status == "completed" })
            #expect(report.finalFiles.contains { $0.path == "scratch.txt" && $0.exists == false })
            #expect(report.finalFiles.contains { $0.path == "audit.txt" && $0.contents == "deleted scratch.txt\n" })
            try harness.writeReport(report, fileName: "live-file-mutation-scenario.json")

            await client.stop()
        } catch {
            await client.stop()
            throw error
        }
    }

    @Test(
        "probes live same-thread overlapping turn behavior",
        .enabled(
            if: ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_TESTS"] == "1"
                || ProcessInfo.processInfo.environment["SWIFTASB_ENABLE_LIVE_CODEX_SAME_THREAD_TESTS"] == "1",
            "Requires explicit opt-in because this test launches the local Codex CLI."
        ),
        .timeLimit(.minutes(2))
    )
    func probesLiveSameThreadOverlappingTurnBehavior() async throws {
        let harness = try LiveCodexHarness()
        defer { harness.cleanup() }

        let client = try await makeInitializedLiveClient(using: harness)
        do {
            let sharedThread = try await startThread(
                on: client,
                workspacePath: harness.sameThreadWorkspace.path,
                label: "same-thread"
            )

            let firstSameThreadTurn = try await startTurn(
                on: sharedThread,
                prompt: prompt(label: "SAME_THREAD_FIRST_DONE")
            )

            let secondSameThreadOutcome = await startSecondSameThreadTurn(
                on: sharedThread,
                prompt: prompt(label: "SAME_THREAD_SECOND_DONE")
            )

            switch secondSameThreadOutcome {
            case .started:
                Issue.record(
                    """
                    SwiftASB should reject overlapping same-thread turns before they reach the live \
                    Codex app-server because the live same-thread lifecycle is not independently \
                    routable today.
                    """
                )
            case let .failed(errorDescription):
                #expect(
                    errorDescription.contains("overlapping same-thread turns")
                        || errorDescription.contains("another turn start in flight")
                        || errorDescription.contains("already has an active turn")
                )
                #expect(errorDescription.isEmpty == false)

                let firstCompletion = try await awaitCompletion(
                    of: firstSameThreadTurn,
                    timeoutSeconds: 45,
                    operation: "waiting for the first same-thread turn to complete after the second start was rejected"
                )
                #expect(firstCompletion.turn.status.isTerminal)
            }

            await client.stop()
        } catch {
            await client.stop()
            throw error
        }
    }
}
