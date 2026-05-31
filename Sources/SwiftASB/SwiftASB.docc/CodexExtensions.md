# ``CodexExtensions``

Manage app-server extension inventory and extension-family helpers.

## Overview

`CodexExtensions` is exposed through ``CodexAppServer/extensions``. Prefer
``makeInventory(configuration:)`` for routine MCP, app, skill, plugin,
collaboration-mode, model, and hook UI so SwiftASB owns loading and notification
refresh. Use the family surfaces directly when a caller intentionally owns
pagination, custom refresh timing, or one selected plugin detail.

```swift
let apps = try await appServer.extensions.apps.list()
let skills = try await appServer.extensions.skills.list(
    .init(currentDirectoryPaths: [thread.currentDirectoryPath])
)
```

Use the unified install surface for extension-family installs:

```swift
try await appServer.extensions.install(.mcp(.stdio(name: "docs", command: "/usr/bin/env")))
```

Plugin install, uninstall, marketplace mutation, and skill config writes remain
unpromoted until SwiftASB has a clearer permission and user-review story for
those operations.

Plugin detail reads stay explicit because selecting one plugin to inspect is
caller intent. Detail responses include app, skill, MCP server, and hook
summaries so an extension inspector can show which entry points a plugin
contributes without reading plugin files directly.

## Topics

### Inventory

- ``makeInventory(configuration:)``
- ``Inventory``

### Families

- ``mcp``
- ``apps``
- ``skills``
- ``plugins``
- ``collaborationModes``
- ``install(_:)``
- ``InstallRequest``
- ``InstallResult``

### Apps

- ``AppListRequest``
- ``AppListPage``
- ``AppInfo``
- ``AppBranding``
- ``AppScreenshot``

### Skills

- ``SkillListRequest``
- ``SkillListSnapshot``
- ``SkillListEntry``
- ``SkillMetadata``
- ``SkillError``
- ``SkillSummary``

### Plugins

- ``PluginListRequest``
- ``PluginListSnapshot``
- ``PluginMarketplace``
- ``PluginSummary``
- ``PluginInterface``
- ``PluginReadRequest``
- ``PluginDetail``
- ``PluginHookSummary``
- ``MarketplaceLoadError``

### Collaboration Modes

- ``CollaborationModeList``
- ``CollaborationMode``
