#!{PROJECT_ROOT}/.venv-sql/bin/python
from __future__ import annotations
from datetime import datetime
from pathlib import Path
import psycopg
from psycopg import sql

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


def main() -> int:
    env = load_env(ENV_PATH)
    conninfo = {
        'host': env['EPF_SQL_RO_HOST'],
        'port': int(env.get('EPF_SQL_RO_PORT', '5432')),
        'dbname': env['EPF_SQL_RO_DB'],
        'user': env['EPF_SQL_RO_USER'],
        'password': env['EPF_SQL_RO_PWD'],
        'connect_timeout': 8,
    }
    schema = env.get('EPF_SQL_RO_SCHEMA', 'public')
    ts = datetime.now().strftime('%Y%m%d_%H%M%S')
    report_path = LOG_DIR / f'sql_ro_probe_{ts}.md'
    lines: list[str] = []
    lines.append('# SQL RO Probe')
    lines.append('')
    lines.append(f'- Timestamp: `{datetime.now().isoformat(timespec="seconds")}`')
    lines.append(f'- Host: `{conninfo["host"]}`')
    lines.append(f'- Port: `{conninfo["port"]}`')
    lines.append(f'- Database: `{conninfo["dbname"]}`')
    lines.append(f'- Schema: `{schema}`')
    lines.append(f'- User: `{conninfo["user"]}`')
    lines.append('')
    try:
        with psycopg.connect(**conninfo) as conn:
            with conn.cursor() as cur:
                cur.execute('select current_user, current_database(), inet_server_addr()::text, inet_server_port(), version()')
                current_user, current_db, server_addr, server_port, version = cur.fetchone()
                lines.append('## Connection')
                lines.append('')
                lines.append(f'- current_user: `{current_user}`')
                lines.append(f'- current_database: `{current_db}`')
                lines.append(f'- server_addr: `{server_addr}`')
                lines.append(f'- server_port: `{server_port}`')
                lines.append(f'- version: `{version}`')
                lines.append('')

                cur.execute('select count(*) from information_schema.tables where table_schema = %s', (schema,))
                table_count = cur.fetchone()[0]
                lines.append('## Schema Summary')
                lines.append('')
                lines.append(f'- tables_in_schema: `{table_count}`')
                lines.append('')

                cur.execute('select table_name from information_schema.tables where table_schema = %s order by table_name limit 30', (schema,))
                table_names = [r[0] for r in cur.fetchall()]
                lines.append('## First Tables')
                lines.append('')
                for name in table_names:
                    lines.append(f'- `{name}`')
                lines.append('')

                tested_table = None
                tested_count = None
                for name in table_names:
                    try:
                        cur.execute(sql.SQL('select count(*) from {}.{}').format(sql.Identifier(schema), sql.Identifier(name)))
                        tested_count = cur.fetchone()[0]
                        tested_table = name
                        break
                    except Exception:
                        conn.rollback()
                        continue
                lines.append('## Read Test')
                lines.append('')
                if tested_table is None:
                    lines.append('- no readable table found in first sample')
                else:
                    lines.append(f'- tested_table: `{tested_table}`')
                    lines.append(f'- row_count: `{tested_count}`')
                lines.append('')

                cur.execute("""
                    select n.nspname, c.relname, c.relkind
                    from pg_class c
                    join pg_namespace n on n.oid = c.relnamespace
                    where n.nspname = %s
                      and c.relkind in ('r','v','m')
                    order by pg_total_relation_size(c.oid) desc nulls last
                    limit 10
                """, (schema,))
                lines.append('## Largest Relations')
                lines.append('')
                for nsp, rel, kind in cur.fetchall():
                    lines.append(f'- `{nsp}.{rel}` kind=`{kind}`')
                lines.append('')
    except Exception as exc:
        lines.append('## Error')
        lines.append('')
        lines.append(f'- `{type(exc).__name__}: {exc}`')
        report_path.write_text('\n'.join(lines) + '\n', encoding='utf-8')
        print(report_path)
        return 1

    report_path.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(report_path)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
