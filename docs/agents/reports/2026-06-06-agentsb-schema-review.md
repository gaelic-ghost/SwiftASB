# AgentSB Schema Review

## Summary

- Reviewed Codex CLI compatibility window: `0.135.x`.
- Latest discovered schema dump: `v0.137.0`.
- Promoted generated wire files: 2.
- Git branch at inspection time: `agents/agentsb-maintenance`.

## Codex CLI Schema State

| Dump | Variant | JSON files |
| --- | --- | --- |
| `v0.124.0` | experimental | 225 |
| `v0.125.0` | experimental | 227 |
| `v0.128.0` | experimental | 269 |
| `v0.129.0` | experimental | 290 |
| `v0.130.0` | experimental | 286 |
| `v0.132.0` | experimental | 297 |
| `v0.133.0` | experimental | 302 |
| `v0.135.0` | experimental | 304 |
| `v0.137.0` | experimental | 312 |

## Schema Diff Evidence

- Compared `v0.135.0` to `v0.137.0`.
- Added JSON files: 8.
- Removed JSON files: 0.
- Changed JSON files: 38.
- Unchanged JSON files: 266.
- Added: `v2/RemoteControlClientsListParams.json`, `v2/RemoteControlClientsListResponse.json`, `v2/RemoteControlClientsRevokeParams.json`, `v2/RemoteControlClientsRevokeResponse.json`, `v2/RemoteControlPairingStartParams.json`, `v2/RemoteControlPairingStartResponse.json`, `v2/SkillsExtraRootsSetParams.json`, `v2/SkillsExtraRootsSetResponse.json`.
- Changed: `ClientRequest.json`, `PermissionsRequestApprovalParams.json`, `ServerNotification.json`, `ServerRequest.json`, `codex_app_server_protocol.schemas.json`, `codex_app_server_protocol.v2.schemas.json`, `v2/AccountRateLimitsUpdatedNotification.json`, `v2/ConfigReadResponse.json`, ... 30 more.

## Boundary Review

- Report skeleton only: classify any new schema families as `public now`, `observable-only`, or `internal-only` before promotion.
- Do not expose generated `CodexWire...` models as public Swift API without a hand-owned SwiftASB boundary.

## Documentation Drift

| Document | Present | Bytes |
| --- | --- | --- |
| `AGENTS.md` | true | 9696 |
| `README.md` | true | 8375 |
| `CONTRIBUTING.md` | true | 8580 |
| `ROADMAP.md` | true | 123500 |
| `docs/maintainers/*.md` | true | 12 files |

## Recommended Probes

- Run `swift build` and `swift test` after package behavior changes.
- Run `scripts/run-live-codex-integration-tests.sh smoke` for runtime confidence after schema-boundary changes.
- Run `xcodebuild docbuild -scheme SwiftASB -destination generic/platform=macOS -derivedDataPath tmp/xcode-docc/DerivedData` after DocC changes.

## Human Decisions

- Decide whether any newly dumped schema family deserves public API, observable-only support, or internal-only coverage.
- Decide whether README, CONTRIBUTING, ROADMAP, or DocC need compatibility-window updates.

## Evidence

- Repository root: `/Users/galew/Workspace/gaelic-ghost/SwiftASB`.
- Git dirty state: `False`.
- Git upstream: `origin/agents/agentsb-maintenance`.
- Reviewed window source: `ROADMAP.md`.
- Promoted wire files:
  - `Sources/SwiftASB/Generated/CodexWire/Latest/CodexLifecycleV2Batch+JSONValue.swift` (222811 bytes)
  - `Sources/SwiftASB/Generated/CodexWire/Latest/CodexWireInitializeResponse.swift` (841 bytes)

## Agent Notes

- AI model: `gpt-5.5`.

AgentSB maintainer notes:

- Repo: `/Users/galew/Workspace/gaelic-ghost/SwiftASB`
- Branch: `agents/agentsb-maintenance`
- Upstream: `origin/agents/agentsb-maintenance`
- Working tree: clean

Inspection scope:

- Reviewed Codex CLI roadmap window: `0.135.x`
- Source: `ROADMAP.md`
- Available experimental schema dumps: `v0.124.0` through `v0.137.0`
- Latest observed dump: `v0.137.0`, 312 JSON files

Schema growth trend:

- `v0.124.0`: 225 JSON files
- `v0.135.0`: 304 JSON files
- `v0.137.0`: 312 JSON files
- Net increase from `v0.124.0` to `v0.137.0`: +87 files

Promoted generated wire files observed:

- `Sources/SwiftASB/Generated/CodexWire/Latest/CodexLifecycleV2Batch+JSONValue.swift` — 222,811 bytes
- `Sources/SwiftASB/Generated/CodexWire/Latest/CodexWireInitializeResponse.swift` — 841 bytes

Boundary note:

- Generated wire snapshot changes are report-only unless explicitly classified against SwiftASB public API boundaries.
- No promotion recommendation is made from these facts alone.

Docs present:

- `AGENTS.md`
- `README.md`
- `CONTRIBUTING.md`
- `ROADMAP.md`

Maintainer docs available include plans for lifecycle, transport architecture, MCP configuration writing, thread history/storage, quicktype codegen, and v1 public API audit/inventory.
