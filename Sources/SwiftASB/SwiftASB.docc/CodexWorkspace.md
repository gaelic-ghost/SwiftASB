# ``CodexWorkspace``

Use app-server-owned workspace permission facts.

## Overview

`CodexWorkspace` contains the workspace and permission values that Codex reports through thread sessions or accepts on thread and turn requests. SwiftASB does not derive these values by reading local directories. That keeps sandboxed clients attached to Codex-owned cwd, Git, filesystem, network, and permission-profile facts.

Use ``PermissionSelection`` when a caller wants a named app-server permissions profile for a new thread, resumed thread, fork, or turn:

```swift
let thread = try await appServer.startThread(
    .init(
        permissions: .workspace
    )
)
```

Codex CLI v0.135 accepts the selected profile id for new thread, resumed thread, fork, and turn requests. ``PermissionSelection/modifications`` is retained as source-compatible local metadata for older callers, but SwiftASB does not send those modifications to the v0.135 app-server because the upstream schema no longer accepts them.

Use ``SessionSnapshot`` or the workspace values on ``CodexThread`` when a UI needs to show what Codex actually activated for the session: current directory, Git metadata, instruction sources, legacy sandbox policy, and active profile id.

Use ``GitStatusSnapshot`` through ``CodexAppServer/Library/selectedGitStatus`` when a library UI wants live selected-worktree Git facts. SwiftASB starts from Codex-reported repository metadata, then uses sandboxed app-server `command/exec` for repository root, remotes, and porcelain status details that are not attached to stored thread metadata yet.

## Topics

### Request Selection

- ``PermissionSelection``
- ``PermissionSelectionModification``

### Runtime Profile

- ``SessionSnapshot``
- ``ActivePermissionProfile``
- ``ActivePermissionModification``
- ``PermissionProfile``
- ``FileSystemPermissions``
- ``FileSystemSandboxEntry``
- ``FileSystemAccessMode``
- ``FileSystemPath``
- ``FileSystemSpecialPath``
- ``NetworkPermissions``

### Git Observability

- ``ProjectInfo``
- ``RepositoryInfo``
- ``WorktreeSnapshot``
- ``GitStatusSnapshot``
- ``GitStatusSummary``
- ``GitRemoteInfo``
- ``GitFactSource``
