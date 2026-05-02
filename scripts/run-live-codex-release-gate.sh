#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SELF_DIR/.." && pwd)

cd "$REPO_ROOT"
SWIFTASB_LIVE_CODEX_REPORT_DIR="${SWIFTASB_LIVE_CODEX_REPORT_DIR:-$REPO_ROOT/tmp/live-codex-reports}"
export SWIFTASB_LIVE_CODEX_REPORT_DIR
mkdir -p "$SWIFTASB_LIVE_CODEX_REPORT_DIR"

printf '%s\n' 'Running SwiftASB live Codex release gate.'
printf '%s\n' 'Step 1/3: approval and server-request probe'
sh "$REPO_ROOT/scripts/run-live-codex-approval-probe.sh"

printf '%s\n' 'Step 2/3: multi-turn file mutation scenario'
sh "$REPO_ROOT/scripts/run-live-codex-file-scenario.sh"

printf '%s\n' 'Step 3/3: rollback scenario'
sh "$REPO_ROOT/scripts/run-live-codex-rollback-scenario.sh"

printf '%s\n' 'SwiftASB live Codex release gate completed successfully.'
