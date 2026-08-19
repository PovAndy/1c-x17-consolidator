#!/usr/bin/env python3
"""Собирает строго read-only доказательную карту остатка [22.12]."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from collections import Counter, defaultdict
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REGISTRY = PROJECT_ROOT / "temp/donor_195_2_work/residual_registry.json"
DEFAULT_SNAPSHOT = Path(
    "/mnt/t/1S/wsl_exchange/work_epf_112_9/temp/donor_195_2_com/donor_snapshot.jsonl"
)
DEFAULT_STATUS = DEFAULT_SNAPSHOT.with_name("donor_snapshot_status.json")
DEFAULT_OUTPUT = PROJECT_ROOT / "temp/donor_facts_195_2.json"

NAME_PATTERN = re.compile(r"Наименование=([^;{}]+)")


def read_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8-sig") as stream:
        return json.load(stream)


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8-sig") as stream:
        for line_number, line in enumerate(stream, start=1):
            item = line.strip()
            if not item:
                continue
            value = json.loads(item)
            if not isinstance(value, dict):
                raise ValueError(f"Некорректная запись JSONL в строке {line_number}.")
            records.append(value)
    return records


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def normalise(value: str) -> str:
    return " ".join(value.casefold().replace("ё", "е").split())


def source_name(source: str) -> str:
    match = NAME_PATTERN.search(source)
    return match.group(1).strip() if match else ""


def compact_candidate(row: dict[str, Any]) -> dict[str, str]:
    return {
        "source_alias": str(row.get("source_alias", "")),
        "entity": str(row.get("entity", "")),
        "ref_uuid": str(row.get("ref_xml", "")),
        "code": str(row.get("code", "")),
        "name": str(row.get("name", "")),
        "deletion_mark": str(row.get("deletion_mark", "")),
    }


def reference_preview(
    row: dict[str, Any], by_name: dict[str, list[dict[str, Any]]]
) -> dict[str, Any]:
    path = str(row.get("path", ""))
    name = source_name(str(row.get("source", "")))
    candidates = [compact_candidate(item) for item in by_name.get(normalise(name), [])] if name else []
    aliases = sorted({item["source_alias"] for item in candidates})
    codes = sorted({item["code"] for item in candidates})
    covered = path.startswith("ПланВидовХарактеристик.икХарактеристикиОбъектовУчета.")
    ambiguous = len(codes) > 1 or len({item["ref_uuid"] for item in candidates}) > 1
    return {
        "event_number": row.get("number"),
        "kind": "missing_reference",
        "path": path,
        "target_type": row.get("target_type"),
        "target_uuid": row.get("target_uuid"),
        "source_uuid": row.get("source_uuid"),
        "source_name": name,
        "coverage": "partial_read_only" if covered else "not_collected",
        "matching_method": "нормализованное_наименование_донора" if candidates else "нет_кандидата",
        "candidate_aliases": aliases,
        "candidate_count": len(candidates),
        "candidate_code_count": len(codes),
        "ambiguity": ambiguous,
        "candidates": candidates,
    }


def parent_preview(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "event_number": row.get("number"),
        "kind": "wrong_parent",
        "path": row.get("path"),
        "source": row.get("source"),
        "coverage": "not_collected",
        "stop": "Требуется ручная проверка типа родителя по метаданным 1С.",
    }


def build(registry: dict[str, Any], records: list[dict[str, Any]], status: list[dict[str, Any]]) -> dict[str, Any]:
    expected_aliases = [
        "x1_01", "x1_02", "x1_03", "x1_06", "x1_08", "x1_10", "x1_11",
        "x1_12", "x1_14", "x1_15", "x1_16", "x1_17", "x1_20", "x1_21",
        "x1_22", "x1_23", "x1_25",
    ]
    successful_aliases = sorted(
        str(item.get("source_alias")) for item in status if item.get("status") == "ok"
    )
    by_name: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for record in records:
        if str(record.get("deletion_mark", "")).casefold() == "true":
            continue
        name = str(record.get("name", "")).strip()
        if name:
            by_name[normalise(name)].append(record)

    references = registry.get("reference_rows", [])
    parents = registry.get("wrong_parents", [])
    previews = [reference_preview(row, by_name) for row in references]
    previews.extend(parent_preview(row) for row in parents)
    preview_references = [item for item in previews if item["kind"] == "missing_reference"]
    uncovered = [item for item in preview_references if item["coverage"] == "not_collected"]
    candidates = [item for item in preview_references if item["candidate_count"]]
    ambiguous = [item for item in preview_references if item["ambiguity"]]

    stop_reasons: list[dict[str, Any]] = []
    if sorted(successful_aliases) != expected_aliases:
        stop_reasons.append({
            "code": "SOURCE_COVERAGE_INCOMPLETE",
            "count": len(successful_aliases),
            "detail": "Не все 17 источников подтвердили read-only снимок.",
        })
    if uncovered:
        stop_reasons.append({
            "code": "METADATA_COVERAGE_INCOMPLETE",
            "count": len(uncovered),
            "detail": "Для указанных путей нет read-only выгрузки соответствующих сущностей донора.",
        })
    if ambiguous:
        stop_reasons.append({
            "code": "DONOR_CANDIDATE_AMBIGUITY",
            "count": len(ambiguous),
            "detail": "Совпадение по наименованию не образует однозначного межбазового соответствия.",
        })
    if parents:
        stop_reasons.append({
            "code": "WRONG_PARENT_REQUIRES_METADATA_REVIEW",
            "count": len(parents),
            "detail": "Два события неверного родителя требуют проверки типов в метаданных 1С.",
        })
    stop_reasons.append({
        "code": "NO_CROSS_DATABASE_UUID_EQUIVALENCE",
        "count": len(preview_references),
        "detail": "UUID из независимых файловых баз не являются доказательством эквивалентности без явной карты.",
    })

    return {
        "schema_version": "1.0",
        "generated_at_utc": datetime.now(UTC).isoformat(),
        "mode": "read_only",
        "scope": "остаток [22.12]: 195 битых ссылок + 2 неверных родителя",
        "source_snapshot": {
            "expected_aliases": expected_aliases,
            "successful_aliases": successful_aliases,
            "successful_alias_count": len(successful_aliases),
            "status_rows": status,
            "record_count": len(records),
            "entities": dict(sorted(Counter(str(item.get("entity", "")) for item in records).items())),
        },
        "residual_summary": {
            "missing_reference_count": len(references),
            "wrong_parent_count": len(parents),
            "source_path_count": len({str(item.get("path", "")) for item in references}),
            "target_type_counts": dict(sorted(Counter(str(item.get("target_type", "")) for item in references).items())),
        },
        "preview_summary": {
            "candidate_event_count": len(candidates),
            "uncovered_event_count": len(uncovered),
            "ambiguous_event_count": len(ambiguous),
            "stop_required": bool(stop_reasons),
        },
        "events": previews,
        "stop_reasons": stop_reasons,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", type=Path, default=DEFAULT_REGISTRY)
    parser.add_argument("--snapshot", type=Path, default=DEFAULT_SNAPSHOT)
    parser.add_argument("--status", type=Path, default=DEFAULT_STATUS)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    registry = read_json(args.registry)
    records = read_jsonl(args.snapshot)
    status = read_json(args.status)
    if not isinstance(status, list):
        raise ValueError("Статус COM-снимка должен быть массивом.")
    result = build(registry, records, status)
    result["input_hashes"] = {
        "registry_sha256": sha256(args.registry),
        "snapshot_sha256": sha256(args.snapshot),
        "status_sha256": sha256(args.status),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        "read_only=ok "
        f"aliases={result['source_snapshot']['successful_alias_count']}/17 "
        f"records={result['source_snapshot']['record_count']} "
        f"events={len(result['events'])} "
        f"stop={result['preview_summary']['stop_required']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
