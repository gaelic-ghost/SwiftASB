# Contributing to SwiftASB

Use this guide when changing the package itself. The README is for package users and their agents; this file is for contributors maintaining SwiftASB source, tests, generated wire snapshots, DocC, release notes, and maintainer-facing workflow.

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

This guide is for contributors changing SwiftASB code, tests, generated-wire review, documentation, validation scripts, or release-facing material.

### Before You Start

Read `AGENTS.md`, `README.md`, and `ROADMAP.md` before editing. `AGENTS.md` owns maintainer guidance for Codex and other agents. `README.md` owns the user-facing package story. `ROADMAP.md` owns current status, release boundaries, and deferred work.

Treat `Package.swift` as the package structure source of truth. Treat `Sources/SwiftASB/Generated/CodexWire/Latest/` as internal generated scaffolding, not public API.

## Contribution Workflow

### Choosing Work

Start from a requested change, the roadmap, or a clearly scoped maintenance need. Keep the branch focused on one coherent outcome, such as a public API adjustment, a generated-wire refresh, a DocC pass, a test slice, or a docs split.

Do not promote generated schema additions to public API just because they exist upstream. First classify each new app-server schema family as public now, observable-only for now, or internal-only.

### Making Changes

Use a feature branch named with the `scope/slug` pattern. Keep commits focused and use scoped subjects such as `docs: simplify readme` or `tests: cover rollback markers`.

Prefer SwiftPM commands for package-structure edits when SwiftPM has a command for the job. For changes SwiftPM cannot express directly, edit `Package.swift` intentionally and keep the package graph explicit.

When touching public API, update the matching tests, DocC, README usage notes when user-visible, and roadmap status in the same branch. When touching generated wire code, use `scripts/generate-wire-types.sh` instead of hand-editing the promoted generated snapshot.

### Generated Wire Policy

Generated `CodexWire...` models are internal until a SwiftASB-owned public or observable surface gives them a real consumer-facing job.

When a generated family becomes public or observable, add representative fixture coverage through the package-owned boundary. Include the fields SwiftASB relies on and one harmless additive unknown field when the upstream payload is expected to stay forward-compatible.

Keep dumped local schemas under `codex-schemas/` untracked unless a maintainer explicitly asks to commit them. Keep temporary derived schemas and quicktype staging output under `tmp/` untracked.

## Local Setup

### Runtime Config

Use Swift 6.3 or newer on macOS 15 or newer.

```bash
swift package resolve
```

Install the local Codex CLI if you need real app-server coverage. SwiftASB discovers `codex` from `PATH`, common Homebrew locations, or the npm global prefix. Tests or apps that need a fixed binary can pass `CodexAppServer.Configuration.codexExecutableURL`.

### Runtime Behavior

Default tests use fake transports and do not require a live Codex subprocess. Live tests are opt-in because they launch the local Codex CLI in temporary workspaces and depend on the installed runtime.

Some live probes are observational because the local Codex runtime does not always force the same approval or history behavior from the same prompt. Deterministic approval coverage uses the real app-server with an isolated `CODEX_HOME` and a local mock Responses-compatible endpoint so the request, response, resolution, and turn-completion path can be asserted without calling the hosted OpenAI API.

The live file-scenario and rollback probes use disposable workspaces or non-ephemeral threads. They are useful release-confidence checks, but they should not be described as broader guarantees than they actually prove.

## Development Expectations

### Naming Conventions

Keep public names explicit and Swift-shaped. Preserve upstream names when they carry stable wire or persistence meaning, and avoid duplicate rename layers unless the meaning changes at a real package boundary.

Use `CodexAppServer` for app-server process and app-wide actions, `CodexThread` for conversation-scoped actions, and `CodexTurnHandle` for active-turn actions. Keep UI-shaped live mirrors as observable companions, not separate control paths.

### Accessibility Expectations

SwiftASB does not ship UI, but its observable companions are intended for SwiftUI and macOS app surfaces. When package behavior affects UI-facing state, make that state clear enough for downstream apps to label, announce, inspect, and reconcile without reading raw transport details.

### Verification

Run the package checks before committing package changes:

```bash
swift build
swift test
```

Run repo-maintenance validation before release, CI wrapper, maintainer guidance, or tooling changes:

```bash
bash scripts/repo-maintenance/validate-all.sh
```

Validate DocC through Xcode when documentation changes:

```bash
xcodebuild docbuild -scheme SwiftASB -destination generic/platform=macOS -derivedDataPath tmp/xcode-docc/DerivedData
```

Check whitespace before staging:

```bash
git diff --check
```

### Live Codex Checks

Use the live integration runner when the local Codex CLI is available and the change needs real-runtime confidence:

```bash
scripts/run-live-codex-integration-tests.sh
```

The default mode runs the full local release gate, including the ordinary Swift package test suite and the maintained live Codex probe set. Focused modes include `smoke`, `transport`, `capability`, `thread`, `turn`, `approval`, `behavior-matrix`, `server-requests`, `file-scenario`, `rollback`, `same-thread`, and `all`.

Other useful wrappers:

```bash
scripts/run-live-codex-release-gate.sh
scripts/run-live-codex-approval-probe.sh
scripts/run-live-codex-behavior-matrix.sh
scripts/run-live-codex-server-request-probes.sh
scripts/run-live-codex-file-scenario.sh
scripts/run-live-codex-rollback-scenario.sh
```

Reports default to `tmp/live-codex-reports/`. Use `SWIFTASB_LIVE_CODEX_REPORT_DIR` for another report directory, `SWIFTASB_LIVE_CODEX_BIN` for a specific Codex executable, `SWIFTASB_LIVE_CODEX_TIMEOUT_SECONDS` to override per-operation live probe timeouts, and `SWIFTASB_LIVE_CODEX_KEEP_WORKSPACES=1` to preserve temporary workspaces for debugging.

### Maintainer Scripts

Refresh Codex schema-derived wire types through the maintainer entrypoint:

```bash
scripts/generate-wire-types.sh
```

Dump the installed Codex CLI app-server schemas when a new CLI version needs review:

```bash
scripts/dump-codex-schemas.sh
```

Run the shared repo-maintenance sync entrypoint for future managed refreshes:

```bash
bash scripts/repo-maintenance/sync-shared.sh
```

Start a standard release from a feature branch or isolated worktree with a clean committed worktree:

```bash
bash scripts/repo-maintenance/release.sh --mode standard --version vX.Y.Z
```

Standard release mode runs repo-maintenance validation, bumps release references, then runs the full local release gate before it tags, pushes, opens the release PR, watches remote CI, merges, fast-forwards `main`, and creates the GitHub release.

## Pull Request Expectations

PRs should identify the changed surface, explain any public API or docs boundary decision, and list the validation commands that ran.

Keep README product-facing. Keep contributor workflow, local validation, live test flags, schema generation, DocC build commands, and release-prep details in this file unless the README user needs them to consume the package.

## Communication

Surface uncertainty early when a change widens public API, changes ownership, adds a dependency, changes release boundaries, or makes live Codex runtime behavior sound more stable than it is.

Record settled decisions in `ROADMAP.md`, DocC, maintainer docs, or this guide so future contributors do not need chat history to preserve them.

## License and Contribution Terms

SwiftASB is licensed under the Apache License, Version 2.0. Contributions are accepted under the same license terms unless maintainers state a different written agreement before the work lands.
