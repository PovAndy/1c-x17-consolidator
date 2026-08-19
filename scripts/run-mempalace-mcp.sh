#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="$REPO_ROOT/.venv-mempalace"
PALACE_HOME="$REPO_ROOT/context/mempalace/palace"

if [[ ! -x "$VENV/bin/python" ]]; then
  echo "Missing pilot venv: $VENV" >&2
  exit 1
fi

if ! MEMPALACE_PALACE_PATH="$PALACE_HOME" "$VENV/bin/python" - <<'PY' >/dev/null 2>&1
import mempalace  # noqa
import chromadb   # noqa
PY
then
  echo "MemPalace runtime dependencies are not installed in $VENV" >&2
  echo "Run scripts/bootstrap-mempalace-pilot.sh first." >&2
  exit 2
fi

export MEMPALACE_PALACE_PATH="$PALACE_HOME"
exec "$VENV/bin/python" -m mempalace.mcp_server --palace "$PALACE_HOME"
