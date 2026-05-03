#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SELF_DIR/.." && pwd)

cd "$REPO_ROOT"
report_dir="${SWIFTASB_LIVE_CODEX_REPORT_DIR:-$REPO_ROOT/tmp/live-codex-reports}"
test_filter='CodexAppServerLiveIntegrationTests/(completesDeterministicCommandApprovalThroughRawRealAppServer|completesDeterministicPermissionsApprovalThroughRawRealAppServer|probesLiveApprovalAndServerRequestCandidates)'
mkdir -p "$report_dir"

env SWIFTASB_ENABLE_LIVE_CODEX_APPROVAL_PROBE_TESTS=1 \
    SWIFTASB_LIVE_CODEX_REPORT_DIR="$report_dir" \
    swift test --filter "$test_filter"
