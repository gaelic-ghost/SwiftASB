#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SELF_DIR/.." && pwd)

cd "$REPO_ROOT"

env SWIFTASB_ENABLE_LIVE_CODEX_ROLLBACK_TESTS=1 \
    swift test --filter 'CodexAppServerLiveIntegrationTests/rollsBackLiveThreadAndRecordsMarker'
