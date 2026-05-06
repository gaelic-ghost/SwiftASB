# ``CodexConfig``

Read app-server configuration facts through Codex.

## Overview

`CodexConfig` is exposed through ``CodexAppServer/config``. Use it when a
sandboxed client needs the effective Codex configuration or active requirements
policy without reading local config files directly.

```swift
let snapshot = try await appServer.config.read(
    .init(currentDirectoryPath: thread.currentDirectoryPath, includeLayers: true)
)
```

The effective config is exposed as ``CodexAppServer/JSONValue`` so SwiftASB can
preserve app-server-owned config shape without turning unstable config keys into
long-lived public Swift fields too early.

## Topics

### Reads

- ``read(_:)``
- ``readRequirements()``

### Models

- ``ReadRequest``
- ``Snapshot``
- ``Layer``
- ``LayerMetadata``
- ``LayerSource``
- ``RequirementsSnapshot``
