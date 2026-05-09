# Feature Permission Policy Plan

## Purpose

This note records the intended `SwiftASB` design for feature-level permission
policy before the package promotes convenience APIs that run Git commands,
refresh repo guidance, mutate config, or maintain installed extensions.

The goal is to make common, safe, idempotent developer workflows feel
trustworthy and quiet instead of forcing repeated review prompts. SwiftASB
should ask once at the feature-category boundary, keep read-only facts available
by default, and emit clear observable mutation events when an enabled feature
changes local state.

## Design Posture

SwiftASB should not build a second filesystem sandbox on top of Codex. The
Codex app-server already owns command sandboxing for `command/exec`, and
`command/exec` defaults to the user's configured permissions when no explicit
permission profile or legacy sandbox policy is supplied.

SwiftASB's job is narrower:

- expose typed feature categories instead of arbitrary shell access
- keep low-surprise read-only and inventory features enabled by default
- let consuming apps enable trusted mutation categories once
- make every mutation visible through human-readable events
- keep rollback and Git-based recovery paths close to any repo-writing feature

In plain language: permissions should protect users from surprising authority,
not punish them for using tools they intentionally enabled.

## Command Execution Boundary

Use `command/exec` for SwiftASB-owned Git and GitHub helpers that need an
external executable.

`command/exec` is the correct primitive because it:

- runs an argv vector in the Codex app-server sandbox
- does not create a thread or turn
- does not create user-message, command-execution, or transcript items
- can stream stdout and stderr through connection-scoped notifications
- defaults to the user's configured permissions when request overrides are
  omitted

Do not use `process/spawn` for permission-sensitive SwiftASB helpers.
`process/spawn` is explicitly unsandboxed on the host where the app-server is
running, and should remain an internal or advanced-process-control concern until
SwiftASB has a consumer workflow that justifies it.

Do not use thread shell-command flows for library-owned Git facts. Thread shell
commands are user-facing conversation activity and should remain part of the
thread/turn transcript model.

## Policy Ownership

Add a SwiftASB-owned app-wide policy model, separate from Codex's interactive
approval request types.

Avoid names like `SwiftASBApprovals` for the top-level owner because
`CodexApprovalRequest` already means server-originated approval requests that a
turn or thread must answer. Prefer language such as:

- `SwiftASBFeaturePolicy`
- `SwiftASBFeatureGate`
- `SwiftASBFeatureCategory`
- `SwiftASBHostAccess`

This policy describes what SwiftASB convenience features are allowed to do. It
does not describe every low-level Codex permission profile or sandbox rule.

## Feature Categories

Each category should have a stable id, user-facing name, description,
permission reason, default mode, current mode, sensitivity, and event policy.

Candidate modes:

- `enabled`: the feature can run
- `disabled`: the feature cannot run
- `readOnly`: the feature can read or inventory state but cannot mutate it

Candidate event policies:

- `quietReads`: read-only refreshes should not announce every poll
- `notifyOnMutation`: writes, upgrades, or repo changes must emit observable
  events
- `requireExplicitAction`: high-impact operations require a direct caller action
  even when the category is enabled

Initial categories:

| Category | Default | Event Policy | Scope |
| --- | --- | --- | --- |
| `gitObservability` | `enabled` | `quietReads` | Read branch, SHA, remotes, status summaries, repository identity, and Git availability through Codex-owned facts or sandboxed `command/exec`. |
| `extensionInventory` | `enabled` | `quietReads` | List installed apps, skills, plugins, marketplaces, collaboration modes, and update availability. |
| `extensionMaintenance` | `enabled` | `notifyOnMutation` | Upgrade already-installed extensions, plugins, skills, or marketplace entries. Installing new extensions and uninstalling existing ones should remain separate actions or stricter categories. |
| `swiftRepoGuidanceSync` | `disabled` | `notifyOnMutation` | Apply trusted, idempotent Apple/Swift repo guidance updates inside detected Git repositories with rollback support. |
| `gitActions` | `disabled` | `notifyOnMutation` | Run bounded typed Git intents such as branch creation, staging, commit preparation, or local rollback helpers. Push, force-push, and history rewriting should be stricter subcategories or explicit actions. |
| `configMutation` | `disabled` | `notifyOnMutation` | Write Codex or SwiftASB configuration values through app-server config-write surfaces once those surfaces have a stable public model. |
| `extensionMutation` | `disabled` | `notifyOnMutation` | Install new extensions, uninstall extensions, change extension config, or mutate extension sharing settings. |
| `worktreeAutomation` | `disabled` | `notifyOnMutation` | Create, update, or clean worktrees after the workspace/Git fact model and rollback story are explicit. |

Read-only categories being enabled by default is intentional. SwiftASB consumers
should not need to ask users repeatedly before showing basic developer-tool
facts that the app-server and Codex config already permit.

## Host Access Model

SwiftASB should support unsandboxed apps and sandboxed macOS apps with explicit
user-granted access to the home directory or another broad workspace root.

Model this as host access capability rather than as a feature category.

Candidate shape:

```swift
public struct SwiftASBHostAccess: Sendable, Equatable {
    public var homeDirectoryReadWriteGranted: Bool
    public var homeDirectoryURL: URL?
    public var accessSource: AccessSource
}

public enum AccessSource: Sendable, Equatable {
    case unsandboxed
    case securityScopedBookmark
    case userSelectedDirectory
    case fullDiskAccess
    case declaredByHostApp
    case unknown
}
```

The target practical assumption is: sandboxed, but the consuming application has
read-write access to the user's home directory or another broad workspace root.
That is close to the unsandboxed case while still supporting the realistic
sandboxed case for developer tools.

SwiftASB should still handle denial gracefully. On macOS, user-granted access,
security-scoped bookmarks, Full Disk Access, POSIX permissions, and mandatory
system protections can disagree in practice. A declared capability should make a
feature eligible to try work; it should not be treated as proof that every path
will succeed.

Apple's sandbox rules matter here:

- sandboxed apps can persist access to user-selected resources with
  security-scoped bookmarks
- resolved security-scoped URLs require balanced access calls while the resource
  is in use
- Full Disk Access is granted by the person using the app in System Settings,
  not acquired automatically by entitlement or code

## Observable Mutation Events

Every enabled mutation category must produce human-readable observable events.
These events are the low-friction alternative to repeated prompts.

Mutation events should include:

- category id
- stable operation id
- short title
- human-readable summary
- reason text
- start time and completion time
- affected paths when known
- commands run when applicable
- app-server method or SwiftASB intent kind
- result status
- rollback availability and rollback handle when available
- diagnostic text for failures

The event copy should answer: what changed, why SwiftASB changed it, where it
changed, and how to undo or inspect it.

Do not emit noisy events for routine read-only refreshes such as branch/SHA
hydration, installed-extension inventory, or update availability checks.

## Proactive Observable Refresh

`CodexAppServer.Library` should become proactive for safe expected facts.

When a thread or worktree is selected and `gitObservability` is enabled, the
library should refresh Git facts automatically:

- repository root when Codex or sandboxed command execution can provide it
- current branch
- current SHA
- origin/remotes
- dirty/clean status summary
- ahead/behind facts when cheap and safe

These values should hydrate existing app-wide observable snapshots instead of
forcing each consuming UI to run its own Git probes.

The first implementation should prefer Codex app-server-owned facts when they
exist, then use sandboxed `command/exec` as the fallback for Git facts that
upstream does not expose yet.

## Swift Repo Guidance Sync

`swiftRepoGuidanceSync` should be a trusted, idempotent repo-maintenance
category rather than a per-file approval prompt loop.

Rules for the first implementation:

- run only inside a detected Git repository
- require a clean or explicitly recoverable working tree unless the caller opts
  into working with existing changes
- update only the repo guidance surfaces owned by the selected workflow
- preserve intentional document structure
- emit one mutation event with the touched file list and summary
- provide a one-action rollback path when possible
- leave a clear diagnostic when rollback is unavailable

The initial workflow can be based on the open-source Apple Dev Skills sync
guidance because that source is trusted, maintained by Gale, and aligned with
SwiftASB's Swift/Apple package conventions.

## Typed Intents

Do not expose arbitrary command strings as the main public API.

Expose typed intents that SwiftASB can validate, describe, run, observe, and
eventually roll back. Examples:

- `refreshGitStatus(worktree:)`
- `refreshGitRemotes(worktree:)`
- `upgradeInstalledExtensions(_:)`
- `syncSwiftRepoGuidance(repository:)`
- `prepareGitCommit(repository:message:)`
- `rollbackGuidanceSync(handle:)`

Each intent should declare the feature category it requires and whether it is
read-only, idempotent maintenance, or mutation.

## Future `run(...)` And `liftoff(...)`

When SwiftASB grows a one-shot `run(...)` or larger `liftoff(...)` convenience
surface, feature policy should be part of its configuration.

The convenience API should accept an explicit policy value and should also have
safe defaults:

- read-only and inventory features enabled
- mutation features disabled except existing-extension maintenance if the
  consuming app chooses to keep that default
- host access unset unless the app declares or supplies it
- observable mutation events enabled

The convenience API should not hide mutations. It can make common work easy, but
it must still surface what changed.

## Implementation Slices

### Slice 1: Policy Types And Descriptors

Status: shipped on `docs/feature-permission-plan`.

- Add public feature-policy value types.
- Add built-in category descriptors with names, descriptions, reasons, defaults,
  sensitivity, and event policy.
- Add tests for defaults, stable ids, and category lookup.
- Document the categories in DocC.

### Slice 2: Command Execution Protocol Surface

Status: shipped on `docs/feature-permission-plan`.

- Promote app-server `command/exec` request/response types through an internal
  protocol layer.
- Keep raw process control internal.
- Add a small internal executor that runs argv commands through `command/exec`
  using default Codex permissions unless an implementation test intentionally
  supplies a sandbox override.
- Add live or fake-transport tests proving command output does not become thread
  transcript activity.

### Slice 3: Git Observability

- Add typed Git fact intents backed by app-server facts first and sandboxed
  `command/exec` fallback second.
- Hydrate `CodexWorkspace.WorktreeSnapshot` or a sibling Git-status snapshot
  with branch, SHA, root, remotes, and status summary when available.
- Wire safe refresh into `CodexAppServer.Library` selection/worktree refresh.
- Keep Git observability on by default.

### Slice 4: Mutation Event Stream

- Add an app-wide observable/event stream for SwiftASB-owned feature operations.
- Emit events for any enabled mutation category.
- Keep read-only refreshes quiet unless they fail in a user-visible way.

### Slice 5: Existing Extension Maintenance

- Promote the narrow installed-extension update path after the app-server schema
  and current Codex behavior are verified.
- Keep listing and update checks on by default.
- Treat new installs, uninstalls, config mutation, and sharing mutation as
  separate stricter categories.

### Slice 6: Swift Repo Guidance Sync

- Add the repo-detection, Git preflight, idempotent write, observable event, and
  rollback handle model.
- Start with the Apple/Swift guidance sync workflow.
- Keep the category disabled by default until the consuming app enables it.

## Definition Of Done

This plan is complete when SwiftASB can:

- describe built-in feature categories to a consuming UI
- keep read-only Git and extension inventory flows available by default
- allow a consuming app to enable mutation categories once
- run Git fact refreshes without creating thread transcript items
- emit clear mutation events when enabled categories change local state
- support sandboxed host apps that declare broad home/workspace access
- gracefully report denied filesystem or command access without confusing it
  with feature-policy denial

## Open Questions

- Should existing-extension upgrades be enabled by default, or should they start
  as `readOnly` with a recommended one-time enable prompt?
- Should Git pushes be part of `gitActions`, or a separate `gitRemoteActions`
  category?
- Should the host access model store security-scoped bookmark data itself, or
  should consuming apps own bookmark persistence and pass active access into
  SwiftASB?
- Should mutation events live on `CodexAppServer`, `CodexAppServer.Library`, or
  a dedicated app-wide operation center owned by `CodexAppServer`?
