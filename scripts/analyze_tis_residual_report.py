#!/usr/bin/env python3
"""Distill a [22.12] TiS residual Markdown report without LLM processing."""

from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter, defaultdict
from pathlib import Path


ROW_RE = re.compile(r"^\|\s*(\d+)\s*\|")
UUID_RE = re.compile(
    r"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b"
)


def parse_markdown_row(line: str) -> list[str]:
    return [part.strip() for part in line.strip().strip("|").split("|")]


def read_restore_map(path: Path) -> dict[str, list[dict[str, str]]]:
    result: dict[str, list[dict[str, str]]] = defaultdict(list)
    if not path.exists():
        return result
    with path.open(encoding="utf-8-sig", newline="") as stream:
        for row in csv.DictReader(stream):
            key = (row.get("broken_internal_key") or "").strip().lower()
            if key:
                result[key].append(row)
    return result


def parse_report(path: Path) -> tuple[dict[str, str], list[dict[str, str]], list[dict[str, str]]]:
    text = path.read_text(encoding="utf-8-sig")
    control: dict[str, str] = {}
    for key, pattern in {
        "version": r"^- Версия обработки:\s*(.+)$",
        "database": r"^- База:\s*(.+)$",
        "status": r"^- Статус:\s*(.+)$",
        "broken": r"^- Битых ссылок:\s*(.+)$",
        "parents": r"^- Неправильных родителей:\s*(.+)$",
        "query_errors": r"^- Ошибок запросов:\s*(.+)$",
        "unresolved": r"^- Неразрешенных UUID целей:\s*(.+)$",
        "md5": r"^- MD5 реестра:\s*(.+)$",
        "duration": r"^- Длительность:\s*(.+)$",
    }.items():
        match = re.search(pattern, text, re.MULTILINE)
        control[key] = match.group(1).strip() if match else ""

    rows: list[dict[str, str]] = []
    parents: list[dict[str, str]] = []
    section = ""
    for line in text.splitlines():
        if line == "## Полный реестр битых ссылок":
            section = "references"
            continue
        if line == "## Неправильные родители":
            section = "parents"
            continue
        if not line.startswith("|") or line.startswith("|---"):
            continue
        parts = parse_markdown_row(line)
        if section == "references" and ROW_RE.match(line) and len(parts) == 6:
            source_uuids = UUID_RE.findall(parts[2])
            rows.append(
                {
                    "number": parts[0],
                    "path": parts[1],
                    "source": parts[2],
                    "source_uuid": source_uuids[0].lower() if source_uuids else "",
                    "target_type": parts[3],
                    "target_uuid": parts[4].lower(),
                    "internal_key": parts[5].lower(),
                }
            )
        elif section == "parents" and len(parts) == 5 and parts[0] != "Источник":
            source_uuids = UUID_RE.findall(parts[0])
            parents.append(
                {
                    "source": parts[0],
                    "source_uuid": source_uuids[0].lower() if source_uuids else "",
                    "current_parent": parts[1],
                    "target_type": parts[2],
                    "target_uuid": parts[3].lower(),
                    "proposed_parent": parts[4],
                }
            )
    return control, rows, parents


def category(path: str) -> str:
    return path.split(".", 1)[0]


def build_distill(
    control: dict[str, str],
    rows: list[dict[str, str]],
    parents: list[dict[str, str]],
    restore_map: dict[str, list[dict[str, str]]],
) -> dict[str, object]:
    by_uuid: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        by_uuid[row["target_uuid"]].append(row)

    uuid_groups = []
    for target_uuid, group in sorted(
        by_uuid.items(), key=lambda item: (-len(item[1]), item[0])
    ):
        types = Counter(row["target_type"] for row in group)
        paths = Counter(row["path"] for row in group)
        keys = sorted({row["internal_key"] for row in group})
        candidates = []
        for key in keys:
            for candidate in restore_map.get(key, []):
                candidates.append(
                    {
                        "broken_internal_key": key,
                        "target_description": candidate.get("target_description", ""),
                        "target_code": candidate.get("target_code", ""),
                        "target_ref": candidate.get("target_ref", ""),
                        "target_base_alias": candidate.get("target_base_alias", ""),
                        "target_value_type": candidate.get("target_value_type", ""),
                        "allow_create": candidate.get("allow_create", ""),
                        "comment": candidate.get("comment", ""),
                    }
                )
        uuid_groups.append(
            {
                "target_uuid": target_uuid,
                "count": len(group),
                "types": dict(types.most_common()),
                "paths": dict(paths.most_common()),
                "source_objects": len({row["source_uuid"] for row in group}),
                "internal_keys": keys,
                "cross_type": len(types) > 1,
                "restore_map_candidates": candidates,
            }
        )

    return {
        "control": control,
        "row_count": len(rows),
        "parent_count": len(parents),
        "unique_target_uuids": len(by_uuid),
        "unique_target_uuid_type_pairs": len(
            {(row["target_uuid"], row["target_type"]) for row in rows}
        ),
        "unique_sources": len({row["source_uuid"] for row in rows}),
        "categories": dict(Counter(category(row["path"]) for row in rows).most_common()),
        "paths": dict(Counter(row["path"] for row in rows).most_common()),
        "target_types": dict(
            Counter(row["target_type"] for row in rows).most_common()
        ),
        "reference_rows": rows,
        "uuid_groups": uuid_groups,
        "wrong_parents": parents,
        "restore_map_covered_rows": sum(
            len(group)
            for group in by_uuid.values()
            if any(restore_map.get(row["internal_key"]) for row in group)
        ),
    }


def write_markdown(data: dict[str, object], path: Path) -> None:
    control = data["control"]
    lines = [
        "# Дистиллят [22.12]",
        "",
        f"- Версия: {control['version']}",
        f"- База: {control['database']}",
        f"- Контроль: {control['status']}",
        f"- Строк: {data['row_count']}",
        f"- Неправильных родителей: {data['parent_count']}",
        f"- Уникальных целевых UUID: {data['unique_target_uuids']}",
        f"- UUID+тип: {data['unique_target_uuid_type_pairs']}",
        f"- Уникальных источников: {data['unique_sources']}",
        f"- Покрыто текущей restore_map строк: {data['restore_map_covered_rows']}",
        f"- MD5: {control['md5']}",
        "",
        "## Группы UUID",
        "",
        "| UUID | Строк | Типов | Источников | Cross-type | Кандидатов карты |",
        "|---|---:|---:|---:|---|---:|",
    ]
    for group in data["uuid_groups"]:
        lines.append(
            f"| {group['target_uuid']} | {group['count']} | "
            f"{len(group['types'])} | {group['source_objects']} | "
            f"{'STOP' if group['cross_type'] else 'нет'} | "
            f"{len(group['restore_map_candidates'])} |"
        )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("report", type=Path)
    parser.add_argument("--json-out", required=True, type=Path)
    parser.add_argument("--md-out", required=True, type=Path)
    parser.add_argument(
        "--restore-map",
        type=Path,
        default=Path("context/recovery/other-pvh/out/restore_map.csv"),
    )
    args = parser.parse_args()

    control, rows, parents = parse_report(args.report)
    data = build_distill(
        control, rows, parents, read_restore_map(args.restore_map)
    )
    args.json_out.parent.mkdir(parents=True, exist_ok=True)
    args.md_out.parent.mkdir(parents=True, exist_ok=True)
    args.json_out.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    write_markdown(data, args.md_out)
    print(
        "PASS "
        f"rows={data['row_count']} parents={data['parent_count']} "
        f"uuids={data['unique_target_uuids']} "
        f"uuid_types={data['unique_target_uuid_type_pairs']} "
        f"map_rows={data['restore_map_covered_rows']}"
    )


if __name__ == "__main__":
    main()
