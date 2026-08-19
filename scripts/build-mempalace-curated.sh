#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPO_ROOT/context/mempalace/manifest-curated.txt"
STAGING="$REPO_ROOT/context/mempalace/source-curated"
GENERATED="$REPO_ROOT/context/mempalace/source-generated"
RESOLVED="$GENERATED/resolved-manifest.txt"

mkdir -p "$STAGING" "$GENERATED"
rm -rf "$STAGING"
mkdir -p "$STAGING"
: > "$RESOLVED"

copy_path() {
  local rel="$1"
  local src="$REPO_ROOT/$rel"
  local dst="$STAGING/$rel"
  if [[ ! -e "$src" ]]; then
    echo "MISSING $rel" >&2
    return 1
  fi
  mkdir -p "$(dirname "$dst")"
  if [[ -d "$src" ]]; then
    cp -a "$src" "$dst"
  else
    cp -a "$src" "$dst"
  fi
  printf '%s\n' "$rel" >> "$RESOLVED"
}

while IFS= read -r line; do
  line="${line%%#*}"
  line="$(printf '%s' "$line" | sed 's/[[:space:]]*$//')"
  [[ -z "$line" ]] && continue
  copy_path "$line"
done < "$MANIFEST"

echo "Curated staging built:"
echo "  manifest: $MANIFEST"
echo "  resolved: $RESOLVED"
echo "  staging : $STAGING"
