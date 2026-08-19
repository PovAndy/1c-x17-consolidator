#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_PY="$ROOT_DIR/.venv-mcp/bin/python"
WEB_SERVER="$ROOT_DIR/scripts/local_web_mcp.py"

echo "== Codex MCP list =="
codex mcp list

echo
echo "== local-web self-test: search =="
"$VENV_PY" "$WEB_SERVER" --self-test-search "Универсальный механизм обмена данными 1С" --self-test-site "its.1c.ru" | sed -n '1,80p'

echo
echo "== local-web self-test: fetch =="
"$VENV_PY" "$WEB_SERVER" --self-test-fetch "https://its.1c.ru/db/content/intgr83/src/139.html" | sed -n '1,80p'
