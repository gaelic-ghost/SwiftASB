#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SELF_DIR/.." && pwd)

cd "$REPO_ROOT"
mkdir -p tmp/live-codex-reports

env SWIFTASB_ENABLE_LIVE_CODEX_APPROVAL_PROBE_TESTS=1 \
    SWIFTASB_LIVE_CODEX_REPORT_DIR="$REPO_ROOT/tmp/live-codex-reports" \
    swift test --filter 'CodexAppServerLiveIntegrationTests/(reachesDeterministicCommandApprovalStateThroughRawRealAppServer|probesLiveApprovalAndServerRequestCandidates)'
