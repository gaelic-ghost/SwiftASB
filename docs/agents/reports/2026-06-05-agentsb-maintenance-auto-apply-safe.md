# AgentSB Auto-Apply Safe Maintenance Run

## Summary

- Mode: `auto-apply-safe`.
- Git branch at inspection time: `agents/agentsb-maintenance`.
- Git dirty state at inspection time: `True`.
- Candidates reviewed: 3.
- Safe changes applied: 1.

## Schema Diff Evidence

- Compared `v0.133.0` to `v0.135.0`.
- Added JSON files: 2.
- Removed JSON files: 0.
- Changed JSON files: 34.
- Unchanged JSON files: 268.
- Added: `v2/ThreadSearchParams.json`, `v2/ThreadSearchResponse.json`.
- Changed: `ClientRequest.json`, `ServerNotification.json`, `codex_app_server_protocol.schemas.json`, `codex_app_server_protocol.v2.schemas.json`, `v2/ConfigReadParams.json`, `v2/ConfigReadResponse.json`, `v2/ConfigRequirementsReadResponse.json`, `v2/FeedbackUploadParams.json`, ... 26 more.

## Candidate Decisions

### 1. Write schema-review evidence report

- Decision: `auto-apply`.
- Change kind: `report-create`.
- Paths: `docs/agents/reports/2026-06-05-agentsb-schema-review-2.md`.
- Summary: Create an AgentSB-owned schema-review report with deterministic repo facts and schema diff evidence.
- Reasons: `candidate is limited to AgentSB-owned report formatting or report creation`.
- Required checks: `uv run pytest`.

### 2. Classify schema family changes before generated-wire promotion

- Decision: `report-only`.
- Change kind: `schema-family-promotion`.
- Paths: `Sources/SwiftASB/Generated/CodexWire/Latest/CodexLifecycleV2Batch+JSONValue.swift`.
- Summary: Schema dumps `v0.133.0` and `v0.135.0` differ; maintainers need to classify added or changed families before promotion.
- Reasons: `generated wire snapshots require maintainer-controlled promotion`.

### 3. Draft AgentSB roadmap evidence note

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
+- Latest local schema diff evidence: AgentSB compared `v0.133.0` to `v0.135.0` and found 2 added, 0 removed, and 34 changed JSON files. Do not update public support claims or generated wire output until maintainers classify each changed family.
```

## Applied Changes

- `docs/agents/reports/2026-06-05-agentsb-schema-review-2.md`: Wrote AgentSB-owned schema-review report.

## Required Checks

- `uv run pytest` exited 0: ============================== 23 passed in 0.68s ==============================

## Evidence

- Repository root: `/Users/galew/Workspace/gaelic-ghost/SwiftASB`.
- Reviewed window source: `ROADMAP.md`.
- Git upstream: `origin/agents/agentsb-maintenance`.
