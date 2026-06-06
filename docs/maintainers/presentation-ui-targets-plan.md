# Presentation UI Targets Plan

This plan records the intended shape for SwiftASB UI component targets. The goal
is to let consuming macOS apps build high-performance Codex interfaces without
duplicating thread-list, transcript, selection, cache, and action mapping logic
between AppKit and SwiftUI.

Status: planned. No package targets have been added yet.

## Decision

Use a hybrid of the shared-presentation and AppKit-first options:

- `SwiftASB` remains the runtime, protocol, history, diagnostics, and observable
  companion package.
- `ASBPresentation` becomes the framework-neutral presentation target.
- `ASBAppKit` becomes the high-performance macOS component target.
- `ASBSwiftUI` becomes the ergonomic SwiftUI target, with native SwiftUI views
  for light surfaces and AppKit-backed wrappers for dense surfaces.

This is a durable building-block change. It creates one shared presentation
contract for both AppKit and SwiftUI while still allowing the dense renderers to
use AppKit data sources, reuse, selection, and scrolling behavior.

## Practical Failure Mode

The failure mode to avoid is letting AppKit and SwiftUI each invent their own
thread-list model, turn-list model, selection state, cache visibility inputs,
and action mapping. That would make the first components quick but would leave
two subtly different UI data paths to maintain.

The preferred data path is:

```text
SwiftASB runtime and companions
  -> ASBPresentation snapshots and intents
  -> ASBAppKit data sources and views or ASBSwiftUI views and wrappers
  -> ASBPresentation intents
  -> SwiftASB runtime actions
```

`ASBPresentation` must not become a hidden UI framework. It should not import
AppKit or SwiftUI. Its job is to own value snapshots, list identity, selection
inputs, viewport hints, and typed intents.

## Target Responsibilities

### SwiftASB

`SwiftASB` keeps the current public runtime model:

- `CodexAppServer`
- `CodexThread`
- `CodexTurnHandle`
- local history and reconciliation
- public query descriptors
- observable companions such as `Library`, `Agenda`, `Dashboard`,
  `RecentTurns`, `RecentFiles`, `RecentCommands`, and `Minimap`
- feature policy and operation events

Existing observable companions should not be moved wholesale into
`ASBPresentation`. They are useful public state owners and remain the primary
runtime-facing objects.

### ASBPresentation

`ASBPresentation` owns framework-neutral projections over SwiftASB state. It
adapts current-state companions into stable UI snapshots and maps UI commands
into typed intents.

Likely first families:

- `ThreadSidebarSnapshot`
- `ThreadSidebarSection`
- `ThreadSidebarItem`
- `ThreadSelectionState`
- `TurnTimelineSnapshot`
- `TurnTimelineSection`
- `TurnTimelineItem`
- `TurnTimelineViewportState`
- `RecentActivitySnapshot`
- `RecentActivityItem`
- `AgendaSnapshot`
- `DashboardSnapshot`
- `PresentationIntent`

The first implementation should keep these shapes intentionally small. Prefer
plain value types with stable identifiers over protocols or generic renderer
models. Add broader search, filtering, and decoration payloads only when a
component needs them.

### ASBAppKit

`ASBAppKit` owns high-density macOS UI. It should depend on `SwiftASB` and
`ASBPresentation`.

Likely first components:

- `ASBThreadSidebarView`
- `ASBTurnTimelineView`
- `ASBRecentActivityView`

The dense views should use AppKit collection, table, or outline data sources as
appropriate. Their data sources consume `ASBPresentation` snapshots and send
`ASBPresentation` intents back to a host-provided handler. AppKit-specific
concepts such as index paths, reuse identifiers, and view-controller lifetimes
must stay inside `ASBAppKit`.

### ASBSwiftUI

`ASBSwiftUI` owns SwiftUI ergonomics. It should depend on `SwiftASB`,
`ASBPresentation`, and, for AppKit-backed dense components on macOS,
`ASBAppKit`.

Likely first components:

- `ThreadSidebar`
- `TurnTimeline`
- `AgendaPanel`
- `DashboardPanel`

Use native SwiftUI for light surfaces such as agenda, dashboard, connection
status, empty states, controls, and small inspectors. Use AppKit-backed
representable wrappers for dense surfaces such as the thread sidebar and turn
timeline when scrolling, selection, reuse, or incremental updates are central to
the component.

## Ownership Rules

- SwiftASB owns runtime truth.
- Presentation snapshots are read-only value projections.
- Selection state belongs to the presentation/controller instance unless the
  host app explicitly persists it.
- Visibility and scroll-position inputs are UI hints, not runtime state.
- AppKit data sources own view reuse and index-path mechanics only.
- SwiftUI wrappers own SwiftUI environment, binding, and lifecycle adaptation
  only.
- User actions cross framework boundaries as typed intents, not closures that
  mutate arbitrary runtime state from inside reusable cells.

## Initial Data Contracts

### Thread Sidebar

Inputs:

- `CodexAppServer.Library`
- grouping and sorting choices from the library configuration or a presentation
  configuration
- selected thread id
- optional selected worktree or repository id

Snapshot outputs:

- sections for ungrouped, cwd, repository, or worktree grouping
- thread rows with stable ids, title, source badge, archive state, activity
  status, project/worktree summary, updated time, and optional Git status
- empty and loading states
- presentation errors that can be shown without exposing raw transport details

Intents:

- select thread
- open thread
- archive or unarchive thread
- refresh unarchived threads
- refresh archived threads
- refresh selected worktree Git status

### Turn Timeline

Inputs:

- `CodexThread.RecentTurns`
- active `CodexTurnHandle.Minimap` when a turn is running
- visibility and scroll-position hints from the renderer

Snapshot outputs:

- turn sections or rows with stable turn ids
- item rows with stable item ids and display kind
- compact display summaries for commands, files, MCP activity, reasoning, and
  messages
- loading and pagination affordances
- slimmed or rehydratable payload state when the recent-turn cache has trimmed
  older details

Intents:

- load older turns
- load newer turns when supported by the current query shape
- mark visible turn ids
- mark scroll anchor or viewport state
- select item
- rehydrate selected or visible payloads

### Agenda And Dashboard

Inputs:

- `CodexThread.Agenda`
- `CodexThread.Dashboard`

Snapshot outputs:

- current goal title and status
- current plan title and step list
- proposed plan text while planning is active
- tool, MCP, hook, compaction, and auto-review status summaries

Intents:

- start a planning turn
- set, pause, resume, or clear a goal
- answer approval or elicitation requests through the owning thread or turn

## Implementation Slices

### Slice 1: Planning And Package Boundary

- Add this maintainer plan.
- Update the roadmap backlog item from a basic SwiftUI component library to the
  hybrid presentation/UI target plan.
- Do not add targets yet.

### Slice 2: ASBPresentation Skeleton

- Add the `ASBPresentation` target and tests.
- Add the first value snapshot types for thread sidebar state.
- Add a small projection from `CodexAppServer.Library` into
  `ThreadSidebarSnapshot`.
- Add tests that prove stable identity, grouping, and selection behavior.

### Slice 3: ASBAppKit Sidebar Prototype

- Add the `ASBAppKit` target and tests where practical.
- Build `ASBThreadSidebarView` around AppKit data-source ownership.
- Keep item reuse, index paths, and AppKit selection inside the target.
- Emit typed presentation intents instead of mutating SwiftASB directly from
  view cells.

### Slice 4: ASBSwiftUI Sidebar Wrapper And Light Panels

- Add the `ASBSwiftUI` target.
- Add a SwiftUI `ThreadSidebar` wrapper around `ASBThreadSidebarView`.
- Add native SwiftUI `AgendaPanel` and `DashboardPanel` components because those
  are light current-state surfaces.
- Document when consumers should choose native SwiftUI components versus
  AppKit-backed wrappers.

### Slice 5: Turn Timeline

- Add `TurnTimelineSnapshot` in `ASBPresentation`.
- Add `ASBTurnTimelineView` in `ASBAppKit`.
- Add a SwiftUI `TurnTimeline` wrapper.
- Wire viewport and visible-item hints back to `CodexThread.RecentTurns` without
  exposing AppKit index paths or SwiftUI scroll internals through
  `ASBPresentation`.

## Validation Plan

For planning-only changes:

```bash
bash scripts/repo-maintenance/validate-all.sh
git diff --check
```

For target additions:

```bash
swift build
swift test
bash scripts/repo-maintenance/validate-all.sh
git diff --check
```

For AppKit components, add focused unit tests around presentation projection
and data-source snapshots first. UI interaction tests can follow once the view
surface has enough stable behavior to justify Xcode-managed test execution.

## Open Questions

- Should `ASBPresentation` expose only value snapshots, or should it also own
  small `@Observable` presenter objects that bridge SwiftASB companions to
  snapshots?
- Should `ASBSwiftUI` depend on `ASBAppKit` directly, or should AppKit-backed
  wrappers be isolated behind a macOS-only product if future non-macOS SwiftUI
  reuse becomes important?
- Should the first sidebar target use collection view, outline view, or table
  view? The likely answer is collection view for custom rows and modern
  layouts, but the first prototype should validate keyboard navigation,
  selection, row reuse, and grouped-section rendering.
- How much styling belongs in reusable components versus examples? The default
  should be enough visual structure to be useful, with host apps retaining
  theme and layout ownership.
