# App-Wide Capabilities

Discover model, MCP-server, MCP-resource, hook diagnostics, and model-capability snapshots from the app-server owner.

## Overview

Some app-server operations describe the connection rather than one conversation thread. SwiftASB exposes opinionated snapshots on ``CodexAppServer`` and observable companions so consumers can populate settings screens, model pickers, feature gates, MCP inspectors, hook diagnostics, and other app-wide views without orchestrating every app-server read.

Use ``CodexExtensions/makeInventory(configuration:)`` for routine app-wide UI that needs model capabilities, global MCP summaries, hook diagnostics, apps, skills, plugins, and collaboration modes. Inventory loads these snapshots on creation by default and refreshes when the app-server reports app-list, skill, or MCP-server status changes.

Use ``CodexAppServer/makeLibrary(configuration:)`` when these same model, MCP, and hook snapshots should live beside observable stored-thread lists. ``CodexAppServer/Library/refreshAppSnapshots()`` reads the current app-wide snapshots and publishes them as Library state; MCP status uses SwiftASB's owned cache, and hook diagnostics use Library thread `cwd` values unless configuration passes explicit hook current-directory paths.

Use ``CodexAppServer/listModels(_:)``, ``CodexAppServer/readModelCapabilities()``, ``CodexAppServer/listHooks(_:)``, and ``CodexAppServer/extensions`` as direct escape hatches when the caller intentionally owns pagination, one-off reads, or custom refresh timing. Use ``CodexExtensions/MCP/statusSnapshot()`` to inspect SwiftASB's latest full MCP server catalog, including resources, resource templates, and tools. Use ``CodexExtensions/MCP/readResource(server:uri:threadID:)`` to read one advertised MCP resource. ``CodexExtensions/Plugins/upgradeMarketplace(_:)`` is the narrow maintenance mutation in this app-wide family: it upgrades an already-configured plugin marketplace through app-server `command/exec` and reports the operation through ``CodexAppServer/featureOperationEvents()``.

```swift
let inventory = try await appServer.extensions.makeInventory()

let modelCapabilities = inventory.modelCapabilities
let globalMCPServers = inventory.mcpServers
let hooks = inventory.hookListSnapshot
let apps = inventory.apps
let skills = inventory.skillEntries
let pluginMarketplaces = inventory.pluginMarketplaces
let collaborationModes = inventory.collaborationModes
```

When a caller intentionally owns one-off reads or inspector detail, use the
direct app-wide surfaces:

```swift
let models = try await appServer.listModels(
    .init(limit: 50, includeHidden: false)
)

let statuses = await appServer.extensions.mcp.statusSnapshot()

let resource = try await appServer.extensions.mcp.readResource(
    server: "docs",
    uri: "docs://swiftasb/current"
)

let hooks = try await appServer.listHooks(
    .init(currentDirectoryPaths: ["/absolute/path/to/workspace"])
)
```

These direct requests are snapshots. If your UI needs refresh behavior, prefer ``CodexExtensions/Inventory`` so SwiftASB owns the refresh path and notification handling. Use ``CodexAppServer/Library`` instead when the same model, MCP, and hook snapshots should sit beside stored-thread lists. Inventory, Library, and thread dashboard MCP state intentionally use ``CodexAppServer/McpServerSummary`` instead of the full catalog so common SwiftUI surfaces can stay compact.

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
- ``CodexExtensions/MCP/statusSnapshot()``
- ``CodexExtensions/MCP/readResource(server:uri:threadID:)``
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

- ``CodexExtensions/makeInventory(configuration:)``
- ``CodexExtensions/Inventory``
- ``CodexAppServer/extensions``
- ``CodexExtensions``
- ``CodexExtensions/Plugins/upgradeMarketplace(_:)``
- ``CodexExtensions/MarketplaceUpgradeRequest``
- ``CodexExtensions/MarketplaceUpgradeResult``
