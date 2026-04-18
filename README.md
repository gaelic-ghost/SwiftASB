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

SwiftASB is in early development, but `v0.0.1` is a reasonable experimental baseline for the package as it exists today.

### What This Project Is

SwiftASB is a library-first Swift package that wraps the Codex app-server lifecycle in typed Swift APIs. The current public surface centers on `CodexAppServer`, `CodexThread`, and `CodexTurnHandle`, with typed initialize, thread start, turn start, and event-stream handling for Swift clients that want to work against a local Codex CLI runtime.

### Motivation

This package exists to give Swift developers a Swift-native bridge to the Codex app-server without exposing generated wire types as the public API. The repo is maintained separately so transport, protocol typing, concurrency behavior, and public package ergonomics can be worked out in the open as a real Swift library instead of as one-off glue code.

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

The package assumes a local Codex CLI runtime. A minimal flow looks like this:

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

Current concurrency behavior is explicit:

- Different threads may host concurrent turns.
- Overlapping turns on the same thread are rejected client-side with `CodexAppServerError.invalidState` because the live app-server does not yet expose a reliable independent lifecycle for them.

## Development

### Setup

- Use Swift 6.3 or newer on macOS 15 or newer.
- Install the local Codex CLI if you want to run the live integration tests.
- Clone the repo and build with SwiftPM.

```bash
swift build
```

### Workflow

- Keep the public API deliberate and library-first.
- Use the fake transport tests for deterministic public-surface work.
- Use the opt-in live tests when verifying real Codex CLI subprocess behavior.
- Keep generated wire code internal and treat the public wrappers as the actual package surface.

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
env SWIFTASB_ENABLE_LIVE_CODEX_SAME_THREAD_TESTS=1 swift test
```

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

`ROADMAP.md` tracks milestone status and the next release-facing work. Until the first tagged release is cut, the roadmap plus git history are the source of truth for shipped scope. The current package state is substantial enough to peg as an experimental `v0.0.1`.

## License

See [LICENSE](./LICENSE).
