#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export REPO_MAINTENANCE_COMMON_DIR="$SELF_DIR/../lib"
. "$SELF_DIR/../lib/common.sh"

log "Verifying generated wire remains internal to SwiftASB."

generated_root="$REPO_ROOT/Sources/SwiftASB/Generated/CodexWire"
if [ -d "$generated_root" ] &&
  grep -R -n -E '^[[:space:]]*(public|open)[[:space:]]' "$generated_root" >/dev/null 2>&1
then
  grep -R -n -E '^[[:space:]]*(public|open)[[:space:]]' "$generated_root" >&2 || true
  die "Generated CodexWire sources must not declare public or open symbols."
fi

public_leaks=$(
  grep -R -n -E '^[[:space:]]*(public|open)[[:space:]]' "$REPO_ROOT/Sources/SwiftASB" |
    grep -F "CodexWire" || true
)

if [ -n "$public_leaks" ]; then
  printf '%s\n' "$public_leaks" >&2
  die "Public SwiftASB declarations must not expose generated CodexWire names. Add a hand-owned public type and keep generated wire internal."
fi

log "Generated wire sources are internal and no public declaration exposes CodexWire names."
