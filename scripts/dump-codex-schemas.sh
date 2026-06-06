#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCHEMA_PARENT=${CODEX_SCHEMA_ROOT:-"$ROOT_DIR/codex-schemas"}
CODEX_BIN=${CODEX_BIN:-codex}
BREW_CODEX_PACKAGE=${BREW_CODEX_PACKAGE:-codex}

include_experimental=true
force=false
mode=dump
output_json=false
brew_check=false
brew_upgrade=false
dump_after_upgrade=false

usage() {
  cat <<'USAGE'
Usage:
  scripts/dump-codex-schemas.sh [--experimental] [--stable] [--force]
  scripts/dump-codex-schemas.sh --check [--json] [--brew-check]
  scripts/dump-codex-schemas.sh --dump-if-newer [--json] [--brew-check]
  scripts/dump-codex-schemas.sh --brew-upgrade-codex --dump-after-upgrade [--json]

Checks the installed Codex CLI version, then dumps the app-server JSON Schema
bundle into codex-schemas/vX.Y.Z when that version has not been dumped yet.
The default dump includes experimental methods and fields because SwiftASB uses
the versioned schema as the maintainer source for generated wire review.

Options:
  --check   Inspect installed/local schema state without dumping schemas.
  --json    Print a machine-readable JSON summary after check or dump work.
  --dump-if-newer
            Dump only when the installed Codex CLI version is newer than the
            latest local schema dump for the selected variant.
  --brew-check
            Run brew outdated for the Codex Homebrew package and report whether
            Homebrew has a newer version available.
  --brew-upgrade-codex
            Explicitly upgrade only the Codex Homebrew package when brew reports
            it outdated. This is never implied by --brew-check.
  --dump-after-upgrade
            After --brew-upgrade-codex, re-check codex --version and dump the
            upgraded CLI schemas when they are newer than local dumps.
  --experimental
            Include experimental methods and fields. This is the default.
  --stable  Dump only the stable app-server schema surface for comparison
            under codex-schemas/vX.Y.Z-stable.
  --force   Replace an existing dump for the detected Codex CLI version.

Environment:
  CODEX_BIN  Codex CLI executable to inspect and run. Defaults to codex.
  CODEX_SCHEMA_ROOT
             Parent directory for versioned schema dumps. Defaults to
             codex-schemas under the repository root.
  BREW_CODEX_PACKAGE
             Homebrew formula or cask name to check or upgrade. Defaults to
             codex.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check)
      mode=check
      shift
      ;;
    --json)
      output_json=true
      shift
      ;;
    --dump-if-newer)
      mode=dump-if-newer
      shift
      ;;
    --brew-check)
      brew_check=true
      shift
      ;;
    --brew-upgrade-codex)
      brew_upgrade=true
      brew_check=true
      shift
      ;;
    --dump-after-upgrade)
      dump_after_upgrade=true
      shift
      ;;
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

if [ "$mode" = check ] && [ "$brew_upgrade" = true ]; then
  printf 'ERROR: --check cannot be combined with --brew-upgrade-codex.\n' >&2
  exit 1
fi

if [ "$dump_after_upgrade" = true ] && [ "$brew_upgrade" = false ]; then
  printf 'ERROR: --dump-after-upgrade requires --brew-upgrade-codex.\n' >&2
  exit 1
fi

command -v "$CODEX_BIN" >/dev/null 2>&1 || {
  printf 'ERROR: Codex CLI executable not found: %s\n' "$CODEX_BIN" >&2
  exit 1
}

variant_suffix() {
  if [ "$include_experimental" = true ]; then
    printf '%s\n' ''
  else
    printf '%s\n' '-stable'
  fi
}

schema_variant_name() {
  if [ "$include_experimental" = true ]; then
    printf '%s\n' 'experimental'
  else
    printf '%s\n' 'stable'
  fi
}

version_key() {
  printf '%s\n' "$1" |
    sed 's/^v//; s/-stable$//; s/[^0-9.].*$//'
}

version_gt() {
  awk -v left="$1" -v right="$2" '
    BEGIN {
      split(left, a, ".")
      split(right, b, ".")
      for (i = 1; i <= 4; i++) {
        av = (a[i] == "" ? 0 : a[i]) + 0
        bv = (b[i] == "" ? 0 : b[i]) + 0
        if (av > bv) { exit 0 }
        if (av < bv) { exit 1 }
      }
      exit 1
    }
  '
}

json_escape() {
  printf '%s' "$1" |
    awk 'BEGIN { first = 1 } {
      gsub(/\\/, "\\\\")
      gsub(/"/, "\\\"")
      gsub(/\t/, "\\t")
      if (first) {
        first = 0
      } else {
        printf "\\n"
      }
      printf "%s", $0
    }'
}

say() {
  if [ "$output_json" = false ]; then
    printf "$@"
  fi
}

schema_json_count() {
  dir=$1
  if [ ! -d "$dir" ]; then
    printf '%s\n' 0
    return
  fi
  find "$dir" -type f -name '*.json' | wc -l | tr -d ' '
}

codex_version() {
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
  printf '%s\n' "$version"
}

latest_local_dump() {
  suffix=$(variant_suffix)
  latest_name=''
  latest_key=''
  [ -d "$SCHEMA_PARENT" ] || {
    printf '%s\n' ''
    return
  }

  for dir in "$SCHEMA_PARENT"/v*; do
    [ -d "$dir" ] || continue
    name=$(basename -- "$dir")
    case "$suffix:$name" in
      -stable:*-stable) ;;
      -stable:*) continue ;;
      :*-stable) continue ;;
      :) ;;
    esac
    count=$(schema_json_count "$dir")
    [ "$count" != 0 ] || continue
    key=$(version_key "$name")
    if [ -z "$latest_name" ] || version_gt "$key" "$latest_key"; then
      latest_name=$name
      latest_key=$key
    fi
  done
  printf '%s\n' "$latest_name"
}

run_brew_check() {
  brew_status=not-run
  brew_outdated=false
  brew_output=''
  brew_error=''

  if [ "$brew_check" = false ]; then
    return
  fi

  if ! command -v brew >/dev/null 2>&1; then
    brew_status=unavailable
    brew_error='Homebrew executable not found.'
    return
  fi

  brew_status=checked
  brew_stdout=$(mktemp "${TMPDIR:-/tmp}/swiftasb-brew-outdated.stdout.XXXXXX")
  brew_stderr=$(mktemp "${TMPDIR:-/tmp}/swiftasb-brew-outdated.stderr.XXXXXX")
  set +e
  brew outdated "$BREW_CODEX_PACKAGE" >"$brew_stdout" 2>"$brew_stderr"
  brew_code=$?
  set -e
  brew_output=$(cat "$brew_stdout")
  brew_error=$(cat "$brew_stderr")
  rm -f "$brew_stdout" "$brew_stderr"

  if [ "$brew_code" -ne 0 ] && [ -z "$brew_output" ] && [ -n "$brew_error" ]; then
    brew_status=error
    return
  fi

  if [ "$brew_code" -eq 0 ]; then
    brew_error=''
  fi

  if [ -n "$brew_output" ]; then
    brew_outdated=true
  fi
}

maybe_brew_upgrade() {
  brew_upgraded=false
  if [ "$brew_upgrade" = false ]; then
    return
  fi

  if [ "$brew_status" != checked ]; then
    printf 'ERROR: Cannot upgrade Codex because brew check did not succeed: %s\n' "$brew_error" >&2
    exit 1
  fi

  if [ "$brew_outdated" = false ]; then
    say 'Homebrew reports %s is already current.\n' "$BREW_CODEX_PACKAGE"
    return
  fi

  say 'Upgrading Homebrew package %s before schema dump.\n' "$BREW_CODEX_PACKAGE"
  brew upgrade "$BREW_CODEX_PACKAGE"
  brew_upgraded=true
}

print_json_summary() {
  printf '{\n'
  printf '  "codex_bin": "%s",\n' "$(json_escape "$CODEX_BIN")"
  printf '  "installed_codex_cli": "%s",\n' "$(json_escape "$version")"
  printf '  "schema_variant": "%s",\n' "$(json_escape "$schema_variant")"
  printf '  "schema_parent": "%s",\n' "$(json_escape "$SCHEMA_PARENT")"
  printf '  "schema_version": "%s",\n' "$(json_escape "$schema_version")"
  printf '  "schema_dir": "%s",\n' "$(json_escape "$schema_dir")"
  printf '  "schema_json_files": %s,\n' "$schema_json_files"
  printf '  "latest_local_dump": "%s",\n' "$(json_escape "$latest_dump")"
  printf '  "installed_newer_than_local": %s,\n' "$installed_newer_than_local"
  printf '  "dump_missing": %s,\n' "$dump_missing"
  printf '  "dumped": %s,\n' "$dumped"
  printf '  "brew": {\n'
  printf '    "package": "%s",\n' "$(json_escape "$BREW_CODEX_PACKAGE")"
  printf '    "status": "%s",\n' "$(json_escape "$brew_status")"
  printf '    "outdated": %s,\n' "$brew_outdated"
  printf '    "upgraded": %s,\n' "$brew_upgraded"
  printf '    "detail": "%s",\n' "$(json_escape "$brew_output")"
  printf '    "error": "%s"\n' "$(json_escape "$brew_error")"
  printf '  }\n'
  printf '}\n'
}

dump_schemas() {
  if [ -d "$schema_dir" ] && [ "$force" = false ]; then
    if find "$schema_dir" -type f -name '*.json' -print -quit | grep . >/dev/null 2>&1; then
      say 'Codex CLI %s %s schemas already exist at %s.\n' "v$version" "$schema_variant" "$schema_dir"
      say 'Use --force to replace that dump.\n'
      return
    fi
  fi

  if [ -e "$schema_dir" ] && [ ! -d "$schema_dir" ]; then
    printf 'ERROR: Schema output path exists but is not a directory: %s\n' "$schema_dir" >&2
    exit 1
  fi

  tmp_dir=''
  if [ -d "$schema_dir" ] && [ "$force" = true ]; then
    tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/swiftasb-codex-schemas.XXXXXX")
    trap 'rm -rf "$tmp_dir"' EXIT INT TERM
    out_dir="$tmp_dir/$schema_version"
  else
    mkdir -p "$schema_dir"
    out_dir="$schema_dir"
  fi

  say 'Dumping Codex CLI v%s %s app-server schemas to %s\n' "$version" "$schema_variant" "$schema_dir"

  if [ "$include_experimental" = true ]; then
    if [ "$output_json" = true ]; then
      "$CODEX_BIN" app-server generate-json-schema --experimental --out "$out_dir" >&2
    else
      "$CODEX_BIN" app-server generate-json-schema --experimental --out "$out_dir"
    fi
  else
    if [ "$output_json" = true ]; then
      "$CODEX_BIN" app-server generate-json-schema --out "$out_dir" >&2
    else
      "$CODEX_BIN" app-server generate-json-schema --out "$out_dir"
    fi
  fi

  json_count=$(schema_json_count "$out_dir")

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

  dumped=true
  say 'Wrote %s JSON schema files for Codex CLI v%s %s under %s\n' "$json_count" "$version" "$schema_variant" "$schema_dir"
}

brew_status=not-run
brew_outdated=false
brew_output=''
brew_error=''
brew_upgraded=false
dumped=false

version=$(codex_version)
schema_variant=$(schema_variant_name)
schema_version="v$version$(variant_suffix)"
schema_dir="$SCHEMA_PARENT/$schema_version"
latest_dump=$(latest_local_dump)
schema_json_files=$(schema_json_count "$schema_dir")
dump_missing=false
[ "$schema_json_files" = 0 ] && dump_missing=true

installed_newer_than_local=false
if [ -n "$latest_dump" ]; then
  if version_gt "$(version_key "$schema_version")" "$(version_key "$latest_dump")"; then
    installed_newer_than_local=true
  fi
else
  installed_newer_than_local=true
fi

run_brew_check
maybe_brew_upgrade

if [ "$brew_upgraded" = true ]; then
  version=$(codex_version)
  schema_version="v$version$(variant_suffix)"
  schema_dir="$SCHEMA_PARENT/$schema_version"
  latest_dump=$(latest_local_dump)
  schema_json_files=$(schema_json_count "$schema_dir")
  dump_missing=false
  [ "$schema_json_files" = 0 ] && dump_missing=true
  installed_newer_than_local=false
  if [ -n "$latest_dump" ]; then
    if version_gt "$(version_key "$schema_version")" "$(version_key "$latest_dump")"; then
      installed_newer_than_local=true
    fi
  else
    installed_newer_than_local=true
  fi
fi

case "$mode" in
  check)
    say 'Installed Codex CLI: v%s\n' "$version"
    say 'Latest local %s schema dump: %s\n' "$schema_variant" "${latest_dump:-none}"
    if [ "$installed_newer_than_local" = true ]; then
      say 'Installed Codex CLI is newer than local schema dumps.\n'
    else
      say 'Installed Codex CLI is not newer than local schema dumps.\n'
    fi
    ;;
  dump-if-newer)
    if [ "$installed_newer_than_local" = true ] || [ "$dump_missing" = true ]; then
      dump_schemas
    else
      say 'No schema dump needed for Codex CLI v%s %s; local dump %s is current.\n' "$version" "$schema_variant" "$latest_dump"
    fi
    ;;
  dump)
    if [ "$brew_upgraded" = true ] && [ "$dump_after_upgrade" = true ]; then
      if [ "$installed_newer_than_local" = true ] || [ "$dump_missing" = true ]; then
        dump_schemas
      else
        say 'No schema dump needed after upgrade; local dump %s is current.\n' "$latest_dump"
      fi
    else
      dump_schemas
    fi
    ;;
  *)
    printf 'ERROR: Unknown mode: %s\n' "$mode" >&2
    exit 1
    ;;
esac

schema_json_files=$(schema_json_count "$schema_dir")

if [ "$output_json" = true ]; then
  print_json_summary
fi
