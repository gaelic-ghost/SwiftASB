# SwiftASB

SwiftASB helps Swift apps work with the local Codex app-server without making app builders deal with Codex's raw app-server messages directly.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Agent Guidance](#agent-guidance)
- [Development](#development)
- [Repo Structure](#repo-structure)
- [Release Notes](#release-notes)
- [License](#license)

## Overview

### Status

SwiftASB has a supported v1 public API for the core local Codex app-server lifecycle. `v1.1.4` is the current released baseline.

### What This Project Is

TBD

### Motivation

TBD

## Quick Start

Add SwiftASB from the GitHub package URL:

https://github.com/gaelic-ghost/SwiftASB

Use release `v1.1.4` or newer unless your project intentionally pins an older version.

You also need a local Codex CLI installation with app-server support. SwiftASB looks for `codex` in the usual command-line locations, and apps can provide an exact executable path when they need stricter control.

For copy-pasteable startup code, open the DocC getting-started guide:

- `Sources/SwiftASB/SwiftASB.docc/GettingStartedWithSwiftASB.md`

## Usage

Use SwiftASB when an app needs to show what Codex is doing right now, keep recent command and file activity visible, answer interactive requests, or build SwiftUI state around a running Codex turn.

For app-wide sidebars and launchers, `CodexAppServer.makeLibrary()` provides observable stored-thread lists, cwd or repository grouping, refresh actions, library-local selection state, and app-wide model, MCP, and hook diagnostics snapshots. Thread handles can also name, archive, unarchive, compact, and roll back stored threads through thread-scoped methods.

Use `CodexAppServer.fs` when a sandboxed client needs filesystem metadata, directory listings, file bytes, file discovery, fuzzy file lookup, or file-change watches through the Codex app-server instead of reading local disk directly. File-discovery hits include match kind, matched character ranges, and ranking reasons for picker highlighting and result explanations. `CodexWorkspace` carries app-server-owned workspace permission selections, active permission-profile provenance, and runtime filesystem/network permission facts for started threads and turns. Use `CodexAppServer.config` for effective config reads, and `CodexAppServer.extensions` for app, skill, plugin, and collaboration-mode inventory.

Use `CodexAppServer.ThreadListQD`, `CodexFS.FileDiscoveryQD`, `CodexThread.HistoryWindowQD`, `CodexThread.RecentFilesQD`, and `CodexThread.RecentCommandsQD` when a client needs to preserve repeatable list, file-discovery, history-window, or recent-activity intent without depending on Core Data, SwiftData, direct filesystem reads, or raw app-server paging details.

The generated Codex wire models are internal to this package. App code should use SwiftASB's public Swift types instead.

For implementation details, start with the DocC catalog under `Sources/SwiftASB/SwiftASB.docc/`.

## Agent Guidance

Agents helping someone adopt SwiftASB should use the `swiftasb-skills` plugin from `socket` for SwiftASB-specific workflow guidance:

https://github.com/gaelic-ghost/socket/tree/main/plugins/swiftasb-skills

Use those skills for adoption fit, integration-shape choices, SwiftUI-facing state, and runtime diagnostics. Use Apple development guidance for SwiftUI, AppKit, Xcode, and Apple framework behavior.

## Development

This README is for package users and their agents.

Contributor setup, validation, generated-wire refreshes, live test flags, DocC checks, release prep, and PR expectations live in [CONTRIBUTING.md](./CONTRIBUTING.md).

Agent-facing maintainer guidance lives in [AGENTS.md](./AGENTS.md).

## Repo Structure

```text
.
├── AGENTS.md
├── CONTRIBUTING.md
├── Package.swift
├── README.md
├── ROADMAP.md
├── Sources/
│   └── SwiftASB/
│       ├── Generated/
│       ├── History/
│       ├── Protocol/
│       ├── Public/
│       ├── SwiftASB.docc/
│       └── Transport/
├── Tests/
│   └── SwiftASBTests/
└── scripts/
    ├── generate-wire-types.sh
    ├── run-live-codex-integration-tests.sh
    └── repo-maintenance/
```

## Release Notes

`ROADMAP.md` tracks milestone status and release-facing work. Git tags and GitHub releases are the source of truth for published versions.

## License

SwiftASB is licensed under the Apache License, Version 2.0. See [LICENSE](./LICENSE).
