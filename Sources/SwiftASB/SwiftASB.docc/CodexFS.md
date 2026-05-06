# ``CodexFS``

Read filesystem facts through the Codex app-server.

## Overview

`CodexFS` is the app-server-owned filesystem surface exposed through
``CodexAppServer/fs``. Use it when a sandboxed Swift app needs metadata,
directory entries, or file bytes without reading local disk from the app
process.

The current surface supports read-only requests, app-server filesystem watch
notifications, and bounded file discovery. Discovery walks directories through
app-server `fs/readDirectory` calls and applies SwiftASB-owned fuzzy ranking to
the returned entry names and relative paths.

```swift
let files = try await appServer.fs.discoverFiles(
    .files(under: thread.currentDirectoryPath, matching: "codexfs")
)
```

## Topics

### Reads

- ``readMetadata(_:)``
- ``readDirectory(_:)``
- ``readFile(_:)``
- ``watch(_:)``
- ``unwatch(_:)``
- ``discoverFiles(_:)``

### Models

- ``FileDiscoveryQD``
- ``FileDiscoveryResult``
- ``FileDiscoveryHit``
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
