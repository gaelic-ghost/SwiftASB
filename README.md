# SwiftASB

`SwiftASB` is a Swift library package for driving the local Codex app-server from Swift and SwiftUI apps.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Development](#development)
- [Repo Structure](#repo-structure)
- [Release Notes](#release-notes)
- [License](#license)

## Overview

### Status

SwiftASB is in early development, and `v0.8.4` is the current experimental baseline.

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
.package(url: "https://github.com/gaelic-ghost/SwiftASB", from: "0.8.4")
```

Then add the product to the target that talks to Codex:

```swift
.product(name: "SwiftASB", package: "SwiftASB")
```

SwiftASB expects a local Codex CLI runtime. By default it discovers `codex` from `PATH`, common Homebrew locations, or the npm global prefix. Apps that need a fixed runtime can pass `CodexAppServer.Configuration.codexExecutableURL`.

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

If the runtime does not naturally raise an approval request for a particular prompt, that is expected today. The live approval-path test is useful for observing current behavior, but it is not a deterministic release gate.

### SwiftUI State Companions

SwiftUI apps should not need to replay every raw event to show useful state. The current companion types cover the first UI-shaped surfaces:

- `CodexThread.makeDashboard()` mirrors thread-level current state, including aggregate tool activity, MCP activity, hook activity, and active thread compaction.
- `CodexTurnHandle.makeMinimap()` mirrors per-turn current state, including command, file-edit, dynamic-tool, collab-tool, MCP, and compaction activity.
- `CodexThread.makeRecentTurns(limit:cachePolicy:)` provides a bounded turn-centric history view with cache presets for chat, transcript, and compact rails.
- `CodexThread.makeRecentFiles(limit:cachePolicy:)` provides a file-change-centric view with selection-aware payload slimming and rehydration.
- `CodexThread.makeRecentCommands(limit:cachePolicy:)` provides a command-centric view with output-aware slimming and rehydration.

For inspector-style UI that needs completed history without binding to an observable, `CodexThread.HistoryWindow` and the `readRecent...`, `readOlder...`, `readNewer...`, `windowAroundTurn(...)`, and `windowAroundItem(...)` helpers expose narrow local-history reads.

### Supported Today

The current public lifecycle contract is intentionally narrow and explicit:

- `CodexAppServer` starts and stops the subprocess, initializes the session, starts threads and turns, lists stored threads, reads/resumes/forks threads, pages stored turns, lists models, and lists MCP server statuses.
- `CodexThread` owns thread-scoped turn creation, thread events, thread-management actions, local-history reads, and thread-scoped observable companions.
- `CodexTurnHandle` owns active-turn events and active-turn controls such as response handling, steering, interruption, minimap creation, and explicit close-to-snapshot handoff.
- Different threads may host concurrent turns.
- Overlapping turns on the same thread are rejected client-side with `CodexAppServerError.invalidState` because the live app-server does not yet expose a reliable independent lifecycle for them.
- The generated wire layer stays internal.
- A one-shot `run(...)` convenience API is intentionally deferred.

The current Codex CLI compatibility window is `0.123.x` through `0.125.x`. New upstream schema features are classified before they become public Swift API.

## Development

### Setup

This README is written for package users. Contributor setup lives in [CONTRIBUTING.md](./CONTRIBUTING.md).

### Workflow

Contributor branch workflow, generated-wire maintenance, DocC updates, and release-readiness expectations live in [CONTRIBUTING.md](./CONTRIBUTING.md).

### Validation

Contributor validation commands, live test flags, and the Xcode DocC build command live in [CONTRIBUTING.md](./CONTRIBUTING.md).

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

`ROADMAP.md` tracks milestone status and the next release-facing work. `v0.8.4` is already tagged as the current experimental baseline, and the roadmap plus git history remain the source of truth for what has shipped versus what is intentionally open.

## License

SwiftASB is licensed under `FSL-1.1-ALv2`. Current versions are available under the Functional Source License with no commercial competing-use right, and each version converts to Apache 2.0 on the second anniversary of the date that version was first made available. See [LICENSE](./LICENSE).
