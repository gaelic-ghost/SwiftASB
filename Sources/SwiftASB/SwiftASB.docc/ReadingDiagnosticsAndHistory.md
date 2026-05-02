# Reading Diagnostics And History

Observe passive runtime diagnostics and read completed local turn history.

## Overview

Diagnostics and history answer different questions. Diagnostics explain what the runtime is warning about right now: model reroutes, model verification results, guardian warnings, and general runtime warnings. History reads return completed turns that SwiftASB has persisted or hydrated from the app-server.

```swift
func observeDiagnostics(appServer: CodexAppServer) {
    Task {
        do {
            for try await diagnostic in await appServer.diagnosticEvents() {
                switch diagnostic {
                case let .warning(warning):
                    log("Warning: \(warning.message)")
                case let .guardianWarning(warning):
                    log("Guardian: \(warning.message)")
                case let .modelRerouted(reroute):
                    log("Model changed from \(reroute.fromModel) to \(reroute.toModel)")
                case let .modelVerification(verification):
                    log("Verification count: \(verification.verifications.count)")
                }
            }
        } catch {
            log("Diagnostic stream failed: \(error)")
        }
    }
}
```

Diagnostics are passive. They are not approval requests and do not need responses.

## Reading Local History

Use local history helpers when a caller needs completed turn snapshots without a live observable companion.

```swift
func renderRecentHistory(thread: CodexThread) async throws {
    let recent = try await thread.readRecentTurnHistoryWindow(limit: 12)
    renderTurns(recent.turns)

    if recent.hasOlderTurns, let oldest = recent.oldestTurnID {
        let older = try await thread.readOlderTurnHistoryWindow(
            olderThan: oldest,
            limit: 12
        )
        renderOlderTurns(older.turns)
    }
}
```

Use ``CodexThread/windowAroundTurn(_:limit:)`` or ``CodexThread/windowAroundItem(_:limit:)`` when an inspector starts from a known turn or item and needs nearby context.

## Remote Paging Boundary

``CodexAppServer/listThreadTurns(_:)`` talks directly to the app-server and surfaces app-server failures. Recent observable companions use a narrower startup rule: if the app-server reports that turn paging is unavailable for an ephemeral thread or not-yet-materialized stored thread, they can start from an empty local view and keep listening to live events.

## Topics

### Diagnostics

- ``CodexAppServer/diagnosticEvents()``
- ``CodexDiagnosticEvent``
- ``CodexRuntimeWarning``
- ``CodexGuardianWarning``
- ``CodexModelReroute``
- ``CodexModelVerificationDiagnostic``

### Local History

- ``CodexThread/readRecentTurnHistoryWindow(limit:)``
- ``CodexThread/readOlderTurnHistoryWindow(olderThan:limit:)``
- ``CodexThread/readNewerTurnHistoryWindow(newerThan:limit:)``
- ``CodexThread/windowAroundTurn(_:limit:)``
- ``CodexThread/windowAroundItem(_:limit:)``
- ``CodexThread/HistoryWindow``
