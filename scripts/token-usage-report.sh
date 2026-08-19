#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-daily}"
shift || true
cd {PROJECT_ROOT}
npx --yes @ccusage/codex@18.0.10 "$MODE" "$@"
