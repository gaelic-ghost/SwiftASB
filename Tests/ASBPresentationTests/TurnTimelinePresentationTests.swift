import ASBPresentation
import Testing

struct TurnTimelinePresentationTests {
    @Test("snapshot flattens sections and preserves viewport hints")
    func snapshotFlattensSectionsAndViewport() {
        let command = item(id: "item-command", turnID: "turn-1", title: "swift test")
        let file = item(id: "item-file", turnID: "turn-2", title: "Package.swift", kind: .fileEdit)
        let snapshot = TurnTimelineSnapshot(
            sections: [
                .init(id: "turn-1", turnID: "turn-1", title: "First", status: "completed", items: [command]),
                .init(id: "turn-2", turnID: "turn-2", title: "Second", status: "inProgress", items: [file]),
            ],
            viewport: .init(
                visibleTurnIDs: ["turn-1", "turn-2"],
                scrollAnchorTurnID: "turn-2",
                scrollActivityPhase: .interacting,
                scrollVelocityPointsPerSecond: 240
            ),
            selectedItemID: "item-file",
            isLoadingOlderTurns: true,
            canLoadOlderTurns: true
        )

        #expect(snapshot.items.map(\.id) == ["item-command", "item-file"])
        #expect(snapshot.viewport.visibleTurnIDs == ["turn-1", "turn-2"])
        #expect(snapshot.viewport.scrollAnchorTurnID == "turn-2")
        #expect(snapshot.selectedItemID == "item-file")
        #expect(snapshot.isLoadingOlderTurns)
        #expect(snapshot.canLoadOlderTurns)
    }

    @Test("timeline item identity stays stable across payload hydration")
    func itemIdentitySurvivesHydration() {
        let slimmed = item(
            id: "item-1",
            turnID: "turn-1",
            title: "Edited README.md",
            kind: .fileEdit,
            isPayloadComplete: false,
            omittedPayloadCount: 400
        )
        let hydrated = item(
            id: "item-1",
            turnID: "turn-1",
            title: "Edited README.md",
            kind: .fileEdit,
            text: "diff --git a/README.md b/README.md",
            isPayloadComplete: true,
            omittedPayloadCount: 0
        )

        #expect(hydrated.id == slimmed.id)
        #expect(hydrated.turnID == slimmed.turnID)
        #expect(hydrated.isPayloadComplete)
        #expect(hydrated.omittedPayloadCount == 0)
    }

    @Test("timeline intents describe runtime actions without renderer indexes")
    func timelineIntentsAreRendererNeutral() {
        let intents: [TurnTimelineIntent] = [
            .loadOlderTurns,
            .loadNewerTurns,
            .updateVisibleTurnIDs(["turn-1"]),
            .updateViewport(.init(scrollAnchorTurnID: "turn-1")),
            .selectItem(id: "item-1"),
            .rehydratePayload(itemID: "item-1"),
        ]

        #expect(intents.contains(.loadOlderTurns))
        #expect(intents.contains(.updateVisibleTurnIDs(["turn-1"])))
        #expect(intents.contains(.selectItem(id: "item-1")))
    }

    private func item(
        id: String,
        turnID: String,
        title: String,
        kind: TurnTimelineItemKind = .command,
        text: String? = nil,
        isPayloadComplete: Bool = true,
        omittedPayloadCount: Int = 0
    ) -> TurnTimelineItem {
        TurnTimelineItem(
            id: id,
            turnID: turnID,
            displayKind: kind,
            title: title,
            text: text,
            isPayloadComplete: isPayloadComplete,
            omittedPayloadCount: omittedPayloadCount
        )
    }
}
