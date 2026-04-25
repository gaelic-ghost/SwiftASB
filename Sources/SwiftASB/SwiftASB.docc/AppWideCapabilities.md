# App-Wide Capabilities

Discover model and MCP-server capability snapshots from the app-server owner.

## Overview

Some app-server operations describe the connection rather than one conversation thread. SwiftASB exposes those operations on ``CodexAppServer`` so consumers can populate settings screens, model pickers, MCP inspectors, and diagnostics without needing a thread handle.

Use ``CodexAppServer/listModels(_:)`` to read the currently visible model catalog. Use ``CodexAppServer/listMcpServerStatuses(_:)`` to inspect configured MCP servers, their auth status, and their resource, resource-template, and tool metadata.

```swift
let models = try await appServer.listModels(
    .init(limit: 50, includeHidden: false)
)

let statuses = try await appServer.listMcpServerStatuses(
    .init(detail: .toolsAndAuthOnly)
)
```

Both requests are snapshots. If your UI needs refresh behavior, keep that refresh policy in the caller and ask the app-server for a new page when needed.

## Pagination

Both capability APIs accept an optional cursor and return an optional next cursor. Keep requesting pages until `nextCursor` is `nil`.

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
- ``CodexAppServer/ModelUpgradeInfo``

### MCP Servers

- ``CodexAppServer/listMcpServerStatuses(_:)``
- ``CodexAppServer/McpServerStatusListRequest``
- ``CodexAppServer/McpServerStatusPage``
- ``CodexAppServer/McpServerStatus``
- ``CodexAppServer/McpResource``
- ``CodexAppServer/McpResourceTemplate``
- ``CodexAppServer/McpTool``
