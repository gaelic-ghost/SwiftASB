#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

cd "$REPO_ROOT"

env SWIFTASB_ENABLE_LIVE_CODEX_FILE_SCENARIO_TESTS=1 \
    swift test --filter 'CodexAppServerLiveIntegrationTests/runsMultiTurnLiveFileMutationScenario'
