# ``CodexWorkspace``

Use app-server-owned workspace permission facts.

## Overview

`CodexWorkspace` contains the workspace and permission values that Codex reports through thread sessions or accepts on thread and turn requests. SwiftASB does not derive these values by reading local directories. That keeps sandboxed clients attached to Codex-owned cwd, Git, filesystem, network, and permission-profile facts.

Use ``PermissionSelection`` when a caller wants a named app-server permissions profile for a new thread, resumed thread, fork, or turn:

```swift
let thread = try await appServer.startThread(
    .init(
        permissions: .init(
            id: ":workspace",
            modifications: [
                .init(additionalWritableRoot: "/tmp/project-fixtures"),
            ]
        )
    )
)
```

Use ``SessionSnapshot`` or the workspace values on ``CodexThread`` when a UI needs to show what Codex actually activated for the session: current directory, Git metadata, instruction sources, legacy sandbox policy, active profile id, and exact filesystem/network permissions.

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
