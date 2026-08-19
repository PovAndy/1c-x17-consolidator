#!/usr/bin/env bash
set -euo pipefail

ROOT="{PROJECT_ROOT}"
ARCHIVE="$ROOT/Archive"

mkdir -p \
  "$ARCHIVE/scripts/versioned-copy" \
  "$ARCHIVE/build/history" \
  "$ARCHIVE/logs/history"

for f in "$ROOT"/scripts/*; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"
  case "$name" in
    copy-report-build.win.ps1|copy-116*|copy-117*)
      mv -f "$f" "$ARCHIVE/scripts/versioned-copy/$name"
      ;;
  esac
done

for f in "$ROOT"/build/*.epf; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"
  case "$name" in
    compiled.epf|ВыгрузкаЗагрузкаДанныхXMLАдаптивная_v25-117.30.epf)
      ;;
    *)
      mv -f "$f" "$ARCHIVE/build/history/$name"
      ;;
  esac
done

for f in "$ROOT"/logs/*; do
  [ -e "$f" ] || continue
  name="$(basename "$f")"
  case "$name" in
    autorun|compile.log|decompile.log|preflight.report.md)
      ;;
    *)
      mv -f "$f" "$ARCHIVE/logs/history/$name"
      ;;
  esac
done

echo "Workspace housekeeping completed."
