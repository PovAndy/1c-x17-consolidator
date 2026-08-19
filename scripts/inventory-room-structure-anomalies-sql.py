#!{PROJECT_ROOT}/.venv-sql/bin/python
from __future__ import annotations
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
import csv
import psycopg

ROOT = Path('{PROJECT_ROOT}')
ENV_PATH = ROOT / '.env'
LOG_DIR = ROOT / 'logs' / 'duplicates'
LOG_DIR.mkdir(parents=True, exist_ok=True)

SUSPICIOUS_CODES = ('000000267','000000268','000000269','000000270','000000271','000000272')
CORE_NAMES = ('Жилая площадь','Общая площадь')


@dataclass
class Row:
    code: str
    description: str
    marked: bool
    folder: bool
    ref_hex: str
    live_hits: int


def load_env(path: Path) -> dict[str, str]:
    env: dict[str, str] = {}
    for raw in path.read_text(encoding='utf-8').splitlines():
        line = raw.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        k, v = line.split('=', 1)
        env[k.strip()] = v.strip()
    return env


def connect():
    env = load_env(ENV_PATH)
    return psycopg.connect(
        host=env['EPF_SQL_RO_HOST'],
        port=int(env.get('EPF_SQL_RO_PORT', '5432')),
        dbname=env['EPF_SQL_RO_DB'],
        user=env['EPF_SQL_RO_USER'],
        password=env['EPF_SQL_RO_PWD'],
        connect_timeout=8,
    )


def fetch_rows(conn: psycopg.Connection, query: str, params: tuple) -> list[Row]:
    with conn.cursor() as cur:
        cur.execute(query, params)
        result: list[Row] = []
        for code, description, marked, folder, ref_hex, live_hits in cur.fetchall():
            result.append(Row(
                code=str(code),
                description=str(description),
                marked=bool(marked),
                folder=bool(folder),
                ref_hex=str(ref_hex),
                live_hits=int(live_hits),
            ))
        return result


def write_csv(path: Path, rows: list[Row]) -> None:
    with path.open('w', encoding='utf-8', newline='') as fh:
        writer = csv.writer(fh)
        writer.writerow(['code','description','marked','folder','ref_hex','live_hits'])
        for r in rows:
            writer.writerow([r.code, r.description, 'Да' if r.marked else 'Нет', 'Да' if r.folder else 'Нет', r.ref_hex, r.live_hits])


def write_md(path: Path, suspicious: list[Row], core: list[Row]) -> None:
    total_live_suspicious = sum(r.live_hits for r in suspicious)
    total_live_core = sum(r.live_hits for r in core)
    by_code: dict[str, int] = defaultdict(int)
    for r in suspicious:
        by_code[r.code] += r.live_hits

    lines: list[str] = []
    lines.append('# Room Structure Anomalies Inventory')
    lines.append('')
    lines.append(f'- Timestamp: `{datetime.now().isoformat(timespec="seconds")}`')
    lines.append('- Source: `x17_pg2` via SQL RO')
    lines.append(f'- suspicious codes checked: `{", ".join(SUSPICIOUS_CODES)}`')
    lines.append(f'- core names checked: `{", ".join(CORE_NAMES)}`')
    lines.append('')
    lines.append('## Summary')
    lines.append('')
    lines.append(f'- suspicious rows: `{len(suspicious)}`')
    lines.append(f'- suspicious live hits total: `{total_live_suspicious}`')
    lines.append(f'- core duplicate rows: `{len(core)}`')
    lines.append(f'- core duplicate live hits total: `{total_live_core}`')
    if by_code:
        lines.append('- suspicious live hits by code:')
        for code in sorted(by_code):
            lines.append(f'  - `{code}` -> `{by_code[code]}`')
    lines.append('')

    lines.append('## Suspicious Codes 267..272')
    lines.append('')
    if not suspicious:
        lines.append('_No rows found_')
    else:
        lines.append('| code | description | marked | folder | live_hits | ref_hex |')
        lines.append('| --- | --- | --- | --- | --- | --- |')
        for r in suspicious:
            lines.append(f'| {r.code} | {r.description} | {"Да" if r.marked else "Нет"} | {"Да" if r.folder else "Нет"} | {r.live_hits} | {r.ref_hex} |')
    lines.append('')

    lines.append('## Core Living-Area Duplicates')
    lines.append('')
    if not core:
        lines.append('_No rows found_')
    else:
        lines.append('| code | description | marked | folder | live_hits | ref_hex |')
        lines.append('| --- | --- | --- | --- | --- | --- |')
        for r in core:
            lines.append(f'| {r.code} | {r.description} | {"Да" if r.marked else "Нет"} | {"Да" if r.folder else "Нет"} | {r.live_hits} | {r.ref_hex} |')
    lines.append('')
    path.write_text('\n'.join(lines) + '\n', encoding='utf-8')


def main() -> int:
    suspicious_query = """
with targets as (
    select _idrref, _code, _description, _marked, _folder
    from _chrc2105
    where _code = any(%s)
), hits as (
    select _fld36813rref as ref, count(*)::bigint as hit_cnt
    from _inforg36811
    where _active
    group by _fld36813rref
)
select t._code, t._description, t._marked, t._folder, encode(t._idrref,'hex') as ref_hex, coalesce(h.hit_cnt,0) as live_hits
from targets t
left join hits h on h.ref = t._idrref
order by t._code, t._description
"""
    core_query = """
with targets as (
    select _idrref, _code, _description, _marked, _folder
    from _chrc2105
    where _description = any(%s)
), hits as (
    select _fld36813rref as ref, count(*)::bigint as hit_cnt
    from _inforg36811
    where _active
    group by _fld36813rref
)
select t._code, t._description, t._marked, t._folder, encode(t._idrref,'hex') as ref_hex, coalesce(h.hit_cnt,0) as live_hits
from targets t
left join hits h on h.ref = t._idrref
order by t._description, t._code, t._marked
"""

    with connect() as conn:
        suspicious = fetch_rows(conn, suspicious_query, (list(SUSPICIOUS_CODES),))
        core = fetch_rows(conn, core_query, (list(CORE_NAMES),))

    ts = datetime.now().strftime('%Y%m%d_%H%M%S')
    md = LOG_DIR / f'room_structure_anomalies_{ts}.md'
    csv_susp = LOG_DIR / f'room_structure_anomalies_suspicious_{ts}.csv'
    csv_core = LOG_DIR / f'room_structure_anomalies_core_{ts}.csv'
    write_md(md, suspicious, core)
    write_csv(csv_susp, suspicious)
    write_csv(csv_core, core)
    print(md)
    print(csv_susp)
    print(csv_core)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
