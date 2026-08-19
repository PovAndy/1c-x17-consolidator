#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="$REPO_ROOT/.venv-mempalace"
WHEELHOUSE="$REPO_ROOT/context/mempalace/wheelhouse"
VENDOR_SRC="$REPO_ROOT/context/mempalace/vendor/mempalace-main"
CHROMADB_COMPAT="$REPO_ROOT/tools/mempalace_chromadb_compat"

mkdir -p "$WHEELHOUSE"

if [[ ! -d "$VENV" ]]; then
  python3 -m venv "$VENV"
fi

PY="$VENV/bin/python"
PIP="$VENV/bin/pip"

missing=0
if ! find "$WHEELHOUSE" -maxdepth 1 -type f | rg -qi '/pyyaml-'; then
  echo "Missing wheel for dependency: pyyaml"
  missing=1
fi

if [[ ! -d "$VENDOR_SRC" ]]; then
  echo "Missing vendored MemPalace source at: $VENDOR_SRC"
  echo "Run scripts/download-mempalace-source.py first."
  missing=1
fi

if [[ ! -d "$CHROMADB_COMPAT" ]]; then
  echo "Missing local chromadb compatibility package at: $CHROMADB_COMPAT"
  missing=1
fi

if [[ $missing -ne 0 ]]; then
  echo "Offline install prerequisites are incomplete."
  exit 2
fi

src_dir="$(find "$VENDOR_SRC" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
if [[ -z "$src_dir" ]]; then
  echo "Cannot find extracted MemPalace source inside: $VENDOR_SRC"
  exit 3
fi

"$PIP" install --no-index --find-links "$WHEELHOUSE" pyyaml
"$PIP" install --no-deps -e "$CHROMADB_COMPAT"
"$PIP" install --no-deps "$src_dir"

echo "Offline MemPalace install completed in $VENV using local chromadb compatibility backend"
