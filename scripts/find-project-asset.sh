#!/usr/bin/env bash
set -euo pipefail
ROOT="{PROJECT_ROOT}"
if [ $# -eq 0 ]; then
  echo "Usage: $0 <pattern> [more patterns]" >&2
  exit 2
fi
find "$ROOT" \
  -path "$ROOT/Archive" -prune -o \
  -type f \( ! -name 'MANIFEST.csv' -a ! -name 'INDEX.md' \) -print | while read -r f; do
  bn="$(basename "$f")"
  path="$f"
  ok=1
  for q in "$@"; do
    ql="$(printf '%s' "$q" | tr '[:upper:]' '[:lower:]')"
    hay="$(printf '%s %s' "$bn" "$path" | tr '[:upper:]' '[:lower:]')"
    case "$hay" in
      *"$ql"*) ;;
      *) ok=0; break ;;
    esac
  done
  [ $ok -eq 1 ] && printf '%s\n' "$f"
done
