# Feature Permission Policy

Describe and configure SwiftASB-owned convenience features without forcing repeated prompts for safe, expected work.

## Overview

``SwiftASBFeaturePolicy`` is separate from Codex app-server approval requests.
Codex approvals answer server-originated requests during a thread or turn.
Feature policy says which SwiftASB convenience categories a consuming app has
enabled.

Read-only and inventory categories are available by default. Mutation categories
are disabled until the consuming app enables them, and enabled mutations should
emit human-readable operation events as those surfaces land.

The initial built-in categories are:

- ``SwiftASBFeatureCategory/ID/gitObservability``
- ``SwiftASBFeatureCategory/ID/extensionInventory``
- ``SwiftASBFeatureCategory/ID/extensionMaintenance``
- ``SwiftASBFeatureCategory/ID/swiftRepoGuidanceSync``
- ``SwiftASBFeatureCategory/ID/gitActions``
- ``SwiftASBFeatureCategory/ID/configMutation``
- ``SwiftASBFeatureCategory/ID/extensionMutation``
- ``SwiftASBFeatureCategory/ID/worktreeAutomation``

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
