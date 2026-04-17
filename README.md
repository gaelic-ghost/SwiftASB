# SwiftASB

`SwiftASB` is an early-stage Swift library package for a Codex app-server bridge aimed at Swift developers.

The package is intentionally starting small. This first snapshot establishes a clean SwiftPM library baseline, repo-local contributor guidance, and a lightweight package surface we can grow without needing to clean up bootstrap noise later.

## Development Quickstart

```bash
swift build
swift test
```

## Current Status

- SwiftPM library package scaffolded and checked into git.
- Swift 6 language mode enabled in `Package.swift`.
- Swift Testing configured as the default test framework.
- Repo-local guidance and roadmap added for follow-on work.

## Near-Term Direction

- Define the bridge model between Swift clients and the app-server surface.
- Add the first concrete public APIs once the transport and ownership boundaries are settled.
- Grow tests alongside the public surface instead of leaving the package as undocumented template code.
