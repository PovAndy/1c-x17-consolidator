#!/usr/bin/env python3
"""Collect bounded read-only donor facts for the [22.12] residual registry."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path
from typing import Any

ROOT = Path("{PROJECT_ROOT}")
sys.path.insert(0, str(ROOT / "scripts"))

from call_test_bridge import call_bridge  # noqa: E402


PVH_OBJECT_PREFIX = (
    "ПланВидовХарактеристик.икХарактеристикиОбъектовУчета.Реквизит."
)
PVH_OTHER_PATH = (
    "ПланВидовХарактеристик.икХарактеристикиПрочихОбъектов.Реквизит.ВидОбъекта"
)
PAYMENT_PREFIX = "Справочник.икВариантыОплатыУслуг.Реквизит."


def source_name(source: str) -> str:
    match = re.search(r"Наименование=([^;]+)", source)
    if match:
        return match.group(1).strip()
    match = re.search(r"Ссылка=(.*?)\s+\{UUID=", source)
    return match.group(1).strip() if match else ""


def quote(value: str) -> str:
    return '"' + value.replace('"', '""') + '"'


def in_list(values: set[str]) -> str:
    return ", ".join(quote(value) for value in sorted(values))


def configure_MergedBase() -> None:
    os.environ["LDS_1C_BRIDGE_TARGET"] = "MergedBase"
    os.environ["LDS_1C_BRIDGE_URL"] = (
        "http://{V8_SERVER}/MergedBase/hs/codex-test"
    )
    os.environ["LDS_1C_BRIDGE_URL_IP"] = (
        "http://192.168.195.46/MergedBase/hs/codex-test"
    )


def run_query(name: str, text: str, out_dir: Path, limit: int = 1000) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for attempt in range(1, 4):
        result = call_bridge("Query", {"text": text, "limit": limit, "params": {}})
        bridge_url = str(result.get("bridge_url", "")).lower()
        if result.get("ok") and "/MergedBase/" in bridge_url:
            break
        if attempt < 3:
            time.sleep(attempt * 2)
    else:
        raise RuntimeError(
            f"{name}: invalid MergedBase response: "
            f"ok={result.get('ok')} bridge_url={bridge_url} "
            f"error={result.get('error')}"
        )
    (out_dir / f"{name}.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return result


def presentation(value: Any) -> str:
    if isinstance(value, dict):
        return str(value.get("presentation", ""))
    return "" if value is None else str(value)


def uuid(value: Any) -> str:
    if isinstance(value, dict):
        return str(value.get("uuid", "")).lower()
    return ""


def compact_rows(result: dict[str, Any], fields: list[str]) -> list[dict[str, str]]:
    compact: list[dict[str, str]] = []
    for row in result.get("rows", []):
        item: dict[str, str] = {}
        for field in fields:
            value = row.get(field)
            item[field] = presentation(value)
            ref_uuid = uuid(value)
            if ref_uuid:
                item[f"{field}UUID"] = ref_uuid
        compact.append(item)
    return compact


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("distilled", type=Path)
    parser.add_argument("--out-dir", required=True, type=Path)
    args = parser.parse_args()

    data = json.loads(args.distilled.read_text(encoding="utf-8"))
    rows = data["reference_rows"]
    object_names = {
        source_name(row["source"])
        for row in rows
        if row["path"].startswith(PVH_OBJECT_PREFIX)
    }
    other_names = {
        source_name(row["source"])
        for row in rows
        if row["path"] == PVH_OTHER_PATH
    }
    payment_names = {
        source_name(row["source"])
        for row in rows
        if row["path"].startswith(PAYMENT_PREFIX)
    }

    args.out_dir.mkdir(parents=True, exist_ok=True)
    configure_MergedBase()
    health = call_bridge("Health")
    if not health.get("ok") or "/MergedBase/" not in str(
        health.get("bridge_url", "")
    ).lower():
        raise RuntimeError(f"MergedBase health mismatch: {health}")

    object_result = run_query(
        "pvh_object_candidates",
        f"""
ВЫБРАТЬ
    Характеристики.Ссылка КАК Ссылка,
    Характеристики.Код КАК Код,
    Характеристики.Наименование КАК Наименование,
    Характеристики.Родитель КАК Родитель,
    Характеристики.ВидОбъектаУчета КАК ВидОбъектаУчета,
    Характеристики.ВидОбъектаУчетаДляВычисления КАК ВидОбъектаУчетаДляВычисления,
    Характеристики.ХарактеристикаОбъектаУчетаДляВычисления КАК ХарактеристикаОбъектаУчетаДляВычисления,
    Характеристики.ГруппаГраждан КАК ГруппаГраждан,
    Характеристики.ЕдиницаИзмерения КАК ЕдиницаИзмерения,
    Характеристики.ПометкаУдаления КАК ПометкаУдаления
ИЗ
    ПланВидовХарактеристик.икХарактеристикиОбъектовУчета КАК Характеристики
ГДЕ
    Характеристики.Наименование В ({in_list(object_names)})
УПОРЯДОЧИТЬ ПО
    Наименование,
    Код
""",
        args.out_dir,
    )
    other_result = run_query(
        "pvh_other_candidates",
        f"""
ВЫБРАТЬ
    Характеристики.Ссылка КАК Ссылка,
    Характеристики.Код КАК Код,
    Характеристики.Наименование КАК Наименование,
    Виды.Ссылка КАК ВидОбъекта,
    Виды.Наименование КАК ВидОбъектаНаименование,
    Характеристики.ПометкаУдаления КАК ПометкаУдаления
ИЗ
    ПланВидовХарактеристик.икХарактеристикиПрочихОбъектов КАК Характеристики
        ВНУТРЕННЕЕ СОЕДИНЕНИЕ ПланВидовХарактеристик.икВидыПрочихОбъектов КАК Виды
        ПО Характеристики.ВидОбъекта = Виды.Ссылка
УПОРЯДОЧИТЬ ПО
    Наименование,
    Код
""",
        args.out_dir,
    )
    payment_result = run_query(
        "payment_candidates",
        f"""
ВЫБРАТЬ
    Варианты.Ссылка КАК Ссылка,
    Варианты.Код КАК Код,
    Варианты.Наименование КАК Наименование,
    Варианты.Родитель КАК Родитель,
    Варианты.ВидОплаты КАК ВидОплаты,
    Варианты.Договор КАК Договор,
    Варианты.Контрагент КАК Контрагент,
    Варианты.НастройкиПечатиЧека КАК НастройкиПечатиЧека,
    Варианты.Организация КАК Организация,
    Варианты.ПолучательПлатежа КАК ПолучательПлатежа,
    Варианты.СписокУслуг КАК СписокУслуг,
    Варианты.СпособРаспределения КАК СпособРаспределения,
    Варианты.СтатьяДвиженияДенежныхСредств КАК СтатьяДвиженияДенежныхСредств,
    Варианты.СчетАвансов КАК СчетАвансов,
    Варианты.СчетРасчетов КАК СчетРасчетов,
    Варианты.СчетУчетаРасчетовСКонтрагентом КАК СчетУчетаРасчетовСКонтрагентом,
    Варианты.УстройствоПечатиЧекаПоУмолчанию КАК УстройствоПечатиЧекаПоУмолчанию,
    Варианты.ПометкаУдаления КАК ПометкаУдаления
ИЗ
    Справочник.икВариантыОплатыУслуг КАК Варианты
ГДЕ
    Варианты.Наименование В ({in_list(payment_names)})
УПОРЯДОЧИТЬ ПО
    Наименование,
    Код
""",
        args.out_dir,
    )
    basis_result = run_query(
        "service_basis_candidates",
        """
ВЫБРАТЬ
    Основания.Ссылка КАК Ссылка,
    Основания.Код КАК Код,
    Основания.Наименование КАК Наименование,
    Основания.ХарактеристикаОбъектаУчета КАК ХарактеристикаОбъектаУчета,
    Основания.ПометкаУдаления КАК ПометкаУдаления
ИЗ
    Справочник.икОснованияРасчетаУслуг КАК Основания
ГДЕ
    Основания.Наименование = "Количество голов КРС (корова)"
УПОРЯДОЧИТЬ ПО
    Код
""",
        args.out_dir,
    )

    compact_other_rows = [
        row
        for row in compact_rows(
            other_result,
            [
                "Ссылка",
                "Код",
                "Наименование",
                "ВидОбъекта",
                "ВидОбъектаНаименование",
                "ПометкаУдаления",
            ],
        )
        if row["Наименование"] in other_names
    ]
    compact = {
        "health": {
            "bridge_url": health.get("bridge_url", ""),
            "transport": health.get("transport", ""),
        },
        "pvh_object_candidates": compact_rows(
            object_result,
            [
                "Ссылка",
                "Код",
                "Наименование",
                "Родитель",
                "ВидОбъектаУчета",
                "ВидОбъектаУчетаДляВычисления",
                "ХарактеристикаОбъектаУчетаДляВычисления",
                "ГруппаГраждан",
                "ЕдиницаИзмерения",
                "ПометкаУдаления",
            ],
        ),
        "pvh_other_candidates": compact_other_rows,
        "payment_candidates": compact_rows(
            payment_result,
            [
                "Ссылка",
                "Код",
                "Наименование",
                "Родитель",
                "ВидОплаты",
                "Договор",
                "Контрагент",
                "НастройкиПечатиЧека",
                "Организация",
                "ПолучательПлатежа",
                "СписокУслуг",
                "СпособРаспределения",
                "СтатьяДвиженияДенежныхСредств",
                "СчетАвансов",
                "СчетРасчетов",
                "СчетУчетаРасчетовСКонтрагентом",
                "УстройствоПечатиЧекаПоУмолчанию",
                "ПометкаУдаления",
            ],
        ),
        "service_basis_candidates": compact_rows(
            basis_result,
            [
                "Ссылка",
                "Код",
                "Наименование",
                "ХарактеристикаОбъектаУчета",
                "ПометкаУдаления",
            ],
        ),
    }
    (args.out_dir / "compact.json").write_text(
        json.dumps(compact, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(
        "PASS "
        f"pvh_object={len(compact['pvh_object_candidates'])} "
        f"pvh_other={len(compact['pvh_other_candidates'])} "
        f"payments={len(compact['payment_candidates'])} "
        f"basis={len(compact['service_basis_candidates'])}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
