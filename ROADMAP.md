# Project Roadmap

## Table of Contents

- [Vision](#vision)
- [Product Principles](#product-principles)
- [Current Feature Matrix](#current-feature-matrix)
- [Milestone Progress](#milestone-progress)
- [Current Maintainer Priority](#current-maintainer-priority)
- [V1 Readiness Checklist](#v1-readiness-checklist)
- [Live App-Server Findings](#live-app-server-findings)
- [Live Testing Expansion Plan](#live-testing-expansion-plan)
- [Previous V1 Release Slice](#previous-v1-release-slice)
- [Decisions Made For The First Interactive Lifecycle](#decisions-made-for-the-first-interactive-lifecycle)
- [Milestone 0: Package And Repo Baseline](#milestone-0-package-and-repo-baseline)
- [Milestone 1: Wire Model And Codegen Foundation](#milestone-1-wire-model-and-codegen-foundation)
- [Milestone 2: Stdio Transport And Typed Protocol Slice](#milestone-2-stdio-transport-and-typed-protocol-slice)
- [Milestone 3: Public Client Actor And First Lifecycle API](#milestone-3-public-client-actor-and-first-lifecycle-api)
- [Milestone 4: Event Streams And Ergonomic Handles](#milestone-4-event-streams-and-ergonomic-handles)
- [Milestone 5: Approvals, Richer Notifications, And Broader Protocol Coverage](#milestone-5-approvals-richer-notifications-and-broader-protocol-coverage)
- [Milestone 6: Public Docs, Examples, And Release Readiness](#milestone-6-public-docs-examples-and-release-readiness)
- [Open Tickets](#open-tickets)
- [Backlog Candidates](#backlog-candidates)
- [History](#history)

## Vision

- Make `SwiftASB` a small, dependable Swift package for talking to the local Codex app-server with a public API that feels native to Swift rather than like a thin JSON-RPC dump.

## Product Principles

- Keep the public API compact and easy to reason about.
- Keep generated wire models internal unless a public exposure case is clearly earned.
- Prefer explicit data models, actor ownership, and typed async streams over stringly fallback surfaces.
- Grow the package from real lifecycle use cases instead of speculative abstraction.
- Keep tests, maintainer notes, and roadmap status aligned with the actual shipped surface.

## Current Feature Matrix

| Area | Current Status | Notes |
| --- | --- | --- |
| Bundled schema-driven wire generation | `Shipped internally` | `scripts/generate-wire-types.sh` derives from the bundled v2 schema, patches dynamic JSON to `CodexWireJSONValue`, and validates the staged Swift output. |
| Promoted generated v2 wire snapshot | `Shipped internally` | `Sources/SwiftASB/Generated/CodexWire/Latest/` now contains a wider lifecycle batch covering bootstrap, stored and loaded thread reads, filesystem reads and watches, config reads, extension inventory, thread goals, and many thread, turn, item, reasoning, and tool-progress notifications, alongside the hand-owned `CodexWireInitializeResponse` shim. |
| Codex CLI schema review | `Shipped / ongoing` | The current reviewed compatibility window is `codex-cli 0.128.x`; the v0.128 schema families have been classified for the v1 boundary, and `scripts/dump-codex-schemas.sh` makes future versioned experimental dumps repeatable by default. Future Codex CLI schema families still need public/observable/internal decisions before promotion. |
| Stdio subprocess transport | `Shipped internally` | The transport launches `codex app-server --listen stdio://`, frames newline-delimited JSON, correlates request IDs, and captures stderr for diagnostics. |
| Raw server-event fanout | `Shipped internally` | Transport can stream raw JSON-RPC notifications and server requests to higher layers. |
| Typed protocol request encoding | `Shipped internally` | `initialize`, `initialized`, core thread and turn methods, archive-state actions, filesystem reads and watches, config reads, app/skill/plugin/collaboration-mode inventory, model/MCP/hook reads, MCP resource reads, and thread-goal methods are encoded through the protocol layer. |
| Typed protocol response decoding | `Shipped internally` | `initialize`, core thread and turn methods, archive-state actions, filesystem reads and watches, config reads, app/skill/plugin/collaboration-mode inventory, model/MCP/hook reads, MCP resource reads, and thread-goal responses are decoded and validated against request IDs. |
| Typed protocol notification decoding | `Partially shipped` | The protocol layer now maps a broader batch of app, thread, turn, item, reasoning, hook, MCP-status, config-warning, deprecation, remote-control, and reroute notifications, plus the item lifecycle needed to drive the current observable tool, MCP, file-edit, hook, and compaction summaries. |
| Public owning client actor | `Shipped` | `CodexAppServer` owns transport plus protocol and exposes startup, shutdown, initialize, thread start, and turn start. |
| Public value-typed request and result models | `Shipped` | Public API uses hand-owned Swift value types rather than exposing `CodexWire...` directly. |
| App-wide capability surfaces | `Partially shipped` | `CodexAppServer.listModels(...)`, `CodexAppServer.readModelCapabilities()`, `CodexAppServer.listMcpServerStatuses(...)`, `CodexAppServer.readMcpResource(...)`, and `CodexAppServer.listHooks(...)` now wrap `model/list`, `modelProvider/capabilities/read`, `mcpServerStatus/list`, `mcpServer/resource/read`, and `hooks/list` with hand-owned Swift models. These are connection-wide capability and diagnostics snapshots rather than thread-owned lifecycle actions. Broader app-wide settings and actions still need deliberate public models before promotion. |
| Initialize handshake | `Shipped` | `initialize(...)` automatically sends the follow-up `initialized` notification. |
| Thread start flow | `Shipped` | `startThread(...)` returns `CodexThread`, which carries thread metadata plus a back-reference to the shared app-server owner. |
| Stored thread list flow | `Shipped` | `listThreads(...)` wraps `thread/list`, returns typed stored-thread pages, and now reconciles local thread metadata plus explicit archived or unarchived list results back into the internal history store. |
| Stored thread read flow | `Shipped` | `readThread(...)` wraps `thread/read`, returns typed thread and turn values, and hydrates the internal history store when turns are requested. |
| Stored thread resume flow | `Shipped` | `resumeThread(...)` wraps `thread/resume`, returns a normal `CodexThread`, restores thread defaults, clears stale archived state for the reopened thread, and hydrates any resumed persisted turns into the same local history store without resetting completeness to a fresh-thread state. Callers can set `excludeTurns` when they plan to page history separately through `thread/turns/list`. |
| Stored thread fork flow | `Shipped` | `forkThread(...)` wraps `thread/fork`, returns a normal `CodexThread`, persists copied fork history into thread-scoped local turn rows, and records explicit fork lineage through the source thread id plus the last shared turn id. Callers can set `excludeTurns` when they want the fork metadata first and copied turn history through paged reads afterward. |
| Thread management actions | `Partially shipped` | `CodexThread.setName(...)` wraps `thread/name/set`, `CodexThread.archive()` wraps `thread/archive`, `CodexThread.unarchive()` wraps `thread/unarchive`, `CodexThread.updateMetadata(...)` wraps `thread/metadata/update`, and `CodexThread.rollbackLastTurns(...)` wraps `thread/rollback`. Metadata patches use an explicit replace/clear/unchanged field model so callers can express upstream null-vs-omitted semantics. Rollback reconciles visible local history to the app-server response, records a rollback marker, and now has opt-in live coverage against a disposable non-ephemeral thread, but it does not preserve full removed turn payloads as forensic archive data yet. |
| App-server filesystem reads and watches | `Partially shipped` | `CodexAppServer.fs` now exposes the `CodexFS` namespace for app-server-routed metadata, directory listing, file-byte reads, bounded file discovery, SwiftASB-owned fuzzy ranking over app-server-returned entries, UI-ready discovery match metadata, and filesystem watch notifications. This gives sandboxed clients a Codex-owned path for basic filesystem facts and picker/search views instead of requiring direct local disk reads. File mutations and repository-root discovery remain separate schema families for later promotion decisions. |
| App-server config reads | `Partially shipped` | `CodexAppServer.config` now exposes `CodexConfig` for effective config and requirements reads through the app-server. Effective config stays JSON-shaped for now so SwiftASB does not turn unstable config keys into long-lived public Swift fields too early. |
| App-server extension inventory | `Partially shipped` | `CodexAppServer.extensions` now exposes `CodexAppServer.CodexExtensions` for app, skill, plugin, and collaboration-mode inventory. Plugin install/uninstall/upgrade and skills config writes remain unpromoted until their permission and review model is clearer. |
| Thread goals | `Partially shipped` | `CodexThread.readGoal()`, `setGoal(...)`, and `clearGoal()` wrap `thread/goal/get`, `thread/goal/set`, and `thread/goal/clear`, and thread event streams now surface goal updated and cleared notifications. |
| Paged turn-history flow | `Shipped` | `listThreadTurns(...)` wraps `thread/turns/list`, returns typed paged turn values, and can now seed the local history cache even before that thread has been loaded locally. |
| Typed async thread event stream | `Partially shipped` | `CodexThread.events` now streams `thread/started`, `thread/status/changed`, `thread/archived`, `thread/unarchived`, `thread/name/updated`, `thread/tokenUsage/updated`, `thread/goal/updated`, `thread/goal/cleared`, and `thread/closed`, but broader thread lifecycle coverage is still pending. |
| Turn start flow | `Shipped` | `startTurn(...)` returns `CodexTurnHandle`. |
| Typed async turn event stream | `Partially shipped` | `CodexTurnHandle.events` now streams `turn/started`, `turn/plan/updated`, `turn/diff/updated`, item lifecycle updates, message deltas, reasoning deltas, and `turn/completed`, but broader item and thread events still remain internal. |
| Multiple active threads per app-server | `Shipped` | One `CodexAppServer` now supports many concurrently held `CodexThread` handles, and the package tests plus live probes treat cross-thread concurrency as a supported model. |
| Multiple simultaneous turns on one thread | `Resolved for now` | Live probing showed that same-thread overlap is not independently routable at the app-server layer today, so `SwiftASB` rejects overlapping same-thread turns client-side with `CodexAppServerError.invalidState`. |
| `CodexThread` convenience wrapper | `Partially shipped` | `CodexThread` exists, owns thread-scoped turn creation, includes a `startTextTurn(...)` happy-path helper, exposes a typed thread event stream, wraps `compactContext()`, and can now vend a live `Dashboard` observable mirror with aggregate tool-calling, MCP-calling, hook-run, and thread-compaction state. |
| Thread-scoped recent-turn observable | `Partially shipped` | `CodexThread.makeRecentTurns(limit:)` now vends a bounded recent-turn observable that prewarms from the local history store, supports explicit older/newer whole-turn window expansion, seeds upstream paging cursors even when the visible initial window came from local history, and falls back to `thread/turns/list` when needed. Live probing showed that upstream turn paging is available only after a non-ephemeral thread has materialized at least one user turn, so recent observable startup now degrades to an empty local-only view for the known ephemeral and pre-materialized live runtime responses instead of surfacing raw protocol text. `RecentTurns` now ships named cache-policy presets for chat UIs, full inspectors, and compact history rails; tracks both resident item counts and weighted resident item cost; slims low-value payloads out of older non-visible completed turns before evicting whole turns; rehydrates slimmed turns when they become visible again; and uses scroll-position, visibility, phase, and velocity signals to drive protected residency plus earlier prefetch. Richer weighting heuristics and deeper policy tuning are still open. |
| Thread-scoped recent-file observable | `Partially shipped` | `CodexThread.makeRecentFiles(limit:)` and `makeRecentFiles(_:)` now vend a file-centric recent-files observable that hydrates from persisted file-change items, keeps one resident entry per file-change item, enriches live entries from `item/fileChange/outputDelta` and `item/fileChange/patchUpdated`, can load older file entries from the same turn before stepping farther back through older turns, and supports selection-aware shell-versus-payload slimming with automatic payload rehydration for protected files. `CodexThread.RecentFilesQD` gives callers a repeatable descriptor for the initial resident file window and cache policy. Live probing exercises a real create/edit/delete scenario, and recent-file startup now inherits the same empty local-only degradation as recent-turns for the known live history-unavailable responses. The current weighting now accounts for diff structure and line volume, and shell summaries prefer concise edit summaries over raw terminal status when sealed payload is available. The remaining open work is better payload-cost calibration at the margins and richer structured patch presentation beyond the current text preview. |
| Thread-scoped recent-command observable | `Partially shipped` | `CodexThread.makeRecentCommands(limit:)` and `makeRecentCommands(_:)` now vend a command-centric recent-commands observable that hydrates from persisted `commandExecution` items, keeps one resident entry per command item, enriches live entries from `item/commandExecution/outputDelta`, can load older command entries from the same turn before stepping farther back through older turns, and supports selection-aware shell-versus-output slimming with automatic output rehydration for protected commands. `CodexThread.RecentCommandsQD` gives callers a repeatable descriptor for the initial resident command window and cache policy. Recent-command startup now inherits the same empty local-only degradation as recent-turns for the known live history-unavailable responses. Current output weighting accounts for output size and line structure, and shell summaries prefer concise command and output summaries over raw transport detail. The remaining open work is better output-cost calibration and sharper shell-summary heuristics. |
| App-wide observable companion | `In Progress` | `CodexAppServer.makeLibrary()` and `CodexAppServer.Library` now expose Core Data-backed value snapshots for unarchived, archived, cwd-grouped, and repository-grouped threads, `CodexWorkspace.ProjectInfo` identity for thread and group displays, bindable sort/grouping policies, thread-list query descriptors, scoped refresh actions, library-local selection, recently selected ordering, local reloads after app-wide thread/turn events, and app-wide model/MCP/hook snapshots for launcher and sidebar UI. `CodexWorkspace` now promotes active permission-profile provenance, runtime filesystem/network permission facts, and app-server-owned project identity from thread sessions, but the library still needs broader app-wide settings/actions. |
| Public query descriptors | `Partially shipped` | `CodexAppServer.ThreadListQD` now provides repeatable thread-list intent for direct app-server `thread/list` reads and app-wide `Library` loading, `CodexFS.FileDiscoveryQD` provides repeatable bounded file-discovery intent over app-server `fs/readDirectory` reads, `CodexThread.HistoryWindowQD` provides repeatable local completed-turn window intent for recent, older, newer, turn-centered, and item-centered reads, and `CodexThread.RecentFilesQD` plus `CodexThread.RecentCommandsQD` describe recent-activity companion startup. Repository grouping now uses `CodexWorkspace.ProjectInfo`, which identifies a project by Codex-reported Git origin when available and falls back to cwd. Remaining descriptor work includes broader public cursor semantics, selection-centered reads if a concrete caller needs them, and later search-hit hydration. |
| Non-UI local history-reading helpers | `Partially shipped` | `CodexThread` now exposes a lightweight `HistoryWindow` page shape for recent local history, older or newer local windows around a known boundary turn id, centered `windowAroundTurn(...)` reads, centered `windowAroundItem(...)` reads, direct `ClosedTurn` reads for one turn, and convenience array helpers over those same windows. This gives non-UI callers an intentional path into the local history store without binding a UI-oriented observable, while still deferring a broader public cursor model, transcript search surface, and richer history-query helpers. |
| Public API curation | `Shipped / ongoing` | The source-organization pass has split app-wide model, MCP, thread-management, history, and observable companion values into focused public files while preserving `CodexAppServer`, `CodexThread`, and `CodexTurnHandle` as the three real owners. The connected public-surface review closed the v1 ownership model; future curation should stay tied to concrete public API additions. |
| DocC documentation | `Shipped / ongoing` | `Sources/SwiftASB/SwiftASB.docc/` contains a package landing page, public-handle extension pages, conceptual articles for app-wide capabilities, interactive lifecycle, thread management, history/observable companions, generated-wire boundary notes, and copy-pasteable walkthroughs for startup, progress/approval handling, diagnostics/history, and SwiftUI observable companions. The catalog is validated through Xcode `docbuild`; future work is ordinary stale-link, prose, and symbol-comment refinement as the public API grows. |
| Swift Package Index readiness | `Shipped` | `.spi.yml` declares `SwiftASB` as the documentation target, and Swift Package Index lists `gaelic-ghost/SwiftASB` with a documentation link, compatibility/build results, Package ID `9B5839D9-9551-473F-A939-841534A3FC55`, and a 2026-05-06 update timestamp for the latest confirmed indexed release. Recheck SPI after the `v1.1.2` tag is published. |
| Contributor documentation split | `Shipped` | `README.md` is now focused on Swift and SwiftUI package users, while `CONTRIBUTING.md` owns contributor setup, validation, DocC, live-test flags, generated-wire refresh, and PR expectations. |
| `CodexTurnHandle` live observable companion | `Partially shipped` | `CodexTurnHandle` owns a live `Minimap` companion that is attached when the handle is created and maintains current-state call snapshots for command, file-edit, dynamic-tool, collab-tool, and MCP item activity. It also now mirrors whether thread context compaction is active for the turn and supports explicit `complete()` handoff into a caller-owned sealed turn snapshot. |
| Additional turn event mapping | `Partially shipped` | The public event layer covers the current interactive lifecycle plus the item-start and item-complete events needed for observable call-state mirrors. Raw command-output and file-change-output deltas now stay internal as transport detail but drive the shipped `RecentCommands` and `RecentFiles` companions, and streamed or patch-updated payloads are preserved when later completed snapshots are thinner. Richer MCP-progress detail still remains internal, while warning, guardian-warning, config-warning, deprecation, MCP-server-status, remote-control-status, model-reroute, and model-verification notifications now surface through hand-owned diagnostic events. |
| Server request / approval handling | `Partially shipped` | Typed approval and elicitation request models now surface on thread and turn event streams, explicit response APIs exist on `CodexThread` and `CodexTurnHandle`, request resolution is tracked by JSON-RPC request id, and deterministic command-approval plus permissions-approval completion are covered through the real app-server with a mock Responses provider. Diagnostics are now separated from control flows: passive warning/model/guardian signals are public diagnostics, while guardian denied-action approval remains internal until SwiftASB owns a stable request/response model for it. |
| Internal thread history persistence | `Partially shipped` | The package now has a Core Data-backed `ThreadHistoryStore` that persists live-built thread and turn history, hydrates stored turns from `thread/read`, `thread/resume`, `thread/fork`, and `thread/turns/list`, seeds previously unknown local threads from paged history, widens persisted turn identity to stay thread-scoped across forks, and records explicit fork lineage while preserving conservative reconciliation that keeps richer local detail when upstream stored history is thinner. Public history paging/search helpers and archive-retention policy are still open. |
| Convenience run API | `Not started` | No `run(...)` or one-shot text convenience layer yet. |
| Binary discovery and compatibility policy | `Partially shipped` | Explicit binary override exists, the docs now define a current-reviewed Codex CLI support window of `0.128.x`, transport startup checks PATH, common Homebrew paths, and the npm global prefix on macOS, and `cliExecutableDiagnostics()` now exposes the resolved binary, version string, and documented support-window assessment. Any further diagnostics work is now expansion rather than a missing baseline surface. |
| README-level consumer docs | `Shipped / ongoing` | The README covers installation, runtime assumptions, first-use examples, the supported lifecycle, SwiftUI companion surfaces, and the current Codex CLI compatibility window. Future README work should track new public API additions rather than prerelease readiness. |
| Agent workflow guidance | `Shipped / ongoing` | SwiftASB-specific Codex guidance now ships through `socket`'s [`swiftasb-skills`](https://github.com/gaelic-ghost/socket/tree/main/plugins/swiftasb-skills) plugin, with skills for explaining SwiftASB, choosing an integration shape, building SwiftUI-facing app state, and diagnosing integration failures. This repo now points package users and maintainers at that plugin while keeping SwiftASB source, DocC, tests, generated-wire review, and release notes here as the package source of truth. |
| End-to-end subprocess integration tests | `Shipped / ongoing` | The package includes opt-in live Codex CLI integration tests with temp workspaces and time limits, including raw transport startup, single-turn completion, cross-thread completion, app-wide model/MCP/hook diagnostics snapshots, thread-name mutation, stored-history materialization, same-thread concurrency probing, deterministic command and permissions approvals through a mock Responses provider, a best-effort prompt-driven approval-path probe, a disposable live rollback scenario, and a multi-turn file-mutation scenario that creates, edits, and deletes files through the real CLI. The umbrella runner is `scripts/run-live-codex-integration-tests.sh`; it defaults to the release-gate set and exposes focused modes for smoke, transport, capability, thread, turn, approval, file-scenario, rollback, same-thread, and all opt-in live tests. Stored-history materialization remains in focused `thread`/`all` runs instead of the release-gate smoke group because the live app-server can delay history materialization. |
| Apache 2.0 licensing | `Shipped` | The repo now carries the Apache License, Version 2.0 text, and README plus contributor docs describe current releases as Apache 2.0 licensed. |

## Milestone Progress

- Milestone 0: Package And Repo Baseline - Completed
- Milestone 1: Wire Model And Codegen Foundation - Completed
- Milestone 2: Stdio Transport And Typed Protocol Slice - Completed
- Milestone 3: Public Client Actor And First Lifecycle API - Completed
- Milestone 4: Event Streams And Ergonomic Handles - Completed
- Milestone 5: Approvals, Richer Notifications, And Broader Protocol Coverage - Completed
- Milestone 6: Public Docs, Examples, And Release Readiness - Completed

## Current Maintainer Priority

The next meaningful package step is no longer proving the v1 interactive
lifecycle, SPI visibility, basic history hydration, first-pass reconciliation,
or command-approval completion. Those slices now exist and shipped in the
`v1.1.2` baseline.

The next meaningful work is to widen the reviewed app-server schema and protocol
coverage before adding more public query descriptors. Descriptors should compile
against Codex-owned workspace, Git, file, and thread facts wherever possible,
rather than making SwiftASB or a sandboxed client infer repository identity by
walking the local filesystem.

The package can now:

- start turns through `CodexThread`
- stream typed thread and turn progress
- answer approval and elicitation requests through typed public models
- steer an active turn
- interrupt an active turn
- mirror per-turn command, file-edit, and MCP activity through `CodexTurnHandle.Minimap.callSnapshots`
- mirror thread-level tool, MCP, hook, and compaction status through `CodexThread.Dashboard`
- read a stored thread through `thread/read`
- list stored threads through `thread/list`
- page stored turn history through `thread/turns/list`
- hydrate the internal history store from both live item streams and upstream stored-history reads
- read centered local history windows around a known turn or item through
  `windowAroundTurn(...)` and `windowAroundItem(...)`
- set thread names, patch stored Git metadata, and roll back trailing turns
  through `CodexThread`
- archive and unarchive stored threads through `CodexThread`
- list app-wide model, MCP-server, MCP-resource, and hook diagnostics snapshots
  through `CodexAppServer`
- document the supported lifecycle in the README without sending consumers into
  the tests

That means the current priority order is:

1. Review the currently bundled app-server schema families that are not yet
   promoted through SwiftASB's hand-shaped protocol/public surfaces, with
   special attention to workspace, filesystem, Git/repository, and app-server
   action families that let sandboxed clients ask Codex for facts instead of
   reading disk directly.
2. Continue promoting app-server-owned workspace and Git facts beyond the
   current cwd, origin metadata, and runtime permission-profile provenance: Git
   worktree root if upstream exposes it, branch/SHA observables, and any
   workspace listing/search/status actions that upstream already owns.
3. Finish the next descriptor increment beyond the current list, history, and
   recent-activity descriptors: broader public cursor semantics, any
   selection-centered reads that become necessary, and later search-hit
   hydration.
4. Finish the next `CodexAppServer.Library` slice around richer Git observables
   and app-wide settings/actions, using promoted app-server facts and descriptor
   values where they make list and selection behavior explicit.
5. Keep tuning `RecentTurns`, `RecentFiles`, and `RecentCommands` after v1 as
   real UI usage teaches better calibration. The v1 review keeps the separate
   turn/file/command companions, current cache-policy names and defaults,
   selection/visibility protection, slimming behavior, and rehydration model as
   stable enough; remaining work is calibration and richer previews, not proving
   the model exists.
6. Keep future Codex CLI schema additions classified before public promotion:
   `excludeTurns` remains public on resume/fork request models because it
   directly supports the existing paged history model; permission-profile
   families stay internal until SwiftASB owns a deliberate public permission
   model; hooks, models, MCP status, and MCP resource reads remain app-wide
   diagnostics/capability snapshots; thread goals, realtime, fuzzy file search
   sessions, marketplace/account-management families, and guardian
   denied-action approval remain post-v1 until their consumer workflows are
   clearer.
5. Flesh out archive-aware retention and eviction beyond the current list-driven
   archive-state drift correction.
6. Add any sharper binary-discovery diagnostics we want alongside the
   current-reviewed compatibility window before a broader compatibility release.
7. Revisit whether a convenience `run(...)` API is earned only after the
   lower-level lifecycle has more production mileage.

## V1 Readiness Checklist

This checklist records the work that made `SwiftASB` ready for the `v1.1.2`
tag. The goal was not to make every possible app-server feature public before
v1. The goal was to make the supported lifecycle honest, durable, well
documented, and intentionally shaped.

### Release Boundary Decision

- [x] Decide whether the shipped interactive lifecycle is a credible v1 surface:
  thread start/resume/fork/read/list, turn start/control, typed progress,
  approvals, elicitation, diagnostics, local history hydration, recent
  observables, rollback, and app-wide model/MCP snapshots.
  Decision: yes. Treat v1 as the first stable Swift-native client surface for
  the core Codex app-server lifecycle, not as a promise that every generated
  app-server feature is public.
- [x] Explicitly classify each remaining Milestone 5 gap as `v1 blocker`,
  `v1 docs-only note`, or `post-v1`.
  Decision: the remaining unpromoted generated families listed below are
  post-v1 unless a real consumer workflow reclassifies one before the v1 API
  freeze.
- [x] Keep guardian denied-action approval internal for v1.
  Decision: post-v1. It needs a stable user-facing control-flow model for what
  is being approved and how a Swift consumer should answer it.
- [x] Keep marketplace upgrade, account-management variants, richer MCP
  progress, external-agent config import, structured patch rendering, and
  mixed recent activity out of v1.
  Decision: post-v1. The v1 surface should not widen just because the generated
  schema contains those families.
- [x] Decide whether the current rollback behavior is enough for v1.
  Decision: yes. `CodexThread.rollbackLastTurns(...)` may be stable for v1
  without preserving full removed-turn payloads as forensic archive data; richer
  rollback forensics are post-v1.

### Post-V1 Deferred Items

These are intentionally outside the v1 promise unless a concrete consumer
workflow earns them in a later feature release.

- [ ] Guardian denied-action approval with a stable request and response model.
- [x] Hooks list surface after v1. `CodexAppServer.listHooks(...)` exposes
  per-cwd hook metadata, warnings, and load errors through a deliberate
  diagnostics/capability API so Swift clients can show what hooks are active
  before a turn runs. Hook enable/disable mutation remains post-v1+ until the
  configuration-writing UX is clearer.
- [ ] Marketplace upgrade surfaces.
- [ ] Account-management variants, including provider-specific account families
  such as Amazon Bedrock.
- [ ] Richer MCP progress detail beyond the current dashboard/minimap summaries.
- [ ] External-agent config import surfaces.
- [x] File patch-updated text previews for `RecentFiles`.
- [ ] Structured patch rendering for `RecentFiles`.
- [ ] Mixed `RecentActivity` timeline. Keep `RecentTurns`, `RecentFiles`, and
  `RecentCommands` separate for v1.
- [ ] Review and promote more app-server schema families before widening query
  descriptors, prioritizing workspace, filesystem, Git/repository, and
  app-server action surfaces that let sandboxed clients ask Codex for facts
  instead of reading local disk directly.
- [ ] Finish the `CodexAppServer` app-wide observable companion with derived
  repository-root grouping, richer Git observables, and any broader app-wide
  settings/actions that earn public models.
- [ ] SwiftASB-owned query descriptors for thread lists, project grouping,
  history windows, selection-centered reads, and later search-hit hydration.
- [ ] Richer file-discovery hit metadata for UI highlighting and ranking
  explanations, without exposing generated wire shapes.
- [ ] Later upstream fuzzy file-search promotion after the app-server schema has
  a clear search, cursor, and result-stability contract.
- [ ] Broader public history cursor semantics.
- [ ] Transcript search.
- [ ] Richer non-UI history query helpers beyond the current local windows.
- [ ] Archive-aware retention and eviction beyond the current list-driven
  archive-state drift correction.
- [ ] Rollback forensic archival that preserves full removed-turn payloads.
- [ ] One-shot `run(...)` convenience API after the lower-level lifecycle is
  stable enough to hide honestly.
- [x] `swiftasb-skills` plugin guidance for agents building with SwiftASB.
  Decision: `socket` now owns the Codex-visible
  [`swiftasb-skills`](https://github.com/gaelic-ghost/socket/tree/main/plugins/swiftasb-skills)
  plugin with `explain-swiftasb`, `choose-integration-shape`,
  `build-swiftui-app`, and `diagnose-integration` skills. Keep this repo's
  package docs and DocC as the source of truth for SwiftASB behavior, then sync
  the plugin when public API, examples, compatibility windows, diagnostics,
  approval handling, validation, or recommended integration shape changes.
- [ ] Basic SwiftUI component library for SwiftASB consumers. Start with small,
  copyable components that demonstrate the stable observable companions:
  dashboard status, turn minimap call snapshots, recent turns, recent files,
  recent commands, diagnostics, and approval/elicitation prompts. Keep this as a
  development aide and example surface first; do not let it blur the core
  package API or force an app-specific design system into the library.

### Public API Curation

- [x] Inventory every public type, initializer, method, enum case, and default
  argument under `Sources/SwiftASB/Public/`.
  Decision: `docs/maintainers/v1-public-api-symbol-inventory.md` now records
  the SwiftPM public symbol graph for the v1 freeze, while
  `docs/maintainers/v1-public-api-audit.md` remains the durable decision
  checklist.
- [x] For each public symbol, decide whether it is stable for v1, should be
  renamed before v1, should become internal, or should move behind a narrower
  owning type.
  Progress: the access-control audit is now explicit. The first tightening pass
  removes the stale public `SwiftASB` namespace placeholder and narrows
  app-server-authored interactive request and passive diagnostic payload
  constructors so the package no longer exports template-era, request
  fabrication, or diagnostic-emission surfaces that consumers should not depend
  on. The second pass also removes marketplace-adjacent model upgrade fields
  from the public model-list shape while keeping the generated wire decode
  internal.
  Decision: completed in `docs/maintainers/v1-public-api-audit.md` and the
  regenerated symbol inventory. The final pre-v1 public graph records 1,107
  public/open symbols after the v0.128 sandbox-field cleanup, with no generated
  `CodexWire...` names exposed through the `SwiftASB` product.
- [x] Audit access control symbol-by-symbol before docs/examples: remove stale
  public placeholders, keep observable snapshots read-only unless callers need
  to construct them, keep request/response values constructible where consumers
  need to send or test them, and regenerate the public symbol inventory after
  each tightening pass.
  Decision: observable companion state has been reviewed. Companion construction
  stays internal, presentation state is read-only or `public private(set)`, and
  the mutable public companion fields are limited to caller-owned UI inputs.
  App-server-authored request identifiers and passive diagnostic payload
  constructors remain internal, while request and response values that callers
  need to send or test remain constructible.
- [x] Review `CodexAppServer`, `CodexThread`, `CodexTurnHandle`, `Dashboard`,
  `Minimap`, `RecentTurns`, `RecentFiles`, `RecentCommands`, history-window
  helpers, diagnostics, approval, elicitation, model, MCP, and thread-management
  surfaces as one connected API rather than as separate shipped slices.
  Decision: keep the connected v1 owner model. `CodexAppServer` remains the
  root subprocess owner and low-level app-wide operation surface;
  `CodexThread` remains the high-level conversation handle for thread-scoped
  actions, history, request routing, and SwiftUI companions; `CodexTurnHandle`
  remains the active-turn control and completion surface. Dashboard, minimap,
  recent-turn, recent-file, and recent-command companions are current-state or
  bounded-history mirrors, not alternate protocol owners. Diagnostics remain
  passive events, and model/MCP reads remain app-wide snapshots.
- [x] Split any remaining oversized public source files where the split removes
  real navigation cost or clarifies ownership boundaries.
  Decision: no additional pre-v1 split is needed. The remaining large public
  actor source carries runtime entrypoints and internal mapping work; the
  consumer-facing request, result, model, MCP, thread-management, observable,
  diagnostics, approval, and elicitation values already live in focused files.
- [x] Tighten public names and parameter labels so callers can understand the
  operation without reading generated-wire terminology.
  Decision: the final connected-surface pass keeps the current owner and naming
  model for v1. The first field/default/enum vocabulary pass corrected the public
  execution-policy approval response case to
  `acceptWithExecPolicyAmendment(_:)`, matching the already-corrected
  `proposedExecPolicyAmendment` request field while keeping the private
  app-server wire spelling for compatibility.
- [x] Review default arguments for compatibility risk before v1, especially
  cache-policy defaults, history limits, binary-discovery defaults, and request
  options that mirror upstream Codex behavior.
  Decision: the audit now classifies defaults as compatibility promises. The
  first source-level documentation pass now covers the main default-bearing
  public initializers and methods, including nil app-server request omissions,
  SwiftASB local-history/UI page sizes, cache-policy derivation, and explicit
  response/update safety defaults.
- [x] Make sure public stream semantics are consistent: when streams buffer,
  when they finish, whether they throw, and which owner is responsible for
  answering or observing each event.
  Decision: documented in source comments, DocC, and the v1 audit. Thread and
  turn lifecycle streams are the canonical public event surfaces; diagnostics
  are passive app-wide signals; observable companions are current-state mirrors
  over live feeds rather than replayable logs.

### Documentation And Examples

- [x] Update stale release references after the `v1.1.2` release.
  Decision: README now names `v1.1.2` as the current released baseline and no
  longer describes the package as early development.
- [x] Finish DocC symbol comments for the supported lifecycle, not just the
  conceptual articles.
  Decision: the source-level documentation pass now covers
  `CodexAppServer`, `CodexThread`, and `CodexTurnHandle` lifecycle entrypoints,
  defaults, response routing, completion handoff, diagnostics, and history
  access, plus the stable public value types for model, MCP, thread-management,
  approval, elicitation, diagnostics, compatibility, and app-server bootstrap
  surfaces.
- [x] Add copy-pasteable DocC walkthroughs for: starting and initializing an
  app-server, starting a thread and turn, observing turn progress, answering an
  approval request, handling diagnostics, reading recent history, and using
  recent file/command companions in a SwiftUI view model.
  Decision: covered by the startup, progress/approval, diagnostics/history, and
  SwiftUI observable companion walkthroughs in `Sources/SwiftASB/SwiftASB.docc/`.
- [x] Keep README product-facing and concise, but make sure it names every
  v1-supported surface that a new consumer is expected to trust.
  Decision: README stays consumer-facing and names the supported app-server
  lifecycle, SwiftUI observable companions, diagnostics, model/MCP snapshots,
  local history, live probes, and the v1 compatibility boundary without
  duplicating maintainer workflow details.
- [x] Keep `CONTRIBUTING.md` focused on contributor workflow, generated schema
  refreshes, live-test flags, validation commands, release workflow, and
  temporary compatibility-shim policy.
  Decision: CONTRIBUTING remains the maintainer workflow home for local
  validation, schema generation, opt-in live tests, release steps, and temporary
  compatibility cleanup policy.
- [x] Run and keep clean the Xcode DocC validation path before the v1 tag.
  Decision: `xcodebuild docbuild -scheme SwiftASB -destination
  generic/platform=macOS -derivedDataPath tmp/xcode-docc/DerivedData` passed on
  2026-05-02 after the walkthrough and source-comment pass.

### Test And Runtime Confidence

- [x] Keep default `swift test` deterministic and local, with fake transport
  coverage for public API behavior.
  Decision: the default deterministic suite passed on 2026-05-02 with 147 Swift
  Testing tests; live Codex tests remained skipped unless their explicit
  environment flags or wrapper scripts were used.
- [x] Keep live Codex CLI tests opt-in, because the installed CLI and prompt
  behavior remain external local dependencies.
  Decision: live probes remain opt-in through `SWIFTASB_ENABLE_LIVE_CODEX_*`
  flags, focused wrapper scripts, and the umbrella
  `scripts/run-live-codex-integration-tests.sh` runner.
- [x] Run the opt-in live probes before v1 and record any observed behavior
  changes in `ROADMAP.md` or maintainer docs.
  Decision: the 2026-05-02 live confidence run passed the approval probe,
  multi-turn file mutation scenario, and rollback scenario against
  `codex-cli 0.128.0`; observed approval behavior changes are recorded in
  [Live App-Server Findings](#live-app-server-findings).
- [x] Resolve or deliberately narrow the subprocess timing flake where child
  process exit can sometimes surface as `unexpectedEndOfStream` with retained
  stderr instead of `processTerminated`.
  Decision: narrowed to the stable consumer contract. The subprocess-edge test
  now accepts either process termination or stdout EOF when the same fake child
  process exits after writing stderr, while still asserting that the retained
  stderr ring contains the expected last 20 lines.
- [x] Decide whether the existing multi-turn live file-mutation scenario is
  enough live coverage for v1, or whether v1 needs another deterministic real
  app-server scenario.
  Decision: enough for v1 when paired with the deterministic raw command
  approval probe and rollback probe. Additional permissions/MCP server-request
  families are post-v1 expansion work, not a v1 blocker.
- [x] Confirm approval/server-request coverage still proves the request,
  response, `serverRequest/resolved`, and terminal-turn path through the real
  app-server with a mock Responses provider.
  Decision: `scripts/run-live-codex-approval-probe.sh` passed on 2026-05-02,
  including the deterministic raw command approval path through real app-server
  request delivery, SwiftASB response, `serverRequest/resolved`, command
  completion, follow-up mock Responses call, and terminal `turn/completed`.

### Compatibility And Generated Wire

- [x] Audit active compatibility shims and give each one a removal trigger tied
  to the Codex CLI support window.
  Progress: the v0.125 permission-profile decode shim is removed as part of the
  v0.128 support-window advance; no generated-wire drift shim remains active.
- [x] Remove the v0.125 `permissionProfile` compatibility shim when the support
  window advanced beyond the older loose shape.
- [x] Confirm the promoted generated-wire snapshot matches the Codex CLI schema
  version included in the v1 compatibility window.
- [x] Classify the Codex CLI `v0.128.0` schema diff before promotion. Decision:
  generated permission-profile shapes remain internal, `hooks/list` is public
  as a read-only diagnostics/capability snapshot, model-provider capabilities
  are a clean public candidate, and thread goals, realtime, fuzzy file search,
  remote-control management, marketplace/account-management families, and
  guardian denied-action approval stay post-v1.
- [x] Confirm generated wire stays internal in docs, source organization, and
  public examples.
  Decision: generated wire remains internal scaffolding. Public docs and README
  describe hand-owned SwiftASB values, generated-wire references stay in
  maintainer docs/scripts/internal protocol tests, and repo-maintenance
  validation now fails if generated sources declare public symbols or public
  declarations expose `CodexWire...` names.
- [x] Re-run schema drift fixture coverage after any promoted generated-wire
  refresh.
  Progress: `swift test` has been rerun after the v0.128 promoted-wire refresh
  and exercises the v0.128 permission-profile fixtures, request/response
  envelopes, notification fixtures, and public conversion paths.
- [x] Decide whether v1 should support only the latest documented rolling window
  or whether a shorter first-v1 compatibility promise is more honest.
  Decision: use a narrow `0.128.x` support window for the first v1 boundary,
  then widen deliberately after generated-wire and public API review catches up
  with later Codex CLI releases.

### History And Observable Companions

- [x] Review `RecentTurns`, `RecentFiles`, and `RecentCommands` cache-policy
  names, defaults, selection behavior, slimming behavior, and rehydration
  semantics before v1.
  Decision: keep the separate companion families for v1. `RecentTurns` keeps
  named `chatUI`, `inspector`, and `historyRail` presets, while
  `RecentFiles` and `RecentCommands` keep automatic page-size-derived policies
  until real UI usage justifies more presets. Selection and visible-ID inputs
  remain caller-owned UI hints; presentation snapshots stay read-only. Payload
  and item slimming remains a cache-residency detail, and protected slimmed
  entries rehydrate from local history when selected or visible. Unsafe numeric
  cache-policy inputs are normalized consistently across all three companion
  families.
- [x] Decide whether archive-aware retention and eviction is a v1 blocker or a
  documented post-v1 history-store enhancement.
  Decision: post-v1. The v1 local-history promise is current non-archived cache
  use plus archive-state drift correction, not a durable archived-thread
  retention contract.
- [x] Decide whether broader public cursor semantics, transcript search, or
  richer non-UI history query helpers are post-v1.
  Decision: post-v1. Keep the current local `HistoryWindow` reads plus centered
  turn/item windows as the v1 non-UI surface; do not expose a broader public
  cursor or transcript-search contract before the local completeness model has
  more production mileage.
- [x] Keep `RecentActivity` out of v1 unless a real consumer workflow needs a
  mixed timeline; the current decision is to keep file, command, and turn
  companions separate.
  Decision: keep `RecentTurns`, `RecentFiles`, and `RecentCommands` separate
  for v1. A mixed feed remains post-v1 unless a concrete app workflow proves it
  improves scanning more than it muddies the ownership model.
- [x] Confirm history reads prefer local data only when local completeness is
  trustworthy, and still expose upstream failures through low-level APIs where
  callers need them.
  Decision: recent observables and local window helpers prefer the local history
  store only after SwiftASB has useful local completeness, and they degrade to
  empty local-only startup for known ephemeral or pre-materialized live history
  responses. Low-level `CodexAppServer.listThreadTurns(...)` remains the direct
  app-server paging surface and still reports upstream protocol failures.

### Packaging And Release Verification

- [x] Confirm Swift Package Index listing and DocC rendering after the latest
  public tag is indexed.
  Decision: completed on 2026-05-06. Swift Package Index lists
  `gaelic-ghost/SwiftASB`, selects `v1.1.1`, exposes a Documentation link,
  shows compatibility/build results, and reports Package ID
  `9B5839D9-9551-473F-A939-841534A3FC55`.
- [x] Run `swift test`, `git diff --check`, and
  `bash scripts/repo-maintenance/validate-all.sh` before the v1 release branch.
  Decision: `swift build`, `swift test`,
  `bash scripts/repo-maintenance/validate-all.sh`, and `git diff --check`
  passed on the `release/v1.0.0` branch on 2026-05-02.
- [x] Run Xcode DocC validation before the v1 release branch.
  Decision: `xcodebuild docbuild -scheme SwiftASB -destination
  generic/platform=macOS -derivedDataPath tmp/xcode-docc/DerivedData` passed on
  the `release/v1.0.0` branch on 2026-05-02 and on the
  `release/v1.0.1-prep` branch on 2026-05-02.
- [x] Decide whether another targeted `v0.9.x` patch release is needed before
  `v1.1.2`, or whether the remaining work should go straight into the v1
  release branch.
  Decision: no additional `v0.9.x` patch is needed. The remaining work should go
  straight into the `v1.1.2` release branch.
- [x] Prepare v1 release notes with explicit sections for public surface,
  intentionally internal surfaces, compatibility window, migration notes,
  validation performed, and known post-v1 work.
  Decision: the v1 release notes draft below is the source text for the GitHub
  release object.

### V1 Release Notes Draft

#### Public Surface

- `CodexAppServer` is the root owner for starting/stopping the local Codex
  app-server subprocess, initializing the session, starting/resuming/forking
  threads, paging stored threads and turns, listing models, listing MCP server
  statuses, and reading passive diagnostics.
- `CodexThread` is the conversation-scoped owner for starting turns, observing
  thread events, naming threads, updating thread metadata, compacting context,
  rolling back trailing turns, reading local history windows, and creating
  SwiftUI-friendly observable companions.
- `CodexTurnHandle` is the active-turn owner for observing turn events,
  answering approval and elicitation requests, steering text, interrupting
  work, reading the minimap, and completing into a sealed turn snapshot.
- SwiftUI companion surfaces are stable for v1: `Dashboard`, `Minimap`,
  `RecentTurns`, `RecentFiles`, and `RecentCommands`.
- Public diagnostics cover runtime warnings, guardian warnings, config warnings,
  deprecation notices, MCP-server status changes, remote-control status changes,
  model reroutes, and model-verification events through hand-owned Swift values.

#### Intentionally Internal Surfaces

- Generated `CodexWire...` models remain internal scaffolding and are not part
  of the public Swift API.
- Broader app-server families remain post-v1 until their consumer workflows are
  clearer, including guardian denied-action approval, marketplace/account
  management, remote-control management, thread goals, realtime, fuzzy file search,
  hook mutation, external-agent config import, richer MCP progress, and
  structured patch previews.
- A one-shot `run(...)` convenience API is intentionally deferred until the
  lower-level lifecycle has more production mileage.

#### Compatibility Window

- The first v1 compatibility promise is intentionally narrow: reviewed support
  for Codex CLI `0.128.x`.
- SwiftASB discovers `codex` from an explicit executable URL, `PATH`, common
  Homebrew locations, or the npm global prefix, and exposes startup diagnostics
  through `cliExecutableDiagnostics()`.
- Future Codex CLI schema dumps must be classified before generated shapes are
  promoted to public or observable behavior.

#### Migration Notes

- Existing `v0.9.x` consumers should update the SwiftPM dependency to
  `from: "1.1.2"` once the tag is published.
- The v1 API surface has removed stale pre-v1 compatibility shims and phantom
  fields that no longer exist in the reviewed `v0.128.0` schema.
- Same-thread overlapping turns are rejected client-side with
  `CodexAppServerError.invalidState`; use separate threads for concurrent
  turns.
- Prompt-driven approval behavior remains runtime-dependent. Deterministic
  approval regression coverage uses the real app-server with a local mock
  Responses provider.

#### Validation Performed

- `swift build`
- `swift test`
- `bash scripts/repo-maintenance/validate-all.sh`
- `git diff --check`
- `xcodebuild docbuild -scheme SwiftASB -destination generic/platform=macOS -derivedDataPath tmp/xcode-docc/DerivedData`
- `scripts/run-live-codex-approval-probe.sh`
- `scripts/run-live-codex-file-scenario.sh`
- `scripts/run-live-codex-rollback-scenario.sh`

#### Known Post-V1 Work

- Keep an eye on future Swift Package Index builds after compatibility-window
  or DocC changes; the `v1.1.1` listing and documentation link are live, and
  `v1.1.2` should be rechecked after the patch tag is indexed.
- Add broader live server-request coverage for permissions and MCP elicitation
  if those become stronger public runtime guarantees.
- Continue tuning recent companion cache calibration, richer file previews,
  archive-aware retention, and rollback forensic archival.

## Live App-Server Findings

The current live Codex CLI probes have found real app-server behavior that should
shape `SwiftASB` rather than stay as one-off test knowledge.

- `thread/turns/list` rejects ephemeral threads. Recent observable startup now
  treats that known response as an empty local-only initial view instead of
  surfacing raw protocol text.
- `thread/turns/list` also rejects a non-ephemeral thread before the first user
  message materializes stored thread history. Recent-turn, recent-file, and
  recent-command observable startup now treats that known response as an empty
  local-only initial view. Unexpected `thread/turns/list` failures still remain
  failures.
- Approval prompts remain nondeterministic for prompt-driven live tests. Live
  scenarios should accept approval requests when they surface, but durable
  assertions should focus on terminal turn status, observable call snapshots, and
  filesystem or history outcomes.
- Upstream Codex app-server coverage proves the JSON-RPC server-request path is
  deterministic when the model stream is controlled. Their v2 app-server tests
  trigger `CommandExecutionRequestApproval`, `FileChangeRequestApproval`,
  `PermissionsRequestApproval`, and MCP elicitation requests with a mock
  Responses provider and then answer the JSON-RPC request before waiting for
  `serverRequest/resolved`. SwiftASB should mirror that shape with a local mock
  Responses server instead of treating prompt-driven live approval behavior as
  the only possible real-CLI test path.
- For ordinary command and file-change approvals, upstream uses mocked Responses
  tool-call events such as shell command and apply-patch calls under
  `approval_policy = "untrusted"` and `sandbox_mode = "read-only"` to force
  app-server request emission. For request-permissions coverage, upstream enables
  `[features] request_permissions_tool = true` and emits a `request_permissions`
  tool call. That gives SwiftASB a reproducible protocol path while still
  launching the real installed `codex app-server`.
- SwiftASB now has opt-in real-app-server coverage for the deterministic command
  approval path: an isolated `CODEX_HOME`, local mock Responses provider,
  command item, `waitingOnApproval` thread state, raw
  `item/commandExecution/requestApproval` JSON-RPC delivery, SwiftASB's
  response, `serverRequest/resolved`, command completion, and final
  `turn/completed`. The root cause of the former gap was local: the JSON-RPC
  envelope parser treated numeric request id `0` as a boolean because
  `JSONSerialization` bridges JSON numbers through `NSNumber`. SwiftASB now
  checks CoreFoundation boolean identity before accepting numeric request IDs.
  Upstream app-server protocol structs are intentionally JSON-RPC-like rather
  than strict JSON-RPC 2.0 and do not send or expect a `jsonrpc` version member,
  so SwiftASB should keep generated outbound envelopes aligned with that shape
  unless upstream changes the wire contract.
- `approvalPolicy: .onRequest` plus `approvalsReviewer: .user` does not force
  approval requests for workspace-write command, file-create, or file-edit
  turns in the current live runtime. The approval/server-request probe records
  those turns as completed command calls with no accepted approval kinds.
- Current v1 confidence run, 2026-05-02 with `codex-cli 0.128.0`: the isolated
  live-test Codex config using `approval_policy = "untrusted"`,
  `approvals_reviewer = "user"`, `sandbox_mode = "workspace-write"`, and an
  untrusted project now produces clean typed approval flow for command read,
  file create, file edit, and a read-only sandbox write candidate. SwiftASB
  accepted those approvals through the public surfaces, each turn completed, and
  the report recorded concrete command/file-edit call kinds plus expected file
  outcomes. This supersedes the earlier timeout finding from the exploratory
  `.onRequest`/strict-probe attempts.
- `scripts/run-live-codex-approval-probe.sh` is the preferred exploratory
  validation for approval/server-request candidates. It opts into the live probe
  and writes `live-approval-server-request-probe.json` under
  `tmp/live-codex-reports/` so maintainers can inspect attempted Codex config,
  observed call kinds, approval kinds, terminal text, file outcomes, and probe
  errors after a real CLI run.
- `scripts/run-live-codex-file-scenario.sh` is the preferred validation for the
  create/edit/delete path. It opts into the live file scenario and writes a JSON
  diagnostic report under `tmp/live-codex-reports/` so maintainers can inspect
  observed call kinds, approval kinds, recent-file snapshots, and recent-command
  snapshots after a real CLI run.
- Test coverage audit, 2026-04-28: protocol encode/decode tests should assert
  the app-server's JSON-RPC-like envelope shape directly. The upstream protocol
  does not include `jsonrpc = "2.0"` on requests, notifications, or responses,
  and `initialized` has no `params` field. Keep the default fake-transport tests
  responsible for public-client routing and history behavior, and keep opt-in
  live tests responsible for installed-runtime behavior. Raw command-approval
  request delivery plus `serverRequest/resolved` is now covered through the real
  app-server; the remaining live approval findings are prompt-driven runtime
  behavior and additional server-request families.
- Test coverage audit, 2026-05-02: the default deterministic suite now has 147
  Swift Testing tests and directly covers the public `CodexAppServerError`
  description/wrapping contract in addition to the existing protocol, transport,
  public-client, observable companion, generated-wire, diagnostics, approval,
  elicitation, model, MCP, thread-management, and history coverage. The
  remaining intentional gap is not local unit coverage; it is live breadth for
  future server-request families such as permissions and MCP elicitation when
  SwiftASB chooses to promote those as stronger public runtime guarantees.
- Test coverage audit, 2026-05-06: deterministic promoted-schema coverage now
  exercises `CodexFS.FileDiscoveryQD` depth, hidden-entry, no-match, and fuzzy
  ranking behavior over app-server `fs/readDirectory` fixtures; richer
  `CodexConfig` and `CodexAppServer.CodexExtensions` optional fields; and
  `thread/resume` plus `thread/fork` workspace-permission selection encoding.

### Test Coverage Gap Register

Keep this register current after `1.0.0`; tests are part of the public contract
because consumers are wrapping a fast-moving local runtime.

- Approval/server-request completion now has deterministic SwiftASB-owned
  coverage and a focused live app-server completion probe. Fake-transport
  public-client tests prove typed approval events surface through
  `CodexTurnHandle`, `respond(...)` writes the expected JSON-RPC result,
  `serverRequest/resolved` clears the route, and wrong-surface, wrong-kind,
  already-resolved, and wrong-thread responses fail with descriptive errors. The
  opt-in live raw mock-Responses probe now proves the real app-server
  can reach a command item plus `waitingOnApproval`, deliver an answerable
  `item/commandExecution/requestApproval` request with numeric id `0`, accept
  SwiftASB's response, emit `serverRequest/resolved`, complete the command, make
  the follow-up mock Responses call, and finish the turn.
- Malformed server-originated request coverage now covers missing-params
  notifications, unknown server-request methods, unsupported request ID types,
  malformed command approval, malformed file-change approval, malformed
  permissions approval, malformed tool user input, malformed MCP elicitation,
  route disappearance after resolution, wrong response surfaces, and
  request/response IDs routed through the wrong active thread.
- Live history coverage now includes an opt-in mock-Responses wrapper proving
  that a real non-ephemeral stored thread can complete harmless text-only turns,
  then read those turns back through `thread/read` and page them through
  `thread/turns/list`.
- Transport edge coverage now covers both envelope/line-buffer parsing and
  real subprocess failure modes. The default tests cover versionless app-server
  envelopes, optional tolerated `jsonrpc` fields, boolean/fractional/object
  request IDs, notifications without `params`, partial line draining, duplicate
  pending request IDs, pending response failure when the child process exits,
  recent-stderr retention, malformed stdout followed by a later valid response,
  and late duplicate response lines after a pending request has already been
  fulfilled.
- The subprocess-exit versus stdout-end ordering is intentionally tested by
  stable consumer contract now: pending responses must fail and retain recent
  stderr, whether the child-process race surfaces as process termination or
  stdout EOF first.
- Public app-server error coverage now directly asserts that invalid-state
  reasons pass through unchanged and that internal transport/protocol failures
  wrap into descriptive operation-scoped `CodexAppServerError` values.
- Schema drift guardrails now include generated-wire fixture payloads for
  `thread/read`, `thread/turns/list`, command-execution thread items,
  active thread status flags, additive thread fields, and
  `serverRequest/resolved`. Keep adding one fixture whenever a promoted schema
  family graduates from generated-internal to public or observable behavior.
  The policy is: promotion from generated-internal to public or observable
  behavior must include at least one representative fixture in the same PR,
  including one additive unknown field when the upstream shape is expected to
  remain forward-compatible.
- Promoted app-server surface coverage now includes deterministic request-shape
  assertions for `skills/list`, `plugin/list`, `plugin/read`,
  `thread/resume`, and `thread/fork`, plus representative optional-field
  decoding for app, skill, plugin, config layer, config origin, and
  file-discovery descriptors. Keep extending these deterministic fixtures before
  moving broader live runtime breadth into the release-gate matrix.

## Live Testing Expansion Plan

Now that `SwiftASB` has a v1 public API, live testing is a release-maintenance
surface. Its job is to prove the package still matches the installed Codex CLI
when app-server behavior changes underneath the Swift API.

### Release-Gate Live Probes

These are the small, high-signal live probes that should run before ordinary
releases:

- [x] Consolidate the current release-gate probes behind
  `scripts/run-live-codex-release-gate.sh`.
- [x] Add a clearer umbrella live integration-test runner at
  `scripts/run-live-codex-integration-tests.sh`.
- [x] Keep startup, initialize, binary diagnostics, app-wide model/MCP snapshot,
  single-turn, and cross-thread coverage in the release-gate set when their
  runtime cost stays reasonable.
- [x] Keep deterministic command approval with a mock Responses provider in the
  release-gate set.
- [x] Keep the multi-turn create/edit/delete file scenario in the release-gate
  set.
- [x] Keep the disposable stored-thread rollback scenario in the release-gate
  set.

Release-gate probes should fail when SwiftASB's documented v1 contract is
broken. They should stay small enough that maintainers can run them during
release prep without turning every release into an exploratory runtime study.

### Compatibility And Behavior Probes

These probes are observational and should write JSON reports. They should fail
only when SwiftASB's documented contract breaks; otherwise behavior drift should
be recorded in this roadmap or maintainer docs.

- [x] Approval-policy matrix: `.never`, `.onRequest`, `.untrusted`, and
  `.granular`.
- [x] Sandbox matrix: `.readOnly` and `.workspaceWrite`. Keep tightly isolated
  danger-full-access coverage out of the first matrix until the test workspace
  makes the risk clear.
- [x] Same-thread overlap probe, kept observational until upstream app-server
  semantics become independently routable.
- [x] Ephemeral and pre-materialized thread-history behavior probes.
- [x] Codex CLI version/support-window diagnostics probe that records the
  installed runtime, schema dump availability, and SwiftASB compatibility
  result.

### Server-Request Family Probes

Every promoted answerable server-request family should have both deterministic
fake-transport unit coverage and an opt-in real app-server probe when the real
runtime can be driven with a mock Responses provider.

- [x] Permissions approval / request-permissions tool path.
- [x] Tool user input.
  Decision: deterministic fake-transport coverage proves public routing and
  response behavior, and the opt-in live server-request runner now drives the
  real app-server with a mock Responses `request_user_input` call in plan
  collaboration mode. The probe asserts `item/tool/requestUserInput` delivery,
  SwiftASB's JSON-RPC response, `serverRequest/resolved`, and terminal turn
  completion.
- [x] MCP server elicitation.
  Decision: deterministic fake-transport coverage proves public routing and
  response behavior, and the opt-in live server-request runner now drives an
  app-connector MCP fixture through the real app-server. The probe asserts MCP
  tool-call delivery, `mcpServer/elicitation/request` delivery, SwiftASB's
  JSON-RPC response, `serverRequest/resolved`, and terminal turn completion.
  The regular stdio MCP fixture remains in the runner as model-to-MCP tool-path
  evidence, while app-connector MCP is the deterministic live elicitation
  coverage source.
- [ ] Guardian denied-action approval after SwiftASB owns a stable public model.
- [x] Model capability snapshot through `CodexAppServer.readModelCapabilities()`.

### Harness And Script Shape

Live tests should grow a shared harness instead of more one-off setup code.
The harness should own temporary workspaces, isolated `CODEX_HOME`, Codex config
generation, mock Responses provider startup, report writing, timeouts, cleanup,
and optional workspace retention for debugging.

Planned script entrypoints:

- [x] `scripts/run-live-codex-integration-tests.sh`
- [x] `scripts/run-live-codex-release-gate.sh`
- [x] `scripts/run-live-codex-behavior-matrix.sh`
- [x] Add a focused mode or companion script for remaining answerable
  server-request families once tool-user-input and MCP elicitation probes are
  promoted into live coverage.

The live script surface should support these environment knobs consistently:

- `SWIFTASB_LIVE_CODEX_TIMEOUT_SECONDS`
- `SWIFTASB_LIVE_CODEX_REPORT_DIR`
- `SWIFTASB_LIVE_CODEX_KEEP_WORKSPACES=1`
- `SWIFTASB_LIVE_CODEX_BIN=/path/to/codex`

### First Implementation Slice

The first post-v1 live-testing slice is the consolidated release-gate runner.
It runs the currently proven high-signal probes in order: broad smoke coverage
for startup, raw transport initialize/thread/turn, binary diagnostics,
app-wide model/MCP/hook snapshots, thread-name mutation, single-turn,
cross-thread, and same-thread behavior; deterministic approval/server-request
coverage; the multi-turn file mutation scenario; and rollback. The permissions
approval mock-Responses probe now covers the largest answerable server-request
family gap. The umbrella live integration-test runner now gives maintainers one
entrypoint for release-gate, focused, and full opt-in live coverage, with
`SWIFTASB_LIVE_CODEX_TIMEOUT_SECONDS` available when a slower runtime needs a
longer per-operation timeout.

## Previous V1 Release Slice

This section records the release-hardening slice that produced the first
interactive lifecycle release. Keep it as historical release-boundary context,
not as the current maintainer priority.

### Shipped in the v0.9.x lifecycle slice

- Enough notification coverage that a consumer can build a multi-turn interactive flow without dropping to raw payloads.
- Observable current-state companions for in-flight call activity and blocked thread state so UI consumers can show "what is happening right now" without replaying raw deltas themselves.
- A written release boundary that says what is public, what stays internal scaffolding, and what is intentionally unsupported.
- A maintainer-facing classification of generated notification families as public now, observable-only for now, or internal-only for now.
- The first deliberate public thread-management expansion beyond `thread/start`, with `thread/list`, `thread/read`, `thread/resume`, `thread/fork`, and `thread/turns/list` now landed.
- Version-compatibility guidance and baseline discovery diagnostics for the local Codex CLI runtime.
- Protocol/event promotion required to support the current release boundary, with richer tool, file-edit, and MCP detail feeding companion observables rather than widening into raw generated public payloads.
- A written and implemented boundary for recent completed turns: thread-scoped recent-turn observables for UI, plus explicit `CodexTurnHandle.complete()` for caller-owned sealed turn values.
- Centered local history reads through `windowAroundTurn(...)` and
  `windowAroundItem(...)` before any broader cursor or transcript-search
  contract.
- A `v0.128.0` experimental schema compatibility pass has refreshed the staging
  generator, updated the Codex CLI compatibility window, kept generated
  permission-profile shapes internal, removed the older permission-profile
  compatibility shim, and promoted `hooks/list` as a post-v1 public
  diagnostics/capability surface.
- API curation and DocC docs good enough that a Swift consumer can understand
  the supported package surface without reading maintainer notes, including
  walkthroughs for the primary v1 lifecycle jobs.

### Remaining post-v1 follow-up

- [x] Complete the public API inventory and freeze decisions recorded in
  `docs/maintainers/v1-public-api-audit.md`.
- [x] Finish the targeted source-level symbol documentation skim for the
  supported lifecycle.
- [x] Keep default local tests deterministic, narrow or document the known
  subprocess timing flake, and run the opt-in live probes before the v1 tag.
- [x] Audit active compatibility shims and tie each removal trigger to the current
  reviewed Codex CLI support window.
- [x] Confirm Swift Package Index listing and DocC rendering after the latest public
  tag is indexed.
  Decision: completed on 2026-05-06 for `v1.1.1`.

### Deferred By The V1 Release Boundary

- A one-shot `run(...)` convenience API.
- Broader sugar beyond `startTextTurn(...)`.
- Public exposure of generated wire models.
- Expanding the public API just because the generated schema contains more message types.
- Guardian denied-action approval until SwiftASB owns a stable request and
  response model for that control flow.
- Marketplace upgrade and account-management variants, including
  provider-specific account families such as Amazon Bedrock.
- Richer MCP progress detail beyond the current dashboard/minimap summaries.
- External-agent config import surfaces.
- Structured patch rendering for `RecentFiles`.
- Broader history cursor semantics, transcript search, and richer non-UI
  history query helpers beyond the current local windows.
- Archive-aware retention/eviction and rollback forensic archival of removed
  turn payloads.
- A mixed `RecentActivity` feed; keep `RecentTurns`, `RecentFiles`, and
  `RecentCommands` as separate first-class surfaces for v1.
- Treating the prompt-driven live approval-path probe as a deterministic release gate while that runtime repro remains non-deterministic.

### Exit signal for this slice

This slice is done when a Swift consumer can:

- start the app-server
- initialize a session
- start a thread
- start a turn
- observe meaningful thread and turn progress
- respond to approval or elicitation requests
- steer or interrupt an active turn through the public handle API
- understand, from the docs alone, which lifecycle surfaces are supported today
- understand which generated or protocol surfaces are intentionally not public yet

without needing raw JSON-RPC access or generated wire types.

## Decisions Made For The First Interactive Lifecycle

- Keep the current ownership model:
  - `CodexAppServer` owns transport, protocol, fanout, and server-request routing.
  - `CodexThread` remains the ergonomic thread handle.
  - `CodexTurnHandle` remains the ergonomic turn handle.
- Keep typed async streams as the canonical lifecycle surface.
- Keep `Dashboard` and `Minimap` as current-state mirrors of typed public events, not as a second control path.
- Use a stream-first model for approval and elicitation requests.
- Keep `ThreadItem` activity stream-first, with observable companions mirroring only selected latest-state summaries when useful.
- Keep `RecentTurns`, `RecentFiles`, and `RecentCommands` as separate public
  companions. Do not add a mixed `RecentActivity` surface for v1 because it
  would blur three already-clear consumer jobs.
- Promote additional notification families by supported-release intent, not by schema breadth alone.
- Keep public lifecycle failures unified under `CodexAppServerError`.
- Defer a one-shot `run(...)` API until the lower-level interactive lifecycle is complete enough to hide honestly.
- Do not add a `CodexSession` type at this layer; the package should keep connection ownership on `CodexAppServer` and conversation ownership on `CodexThread`.
- Keep app-wide configuration, settings, and actions on `CodexAppServer` when
  they describe the shared app-server connection rather than one thread or one
  turn. `CodexAppServer.Configuration` remains local process-launch
  configuration, not a remote settings model.
- Do not add a new top-level `CodexApp`, `CodexSettings`, or app-wide session
  owner for v1. Split `CodexAppServer` source files by responsibility during
  API curation if the file size gets in the way, but preserve one
  connection-wide public owner.
- If reusable execution knobs need a shared public value type later, prefer a narrow thread-scoped shape such as `CodexThreadDefaults` instead of a new top-level owner or a vague global config wrapper.
- Treat app-level defaults as inputs to new thread creation, and treat later user changes as persisted thread-scoped overrides so one thread's settings do not silently affect another.

## Milestone 0: Package And Repo Baseline

### Status

Completed

### Scope

- [x] Establish the initial SwiftPM package, baseline guidance, and first smoke-testable public namespace.

### Tickets

- [x] Create the SwiftPM library package scaffold.
- [x] Enable Swift 6 language mode.
- [x] Add repo-local guidance for package work.
- [x] Add a minimal public namespace and smoke-test coverage.
- [x] Add root `ROADMAP.md` so project planning has a durable home.

### Exit Criteria

- [x] `swift build` passes.
- [x] `swift test` passes.

## Milestone 1: Wire Model And Codegen Foundation

### Status

Completed

### Scope

- [x] Make the bundled Codex app-server v2 schema the repeatable generated-wire source of truth while keeping generated models internal.

### Tickets

- [x] Decide that the bundled Codex app-server v2 schema is the primary generated-wire source of truth.
- [x] Build a repeatable derivation flow that turns the bundled schema into a quicktype-friendly root.
- [x] Patch dynamic JSON holes to `CodexWireJSONValue`.
- [x] Promote the generated v2 lifecycle batch into `Sources/SwiftASB/Generated/CodexWire/Latest/`.
- [x] Expand the generated v2 lifecycle batch to include a broader notification/event family rather than only the minimal bootstrap slice.
- [x] Keep `CodexWireInitializeResponse` hand-owned until the upstream v2 schema exposes it directly.

### Exit Criteria

- [x] `scripts/generate-wire-types.sh` regenerates the staged wire layer successfully.
- [x] The promoted generated v2 batch compiles cleanly with the package.
- [x] The v1 generated batch is no longer required as a promoted compiled artifact.

## Milestone 2: Stdio Transport And Typed Protocol Slice

### Status

Completed

### Scope

- [x] Build the internal subprocess transport and typed protocol helpers needed for the first initialize, thread, and turn lifecycle.

### Tickets

- [x] Implement an internal stdio transport around `codex app-server --listen stdio://`.
- [x] Correlate JSON-RPC responses by request ID.
- [x] Fan out non-response inbound messages as raw server events.
- [x] Build typed protocol helpers for `initialize`, `initialized`, `thread/start`, and `turn/start`.
- [x] Add focused tests that prove envelope classification and protocol encode/decode behavior.

### Exit Criteria

- [x] Transport and protocol layers are buildable and covered by Swift Testing suites.
- [x] Protocol errors are descriptive and carry method-specific context.
- [x] The package has a stable internal seam between transport and protocol responsibilities.

## Milestone 3: Public Client Actor And First Lifecycle API

### Status

Completed

### Scope

- [x] Expose the first hand-owned public Swift API around startup, initialize, thread start, and turn start.

### Tickets

- [x] Implement a public `CodexAppServer` actor that owns transport plus protocol.
- [x] Keep the public request and response models hand-owned and Swift-shaped.
- [x] Expose `start()`, `stop()`, `initialize(...)`, `startThread(...)`, and `startTurn(...)`.
- [x] Enforce initialize-before-thread and initialize-before-turn lifecycle guards.
- [x] Map internal transport and protocol failures into public-facing `CodexAppServerError`.
- [x] Add deterministic public-client tests using an internal fake transport seam.

### Exit Criteria

- [x] The public client can complete initialize, thread start, and turn start in tests.
- [x] The initialize handshake sends `initialized` automatically.
- [x] The public API does not expose generated `CodexWire...` types.

## Milestone 4: Event Streams And Ergonomic Handles

### Status

Completed

### Scope

- [x] Shape the ergonomic thread and turn handles, event streams, and observable companions that make the package usable for interactive Swift clients.

### Tickets

- [x] Return `CodexTurnHandle` from `startTurn(...)`.
- [x] Expose a real `AsyncThrowingStream` for turn events.
- [x] Decode `turn/completed` into a typed public turn event.
- [x] Keep per-turn stream fanout owned by the public client actor.
- [x] Treat one `CodexAppServer` as the shared owner for many logical threads.
- [x] Add a lightweight `CodexThread` wrapper around the shared owning app-server.
- [x] Make multiple active threads a first-class supported consumer model once `CodexThread` exists.
- [x] Verify real app-server behavior for multiple simultaneous turns on the same thread.
- [x] Decide whether same-thread concurrent turns should be allowed, queued, or rejected in the public API.
- [x] Add a thread-scoped turn start API so normal consumers do not carry raw thread IDs around.
- [x] Add a simple text-only turn convenience on `CodexThread` for the common case.
- [x] Add live observable thread state via `CodexThread.Dashboard` and `makeDashboard()`.
- [x] Add live observable turn state via `CodexTurnHandle.Minimap` and the
  `minimap` property.
- [x] Decide whether additional convenience APIs belong as observable companions, async helpers, or neither.
  Decision: defer new convenience APIs for now; keep the current handle model and revisit helpers only after the interactive lifecycle is complete enough to hide honestly.
- [x] Decide how much terminal-event buffering should remain implicit versus explicit in the public API.
  Decision: typed public streams remain the canonical lifecycle surface, while `Dashboard` and `Minimap` keep only current-state mirror buffering rather than becoming a second event system.
- [x] Decide whether Milestone 4 is complete enough to freeze the current handle model before adding approval-driven surfaces above it.
  Decision: yes for ownership. `CodexAppServer`, `CodexThread`, `CodexTurnHandle`, `Dashboard`, and `Minimap` are the model Milestone 5 should build on.

### Exit Criteria

- [x] A started turn can emit at least one typed async event through a handle-owned stream.
- [x] `CodexThread` exists as a public ergonomic wrapper with a clear ownership model.
- [x] The documented concurrency model is explicit for both cross-thread and same-thread turn starts.
- [x] The remaining open questions for Milestone 4 are narrow enough that Milestone 5 can build on the current handles without likely reshaping them again.
- [x] Thread and turn handles plus their observable companions feel like the real public surface rather than transitional wrappers.

## Milestone 5: Approvals, Richer Notifications, And Broader Protocol Coverage

### Status

Completed

### Scope

- [x] Promote the interactive request, richer notification, and live subprocess coverage needed for a credible first interactive lifecycle release.

### Tickets

- [x] Add typed protocol mapping for an initial batch of generated thread, turn, item, and reasoning notifications beyond `turn/completed`.
- [x] Audit the generated lifecycle batch and explicitly mark which notification families matter for the first interactive public lifecycle.
- [x] Expand typed protocol mapping to the remaining generated notifications that matter for the first public interactive lifecycle, or deliberately classify them as companion-only or internal-only.
  Decision: complete for the v1 lifecycle boundary. Richer MCP progress,
  guardian denied-action approval, external-agent import, patch previews, mixed
  recent activity, and broader history/search surfaces are post-v1 unless a real
  consumer workflow reclassifies them.
- [x] Decide how to surface `ThreadItem`-level activity in the public API.
  Decision: stream-first, with observable companions limited to selected latest-state mirrors for UI-oriented summaries.
- [x] Add a public model for server-originated approval and elicitation requests.
- [x] Decide whether approval handling should be callback-based, stream-based, or both.
  Decision: stream-first. Approval and elicitation requests should arrive as typed public events, with answers sent through explicit public methods on the owning surface.
- [x] Add fake-transport tests that prove approval and elicitation messages can be observed and answered through the chosen public shape.
- [x] Add opt-in live coverage for app-wide model, MCP, and hook diagnostics snapshots plus a straightforward thread-management smoke path.
- [x] Add opt-in live coverage for a multi-turn file mutation scenario against the real CLI, with deterministic filesystem assertions and optional diagnostic report output.
- [x] Add opt-in live rollback coverage using a disposable thread with isolated harmless turns and explicit local rollback-marker assertions.
- [x] Add opt-in real-app-server coverage for deterministic approval setup using an isolated `CODEX_HOME`, a local mock Responses provider, and a real command item reaching `waitingOnApproval`.
- [x] Extend deterministic SwiftASB-owned approval coverage through typed public request delivery, SwiftASB response handling, route resolution, and response guardrails.
- [x] Extend opt-in raw real-app-server approval coverage through `item/commandExecution/requestApproval`, SwiftASB response handling, `serverRequest/resolved`, command completion, and `turn/completed`.
- [x] Tighten recent-history helper behavior around live `thread/turns/list` boundaries for ephemeral and pre-materialized threads.
- [x] Add cancellation or interruption flows that are part of the intended first public lifecycle.
- [x] Revisit whether more of the generated wire graph needs to be promoted into internal compiled sources, starting with the `v0.124.0` schema additions and their public/observable/internal classification.

### Exit Criteria

- [x] The repo has a deliberate answer for where approval requests, elicitation requests, and item-level activity belong in the public model.
- [x] The public API can represent the most important server-driven lifecycle events without dropping back to raw payloads.
- [x] Approval and user-input request handling has a deliberate public model.
- [x] The package covers a meaningful multi-turn interactive lifecycle rather than only the happy-path bootstrap, including thread management, diagnostics, approvals, local history hydration, recent observables, rollback, and live file-mutation coverage.
  Decision: richer MCP progress, guardian denied-action approval, external-agent import, patch previews, mixed recent activity, and broader history/search surfaces are post-v1 rather than Milestone 5 blockers.

## Milestone 6: Public Docs, Examples, And Release Readiness

### Status

Completed

### Scope

- [x] Keep the package understandable, verifiable, and releasable for Swift consumers without requiring them to read generated wire code or maintainer chat history.

### Tickets

- [x] Expand `README.md` with installation, runtime assumptions, and a minimal working example.
- [x] Document the local Codex CLI dependency and explicit binary override path clearly.
- [x] Add at least one consumer-facing example for initialize, thread start, turn start, event streaming, and approval handling.
- [x] Decide on the first release boundary and what remains intentionally internal.
- [x] Add an explicit "Supported Today" section to `README.md` that mirrors the real public lifecycle and concurrency contract.
- [x] Add a maintainer-facing note that clarifies which generated notification families intentionally remain internal for now.
- [x] Add version-compatibility policy notes for the local Codex binary.
- [x] Refresh the compatibility window and promoted generated snapshot against the current `v0.124.0` schema dump once the added endpoint, notification, and field families have been classified.
- [x] Curate the public API before v1 by splitting large source files along existing responsibility boundaries where still helpful, tightening public names/defaults, and finishing targeted source-level symbol documentation for the supported lifecycle.
  Decision: completed for the `v1.1.2` boundary through the public API audit,
  symbol inventory, source-comment pass, and focused public file organization.
- [x] Add the first DocC documentation catalog before v1, including a package landing page, public-handle topic groups, and conceptual articles for the interactive lifecycle, history companions, and generated-wire boundary.
- [x] Validate the DocC catalog through Xcode `docbuild` and document the maintainer command.
- [x] Add Swift Package Index metadata that declares `SwiftASB` as the documentation target.
- [x] Split package-user documentation from contributor workflow by keeping `README.md` product-focused and adding `CONTRIBUTING.md` for package development.
- [x] Expand DocC with deeper source-level symbol comments and more examples before a v1 tag.
  Decision: the first source-comment pass and four copy-pasteable walkthroughs
  now cover startup, progress/approvals, diagnostics/history, and SwiftUI
  observable companions. Keep any final pre-v1 edits focused on stale links,
  stale prose, and symbol comments that are still too terse.
- [x] Confirm the Swift Package Index listing after the package is publicly indexed and tagged.
  Decision: completed on 2026-05-06 for `v1.1.1`.
- [x] Decide whether real subprocess integration tests are required before the first release.
  Decision: yes, but as opt-in suites rather than as part of the default `swift test` path while the live Codex runtime remains an external local dependency.
- [x] Add an explicit source-available license for the package.

### Exit Criteria

- [x] A new consumer can understand what `SwiftASB` is, what it depends on, and how to use the first supported lifecycle slice.
- [x] The release boundary between public API, internal wire scaffolding, and unsupported protocol surfaces is explicit.
- [x] A new consumer can discover the supported interactive lifecycle, including approval handling if shipped, from docs and examples without reading tests or maintainer notes.
- [x] The roadmap can identify a credible `v0.x` release candidate instead of only an exploration phase.

## Open Tickets

- [x] Freeze the Milestone 4 handle model enough that Milestone 5 does not reopen the ownership story for `CodexAppServer`, `CodexThread`, `CodexTurnHandle`, `Dashboard`, and `Minimap`.
- [x] Audit the generated lifecycle graph and classify events as public now, observable-only for now, or internal-only for now.
- [x] Add `CodexThread` as a first-class public wrapper and move turn creation onto it.
- [x] Document and enforce the intended behavior for multiple active threads on one `CodexAppServer`.
- [x] Investigate same-thread concurrent turn behavior against the real app-server and codify the result.
  Result: cross-thread concurrent turns complete successfully through the live client, but same-thread overlap is not independently routable at the live app-server layer today. `SwiftASB` now rejects overlapping same-thread `startTurn(...)` calls client-side with a descriptive `CodexAppServerError.invalidState` until the upstream lifecycle semantics become reliable.
- [x] Map an initial progress-oriented notification batch into `CodexTurnEvent` so the stream covers more than completion.
- [x] Decide whether additional item lifecycle and thread-scoped notifications should join the public stream surface or instead only feed observable companions like `Dashboard` and `Minimap`.
  Decision: default to the public stream; use observable companions only for selected current-state mirrors.
- [x] Decide whether the public stream should surface protocol failures directly or always wrap them as `CodexAppServerError`.
  Decision: keep public lifecycle failures unified under `CodexAppServerError`, with internal causes preserved only as supporting detail.
- [x] Add a typed surface for approval requests and other server-originated request messages.
- [x] Add tests that prove approval and elicitation handling through the public surface before adding more convenience APIs.
- [x] Add centered non-UI history windows with `windowAroundTurn(...)` and `windowAroundItem(...)`.
- [x] Decide whether to add a mixed `RecentActivity` companion.
  Decision: no for v1. Keep `RecentTurns`, `RecentFiles`, and `RecentCommands` as separate, clearer public surfaces.
- [x] Classify and promote the `v0.124.0` schema changes deliberately instead of treating every additive generated type as public API.
- [x] Add API curation and DocC documentation as explicit v1-readiness work.
- [ ] Add a one-shot `run(...)` convenience API once the handle model feels stable.
- [x] Add consumer-facing examples for the supported interactive lifecycle before broadening the public API further.
- [x] Add a real subprocess-backed integration test harness once the supported event set is less volatile.
  Current shape: the repo now has an opt-in live harness for raw transport/protocol checks, public-client turn and concurrency probes, deterministic command-approval completion, disposable rollback, and a multi-turn real-CLI file mutation scenario with JSON report output; broader always-on subprocess coverage is still intentionally deferred.
- [x] Expand `README.md` with first-use examples and runtime expectations.
- [x] Make recent-history observables fit live app-server history availability more explicitly instead of surfacing raw `thread/turns/list` protocol errors for ephemeral or pre-materialized threads.

## Backlog Candidates

- [ ] Add a one-shot `run(...)` convenience API once the lower-level handle model is stable enough to hide honestly.
- [ ] Add a broader public history cursor or transcript search surface after the local history contract is clearer.
- [ ] Add richer MCP progress detail either as public event cases or as deeper observable companion state.
- [ ] Add guardian denied-action approval once SwiftASB owns a stable request and response model for that control flow.
- [ ] Add marketplace upgrade and account-management surfaces after SwiftASB has a concrete app-wide management workflow.
- [ ] Add external-agent config import surfaces after external-agent configuration becomes a public app-server management workflow.
- [ ] Add structured patch rendering for `RecentFiles`.
- [x] Add richer `CodexFS.FileDiscoveryHit` search metadata soon, including
  match kind, matched ranges, or ranking reason once UI highlighting needs an
  explicit public model.
- [ ] Promote an upstream app-server fuzzy file-search endpoint later if Codex
  owns indexing, ignore rules, pagination, and result stability clearly enough
  for SwiftASB to wrap it as a separate public API.
- [ ] Add archive-aware retention/eviction and rollback forensic archival for removed turn payloads.
- [x] Add live rollback coverage once the disposable-thread path is reliable enough to assert explicit local rollback markers.
- [x] Add a local-only startup mode for recent history observables when live upstream paging is unavailable because the thread is ephemeral or not yet materialized.
- [x] Confirm the Swift Package Index listing after the package is publicly indexed and tagged.
  Decision: completed on 2026-05-06 for `v1.1.1`.

## History

- 2026-04-25: Added Xcode `docbuild` DocC validation, Swift Package Index metadata, and warning-clean DocC links.
- 2026-04-25: Split README package-user guidance from contributor workflow in `CONTRIBUTING.md`.
- 2026-05-06: Marked the `v1.1.1` SPI listing confirmed, closed the completed v1 milestone status drift, and moved the active maintainer priority to post-v1 query descriptors plus app-library grouping.
- 2026-05-06: Reprioritized the next post-v1 slice around broader app-server schema and protocol promotion before additional query descriptors, so sandboxed clients can rely on Codex-owned workspace and Git facts instead of SwiftASB filesystem inference.
- 2026-05-06: Promoted the first read-only app-server filesystem slice through `CodexFS`, covering `fs/getMetadata`, `fs/readDirectory`, and `fs/readFile`, and added `thread/loaded/list` for loaded runtime thread ids.
- 2026-05-06: Removed the older `CodexThread` local workspace-file helpers after `CodexFS` became the promoted app-server-routed filesystem namespace.
- 2026-05-06: Promoted filesystem watches, config reads, extension inventory, and thread goals through `CodexFS`, `CodexConfig`, `CodexAppServer.CodexExtensions`, and `CodexThread` goal APIs.
- 2026-05-06: Added recent-file and recent-command descriptors, and taught app-wide library grouping to use app-server Git origin metadata with cwd fallback.
- 2026-05-06: Promoted workspace permission-profile selections and runtime permission facts through `CodexWorkspace`, and exposed active permission profiles on thread sessions and handles.
- 2026-05-06: Promoted bounded file discovery and fuzzy file lookup through `CodexFS.FileDiscoveryQD` and `CodexFS.discoverFiles(_:)`, keeping traversal on app-server `fs/readDirectory` while SwiftASB owns local ranking over returned entries.
- 2026-05-06: Expanded deterministic coverage for promoted file discovery, config, extension inventory, and workspace-permission request descriptors.
- 2026-05-07: Added UI-ready `CodexFS.FileDiscoveryHit` search metadata for match kind, matched file-name and relative-path character ranges, and stable ranking reasons.
