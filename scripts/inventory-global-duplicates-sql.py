#!{PROJECT_ROOT}/.venv-sql/bin/python
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
import csv
import json
import re
import sys
import argparse
import xml.etree.ElementTree as ET

import psycopg
from psycopg import sql


ROOT = Path("{PROJECT_ROOT}")
ENV_PATH = ROOT / ".env"
OUT_DIR = ROOT / "logs" / "duplicates"
OUT_DIR.mkdir(parents=True, exist_ok=True)
CONFIG_XML = ROOT / "context" / "config-dumps" / "x1_14_local_full" / "Configuration.xml"


@dataclass
class TableInfo:
    name: str
    family: str
    has_marked: bool
    has_folder: bool
    has_code: bool
    has_description: bool
    has_number: bool
    has_date_time: bool


def load_env(path: Path) -> dict[str, str]:
    env: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        env[key.strip()] = value.strip()
    return env


def connect() -> psycopg.Connection:
    env = load_env(ENV_PATH)
    conn = psycopg.connect(
        host=env["EPF_SQL_RO_HOST"],
        port=int(env.get("EPF_SQL_RO_PORT", "5432")),
        dbname=env["EPF_SQL_RO_DB"],
        user=env["EPF_SQL_RO_USER"],
        password=env["EPF_SQL_RO_PWD"],
        connect_timeout=8,
    )
    conn.read_only = True
    with conn.cursor() as cur:
        cur.execute("set statement_timeout = '5000ms'")
    return conn


def table_sort_key(name: str) -> tuple[str, int]:
    match = re.search(r"(\d+)$", name)
    return (re.sub(r"\d+$", "", name), int(match.group(1)) if match else 0)


def load_metadata_order() -> tuple[list[str], list[str]]:
    if not CONFIG_XML.exists():
        return [], []
    root = ET.parse(CONFIG_XML).getroot()
    catalogs = [node.text or "" for node in root.iter() if node.tag.endswith("Catalog")]
    documents = [node.text or "" for node in root.iter() if node.tag.endswith("Document")]
    return catalogs, documents


def metadata_name_for_table(table_name: str, catalogs: list[str], documents: list[str]) -> str:
    ref_match = re.fullmatch(r"_reference(\d+)", table_name)
    if ref_match:
        index = int(ref_match.group(1)) - 66
        return f"Справочник.{catalogs[index]}" if 0 <= index < len(catalogs) else ""
    doc_match = re.fullmatch(r"_document(\d+)", table_name)
    if doc_match:
        index = int(doc_match.group(1)) - 672
        return f"Документ.{documents[index]}" if 0 <= index < len(documents) else ""
    return ""


def get_tables(conn: psycopg.Connection, family_filter: str) -> list[TableInfo]:
    query = """
        select table_name, column_name
        from information_schema.columns
        where table_schema = 'public'
          and (
            (%s in ('all', 'reference') and table_name ~ '^_reference[0-9]+$')
            or (%s in ('all', 'document') and table_name ~ '^_document[0-9]+$')
          )
        order by table_name, ordinal_position
    """
    by_table: dict[str, set[str]] = {}
    with conn.cursor() as cur:
        cur.execute(query, (family_filter, family_filter))
        for table_name, column_name in cur.fetchall():
            by_table.setdefault(table_name, set()).add(column_name)

    result: list[TableInfo] = []
    for name, cols in sorted(by_table.items(), key=lambda item: table_sort_key(item[0])):
        family = "reference" if name.startswith("_reference") else "document"
        result.append(
            TableInfo(
                name=name,
                family=family,
                has_marked="_marked" in cols,
                has_folder="_folder" in cols,
                has_code="_code" in cols,
                has_description="_description" in cols,
                has_number="_number" in cols,
                has_date_time="_date_time" in cols,
            )
        )
    return result


def scalar(cur: psycopg.Cursor, query: sql.Composed, params: tuple = ()) -> int:
    cur.execute(query, params)
    value = cur.fetchone()[0]
    return int(value or 0)


def duplicate_summary(
    cur: psycopg.Cursor,
    table: str,
    exprs: list[sql.SQL],
    where_parts: list[sql.SQL],
) -> tuple[int, int, list[tuple]]:
    where_sql = sql.SQL(" and ").join(where_parts) if where_parts else sql.SQL("true")
    expr_sql = sql.SQL(", ").join(exprs)
    query = sql.SQL(
        """
        with grouped as (
          select {expr_sql}, count(*) as cnt
          from {table}
          where {where_sql}
          group by {expr_sql}
          having count(*) > 1
        )
        select count(*)::bigint, coalesce(sum(cnt), 0)::bigint
        from grouped
        """
    ).format(expr_sql=expr_sql, table=sql.Identifier(table), where_sql=where_sql)
    cur.execute(query)
    group_count, element_count = cur.fetchone()

    sample_query = sql.SQL(
        """
        select {expr_sql}, count(*) as cnt
        from {table}
        where {where_sql}
        group by {expr_sql}
        having count(*) > 1
        order by cnt desc, {expr_sql}
        limit 5
        """
    ).format(expr_sql=expr_sql, table=sql.Identifier(table), where_sql=where_sql)
    cur.execute(sample_query)
    samples = cur.fetchall()
    return int(group_count or 0), int(element_count or 0), samples


def text_expr(column: str) -> sql.SQL:
    return sql.SQL("nullif(btrim({field}::text), '')").format(field=sql.Identifier(column))


def date_expr() -> sql.SQL:
    return sql.SQL("_date_time")


def inspect_table(conn: psycopg.Connection, info: TableInfo, metadata_name: str) -> dict:
    where_active: list[sql.SQL] = []
    if info.has_marked:
        where_active.append(sql.SQL("not _marked"))

    result = {
        "table": info.name,
        "metadata": metadata_name,
        "family": info.family,
        "active_rows": 0,
        "active_elements": 0,
        "active_folders": 0,
        "dup_code_groups": 0,
        "dup_code_elements": 0,
        "dup_name_groups": 0,
        "dup_name_elements": 0,
        "dup_number_groups": 0,
        "dup_number_elements": 0,
        "dup_number_date_groups": 0,
        "dup_number_date_elements": 0,
        "samples": {},
        "error": "",
    }

    with conn.cursor() as cur:
        try:
            result["active_rows"] = scalar(
                cur,
                sql.SQL("select count(*) from {table} where {where_sql}").format(
                    table=sql.Identifier(info.name),
                    where_sql=sql.SQL(" and ").join(where_active) if where_active else sql.SQL("true"),
                ),
            )

            if info.family == "reference":
                if info.has_folder:
                    result["active_folders"] = scalar(
                        cur,
                        sql.SQL("select count(*) from {table} where {where_sql} and _folder").format(
                            table=sql.Identifier(info.name),
                            where_sql=sql.SQL(" and ").join(where_active) if where_active else sql.SQL("true"),
                        ),
                    )
                    result["active_elements"] = scalar(
                        cur,
                        sql.SQL("select count(*) from {table} where {where_sql} and not _folder").format(
                            table=sql.Identifier(info.name),
                            where_sql=sql.SQL(" and ").join(where_active) if where_active else sql.SQL("true"),
                        ),
                    )
                    element_where = where_active + [sql.SQL("not _folder")]
                else:
                    result["active_elements"] = result["active_rows"]
                    element_where = where_active

                if info.has_code:
                    groups, elements, samples = duplicate_summary(
                        cur,
                        info.name,
                        [text_expr("_code")],
                        element_where + [sql.SQL("nullif(btrim(_code::text), '') is not null")],
                    )
                    result["dup_code_groups"] = groups
                    result["dup_code_elements"] = elements
                    result["samples"]["code"] = samples

                if info.has_description:
                    groups, elements, samples = duplicate_summary(
                        cur,
                        info.name,
                        [sql.SQL("lower(nullif(btrim(_description::text), ''))")],
                        element_where + [sql.SQL("nullif(btrim(_description::text), '') is not null")],
                    )
                    result["dup_name_groups"] = groups
                    result["dup_name_elements"] = elements
                    result["samples"]["name"] = samples

            if info.family == "document" and info.has_number:
                number_where = where_active + [sql.SQL("nullif(btrim(_number::text), '') is not null")]
                groups, elements, samples = duplicate_summary(cur, info.name, [text_expr("_number")], number_where)
                result["dup_number_groups"] = groups
                result["dup_number_elements"] = elements
                result["samples"]["number"] = samples

                if info.has_date_time:
                    groups, elements, samples = duplicate_summary(
                        cur,
                        info.name,
                        [text_expr("_number"), date_expr()],
                        number_where,
                    )
                    result["dup_number_date_groups"] = groups
                    result["dup_number_date_elements"] = elements
                    result["samples"]["number_date"] = samples

        except Exception as exc:  # noqa: BLE001 - diagnostic must continue per table
            result["error"] = str(exc)
            conn.rollback()
    return result


def has_findings(row: dict) -> bool:
    return any(
        row[key] > 0
        for key in (
            "dup_code_groups",
            "dup_name_groups",
            "dup_number_groups",
            "dup_number_date_groups",
        )
    ) or bool(row["error"])


def sample_text(samples: list[tuple]) -> str:
    if not samples:
        return ""
    rendered = []
    for sample in samples[:3]:
        *values, count = sample
        rendered.append("/".join(str(value) for value in values) + f" ({count})")
    return "; ".join(rendered)


def write_outputs(rows: list[dict]) -> dict[str, str | int]:
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    md_path = OUT_DIR / f"global_duplicates_sql_{stamp}.md"
    csv_path = OUT_DIR / f"global_duplicates_sql_{stamp}.csv"

    finding_rows = [row for row in rows if has_findings(row)]
    lines = [
        "# Global duplicate inventory via SQL RO",
        "",
        f"- Timestamp: `{datetime.now().isoformat(timespec='seconds')}`",
        "- Base: `MergedBase` / `x17_pg2`",
        "- Mode: read-only",
        "- Scope: main `_referenceNNN` and `_documentNNN` tables, excluding tabular sections",
        f"- Tables scanned: {len(rows)}",
        f"- Tables with findings/errors: {len(finding_rows)}",
        "",
        "## Summary",
        "",
    ]

    totals = {
        "dup_code_groups": sum(row["dup_code_groups"] for row in rows),
        "dup_code_elements": sum(row["dup_code_elements"] for row in rows),
        "dup_name_groups": sum(row["dup_name_groups"] for row in rows),
        "dup_name_elements": sum(row["dup_name_elements"] for row in rows),
        "dup_number_groups": sum(row["dup_number_groups"] for row in rows),
        "dup_number_elements": sum(row["dup_number_elements"] for row in rows),
        "dup_number_date_groups": sum(row["dup_number_date_groups"] for row in rows),
        "dup_number_date_elements": sum(row["dup_number_date_elements"] for row in rows),
    }
    for key, value in totals.items():
        lines.append(f"- {key}: {value}")

    lines.extend(["", "## Top Findings", ""])
    if not finding_rows:
        lines.append("- Findings not detected.")
    else:
        top = sorted(
            finding_rows,
            key=lambda row: (
                row["dup_number_date_elements"],
                row["dup_number_elements"],
                row["dup_code_elements"],
                row["dup_name_elements"],
            ),
            reverse=True,
        )[:60]
        lines.append("| table | metadata | family | active | code groups/elements | name groups/elements | number groups/elements | number+date groups/elements | samples | error |")
        lines.append("| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- | --- |")
        for row in top:
            rendered_samples = []
            for key in ("code", "name", "number", "number_date"):
                text = sample_text(row["samples"].get(key, []))
                if text:
                    rendered_samples.append(f"{key}: {text}")
            lines.append(
                f"| {row['table']} | {row['metadata']} | {row['family']} | {row['active_rows']} | "
                f"{row['dup_code_groups']}/{row['dup_code_elements']} | "
                f"{row['dup_name_groups']}/{row['dup_name_elements']} | "
                f"{row['dup_number_groups']}/{row['dup_number_elements']} | "
                f"{row['dup_number_date_groups']}/{row['dup_number_date_elements']} | "
                f"{'<br>'.join(rendered_samples).replace('|', '\\|')} | "
                f"{row['error'].replace('|', '\\|')} |"
            )

    lines.extend(
        [
            "",
            "## Interpretation",
            "",
            "- Duplicate `_number + _date_time` in one document table is the strongest update-risk signal.",
            "- Duplicate `_number` without equal date can be valid only if the document type uses non-unique numbering rules; verify in 1C before fixing.",
            "- Duplicate `_code` in one catalog table is a high-risk signal for update and choice-list stability.",
            "- Duplicate names are informational unless profile/reference usage proves they are true duplicates.",
        ]
    )
    md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    fieldnames = [
        "table",
        "metadata",
        "family",
        "active_rows",
        "active_elements",
        "active_folders",
        "dup_code_groups",
        "dup_code_elements",
        "dup_name_groups",
        "dup_name_elements",
        "dup_number_groups",
        "dup_number_elements",
        "dup_number_date_groups",
        "dup_number_date_elements",
        "error",
    ]
    with csv_path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({key: row[key] for key in fieldnames})

    return {"md": str(md_path), "csv": str(csv_path), "tables": len(rows), "findings": len(finding_rows)}


def main() -> int:
    parser = argparse.ArgumentParser(description="Inventory duplicate codes/numbers in 1C PostgreSQL tables")
    parser.add_argument("--family", choices=("all", "reference", "document"), default="all")
    parser.add_argument("--max-tables", type=int, default=0, help="Debug limit; 0 means all")
    args = parser.parse_args()

    try:
        with connect() as conn:
            tables = get_tables(conn, args.family)
            if args.max_tables > 0:
                tables = tables[: args.max_tables]
            catalogs, documents = load_metadata_order()
            rows = []
            for index, table in enumerate(tables, start=1):
                if index == 1 or index % 25 == 0:
                    print(f"scan {index}/{len(tables)} {table.name}", file=sys.stderr, flush=True)
                metadata_name = metadata_name_for_table(table.name, catalogs, documents)
                rows.append(inspect_table(conn, table, metadata_name))
        print(json.dumps(write_outputs(rows), ensure_ascii=False))
        return 0
    except Exception as exc:  # noqa: BLE001
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
