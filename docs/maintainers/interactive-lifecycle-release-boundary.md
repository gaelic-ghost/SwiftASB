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
  turn steering, and turn interruption
- `CodexThread` as the conversation-scoped public handle
- `CodexTurnHandle` as the active-turn public handle
- typed thread and turn event streams as the canonical lifecycle surface
- typed approval and elicitation request handling through public value types and
  explicit response methods
- `Dashboard` and `Minimap` as current-state mirrors of selected public events

The first interactive lifecycle release does not support:

- public exposure of generated `CodexWire...` types
- public APIs for `thread/resume`, `thread/fork`, `thread/read`,
  `thread/rollback`, or broader thread-management endpoints not yet wrapped by
  the package
- public APIs for every generated notification family just because the schema
  already contains them
- any "second event system" where observable companions expose lifecycle data
  that the typed public streams do not

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

### Observable-only for now

None.

`Dashboard` and `Minimap` currently mirror selected latest-state summaries from
already-public thread and turn events. They do not presently introduce any
extra lifecycle family that exists only through Observation and not through the
typed public streams.

### Internal-only for now

| Family | Why it remains internal |
| --- | --- |
| Command output delta notifications | Useful for future richer command/tool surfaces, but not yet part of the first supported public event contract. |
| File-change output delta notifications | Same reason as command output deltas: generated and compiled, but not yet promoted with a deliberate public model. |
| MCP tool-call progress notifications | Relevant for future richer tool-progress APIs, but intentionally deferred until a stronger public progress model is chosen. |
| Model-rerouted notifications | Operationally interesting, but not yet part of the stable public lifecycle promised to consumers. |
| Hook started / completed notifications | Internal runtime detail for now; no public wrapper model has been chosen. |
| Raw response item completed notifications | Too low-level and transport-adjacent for the current public lifecycle boundary. |
| Context compacted notifications | Interesting for diagnostics, but not yet surfaced as part of the supported public Swift API. |
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
| `CommandExecutionOutputDeltaNotification` | `Internal-only for now` |
| `CommandExecOutputDeltaNotification` | `Internal-only for now` |
| `FileChangeOutputDeltaNotification` | `Internal-only for now` |
| `McpToolCallProgressNotification` | `Internal-only for now` |
| `ModelReroutedNotification` | `Internal-only for now` |
| `HookStartedNotification` | `Internal-only for now` |
| `HookCompletedNotification` | `Internal-only for now` |
| `RawResponseItemCompletedNotification` | `Internal-only for now` |
| `ContextCompactedNotification` | `Internal-only for now` |
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

That means the first interactive lifecycle boundary is defined by both
notification promotion and server-request routing, not by notifications alone.

## What To Promote Next

Only promote another internal family when all of the following are true:

1. a real Swift consumer needs it to build an honest multi-turn interactive
   experience without dropping to raw payloads
2. the family has a stable enough meaning to justify a hand-shaped public Swift
   model
3. the public destination is clear:
   either `CodexThreadEvent`, `CodexTurnEvent`, or a future deliberate public
   companion surface

Until those conditions are met, the generated wire layer should remain broader
than the public API on purpose.
