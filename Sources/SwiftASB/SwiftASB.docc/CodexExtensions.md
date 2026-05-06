# ``CodexAppServer/CodexExtensions``

Read app-server extension inventory.

## Overview

`CodexExtensions` is exposed through ``CodexAppServer/extensions``. Use it when
a client needs available apps, skills, plugins, or collaboration modes without
reading installed plugin or skill directories from the Swift process.

```swift
let apps = try await appServer.extensions.listApps()
let skills = try await appServer.extensions.listSkills(
    .init(currentDirectoryPaths: [thread.currentDirectoryPath])
)
```

The namespace is read-only. Plugin install, uninstall, marketplace mutation, and
skill config writes remain unpromoted until SwiftASB has a clearer permission
and user-review story for those operations.

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
- ``MarketplaceLoadError``

### Collaboration Modes

- ``CollaborationModeList``
- ``CollaborationMode``
