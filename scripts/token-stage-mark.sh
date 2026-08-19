#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/codex_token_telemetry.py stage-mark "$@"
