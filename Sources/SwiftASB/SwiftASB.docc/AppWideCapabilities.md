# App-Wide Capabilities

Discover model, MCP-server, MCP-resource, hook diagnostics, and model-capability snapshots from the app-server owner.

## Overview

Some app-server operations describe the connection rather than one conversation thread. SwiftASB exposes opinionated snapshots on ``CodexAppServer`` and observable companions so consumers can populate settings screens, model pickers, feature gates, MCP inspectors, hook diagnostics, and other app-wide views without orchestrating every app-server read.

Use ``CodexAppServer/listModels(_:)`` to read the currently visible model catalog. Use ``CodexAppServer/readModelCapabilities()`` to decide whether the current model provider supports web search, image generation, or namespace tools. Use ``CodexAppServer/mcpServerStatusSnapshot()`` to inspect SwiftASB's latest configured MCP server catalog, including auth status, resources, resource templates, and tools. Use ``CodexAppServer/Library/mcpServers`` when an app-wide observable UI only needs server names, auth state, scope, and advertised capability counts. Use ``CodexAppServer/readMcpResource(_:)`` to read one advertised MCP resource. Use ``CodexAppServer/listHooks(_:)`` to inspect configured hooks, warnings, and load errors for one or more working directories before a turn runs.

Use ``CodexAppServer/makeLibrary(configuration:)`` when these same model, MCP, and hook snapshots should live beside observable stored-thread lists. ``CodexAppServer/Library/refreshAppSnapshots()`` reads the current app-wide snapshots and publishes them as Library state; MCP status uses SwiftASB's owned cache, and hook diagnostics use Library thread `cwd` values unless configuration passes explicit hook current-directory paths.

Use ``CodexAppServer/extensions`` for app, skill, plugin, and collaboration-mode inventory. ``CodexAppServer/CodexExtensions/upgradeMarketplace(_:)`` is the narrow maintenance mutation in this app-wide family: it upgrades an already-configured plugin marketplace through app-server `command/exec` and reports the operation through ``CodexAppServer/featureOperationEvents()``.

```swift
let models = try await appServer.listModels(
    .init(limit: 50, includeHidden: false)
)

let modelCapabilities = try await appServer.readModelCapabilities()

let statuses = await appServer.mcpServerStatusSnapshot()

let resource = try await appServer.readMcpResource(
    .init(server: "docs", uri: "docs://swiftasb/current")
)

let hooks = try await appServer.listHooks(
    .init(currentDirectoryPaths: ["/absolute/path/to/workspace"])
)
```

These requests are snapshots. If your UI needs refresh behavior, prefer ``CodexAppServer/Library`` so SwiftASB owns the refresh path and notification handling. Library and thread dashboard MCP state intentionally uses ``CodexAppServer/McpServerSummary`` instead of the full catalog so common SwiftUI surfaces can stay compact.

## Model Capabilities

Model capabilities are feature gates for the current model provider. They are useful before showing controls that rely on provider-owned behavior.

```swift
let capabilities = try await appServer.readModelCapabilities()

searchToggle.isEnabled = capabilities.webSearch
imageButton.isEnabled = capabilities.imageGeneration
namespaceToolsInspector.isHidden = !capabilities.namespaceTools
```

## Hook Diagnostics

Hook diagnostics are useful before a GUI starts a turn. A settings or inspector view can call ``CodexAppServer/listHooks(_:)`` for the selected workspace, show warnings and load errors directly, and still let empty hook lists render as a healthy "no configured hooks" state.

```swift
let snapshot = try await appServer.listHooks(
    .init(currentDirectoryPaths: [workspaceURL.path])
)

for entry in snapshot.entries {
    renderHookDiagnostics(
        workspace: entry.currentDirectoryPath,
        diagnostics: entry.diagnostics,
        enabledHooks: entry.enabledHooks,
        disabledHooks: entry.disabledHooks
    )
}
```

Use ``CodexAppServer/HookListSnapshot/hasDiagnostics`` for badges or sidebar state, ``CodexAppServer/HookListSnapshot/entry(forCurrentDirectoryPath:)`` to pull one workspace from a multi-workspace snapshot, and ``CodexAppServer/HookListEntry/diagnostics`` when the UI wants one display list instead of separate warning and error arrays.

## Pagination

Model and MCP status-list APIs accept an optional cursor and return an optional next cursor. Keep requesting pages until `nextCursor` is `nil`. MCP resource reads return the current contents for one server and URI. Hook diagnostics are returned as one snapshot grouped by working directory.

## Boundary

These types are public because a consumer can use them directly today. Other generated app-wide schema additions stay internal until there is a clear Swift-facing job for them.

## Topics

### Models

- ``CodexAppServer/listModels(_:)``
- ``CodexAppServer/readModelCapabilities()``
- ``CodexAppServer/ModelListRequest``
- ``CodexAppServer/ModelListPage``
- ``CodexAppServer/Model``
- ``CodexAppServer/ModelCapabilities``
- ``CodexAppServer/InputModality``
- ``CodexAppServer/ReasoningEffortOption``

### MCP Servers

- ``CodexAppServer/mcpServerStatusSnapshot()``
- ``CodexAppServer/readMcpResource(_:)``
- ``CodexAppServer/McpServerStatusListRequest``
- ``CodexAppServer/McpServerStatusPage``
- ``CodexAppServer/McpServerStatus``
- ``CodexAppServer/McpServerSummary``
- ``CodexAppServer/McpResource``
- ``CodexAppServer/McpResourceReadRequest``
- ``CodexAppServer/McpResourceReadResult``
- ``CodexAppServer/McpResourceContent``
- ``CodexAppServer/McpResourceTemplate``
- ``CodexAppServer/McpTool``

### Hooks

- ``CodexAppServer/listHooks(_:)``
- ``CodexAppServer/HookListRequest``
- ``CodexAppServer/HookListSnapshot``
- ``CodexAppServer/HookListEntry``
- ``CodexAppServer/HookMetadata``
- ``CodexAppServer/HookError``
- ``CodexAppServer/HookDiagnostic``

### Extensions

- ``CodexAppServer/extensions``
- ``CodexAppServer/CodexExtensions``
- ``CodexAppServer/CodexExtensions/upgradeMarketplace(_:)``
- ``CodexAppServer/CodexExtensions/MarketplaceUpgradeRequest``
- ``CodexAppServer/CodexExtensions/MarketplaceUpgradeResult``
