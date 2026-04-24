# Interactive Lifecycle Release Boundary

## Purpose

This note records the release boundary for the first real interactive
`SwiftASB` lifecycle.

It answers four maintainer-facing questions:

1. which generated notification families are part of the supported public
   lifecycle today
2. which generated notification families are compiled internally but
   intentionally remain non-public
3. whether any notification family is currently observable-only
4. which adjacent protocol surfaces are still intentionally unsupported even if
   upstream `codex app-server` already documents them

This document is deliberately stricter than "what exists in the generated wire
snapshot." Generated schema breadth is not itself the release boundary.

## Release Boundary Summary

The first interactive lifecycle release supports:

- `CodexAppServer` startup, shutdown, initialize, thread start, turn start,
  turn steering, turn interruption, thread management, and manual thread
  context compaction start
- `CodexThread` as the conversation-scoped public handle
- `CodexTurnHandle` as the active-turn public handle
- typed thread and turn event streams as the canonical lifecycle surface
- typed approval and elicitation request handling through public value types and
  explicit response methods
- `Dashboard` and `Minimap` as current-state mirrors of selected public events

The first interactive lifecycle release does not support:

- public exposure of generated `CodexWire...` types
- public APIs for `thread/rollback` or every broader thread-management endpoint
  not yet wrapped by the package
- public APIs for every generated notification family just because the schema
  already contains them
- an accidental "second event system" where observable companions drift into a
  broad unsourced parallel lifecycle without a deliberate current-state role

## Codex CLI Compatibility Policy

`SwiftASB` intentionally uses a rolling compatibility window for the local
Codex CLI runtime.

Current policy:

- support the latest public Codex CLI release
- support the prior two minor versions as well
- reassess this policy when Codex reaches a future major-version release

Practical implications:

- do not require exact CLI-version pinning as the normal package contract
- expect many upstream releases to be additive rather than immediately breaking
- when a newer CLI exposes extra app-server behavior, treat that as a possible
  late additive promotion or gated capability rather than as proof that the
  older supported window is no longer valid
- if a newly introduced upstream change is genuinely incompatible with the
  written public lifecycle boundary, tighten the support statement explicitly
  in docs and tests instead of letting drift stay implicit

Current binary discovery on macOS should follow this order:

1. explicit `CodexAppServer.Configuration.codexExecutableURL`
2. `PATH` probe via `codex --version`
3. Homebrew paths:
   `/opt/homebrew/bin/codex` and `/usr/local/bin/codex`
4. npm global prefix lookup via `npm prefix -g`, then `<prefix>/bin/codex`

The discovery path intentionally covers the two officially documented install
options for Codex CLI on macOS: Homebrew cask install and global npm install.

The package now also exposes read-only startup diagnostics for the resolved
binary through `CodexAppServer.cliExecutableDiagnostics()`. That surface is for
operator inspection only; it should not become a second source of lifecycle
control or a reason to widen the public API beyond binary, source, version, and
support-window inspection.

This policy is intentionally softer than the upstream Python package model that
pins an exact runtime dependency. `SwiftASB` is expected to work against a
reasonably recent installed local Codex CLI, not only one exact binary build.

## Classification Rules

Use these labels when deciding whether a protocol or generated-wire family
belongs in the release boundary:

| Classification | Meaning |
| --- | --- |
| `Public now` | Mapped through the protocol layer and surfaced through stable public value types or public event enums. Consumers should be able to rely on this family today. |
| `Observable-only for now` | Not a standalone public event family, but intentionally mirrored as current state in `Dashboard` or `Minimap`. |
| `Internal-only for now` | Compiled in the generated or protocol layer for scaffolding, future work, or internal correlation, but intentionally not part of the public contract yet. |

## Current Classification

### Public now

| Family | Current public surface | Notes |
| --- | --- | --- |
| Thread lifecycle notifications | `CodexThreadEvent.started`, `.statusChanged`, `.archived`, `.unarchived`, `.closed`, `.nameUpdated`, `.tokenUsageUpdated` | These are mapped through the protocol layer and streamed publicly. |
| Turn lifecycle notifications | `CodexTurnEvent.started`, `.planUpdated`, `.diffUpdated`, `.completed` | These define the main public turn-progress shape. |
| Core item lifecycle notifications | `CodexTurnEvent.itemStarted`, `.itemCompleted` | These are the supported item-level lifecycle events today. |
| Agent-message and plan deltas | `CodexTurnEvent.agentMessageDelta`, `.planDelta` | These are part of the intended interactive turn stream. |
| Reasoning deltas | `CodexTurnEvent.reasoningSummaryPartAdded`, `.reasoningSummaryTextDelta`, `.reasoningTextDelta` | These are public because they are already part of the meaningful supported turn stream. |
| Server-request resolution notifications | `CodexTurnEvent.serverRequestResolved`, `CodexThreadEvent.serverRequestResolved` | These are public because request cleanup is part of the supported interactive lifecycle. |
| Approval request families | `CodexTurnEvent.approvalRequested`, `CodexThreadEvent.approvalRequested` | These are protocol-level server requests rather than generated notifications, but they are part of the supported public lifecycle. |
| Elicitation request families | `CodexTurnEvent.elicitationRequested`, `CodexThreadEvent.elicitationRequested` | These are also protocol-level server requests and part of the supported public lifecycle. |
| Approval reviewer options | `CodexAppServer.ApprovalsReviewer.autoReview` | v0.124 adds `auto_review`; this is a small public enum widening because callers already choose approval-review behavior through hand-owned request models. |

### Observable-only for now

This category is now in real use.

`Dashboard` and `Minimap` still derive their current-state summaries from the
typed public lifecycle, but they now also expose a deliberate observable-only
summary slice that is not represented as standalone public event cases.

Current observable-only families:

| Family | Current public surface | Why it is observable-only for now |
| --- | --- | --- |
| Per-turn tool, file-edit, and MCP activity summaries | `CodexTurnHandle.Minimap.callSnapshots` | Consumers often need a stable "calls made during this turn" list more than they need every raw progress delta as a first-class event enum. |
| Per-turn compaction status | `CodexTurnHandle.Minimap.isCompactingThreadContext` | Turn-scoped UI often needs to know when the current turn is blocked on context compaction, but the package still does not expose raw compaction notifications as first-class public events. |
| Thread-level aggregate tool activity | `CodexThread.Dashboard.toolCallingStatus` | This is a current-state blocked-or-busy summary, not canonical event history. |
| Thread-level aggregate MCP activity | `CodexThread.Dashboard.mcpCallingStatus` | Same reason as tool activity: useful UI summary, but not a separate public event family yet. |
| Thread-level recent file edits | `CodexThread.RecentFiles` | File viewers and diff panels need file-centric current state, not raw file-change delta notifications as a top-level event enum. |
| Thread-level recent command activity | `CodexThread.RecentCommands` | Terminal-style inspectors need command-centric current state, not raw command-output delta notifications as a top-level event enum. |
| Thread-level active hook runs | `CodexThread.Dashboard.hookRuns` | Consumers need a stable current-state view of which hooks are running or have just completed more than they need raw hook notifications as first-class event enums. |
| Thread-level compaction status | `CodexThread.Dashboard.isCompactingThreadContext` | Current blocked-thread state matters to consumers, but the package does not yet expose full compaction progress as a public event stream. |
| Hook permission-request event names | `CodexThread.Dashboard.HookRun.EventName.permissionRequest` | v0.124 adds this hook event name. The hook-run mirror can display it, but raw hook notifications still are not public event cases. |

Future observable-only families are acceptable when all of the following are
true:

- the consumer job is current-state UI, not historical replay or precise event
  sequencing
- the mirrored state is derived from one or more generated or protocol families
  that would be awkward, noisy, or misleading to expose as first-class public
  event cases
- the observable shape is a deliberate ergonomic summary such as a status flag,
  activity snapshot, or in-flight work list rather than a raw payload dump
- the docs say plainly that the observable surface is a current-state mirror,
  not the canonical event history

Current implementation intent for those mirrors:

- a turn-scoped minimap is a handle-owned current-state companion and should be
  attached eagerly with the turn handle rather than depending on late observer
  subscription for correctness
- a thread-scoped dashboard remains opt-in for now, so the package should not
  retain an unbounded backlog of thread-level turn activity solely to serve a
  dashboard that may never be created

Remaining gap inside the observable-only slice:

- `Minimap.callSnapshots` currently summarizes call start and completion state,
  plus a few display-oriented fields, but it does not yet expose richer
  progress detail from MCP-progress notifications.
- `RecentCommands` now gives command-output deltas a concrete current-state
  destination, but it is still intentionally command-centric rather than being
  a mixed recent-activity feed.
- `RecentFiles` now gives file-change output deltas a concrete current-state
  destination, but it is still intentionally file-centric rather than being a
  mixed recent-activity feed.
- `Dashboard` currently summarizes whether tool work, MCP work, or thread
  compaction is active or left error residue behind, and it now mirrors active
  hook runs plus their latest status, but it does not yet expose richer command
  or file progress detail.

### Internal-only for now

| Family | Why it remains internal |
| --- | --- |
| Command output delta notifications | The raw notifications remain internal, but they now feed `CodexThread.RecentCommands` as a command-centric observable companion instead of becoming new top-level public event cases. |
| File-change output delta notifications | The raw notifications remain internal, but they now feed `CodexThread.RecentFiles` as a file-centric observable companion instead of becoming new top-level public event cases. |
| File-change patch-updated notifications | Useful for richer `RecentFiles` previews later, but not yet wired into a stable public diff model. For now the generated type is internal scaffolding. |
| MCP tool-call progress notifications | The current public surface already covers MCP activity at the summary level through `Minimap.callSnapshots` and `Dashboard.mcpCallingStatus`; richer MCP progress remains internal until a stronger public model is chosen. |
| Model-rerouted notifications | Operationally interesting, but not yet part of the stable public lifecycle promised to consumers. These currently stay internal and are logged for operator diagnostics. |
| Model-verification notifications | Operationally useful diagnostics, but no public consumer model has been chosen yet. |
| Warning and guardian-warning notifications | These are important operator signals, but need a deliberate diagnostics surface rather than being exposed as raw event payloads. |
| External-agent config import completed notifications | Useful when the app grows external-agent configuration surfaces; not part of the current lifecycle API. |
| Guardian denied-action approval endpoint | Generated internally because it appears in v0.124, but it needs a real guardian workflow model before it becomes public. |
| Hook started / completed notifications | The raw notifications remain internal; consumers see their current-state effect through `CodexThread.Dashboard.hookRuns` instead of through new event-enum cases. |
| Raw response item completed notifications | Too low-level and transport-adjacent for the current public lifecycle boundary. |
| Context compacted notifications | Interesting for diagnostics, but still not surfaced as a first-class public event; consumers currently see compaction through `Dashboard` and `Minimap` state plus explicit `compactContext()` control. |
| Error notifications | The current public contract keeps lifecycle failures unified under `CodexAppServerError` instead of streaming raw protocol error-notification payloads. |
| Guardian approval review started / completed notifications | The generated wire comments already mark these payloads as unstable, so they should stay internal until upstream stabilizes them and the package decides on a real public model. |

## Family Inventory

For the current promoted generated v2 lifecycle batch, the notification
families break down like this:

| Generated notification family | Classification |
| --- | --- |
| `ThreadStartedNotification` | `Public now` |
| `ThreadStatusChangedNotification` | `Public now` |
| `ThreadNameUpdatedNotification` | `Public now` |
| `ThreadTokenUsageUpdatedNotification` | `Public now` |
| `ThreadArchivedNotification` | `Public now` |
| `ThreadUnarchivedNotification` | `Public now` |
| `ThreadClosedNotification` | `Public now` |
| `TurnStartedNotification` | `Public now` |
| `TurnPlanUpdatedNotification` | `Public now` |
| `TurnDiffUpdatedNotification` | `Public now` |
| `TurnCompletedNotification` | `Public now` |
| `ItemStartedNotification` | `Public now` |
| `ItemCompletedNotification` | `Public now` |
| `PlanDeltaNotification` | `Public now` |
| `ReasoningTextDeltaNotification` | `Public now` |
| `ReasoningSummaryPartAddedNotification` | `Public now` |
| `ReasoningSummaryTextDeltaNotification` | `Public now` |
| `AgentMessageDeltaNotification` | `Public now` |
| `ServerRequestResolvedNotification` | `Public now` |
| `CommandExecutionOutputDeltaNotification` | `Observable-only for now` |
| `CommandExecOutputDeltaNotification` | `Internal-only for now` |
| `FileChangeOutputDeltaNotification` | `Observable-only for now` |
| `FileChangePatchUpdatedNotification` | `Internal-only for now` |
| `McpToolCallProgressNotification` | `Internal-only for now` |
| `ModelVerificationNotification` | `Internal-only for now` |
| `ModelReroutedNotification` | `Internal-only for now` |
| `HookStartedNotification` | `Observable-only for now` |
| `HookCompletedNotification` | `Observable-only for now` |
| `RawResponseItemCompletedNotification` | `Internal-only for now` |
| `ContextCompactedNotification` | `Internal-only for now` |
| `ExternalAgentConfigImportCompletedNotification` | `Internal-only for now` |
| `GuardianWarningNotification` | `Internal-only for now` |
| `WarningNotification` | `Internal-only for now` |
| `ErrorNotification` | `Internal-only for now` |
| `ItemGuardianApprovalReviewStartedNotification` | `Internal-only for now` |
| `ItemGuardianApprovalReviewCompletedNotification` | `Internal-only for now` |

## Adjacent Non-Notification Surfaces

Some important supported public lifecycle behavior does not come from generated
notification families at all:

- approval requests are public through typed server-request decoding
- elicitation requests are public through typed server-request decoding
- approval and elicitation responses are public through explicit methods on
  `CodexThread` and `CodexTurnHandle`
- turn interruption and steering are public control methods rather than event
  families
- `thread/turns/list` is public through hand-owned history paging APIs even
  though the generated params and response stay internal
- `permissionProfile` is generated and decoded internally, but the public API
  still accepts the existing hand-owned sandbox and approval settings until a
  deliberate permission-profile model is designed
- device-key, marketplace-removal, and add-credits email endpoints remain
  outside the first lifecycle boundary

That means the first interactive lifecycle boundary is defined by both
notification promotion and server-request routing, not by notifications alone.

It is also now defined partly by deliberate observable-only summaries:

- `CodexTurnHandle.Minimap.callSnapshots` gives consumers a stable per-turn
  list of command, file-edit, dynamic-tool, collab-tool, and MCP activity.
- `CodexTurnHandle.Minimap.isCompactingThreadContext` gives consumers a stable
  per-turn answer to whether context compaction is currently active.
- `CodexThread.RecentFiles` gives consumers a stable thread-scoped list of
  recent file edits, hydrated from the same persisted turn history and enriched
  by live file-change output deltas while an edit is still in progress.
- `CodexThread.RecentCommands` gives consumers a stable thread-scoped list of
  recent command activity, hydrated from the same persisted turn history and
  enriched by live command-output deltas while a command is still in progress.
- `CodexThread.Dashboard` gives consumers current-state thread summaries for
  aggregate tool activity, aggregate MCP activity, active hook runs, and
  whether thread compaction is currently active.

## What To Promote Next

Only promote another internal family when all of the following are true:

1. a real Swift consumer needs it to build an honest multi-turn interactive
   experience without dropping to raw payloads
2. the family has a stable enough meaning to justify a hand-shaped public Swift
   model
3. the public destination is clear:
   either `CodexThreadEvent`, `CodexTurnEvent`, or a future deliberate public
   companion surface

If the destination is a companion surface, the design should state why the
family works better as a current-state observable mirror than as a canonical
typed event case.

The current remaining promotion questions are therefore narrower than before:

1. should richer MCP progress stay inside the existing observable summaries, or
   graduate into additional public event cases?
2. should `FileChangePatchUpdatedNotification` enrich `RecentFiles` with
   structured patch previews, and if so, what stable file-diff model should the
   package own instead of leaking generated wire shapes?
3. should `permissionProfile` become a public request/defaults model, or stay
   internal while the current sandbox and approval request models are enough?
4. warning, guardian-warning, model-verification, and guardian denied-action
   families need a diagnostics/control story before they graduate from internal
   generated scaffolding.
5. file and command detail are now both treated as dedicated companion
   observables rather than as widened event enums:
   `RecentFiles` and `RecentCommands` are the shipped file-centric and
   command-centric surfaces, and a later `RecentActivity` feed should stay
   separate instead of swallowing those narrower models.
6. how far should the non-UI public history-reading surface go beyond the
   first shipped `ClosedTurn` helpers before the package commits to a broader
   cursor or search contract?

## Decided Next Companion Shape

The file and command companion shapes are now considered decided and shipped:

- add `CodexThread.RecentFiles` as a file-centric observable
- keep `RecentFiles` item-scoped in the first pass:
  one observable entry per file-change item, not path-level coalescing
- derive file identity and metadata from item lifecycle plus persisted turn
  history, and use file-change output deltas only to enrich the current
  payload
- keep file-entry shells resident longer than heavier payload text, and
  rehydrate payload when a file becomes visible or selected again
- preserve already-streamed file payload when a later completed snapshot is
  thinner than the live observable state
- add `CodexThread.RecentCommands` as a command-centric observable
- keep `RecentCommands` item-scoped in the first pass:
  one observable entry per `commandExecution` item
- derive command identity and metadata from item lifecycle plus persisted turn
  history, and use command-output deltas only to enrich the current output
- keep command-entry shells resident longer than heavier output text, and
  rehydrate output when a command becomes visible or selected again
- preserve already-streamed command output when a later completed snapshot is
  thinner than the live observable state
- treat a later `RecentActivity` surface as a separate mixed timeline for
  commands, files, MCP work, and other recent activity rather than as a base
  type that owns `RecentFiles` or `RecentCommands`

This means file-change and command-output deltas remain internal transport
detail, but they are now earmarked for specific public destinations:
`CodexThread.RecentFiles` and `CodexThread.RecentCommands` as current-state
observable companions.

Until those conditions are met, the generated wire layer should remain broader
than the public API on purpose.
