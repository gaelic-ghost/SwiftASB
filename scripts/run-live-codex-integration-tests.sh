#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SELF_DIR/.." && pwd)

usage() {
    cat <<'USAGE'
Usage: scripts/run-live-codex-integration-tests.sh [mode]

Modes:
  release-gate    Run the maintained release-gate live probe set. This is the default.
  approval        Run command, permissions, and exploratory approval live probes.
  file-scenario   Run the multi-turn create/edit/delete file scenario.
  rollback        Run the disposable stored-thread rollback scenario.
  all             Run every opt-in CodexAppServer live integration test.
  help            Show this help text.

Environment:
  SWIFTASB_LIVE_CODEX_REPORT_DIR  Directory for JSON reports from reporting probes.
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
    approval)
        sh "$REPO_ROOT/scripts/run-live-codex-approval-probe.sh"
        ;;
    file-scenario)
        sh "$REPO_ROOT/scripts/run-live-codex-file-scenario.sh"
        ;;
    rollback)
        sh "$REPO_ROOT/scripts/run-live-codex-rollback-scenario.sh"
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
