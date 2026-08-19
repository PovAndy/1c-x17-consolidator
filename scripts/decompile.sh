#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck disable=SC1090
source "$root/.env"

DB_USER="${DB_USER:-${EPF_DB_USER:-}}"
DB_PWD="${DB_PWD:-${EPF_DB_PWD:-}}"

EPF_SRC="$root/../ВыгрузкаЗагрузкаДанныхXML83_О_А_25-112.9.epf"
OUT_DIR="$root/src"

mkdir -p "$OUT_DIR"

{WORKSPACE_ROOT}/oscript_modules/bin/vrunner decompileepf "$EPF_SRC" "$OUT_DIR" \
  --ibconnection "$IB_CONN" \
  ${DB_USER:+--db-user "$DB_USER"} \
  ${DB_PWD:+--db-pwd "$DB_PWD"} \
  ${V8_VERSION:+--v8version "$V8_VERSION"} \
  ${BITNESS:+--bitness "$BITNESS"} \
  --language "${LANG:-ru}" \
  --root "$root" \
  --nocacheuse
