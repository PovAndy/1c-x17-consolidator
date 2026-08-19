#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail=0
windows_bridge_ok=0

if [ ! -x {WORKSPACE_ROOT}/oscript_modules/bin/vrunner ]; then
  echo "ERROR: vrunner not found or not executable: {WORKSPACE_ROOT}/oscript_modules/bin/vrunner"
  fail=1
else
  {WORKSPACE_ROOT}/oscript_modules/bin/vrunner version || true
fi

if [ ! -f "$root/.env" ]; then
  echo "WARN: $root/.env not found. Copy .env.example to .env and fill values."
  fail=1
fi

if [ -f "$root/.env" ]; then
  # shellcheck disable=SC1090
  source "$root/.env"

  if command -v powershell.exe >/dev/null 2>&1 && [ -f "$root/scripts/compile.win.ps1" ]; then
    if powershell.exe -NoProfile -Command "Test-Path 'C:\Program Files\1cv8\8.3.27.1964\bin\1cv8.exe'" | tr -d '\r' | grep -q '^True$'; then
      windows_bridge_ok=1
      echo "INFO: Windows bridge compile path is available"
    fi
  fi

  if [ -n "${V8_BIN:-}" ] && [ -x "${V8_BIN:-}" ] && [ -n "${IB_CONN:-}" ]; then
    echo "INFO: Linux vrunner compile path is available"
  elif [ $windows_bridge_ok -eq 1 ]; then
    echo "INFO: Linux V8/IB_CONN not configured, but Windows bridge is the active supported path"
  else
    if [ -z "${V8_BIN:-}" ] || [ ! -x "${V8_BIN:-}" ]; then
      echo "WARN: V8_BIN is not set or not executable: ${V8_BIN:-<empty>}"
    fi
    if [ -z "${IB_CONN:-}" ]; then
      echo "WARN: IB_CONN is empty"
    fi
    fail=1
  fi

  if [ -z "${DB_USER:-${EPF_DB_USER:-}}" ]; then
    echo "WARN: neither DB_USER nor EPF_DB_USER is set"
    fail=1
  fi
  if [ -z "${DB_PWD:-${EPF_DB_PWD:-}}" ]; then
    echo "WARN: neither DB_PWD nor EPF_DB_PWD is set"
    fail=1
  fi
fi

if [ $fail -ne 0 ]; then
  exit 2
fi

echo "OK"
