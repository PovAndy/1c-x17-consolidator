#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WHEELHOUSE="$REPO_ROOT/context/mempalace/wheelhouse"

mkdir -p "$WHEELHOUSE"

copy_if_found() {
  local pattern="$1"
  local found
  found="$(find {HOME} -maxdepth 6 -type f | rg "$pattern" | head -n 1 || true)"
  if [[ -n "$found" ]]; then
    cp -f "$found" "$WHEELHOUSE/"
    echo "Copied: $found"
  else
    echo "Missing local wheel: $pattern"
  fi
}

copy_if_found 'pyyaml-.*\.whl$'
copy_if_found 'chromadb-.*\.(whl|tar\.gz)$'

echo "Wheelhouse: $WHEELHOUSE"
find "$WHEELHOUSE" -maxdepth 1 -type f | sort
