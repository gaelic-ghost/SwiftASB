# ``CodexFS``

Read filesystem facts through the Codex app-server.

## Overview

`CodexFS` is the app-server-owned filesystem surface exposed through
``CodexAppServer/fs``. Use it when a sandboxed Swift app needs metadata,
directory entries, or file bytes without reading local disk from the app
process.

The current surface supports read-only requests and app-server filesystem watch
notifications. Mutation and fuzzy search remain separate schema families that
need public API and permission decisions before promotion.

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
- ``watch(_:)``
- ``unwatch(_:)``

### Models

- ``MetadataRequest``
- ``Metadata``
- ``DirectoryReadRequest``
- ``DirectoryReadResult``
- ``DirectoryEntry``
- ``FileReadRequest``
- ``FileReadResult``
- ``WatchRequest``
- ``UnwatchRequest``
- ``Watch``
- ``ChangeEvent``
