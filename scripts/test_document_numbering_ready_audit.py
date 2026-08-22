#!/usr/bin/env python3
"""Static and provenance checks for the guarded [18.12] ReadOnly audit."""

from __future__ import annotations

import hashlib
import re
from pathlib import Path

from epf_test_utils import current_processing_version, require_form_version, version_return_marker


ROOT = Path(__file__).resolve().parents[1]
OBJECT = ROOT / "src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная/Ext/ObjectModule.bsl"
FORM = ROOT / "src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная/Forms/Форма/Ext/Form/Module.bsl"
FORM_XML = ROOT / "src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная/Forms/Форма/Ext/Form.xml"
ROOT_XML = ROOT / "src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная.xml"
TEMPLATE = ROOT / (
    "src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная/Templates/"
    "ПланАудитаREADYНумерации12305/Ext/Template.txt"
)


def require(text: str, marker: str, label: str) -> None:
    if marker not in text:
        raise AssertionError(f"Missing {label}: {marker}")


def function_body(module: str, name: str) -> str:
    match = re.search(
        rf"Функция\s+{re.escape(name)}\([\s\S]*?\)\s*(?:Экспорт)?\s*\n(.*?)\nКонецФункции",
        module,
        flags=re.S,
    )
    if not match:
        raise AssertionError(f"Function not found: {name}")
    return match.group(1)


def template_rows(template_text: str) -> list[tuple[str, ...]]:
    result: list[tuple[str, ...]] = []
    document_type = ""
    for line in template_text.replace("\r", "").splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith("@"):
            document_type = line[1:]
            continue
        columns = [part.strip().strip("`") for part in line.split("|")]
        if len(columns) != 6 or not document_type:
            raise AssertionError(f"Unexpected template row: {line[:200]}")
        result.append(
            (
                document_type,
                columns[0].lower(),
                columns[1],
                columns[2],
                columns[3],
                columns[4],
                columns[5],
            )
        )
    result.sort(key=lambda item: (item[0].casefold(), item[1]))
    return result


def expected_registry(rows: list[tuple[str, ...]]) -> str:
    lines: list[str] = []
    current_type = ""
    for row in rows:
        if row[0] != current_type:
            lines.append(f"@{row[0]}")
            current_type = row[0]
        lines.append("|".join(row[1:]))
    return "\n".join(lines)


def expected_state(rows: list[tuple[str, ...]]) -> str:
    lines: list[str] = []
    current_type = ""
    for document_type, uuid, date_key, posted, _old, target, district in rows:
        if document_type != current_type:
            lines.append(f"@{document_type}")
            current_type = document_type
        lines.append("|".join((uuid, date_key, posted, target, district)))
    return "\n".join(lines)


def main() -> None:
    object_module = OBJECT.read_text(encoding="utf-8-sig")
    form_module = FORM.read_text(encoding="utf-8-sig")
    form_xml = FORM_XML.read_text(encoding="utf-8-sig")
    root_xml = ROOT_XML.read_text(encoding="utf-8-sig")

    audit = function_body(
        object_module,
        "Адапт_АудитREADYНумерацииДокументовСвежейКопии",
    )
    checker = function_body(
        object_module,
        "Адапт_ПроверитьПланАудитаREADYНумерации12305",
    )
    version = current_processing_version(object_module, 10)
    require(object_module, version_return_marker(version), "processor version")
    require_form_version(form_xml, version)
    require(audit, "ОжидаетсяСтрок = 3", "synthetic fixture row count")
    require(audit, 'ОжидаетсяMD5Реестра = "DE9795874164AA1A85F4E2296F00DB3F"', "public registry MD5")
    require(audit, 'ОжидаетсяMD5Состояния = "452B7D0F1046EEDD1BE5498A8D401D4F"', "public state MD5")
    require(audit, "Адапт_ЭтоКонтурPostgres3ДляСвежейКопии", "FreshCopyTarget contour guard")
    require(checker, "Документ.Ссылка В (&Ссылки)", "batched read query")
    require(checker, "РазмерПакета", "batch limit")
    for forbidden in ("Записать(", "НачатьТранзакцию(", "ЗафиксироватьТранзакцию(", "Удалить("):
        if forbidden in audit or forbidden in checker:
            raise AssertionError(f"ReadOnly audit contains forbidden operation: {forbidden}")

    require(form_module, "АудитREADYНумерацииДокументовСвежейКопииНаСервере", "form server wrapper")
    require(form_xml, "[18.12] Аудит synthetic fixture номеров", "form command title")
    require(root_xml, "<Template>ПланАудитаREADYНумерации12305</Template>", "template registration")

    template = TEMPLATE.read_text(encoding="utf-8-sig").replace("\r", "").rstrip("\n")
    rows = template_rows(template)
    if len(rows) != 3:
        raise AssertionError(f"Synthetic template contains {len(rows)} READY rows")
    registry = expected_registry(rows)
    if template != registry:
        raise AssertionError("Embedded registry is not canonical after normalization")
    registry_md5 = hashlib.md5(registry.encode()).hexdigest().upper()
    state_md5 = hashlib.md5(expected_state(rows).encode()).hexdigest().upper()
    if registry_md5 != "DE9795874164AA1A85F4E2296F00DB3F":
        raise AssertionError(f"Unexpected registry MD5: {registry_md5}")
    if state_md5 != "452B7D0F1046EEDD1BE5498A8D401D4F":
        raise AssertionError(f"Unexpected state MD5: {state_md5}")

    print("PASS: [18.12] registry, ReadOnly contract, form command and exact MD5 are valid")


if __name__ == "__main__":
    main()
