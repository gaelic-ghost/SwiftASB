# AGENTS.md

Repo-local guidance for maintaining SwiftASB, a Swift Package Manager library that wraps the local Codex app-server for Swift and SwiftUI clients.

## Repository Scope

### What This File Covers

- Use this file for all work at the SwiftASB repository root.
- Treat this package as a library first: public API should be deliberate, documented, and tested.
- Use Swift Package Manager as the source of truth for package structure, dependencies, products, targets, resources, and Swift language mode.
- Treat the bundled Codex app-server v2 schema as the primary generated-wire source of truth.
- Treat the generated wire layer as internal scaffolding, not the final public Swift API.

### Where To Look First

- Start with `Package.swift` for package graph, target, dependency, platform, and Swift language mode changes.
- Use `Sources/SwiftASB/Public/` for public API shape and `Sources/SwiftASB/Protocol/`, `Sources/SwiftASB/Transport/`, and `Sources/SwiftASB/History/` for the main internal runtime surfaces.
- Use `Sources/SwiftASB/Generated/CodexWire/Latest/` for the promoted generated v2 wire snapshot.
- Use `Tests/SwiftASBTests/` for Swift Testing coverage.
- Use `scripts/generate-wire-types.sh` for Codex schema-derived wire refreshes.
- Use `scripts/repo-maintenance/` for repo-owned validation, shared sync, and release entrypoints.
- Use `README.md`, `CONTRIBUTING.md`, `ROADMAP.md`, and `docs/maintainers/` for shipped behavior, contributor workflow, planned work, and durable design decisions.

## Working Rules

### Change Scope

- Prefer the simplest correct Swift that is easiest to read, reason about, and maintain.
- Prefer value types for domain modeling.
- Prefer concrete types internally and reserve protocols for real seams.
- Mark classes `final` by default when reference semantics are required.
- Keep dependency flow unidirectional and ownership obvious.
- Prefer explicit, consistent, and unambiguous names.
- Prefer synthesized conformances and memberwise initialization whenever they satisfy the real need.
- Avoid ceremony, wrappers, or extra abstraction layers unless they solve a concrete package problem.
- Keep operator-facing errors, warnings, and log strings descriptive and human-readable.

### Source of Truth

- Prefer `swift package` CLI commands for structural changes whenever the command exists.
- Use `swift package add-dependency` to add dependencies instead of hand-editing package graphs.
- Use `swift package add-target` to add library, executable, or test targets.
- For package configuration not covered by CLI commands, update `Package.swift` intentionally and keep edits minimal.
- Keep package graph updates together in the same change when structure changes.
- Keep `Package.swift` explicit about its package-wide Swift language mode; prefer `swiftLanguageModes: [.v6]` on current Swift 6-era manifests.
- Treat `Package.resolved` and similar package-manager outputs as generated files; do not hand-edit them.
- Keep package resources under the owning target tree, declare them intentionally, and load bundled resources through `Bundle.module`.

### Agent Guidance Boundary

- Keep the README product-facing and approachable for package users and their agents.
- Keep contributor setup, validation, generated-wire refreshes, DocC checks, live test flags, release prep, and PR expectations in `CONTRIBUTING.md`.
- Keep Codex-facing maintainer instructions in this file or a more specific nested `AGENTS.md`.
- SwiftASB-specific adoption guidance for external agents lives in the `swiftasb-skills` plugin in `socket`, not in this package. Update that plugin separately when public API changes would make those skills stale.

### Communication and Escalation

- For Swift, Apple-framework, Apple-platform, or Xcode-related tasks, read the relevant Apple or Swift documentation first before proposing or making changes.
- If a public API change, generated-wire promotion, new dependency, or ownership change starts widening beyond the requested scope, surface that before implementing it.
- If SwiftPM guidance drifts, use `sync-swift-package-guidance` to refresh or merge the package workflow baseline.
- Use `bootstrap-swift-package` only when a new Swift package repo still needs to be created from scratch.
- Use `swift-package-build-run-workflow` for manifest, dependency, resource, build, and run work when `Package.swift` is the source of truth.
- Use `swift-package-testing-workflow` for Swift Testing, XCTest holdouts, fixtures, package test diagnosis, and package test-plan work.
- Prefer `xcode-build-run-workflow` or `xcode-testing-workflow` only when package work needs Xcode-managed SDK, toolchain, DocC, or test behavior.
- Re-run `sync-swift-package-guidance` after substantial package-workflow or plugin updates so local guidance stays aligned.

## Commands

### Setup

Use Swift 6.3 or newer on macOS 15 or newer. SwiftASB discovers the local Codex CLI from `PATH`, common Homebrew locations, or the npm global prefix.

```bash
swift package resolve
```

### Validation

Run the package checks before committing package changes:

```bash
swift build
swift test
```

Run the repo-maintenance validation before release or maintainer-surface changes:

```bash
bash scripts/repo-maintenance/validate-all.sh
```

Check whitespace before staging:

```bash
git diff --check
```

### Optional Project Commands

Refresh generated Codex wire types through the maintainer entrypoint:

```bash
scripts/generate-wire-types.sh
```

Run the repo-maintenance shared sync entrypoint:

```bash
bash scripts/repo-maintenance/sync-shared.sh
```

Start a standard release from a feature branch with a clean committed worktree:

```bash
bash scripts/repo-maintenance/release.sh --mode standard --version vX.Y.Z
```

Validate DocC through Xcode when documentation changes:

```bash
xcodebuild docbuild -scheme SwiftASB -destination generic/platform=macOS -derivedDataPath tmp/xcode-docc/DerivedData
```

## Review and Delivery

### Review Expectations

- Keep package, docs, tests, and generated-wire surfaces aligned in the same branch when one change affects more than one of them.
- Do not promote generated schema additions to public API just because they exist upstream; classify them as public now, observable-only for now, or internal-only before exposing them.
- Keep README product-facing. Keep contributor workflow, local validation, live test flags, schema generation, DocC build commands, and release-prep details in `CONTRIBUTING.md` unless the README user needs them to consume the package.
- PRs should identify the changed surface, explain any public API or docs boundary decision, and list the validation commands that ran.

### Definition of Done

- `swift build` and `swift test` pass for package changes unless the task is explicitly docs-only and no package behavior changed.
- `bash scripts/repo-maintenance/validate-all.sh` passes for maintainer guidance, repo tooling, CI wrapper, or release setup changes.
- Documentation reflects the actual shipped behavior, not aspirational API.
- Live Codex runtime probes are described as observational when runtime behavior is nondeterministic.

## Safety Boundaries

### Never Do

- Do not hand-edit `Package.resolved`.
- Do not hand-edit the promoted generated wire snapshot in `Sources/SwiftASB/Generated/CodexWire/Latest/`; use `scripts/generate-wire-types.sh`.
- Do not reintroduce a promoted generated v1 batch unless Gale explicitly asks for that compatibility surface again.
- Do not commit dumped local schema artifacts under `codex-schemas/` unless Gale explicitly asks to commit them.
- Do not commit temporary derived schemas or raw or patched quicktype staging output under `tmp/`.
- Do not treat the generated wire layer as public Swift API.
- Do not use `xcodebuild` as the default package validation path when plain SwiftPM validation is enough.

### Ask Before

- Ask before changing the public API ownership model, release boundary, licensing terms, or Codex CLI compatibility window.
- Ask before adding dependencies that are not first-party or top-tier Swift ecosystem packages.
- Ask before changing the shape of promoted generated-wire output.
- Ask before committing local schema dumps or temporary generated artifacts that are normally untracked.

## Local Overrides

- No nested `AGENTS.md` files are currently present below the repository root.
- If a more specific `AGENTS.md` is added later, follow the closer file for its subtree while keeping this root guidance as the package-wide baseline.

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

## Swift Package Workflow

- Use `swift build` and `swift test` as the default first-pass validation commands for this package.
- Use `bootstrap-swift-package` when a new Swift package repo still needs to be created from scratch.
- Use `sync-swift-package-guidance` when the repo guidance for this package drifts and needs to be refreshed or merged forward.
- Re-run `sync-swift-package-guidance` after substantial package-workflow or plugin updates so local guidance stays aligned.
- Use `swift-package-build-run-workflow` for manifest, dependency, plugin, resource, Metal-distribution, build, and run work when `Package.swift` is the source of truth.
- Use `swift-package-testing-workflow` for Swift Testing, XCTest holdouts, `.xctestplan`, fixtures, and package test diagnosis.
- Use `scripts/repo-maintenance/validate-all.sh` for local maintainer validation and `scripts/repo-maintenance/sync-shared.sh` for repo-local sync steps.
- Use `scripts/repo-maintenance/release.sh --mode standard --version vX.Y.Z` from a feature branch or worktree only when the task is actually a protected-main release, publish, merge, tag, or release-PR preparation.
- Do not run the standard release workflow from `main`; when a protected-main release is explicitly requested, let it validate, bump versions, tag, push the branch and tag, open the release PR, watch CI, address valid PR comments or record out-of-scope concerns in `ROADMAP.md`, merge to protected `main`, fast-forward local `main`, and clean up stale branches.
- Treat `scripts/repo-maintenance/config/profile.env` as the installed `maintain-project-repo` profile marker, and keep it on the `swift-package` profile for plain package repos.
- Read relevant SwiftPM, Swift, and Apple documentation before proposing package-structure, dependency, manifest, concurrency, or architecture changes.
- Prefer Dash or local Swift docs first, then official Swift or Apple docs when local docs are insufficient.
- When SwiftPM behavior, manifest syntax, package plugins, resources, products, targets, or dependency rules matter, prefer the Dash.app docset workflow with the `swiftlang/swift-package-manager` docset first; fall back to the canonical `swiftlang/swift-package-manager` GitHub repository only when the local docset is unavailable or insufficient.
- Prefer the simplest correct Swift that is easiest to read and reason about.
- Prefer synthesized and framework-provided behavior over extra wrappers and boilerplate.
- For public Swift APIs, treat streamlined, compact, ergonomic call sites as the only acceptable default; prefer optional parameters with explicit default values over additional methods or overloads when the difference is optional behavior on the same operation.
- When a public function, initializer, or method reaches four or more arguments or parameters, strongly prefer a named typed `struct` request, options, or configuration value so call sites stay readable and future additions do not multiply overloads.
- Prefer enums, enum cases with associated values, and narrow typed values over strings, booleans, sentinel values, or parallel parameters whenever the domain has a closed or meaningful set of choices.
- Keep data flow straight and dependency direction unidirectional.
- Treat `Package.swift` as the source of truth for package structure, targets, products, and dependencies.
- Prefer `swift package` subcommands for structural package edits before manually editing `Package.swift`.
- Edit `Package.swift` intentionally and keep it readable; agents may modify it when package structure, targets, products, or dependencies need to change, and should try to keep package graph updates consolidated in one change when possible.
- Keep `Package.swift` explicit about its package-wide Swift language mode. On current Swift 6-era manifests, prefer `swiftLanguageModes: [.v6]` as the default declaration, treat `swiftLanguageVersions` as a legacy alias used only when an older manifest surface requires it, and keep the supported Swift toolchain window focused on the latest stable minor and previous stable minor. Treat Swift `6.2` as the current minimum floor for trait-enabled manifests, not as a ceiling; use newer stable Swift toolchains when available and validated, and refresh this guidance when the maintained floor or window changes. Do not lower `// swift-tools-version:` below `6.2` without an explicit repo policy and a matching guidance update.
- Keep `swift-configuration` as the default configuration dependency for Swift packages unless the package has a concrete reason to remove it. The preferred manifest shape depends on `https://github.com/apple/swift-configuration` from `1.2.0`, enables the `.defaults`, `Reloading`, `YAML`, and `CommandLineArguments` package traits, and adds the `Configuration` product to the primary target. Add the `PropertyList` trait when the package should parse property-list configuration, and add the `Logging` trait when configuration access should integrate with `SwiftLog.Logger`.
- Keep dependency provenance concise but explicit enough for another contributor to fetch the same package: use package-manager, package-registry, GitHub URL, or other real remote repository requirements, and do not commit machine-local dependency paths such as `/Users/...`, `~/...`, `../...`, local worktrees, or private checkout paths. Avoid branch- or revision-based requirements unless the user explicitly asks for that level of control.
- Treat `Package.resolved` and similar package-manager outputs as generated files; do not hand-edit them.
- Prefer Swift Testing by default unless an external constraint requires XCTest.
- Use `apple-ui-accessibility-workflow` when the package work crosses into SwiftUI accessibility semantics, Apple UI accessibility review, or UIKit/AppKit accessibility bridge behavior.
- Keep package resources under the owning target tree, declare them intentionally with `Resource.process(...)`, `Resource.copy(...)`, `Resource.embedInCode(...)`, and load them through `Bundle.module`.
- Keep test fixtures as test-target resources instead of relying on the working directory.
- Bundle precompiled Metal artifacts such as `.metallib` files as explicit resources when they ship with the package, and prefer `xcode-build-run-workflow` when shader compilation or Apple-managed Metal toolchain behavior matters.
- Prefer normal SwiftPM parallel test execution for ordinary Swift Testing and XCTest runs. Do not serialize regular package tests just because they use Swift, XCTest, async tests, fixtures, or test plans.
- Treat tests that load large local AI or ML models, especially models over 500 million parameters, as heavy system-resource tests. Run those tests sequentially, one at a time, and call `unload_models` on Gale's live TTS service before the heavy run and `reload_models` after it ends, even when the run fails or is interrupted.
- Validate both Debug and Release paths when optimization or packaging differences matter, and treat tagged releases as a cue to verify the Release artifact path before publishing.
- Prefer `xcode-build-run-workflow` or `xcode-testing-workflow` only when package work needs Xcode-managed SDK, toolchain, or test behavior.
- Keep runtime UI accessibility verification and XCUITest follow-through in `xcode-testing-workflow` rather than treating package-side testing as a substitute for live UI verification.
