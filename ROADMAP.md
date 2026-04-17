# Project Roadmap

## Vision

- Make `SwiftASB` a small, dependable Swift package for talking to an app-server bridge without burying the real transport model under avoidable scaffolding.

## Product Principles

- Keep the public API compact and easy to reason about.
- Prefer explicit data models and ownership over stringly or ad hoc bridging surfaces.
- Grow the package from real use cases instead of speculative abstraction.
- Keep package documentation and tests aligned with the shipped surface.

## Milestone Progress

- [x] Milestone 0: Package baseline
- [ ] Milestone 1: Bridge model and public API draft
- [ ] Milestone 2: Transport integration and error handling
- [ ] Milestone 3: Documentation and usage examples

## Milestone 0: Package Baseline

Scope:

- [x] Create the SwiftPM library package scaffold.
- [x] Enable Swift 6 language mode.
- [x] Add repo-local guidance for package work.
- [x] Add a minimal public library surface and smoke-test coverage.

Exit criteria:

- [x] `swift build` passes.
- [x] `swift test` passes.

## Milestone 1: Bridge Model and Public API Draft

Scope:

- [ ] Define the core bridge concepts the library needs to expose.
- [ ] Decide what belongs in the initial public API and what should stay internal.
- [ ] Add first real documentation comments and example usage once the surface exists.

## Milestone 2: Transport Integration and Error Handling

Scope:

- [ ] Introduce the first concrete transport or adapter layer once the real use case is chosen.
- [ ] Make failure states descriptive, typed where useful, and easy to debug.
- [ ] Add tests that prove request and response behavior instead of only package smoke coverage.

## Milestone 3: Documentation and Usage Examples

Scope:

- [ ] Expand `README.md` with installation, integration, and example usage.
- [ ] Add contributor-facing notes for evolving the bridge safely.
- [ ] Revisit release and versioning policy once the first public API lands.
