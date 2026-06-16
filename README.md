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

SwiftASB is actively maintained and supported by Gale. Our current API is v1, and `v1.7.5` is the current and latest release.

### What This Project Is

SwiftASB is a native Swift client/runtime layer for AI coding agent app-servers and streaming orchestration systems.

### Motivation

I built SwiftASB because I saw so many others building and forking existing Apps for agentic coding on the desktop. I wanted to build my own, of course, but I also wanted to make it easier for anyone to build a custom UI tailored to the way they like to work. SwiftASB handles the complexity and rough edges, providing a rock-solid foundation for everyone from vibecoders to staff engineers. Just grab the `swiftasb-skills` plugin from [Socket Marketplace](https://www.github.com/gaelic-ghost/socket) and you're off to the races.

## Quick Start

Add SwiftASB to your `Package.swift` dependencies:

```swift
.package(url: "https://github.com/gaelic-ghost/SwiftASB", from: "1.7.5"),
```

Then add the library product to your target dependencies:

```swift
.product(name: "SwiftASB", package: "SwiftASB"),
```

For reusable presentation or UI components, also add the products you use:

```swift
.product(name: "ASBPresentation", package: "SwiftASB"),
.product(name: "ASBAppKit", package: "SwiftASB"),
.product(name: "ASBSwiftUI", package: "SwiftASB"),
```

Check your Codex version:

```bash
codex --version
```
*Note: SwiftASB currently supports the reviewed current Codex CLI minor release, `0.140.x`, and the latest prior minor, `0.139.x`, when that prior runtime remains compatible. This narrow reviewed window will be revised once the app-server schema stabilizes or Codex CLI reaches a v1.x.x release.*

Add the Socket Marketplace to Codex and enable the SwiftASB Skills Plugin:

```bash
codex plugin marketplace add socket
```

For copy-pasteable startup code, open the DocC getting-started guide:

- `Sources/SwiftASB/SwiftASB.docc/GettingStartedWithSwiftASB.md`

Most clients should start with `CodexAppServer.start(_:)`. The one-call startup
API launches the local Codex app-server, verifies the selected Codex CLI against
SwiftASB's reviewed compatibility window, initializes the session, and throws
typed `CodexAppServerStartupError` values for missing, incompatible, or
unparseable CLI installs.

## Usage

Use SwiftASB when an app needs to show what Codex is doing right now, keep plan and goal state visible, keep recent command and file activity visible, answer interactive requests, or build SwiftUI state around a running Codex turn.

For app-wide capability and extension UI, `CodexAppServer.makeInventory()` provides observable model capabilities, global MCP summaries, hook diagnostics, apps, skills, plugins, and collaboration modes, with SwiftASB-owned refresh from app-server inventory notifications. For app-wide sidebars and launchers, `CodexAppServer.makeLibrary()` provides observable stored-thread lists, cwd or repository grouping, stable worktree groups, repository/worktree thread filters, refresh actions, library-local selection state, app-server-owned worktree snapshots, selected-worktree Git status, and optional app-wide model, MCP, and hook diagnostics snapshots beside thread lists. Thread handles can also name, archive, unarchive, compact, and roll back stored threads through thread-scoped methods.

Use `CodexAppServer.fs` when a sandboxed client needs filesystem metadata, directory listings, file bytes, file discovery, fuzzy file lookup, or file-change watches through the Codex app-server instead of reading local disk directly. File-discovery hits include match kind, matched character ranges, and ranking reasons for picker highlighting and result explanations. `CodexWorkspace` carries app-server-owned worktree, Git, workspace permission selection, active permission-profile provenance, and runtime filesystem/network permission facts for started threads and turns. Use `CodexAppServer.config` for effective config reads, `CodexAppServer.mcp` for opinionated MCP installs plus explicit MCP detail reads, and `CodexAppServer.extensions` only when a caller intentionally owns direct extension pagination, plugin-detail inspection, or configured plugin-marketplace upgrades.

Use `CodexAppServer.ThreadListQD`, `CodexFS.FileDiscoveryQD`, `CodexThread.HistoryWindowQD`, `CodexThread.RecentFilesQD`, and `CodexThread.RecentCommandsQD` when a client needs to preserve repeatable list, file-discovery, history-window, or recent-activity intent without depending on Core Data, SwiftData, direct filesystem reads, or raw app-server paging details.

Use `CodexThread.makeAgenda()` when a SwiftUI surface needs the thread's current goal, latest accepted plan, proposed plan text, and summary titles without manually assembling raw plan deltas or reconciling goal reads with goal events.

Use `ASBSwiftUI` when a macOS app wants ready-made SwiftUI surfaces over the
presentation snapshots:

```swift
import ASBPresentation
import ASBSwiftUI

ASBThreadSidebar(snapshot: ThreadSidebarSnapshot(library: library)) { intent in
    // Route ThreadSidebarIntent values back to the owning app state.
}

ASBAgendaPanel(snapshot: AgendaSnapshot(agenda: agenda)) { intent in
    // Route AgendaIntent values through the owning CodexThread.
}

ASBDashboardPanel(snapshot: DashboardSnapshot(dashboard: dashboard))
```

`ASBThreadSidebar` wraps the AppKit-backed source-list renderer for dense
thread lists. `ASBAgendaPanel` and `ASBDashboardPanel` are native SwiftUI
panels for lighter current-state surfaces.

Use `CodexThread.startPlanningTurn(...)` when a mode button or segmented control should start the next turn in Codex plan mode without sending slash-command text through the prompt. Advanced callers can use `CodexAppServer.TurnCollaborationMode` directly on a turn-start request.

Plan and goal controls are intentionally separate for now. The recommended workflow is to use plan mode first to shape complex or ambiguous work, then set a persistent goal from the accepted objective when the host app or user is ready to track execution. SwiftASB does not currently auto-create goals from plan prompts or auto-promote completed plans into goals.

Use `CodexThread.startReview(against:placement:)` to start app-server code reviews from a thread. The public API uses hand-owned Swift subjects such as `.uncommittedChanges`, `.baseBranch("main")`, `.commit(sha:title:)`, and `.custom(instructions:)`; `placement: .inline` runs the review turn on the current thread, while `.detached` runs it on a returned review thread.

Use `CodexThread.sendShellCommand(_:)` only for explicit user-level shell access. It sends a literal shell command string through app-server `thread/shellCommand`, preserves shell syntax such as pipes and redirects, and is documented upstream as unsandboxed full-user shell execution. SwiftASB keeps its internal `command/exec` helper path separate because that path is argv-shaped app-server command execution for SwiftASB-owned helper intents. `sendShellCommand(_:)` is gated by the disabled-by-default `shellCommandExecution` feature category.

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
│   ├── ASBAppKit/
│   ├── ASBPresentation/
│   ├── ASBSwiftUI/
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

`ROADMAP.md` tracks milestone status and release-facing work. The `docs/releases/` directory contains checked-in patch release notes. Git tags and GitHub releases are the source of truth for published versions.

## License

SwiftASB is licensed under the PolyForm Noncommercial License 1.0.0 for future public versions. See [LICENSE](./LICENSE), [NOTICE](./NOTICE), and [COMMERCIAL-USE.md](./COMMERCIAL-USE.md).

Commercial use is not licensed by the public license. See [COMMERCIAL-USE.md](./COMMERCIAL-USE.md) for the current commercial-use policy and contact path.

SwiftASB versions published before the PolyForm Noncommercial change remain available under the license terms that applied to those versions. The historical Apache License 2.0 text is preserved in [LICENSE-HISTORICAL-APACHE-2.0](./LICENSE-HISTORICAL-APACHE-2.0).
