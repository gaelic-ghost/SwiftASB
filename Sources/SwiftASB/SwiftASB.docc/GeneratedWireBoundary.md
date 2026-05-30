# Generated Wire Boundary

Keep generated Codex schema output internal and expose deliberate Swift models publicly.

## Overview

SwiftASB derives internal wire types from the bundled Codex app-server v2 schema. Those generated types are useful for protocol correctness, but they are not the package's public API.

Public callers should depend on the hand-owned Swift models exposed by ``CodexAppServer``, ``CodexThread``, ``CodexTurnHandle``, and the event/request types in this documentation catalog.

## Why The Boundary Exists

The app-server schema can add transport fields, notification families, and endpoint-specific details faster than a library should expose them as stable public Swift API. Keeping generated wire types internal lets SwiftASB:

- refresh schema coverage without turning every upstream addition into a public promise
- promote only the endpoint and notification families that have a clear consumer job
- keep Swift naming and value shapes intentional
- preserve compatibility shims internally while avoiding stringly public fallbacks

## Current Promotion Rule

Generated types are promoted to public wrappers only when there is a clear supported use case.

Examples currently promoted through hand-owned public types include:

- model catalog snapshots through ``CodexAppServer/listModels(_:)``
- MCP server status snapshots through ``CodexMCP/statusSnapshot()``
- MCP resource reads through ``CodexMCP/readResource(server:uri:threadID:)``
- hook diagnostics snapshots through ``CodexAppServer/listHooks(_:)``
- app-wide observable inventory through ``CodexAppServer/makeInventory(configuration:)``
- thread naming through ``CodexThread/setName(_:)``
- thread archive-state actions through ``CodexThread/archive()`` and ``CodexThread/unarchive()``
- thread metadata patches through ``CodexThread/updateMetadata(gitInfo:)``
- thread rollback through ``CodexThread/rollbackLastTurns(_:)``
- thread shell commands through ``CodexThread/sendShellCommand(_:)`` with a high-impact feature-policy gate
- code review starts through ``CodexThread/startReview(against:placement:)`` with hand-owned review subjects and placement names
- file and command deltas as inputs to ``CodexThread/RecentFiles`` and ``CodexThread/RecentCommands``
- passive diagnostics through ``CodexAppServer/diagnosticEvents()``

Other generated notifications and fields can remain internal until they support a public handle, event, observable companion, or diagnostic story.

## Maintainer Workflow

Use `scripts/generate-wire-types.sh` as the maintainer entrypoint for schema derivation, quicktype generation, dynamic JSON patching, and staged Swift validation.

Keep dumped schema artifacts under `codex-schemas/` untracked unless maintainers explicitly decide otherwise. Keep temporary generated staging output under `tmp/` untracked. Promote only the reviewed v2 snapshot into `Sources/SwiftASB/Generated/CodexWire/Latest/`.

## Topics

### Public Surface

- ``CodexAppServer``
- ``CodexThread``
- ``CodexTurnHandle``

### Diagnostics

- ``CodexAppServerError``
