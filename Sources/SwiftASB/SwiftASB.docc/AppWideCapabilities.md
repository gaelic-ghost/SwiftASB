# App-Wide Capabilities

Discover model, MCP-server, and hook diagnostics snapshots from the app-server owner.

## Overview

Some app-server operations describe the connection rather than one conversation thread. SwiftASB exposes those operations on ``CodexAppServer`` so consumers can populate settings screens, model pickers, MCP inspectors, hook diagnostics, and other app-wide views without needing a thread handle.

Use ``CodexAppServer/listModels(_:)`` to read the currently visible model catalog. Use ``CodexAppServer/listMcpServerStatuses(_:)`` to inspect configured MCP servers, their auth status, and their resource, resource-template, and tool metadata. Use ``CodexAppServer/listHooks(_:)`` to inspect configured hooks, warnings, and load errors for one or more working directories before a turn runs.

```swift
let models = try await appServer.listModels(
    .init(limit: 50, includeHidden: false)
)

let statuses = try await appServer.listMcpServerStatuses(
    .init(detail: .toolsAndAuthOnly)
)

let hooks = try await appServer.listHooks(
    .init(currentDirectoryPaths: ["/absolute/path/to/workspace"])
)
```

These requests are snapshots. If your UI needs refresh behavior, keep that refresh policy in the caller and ask the app-server for a new snapshot or page when needed.

## Pagination

Model and MCP capability APIs accept an optional cursor and return an optional next cursor. Keep requesting pages until `nextCursor` is `nil`. Hook diagnostics are returned as one snapshot grouped by working directory.

## Boundary

These types are public because a consumer can use them directly today. Other generated app-wide schema additions stay internal until there is a clear Swift-facing job for them.

## Topics

### Models

- ``CodexAppServer/listModels(_:)``
- ``CodexAppServer/ModelListRequest``
- ``CodexAppServer/ModelListPage``
- ``CodexAppServer/Model``
- ``CodexAppServer/InputModality``
- ``CodexAppServer/ReasoningEffortOption``

### MCP Servers

- ``CodexAppServer/listMcpServerStatuses(_:)``
- ``CodexAppServer/McpServerStatusListRequest``
- ``CodexAppServer/McpServerStatusPage``
- ``CodexAppServer/McpServerStatus``
- ``CodexAppServer/McpResource``
- ``CodexAppServer/McpResourceTemplate``
- ``CodexAppServer/McpTool``

### Hooks

- ``CodexAppServer/listHooks(_:)``
- ``CodexAppServer/HookListRequest``
- ``CodexAppServer/HookListSnapshot``
- ``CodexAppServer/HookListEntry``
- ``CodexAppServer/HookMetadata``
- ``CodexAppServer/HookError``
