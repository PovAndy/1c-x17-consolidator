#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="$REPO_ROOT/.venv-mempalace"
PALACE_HOME="$REPO_ROOT/context/mempalace/palace"
STAGING="$REPO_ROOT/context/mempalace/source-curated"
LOG_DIR="$REPO_ROOT/context/mempalace/logs"
WHEELHOUSE="$REPO_ROOT/context/mempalace/wheelhouse"
VENDOR="$REPO_ROOT/context/mempalace/vendor"

echo "MemPalace pilot status"
echo "repo          : $REPO_ROOT"
echo "venv exists   : $( [[ -d "$VENV" ]] && echo yes || echo no )"
echo "palace exists : $( [[ -d "$PALACE_HOME" ]] && echo yes || echo no )"
echo "staging exists: $( [[ -d "$STAGING" ]] && echo yes || echo no )"
echo "logs exists   : $( [[ -d "$LOG_DIR" ]] && echo yes || echo no )"
echo "wheelhouse    : $( [[ -d "$WHEELHOUSE" ]] && echo yes || echo no )"
echo "vendor exists : $( [[ -d "$VENDOR" ]] && echo yes || echo no )"

if [[ -x "$VENV/bin/python" ]]; then
  "$VENV/bin/python" --version
  "$VENV/bin/python" - <<'PY' || true
try:
    import chromadb
    print('chromadb import : yes')
    print('compat backend  :', getattr(chromadb, '__compat_backend__', False))
except Exception as e:
    print('chromadb import : no')
    print('chromadb error  :', e)
try:
    import mempalace
    print('mempalace import: yes')
    print('mempalace ver   :', getattr(mempalace, '__version__', 'unknown'))
except Exception as e:
    print('mempalace import: no')
    print('mempalace error :', e)
PY
fi

if [[ -x "$VENV/bin/mempalace" ]]; then
  MEMPALACE_PALACE_PATH="$PALACE_HOME" "$VENV/bin/mempalace" status || true
else
  echo "mempalace CLI not installed in pilot venv"
fi

echo "wheelhouse files:"
find "$WHEELHOUSE" -maxdepth 1 -type f 2>/dev/null | sort || true
