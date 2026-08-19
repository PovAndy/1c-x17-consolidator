#!{PROJECT_ROOT}/.venv-sql/bin/python
from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
import csv
import json
import argparse

import psycopg

ROOT = Path('{PROJECT_ROOT}')
ENV_PATH = ROOT / '.env'
LOG_DIR = ROOT / 'logs' / 'duplicates'
LOG_DIR.mkdir(parents=True, exist_ok=True)

PVH_TABLES = {
    '_chrc2105': 'икХарактеристикиОбъектовУчета',
    '_chrc2106': 'икХарактеристикиПрочихОбъектов',
}

FOCUSED_COLUMNS = {
    '_chrc2105': [('_inforg36811', '_fld36813rref')],
    '_chrc2106': [('_inforg36817', '_fld36819rref')],
}


@dataclass
class PvhRow:
    source_table: str
    pvh_name: str
    ref: bytes
    ref_hex: str
    description: str
    code: str
    marked: bool


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


def sanitize_cell(value) -> str:
    if value is None:
        return ''
    return str(value).replace('\n', ' ').replace('\r', ' ')


def classify_group(active_count: int, ref_hits: int) -> str:
    if active_count > 1 and ref_hits > 0:
        return 'unsafe_live'
    if active_count > 1:
        return 'live_no_refs'
    if ref_hits > 0:
        return 'tail_with_refs'
    return 'tail_no_refs'


def fetch_duplicate_groups(cur, source_filter: str | None) -> tuple[dict[str, list[PvhRow]], list[bytes]]:
    groups: dict[str, list[PvhRow]] = defaultdict(list)
    active_ids: list[bytes] = []
    items = PVH_TABLES.items()
    if source_filter:
        items = [(source_filter, PVH_TABLES[source_filter])]
    for table_name, pvh_name in items:
        cur.execute(
            f"""
            WITH dup_names AS (
                SELECT _description
                FROM public."{table_name}"
                GROUP BY _description
                HAVING count(*) > 1
            )
            SELECT encode(x._idrref, 'hex') AS ref_hex,
                   x._idrref,
                   x._description,
                   x._code,
                   x._marked
            FROM public."{table_name}" x
            JOIN dup_names d ON d._description = x._description
            ORDER BY x._description, x._marked, x._code
            """
        )
        for ref_hex, ref, description, code, marked in cur.fetchall():
            row = PvhRow(
                source_table=table_name,
                pvh_name=pvh_name,
                ref=ref,
                ref_hex=ref_hex,
                description=description,
                code=code,
                marked=bool(marked),
            )
            key = f'{table_name}|{description}'
            groups[key].append(row)
            if not row.marked:
                active_ids.append(ref)
    return groups, active_ids


def fetch_candidate_columns(
    cur,
    scope: str,
    source_filter: str | None,
    table_like: str | None = None,
) -> list[tuple[str, str]]:
    if scope == 'focused':
        columns: list[tuple[str, str]] = []
        sources = [source_filter] if source_filter else list(FOCUSED_COLUMNS)
        for source in sources:
            columns.extend(FOCUSED_COLUMNS.get(source, []))
        return columns
    where_parts = [
        "table_schema = 'public'",
        "udt_name = 'bytea'",
        "column_name ILIKE %s",
    ]
    params: list[object] = ['%rref']
    if scope == 'inforg':
        where_parts.append("table_name LIKE %s")
        params.append('_inforg%')
    if table_like:
        where_parts.append("table_name ILIKE %s")
        params.append(table_like)
    cur.execute(
        f"""
        SELECT table_name, column_name
        FROM information_schema.columns
        WHERE {' AND '.join(where_parts)}
        ORDER BY table_name, column_name
        """,
        params,
    )
    return [(r[0], r[1]) for r in cur.fetchall()]


def scan_references(
    cur,
    active_ids: list[bytes],
    scope: str,
    source_filter: str | None,
    table_like: str | None,
    offset_columns: int,
    limit_columns: int,
    progress_every: int,
) -> tuple[dict[str, list[tuple[str, str, int]]], int, int]:
    by_ref: dict[str, list[tuple[str, str, int]]] = defaultdict(list)
    if not active_ids:
        return by_ref, 0, 0
    candidate_columns = fetch_candidate_columns(cur, scope, source_filter, table_like)
    total_candidates = len(candidate_columns)
    start = max(0, offset_columns)
    end = total_candidates if limit_columns <= 0 else min(total_candidates, start + limit_columns)
    candidate_columns = candidate_columns[start:end]
    ref_set = set(active_ids)
    for idx, (table_name, column_name) in enumerate(candidate_columns, start=1):
        sql = f'''
            SELECT encode("{column_name}", 'hex') AS ref_hex, count(*)::bigint AS cnt
            FROM public."{table_name}"
            WHERE "{column_name}" = ANY(%s)
            GROUP BY "{column_name}"
        '''
        cur.execute(sql, (list(ref_set),))
        for ref_hex, cnt in cur.fetchall():
            by_ref[ref_hex].append((table_name, column_name, int(cnt)))
        if progress_every > 0 and idx % progress_every == 0:
            print(
                f'[scan] {scope}: local {idx}/{len(candidate_columns)} columns '
                f'(global {start + idx}/{total_candidates})',
                flush=True,
            )
    return by_ref, total_candidates, len(candidate_columns)


def write_csv(path: Path, header: list[str], rows: list[list[object]]) -> None:
    with path.open('w', encoding='utf-8', newline='') as fh:
        writer = csv.writer(fh)
        writer.writerow(header)
        writer.writerows(rows)


def render_md(path: Path, summary_rows: list[list[object]], detail_rows: list[list[object]], hit_rows: list[list[object]]) -> None:
    lines = [
        '# Live PVH Duplicate Inventory',
        '',
        f'- Timestamp: `{datetime.now().isoformat(timespec="seconds")}`',
        '',
        '## Summary',
        '',
    ]
    if summary_rows:
        lines.append('| ПВХ | Наименование | Всего | Активных | Помеченных | HitColumns | RefHits | Risk |')
        lines.append('| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |')
        for row in summary_rows:
            lines.append('| ' + ' | '.join(sanitize_cell(v) for v in row) + ' |')
    else:
        lines.append('_Duplicate groups not found_')
    lines.extend(['', '## Detail', ''])
    if detail_rows:
        lines.append('| ПВХ | Наименование | Код | ПометкаУдаления | СсылкаHex |')
        lines.append('| --- | --- | --- | --- | --- |')
        for row in detail_rows:
            lines.append('| ' + ' | '.join(sanitize_cell(v) for v in row) + ' |')
    else:
        lines.append('_No detail rows_')
    lines.extend(['', '## Reference Hits', ''])
    if hit_rows:
        lines.append('| ПВХ | Наименование | Код | Таблица | Поле | HitCount |')
        lines.append('| --- | --- | --- | --- | --- | ---: |')
        for row in hit_rows:
            lines.append('| ' + ' | '.join(sanitize_cell(v) for v in row) + ' |')
    else:
        lines.append('_No live reference hits found_')
    path.write_text('\n'.join(lines) + '\n', encoding='utf-8')


def main() -> int:
    parser = argparse.ArgumentParser(description='Inventory live duplicate groups in PVH tables')
    parser.add_argument('--scope', choices=('focused', 'inforg', 'all'), default='focused')
    parser.add_argument('--source', choices=tuple(PVH_TABLES.keys()))
    parser.add_argument('--table-like', help='Optional ILIKE filter for candidate table names, e.g. _inforg368%%')
    parser.add_argument('--offset-columns', type=int, default=0, help='Zero-based candidate-column offset for chunked scans')
    parser.add_argument('--limit-columns', type=int, default=0, help='Maximum number of candidate columns to scan; 0 means all from offset')
    parser.add_argument('--statement-timeout-ms', type=int, default=0, help='Optional PostgreSQL statement_timeout in milliseconds')
    parser.add_argument('--progress-every', type=int, default=250, help='Emit progress every N scanned columns; 0 disables progress output')
    args = parser.parse_args()
    ts = datetime.now().strftime('%Y%m%d_%H%M%S')
    suffix = args.scope if not args.source else f'{args.scope}_{args.source}'
    if args.table_like:
        safe_like = args.table_like.replace('%', 'pct').replace('_', 'u')
        suffix += f'_{safe_like}'
    if args.offset_columns or args.limit_columns:
        suffix += f'_off{args.offset_columns}_lim{args.limit_columns}'
    md_path = LOG_DIR / f'live_pvh_duplicates_{suffix}_{ts}.md'
    summary_csv = LOG_DIR / f'live_pvh_duplicates_summary_{suffix}_{ts}.csv'
    detail_csv = LOG_DIR / f'live_pvh_duplicates_detail_{suffix}_{ts}.csv'
    hits_csv = LOG_DIR / f'live_pvh_duplicates_hits_{suffix}_{ts}.csv'

    with connect() as conn:
        with conn.cursor() as cur:
            if args.statement_timeout_ms > 0:
                cur.execute(f"SET statement_timeout = {int(args.statement_timeout_ms)}")
            groups, active_ids = fetch_duplicate_groups(cur, args.source)
            ref_hits, total_candidates, scanned_candidates = scan_references(
                cur,
                active_ids,
                args.scope,
                args.source,
                args.table_like,
                args.offset_columns,
                args.limit_columns,
                args.progress_every,
            )

    summary_rows: list[list[object]] = []
    detail_rows: list[list[object]] = []
    hit_rows: list[list[object]] = []

    for key in sorted(groups, key=lambda k: (groups[k][0].pvh_name, groups[k][0].description.lower())):
        rows = groups[key]
        pvh_name = rows[0].pvh_name
        description = rows[0].description
        active_rows = [r for r in rows if not r.marked]
        deleted_rows = [r for r in rows if r.marked]
        group_hits = 0
        group_hit_cols = 0
        for row in active_rows:
            hits = ref_hits.get(row.ref_hex, [])
            group_hits += sum(cnt for _, _, cnt in hits)
            group_hit_cols += len(hits)
            for table_name, column_name, cnt in sorted(hits, key=lambda item: (-item[2], item[0], item[1])):
                hit_rows.append([pvh_name, description, row.code, table_name, column_name, cnt])
        summary_rows.append([
            pvh_name,
            description,
            len(rows),
            len(active_rows),
            len(deleted_rows),
            group_hit_cols,
            group_hits,
            classify_group(len(active_rows), group_hits),
        ])
        for row in rows:
            detail_rows.append([pvh_name, description, row.code, 'Да' if row.marked else 'Нет', row.ref_hex])

    write_csv(summary_csv, ['pvh_name', 'description', 'total', 'active', 'deleted', 'hit_columns', 'ref_hits', 'risk'], summary_rows)
    write_csv(detail_csv, ['pvh_name', 'description', 'code', 'marked', 'ref_hex'], detail_rows)
    write_csv(hits_csv, ['pvh_name', 'description', 'code', 'table_name', 'column_name', 'hit_count'], hit_rows)
    render_md(md_path, summary_rows, detail_rows, hit_rows)

    print(json.dumps({
        'md': str(md_path),
        'summary_csv': str(summary_csv),
        'detail_csv': str(detail_csv),
        'hits_csv': str(hits_csv),
        'scope': args.scope,
        'source': args.source,
        'table_like': args.table_like,
        'offset_columns': args.offset_columns,
        'limit_columns': args.limit_columns,
        'total_candidate_columns': total_candidates,
        'scanned_candidate_columns': scanned_candidates,
        'groups': len(summary_rows),
        'hit_rows': len(hit_rows),
    }, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
