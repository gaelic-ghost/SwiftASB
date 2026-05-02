# Contributing to SwiftASB

Use this guide when changing the package itself. The README is for Swift and SwiftUI developers who want to consume SwiftASB; this file is for contributors maintaining the package, its generated wire boundary, its tests, and its release-facing docs.

## Table of Contents

- [Overview](#overview)
- [Contribution Workflow](#contribution-workflow)
- [Local Setup](#local-setup)
- [Development Expectations](#development-expectations)
- [Pull Request Expectations](#pull-request-expectations)
- [Communication](#communication)
- [License and Contribution Terms](#license-and-contribution-terms)

## Overview

### Who This Guide Is For

This guide is for contributors working on SwiftASB source, tests, generated wire snapshots, DocC, README, roadmap, or release-readiness material.

### Before You Start

Read `AGENTS.md`, `README.md`, and `ROADMAP.md` before making package changes. Treat `Package.swift` as the package structure source of truth, and treat `Sources/SwiftASB/Generated/CodexWire/Latest/` as generated internal scaffolding rather than public API.

For SwiftPM behavior, the package relies on the documented Swift Package Manager model: the manifest describes package products, targets, dependencies, supported platforms, and Swift language mode. SwiftASB keeps that boundary explicit so source, tests, and docs stay aligned with the package graph.

## Contribution Workflow

### Choosing Work

Start from the current roadmap or an explicitly requested change. Keep work scoped to one coherent outcome, such as a public API promotion, a generated-wire refresh, a DocC improvement, a test slice, or a docs split.

Do not promote generated schema additions to public API just because they exist upstream. Classify new Codex app-server schema families as public now, observable-only for now, or internal-only before exposing them.

### Making Changes

Use a feature branch named with the `scope/slug` pattern. Prefer small, reviewable commits with scoped messages such as `docs: split contributing workflow` or `tests: cover rollback markers`.

Keep package structure changes in `Package.swift`, and prefer SwiftPM commands for structural edits when a command exists. Keep temporary schema dumps under `codex-schemas/` and generated staging output under `tmp/` unless a maintainer explicitly decides otherwise.

When touching public API, update the matching tests, README usage notes, DocC pages, and roadmap status in the same branch. When touching generated wire code, use `scripts/generate-wire-types.sh` instead of hand-editing the promoted generated snapshot.

### Generated Schema Promotion Policy

Generated `CodexWire...` models are internal scaffolding until a SwiftASB-owned surface gives them a consumer-facing job. When a generated schema family graduates into public API or observable companion behavior, the same PR must add at least one representative fixture test that decodes or encodes the promoted shape through the package-owned boundary.

That fixture should cover the exact request, response, notification, or server-request family being promoted; include the fields SwiftASB relies on; and include one harmless additive unknown field when the upstream payload is expected to remain forward-compatible. Keep the fixture close to the protocol or public-client tests that own the behavior, and update `ROADMAP.md` with the public/observable/internal classification decision.

### Asking For Review

A change is ready for review when the relevant validation commands pass, docs reflect the actual shipped behavior, and the PR explains what changed and what was verified. If a live Codex runtime behavior is nondeterministic, say that plainly in the PR body instead of presenting a probe as a hard release gate.

## Local Setup

### Runtime Config

Use Swift 6.3 or newer on macOS 15 or newer. Install the local Codex CLI if you need to run the package against a real app-server or run opt-in live tests.

SwiftASB discovers the Codex executable from `PATH`, common Homebrew locations, or the npm global prefix. Tests or apps that need a fixed binary can pass `CodexAppServer.Configuration.codexExecutableURL`.

### Runtime Behavior

Default tests use fake transports and do not require a live Codex subprocess. Live tests are opt-in because they launch the local Codex CLI in temporary workspaces and depend on the installed runtime.

The live approval-path probe is observational. The current Codex runtime does not reliably force an approval request for a chosen prompt, so that test can complete without observing an approval request and still be useful.

The deterministic app-server approval test uses a different shape. It still launches the installed `codex app-server`, but it seeds an isolated `CODEX_HOME` whose `model_provider` points at a local mock Responses-compatible endpoint. The mock endpoint emits an upstream-style shell-command tool call, so the real app-server reaches a command item plus `waitingOnApproval`, delivers `item/commandExecution/requestApproval`, accepts SwiftASB's JSON-RPC response, emits `serverRequest/resolved`, completes the command, and finishes the turn without calling the hosted OpenAI API. This path does not require an OpenAI API key and should be the preferred regression coverage for deterministic approval setup.

The live file-scenario probe is also observational around approval shape, but deterministic around filesystem outcome. It creates an isolated temporary workspace, asks the real Codex CLI to create, edit, and delete files across multiple turns, accepts approval requests when the runtime raises them, and verifies the final files on disk.

The live rollback probe uses a disposable non-ephemeral thread with harmless text-only turns. It verifies that `rollbackLastTurns(1)` succeeds against the real app-server and that SwiftASB records the local rollback marker for the removed trailing turn.

## Development Expectations

### Naming Conventions

Keep public names explicit and Swift-shaped. Preserve upstream names when they describe stable wire or persistence meaning, and avoid rename-and-copy layers unless the meaning actually changes at a boundary.

Use `CodexAppServer` for connection-wide actions, `CodexThread` for thread-scoped actions, and `CodexTurnHandle` for active-turn actions. Keep app-wide capability snapshots on `CodexAppServer`, and keep UI-shaped live mirrors as observable companions rather than new control paths.

### Accessibility Expectations

SwiftASB does not ship UI, but its observable companions are intended for SwiftUI and macOS app surfaces. When a package change affects UI-facing semantics, make the state clear enough for downstream apps to label, announce, inspect, and reconcile without reading raw transport details.

### Verification

Run the package checks before committing package changes:

```bash
swift build
swift test
```

Run the repo-maintenance validation before release, CI wrapper, maintainer guidance, or tooling changes:

```bash
bash scripts/repo-maintenance/validate-all.sh
```

Validate DocC through Xcode when documentation changes:

```bash
xcodebuild docbuild -scheme SwiftASB -destination generic/platform=macOS -derivedDataPath tmp/xcode-docc/DerivedData
```

Useful opt-in live checks:

```bash
env SWIFTASB_ENABLE_LIVE_CODEX_TRANSPORT_TESTS=1 swift test
env SWIFTASB_ENABLE_LIVE_CODEX_CAPABILITY_TESTS=1 swift test
env SWIFTASB_ENABLE_LIVE_CODEX_THREAD_MANAGEMENT_TESTS=1 swift test
env SWIFTASB_ENABLE_LIVE_CODEX_SINGLE_TURN_TESTS=1 swift test
env SWIFTASB_ENABLE_LIVE_CODEX_CROSS_THREAD_TESTS=1 swift test
env SWIFTASB_ENABLE_LIVE_CODEX_APPROVAL_PROBE_TESTS=1 swift test
env SWIFTASB_ENABLE_LIVE_CODEX_FILE_SCENARIO_TESTS=1 swift test
env SWIFTASB_ENABLE_LIVE_CODEX_ROLLBACK_TESTS=1 swift test
env SWIFTASB_ENABLE_LIVE_CODEX_SAME_THREAD_TESTS=1 swift test
```

Run only the deterministic approval/server-request coverage and the exploratory
approval probe:

```bash
scripts/run-live-codex-approval-probe.sh
```

Run only the multi-turn live file scenario:

```bash
scripts/run-live-codex-file-scenario.sh
```

That wrapper writes the live scenario diagnostic report to
`tmp/live-codex-reports/live-file-mutation-scenario.json`.

Run only the disposable live rollback scenario:

```bash
scripts/run-live-codex-rollback-scenario.sh
```

Use the generated-wire entrypoint when refreshing Codex schema-derived models:

```bash
scripts/generate-wire-types.sh
```

Dump the installed Codex CLI's app-server schemas when a new CLI version is
available:

```bash
scripts/dump-codex-schemas.sh
```

The dump script reads `codex --version`, writes the current schema bundle under
`codex-schemas/vX.Y.Z/` when that version is missing, and leaves existing dumps
untouched unless `--force` is passed. Set `CODEX_BIN` to test a specific Codex
CLI executable and `CODEX_SCHEMA_ROOT` to write into a temporary parent
directory.

Check whitespace before staging:

```bash
git diff --check
```

### Maintainer Scripts

SwiftASB uses `scripts/repo-maintenance/` as the local-first maintainer surface. GitHub Actions stays a thin wrapper around these scripts, and branch protection should require the `validate` check context from `.github/workflows/validate-repo-maintenance.yml`.

Use the shared sync entrypoint for future managed repo-maintenance refreshes:

```bash
bash scripts/repo-maintenance/sync-shared.sh
```

Use the release entrypoint from a feature branch or isolated worktree with a clean committed worktree:

```bash
bash scripts/repo-maintenance/release.sh --mode standard --version vX.Y.Z
```

## Pull Request Expectations

PRs should identify the changed surface, explain any public API or docs boundary decision, and list the validation commands that ran. Use the `documentation` label for docs-only work and a more specific label when the code surface is the stronger signal.

Keep README product-facing. Keep contributor workflow, local validation, live test flags, schema generation, DocC build commands, and release-prep details in this file unless the README user needs them to consume the package.

## Communication

Surface uncertainty early when a change starts widening public API, changing the ownership model, adding a dependency, or making live Codex runtime behavior sound more stable than it is.

When a decision is settled, record it in `ROADMAP.md`, DocC, or this guide so future contributors do not need chat history to preserve it.

## License and Contribution Terms

SwiftASB is licensed under `FSL-1.1-ALv2`. Contributions are accepted under the same license terms unless maintainers state a different written agreement before the work lands.
