#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SELF_DIR/.." && pwd)

cd "$REPO_ROOT"
SWIFTASB_LIVE_CODEX_REPORT_DIR="${SWIFTASB_LIVE_CODEX_REPORT_DIR:-$REPO_ROOT/tmp/live-codex-reports}"
export SWIFTASB_LIVE_CODEX_REPORT_DIR
mkdir -p "$SWIFTASB_LIVE_CODEX_REPORT_DIR"

printf '%s\n' 'Running SwiftASB live Codex release gate.'
printf '%s\n' 'Step 1/7: full Swift package test suite'
swift test

printf '%s\n' 'Step 2/7: every opt-in CodexAppServer live test'
env SWIFTASB_ENABLE_LIVE_CODEX_TESTS=1 \
    SWIFTASB_LIVE_CODEX_REPORT_DIR="$SWIFTASB_LIVE_CODEX_REPORT_DIR" \
    swift test --filter CodexAppServerLive

printf '%s\n' 'Step 3/7: startup, transport, capability, thread, turn, and concurrency smoke probes'
env SWIFTASB_ENABLE_LIVE_CODEX_TRANSPORT_TESTS=1 \
    SWIFTASB_ENABLE_LIVE_CODEX_CAPABILITY_TESTS=1 \
    SWIFTASB_ENABLE_LIVE_CODEX_THREAD_MANAGEMENT_TESTS=1 \
    SWIFTASB_ENABLE_LIVE_CODEX_SINGLE_TURN_TESTS=1 \
    SWIFTASB_ENABLE_LIVE_CODEX_CROSS_THREAD_TESTS=1 \
    SWIFTASB_ENABLE_LIVE_CODEX_SAME_THREAD_TESTS=1 \
    SWIFTASB_LIVE_CODEX_REPORT_DIR="$SWIFTASB_LIVE_CODEX_REPORT_DIR" \
    swift test --filter CodexAppServerLiveIntegrationTests

printf '%s\n' 'Step 4/7: approval and server-request probes'
sh "$REPO_ROOT/scripts/run-live-codex-server-request-probes.sh"

printf '%s\n' 'Step 5/7: behavior matrix probes'
sh "$REPO_ROOT/scripts/run-live-codex-behavior-matrix.sh"

printf '%s\n' 'Step 6/7: multi-turn file mutation scenario'
sh "$REPO_ROOT/scripts/run-live-codex-file-scenario.sh"

printf '%s\n' 'Step 7/7: rollback scenario'
sh "$REPO_ROOT/scripts/run-live-codex-rollback-scenario.sh"

printf '%s\n' 'SwiftASB live Codex release gate completed successfully.'
