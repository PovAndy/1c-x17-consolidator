#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$ROOT_DIR/src"
DOCS_DIR="$ROOT_DIR/docs"
OUT_INDEX="$DOCS_DIR/project-structure.md"
OUT_OUTLINE_DIR="$DOCS_DIR/outlines"

mkdir -p "$DOCS_DIR" "$OUT_OUTLINE_DIR"

{
  echo "# Project Structure Index"
  echo
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  if [ -d "$SRC_DIR" ]; then
    find "$SRC_DIR" -type f | LC_ALL=C sort | while read -r f; do
      rel="${f#$ROOT_DIR/}"
      printf -- "- %s\n" "$rel"
    done
  else
    echo "- src directory not found"
  fi
} > "$OUT_INDEX"

if [ -d "$SRC_DIR" ]; then
  find "$SRC_DIR" -type f \( -name '*.bsl' -o -name '*.xml' \) | while read -r f; do
    rel="${f#$ROOT_DIR/}"
    base_name="$(basename "$f" | sed 's/[^[:alnum:]_.-]/_/g')"
    hash_name="$(printf '%s' "$rel" | sha1sum | cut -c1-10)"
    out="$OUT_OUTLINE_DIR/${base_name}_${hash_name}.md"

    {
      echo "# Outline: $rel"
      echo
      if [[ "$f" == *.bsl ]]; then
        echo "## Top-level Declarations"
        rg -n "^(Процедура|Функция)\\s+" "$f" || true
      else
        echo "## XML Root/Important Tags"
        rg -n "^<[^!?][^>]*>|<MetaDataObject|<Configuration" "$f" | head -n 40 || true
      fi
    } > "$out"
  done
fi

echo "OK: $OUT_INDEX"
echo "OK: $OUT_OUTLINE_DIR"
