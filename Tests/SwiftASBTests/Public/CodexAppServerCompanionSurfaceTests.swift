import Foundation
import Testing
@testable import SwiftASB

extension CodexAppServerTests {
    @MainActor
    @Test("builds a dashboard that stays live with thread events")
    func buildsThreadDashboard() async throws {
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

        let turnHandle = try await thread.startTextTurn("Track dashboard activity")

        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-command-1",
            item: [
                "command": "ls",
                "id": "item-command-1",
                "type": "commandExecution",
            ]
        )
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-mcp-1",
            item: [
                "id": "item-mcp-1",
                "server": "calendar",
                "tool": "list_events",
                "type": "mcpToolCall",
            ]
        )
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-compact-1",
            item: [
                "id": "item-compact-1",
                "type": "contextCompaction",
            ]
        )

        let dashboard = await thread.makeDashboard()

        #expect(dashboard.threadID == thread.id)
        #expect(dashboard.name == nil)
        #expect(dashboard.preview == "Hello from the fake app-server")
        #expect(dashboard.status.type == .active)
        #expect(dashboard.isArchived == false)
        #expect(dashboard.isClosed == false)
        #expect(dashboard.goalTitle == "")
        #expect(dashboard.planTitle == "")
        #expect(dashboard.latestTokenUsage == nil)

        await transport.emitHookStarted(
            threadID: thread.id,
            turnID: turnHandle.turn.id
        )

        try await waitForCondition {
            await client.threadObservableActivityState(threadID: thread.id).hookRuns.count == 1
        }

        await waitForObservableState {
            dashboard.toolCallingStatus == .inProgress
                && dashboard.mcpCallingStatus == .inProgress
                && dashboard.isCompactingThreadContext
                && dashboard.hookRuns.count == 1
        }

        #expect(dashboard.toolCallingStatus == .inProgress)
        #expect(dashboard.mcpCallingStatus == .inProgress)
        #expect(dashboard.isCompactingThreadContext == true)
        #expect(dashboard.hookRuns.count == 1)
        #expect(dashboard.hookRuns[0].status == .running)
        #expect(dashboard.hookRuns[0].turnID == turnHandle.turn.id)

        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-command-1",
            item: [
                "command": "ls",
                "id": "item-command-1",
                "status": "failed",
                "type": "commandExecution",
            ]
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-mcp-1",
            item: [
                "id": "item-mcp-1",
                "server": "calendar",
                "status": "completed",
                "tool": "list_events",
                "type": "mcpToolCall",
            ]
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-compact-1",
            item: [
                "id": "item-compact-1",
                "status": "completed",
                "type": "contextCompaction",
            ]
        )
        await transport.emitHookCompleted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            status: "completed"
        )
        await transport.emitModelRerouted(
            threadID: thread.id,
            turnID: turnHandle.turn.id
        )

        await waitForObservableState {
            dashboard.toolCallingStatus == .errored
                && dashboard.mcpCallingStatus == .idle
                && dashboard.isCompactingThreadContext == false
                && dashboard.hookRuns.first?.status == .completed
        }

        await transport.emitThreadStarted(threadID: thread.id)
        await transport.emitThreadStatusChanged(threadID: thread.id)
        await transport.emitThreadNameUpdated(threadID: thread.id)
        await transport.emitThreadGoalUpdated(threadID: thread.id)
        await transport.emitTurnPlanUpdated(threadID: thread.id, turnID: turnHandle.turn.id)
        await transport.emitThreadArchived(threadID: thread.id)
        await transport.emitThreadTokenUsageUpdated(threadID: thread.id, turnID: "turn-123")
        await transport.emitThreadClosed(threadID: thread.id)

        await waitForObservableState {
            dashboard.name == "Planning Thread"
                && dashboard.isArchived
                && dashboard.isClosed
                && dashboard.goalTitle == "Promote schemas"
                && dashboard.planTitle == "Promote protocol events into CodexTurnEvent"
                && dashboard.latestTokenUsage?.turnID == "turn-123"
        }

        #expect(dashboard.name == "Planning Thread")
        #expect(dashboard.preview == "Hello from thread/started")
        #expect(dashboard.status.type == .active)
        #expect(dashboard.status.activeFlags == [.waitingOnApproval])
        #expect(dashboard.isArchived == true)
        #expect(dashboard.isClosed == true)
        #expect(dashboard.goalTitle == "Promote schemas")
        #expect(dashboard.planTitle == "Promote protocol events into CodexTurnEvent")
        #expect(dashboard.isCompactingThreadContext == false)
        #expect(dashboard.hookRuns.count == 1)
        #expect(dashboard.hookRuns[0].status == .completed)
        #expect(dashboard.hookRuns[0].entries.first?.kind == .feedback)
        #expect(dashboard.latestTokenUsage?.turnID == "turn-123")
        #expect(dashboard.latestTokenUsage?.total.totalTokens == 650)
        #expect(dashboard.toolCallingStatus == .errored)
        #expect(dashboard.mcpCallingStatus == .idle)

        await client.stop()
    }

    @MainActor
    @Test("builds an agenda that owns thread goals and plan state")
    func buildsThreadAgenda() async throws {
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
        let turnHandle = try await thread.startTextTurn("Shape agenda state")

        let agenda = try await thread.makeAgenda()

        #expect(agenda.threadID == thread.id)
        #expect(agenda.goal?.objective == "Promote schemas")
        #expect(agenda.goalStatus == .active)
        #expect(agenda.goalTitle == "Promote schemas")
        #expect(agenda.updatedAt == 1_713_350_010)
        #expect(agenda.currentPlan == nil)
        #expect(agenda.proposedPlan == nil)
        #expect(agenda.planTitle == "")

        await transport.emitPlanDelta(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-plan-1"
        )
        await transport.emitPlanDelta(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-plan-1"
        )

        await waitForObservableState {
            agenda.proposedPlan?.items.first?.text == "Stream partial plan textStream partial plan text"
        }

        #expect(agenda.proposedPlan?.turnID == turnHandle.turn.id)
        #expect(agenda.proposedPlan?.items.first?.id == "item-plan-1")
        #expect(agenda.planTitle == "Stream partial plan textStream partial plan text")

        await transport.emitTurnPlanUpdated(
            threadID: thread.id,
            turnID: turnHandle.turn.id
        )

        await waitForObservableState {
            agenda.currentPlan?.steps.count == 2
                && agenda.proposedPlan == nil
        }

        #expect(agenda.currentPlan?.turnID == turnHandle.turn.id)
        #expect(agenda.currentPlan?.explanation == "Map richer progress notifications.")
        #expect(agenda.currentPlan?.steps[0].id == "\(turnHandle.turn.id):0")
        #expect(agenda.currentPlan?.steps[0].status == .inProgress)
        #expect(agenda.currentPlan?.steps[0].title == "Promote protocol events into CodexTurnEvent")
        #expect(agenda.currentPlan?.steps[1].status == .pending)
        #expect(agenda.planTitle == "Promote protocol events into CodexTurnEvent")

        await transport.emitThreadGoalUpdated(threadID: thread.id)

        await waitForObservableState {
            agenda.goalStatus == .complete
                && agenda.updatedAt == 1_713_350_030
        }

        #expect(agenda.goalTitle == "Promote schemas")

        await transport.emitThreadGoalCleared(threadID: thread.id)

        await waitForObservableState {
            agenda.goal == nil
                && agenda.goalStatus == nil
                && agenda.goalTitle == ""
                && agenda.updatedAt == nil
        }

        await client.stop()
    }

    @MainActor
    @Test("builds a minimap that stays live with turn events")
    func buildsTurnMinimap() async throws {
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

        let turnHandle = try await thread.startTextTurn("Hello from SwiftASB")

        await transport.emitTurnStarted(
            threadID: thread.id,
            turnID: turnHandle.turn.id
        )
        await transport.emitTurnPlanUpdated(
            threadID: thread.id,
            turnID: turnHandle.turn.id
        )
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-command-1",
            item: [
                "command": "ls Sources",
                "id": "item-command-1",
                "type": "commandExecution",
            ]
        )
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-file-1",
            item: [
                "id": "item-file-1",
                "path": "/tmp/project/README.md",
                "type": "fileChange",
            ]
        )
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-mcp-1",
            item: [
                "id": "item-mcp-1",
                "server": "calendar",
                "tool": "list_events",
                "type": "mcpToolCall",
            ]
        )
        await transport.emitItemStarted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-compact-1",
            item: [
                "id": "item-compact-1",
                "type": "contextCompaction",
            ]
        )
        await transport.emitPlanDelta(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-plan-1"
        )
        await transport.emitAgentMessageDelta(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-agent-1"
        )
        await transport.emitReasoningTextDelta(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-reasoning-1"
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-command-1",
            item: [
                "command": "ls Sources",
                "id": "item-command-1",
                "status": "completed",
                "type": "commandExecution",
            ]
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-file-1",
            item: [
                "changes": [
                    [
                        "diff": "@@ -1 +1 @@",
                        "kind": ["type": "update"],
                        "path": "/tmp/project/README.md",
                    ],
                ],
                "id": "item-file-1",
                "status": "completed",
                "type": "fileChange",
            ]
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-mcp-1",
            item: [
                "id": "item-mcp-1",
                "server": "calendar",
                "status": "errored",
                "tool": "list_events",
                "type": "mcpToolCall",
            ]
        )
        await transport.emitItemCompleted(
            threadID: thread.id,
            turnID: turnHandle.turn.id,
            itemID: "item-compact-1",
            item: [
                "id": "item-compact-1",
                "status": "completed",
                "type": "contextCompaction",
            ]
        )
        await transport.emitTurnCompleted(
            threadID: thread.id,
            turnID: turnHandle.turn.id
        )

        let minimap = turnHandle.minimap

        #expect(minimap.threadID == thread.id)
        #expect(minimap.turnID == turnHandle.turn.id)
        #expect(minimap.currentTurn.id == turnHandle.turn.id)
        await waitForObservableState {
            minimap.latestPlanUpdate != nil
                && minimap.latestAgentMessageDelta != nil
                && minimap.latestReasoningTextDelta != nil
                && minimap.latestCompletion != nil
                && minimap.callSnapshots.count == 3
                && minimap.isCompactingThreadContext == false
                && minimap.currentTurn.status == .completed
        }

        #expect(minimap.latestStartedTurn?.turn.id == turnHandle.turn.id)
        #expect(minimap.latestPlanUpdate?.turnID == turnHandle.turn.id)
        #expect(minimap.latestPlanDelta?.itemID == "item-plan-1")
        #expect(minimap.latestAgentMessageDelta?.itemID == "item-agent-1")
        #expect(minimap.latestReasoningTextDelta?.itemID == "item-reasoning-1")
        #expect(minimap.latestCompletion?.turn.id == turnHandle.turn.id)
        #expect(minimap.isCompactingThreadContext == false)
        #expect(minimap.currentTurn.status == .completed)
        #expect(minimap.callSnapshots.count == 3)
        #expect(minimap.callSnapshots[0].kind == .command)
        #expect(minimap.callSnapshots[0].displayName == "ls Sources")
        #expect(minimap.callSnapshots[0].status == .completed)
        #expect(minimap.callSnapshots[1].kind == .fileEdit)
        #expect(minimap.callSnapshots[1].filePath == "/tmp/project/README.md")
        #expect(minimap.callSnapshots[1].status == .completed)
        #expect(minimap.callSnapshots[2].kind == .mcp)
        #expect(minimap.callSnapshots[2].displayName == "calendar.list_events")
        #expect(minimap.callSnapshots[2].status == .errored)

        await client.stop()
    }

}
