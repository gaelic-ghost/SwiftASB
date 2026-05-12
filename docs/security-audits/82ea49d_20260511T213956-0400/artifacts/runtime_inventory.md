# Runtime Inventory

Scan target: repository-wide checked-out SwiftASB repository at commit `82ea49d`.

## Product Runtime Areas

- Package manifest: `Package.swift`.
- Public Swift API: `Sources/SwiftASB/Public/*.swift`.
- Internal protocol layer: `Sources/SwiftASB/Protocol/*.swift`.
- Internal transport layer: `Sources/SwiftASB/Transport/*.swift`.
- Local history storage: `Sources/SwiftASB/History/ThreadHistoryStore.swift`.
- Internal generated Codex wire snapshot: `Sources/SwiftASB/Generated/CodexWire/Latest/*.swift`.
- DocC public usage docs: `Sources/SwiftASB/SwiftASB.docc/*.md`.

## Privileged Or Sensitive Boundaries

- Process launch: `CodexCLIExecutableResolver` and `CodexAppServerTransport`.
- JSON-RPC framing and ID correlation: `LineDelimitedDataBuffer`, `CodexRPCEnvelope`, `CodexAppServerProtocol`, `CodexRPCRequestID`.
- Command execution via Codex app-server: `executeCommand(_:)`, Git observability helpers, and live probe scripts.
- Filesystem access through app-server: `CodexFS` and `fs/*` request wrappers.
- Permission and approval flow: `CodexInteractiveRequests`, `CodexTurnHandle.respond`, and `CodexAppServer.respond`.
- MCP resource/status surfaces: `CodexAppServer+MCP.swift`.
- Hook/plugin/skill/app inventory: `CodexAppServer+Hooks.swift`, `CodexAppServer+CodexExtensions.swift`.
- Local persistence: `ThreadHistoryStore`.
- Maintainer tooling: `scripts/*.sh`, `scripts/*.py`, `scripts/repo-maintenance/**`.

## Source And Sink Search Summary

- Process/shell sinks: `Process` in transport resolver, app-server launch, `command/exec` wrappers, shell scripts.
- Filesystem sinks: app-server `fs/read*` wrappers, schema dump/generation scripts, release/version-bump scripts.
- Network/resource sinks: MCP resource read, marketplace/plugin metadata, GitHub release tooling through `gh`.
- Parser/deserializer sinks: JSON-RPC envelope classification, generated wire decode, Python schema derivation/patching.
- Auth/permission controls: approval requests/responses, permissions approval scope, network policy amendments, sandbox/approval fields.

## Exclusions

- `Tests/` was used for targeted validation evidence but excluded from primary runtime coverage because test code is not shipped runtime code.
- `docs/`, media files, schema dumps under `codex-schemas/`, `tmp/`, `.build/`, and generated build outputs were excluded from primary runtime coverage unless they informed shipped behavior or maintainer workflow.
