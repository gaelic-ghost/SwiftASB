# SwiftASB

*Faster-Than-Light Framework for Custom Codex Apps and Integrations in Swift*

Listen to the SwiftASB Codex apps promo clip:

<audio controls src="docs/media/swiftasb-codex-apps-promo.mp3"></audio>

[Download the promo clip](docs/media/swiftasb-codex-apps-promo.mp3)

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

SwiftASB is actively maintained and supported by Gale. Our current API is v1, and `v1.3.0` is the current and latest release.

### What This Project Is

SwiftASB is a native Swift client/runtime layer for AI coding agent app-servers and streaming orchestration systems.

### Motivation

I built SwiftASB because I saw so many others building and forking existing Apps for agentic coding on thee desktop. I wanted to build my own, of course, but I also wanted to make it easier for anyone to build a custom UI tailored to the way they like to work. SwiftASB handles the complexity and rough edges, providing a rock-solid foundation for everyone from vibecoders to staff engineers. Just grab the `swiftasb-skills` plugin from [Socket Marketplace](https://www.github.com/gaelic-ghost/socket) and you're off to the races.

## Quick Start

Add SwiftASB to your `Package.swift` dependencies:

```swift
.package(url: "https://github.com/gaelic-ghost/SwiftASB", from: "1.3.0"),
```

Then add the library product to your target dependencies:

```swift
.product(name: "SwiftASB", package: "SwiftASB"),
```

Check your Codex version:

```bash
codex --version
```
*Note: SwiftASB supports the latest version of Codex CLI, as well as the prior two minor versions. This policy will be revised once Codex CLI reaches a v1.x.x release.*

Add the Socket Marketplace to Codex and enable the SwiftASB Skills Plugin:

```bash
codex plugin marketplace add socket
```

For copy-pasteable startup code, open the DocC getting-started guide:

- `Sources/SwiftASB/SwiftASB.docc/GettingStartedWithSwiftASB.md`

## Usage

Use SwiftASB when an app needs to show what Codex is doing right now, keep recent command and file activity visible, answer interactive requests, or build SwiftUI state around a running Codex turn.

For app-wide sidebars and launchers, `CodexAppServer.makeLibrary()` provides observable stored-thread lists, cwd or repository grouping, stable worktree groups, repository/worktree thread filters, refresh actions, library-local selection state, app-server-owned worktree snapshots, selected-worktree Git status, and app-wide model, MCP, and hook diagnostics snapshots. Thread handles can also name, archive, unarchive, compact, and roll back stored threads through thread-scoped methods.

Use `CodexAppServer.fs` when a sandboxed client needs filesystem metadata, directory listings, file bytes, file discovery, fuzzy file lookup, or file-change watches through the Codex app-server instead of reading local disk directly. File-discovery hits include match kind, matched character ranges, and ranking reasons for picker highlighting and result explanations. `CodexWorkspace` carries app-server-owned worktree, Git, workspace permission selection, active permission-profile provenance, and runtime filesystem/network permission facts for started threads and turns. Use `CodexAppServer.config` for effective config reads, and `CodexAppServer.extensions` for app, skill, plugin, collaboration-mode inventory, and configured plugin-marketplace upgrades.

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
