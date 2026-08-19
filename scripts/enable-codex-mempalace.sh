#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="$REPO_ROOT/scripts/run-mempalace-mcp.sh"

if ! command -v codex >/dev/null 2>&1; then
  echo "codex CLI not found in PATH" >&2
  exit 1
fi

if [[ ! -x "$RUNNER" ]]; then
  echo "MemPalace MCP runner is missing or not executable: $RUNNER" >&2
  exit 2
fi

codex mcp remove mempalace >/dev/null 2>&1 || true
codex mcp add mempalace -- "$RUNNER"
echo "MemPalace MCP server registered in codex."
echo "If this is an already-open session, restart the session to pick up the new MCP server."
