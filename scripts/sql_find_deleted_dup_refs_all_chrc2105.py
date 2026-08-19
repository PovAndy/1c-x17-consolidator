#!{PROJECT_ROOT}/.venv-sql/bin/python
from __future__ import annotations

from datetime import datetime
from pathlib import Path
import csv
import psycopg

ROOT = Path('{PROJECT_ROOT}')
ENV_PATH = ROOT / '.env'
LOG_DIR = ROOT / 'logs' / 'sql'
LOG_DIR.mkdir(parents=True, exist_ok=True)


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


def q(cur, sql: str, params=None):
    cur.execute(sql, params or ())
    return cur.fetchall()


def main() -> int:
    ts = datetime.now().strftime('%Y%m%d_%H%M%S')
    md_path = LOG_DIR / f'deleted_dup_all_refs_chrc2105_{ts}.md'
    csv_path = LOG_DIR / f'deleted_dup_all_refs_chrc2105_{ts}.csv'

    with connect() as conn:
        with conn.cursor() as cur:
            dup_rows = q(cur, """
                SELECT _idrref, _description, _code
                FROM public._chrc2105
                WHERE _marked = true AND _description LIKE '[ДУБЛЬ] %%'
                ORDER BY _description, _code
            """)
            ids = [row[0] for row in dup_rows]
            if not ids:
                md_path.write_text('# Deleted duplicate refs all tables\n\nNo deleted [ДУБЛЬ] refs found in _chrc2105.\n', encoding='utf-8')
                with csv_path.open('w', encoding='utf-8', newline='') as fh:
                    csv.writer(fh).writerow(['table', 'column', 'hit_count'])
                print(md_path)
                return 0

            cols = q(cur, """
                SELECT table_name, column_name
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND udt_name = 'bytea'
                  AND column_name ILIKE '%%rref'
                ORDER BY table_name, column_name
            """)

            hits: list[tuple[str, str, int]] = []
            for idx, (table_name, column_name) in enumerate(cols, start=1):
                sql = f'SELECT count(*)::bigint FROM public."{table_name}" WHERE "{column_name}" = ANY(%s)'
                cur.execute(sql, (ids,))
                cnt = cur.fetchone()[0]
                if cnt and cnt > 0:
                    hits.append((table_name, column_name, int(cnt)))
                if idx % 250 == 0:
                    print(f'progress {idx}/{len(cols)}', flush=True)

    with csv_path.open('w', encoding='utf-8', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['table', 'column', 'hit_count'])
        w.writerows(hits)

    lines = [
        '# Deleted duplicate refs in all public bytea-rref columns',
        '',
        f'- Timestamp: `{datetime.now().isoformat(timespec="seconds")}`',
        f'- Deleted refs scanned: `{len(ids)}`',
        f'- Candidate columns scanned: `{len(cols)}`',
        f'- Hit columns: `{len(hits)}`',
        '',
        '## Hits',
        ''
    ]
    if hits:
        lines.append('| table | column | hit_count |')
        lines.append('| --- | --- | ---: |')
        for row in hits:
            lines.append(f'| {row[0]} | {row[1]} | {row[2]} |')
    else:
        lines.append('_No hits found_')
    lines.append('')
    lines.append(f'- CSV: `{csv_path}`')
    md_path.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(md_path)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
