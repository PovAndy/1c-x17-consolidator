#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
audit_only=0
if [[ "${1:-}" == "--audit-only" ]]; then
  audit_only=1
elif [[ $# -gt 0 ]]; then
  echo "ОШИБКА: неизвестный параметр сборки: $1" >&2
  exit 2
fi

"$root/.venv-gemini-bridge/bin/python" "$root/scripts/run_targeted_audit.py" --gate

if [[ "$audit_only" -eq 1 ]]; then
  echo 'AUDIT_ONLY_OK'
  exit 0
fi

# shellcheck disable=SC1090
source "$root/.env"

DB_USER="${DB_USER:-${EPF_DB_USER:-}}"
DB_PWD="${DB_PWD:-${EPF_DB_PWD:-}}"

SRC_DIR="$root/src"
OUT_DIR="$root/build"
OUT_EPF="$OUT_DIR/ВыгрузкаЗагрузкаДанныхXML83_О_А_25-112.9.epf"

mkdir -p "$OUT_DIR"

{WORKSPACE_ROOT}/oscript_modules/bin/vrunner compileepf "$SRC_DIR" "$OUT_EPF" \
  --ibconnection "$IB_CONN" \
  ${DB_USER:+--db-user "$DB_USER"} \
  ${DB_PWD:+--db-pwd "$DB_PWD"} \
  ${V8_VERSION:+--v8version "$V8_VERSION"} \
  ${BITNESS:+--bitness "$BITNESS"} \
  --language "${LANG:-ru}" \
  --root "$root" \
  --nocacheuse
