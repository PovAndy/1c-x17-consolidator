#!{PROJECT_ROOT}/.venv-sql/bin/python
from __future__ import annotations
from pathlib import Path
from datetime import datetime
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
    md_path = LOG_DIR / f'deleted_dup_ref_usage_{ts}.md'
    csv_path = LOG_DIR / f'deleted_dup_ref_usage_{ts}.csv'
    sample_path = LOG_DIR / f'deleted_dup_ref_usage_samples_{ts}.csv'

    with connect() as conn:
        with conn.cursor() as cur:
            dup_rows = q(cur, """
                SELECT '_chrc2105' AS source_table, _idrref, _description, _code
                FROM public._chrc2105
                WHERE _marked = true AND _description LIKE '[ДУБЛЬ] %%'
                UNION ALL
                SELECT '_chrc2106' AS source_table, _idrref, _description, _code
                FROM public._chrc2106
                WHERE _marked = true AND _description LIKE '[ДУБЛЬ] %%'
                ORDER BY 1, 3, 4
            """)
            ids = [row[1] for row in dup_rows]
            if not ids:
                md_path.write_text('# Deleted duplicate ref usage\n\nNo deleted [ДУБЛЬ] refs found.\n', encoding='utf-8')
                with csv_path.open('w', encoding='utf-8', newline='') as fh:
                    csv.writer(fh).writerow(['schema', 'table', 'column', 'hit_count'])
                with sample_path.open('w', encoding='utf-8', newline='') as fh:
                    csv.writer(fh).writerow(['schema', 'table', 'column', 'sample_ref'])
                print(md_path)
                return 0

            cols = q(cur, """
                SELECT table_schema, table_name, column_name
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND udt_name = 'bytea'
                  AND column_name LIKE '%%rref'
                ORDER BY table_name, column_name
            """)

            hits = []
            samples = []
            for schema_name, table_name, column_name in cols:
                sql = f'SELECT count(*)::bigint FROM {schema_name}."{table_name}" WHERE "{column_name}" = ANY(%s)'
                cur.execute(sql, (ids,))
                cnt = cur.fetchone()[0]
                if cnt and cnt > 0:
                    hits.append((schema_name, table_name, column_name, cnt))
                    sql2 = f'''SELECT encode("{column_name}", 'hex') AS sample_ref
                               FROM {schema_name}."{table_name}"
                               WHERE "{column_name}" = ANY(%s)
                               LIMIT 5'''
                    cur.execute(sql2, (ids,))
                    for row in cur.fetchall():
                        samples.append((schema_name, table_name, column_name, row[0]))

    with csv_path.open('w', encoding='utf-8', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['schema', 'table', 'column', 'hit_count'])
        w.writerows(hits)

    with sample_path.open('w', encoding='utf-8', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['schema', 'table', 'column', 'sample_ref'])
        w.writerows(samples)

    lines = ['# Deleted duplicate ref usage', '', f'- Timestamp: `{datetime.now().isoformat(timespec="seconds")}`', f'- Deleted refs scanned: `{len(ids)}`', f'- Hit columns: `{len(hits)}`', '']
    lines.append('## Hit columns')
    lines.append('')
    if hits:
        lines.append('| schema | table | column | hit_count |')
        lines.append('| --- | --- | --- | ---: |')
        for row in hits:
            lines.append(f'| {row[0]} | {row[1]} | {row[2]} | {row[3]} |')
    else:
        lines.append('_No referencing columns found_')
    lines.append('')
    lines.append(f'- CSV: `{csv_path}`')
    lines.append(f'- Samples: `{sample_path}`')
    md_path.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(md_path)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
