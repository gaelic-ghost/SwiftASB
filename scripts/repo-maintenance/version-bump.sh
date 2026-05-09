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
ROADMAP_PATH="$REPO_ROOT/ROADMAP.md"
API_AUDIT_PATH="$REPO_ROOT/docs/maintainers/v1-public-api-audit.md"

[ -f "$README_PATH" ] || {
  printf 'ERROR: SwiftASB version bump expected README.md at %s, but the file was not found.\n' "$README_PATH" >&2
  exit 1
}

[ -f "$ROADMAP_PATH" ] || {
  printf 'ERROR: SwiftASB version bump expected ROADMAP.md at %s, but the file was not found.\n' "$ROADMAP_PATH" >&2
  exit 1
}

[ -f "$API_AUDIT_PATH" ] || {
  printf 'ERROR: SwiftASB version bump expected v1 public API audit docs at %s, but the file was not found.\n' "$API_AUDIT_PATH" >&2
  exit 1
}

current_version=$(
  {
    sed -n 's/.*from: "\([0-9][0-9.]*[-A-Za-z0-9.]*\)".*/\1/p' "$README_PATH"
    sed -n 's/.*`v\([0-9][0-9.]*[-A-Za-z0-9.]*\)`.*current and latest release.*/\1/p' "$README_PATH"
  } | head -n 1
)

[ -n "$current_version" ] || {
  printf 'ERROR: SwiftASB version bump could not find a README release version reference.\n' >&2
  exit 1
}

tmp_file="${TMPDIR:-/tmp}/swiftasb-readme-version.XXXXXX"
tmp_file=$(mktemp "$tmp_file")
trap 'rm -f "$tmp_file"' EXIT INT TERM

count_readme_release_references() {
  awk \
    -v version="$1" '
      index($0, "current and latest release") && index($0, "`v" version "`") {
        count += 1
      }
      index($0, "from: \"" version "\"") {
        count += 1
      }
      END {
        print count + 0
      }
    ' "$README_PATH"
}

rewrite_release_references() {
  input_path="$1"
  output_path="$2"

  awk \
    -v old_version="$current_version" \
    -v new_version="$release_version" '
      {
        gsub("`v" old_version "`", "`v" new_version "`")
        gsub("from: \"" old_version "\"", "from: \"" new_version "\"")
        print
      }
    ' "$input_path" >"$output_path"
}

readme_reference_count="$(count_readme_release_references "$current_version")"
[ "$readme_reference_count" -ge 2 ] || {
  printf 'ERROR: SwiftASB version bump expected at least two README release references for %s, but found %s.\n' "$current_version" "$readme_reference_count" >&2
  printf 'Expected the README status sentence and SwiftPM dependency snippet to both carry the release version.\n' >&2
  exit 1
}

rewrite_release_references "$README_PATH" "$tmp_file"

mv "$tmp_file" "$README_PATH"

if [ "$current_version" != "$release_version" ]; then
  stale_readme_reference_count="$(count_readme_release_references "$current_version")"
  [ "$stale_readme_reference_count" = "0" ] || {
    printf 'ERROR: SwiftASB version bump left %s stale README release reference(s) for %s.\n' "$stale_readme_reference_count" "$current_version" >&2
    exit 1
  }
fi

for doc_path in "$ROADMAP_PATH" "$API_AUDIT_PATH"; do
  tmp_file="${TMPDIR:-/tmp}/swiftasb-release-doc-version.XXXXXX"
  tmp_file=$(mktemp "$tmp_file")
  rewrite_release_references "$doc_path" "$tmp_file"
  mv "$tmp_file" "$doc_path"
done

trap 'rm -f "$tmp_file"' EXIT INT TERM

printf 'Updated SwiftASB release references from %s to %s.\n' "$current_version" "$release_version"
