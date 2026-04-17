# AGENTS.md

## Repository Expectations

- Use Swift Package Manager as the source of truth for package structure and dependencies.
- Prefer `swift package` CLI commands for structural changes whenever the command exists.
- Use `swift package add-dependency` to add dependencies instead of hand-editing package graphs.
- Use `swift package add-target` to add library, executable, or test targets.
- For package configuration not covered by CLI commands, update `Package.swift` intentionally and keep edits minimal.
- Keep package graph updates together in the same change when structure changes.
- Validate package changes with:
  - `swift build`
  - `swift test`

## Swift Baseline

- For Swift, Apple-framework, Apple-platform, or Xcode-related tasks, read the relevant Apple or Swift documentation first before proposing or making changes.
- Prefer the simplest correct Swift that is easiest to read, reason about, and maintain.
- Prefer explicit, consistent, and unambiguous names.
- Prefer synthesized conformances and memberwise initialization whenever they satisfy the real need.
- Avoid ceremony, wrappers, or extra abstraction layers unless they solve a concrete package problem.
- Keep operator-facing errors, warnings, and log strings descriptive and human-readable.

## Types and Architecture

- Prefer value types for domain modeling.
- Prefer concrete types internally and reserve protocols for real seams.
- Mark classes `final` by default when reference semantics are required.
- Keep dependency flow unidirectional and ownership obvious.
- Treat this package as a library first: public API should be deliberate, documented, and tested.

## Codex App-Server Wire Workflow

- Treat the bundled Codex app-server v2 schema as the primary generated-wire source of truth.
- Use `scripts/generate-wire-types.sh` as the maintainer entrypoint for schema derivation, quicktype generation, dynamic-JSON patching, and staged Swift validation.
- Keep dumped local schema artifacts under `codex-schemas/` untracked unless Gale explicitly asks to commit them.
- Keep temporary derived schemas and raw or patched quicktype staging output under `tmp/` untracked.
- Promote only the generated v2 wire snapshot into `Sources/SwiftASB/Generated/CodexWire/Latest/` unless Gale explicitly asks for a different promotion shape.
- The current generated promoted file is `CodexLifecycleV2Batch+JSONValue.swift`.
- Keep `CodexWireInitializeResponse` hand-owned in its own dedicated Swift file next to the promoted generated v2 snapshot until the upstream v2 schema exposes that type directly.
- Do not reintroduce a promoted generated v1 batch unless Gale explicitly asks for that compatibility surface again.
- Treat the generated wire layer as an internal scaffolding surface, not the final public Swift API.

## Testing and Tooling

- Use Swift Testing as the default test framework.
- Avoid XCTest unless an external constraint requires it.
- Use `swift build` and `swift test` as the default first-pass validation commands.
- Use `xcodebuild` only when Apple-platform integration details need validation beyond plain SwiftPM.
