# ``CodexAppServer/CodexExtensions``

Read app-server extension inventory.

## Overview

`CodexExtensions` is exposed through ``CodexAppServer/extensions``. Prefer
``CodexAppServer/makeInventory(configuration:)`` for routine app, skill,
plugin, and collaboration-mode UI so SwiftASB owns loading and notification
refresh. Use `CodexExtensions` directly when a caller intentionally owns
pagination, custom refresh timing, or one selected plugin detail.

```swift
let apps = try await appServer.extensions.listApps()
let skills = try await appServer.extensions.listSkills(
    .init(currentDirectoryPaths: [thread.currentDirectoryPath])
)
```

The namespace is read-only. Plugin install, uninstall, marketplace mutation, and
skill config writes remain unpromoted until SwiftASB has a clearer permission
and user-review story for those operations.

Plugin detail reads stay explicit because selecting one plugin to inspect is
caller intent. Detail responses include app, skill, MCP server, and hook
summaries so an extension inspector can show which entry points a plugin
contributes without reading plugin files directly.

## Topics

### Reads

- ``listApps(_:)``
- ``listSkills(_:)``
- ``listPlugins(_:)``
- ``readPlugin(_:)``
- ``listCollaborationModes()``

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
