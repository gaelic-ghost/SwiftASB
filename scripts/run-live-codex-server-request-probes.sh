#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SELF_DIR/.." && pwd)

cd "$REPO_ROOT"
SWIFTASB_LIVE_CODEX_REPORT_DIR="${SWIFTASB_LIVE_CODEX_REPORT_DIR:-$REPO_ROOT/tmp/live-codex-reports}"
export SWIFTASB_LIVE_CODEX_REPORT_DIR
mkdir -p "$SWIFTASB_LIVE_CODEX_REPORT_DIR"

printf '%s\n' 'Running SwiftASB live Codex server-request probes.'
printf '%s\n' 'Step 1/3: deterministic command and permissions approval probes'
sh "$REPO_ROOT/scripts/run-live-codex-approval-probe.sh"

printf '%s\n' 'Step 2/3: deterministic tool-user-input and app-connector MCP observation probes'
env SWIFTASB_ENABLE_LIVE_CODEX_SERVER_REQUEST_TESTS=1 \
    SWIFTASB_LIVE_CODEX_REPORT_DIR="$SWIFTASB_LIVE_CODEX_REPORT_DIR" \
    swift test --filter 'CodexAppServerLiveIntegrationTests/(completesDeterministicToolUserInputThroughRawRealAppServer|completesDeterministicAppConnectorMcpElicitationThroughRawRealAppServer)'

printf '%s\n' 'Step 3/3: server-request family coverage report'
env SWIFTASB_ENABLE_LIVE_CODEX_SERVER_REQUEST_TESTS=1 \
    SWIFTASB_LIVE_CODEX_REPORT_DIR="$SWIFTASB_LIVE_CODEX_REPORT_DIR" \
    swift test --filter CodexAppServerLiveIntegrationTests/recordsLiveServerRequestFamilyCoverageStatus

printf '%s\n' "SwiftASB live Codex server-request probes completed. Report: $SWIFTASB_LIVE_CODEX_REPORT_DIR/live-server-request-family-coverage.json"
