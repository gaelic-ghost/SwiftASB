# Feature Permission Policy

Describe and configure SwiftASB-owned convenience features without forcing repeated prompts for safe, expected work.

## Overview

``SwiftASBFeaturePolicy`` is separate from Codex app-server approval requests.
Codex approvals answer server-originated requests during a thread or turn.
Feature policy says which SwiftASB convenience categories a consuming app has
enabled.

Read-only and inventory categories are available by default. Most mutation
categories are disabled until the consuming app enables them, and enabled
mutations should emit human-readable operation events as those surfaces land.
The deliberate default-enabled exception is extension maintenance for
already-configured plugin marketplaces.

Use ``CodexAppServer/featureOperationEvents()`` to observe those mutation
records. Each ``SwiftASBFeatureOperationEvent`` carries the category id, stable
operation id, title, summary, reason, timing, affected paths, commands,
app-server method or SwiftASB intent kind, result status, rollback metadata, and
diagnostic text when a feature operation fails. Routine read-only refreshes such
as selected-worktree Git status hydration stay quiet.

Pass ``SwiftASBFeaturePolicy`` through ``CodexAppServer/Configuration`` to
control app-server-owned convenience mutations. The default policy enables
``SwiftASBFeatureCategory/ID/extensionMaintenance``, which permits
``CodexExtensions/upgradeMarketplace(_:)`` for already-configured
plugin marketplaces while leaving new installs, removals, sharing changes, and
configuration writes out of scope.

The initial built-in categories are:

- ``SwiftASBFeatureCategory/ID/gitObservability``
- ``SwiftASBFeatureCategory/ID/extensionInventory``
- ``SwiftASBFeatureCategory/ID/extensionMaintenance``
- ``SwiftASBFeatureCategory/ID/swiftRepoGuidanceSync``
- ``SwiftASBFeatureCategory/ID/gitActions``
- ``SwiftASBFeatureCategory/ID/configMutation``
- ``SwiftASBFeatureCategory/ID/extensionMutation``
- ``SwiftASBFeatureCategory/ID/worktreeAutomation``
- ``SwiftASBFeatureCategory/ID/shellCommandExecution``

``SwiftASBFeatureCategory/ID/shellCommandExecution`` is disabled by default and
high impact. It gates ``CodexThread/sendShellCommand(_:)``, which sends a
literal user-level shell command to app-server `thread/shellCommand`. That
endpoint is different from SwiftASB's internal `command/exec` helper path:
`command/exec` sends argv-shaped helper commands through the app-server command
runner, while `thread/shellCommand` preserves shell syntax and is documented by
the upstream schema as unsandboxed full-user shell access.

Use ``SwiftASBHostAccess`` to describe broad filesystem access the host app has
already arranged, such as unsandboxed access or sandboxed home-directory access
through a user-selected directory or security-scoped bookmark.

## Topics

### Policy

- ``SwiftASBFeaturePolicy``
- ``SwiftASBFeatureCategory``
- ``SwiftASBFeatureMode``
- ``SwiftASBFeatureSensitivity``
- ``SwiftASBFeatureEventPolicy``
- ``SwiftASBHostAccess``
- ``SwiftASBFeatureOperationEvent``
