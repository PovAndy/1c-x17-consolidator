#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="$REPO_ROOT/.venv-mempalace"
PALACE_HOME="$REPO_ROOT/context/mempalace/palace"
LOG_DIR="$REPO_ROOT/context/mempalace/logs"
STAGING="$REPO_ROOT/context/mempalace/source-curated"

mkdir -p "$PALACE_HOME" "$LOG_DIR"

if [[ ! -d "$VENV" ]]; then
  python3 -m venv "$VENV"
fi

"$VENV/bin/python" -m pip --version >/dev/null

echo "Building curated staging..."
"$REPO_ROOT/scripts/build-mempalace-curated.sh"

echo "Installing MemPalace pilot runtime..."
"$REPO_ROOT/scripts/install-mempalace-from-wheelhouse.sh" >"$LOG_DIR/bootstrap-install.log" 2>&1

echo "Initializing MemPalace pilot..."
export MEMPALACE_PALACE_PATH="$PALACE_HOME"
"$VENV/bin/mempalace" init --yes "$STAGING" >"$LOG_DIR/init.log" 2>&1 || true

echo "Mining curated staging..."
"$VENV/bin/mempalace" mine "$STAGING" >"$LOG_DIR/mine.log" 2>&1 || true

echo "Running smoke test..."
"$REPO_ROOT/scripts/smoke-test-mempalace.sh" >"$LOG_DIR/smoke.log" 2>&1 || true

echo "Pilot bootstrap completed."
echo "Venv:        $VENV"
echo "Palace home: $PALACE_HOME"
echo "Logs:        $LOG_DIR"
