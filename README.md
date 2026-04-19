# SwiftASB

`SwiftASB` is a Swift library package for driving the Codex app-server from Swift.

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

SwiftASB is in early development, and `v0.0.1` is the current experimental baseline.

### What This Project Is

SwiftASB is a library-first Swift package that wraps the Codex app-server lifecycle in typed Swift APIs. The current public surface centers on `CodexAppServer`, `CodexThread`, and `CodexTurnHandle`, with typed initialize, thread start, turn start, and event-stream handling for Swift clients that want to work against a local Codex CLI runtime.

### Motivation

This package exists to give Swift developers a Swift-native bridge to the Codex app-server without exposing generated wire types as the public API. The repo is maintained separately so transport, protocol typing, concurrency behavior, live subprocess verification, and public package ergonomics can be worked out in the open as a real Swift library instead of as one-off glue code.

## Quick Start

SwiftASB is still experimental, but the shortest real path to trying it is:

1. Install the local Codex CLI and make sure `codex` is on your `PATH`, or plan to pass an explicit executable URL in `CodexAppServer.Configuration`.
2. Add the package to your SwiftPM project.
3. Initialize the client, start a thread, and start a turn.

```swift
.package(url: "https://github.com/gaelic-ghost/SwiftASB", from: "0.0.1")
```

If you just want to explore the package repo itself, start with the commands in [Development](#development).

## Usage

The package assumes a local Codex CLI runtime. The currently shipped public surface includes:

- `CodexAppServer` for process ownership, initialize, thread start, and turn start.
- `CodexThread` for thread-scoped turn creation plus a live `Dashboard` companion.
- `CodexTurnHandle` for typed turn events plus a live `Minimap` companion.
- typed approval and elicitation request models, with explicit response APIs on
  `CodexThread` and `CodexTurnHandle`.

## Supported Today

The current public lifecycle contract is intentionally narrow and explicit:

- `CodexAppServer` owns the local subprocess plus initialize, thread start, and
  turn start.
- `CodexThread` owns thread-scoped turn creation and thread-scoped fallback
  responses for unroutable interactive requests.
- `CodexTurnHandle` owns the active turn stream plus turn-scoped control
  methods, including `respond(to:with:)`, `steer(_:)`, `steerText(_:)`, and
  `interrupt()`.
- `CodexTurnEvent` and `CodexThreadEvent` surface typed progress, item,
  approval, elicitation, and request-resolution events without exposing raw
  generated wire payloads.
- `Dashboard` and `Minimap` are current-state mirrors of the typed public event
  streams rather than a second control path.

Current concurrency behavior is also explicit:

- Different threads may host concurrent turns.
- Overlapping turns on the same thread are rejected client-side with
  `CodexAppServerError.invalidState` because the live app-server does not yet
  expose a reliable independent lifecycle for them.

Current non-goals and intentionally deferred areas are also explicit:

- The generated wire layer stays internal.
- There is not yet a one-shot `run(...)` convenience API.
- The live approval-path probe is best-effort runtime observation, not a
  deterministic release gate, because the current Codex runtime does not
  reliably force an approval request on command.

Current Codex CLI compatibility policy is intentionally rolling:

- `SwiftASB` aims to support the latest public Codex CLI release plus the prior
  two minor versions.
- When newer Codex CLI releases add protocol features without breaking existing
  behavior, `SwiftASB` may adopt those additions later or gate them behind
  newer-version-aware promotion work rather than treating every new upstream
  feature as an immediate public-surface requirement.
- If Codex reaches a future major-version release with a materially different
  compatibility story, this policy should be reassessed rather than assumed to
  carry forward unchanged.

Current executable discovery on macOS follows this order when you do not pass
an explicit `CodexAppServer.Configuration.codexExecutableURL`:

- probe `codex --version` through the current `PATH`
- check the common Homebrew install locations
  `/opt/homebrew/bin/codex` and `/usr/local/bin/codex`
- check the npm global prefix reported by `npm prefix -g`, then look for
  `<prefix>/bin/codex`

If you want to bypass discovery entirely, pass an explicit executable URL.

A minimal flow looks like this:

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

### Interactive Lifecycle Example

This example shows the current intended handle-owned lifecycle: start a turn,
observe events, answer approval requests if they appear, and optionally steer
or interrupt the active turn.

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
        approvalPolicy: .onRequest,
        approvalsReviewer: .user,
        currentDirectoryPath: "/absolute/path/to/workspace",
        ephemeral: true,
        sandboxMode: .workspaceWrite
    )
)

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
    case let .serverRequestResolved(resolution):
        print("Resolved request:", resolution.requestID)
    case let .completed(completion):
        print("Turn finished with status:", completion.turn.status)
        break
    default:
        continue
    }
}

// If your UI or workflow decides the turn should stop early:
try await turn.interrupt()
```

If the runtime does not naturally raise an approval request for a particular
prompt, that is expected today. The live approval-path test is useful for
observing current behavior, but it is not treated as deterministic release
coverage.

## Development

### Setup

- Use Swift 6.3 or newer on macOS 15 or newer.
- Install the local Codex CLI if you want to use the package against a real runtime or run the live integration tests.
- Clone the repo and build with SwiftPM.

```bash
swift build
```

### Workflow

- Keep the public API deliberate and library-first.
- Use the fake transport tests for deterministic public-surface work.
- Use the opt-in live tests when verifying real Codex CLI subprocess behavior.
- Treat the live approval-path probe as best-effort coverage, not as a deterministic release gate; the current Codex runtime does not reliably force an approval request on command, so the same prompt may either raise approval or complete directly.
- Keep generated wire code internal and treat the public wrappers as the actual package surface.
- Keep temporary codegen artifacts under `codex-schemas/` and `tmp/` untracked unless a maintainer explicitly decides otherwise.

### Validation

Run these first:

```bash
swift build
swift test
```

Useful opt-in live checks:

```bash
env SWIFTASB_ENABLE_LIVE_CODEX_TRANSPORT_TESTS=1 swift test
env SWIFTASB_ENABLE_LIVE_CODEX_SINGLE_TURN_TESTS=1 swift test
env SWIFTASB_ENABLE_LIVE_CODEX_CROSS_THREAD_TESTS=1 swift test
env SWIFTASB_ENABLE_LIVE_CODEX_APPROVAL_TESTS=1 swift test
env SWIFTASB_ENABLE_LIVE_CODEX_SAME_THREAD_TESTS=1 swift test
```

Those live suites launch the local Codex CLI through temp workspaces with explicit test time limits. They are intentionally opt-in so day-to-day package validation stays fast and deterministic.
The approval-path probe is especially non-deterministic today and should be read as runtime observation rather than a strict pass/fail release gate.

## Repo Structure

```text
.
├── Package.swift
├── README.md
├── ROADMAP.md
├── Sources/
│   └── SwiftASB/
│       ├── Generated/
│       ├── Protocol/
│       ├── Public/
│       └── Transport/
├── Tests/
│   └── SwiftASBTests/
│       ├── Protocol/
│       ├── Public/
│       └── Transport/
└── scripts/
```

## Release Notes

`ROADMAP.md` tracks milestone status and the next release-facing work. `v0.0.1` is already tagged as the current experimental baseline, and the roadmap plus git history remain the source of truth for what has shipped versus what is still intentionally open.

## License

SwiftASB is licensed under Apache 2.0. See [LICENSE](./LICENSE).
