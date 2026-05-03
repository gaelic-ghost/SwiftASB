#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SELF_DIR/.." && pwd)

cd "$REPO_ROOT"
SWIFTASB_LIVE_CODEX_REPORT_DIR="${SWIFTASB_LIVE_CODEX_REPORT_DIR:-$REPO_ROOT/tmp/live-codex-reports}"
export SWIFTASB_LIVE_CODEX_REPORT_DIR
mkdir -p "$SWIFTASB_LIVE_CODEX_REPORT_DIR"

printf '%s\n' 'Running SwiftASB live Codex behavior matrix.'
env SWIFTASB_ENABLE_LIVE_CODEX_BEHAVIOR_MATRIX_TESTS=1 \
    SWIFTASB_LIVE_CODEX_REPORT_DIR="$SWIFTASB_LIVE_CODEX_REPORT_DIR" \
    swift test --filter CodexAppServerLiveIntegrationTests/recordsLiveBehaviorMatrix

printf '%s\n' "SwiftASB live Codex behavior matrix completed. Report: $SWIFTASB_LIVE_CODEX_REPORT_DIR/live-behavior-matrix.json"
