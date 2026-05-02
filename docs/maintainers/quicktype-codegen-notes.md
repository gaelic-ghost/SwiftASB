# quicktype Codegen Notes

## Current recommendation

Use the bundled Codex protocol schemas as the source of truth, derive
quicktype-friendly synthetic roots from those bundles, generate consolidated
Swift wire files, and immediately patch the dynamic JSON holes to
`CodexWireJSONValue`.

This is now a real repeatable flow, not just a staging-only experiment.

## Why the bundle-derived path works

The dumped protocol bundles such as:

- `codex_app_server_protocol.schemas.json`
- `codex_app_server_protocol.v2.schemas.json`

contain the authoritative shared `definitions` graph for each protocol
generation.

That matters because the earlier "generate one Swift file per individual schema
root" approach re-emitted shared definitions in every output file and caused
large duplicate-type explosions when those files were compiled together.

The direct bundle file still is not a good `quicktype` input on its own,
because `quicktype` does not expand a top-level schema that is basically just a
container object plus a big `definitions` map.

The fix is to derive a synthetic top-level schema that:

- keeps the original `definitions` map intact
- exposes only the selected root definitions we care about as normal
  top-level properties

That lets `quicktype` see one consolidated reachable graph, so shared types are
emitted once instead of once per file.

## The repeatable flow

The repo now standardizes this pipeline in
`scripts/generate-wire-types.sh`:

1. derive a quicktype-friendly schema from the bundled Codex protocol dump
2. generate consolidated Swift wire types with `quicktype`
3. patch dynamic `Any` holes to `CodexWireJSONValue`
4. typecheck the patched output with Swift 6 mode

The helpers are:

- `scripts/derive_quicktype_schema.py`
- `scripts/patch_quicktype_swift_any.py`
- `scripts/generate-wire-types.sh`

## Output layout

Generated artifacts stay outside compiled package sources for now.

Current staging paths:

- derived schemas:
  - `tmp/derived-schemas/<schema-version>/`
- raw quicktype output:
  - `tmp/quicktype-wire/<schema-version>/raw/`
- patched Swift output:
  - `tmp/quicktype-wire/<schema-version>/patched/`

This keeps the raw and patched artifacts separate, which is useful when
inspecting upstream schema changes or quicktype regressions.

## Current generated batch

The default generated batch currently stages against the local experimental
`v0.128.0` schema dump:

- `SCHEMA_VERSION=v0.128.0`
- promoted output:
  `Sources/SwiftASB/Generated/CodexWire/Latest/CodexLifecycleV2Batch+JSONValue.swift`

The promoted `Latest` snapshot is intentionally not swapped blindly just
because staging generation succeeds. The v0.128 experimental dump keeps
`permissionProfile`, adds `activePermissionProfile`, adds request-side
`permissions` profile selection, and removes older `GhostCommit` and
`ReadOnlyAccess` generated definitions. Promote generated changes only after
classifying public, observable-only, and internal effects.

## Compatibility Shim Policy

SwiftASB's Codex CLI support window may widen or narrow as app-server schemas
move, so temporary compatibility shims are expected. They must stay explicit,
tested, and removable.

When adding a compatibility shim:

1. Put the shim in a dedicated hand-owned file, not inside the promoted
   generated batch.
2. Name the older and newer wire shapes it bridges.
3. Add tests for every supported shape in the current support window.
4. Document the removal trigger in the shim comment and in maintainer docs.
5. Revisit the shim whenever the compatibility window advances.

When the oldest affected Codex CLI minor drops out of the documented support
window, remove the shim in the same change that advances the window unless a
newer live-runtime probe proves the older shape can still appear.

There are currently no hand-owned generated-wire compatibility shims for
versioned schema drift. `CodexWireInitializeResponse.swift` remains hand-owned
because the bundled v2 schema still does not expose `InitializeResponse`.

### V2 lifecycle batch

The current v2 lifecycle batch is no longer just the minimal bootstrap slice.
It now includes:

- bootstrap requests and responses:
  - `InitializeParams`
  - `ThreadStartParams`
  - `ThreadStartResponse`
  - `ThreadCompactStartParams`
  - `ThreadCompactStartResponse`
  - `ThreadRollbackParams`
  - `ThreadRollbackResponse`
  - `ThreadSetNameParams`
  - `ThreadSetNameResponse`
  - `ThreadMetadataUpdateParams`
  - `ThreadMetadataUpdateResponse`
  - `ThreadTurnsListParams`
  - `ThreadTurnsListResponse`
  - `TurnStartParams`
  - `TurnStartResponse`
- app-wide capability requests and responses:
  - `ModelListParams`
  - `ModelListResponse`
  - `ListMcpServerStatusParams`
  - `ListMcpServerStatusResponse`
- thread lifecycle notifications:
  - `ThreadStartedNotification`
  - `ThreadStatusChangedNotification`
  - `ThreadNameUpdatedNotification`
  - `ThreadTokenUsageUpdatedNotification`
  - `ThreadArchivedNotification`
  - `ThreadUnarchivedNotification`
  - `ThreadClosedNotification`
- turn lifecycle notifications:
  - `TurnStartedNotification`
  - `TurnPlanUpdatedNotification`
  - `TurnDiffUpdatedNotification`
  - `TurnCompletedNotification`
- item and reasoning notifications:
  - `ItemStartedNotification`
  - `ItemCompletedNotification`
  - `ItemGuardianApprovalReviewStartedNotification`
  - `ItemGuardianApprovalReviewCompletedNotification`
  - `PlanDeltaNotification`
  - `ReasoningTextDeltaNotification`
  - `ReasoningSummaryPartAddedNotification`
  - `ReasoningSummaryTextDeltaNotification`
  - `AgentMessageDeltaNotification`
- tooling and auxiliary lifecycle notifications:
  - `CommandExecutionOutputDeltaNotification`
  - `CommandExecOutputDeltaNotification`
  - `FileChangeOutputDeltaNotification`
  - `FileChangePatchUpdatedNotification`
  - `McpToolCallProgressNotification`
  - `ModelVerificationNotification`
  - `ModelReroutedNotification`
  - `ServerRequestResolvedNotification`
  - `HookStartedNotification`
  - `HookCompletedNotification`
  - `RawResponseItemCompletedNotification`
  - `ContextCompactedNotification`
  - `ExternalAgentConfigImportCompletedNotification`
  - `GuardianWarningNotification`
  - `WarningNotification`
  - `ErrorNotification`
- guardian action requests and responses:
  - `ThreadApproveGuardianDeniedActionParams`
  - `ThreadApproveGuardianDeniedActionResponse`

`InitializeParams` is included here because it exists in the v2 bundle and is
still useful as part of the consolidated lifecycle graph.

The v0.124 and v0.125 dumps also contain endpoint families that are
intentionally not in the promoted batch yet, including device-key signing,
marketplace removal and upgrade, and add-credits email nudges. Those are
account-management or marketplace surfaces,
not first interactive lifecycle or app-wide capability surfaces.

### Hand-owned initialize compatibility shim

The current dumped v2 bundle does not expose `InitializeResponse`, so that one
type is now kept as a small hand-owned Swift file alongside the generated v2
snapshot:

- `CodexWireInitializeResponse`

That is an intentional compatibility shim, not a reason to keep carrying a
second generated v1 batch that duplicates otherwise identical startup types.

## The dynamic JSON problem

The remaining problem was not that `quicktype` was unusable. It was that a
small number of intentionally loose schema surfaces generated as `Any`, which
breaks `Equatable` synthesis and Swift 6 `Sendable`.

For the current widened lifecycle batch, the meaningful dynamic surfaces are
still concentrated in a small number of fields:

- `config`
- hook `event`
- tool-call `arguments`
- tool-call `outputSchema`
- plan-update `tools`
- MCP result `meta`
- MCP result `content`
- MCP result `structuredContent`

Those are now patched to `CodexWireJSONValue`.

## `CodexWireJSONValue`

The patch helper injects:

- `CodexWireJSONValue: Codable, Equatable, Sendable`

with cases for:

- `null`
- `bool`
- `integer`
- `double`
- `string`
- `array`
- `object`

and rewrites the generated Swift file so the dynamic surfaces use
`CodexWireJSONValue` instead of `Any`.

That gives us a wire layer that still reflects the generated schema graph while
remaining valid for the conformances we care about.

## Validation status

The patched lifecycle batch typechecks cleanly with:

- `swiftc -swift-version 6 -typecheck`

That means the current repeatable flow is sufficient for a staged internal wire
layer.

## Current recommendation for package integration

Use the patched generated v2 Swift as internal wire scaffolding, and keep the
hand-owned `CodexWireInitializeResponse` shim next to it until upstream schema
convergence makes that file unnecessary.

Do not expose the generated types directly as the public library API. Keep the
generated layer behind a hand-shaped Swift facade that models the Cocoa-friendly
surface we actually want to ship.

## Next likely step

If this repo starts compiling generated wire models into `Sources/`, the first
promotion should come from the patched consolidated outputs, not from per-file
individual-schema generation.
