# ``CodexFS``

Read filesystem facts through the Codex app-server.

## Overview

`CodexFS` is the app-server-owned filesystem surface exposed through
``CodexAppServer/fs``. Use it when a sandboxed Swift app needs metadata,
directory entries, or file bytes without reading local disk from the app
process.

The current surface is read-only. Mutation, watches, and fuzzy search are still
separate schema families that need public API and permission decisions before
promotion.

```swift
let listing = try await appServer.fs.readDirectory(
    .init(path: thread.currentDirectoryPath)
)
```

## Topics

### Reads

- ``readMetadata(_:)``
- ``readDirectory(_:)``
- ``readFile(_:)``

### Models

- ``MetadataRequest``
- ``Metadata``
- ``DirectoryReadRequest``
- ``DirectoryReadResult``
- ``DirectoryEntry``
- ``FileReadRequest``
- ``FileReadResult``
