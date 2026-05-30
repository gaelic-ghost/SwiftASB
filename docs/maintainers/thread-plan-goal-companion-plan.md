# Thread Plan And Goal Companion Plan

This note maps the SwiftASB cleanup pass for Codex plans and goals. The goal is
to make plan and goal state easy for SwiftUI clients to consume without asking
app code to assemble experimental deltas, manually refresh current goals, or
depend on every raw notification as public API.

Status: the first implementation pass shipped `CodexThread.Agenda`,
`CodexThread.makeAgenda()`, and dashboard title summaries on
`feature/plans-goals-api`.

## Current Facts

Official Codex docs describe plan mode as the way to ask Codex for a multi-step
execution plan before implementation work starts. They describe goals as a
persistent thread target, preferably shaped with a plan first. SwiftASB should
therefore keep plan and goal controls explicit in the shipped API: planning
creates or updates plan state, and goal actions mutate persisted goal state only
when the host app or user asks for that mutation.

The current generated app-server schema exposes:

- `thread/goal/get`
- `thread/goal/set`
- `thread/goal/clear`
- `thread/goal/updated`
- `thread/goal/cleared`
- `turn/plan/updated`
- `item/plan/delta`

The promoted wire model currently includes a stable-looking `ThreadGoal` value
with `objective`, `status`, `tokenBudget`, `tokensUsed`, `timeUsedSeconds`,
`createdAt`, and `updatedAt`. Plan updates carry a complete plan snapshot for
one turn. Plan deltas are explicitly marked experimental and warn clients not to
assume concatenated deltas equal the final plan item content.

The current public SwiftASB API already exposes:

- `CodexThread.readGoal()`
- `CodexThread.setGoal(_:)`
- `CodexThread.clearGoal()`
- `CodexThreadEvent.goalUpdated`
- `CodexThreadEvent.goalCleared`
- `CodexTurnEvent.planUpdated`
- `CodexTurnEvent.planDelta`
- `CodexThread.Dashboard.goal` before the first implementation pass
- `CodexTurnHandle.Minimap.latestPlanUpdate`
- `CodexTurnHandle.Minimap.latestPlanDelta`

That is useful but too raw for routine app UI. Consumers should not need to
reconcile thread-goal reads with live goal notifications, and they should not
need to treat experimental plan deltas as a stable user-facing data source.

## Proposed Public Shape

Add one thread-scoped observable companion that owns plan and goal current state.
This is a durable building-block change: it gives SwiftUI clients one object to
store for planning/progress displays while letting SwiftASB simplify lower-level
events over time.

Recommended name:

- `CodexThread.Agenda`

Other viable names:

- `CodexThread.TaskState`
- `CodexThread.Workspace`
- `CodexThread.Direction`
- `CodexThread.Focus`
- `CodexThread.Planbook`

`Agenda` is the nicest domain name. It naturally holds both the target and the
ordered work. It is also compact in app code:

```swift
let agenda = try await thread.makeAgenda()
agenda.goalTitle
agenda.planTitle
agenda.currentPlan.steps
```

`TaskState` is the safest literal fallback. It says exactly what the object is:
the thread's current task goal plus the plan state currently known for that
task. It is less charming, but it will age well.

`Workspace` is viable only if the companion eventually mirrors the whole active
work shape for one thread: current goal, latest accepted plan, proposed plan
text while it streams, and high-level progress. The downside is likely
confusion with `CodexWorkspace`, so it may be too overloaded.

Preferred recommendation for implementation:

- Use `CodexThread.Agenda`.
- Add `CodexThread.makeAgenda()` as the construction API.
- Treat the companion as the public way to render current goal and plan state.

## Companion Responsibilities

`CodexThread.Agenda` should own:

- initial goal hydration through `thread/goal/get`
- live goal update and clear notifications
- latest complete turn plan snapshot from `turn/plan/updated`
- proposed plan item text assembled from `item/plan/delta`
- reset or replacement behavior when a later complete plan snapshot arrives
- derived titles for dashboard-style display

Suggested initial public fields:

- `threadID: String`
- `goal: CodexThread.Goal?`
- `goalTitle: String`
- `goalStatus: CodexThread.Goal.Status?`
- `currentPlan: Plan?`
- `proposedPlan: ProposedPlan?`
- `planTitle: String`
- `updatedAt: Int?`

Suggested nested values:

- `Plan`
  - `turnID: String`
  - `explanation: String?`
  - `steps: [Step]`
- `Plan.Step`
  - `id: String`
  - `title: String`
  - `status: Status`
- `ProposedPlan`
  - `turnID: String`
  - `items: [Item]`
- `ProposedPlan.Item`
  - `id: String`
  - `text: String`

`Plan.Step.id` can be a stable SwiftASB-derived value from the turn id and
step index because upstream plan steps do not expose ids today. Proposed plan
items should keep upstream `itemId`.

## Dashboard Simplification

`Dashboard` should become lighter. It should expose only plan and goal summary
text, not the full goal object and not plan delta/update details.

Recommended dashboard fields:

- `goalTitle: String`
- `planTitle: String`

Decision:

- Remove `Dashboard.goal` in the same simplification pass and expose
  `Dashboard.goalTitle` plus `Dashboard.planTitle`.

The practical effect is that dashboard stays the broad thread status strip,
while agenda becomes the detailed task-progress model.

## Event Surface Simplification

The public event stream should move toward events that consumers can safely act
on directly. Raw plan deltas are not that kind of event because upstream marks
them experimental and says the final plan item is authoritative.

Recommended classification changes:

- Keep `CodexThreadEvent.goalUpdated` and `.goalCleared` for now only if direct
  event observers still need them outside `Agenda`.
- Reclassify `CodexTurnEvent.planDelta` as observable-owned state for `Agenda`,
  not a preferred consumer event.
- Consider reclassifying `CodexTurnEvent.planUpdated` as observable-owned too,
  once `Agenda.currentPlan` is shipped and documented.

Near-term conservative path:

- Ship `Agenda` first.
- Document that `Agenda` is preferred for plans and goals.
- Leave existing events in place for compatibility.
- In the next public API cleanup, deprecate `planDelta` first.

## Creation And Mutation Boundary

This pass should not yet create a high-level plan or goal authoring API. The
first implementation should be read/exposure-only plus current low-level goal
set/clear compatibility.

Shipped creation and mutation APIs:

- `agenda.setGoal(_ objective: String, tokenBudget: Int?)`
- `agenda.pauseGoal()`
- `agenda.resumeGoal()`
- `agenda.clearGoal()`
- `thread.startPlanningTurn(...)`

These are deliberate convenience APIs, not thin slash-command replicas.

Combined plan-plus-goal workflows are intentionally deferred. Future APIs may
suggest goal strings from accepted plans, stage a "set this plan as the goal"
action, or optionally recommend plan mode for complex prompts, but the current
surface should not auto-create a goal from a raw planning prompt.

## Implementation Slices

1. Add `CodexThread.Agenda` and `makeAgenda()`. Shipped.
2. Hydrate the current goal on construction and apply thread goal events.
   Shipped.
3. Feed turn plan updates and plan deltas into agenda state. Shipped.
4. Add dashboard `goalTitle` and `planTitle` summaries. Shipped.
5. Update DocC to recommend agenda for plan/goal UI. Shipped.
6. Revisit public event deprecations after tests prove agenda covers routine UI.

## Validation

Targeted tests should cover:

- agenda initializes with the current thread goal
- agenda updates and clears goal state from thread events
- agenda derives goal title and status from the current goal
- agenda stores the latest complete plan snapshot from turn plan updates
- agenda accumulates proposed plan text by `itemId` from plan deltas
- agenda replaces or clears proposed state when an authoritative plan update
  arrives for the same turn
- dashboard mirrors only `goalTitle` and `planTitle`
