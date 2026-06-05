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
| `ROADMAP.md` | true | 120802 |
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
- Git dirty state: `True`.
- Git upstream: `origin/agents/agentsb-maintenance`.
- Reviewed window source: `ROADMAP.md`.
- Promoted wire files:
  - `Sources/SwiftASB/Generated/CodexWire/Latest/CodexLifecycleV2Batch+JSONValue.swift` (222811 bytes)
  - `Sources/SwiftASB/Generated/CodexWire/Latest/CodexWireInitializeResponse.swift` (841 bytes)

## Agent Notes

AgentSB maintainer notes:

- Repo is dirty only from new report artifacts under `docs/agents/reports/`:
  - `2026-06-05-agentsb-maintenance-auto-apply-safe.md`
  - `2026-06-05-agentsb-schema-review-2.md`
  - `2026-06-05-agentsb-schema-review.md`
- Reviewed Codex CLI window: `0.135.x` from `ROADMAP.md`.
- Experimental schema dumps observed from `v0.124.0` through `v0.137.0`; latest dump has `312` JSON files.
- Promoted wire files present:
  - `Sources/SwiftASB/Generated/CodexWire/Latest/CodexLifecycleV2Batch+JSONValue.swift`
  - `Sources/SwiftASB/Generated/CodexWire/Latest/CodexWireInitializeResponse.swift`
- Docs baseline is present (`AGENTS.md`, `README.md`, `CONTRIBUTING.md`, `ROADMAP.md`) plus multiple maintainer plans.
- No boundary classification was provided here, so do not treat generated schema/output as promotable by default.
