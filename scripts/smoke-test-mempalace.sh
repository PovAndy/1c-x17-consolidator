#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="$REPO_ROOT/.venv-mempalace"
PALACE_HOME="$REPO_ROOT/context/mempalace/palace"
STAGING="$REPO_ROOT/context/mempalace/source-curated"
PY="$VENV/bin/python"
MEMPAL="$VENV/bin/mempalace"

export MEMPALACE_PALACE_PATH="$PALACE_HOME"

"$PY" - <<'PY'
import chromadb, mempalace
print('python_imports: ok')
print('chromadb_backend:', getattr(chromadb, '__compat_backend__', False))
print('mempalace_version:', getattr(mempalace, '__version__', 'unknown'))
PY

"$MEMPAL" status
"$MEMPAL" search meter >/dev/null || true
"$PY" - <<'PY'
from mempalace.searcher import search_memories
import os
palace = os.environ['MEMPALACE_PALACE_PATH']
res = search_memories('meter recovery', palace, n_results=3)
print('programmatic_search_results:', len(res.get('results', [])))
PY
