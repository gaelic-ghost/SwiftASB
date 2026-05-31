# ``CodexExtensions/Inventory``

Observe app-wide Codex catalogs and diagnostics without issuing every list request yourself.

## Overview

`Inventory` is the app-wide observable companion for routine capability and
extension UI. It refreshes model capabilities, global MCP summaries, hook
diagnostics, apps, skills, plugins, and collaboration modes through the
app-server, then publishes compact Swift values for SwiftUI and other
state-driven clients.

```swift
let inventory = try await appServer.extensions.makeInventory(
    configuration: .init(
        hookListCurrentDirectoryPaths: [workspaceURL.path],
        extensionCurrentDirectoryPaths: [workspaceURL.path]
    )
)

for app in inventory.apps {
    renderApp(app)
}
```

By default, Inventory loads once when it is created and refreshes again when the
app-server reports app-list, skill, or MCP-server status changes. Use
``refresh()`` for an explicit reload.

Direct methods on ``CodexExtensions`` remain available for
advanced callers that need one-off reads, custom pagination, or plugin-detail
inspection. Routine app, skill, plugin, and collaboration-mode displays should
prefer Inventory so SwiftASB owns refresh behavior.

## Topics

### Creating Inventory

- ``CodexExtensions/makeInventory(configuration:)``
- ``Configuration``
- ``Phase``

### Refresh State

- ``refresh()``
- ``phase``
- ``lastRefreshedAt``
- ``latestErrorDescription``

### App-Wide Snapshots

- ``modelCapabilities``
- ``mcpServers``
- ``hookListSnapshot``
- ``appListPage``
- ``skillListSnapshot``
- ``pluginListSnapshot``
- ``collaborationModes``

### Convenience Views

- ``apps``
- ``skillEntries``
- ``skills``
- ``pluginMarketplaces``
- ``collaborationModeEntries``
