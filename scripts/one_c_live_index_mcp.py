#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import platform
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

from mcp.server.fastmcp import FastMCP

IS_WSL = platform.system() == 'Linux' and 'microsoft' in platform.release().lower()
IS_WINDOWS = platform.system() == 'Windows'

if IS_WSL:
    win32com = None

ROOT = Path("{PROJECT_ROOT}")
SQL_RUNNER = ROOT / "scripts" / "sql_ro_query.py"
BASES_CONFIG = ROOT / "scripts" / "1c-bases.win.json"
POWERSHELL = "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
COM_LIST_METADATA = ROOT / "scripts" / "list-metadata-com.win.ps1"
COM_PROBE_METADATA = ROOT / "scripts" / "probe-metadata-com.win.ps1"
WINDOWS_LOG_ROOT = r"T:\1S\wsl_exchange\work_epf_112_9\logs\mcp"
WSL_LOG_ROOT = Path("/mnt/t/1S/wsl_exchange/work_epf_112_9/logs/mcp")

ALLOWED_SQL_PREFIXES = ("select", "with", "explain")
BLOCKED_SQL_TOKENS = {
    "insert",
    "update",
    "delete",
    "truncate",
    "alter",
    "drop",
    "create",
    "grant",
    "revoke",
    "comment",
    "vacuum",
    "analyze",
    "refresh",
    "reindex",
    "cluster",
    "copy",
    "call",
    "do",
}

mcp = FastMCP("1c-live-index")


def _load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _run(cmd: list[str], timeout: int = 45) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=str(ROOT),
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        timeout=timeout,
        check=False,
    )


def _normalize_sql(sql_text: str) -> str:
    return re.sub(r"--.*?$", "", sql_text, flags=re.M).strip()


def _ensure_read_only_sql(sql_text: str) -> None:
    normalized = _normalize_sql(sql_text)
    lowered = normalized.lower()
    if not lowered.startswith(ALLOWED_SQL_PREFIXES):
        raise ValueError("Only SELECT/WITH/EXPLAIN SQL is allowed")
    tokens = set(re.findall(r"[a-z_]+", lowered))
    blocked = sorted(token for token in BLOCKED_SQL_TOKENS if token in tokens)
    if blocked:
        raise ValueError("Blocked SQL tokens detected: " + ", ".join(blocked))


def _run_sql(sql_text: str, title: str, limit: int = 200) -> dict[str, Any]:
    _ensure_read_only_sql(sql_text)
    cmd = [
        str(SQL_RUNNER),
        "--query",
        sql_text,
        "--title",
        title,
        "--limit",
        str(max(1, min(limit, 1000))),
    ]
    proc = _run(cmd, timeout=60)
    if proc.returncode != 0:
        return {
            "ok": False,
            "returncode": proc.returncode,
            "stdout": proc.stdout.strip(),
            "stderr": proc.stderr.strip(),
        }
    try:
        payload = json.loads(proc.stdout.strip().splitlines()[-1])
    except Exception:
        payload = {"stdout": proc.stdout.strip()}
    payload["ok"] = True
    return payload


def _classify_1c_table(name: str) -> str:
    table = name.lower()
    if table.startswith("_reference"):
        return "Catalog / Справочник"
    if table.startswith("_document"):
        return "Document / Документ"
    if table.startswith("_inforg"):
        return "Information register / Регистр сведений"
    if table.startswith("_accumrg"):
        return "Accumulation register / Регистр накопления"
    if table.startswith("_enum"):
        return "Enumeration / Перечисление"
    if table.startswith("_const"):
        return "Constant / Константа"
    if table.startswith("_chrc"):
        return "Characteristic plan / План видов характеристик"
    if table.startswith("_bp"):
        return "Business process / Бизнес-процесс"
    if table.startswith("_task"):
        return "Task / Задача"
    if table.startswith("_sequence"):
        return "Sequence / Последовательность"
    return "Unknown / Служебная или нетиповая таблица"


def _powershell_path(path: Path) -> str:
    return str(path).replace("{PROJECT_ROOT}", r"\\wsl.localhost\Ubuntu\{PROJECT_ROOT}").replace("/", "\\")


@mcp.tool()
def list_configured_1c_bases() -> dict[str, Any]:
    """Return configured 1C bases without secrets."""
    config = _load_json(BASES_CONFIG)
    bases = []
    for alias, base in config.get("bases", {}).items():
        kind = str(base.get("type", "file")).lower()
        bases.append(
            {
                "alias": alias,
                "kind": kind,
                "role": base.get("role", ""),
                "path": base.get("path", ""),
                "server": base.get("server", ""),
                "ref": base.get("ref", ""),
            }
        )
    return {"count": len(bases), "bases": bases}


@mcp.tool()
def pg_schema_overview(limit: int = 50) -> dict[str, Any]:
    """Summarize PostgreSQL schema tables and likely 1C table families."""
    query = """
select
  schemaname,
  relname as table_name,
  n_live_tup::bigint as estimated_rows,
  pg_size_pretty(pg_total_relation_size(format('%I.%I', schemaname, relname))) as total_size
from pg_stat_user_tables
order by pg_total_relation_size(format('%I.%I', schemaname, relname)) desc
limit {limit}
""".format(limit=max(1, min(limit, 200)))
    result = _run_sql(query, "1C PostgreSQL schema overview", limit=limit)
    result["note"] = "Full result is written to the returned md/csv artifacts."
    return result


@mcp.tool()
def pg_search_tables(pattern: str, limit: int = 100) -> dict[str, Any]:
    """Search PostgreSQL tables by name and add a 1C-family classification."""
    safe_pattern = pattern.replace("'", "''")
    query = f"""
select
  table_schema,
  table_name,
  obj_description(format('%I.%I', table_schema, table_name)::regclass, 'pg_class') as comment
from information_schema.tables
where table_type = 'BASE TABLE'
  and table_schema not in ('pg_catalog', 'information_schema')
  and lower(table_name) like lower('%{safe_pattern}%')
order by table_schema, table_name
limit {max(1, min(limit, 500))}
"""
    result = _run_sql(query, "1C PostgreSQL table search", limit=limit)
    result["classification_hint"] = "Use table prefixes such as _Reference, _Document, _InfoRg, _AccumRg, _Chrc."
    return result


@mcp.tool()
def pg_describe_table(table_name: str, schema: str = "public") -> dict[str, Any]:
    """Describe a PostgreSQL table/columns and classify likely 1C purpose."""
    if not re.fullmatch(r"[A-Za-z0-9_]+", table_name):
        raise ValueError("table_name must contain only letters, digits and underscore")
    if not re.fullmatch(r"[A-Za-z0-9_]+", schema):
        raise ValueError("schema must contain only letters, digits and underscore")
    query = f"""
select
  c.ordinal_position,
  c.column_name,
  c.data_type,
  c.udt_name,
  c.is_nullable,
  c.character_maximum_length
from information_schema.columns c
where c.table_schema = '{schema}'
  and c.table_name = '{table_name}'
order by c.ordinal_position
"""
    result = _run_sql(query, f"1C PostgreSQL describe {schema}.{table_name}", limit=500)
    result["table_family"] = _classify_1c_table(table_name)
    return result


@mcp.tool()
def pg_search_columns(pattern: str, limit: int = 200) -> dict[str, Any]:
    """Search columns by name across PostgreSQL tables."""
    safe_pattern = pattern.replace("'", "''")
    query = f"""
select
  table_schema,
  table_name,
  column_name,
  data_type,
  udt_name
from information_schema.columns
where table_schema not in ('pg_catalog', 'information_schema')
  and lower(column_name) like lower('%{safe_pattern}%')
order by table_schema, table_name, ordinal_position
limit {max(1, min(limit, 1000))}
"""
    return _run_sql(query, "1C PostgreSQL column search", limit=limit)


@mcp.tool()
def pg_readonly_query(sql_text: str, limit: int = 200) -> dict[str, Any]:
    """Run a read-only PostgreSQL query through the project read-only SQL runner."""
    return _run_sql(sql_text, "1C PostgreSQL read-only query", limit=limit)


@mcp.tool()
def com_list_metadata(alias: str, kind: str = "Catalogs", limit: int = 300) -> dict[str, Any]:
    """List metadata names through 1C COM for configured file/server aliases."""
    if IS_WSL:
        return {
            "ok": False,
            "returncode": -1,
            "stdout": "",
            "stderr": "COM is not available in WSL. Use PostgreSQL mode instead.",
            "alias": alias,
            "kind": kind,
            "count": 0,
            "names": [],
            "artifact": "",
        }
    if not re.fullmatch(r"[A-Za-z0-9_]+", alias):
        raise ValueError("alias must contain only letters, digits and underscore")
    if not re.fullmatch(r"[A-Za-z0-9_]+", kind):
        raise ValueError("kind must contain only letters, digits and underscore")
    WSL_LOG_ROOT.mkdir(parents=True, exist_ok=True)
    out_win = WINDOWS_LOG_ROOT + rf"\metadata_{alias}_{kind}.txt"
    out_wsl = WSL_LOG_ROOT / f"metadata_{alias}_{kind}.txt"
    cmd = [
        POWERSHELL,
        "-ExecutionPolicy",
        "Bypass",
        "-NoProfile",
        "-File",
        _powershell_path(COM_LIST_METADATA),
        "-Alias",
        alias,
        "-Kind",
        kind,
        "-Out",
        out_win,
    ]
    proc = _run(cmd, timeout=90)
    names: list[str] = []
    if out_wsl.exists():
        names = [line.strip() for line in out_wsl.read_text(encoding="utf-8", errors="ignore").splitlines() if line.strip()]
    return {
        "ok": proc.returncode == 0,
        "returncode": proc.returncode,
        "stdout": proc.stdout.strip(),
        "stderr": proc.stderr.strip(),
        "alias": alias,
        "kind": kind,
        "count": len(names),
        "names": names[: max(1, min(limit, 1000))],
        "artifact": str(out_wsl),
    }


@mcp.tool()
def com_probe_metadata(alias: str, kind: str, name: str) -> dict[str, Any]:
    """Probe one metadata object through 1C COM and return its requisites/tabular sections."""
    if IS_WSL:
        return {
            "ok": False,
            "returncode": -1,
            "stdout_lines": [],
            "stderr": "COM is not available in WSL. Use PostgreSQL mode instead.",
        }
    if not re.fullmatch(r"[A-Za-z0-9_]+", alias):
        raise ValueError("alias must contain only letters, digits and underscore")
    if not re.fullmatch(r"[A-Za-z0-9_]+", kind):
        raise ValueError("kind must contain only letters, digits and underscore")
    cmd = [
        POWERSHELL,
        "-ExecutionPolicy",
        "Bypass",
        "-NoProfile",
        "-File",
        _powershell_path(COM_PROBE_METADATA),
        "-Alias",
        alias,
        "-Kind",
        kind,
        "-Name",
        name,
    ]
    proc = _run(cmd, timeout=90)
    lines = [line.strip() for line in proc.stdout.splitlines() if line.strip()]
    return {
        "ok": proc.returncode == 0,
        "returncode": proc.returncode,
        "stdout_lines": lines,
        "stderr": proc.stderr.strip(),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Read-only MCP bridge for live 1C bases via PostgreSQL and COM")
    parser.parse_args()
    mcp.run()


if __name__ == "__main__":
    main()
