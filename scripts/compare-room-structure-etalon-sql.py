#!{PROJECT_ROOT}/.venv-sql/bin/python
from __future__ import annotations
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
import argparse
import csv
import re
import psycopg

ROOT = Path('{PROJECT_ROOT}')
ENV_PATH = ROOT / '.env'
LOG_DIR = ROOT / 'logs' / 'duplicates'
LOG_DIR.mkdir(parents=True, exist_ok=True)

DEFAULT_ETALON = Path('/mnt/t/1S/wsl_exchange/work_epf_112_9/context/recovery/ls-structure/out/pvh_obj_viewtype_etalon_current.csv')


@dataclass
class Row:
    code: str
    description: str
    ref_hex: str
    live_hits: int
    folder: bool
    marked: bool
    parent_code: str
    parent_name: str


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


def norm_text(text: str) -> str:
    s = text.lower().replace('ё', 'е')
    s = re.sub(r"[\"'`]+", ' ', s)
    s = re.sub(r"[()\[\]{}]+", ' ', s)
    s = re.sub(r"[_\-]+", ' ', s)
    s = re.sub(r"\s+", ' ', s)
    return s.strip()


def load_etalon(path: Path) -> set[str]:
    etalon: set[str] = set()
    with path.open('r', encoding='utf-8') as fh:
        reader = csv.DictReader(fh, delimiter=';')
        for row in reader:
            name_norm = (row.get('char_name_normalized') or '').strip()
            if not name_norm:
                name = (row.get('char_name') or '').strip()
                if name:
                    name_norm = norm_text(name)
            if name_norm:
                etalon.add(name_norm)
    return etalon


def fetch_rows(conn: psycopg.Connection) -> list[Row]:
    query = """
with hits as (
    select _fld36813rref as ref, count(*)::bigint as hit_cnt
    from _inforg36811
    where _active
    group by _fld36813rref
)
select c._code, c._description, encode(c._idrref,'hex') as ref_hex,
       h.hit_cnt, c._folder, c._marked,
       p._code as parent_code, p._description as parent_name
from _chrc2105 c
left join _chrc2105 p on p._idrref = c._parentidrref
join hits h on h.ref = c._idrref
where c._marked = false and c._folder = true
order by h.hit_cnt desc, c._code, c._description
"""
    rows: list[Row] = []
    with conn.cursor() as cur:
        cur.execute(query)
        for code, description, ref_hex, hit_cnt, folder, marked, parent_code, parent_name in cur.fetchall():
            rows.append(Row(
                code=str(code),
                description=str(description),
                ref_hex=str(ref_hex),
                live_hits=int(hit_cnt),
                folder=bool(folder),
                marked=bool(marked),
                parent_code=str(parent_code) if parent_code is not None else '',
                parent_name=str(parent_name) if parent_name is not None else '',
            ))
    return rows


def is_system_group(parent_name: str) -> bool:
    name = parent_name.lower()
    return 'гис жкх' in name or 'гцжс' in name


def write_csv(path: Path, rows: list[Row], etalon: set[str]) -> None:
    with path.open('w', encoding='utf-8', newline='') as fh:
        writer = csv.writer(fh)
        writer.writerow(['code','description','description_norm','in_etalon','system_group','parent_code','parent_name','live_hits','ref_hex'])
        for r in rows:
            n = norm_text(r.description)
            writer.writerow([
                r.code,
                r.description,
                n,
                'Да' if n in etalon else 'Нет',
                'Да' if is_system_group(r.parent_name) else 'Нет',
                r.parent_code,
                r.parent_name,
                r.live_hits,
                r.ref_hex,
            ])


def write_md(path: Path, rows: list[Row], etalon: set[str]) -> None:
    total = len(rows)
    foreign = [r for r in rows if norm_text(r.description) not in etalon]
    foreign_non_system = [r for r in foreign if not is_system_group(r.parent_name)]
    lines: list[str] = []
    lines.append('# Room Structure Etalon Diff (folders only)')
    lines.append('')
    lines.append(f'- Timestamp: `{datetime.now().isoformat(timespec="seconds")}`')
    lines.append('- Source: `x17_pg2` via SQL RO')
    lines.append(f'- Etalon: `{DEFAULT_ETALON}`')
    lines.append('')
    lines.append('## Summary')
    lines.append('')
    lines.append(f'- total active folder rows with hits: `{total}`')
    lines.append(f'- not in etalon: `{len(foreign)}`')
    lines.append(f'- not in etalon and not in system group: `{len(foreign_non_system)}`')
    lines.append('')

    lines.append('## Foreign folder rows (not in etalon)')
    lines.append('')
    if not foreign:
        lines.append('_No foreign folder rows found_')
    else:
        lines.append('| code | description | parent_name | system_group | live_hits | ref_hex |')
        lines.append('| --- | --- | --- | --- | --- | --- |')
        for r in foreign:
            lines.append(
                f'| {r.code} | {r.description} | {r.parent_name} | {"Да" if is_system_group(r.parent_name) else "Нет"} | {r.live_hits} | {r.ref_hex} |'
            )
    lines.append('')

    lines.append('## All folder rows (top 40 by hits)')
    lines.append('')
    lines.append('| code | description | in_etalon | system_group | live_hits |')
    lines.append('| --- | --- | --- | --- | --- |')
    for r in rows[:40]:
        lines.append(
            f'| {r.code} | {r.description} | {"Да" if norm_text(r.description) in etalon else "Нет"} | {"Да" if is_system_group(r.parent_name) else "Нет"} | {r.live_hits} |'
        )
    lines.append('')

    path.write_text('\n'.join(lines) + '\n', encoding='utf-8')


def main() -> int:
    parser = argparse.ArgumentParser(description='Compare x17 room structure folders against etalon names')
    parser.add_argument('--etalon', type=Path, default=DEFAULT_ETALON)
    args = parser.parse_args()
    if not args.etalon.exists():
        raise SystemExit(f'Etalon file not found: {args.etalon}')

    etalon = load_etalon(args.etalon)
    with connect() as conn:
        rows = fetch_rows(conn)

    ts = datetime.now().strftime('%Y%m%d_%H%M%S')
    md = LOG_DIR / f'room_structure_etalon_diff_{ts}.md'
    csv_path = LOG_DIR / f'room_structure_etalon_diff_{ts}.csv'
    write_md(md, rows, etalon)
    write_csv(csv_path, rows, etalon)
    print(md)
    print(csv_path)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
