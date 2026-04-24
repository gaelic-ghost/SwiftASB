#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCHEMA_VERSION=${SCHEMA_VERSION:-v0.124.0}
SCHEMA_ROOT="$ROOT_DIR/codex-schemas/$SCHEMA_VERSION"
DERIVED_DIR="$ROOT_DIR/tmp/derived-schemas/${SCHEMA_VERSION//./_}"
OUT_DIR="$ROOT_DIR/tmp/quicktype-wire/${SCHEMA_VERSION//./_}"
RAW_DIR="$OUT_DIR/raw"
PATCHED_DIR="$OUT_DIR/patched"

if [ ! -d "$SCHEMA_ROOT" ]; then
  printf 'Schema directory not found: %s\n' "$SCHEMA_ROOT" >&2
  exit 1
fi

if ! command -v quicktype >/dev/null 2>&1; then
  printf 'quicktype is not installed or not on PATH.\n' >&2
  exit 1
fi

mkdir -p "$DERIVED_DIR" "$RAW_DIR" "$PATCHED_DIR"

derive_schema() {
  bundle_path=$1
  out_path=$2
  title=$3
  shift 3

  printf 'Deriving %s from %s\n' "$title" "$bundle_path"
  uv run "$ROOT_DIR/scripts/derive_quicktype_schema.py" \
    --bundle "$SCHEMA_ROOT/$bundle_path" \
    --out "$DERIVED_DIR/$out_path" \
    --title "$title" \
    "$@"
}

generate_swift() {
  schema_path=$1
  raw_output_path=$2
  top_level_name=$3

  printf 'Generating raw Swift from %s\n' "$schema_path"
  quicktype \
    --src-lang schema \
    --lang swift \
    --top-level "$top_level_name" \
    --no-initializers \
    --sendable \
    --struct-or-class struct \
    --access-level internal \
    --protocol equatable \
    --type-prefix CodexWire \
    --out "$RAW_DIR/$raw_output_path" \
    "$DERIVED_DIR/$schema_path"
}

patch_swift() {
  raw_input_path=$1
  patched_output_path=$2

  printf 'Patching dynamic JSON holes in %s\n' "$raw_input_path"
  uv run "$ROOT_DIR/scripts/patch_quicktype_swift_any.py" \
    --input "$RAW_DIR/$raw_input_path" \
    --output "$PATCHED_DIR/$patched_output_path"
}

typecheck_swift() {
  patched_output_path=$1

  printf 'Typechecking %s\n' "$patched_output_path"
  swiftc -swift-version 6 -typecheck "$PATCHED_DIR/$patched_output_path"
}

build_batch() {
  bundle_path=$1
  derived_name=$2
  title=$3
  swift_name=$4
  shift 4

  derive_schema "$bundle_path" "$derived_name.schema.json" "$title" "$@"
  generate_swift "$derived_name.schema.json" "$swift_name.swift" "$derived_name"
  patch_swift "$swift_name.swift" "$swift_name+JSONValue.swift"
  typecheck_swift "$swift_name+JSONValue.swift"
}

# Thread and turn lifecycle types come from the v2 bundle and share definitions
# cleanly when generated as one consolidated graph. InitializeResponse remains
# hand-owned in Sources/ because the current v2 bundle does not expose it.
build_batch \
  "codex_app_server_protocol.v2.schemas.json" \
  "CodexLifecycleV2Batch" \
  "CodexLifecycleV2Batch" \
  "CodexLifecycleV2Batch" \
  InitializeParams \
  ThreadStartParams \
  ThreadStartResponse \
  ThreadCompactStartParams \
  ThreadCompactStartResponse \
  ThreadTurnsListParams \
  ThreadTurnsListResponse \
  ThreadStartedNotification \
  ThreadStatusChangedNotification \
  ThreadNameUpdatedNotification \
  ThreadTokenUsageUpdatedNotification \
  ThreadArchivedNotification \
  ThreadUnarchivedNotification \
  ThreadClosedNotification \
  TurnStartParams \
  TurnStartResponse \
  TurnStartedNotification \
  TurnPlanUpdatedNotification \
  TurnDiffUpdatedNotification \
  TurnCompletedNotification \
  ItemStartedNotification \
  ItemCompletedNotification \
  ItemGuardianApprovalReviewStartedNotification \
  ItemGuardianApprovalReviewCompletedNotification \
  PlanDeltaNotification \
  ReasoningTextDeltaNotification \
  ReasoningSummaryPartAddedNotification \
  ReasoningSummaryTextDeltaNotification \
  AgentMessageDeltaNotification \
  CommandExecutionOutputDeltaNotification \
  CommandExecOutputDeltaNotification \
  FileChangeOutputDeltaNotification \
  FileChangePatchUpdatedNotification \
  McpToolCallProgressNotification \
  ModelReroutedNotification \
  ModelVerificationNotification \
  ServerRequestResolvedNotification \
  HookStartedNotification \
  HookCompletedNotification \
  ExternalAgentConfigImportCompletedNotification \
  GuardianWarningNotification \
  WarningNotification \
  RawResponseItemCompletedNotification \
  ContextCompactedNotification \
  ErrorNotification \
  ThreadApproveGuardianDeniedActionParams \
  ThreadApproveGuardianDeniedActionResponse

printf '\nDerived schemas: %s\n' "$DERIVED_DIR"
printf 'Raw quicktype output: %s\n' "$RAW_DIR"
printf 'Patched Swift output: %s\n' "$PATCHED_DIR"
