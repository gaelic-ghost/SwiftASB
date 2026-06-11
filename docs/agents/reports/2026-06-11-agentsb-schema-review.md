# AgentSB Schema Review

## Summary

- Reviewed Codex CLI compatibility window: `0.139.x`.
- Latest discovered schema dump: `v0.139.0`.
- Promoted generated wire files: 2.
- Git branch at inspection time: `schema/codex-cli-0-139-refresh`.

## Codex CLI Schema State

| Dump | Variant | JSON files |
| --- | --- | --- |
| `v0.139.0` | experimental | 316 |

## Schema Diff Evidence

No schema dump diff was available for this report.

## Boundary Review

- Report skeleton only: classify any new schema families as `public now`, `observable-only`, or `internal-only` before promotion.
- Do not expose generated `CodexWire...` models as public Swift API without a hand-owned SwiftASB boundary.

## Documentation Drift

| Document | Present | Bytes |
| --- | --- | --- |
| `AGENTS.md` | true | 17089 |
| `README.md` | true | 8929 |
| `CONTRIBUTING.md` | true | 9007 |
| `ROADMAP.md` | true | 131779 |
| `docs/maintainers/*.md` | true | 13 files |

## Recommended Probes

- Run `swift build` and `swift test` after package behavior changes.
- Run `scripts/run-live-codex-integration-tests.sh smoke` for runtime confidence after schema-boundary changes.
- Run `xcodebuild docbuild -scheme SwiftASB -destination generic/platform=macOS -derivedDataPath tmp/xcode-docc/DerivedData` after DocC changes.

## Human Decisions

- Decide whether any newly dumped schema family deserves public API, observable-only support, or internal-only coverage.
- Decide whether README, CONTRIBUTING, ROADMAP, or DocC need compatibility-window updates.

## Evidence

- Repository root: `/Users/galew/.codex/worktrees/8d09/SwiftASB`.
- Git dirty state: `True`.
- Git upstream: `none`.
- Reviewed window source: `ROADMAP.md`.
- Promoted wire files:
  - `Sources/SwiftASB/Generated/CodexWire/Latest/CodexLifecycleV2Batch+JSONValue.swift` (234422 bytes)
  - `Sources/SwiftASB/Generated/CodexWire/Latest/CodexWireInitializeResponse.swift` (841 bytes)
