# SwiftASB

`SwiftASB` is a Swift library package for driving the local Codex app-server from Swift and SwiftUI apps.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Requirements](#requirements)
- [Usage](#usage)
- [Codex Agent Guidance](#codex-agent-guidance)
- [Development](#development)
- [Repo Structure](#repo-structure)
- [Release Notes](#release-notes)
- [License](#license)

## Overview

### Status

SwiftASB has a supported v1 public API for the core Codex app-server lifecycle. `v1.0.2` is the current released baseline, and current releases are Apache 2.0 licensed.

### What This Project Is

SwiftASB wraps the Codex app-server lifecycle in typed Swift APIs. It gives Swift and SwiftUI clients a package-native way to start the local Codex runtime, open or resume conversations, start turns, observe progress, answer interactive requests, and mirror active command, file-edit, MCP, and history state without exposing generated JSON-RPC wire models as the public API.

The main public handles are:

- `CodexAppServer`, the owner of the local Codex subprocess and app-wide capabilities.
- `CodexThread`, the handle for one Codex conversation thread.
- `CodexTurnHandle`, the handle for one active turn.
- `CodexThread.Dashboard`, `CodexTurnHandle.Minimap`, `RecentTurns`, `RecentFiles`, and `RecentCommands`, the SwiftUI-friendly observable companions for current state and recent local history.

### Motivation

SwiftUI clients need a clean way to show what a Codex turn is doing right now: which command is running, whether a file edit is live, whether an MCP call is active, whether the turn is blocked on approval, and what recent completed work can be shown in a transcript or inspector. SwiftASB exists so those apps can build on typed Swift values, async streams, and observable companions instead of replaying raw protocol payloads themselves.

## Quick Start

Add SwiftASB to a SwiftPM package or Xcode package dependency:

```swift
.package(url: "https://github.com/gaelic-ghost/SwiftASB", from: "1.0.2")
```

Then add the product to the target that talks to Codex:

```swift
.product(name: "SwiftASB", package: "SwiftASB")
```

SwiftASB expects a local Codex CLI runtime. By default it discovers `codex` from `PATH`, common Homebrew locations, or the npm global prefix. Apps that need a fixed runtime can pass `CodexAppServer.Configuration.codexExecutableURL`.

## Requirements

- macOS 15 or newer.
- Swift 6.3 or newer.
- A local Codex CLI installation with app-server support.

The current reviewed Codex CLI compatibility window is `0.128.x`. SwiftASB checks the resolved binary at startup and exposes the resolved path, version text, and compatibility assessment through `CodexAppServer.cliExecutableDiagnostics()`.

## Usage

### Minimal Turn

This is the smallest useful flow: start the app-server, initialize it, create a thread, start a text turn, and wait for completion.

```swift
import SwiftASB

let client = CodexAppServer()

try await client.start()
defer { Task { await client.stop() } }

_ = try await client.initialize(
    .init(
        clientInfo: .init(
            name: "ExampleApp",
            title: "Example App",
            version: "0.1.0"
        )
    )
)

let thread = try await client.startThread(
    .init(
        approvalPolicy: .never,
        currentDirectoryPath: "/absolute/path/to/workspace",
        ephemeral: true,
        sandboxMode: .workspaceWrite
    )
)

let turn = try await thread.startTextTurn(
    "Reply with exactly: hello from SwiftASB",
    approvalPolicy: .never,
    summary: .none
)

for try await event in turn.events {
    if case let .completed(completion) = event {
        print(completion.turn.status)
        break
    }
}
```

After `start()`, apps can inspect the resolved binary, version string, and support-window assessment through `CodexAppServer.cliExecutableDiagnostics()`.

### Interactive Turns

Interactive clients should treat the turn handle as the place where active-turn control lives. A turn can stream events, answer approval or elicitation requests, receive steering text, and be interrupted.

```swift
let turn = try await thread.startTextTurn(
    "Inspect the workspace and summarize what changed.",
    approvalPolicy: .onRequest,
    summary: .concise
)

try await turn.steerText("Keep the answer short and lead with the most important change.")

for try await event in turn.events {
    switch event {
    case let .approvalRequested(request):
        switch request {
        case .commandExecution:
            try await turn.respond(to: request, with: .commandExecution(.accept))
        case .fileChange:
            try await turn.respond(to: request, with: .fileChange(.accept))
        case let .permissions(permissionsRequest):
            try await turn.respond(
                to: request,
                with: .permissions(
                    .init(
                        permissions: permissionsRequest.permissions,
                        scope: .turn
                    )
                )
            )
        }
    case let .elicitationRequested(request):
        switch request {
        case let .toolUserInput(inputRequest):
            let answers = Dictionary(
                uniqueKeysWithValues: inputRequest.questions.map { question in
                    (question.id, CodexToolUserInputResponse.Answer(answers: []))
                }
            )
            try await turn.respond(
                to: request,
                with: .toolUserInput(.init(answers: answers))
            )
        case .mcpServer:
            try await turn.respond(
                to: request,
                with: .mcpServer(.init(action: .accept))
            )
        }
    case let .completed(completion):
        print("Turn finished with status:", completion.turn.status)
        break
    default:
        continue
    }
}
```

If the runtime does not naturally raise an approval request for a particular prompt, that is expected today. SwiftASB keeps prompt-driven live approval probes observational, while deterministic approval regression coverage uses the real app-server with a local mock Responses provider so the request, response, resolution, and turn-completion path can be asserted without calling the hosted OpenAI API.

### SwiftUI State Companions

SwiftUI apps should not need to replay every raw event to show useful state. The current companion types cover the first UI-shaped surfaces:

- `CodexThread.makeDashboard()` mirrors thread-level current state, including aggregate tool activity, MCP activity, hook activity, and active thread compaction.
- `CodexTurnHandle.minimap` mirrors per-turn current state, including command, file-edit, dynamic-tool, collab-tool, MCP, and compaction activity.
- `CodexThread.makeRecentTurns(limit:cachePolicy:)` provides a bounded turn-centric history view with cache presets for chat, inspector, and compact history rails.
- `CodexThread.makeRecentFiles(limit:cachePolicy:)` provides a file-change-centric view with selection-aware payload slimming and rehydration.
- `CodexThread.makeRecentCommands(limit:cachePolicy:)` provides a command-centric view with output-aware slimming and rehydration.

For inspector-style UI that needs completed history without binding to an observable, `CodexThread.HistoryWindow` and the `readRecent...`, `readOlder...`, `readNewer...`, `windowAroundTurn(...)`, and `windowAroundItem(...)` helpers expose narrow local-history reads.

Recent observable startup is intentionally UI-friendly around known live app-server history boundaries. If a thread is ephemeral, or if a non-ephemeral thread has not materialized stored turn history yet, `makeRecentTurns(...)`, `makeRecentFiles(...)`, and `makeRecentCommands(...)` start as empty local-only views instead of surfacing raw `thread/turns/list` protocol text. Direct calls to `CodexAppServer.listThreadTurns(...)` still report the underlying app-server failure so lower-level callers can handle remote paging errors explicitly.

### Supported Today

The current public lifecycle contract is intentionally narrow and explicit:

- `CodexAppServer` starts and stops the subprocess, initializes the session, starts threads and turns, lists stored threads, reads/resumes/forks threads, pages stored turns, lists models, and lists MCP server statuses.
- `CodexThread` owns thread-scoped turn creation, thread events, thread-management actions, local-history reads, and thread-scoped observable companions.
- `CodexTurnHandle` owns active-turn events and active-turn controls such as response handling, steering, interruption, minimap observation, and explicit completion snapshot handoff.
- Approval and elicitation requests use hand-owned public models, including command approval, file-change approval, permissions approval, tool user input, and MCP server elicitation.
- Diagnostics for warnings, guardian warnings, model reroutes, and model verification surface through hand-owned public events rather than generated wire payloads.
- Different threads may host concurrent turns.
- Overlapping turns on the same thread are rejected client-side with `CodexAppServerError.invalidState` because the live app-server does not yet expose a reliable independent lifecycle for them.
- The generated wire layer stays internal.
- A one-shot `run(...)` convenience API is intentionally deferred.

The reviewed generated-wire baseline currently targets the experimental `v0.128.0` Codex CLI schema. Newer Codex CLI schemas are dumped and classified before their generated shapes are promoted or exposed through public Swift API.

## Codex Agent Guidance

SwiftASB-specific Codex guidance ships separately in the [`swiftasb-skills`](https://github.com/gaelic-ghost/socket/tree/main/plugins/swiftasb-skills) plugin in `socket`. Use that plugin when asking an agent to explain SwiftASB, choose an integration shape, build a SwiftUI-facing integration, or diagnose a SwiftASB runtime problem.

The current skills are:

- `explain-swiftasb`, for adoption fit, runtime tradeoffs, public API boundaries, and licensing.
- `choose-integration-shape`, for deciding whether `CodexAppServer`, `CodexThread`, or `CodexTurnHandle` should own a piece of app work.
- `build-swiftui-app`, for SwiftUI app features that use SwiftASB observable companions.
- `diagnose-integration`, for failures around package wiring, Codex CLI discovery, app-server startup, turns, approvals, diagnostics, MCP status, history, and live-test isolation.

Use `swiftasb-skills` for SwiftASB-specific workflow guidance, and use Apple development guidance for SwiftUI, AppKit, Xcode, and Apple framework lifecycle rules.

## Development

### Setup

This README is written for package users. Contributor setup lives in [CONTRIBUTING.md](./CONTRIBUTING.md).

### Workflow

Contributor branch workflow, generated-wire maintenance, DocC updates, and release-readiness expectations live in [CONTRIBUTING.md](./CONTRIBUTING.md).

### Validation

Contributor validation commands, live test flags, and the Xcode DocC build command live in [CONTRIBUTING.md](./CONTRIBUTING.md). The main live runtime entrypoint is:

```bash
scripts/run-live-codex-integration-tests.sh
```

It defaults to the maintained release-gate set and also supports focused modes for smoke, transport, capability, thread, turn, approval, file-scenario, rollback, same-thread, and full opt-in live coverage.

## Repo Structure

```text
.
├── .github/
│   └── workflows/
├── .spi.yml
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
│       ├── Protocol/
│       ├── Public/
│       └── Transport/
└── scripts/
    ├── generate-wire-types.sh
    └── repo-maintenance/
```

## Release Notes

`ROADMAP.md` tracks milestone status and release-facing work. `v1.0.2` is the current released baseline, and the roadmap plus git history remain the source of truth for what has shipped versus what is intentionally open.

## License

SwiftASB is licensed under the Apache License, Version 2.0. See [LICENSE](./LICENSE).
