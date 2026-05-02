#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCHEMA_PARENT=${CODEX_SCHEMA_ROOT:-"$ROOT_DIR/codex-schemas"}
CODEX_BIN=${CODEX_BIN:-codex}
include_experimental=true
force=false

usage() {
  cat <<'USAGE'
Usage:
  scripts/dump-codex-schemas.sh [--experimental] [--stable] [--force]

Checks the installed Codex CLI version, then dumps the app-server JSON Schema
bundle into codex-schemas/vX.Y.Z when that version has not been dumped yet.
The default dump includes experimental methods and fields because SwiftASB uses
the versioned schema as the maintainer source for generated wire review.

Options:
  --experimental
             Include experimental methods and fields. This is the default.
  --stable   Dump only the stable app-server schema surface for comparison
             under codex-schemas/vX.Y.Z-stable.
  --force    Replace an existing dump for the detected Codex CLI version.

Environment:
  CODEX_BIN  Codex CLI executable to inspect and run. Defaults to codex.
  CODEX_SCHEMA_ROOT
             Parent directory for versioned schema dumps. Defaults to
             codex-schemas under the repository root.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --experimental)
      include_experimental=true
      shift
      ;;
    --stable)
      include_experimental=false
      shift
      ;;
    --force)
      force=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'ERROR: Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

command -v "$CODEX_BIN" >/dev/null 2>&1 || {
  printf 'ERROR: Codex CLI executable not found: %s\n' "$CODEX_BIN" >&2
  exit 1
}

version_output=$("$CODEX_BIN" --version 2>&1)
version=$(
  printf '%s\n' "$version_output" |
    sed -n 's/^codex-cli \([0-9][0-9.]*[-A-Za-z0-9.]*\)$/\1/p' |
    tail -n 1
)

[ -n "$version" ] || {
  printf 'ERROR: Could not parse Codex CLI version from output:\n%s\n' "$version_output" >&2
  exit 1
}

if [ "$include_experimental" = true ]; then
  schema_variant="experimental"
  schema_version="v$version"
else
  schema_variant="stable"
  schema_version="v$version-stable"
fi

schema_dir="$SCHEMA_PARENT/$schema_version"

if [ -d "$schema_dir" ] && [ "$force" = false ]; then
  if find "$schema_dir" -type f -name '*.json' -print -quit | grep . >/dev/null 2>&1; then
    printf 'Codex CLI %s %s schemas already exist at %s.\n' "v$version" "$schema_variant" "$schema_dir"
    printf 'Use --force to replace that dump.\n'
    exit 0
  fi
fi

if [ -e "$schema_dir" ] && [ ! -d "$schema_dir" ]; then
  printf 'ERROR: Schema output path exists but is not a directory: %s\n' "$schema_dir" >&2
  exit 1
fi

if [ -d "$schema_dir" ] && [ "$force" = true ]; then
  tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/swiftasb-codex-schemas.XXXXXX")
  trap 'rm -rf "$tmp_dir"' EXIT INT TERM
  out_dir="$tmp_dir/$schema_version"
else
  mkdir -p "$schema_dir"
  out_dir="$schema_dir"
fi

printf 'Dumping Codex CLI v%s %s app-server schemas to %s\n' "$version" "$schema_variant" "$schema_dir"

if [ "$include_experimental" = true ]; then
  "$CODEX_BIN" app-server generate-json-schema --experimental --out "$out_dir"
else
  "$CODEX_BIN" app-server generate-json-schema --out "$out_dir"
fi

json_count=$(find "$out_dir" -type f -name '*.json' | wc -l | tr -d ' ')

if [ "$json_count" = "0" ]; then
  printf 'ERROR: Codex CLI wrote no JSON schema files to %s\n' "$out_dir" >&2
  exit 1
fi

if [ "$force" = true ]; then
  rm -rf "$schema_dir"
  mkdir -p "$SCHEMA_PARENT"
  mv "$out_dir" "$schema_dir"
  trap - EXIT INT TERM
  rm -rf "$tmp_dir"
fi

printf 'Wrote %s JSON schema files for Codex CLI v%s %s under %s\n' "$json_count" "$version" "$schema_variant" "$schema_dir"
