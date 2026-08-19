#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
OUT="$LOG_DIR/preflight.report.md"

mkdir -p "$LOG_DIR"

fail=0
check() {
  local name="$1"; shift
  if "$@"; then
    echo "- PASS: $name" >> "$OUT"
  else
    echo "- FAIL: $name" >> "$OUT"
    fail=1
  fi
}

{
  echo "# Preflight Report"
  echo
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
} > "$OUT"

# 1) Bootstrap context must run successfully
if "$ROOT_DIR/scripts/bootstrap-context.sh" >/dev/null; then
  echo "- PASS: bootstrap-context" >> "$OUT"
else
  echo "- FAIL: bootstrap-context" >> "$OUT"
  fail=1
fi

# 2) Critical paths
check "src exists" test -d "$ROOT_DIR/src"
check "object module exists" test -f "$ROOT_DIR/src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная/Ext/ObjectModule.bsl"
check "windows decompile script exists" test -f "$ROOT_DIR/scripts/decompile.win.ps1"
check "windows compile script exists" test -f "$ROOT_DIR/scripts/compile.win.ps1"

# 3) Safety markers in scripts
check "compile script uses root xml auto-detect" grep -q "Get-ChildItem -LiteralPath \$WinSrc -File -Filter \*.xml" "$ROOT_DIR/scripts/compile.win.ps1"
check "scripts support env credentials" grep -q "EPF_DB_USER" "$ROOT_DIR/scripts/decompile.win.ps1"
check "scripts support env credentials (compile)" grep -q "EPF_DB_USER" "$ROOT_DIR/scripts/compile.win.ps1"

# 4) Agent governance required files
check "runbook exists" test -f "$ROOT_DIR/AGENT_OPERATIONS.md"
check "self-contract exists" test -f "$ROOT_DIR/agents/contracts/codex-self-contract.md"
check "compression policy exists" test -f "$ROOT_DIR/agents/contracts/tool-output-compression.md"
check "typed memory policy exists" grep -q "Memory Types" "$ROOT_DIR/mcp/memory-policy.md"

# 5) Quick code health hints (non-fatal info)
{
  echo
  echo "## Hints"
  rg -n "УстановитьПривилегированныйРежим\(Истина\)" "$ROOT_DIR/src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная/Ext/ObjectModule.bsl" || true
  rg -n "Попытка\s*$|Исключение\s*$" "$ROOT_DIR/src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная/Ext/ObjectModule.bsl" | head -n 20 || true
} >> "$OUT"

if [ "$fail" -ne 0 ]; then
  echo "PRECHECK: FAIL"
  echo "See: $OUT"
  exit 1
fi

echo "PRECHECK: PASS"
echo "See: $OUT"
