import ASBPresentation
import Testing

struct RecentActivityPresentationTests {
    @Test("activity snapshot keeps command and file identity distinct")
    func activityIDsIncludeKindPrefix() {
        let command = RecentActivityItem(
            id: "command:item-1",
            sourceID: "item-1",
            turnID: "turn-1",
            kind: .command,
            title: "swift build",
            status: .completed,
            command: "swift build",
            turnOrderIndex: 2,
            itemOrderIndex: 0,
            turnStartedAt: 20
        )
        let file = RecentActivityItem(
            id: "file:item-1",
            sourceID: "item-1",
            turnID: "turn-1",
            kind: .file,
            title: "Package.swift",
            status: .completed,
            path: "Package.swift",
            turnOrderIndex: 2,
            itemOrderIndex: 1,
            turnStartedAt: 20
        )
        let snapshot = RecentActivitySnapshot(
            items: [command, file],
            selectedItemID: "file:item-1",
            visibleItemIDs: ["command:item-1", "file:item-1"]
        )

        #expect(snapshot.items.map(\.id) == ["command:item-1", "file:item-1"])
        #expect(snapshot.items.map(\.sourceID) == ["item-1", "item-1"])
        #expect(snapshot.items.map(\.itemOrderIndex) == [0, 1])
        #expect(snapshot.selectedItemID == "file:item-1")
        #expect(snapshot.visibleItemIDs == ["command:item-1", "file:item-1"])
    }

    @Test("activity rows carry payload residency state")
    func activityRowsCarryPayloadResidency() {
        let slimmed = RecentActivityItem(
            id: "command:item-2",
            sourceID: "item-2",
            turnID: "turn-1",
            kind: .command,
            title: "swift test",
            status: .completed,
            isPayloadComplete: false,
            omittedPayloadCharacterCount: 128,
            command: "swift test"
        )

        #expect(!slimmed.isPayloadComplete)
        #expect(slimmed.omittedPayloadCharacterCount == 128)
        #expect(slimmed.command == "swift test")
    }

    @Test("activity intents describe list and payload actions")
    func activityIntentsAreNarrow() {
        let intents: [RecentActivityIntent] = [
            .loadOlderItems,
            .updateVisibleItemIDs(["command:item-1"]),
            .selectItem(id: "command:item-1"),
            .rehydratePayload(itemID: "command:item-1"),
        ]

        #expect(intents.contains(.loadOlderItems))
        #expect(intents.contains(.updateVisibleItemIDs(["command:item-1"])))
        #expect(intents.contains(.rehydratePayload(itemID: "command:item-1")))
    }
}
