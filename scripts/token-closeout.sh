#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTDIR="$ROOT/logs/token-telemetry"
mkdir -p "$OUTDIR"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
python3 "$ROOT/scripts/codex_token_telemetry.py" session-report --json > "$OUTDIR/${TS}_session.json"
python3 "$ROOT/scripts/codex_token_telemetry.py" stage-report --json > "$OUTDIR/${TS}_stages.json"
echo "session_report=$OUTDIR/${TS}_session.json"
echo "stage_report=$OUTDIR/${TS}_stages.json"
