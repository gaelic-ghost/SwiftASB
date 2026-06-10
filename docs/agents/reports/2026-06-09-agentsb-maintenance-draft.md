# AgentSB Maintenance Draft

## Summary

- Mode: `draft`.
- Git branch at inspection time: `maintenance/codex-schema-refresh`.
- Git dirty state at inspection time: `True`.
- Candidates reviewed: 5.
- Safe changes applied: 0.

## Schema Diff Evidence

- Compared `v0.137.0` to `v0.138.0`.
- Added JSON files: 4.
- Removed JSON files: 0.
- Changed JSON files: 35.
- Unchanged JSON files: 277.
- Added: `v2/GetAccountTokenUsageResponse.json`, `v2/RemoteControlPairingStatusParams.json`, `v2/RemoteControlPairingStatusResponse.json`, `v2/TurnModerationMetadataNotification.json`.
- Changed: `ClientRequest.json`, `ServerNotification.json`, `codex_app_server_protocol.schemas.json`, `codex_app_server_protocol.v2.schemas.json`, `v2/AccountUpdatedNotification.json`, `v2/CollaborationModeListResponse.json`, `v2/ConfigReadResponse.json`, `v2/ConfigRequirementsReadResponse.json`, ... 27 more.

## Candidate Decisions

### 1. Write schema-review evidence report

- Decision: `auto-apply`.
- Change kind: `report-create`.
- Paths: `docs/agents/reports/2026-06-09-agentsb-schema-review-2.md`.
- Summary: Create an AgentSB-owned schema-review report with deterministic repo facts and schema diff evidence.
- Reasons: `candidate is limited to AgentSB-owned report formatting or report creation`.
- Required checks: `uv run pytest`.

### 2. Draft Codex CLI compatibility alignment patch

- Decision: `draft-only`.
- Change kind: `compatibility-alignment`.
- Paths: `README.md`, `ROADMAP.md`, `docs/maintainers/interactive-lifecycle-release-boundary.md`, `scripts/generate-wire-types.sh`, `Sources/SwiftASB/Transport/CodexCLIExecutableResolver.swift`, `Tools/AgentSB/tests/test_cli.py`, `Tools/AgentSB/tests/test_tools.py`.
- Summary: Draft the predictable version-window updates needed after maintainers classify `v0.138.0` as the reviewed Codex CLI schema.
- Reasons: `Codex CLI compatibility alignment changes need maintainer review before application`.
- Required checks: `swift build`, `swift test`, `uv run pytest`, `git diff --check`.

Proposed patch:

```diff
diff --git a/scripts/generate-wire-types.sh b/scripts/generate-wire-types.sh
--- a/scripts/generate-wire-types.sh
+++ b/scripts/generate-wire-types.sh
@@
-SCHEMA_VERSION=${SCHEMA_VERSION:-v0.137.0}
+SCHEMA_VERSION=${SCHEMA_VERSION:-v0.138.0}
diff --git a/Sources/SwiftASB/Transport/CodexCLIExecutableResolver.swift b/Sources/SwiftASB/Transport/CodexCLIExecutableResolver.swift
--- a/Sources/SwiftASB/Transport/CodexCLIExecutableResolver.swift
+++ b/Sources/SwiftASB/Transport/CodexCLIExecutableResolver.swift
@@
-        internal static let latestSupportedPublicRelease = Version(major: 0, minor: <old-minor>, patch: 0)
+        internal static let latestSupportedPublicRelease = Version(major: 0, minor: 138, patch: 0)
diff --git a/README.md b/README.md
--- a/README.md
+++ b/README.md
@@
-*Note: SwiftASB currently supports the latest reviewed Codex CLI minor release, `0.137.x`.*
+*Note: SwiftASB currently supports the latest reviewed Codex CLI minor release, `0.138.x`.*
diff --git a/ROADMAP.md b/ROADMAP.md
--- a/ROADMAP.md
+++ b/ROADMAP.md
@@
-The current reviewed compatibility window is `codex-cli 0.137.x`
+The current reviewed compatibility window is `codex-cli 0.138.x`
@@
+- [ ] Classify the Codex CLI `v0.138.0` schema diff before promotion.
+  Decision: update the reviewed CLI window to `0.138.x` only after
+  generated-wire and public API boundary review is complete.
diff --git a/docs/maintainers/interactive-lifecycle-release-boundary.md b/docs/maintainers/interactive-lifecycle-release-boundary.md
--- a/docs/maintainers/interactive-lifecycle-release-boundary.md
+++ b/docs/maintainers/interactive-lifecycle-release-boundary.md
@@
-- current reviewed minor release: `0.137.x`
+- current reviewed minor release: `0.138.x`
diff --git a/Tools/AgentSB/tests/test_cli.py b/Tools/AgentSB/tests/test_cli.py
--- a/Tools/AgentSB/tests/test_cli.py
+++ b/Tools/AgentSB/tests/test_cli.py
@@
-    assert facts["reviewed_codex_cli_window"]["window"] == "0.137.x"
+    assert facts["reviewed_codex_cli_window"]["window"] == "0.138.x"
diff --git a/Tools/AgentSB/tests/test_tools.py b/Tools/AgentSB/tests/test_tools.py
--- a/Tools/AgentSB/tests/test_tools.py
+++ b/Tools/AgentSB/tests/test_tools.py
@@
-    assert facts["reviewed_codex_cli_window"]["window"] == "0.137.x"
+    assert facts["reviewed_codex_cli_window"]["window"] == "0.138.x"
```

### 3. Draft generated-wire schema membership patch

- Decision: `draft-only`.
- Change kind: `schema-generator-membership`.
- Paths: `scripts/generate-wire-types.sh`.
- Summary: Draft the generator-script additions for new schema files so maintainers can promote the classified wire batch through the normal script.
- Reasons: `Codex CLI compatibility alignment changes need maintainer review before application`.
- Required checks: `swift build`, `swift test`, `uv run pytest`, `git diff --check`.

Proposed patch:

```diff
diff --git a/scripts/generate-wire-types.sh b/scripts/generate-wire-types.sh
--- a/scripts/generate-wire-types.sh
+++ b/scripts/generate-wire-types.sh
@@
   # Add classified schema families to the consolidated v2 batch.
+  GetAccountTokenUsageResponse \
+  RemoteControlPairingStatusParams \
+  RemoteControlPairingStatusResponse \
+  TurnModerationMetadataNotification \
```

### 4. Classify schema family changes before generated-wire promotion

- Decision: `report-only`.
- Change kind: `schema-family-promotion`.
- Paths: `Sources/SwiftASB/Generated/CodexWire/Latest/CodexLifecycleV2Batch+JSONValue.swift`.
- Summary: Schema dumps `v0.137.0` and `v0.138.0` differ; maintainers need to classify added or changed families before promotion.
- Reasons: `generated wire snapshots require maintainer-controlled promotion`.

### 5. Draft AgentSB roadmap evidence note

- Decision: `draft-only`.
- Change kind: `docs-update`.
- Paths: `docs/agents/agentsb-roadmap.md`.
- Summary: Propose a roadmap note that records the latest local schema diff evidence without changing the source document.
- Reasons: `candidate has unresolved ambiguity and needs maintainer review before application`.
- Required checks: `review drafted diff`.

Proposed patch:

```diff
diff --git a/docs/agents/agentsb-roadmap.md b/docs/agents/agentsb-roadmap.md
--- a/docs/agents/agentsb-roadmap.md
+++ b/docs/agents/agentsb-roadmap.md
@@
+- Latest local schema diff evidence: AgentSB compared `v0.137.0` to `v0.138.0` and found 4 added, 0 removed, and 35 changed JSON files. Do not update public support claims or generated wire output until maintainers classify each changed family.
```

## Applied Changes

No safe changes were applied.

## Required Checks

No checks were run.

## Evidence

- Repository root: `/Users/galew/Workspace/gaelic-ghost/SwiftASB`.
- Reviewed window source: `ROADMAP.md`.
- Git upstream: `none`.
