#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <log_file> [command]"
  exit 2
fi

LOG_FILE="$1"
CMD="${2:-unknown}"

if [ ! -f "$LOG_FILE" ]; then
  echo "log file not found: $LOG_FILE"
  exit 2
fi

STATUS="pass"
if rg -n "ERROR|Ошибка|failed|Exception|Исключение" "$LOG_FILE" >/dev/null 2>&1; then
  STATUS="fail"
fi

echo "command: $CMD"
echo "status: $STATUS"
echo "log_path: $LOG_FILE"
echo "key_errors:"
rg -n "ERROR|Ошибка|failed|Exception|Исключение" "$LOG_FILE" | head -n 12 || true
echo "affected_files:"
rg -no "[A-Za-z]:\\[^\r\n\"]+|/[^\s\"]+\.(bsl|xml|ps1|bat|epf|log)" "$LOG_FILE" | head -n 12 || true
echo "next_action: inspect first key error and rerun preflight"
