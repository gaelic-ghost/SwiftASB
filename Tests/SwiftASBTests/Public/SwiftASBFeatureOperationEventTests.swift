import Foundation
import Testing
@testable import SwiftASB

@Suite("SwiftASB feature operation events")
struct SwiftASBFeatureOperationEventTests {
    @Test("feature operation event carries mutation metadata")
    func featureOperationEventCarriesMutationMetadata() {
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let completedAt = Date(timeIntervalSince1970: 1_700_000_003)
        let event = SwiftASBFeatureOperationEvent(
            categoryID: .swiftRepoGuidanceSync,
            operationID: "guidance-sync-123",
            title: "Sync Swift guidance",
            summary: "Updated repo guidance files for a Swift package.",
            reason: "The host enabled trusted Swift repo guidance sync.",
            startedAt: startedAt,
            completedAt: completedAt,
            affectedPaths: ["AGENTS.md", "CONTRIBUTING.md"],
            commands: [
                .init(
                    argv: ["git", "status", "--short"],
                    currentDirectoryPath: "/tmp/project"
                ),
            ],
            appServerMethod: "command/exec",
            intentKind: "swiftRepoGuidanceSync",
            status: .succeeded,
            rollback: .init(
                isAvailable: true,
                handle: "swift-guidance-sync:guidance-sync-123",
                summary: "Restore the touched guidance files from the pre-sync snapshot."
            ),
            diagnosticText: nil
        )

        #expect(event.id == "guidance-sync-123")
        #expect(event.categoryID == .swiftRepoGuidanceSync)
        #expect(event.operationID == "guidance-sync-123")
        #expect(event.title == "Sync Swift guidance")
        #expect(event.summary == "Updated repo guidance files for a Swift package.")
        #expect(event.reason == "The host enabled trusted Swift repo guidance sync.")
        #expect(event.startedAt == startedAt)
        #expect(event.completedAt == completedAt)
        #expect(event.affectedPaths == ["AGENTS.md", "CONTRIBUTING.md"])
        #expect(event.commands[0].argv == ["git", "status", "--short"])
        #expect(event.commands[0].currentDirectoryPath == "/tmp/project")
        #expect(event.appServerMethod == "command/exec")
        #expect(event.intentKind == "swiftRepoGuidanceSync")
        #expect(event.status == .succeeded)
        #expect(event.rollback.isAvailable)
        #expect(event.rollback.handle == "swift-guidance-sync:guidance-sync-123")
        #expect(event.diagnosticText == nil)
    }
}
