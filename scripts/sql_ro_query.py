#!{PROJECT_ROOT}/.venv-sql/bin/python
from __future__ import annotations
from datetime import datetime
from pathlib import Path
import argparse
import csv
import json
import re
import sys

try:
    import psycopg
except ModuleNotFoundError:
    psycopg = None

try:
    import psycopg2
except ModuleNotFoundError:
    psycopg2 = None

ROOT = Path('{PROJECT_ROOT}')
ENV_PATH = ROOT / '.env'
LOG_DIR = ROOT / 'logs' / 'sql'
LOG_DIR.mkdir(parents=True, exist_ok=True)
ALLOWED_PREFIXES = ('select', 'with', 'explain')
BLOCKED_TOKENS = {
    'insert', 'update', 'delete', 'truncate', 'alter', 'drop', 'create',
    'grant', 'revoke', 'comment', 'vacuum', 'analyze', 'refresh', 'reindex',
    'cluster', 'copy', 'call', 'do'
}


def load_env(path: Path) -> dict[str, str]:
    env: dict[str, str] = {}
    for raw in path.read_text(encoding='utf-8').splitlines():
        line = raw.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        k, v = line.split('=', 1)
        env[k.strip()] = v.strip()
    return env


def normalize_sql(sql_text: str) -> str:
    return re.sub(r'--.*?$', '', sql_text, flags=re.M).strip()


def ensure_read_only(sql_text: str) -> None:
    normalized = normalize_sql(sql_text)
    low = normalized.lower()
    if not low.startswith(ALLOWED_PREFIXES):
        raise ValueError('Only SELECT/WITH/EXPLAIN queries are allowed')
    tokens = set(re.findall(r'[a-z_]+', low))
    blocked_found = sorted(tok for tok in BLOCKED_TOKENS if tok in tokens)
    if blocked_found:
        raise ValueError('Blocked SQL tokens detected: ' + ', '.join(blocked_found))


def fetch_rows(query: str, limit: int | None) -> tuple[list[str], list[tuple]]:
    env = load_env(ENV_PATH)
    conninfo = {
        'host': env['EPF_SQL_RO_HOST'],
        'port': int(env.get('EPF_SQL_RO_PORT', '5432')),
        'dbname': env['EPF_SQL_RO_DB'],
        'user': env['EPF_SQL_RO_USER'],
        'password': env['EPF_SQL_RO_PWD'],
        'connect_timeout': 8,
    }
    if psycopg is not None:
        with psycopg.connect(**conninfo) as conn:
            conn.execute('SET TRANSACTION READ ONLY')
            conn.execute("SET LOCAL statement_timeout = '30s'")
            with conn.cursor() as cur:
                cur.execute(query)
                cols = [d.name for d in cur.description] if cur.description else []
                rows = cur.fetchall() if cur.description else []
                if limit is not None:
                    rows = rows[:limit]
                return cols, rows

    if psycopg2 is None:
        raise ModuleNotFoundError('Neither psycopg nor psycopg2 is installed in the active Python environment')

    with psycopg2.connect(**conninfo) as conn:
        conn.set_session(readonly=True, autocommit=False)
        with conn.cursor() as cur:
            cur.execute("SET LOCAL statement_timeout = '30s'")
            cur.execute(query)
            cols = [d[0] for d in cur.description] if cur.description else []
            rows = cur.fetchall() if cur.description else []
            if limit is not None:
                rows = rows[:limit]
            return cols, rows


def render_md(title: str, query: str, cols: list[str], rows: list[tuple], report_path: Path) -> None:
    lines = [f'# {title}', '', f'- Timestamp: `{datetime.now().isoformat(timespec="seconds")}`', '']
    lines.append('## Query')
    lines.append('')
    lines.append('```sql')
    lines.append(query.strip())
    lines.append('```')
    lines.append('')
    lines.append(f'## Result ({len(rows)} rows)')
    lines.append('')
    if not cols:
        lines.append('_No result set_')
    elif not rows:
        lines.append('_Empty result_')
    else:
        lines.append('| ' + ' | '.join(cols) + ' |')
        lines.append('| ' + ' | '.join(['---'] * len(cols)) + ' |')
        for row in rows:
            cells = [str(v).replace('\n', ' ') if v is not None else '' for v in row]
            lines.append('| ' + ' | '.join(cells) + ' |')
    report_path.write_text('\n'.join(lines) + '\n', encoding='utf-8')


def write_csv(cols: list[str], rows: list[tuple], csv_path: Path) -> None:
    with csv_path.open('w', encoding='utf-8', newline='') as fh:
        writer = csv.writer(fh)
        if cols:
            writer.writerow(cols)
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser(description='Run read-only SQL diagnostics against MergedBase')
    parser.add_argument('--file', help='Path to .sql file')
    parser.add_argument('--query', help='Inline SQL query')
    parser.add_argument('--title', default='SQL RO Query')
    parser.add_argument('--limit', type=int, default=200)
    args = parser.parse_args()
    if bool(args.file) == bool(args.query):
        print('Specify exactly one of --file or --query', file=sys.stderr)
        return 2
    if args.file:
        query = Path(args.file).read_text(encoding='utf-8')
        base = Path(args.file).stem
    else:
        query = args.query
        base = 'inline'
    ensure_read_only(query)
    cols, rows = fetch_rows(query, args.limit)
    ts = datetime.now().strftime('%Y%m%d_%H%M%S')
    md_path = LOG_DIR / f'{base}_{ts}.md'
    csv_path = LOG_DIR / f'{base}_{ts}.csv'
    render_md(args.title, query, cols, rows, md_path)
    write_csv(cols, rows, csv_path)
    print(json.dumps({'md': str(md_path), 'csv': str(csv_path), 'rows': len(rows)}, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
