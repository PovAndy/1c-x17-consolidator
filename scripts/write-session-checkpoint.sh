#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$ROOT/context/memory/session-checkpoint.md"

cat > "$TARGET" <<TPL
# Session Checkpoint

## Objective
- ${OBJECTIVE:-}

## Confirmed Facts
- ${FACTS:-}

## Rejected Hypotheses
- ${REJECTED:-}

## Active Artifacts
- ${ARTIFACTS:-}

## Next Step
- ${NEXT_STEP:-}
TPL

echo "Wrote $TARGET"
