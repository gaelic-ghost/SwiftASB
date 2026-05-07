# Thread Management

Name threads, archive or unarchive stored threads, patch stored metadata, compact context, and roll back trailing turns through the thread-scoped API.

## Overview

Thread-management actions are exposed on ``CodexThread`` because callers usually perform them from an existing conversation surface. The app-server actor still owns the protocol request, but the thread handle supplies the thread identity and keeps defaults attached to any refreshed thread value.

## Naming

Use ``CodexThread/setName(_:)`` to update the stored thread name.

```swift
try await thread.setName("Release planning")
```

The thread event stream may later report the new name through ``CodexThreadEvent/nameUpdated(_:)``.

## Archive State

Use ``CodexThread/archive()`` and ``CodexThread/unarchive()`` to move stored threads in or out of the archived list.

```swift
try await thread.archive()
let refreshed = try await thread.unarchive()
```

Archive and unarchive requests update SwiftASB's local stored-thread archive state. The thread event stream may also report app-server archive notifications through ``CodexThreadEvent/archived(_:)`` and ``CodexThreadEvent/unarchived(_:)``.

## Metadata Updates

Use ``CodexThread/updateMetadata(gitInfo:)`` to patch stored Git metadata. Each field uses ``CodexAppServer/ThreadMetadataFieldUpdate`` so the caller can distinguish "leave this alone", "clear this value", and "replace this value".

```swift
let updatedThread = try await thread.updateMetadata(
    gitInfo: .init(
        branch: .replace("docs/docc-public-surface"),
        originURL: .unchanged,
        sha: .clear
    )
)
```

## Compaction

Use ``CodexThread/compactContext()`` to ask the app-server to compact thread context. Dashboard and minimap companions mirror compaction activity when the runtime emits item lifecycle events for it.

## Rollback

Use ``CodexThread/rollbackLastTurns(_:)`` to roll back trailing turns from a stored thread.

```swift
let refreshedThread = try await thread.rollbackLastTurns(1)
```

Rollback asks the app-server for the updated thread, records a local rollback marker, hydrates the returned turns, deletes locally visible turns that are no longer present in the app-server response, and returns a refreshed ``CodexThread`` handle.

SwiftASB records enough local history to explain that a rollback happened. It does not yet preserve full removed-turn and removed-item payloads as a forensic archive.

## Topics

### Thread Convenience

- ``CodexThread/setName(_:)``
- ``CodexThread/archive()``
- ``CodexThread/unarchive()``
- ``CodexThread/updateMetadata(gitInfo:)``
- ``CodexThread/compactContext()``
- ``CodexThread/rollbackLastTurns(_:)``

### App-Server Requests

- ``CodexAppServer/setThreadName(_:)``
- ``CodexAppServer/archiveThread(_:)``
- ``CodexAppServer/unarchiveThread(_:)``
- ``CodexAppServer/updateThreadMetadata(_:)``
- ``CodexAppServer/compactThread(_:)``
- ``CodexAppServer/rollbackThread(_:)``

### Models

- ``CodexAppServer/ThreadSetNameRequest``
- ``CodexAppServer/ThreadArchiveRequest``
- ``CodexAppServer/ThreadMetadataUpdateRequest``
- ``CodexAppServer/ThreadMetadataGitInfoUpdate``
- ``CodexAppServer/ThreadMetadataFieldUpdate``
- ``CodexAppServer/ThreadRollbackRequest``
- ``CodexAppServer/ThreadCompactRequest``
