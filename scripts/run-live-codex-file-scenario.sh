#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

cd "$REPO_ROOT"
report_dir="${SWIFTASB_LIVE_CODEX_REPORT_DIR:-$REPO_ROOT/tmp/live-codex-reports}"
mkdir -p "$report_dir"

env SWIFTASB_ENABLE_LIVE_CODEX_FILE_SCENARIO_TESTS=1 \
    SWIFTASB_LIVE_CODEX_REPORT_DIR="$report_dir" \
    swift test --filter 'CodexAppServerLiveIntegrationTests/runsMultiTurnLiveFileMutationScenario'
