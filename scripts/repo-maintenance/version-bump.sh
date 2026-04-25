#!/usr/bin/env sh
set -eu

release_version="${1:-}"

case "$release_version" in
  [0-9]*.[0-9]*.[0-9]* | [0-9]*.[0-9]*.[0-9]*-*)
    ;;
  *)
    printf 'ERROR: SwiftASB version bump expected a SemVer version like 0.1.0, but received: %s\n' "$release_version" >&2
    exit 1
    ;;
esac

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SELF_DIR/../.." && pwd)
README_PATH="$REPO_ROOT/README.md"

[ -f "$README_PATH" ] || {
  printf 'ERROR: SwiftASB version bump expected README.md at %s, but the file was not found.\n' "$README_PATH" >&2
  exit 1
}

current_version=$(
  sed -n 's/.*from: "\([0-9][0-9.]*[-A-Za-z0-9.]*\)".*/\1/p' "$README_PATH" | head -n 1
)

[ -n "$current_version" ] || {
  printf 'ERROR: SwiftASB version bump could not find the README SwiftPM package version line.\n' >&2
  exit 1
}

tmp_file="${TMPDIR:-/tmp}/swiftasb-readme-version.XXXXXX"
tmp_file=$(mktemp "$tmp_file")
trap 'rm -f "$tmp_file"' EXIT INT TERM

awk \
  -v old_version="$current_version" \
  -v new_version="$release_version" '
    {
      gsub("`v" old_version "`", "`v" new_version "`")
      gsub("from: \"" old_version "\"", "from: \"" new_version "\"")
      print
    }
  ' "$README_PATH" >"$tmp_file"

mv "$tmp_file" "$README_PATH"
trap - EXIT INT TERM

printf 'Updated SwiftASB README version references from %s to %s.\n' "$current_version" "$release_version"
