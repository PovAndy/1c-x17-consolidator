#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_PY="$ROOT_DIR/.venv-mcp/bin/python"
WEB_SERVER="$ROOT_DIR/scripts/local_web_mcp.py"

if [[ ! -x "$VENV_PY" ]]; then
  echo "missing python venv: $VENV_PY" >&2
  exit 1
fi

if [[ ! -f "$WEB_SERVER" ]]; then
  echo "missing local web server: $WEB_SERVER" >&2
  exit 1
fi

ensure_server() {
  local name="$1"
  shift
  codex mcp get "$name" >/dev/null 2>&1 || codex mcp add "$name" -- "$@"
}

ensure_server filesystem npx -y @modelcontextprotocol/server-filesystem "$ROOT_DIR"
ensure_server sequential-thinking npx -y @modelcontextprotocol/server-sequential-thinking
ensure_server memory npx -y @modelcontextprotocol/server-memory
ensure_server local-web "$VENV_PY" "$WEB_SERVER"

echo "Configured MCP servers:"
codex mcp list
