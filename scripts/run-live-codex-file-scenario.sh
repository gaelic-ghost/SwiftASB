#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

cd "$REPO_ROOT"
mkdir -p tmp/live-codex-reports

env SWIFTASB_ENABLE_LIVE_CODEX_FILE_SCENARIO_TESTS=1 \
    SWIFTASB_LIVE_CODEX_REPORT_DIR="$REPO_ROOT/tmp/live-codex-reports" \
    swift test --filter 'CodexAppServerLiveIntegrationTests/runsMultiTurnLiveFileMutationScenario'
