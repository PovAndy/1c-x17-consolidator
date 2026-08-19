#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <dump_name> [subpath1,subpath2,...]" >&2
  echo "Example: $0 x1_14" >&2
  echo "Example: $0 x1_14 CommonModules,Documents,InformationRegisters,AccumulationRegisters,Catalogs" >&2
  exit 2
fi

DUMP_NAME="$1"
SUBPATHS="${2:-}"

SRC_ROOT="/mnt/t/1S/wsl_exchange/work_epf_112_9/config-dumps/${DUMP_NAME}"
DST_ROOT="{PROJECT_ROOT}/context/config-dumps/${DUMP_NAME}_local"

if [[ ! -d "$SRC_ROOT" ]]; then
  echo "Source dump not found: $SRC_ROOT" >&2
  exit 1
fi

mkdir -p "$DST_ROOT"

copy_one() {
  local rel="$1"
  local src="$SRC_ROOT/$rel"
  local dst="$DST_ROOT/$rel"

  if [[ -d "$src" ]]; then
    mkdir -p "$(dirname "$dst")"
    rm -rf "$dst"
    cp -a "$src" "$dst"
    echo "COPIED DIR $rel"
  elif [[ -f "${src}.xml" ]]; then
    mkdir -p "$(dirname "$dst")"
    cp -a "${src}.xml" "${dst}.xml"
    echo "COPIED XML ${rel}.xml"
  else
    echo "MISS $rel" >&2
  fi
}

if [[ -n "$SUBPATHS" ]]; then
  IFS=',' read -r -a parts <<< "$SUBPATHS"
  for rel in "${parts[@]}"; do
    rel="${rel#"${rel%%[![:space:]]*}"}"
    rel="${rel%"${rel##*[![:space:]]}"}"
    [[ -z "$rel" ]] && continue
    copy_one "$rel"
  done
else
  rm -rf "$DST_ROOT"
  mkdir -p "$DST_ROOT"
  cp -a "$SRC_ROOT/." "$DST_ROOT/"
  echo "COPIED ALL $DUMP_NAME"
fi

echo "TARGET=$DST_ROOT"
find "$DST_ROOT" -maxdepth 2 | sed -n '1,120p'
