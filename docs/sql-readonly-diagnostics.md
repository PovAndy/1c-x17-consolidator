# SQL Read-only Diagnostics

## Purpose
Direct read-only diagnostics against `MergedBase` for fast verification of facts in the copied x17 database.

## Safety
- Use this channel only for `SELECT`/`WITH`/`EXPLAIN`.
- No fixes through SQL.
- All corrections still go through 1C and the EPF processing.
- Prefer narrow predicates and staged diagnostics over broad table scans.
- Treat SQL as a facts channel, not as a replacement for 1C business logic.

## Environment
Configured in `.env`:
- `EPF_SQL_RO_USER`
- `EPF_SQL_RO_PWD`
- `EPF_SQL_RO_HOST`
- `EPF_SQL_RO_PORT`
- `EPF_SQL_RO_DB`
- `EPF_SQL_RO_SCHEMA`

## Tools
- `scripts/sql_ro_probe.py` — smoke/probe report
- `scripts/sql_ro_query.py` — generic read-only query runner

## Working Rules For Heavy Diagnostics
1. Start from the smallest stable scope:
- one LS,
- one month,
- one register / one PVH.

2. Prefer server-side aggregation:
- `count/sum/group by`
- existence checks
- targeted joins

3. Avoid giant `IN (...)` lists in one query:
- split long lists into chunks,
- or stage IDs in temporary sets on the 1C side when moving from diagnostics to fix.

4. Use `EXPLAIN` for uncertain expensive queries before broad runs.

5. Store the result of every meaningful diagnostic run in `logs/sql/` and reuse it instead of re-running the same wide query.

## Templates
- `sql/readonly/00_connection_info.sql`
- `sql/readonly/01_schema_summary.sql`
- `sql/readonly/02_top_relations.sql`
- `sql/readonly/03_name_like_patterns.sql`

## Example
```bash
{PROJECT_ROOT}/scripts/sql_ro_query.py \
  --file {PROJECT_ROOT}/sql/readonly/01_schema_summary.sql \
  --title "Schema Summary"
```

Results go to `logs/sql/` as both `.md` and `.csv`.

## When To Stay In SQL And When To Return To 1C
- Stay in SQL for:
  - counts,
  - presence/absence checks,
  - before/after comparisons,
  - locating candidate rows and suspicious references.
- Return to 1C for:
  - any fix,
  - semantic resolution,
  - link replacement,
  - operations that must respect platform logic.
