# AgentSB Schema Review

## Summary

- Reviewed Codex CLI compatibility window: `0.137.x`.
- Latest discovered schema dump: `v0.138.0`.
- Promoted generated wire files: 2.
- Git branch at inspection time: `maintenance/codex-schema-refresh`.

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
| `v0.138.0` | experimental | 316 |

## Schema Diff Evidence

- Compared `v0.137.0` to `v0.138.0`.
- Added JSON files: 4.
- Removed JSON files: 0.
- Changed JSON files: 35.
- Unchanged JSON files: 277.
- Added: `v2/GetAccountTokenUsageResponse.json`, `v2/RemoteControlPairingStatusParams.json`, `v2/RemoteControlPairingStatusResponse.json`, `v2/TurnModerationMetadataNotification.json`.
- Changed: `ClientRequest.json`, `ServerNotification.json`, `codex_app_server_protocol.schemas.json`, `codex_app_server_protocol.v2.schemas.json`, `v2/AccountUpdatedNotification.json`, `v2/CollaborationModeListResponse.json`, `v2/ConfigReadResponse.json`, `v2/ConfigRequirementsReadResponse.json`, ... 27 more.

## Boundary Review

- Report skeleton only: classify any new schema families as `public now`, `observable-only`, or `internal-only` before promotion.
- Do not expose generated `CodexWire...` models as public Swift API without a hand-owned SwiftASB boundary.

## Documentation Drift

| Document | Present | Bytes |
| --- | --- | --- |
| `AGENTS.md` | true | 17089 |
| `README.md` | true | 8375 |
| `CONTRIBUTING.md` | true | 8580 |
| `ROADMAP.md` | true | 127499 |
| `docs/maintainers/*.md` | true | 13 files |

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
- Git upstream: `none`.
- Reviewed window source: `ROADMAP.md`.
- Promoted wire files:
  - `Sources/SwiftASB/Generated/CodexWire/Latest/CodexLifecycleV2Batch+JSONValue.swift` (229429 bytes)
  - `Sources/SwiftASB/Generated/CodexWire/Latest/CodexWireInitializeResponse.swift` (841 bytes)
