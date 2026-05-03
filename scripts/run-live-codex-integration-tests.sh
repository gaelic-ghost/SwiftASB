#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SELF_DIR/.." && pwd)

usage() {
    cat <<'USAGE'
Usage: scripts/run-live-codex-integration-tests.sh [mode]

Modes:
  release-gate    Run the maintained release-gate live probe set. This is the default.
  smoke           Run startup, transport, capability, thread, turn, and concurrency probes.
  transport       Run raw transport initialize/thread/turn probes.
  capability      Run model and MCP capability snapshot probes.
  thread          Run thread management and stored-history probes.
  turn            Run public single-turn and cross-thread probes.
  approval        Run command, permissions, and exploratory approval live probes.
  behavior-matrix Run observational approval, sandbox, history, and diagnostics probes.
  file-scenario   Run the multi-turn create/edit/delete file scenario.
  rollback        Run the disposable stored-thread rollback scenario.
  same-thread     Run the observational same-thread overlap probe.
  all             Run every opt-in CodexAppServer live integration test.
  help            Show this help text.

Environment:
  SWIFTASB_LIVE_CODEX_REPORT_DIR  Directory for JSON reports from reporting probes.
  SWIFTASB_LIVE_CODEX_BIN         Codex executable path to test instead of PATH discovery.
  SWIFTASB_LIVE_CODEX_KEEP_WORKSPACES=1
                                  Preserve temporary workspaces after each live test.
USAGE
}

mode="${1:-release-gate}"

cd "$REPO_ROOT"
SWIFTASB_LIVE_CODEX_REPORT_DIR="${SWIFTASB_LIVE_CODEX_REPORT_DIR:-$REPO_ROOT/tmp/live-codex-reports}"
export SWIFTASB_LIVE_CODEX_REPORT_DIR
mkdir -p "$SWIFTASB_LIVE_CODEX_REPORT_DIR"

case "$mode" in
    release-gate)
        sh "$REPO_ROOT/scripts/run-live-codex-release-gate.sh"
        ;;
    smoke)
        env SWIFTASB_ENABLE_LIVE_CODEX_TRANSPORT_TESTS=1 \
            SWIFTASB_ENABLE_LIVE_CODEX_CAPABILITY_TESTS=1 \
            SWIFTASB_ENABLE_LIVE_CODEX_THREAD_MANAGEMENT_TESTS=1 \
            SWIFTASB_ENABLE_LIVE_CODEX_SINGLE_TURN_TESTS=1 \
            SWIFTASB_ENABLE_LIVE_CODEX_CROSS_THREAD_TESTS=1 \
            SWIFTASB_ENABLE_LIVE_CODEX_SAME_THREAD_TESTS=1 \
            SWIFTASB_LIVE_CODEX_REPORT_DIR="$SWIFTASB_LIVE_CODEX_REPORT_DIR" \
            swift test --filter CodexAppServerLiveIntegrationTests
        ;;
    transport)
        env SWIFTASB_ENABLE_LIVE_CODEX_TRANSPORT_TESTS=1 \
            SWIFTASB_LIVE_CODEX_REPORT_DIR="$SWIFTASB_LIVE_CODEX_REPORT_DIR" \
            swift test --filter CodexAppServerLiveIntegrationTests
        ;;
    capability)
        env SWIFTASB_ENABLE_LIVE_CODEX_CAPABILITY_TESTS=1 \
            SWIFTASB_LIVE_CODEX_REPORT_DIR="$SWIFTASB_LIVE_CODEX_REPORT_DIR" \
            swift test --filter CodexAppServerLiveIntegrationTests
        ;;
    thread)
        env SWIFTASB_ENABLE_LIVE_CODEX_THREAD_MANAGEMENT_TESTS=1 \
            SWIFTASB_ENABLE_LIVE_CODEX_HISTORY_TESTS=1 \
            SWIFTASB_LIVE_CODEX_REPORT_DIR="$SWIFTASB_LIVE_CODEX_REPORT_DIR" \
            swift test --filter CodexAppServerLiveIntegrationTests
        ;;
    turn)
        env SWIFTASB_ENABLE_LIVE_CODEX_SINGLE_TURN_TESTS=1 \
            SWIFTASB_ENABLE_LIVE_CODEX_CROSS_THREAD_TESTS=1 \
            SWIFTASB_LIVE_CODEX_REPORT_DIR="$SWIFTASB_LIVE_CODEX_REPORT_DIR" \
            swift test --filter CodexAppServerLiveIntegrationTests
        ;;
    approval)
        sh "$REPO_ROOT/scripts/run-live-codex-approval-probe.sh"
        ;;
    behavior-matrix)
        sh "$REPO_ROOT/scripts/run-live-codex-behavior-matrix.sh"
        ;;
    file-scenario)
        sh "$REPO_ROOT/scripts/run-live-codex-file-scenario.sh"
        ;;
    rollback)
        sh "$REPO_ROOT/scripts/run-live-codex-rollback-scenario.sh"
        ;;
    same-thread)
        env SWIFTASB_ENABLE_LIVE_CODEX_SAME_THREAD_TESTS=1 \
            SWIFTASB_LIVE_CODEX_REPORT_DIR="$SWIFTASB_LIVE_CODEX_REPORT_DIR" \
            swift test --filter CodexAppServerLiveIntegrationTests
        ;;
    all)
        env SWIFTASB_ENABLE_LIVE_CODEX_TESTS=1 \
            SWIFTASB_LIVE_CODEX_REPORT_DIR="$SWIFTASB_LIVE_CODEX_REPORT_DIR" \
            swift test --filter CodexAppServerLiveIntegrationTests
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        printf '%s\n' "Unknown live Codex integration test mode: $mode" >&2
        usage >&2
        exit 64
        ;;
esac
