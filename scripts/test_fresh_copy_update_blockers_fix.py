#!/usr/bin/env python3
"""Static fail-closed contract for fresh-copy update blockers stage [25.4]."""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from pathlib import Path

from epf_test_utils import current_processing_version, require_form_version


ROOT = Path(__file__).resolve().parents[1]
OBJECT = ROOT / "src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная/Ext/ObjectModule.bsl"
FORM_MODULE = (
    ROOT
    / "src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная/Forms/Форма/Ext/Form/Module.bsl"
)
FORM_XML = (
    ROOT / "src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная/Forms/Форма/Ext/Form.xml"
)


def function_body(source: str, name: str) -> str:
    match = re.search(
        rf"Функция\s+{re.escape(name)}\([^)]*\)(?:\s+Экспорт)?"
        rf"(?P<body>.*?)КонецФункции",
        source,
        flags=re.DOTALL,
    )
    if match is None:
        raise AssertionError(f"function not found: {name}")
    return match.group("body")


def local_name(element: ET.Element) -> str:
    return element.tag.rsplit("}", 1)[-1]


def find_named(root: ET.Element, tag: str, name: str) -> ET.Element:
    for element in root.iter():
        if local_name(element) == tag and element.get("name") == name:
            return element
    raise AssertionError(f"form node not found: {tag}.{name}")


def main() -> None:
    object_text = OBJECT.read_text(encoding="utf-8-sig")
    form_text = FORM_MODULE.read_text(encoding="utf-8-sig")
    form_xml_text = FORM_XML.read_text(encoding="utf-8-sig")
    form_root = ET.fromstring(form_xml_text)

    version = current_processing_version(object_text, 9)
    assert version == "v25-123.10"
    require_form_version(form_xml_text, version)

    write_guard = function_body(
        object_text, "Адапт_ЭтоКонтурКопииДляПодготовкиОбновления"
    )
    assert "Адапт_ЭтоКонтурPostgres4ДляПодготовкиОбновления()" in write_guard
    assert "Адапт_ЭтоКонтурPostgres3ДляСвежейКопии()" in write_guard

    for name in (
        "Адапт_ИсправитьКарантинРегламентированныхОтчетов36_14",
        "Адапт_ИсправитьКарантинПричинУвольненияПФР36_14",
        "Адапт_ИсправитьКарантинОснованийУвольнения36_14",
    ):
        body = function_body(object_text, name)
        assert "Адапт_ЭтоКонтурКопииДляПодготовкиОбновления()" in body
        assert "PASS_ALREADY_APPLIED" in body
        assert "STOP_ROLLBACK" in body
        assert "НачатьТранзакцию()" in body
        assert "ЗафиксироватьТранзакцию()" in body
        assert "ОтменитьТранзакцию()" in body

    pipeline = function_body(
        object_text,
        "Адапт_ЗавершитьБлокерыОбновления36_14СвежейКопии",
    )
    required_in_order = (
        "Адапт_ИсправитьКарантинРегламентированныхОтчетов36_14()",
        "Адапт_ИсправитьКарантинПричинУвольненияПФР36_14()",
        "Адапт_ИсправитьКарантинОснованийУвольнения36_14()",
        "Адапт_СформироватьПредконтрольОбновления36_14()",
    )
    positions = [pipeline.index(marker) for marker in required_in_order]
    assert positions == sorted(positions)

    for marker in (
        "Адапт_ЭтоКонтурPostgres3ДляСвежейКопии()",
        "STOP_CONTOUR",
        "STOP_TRANSACTION",
        "STOP_24_3",
        "STOP_24_5",
        "STOP_24_7",
        "STOP_24_1",
        "PASS_UPDATE_BLOCKERS",
        "СТ. 336.3",
        "СТ. 337",
    ):
        assert marker in pipeline, marker

    assert "НачатьТранзакцию()" not in pipeline
    assert "ЗафиксироватьТранзакцию()" not in pipeline
    assert "ОтменитьТранзакцию()" not in pipeline
    assert "ВыполнитьПрямойSQL" not in pipeline
    assert "ЗаменитьСсылки" not in pipeline

    route = "fresh_copy_update_blockers_fix"
    assert route in form_text
    assert (
        "ОбработкаОбъект.Адапт_ЗавершитьБлокерыОбновления36_14СвежейКопии()"
        in form_text
    )
    assert "Процедура ЗавершитьБлокерыОбновления36_14СвежейКопии(Команда)" in form_text

    background_dispatcher = function_body(
        object_text,
        "Адапт_ВыполнитьДолгуюОперациюПоКоду",
    )
    background_route = re.search(
        r'ИначеЕсли\s+РежимЭтапа\s*=\s*"fresh_copy_update_blockers_fix"'
        r'\s+Тогда\s+Результат\s*=\s*'
        r'Адапт_ЗавершитьБлокерыОбновления36_14СвежейКопии\(\)\s*;',
        background_dispatcher,
        flags=re.DOTALL,
    )
    assert background_route is not None

    button = find_named(
        form_root,
        "Button",
        "ЗавершитьБлокерыОбновления36_14СвежейКопииТесты",
    )
    command_name = next(
        (child.text for child in button if local_name(child) == "CommandName"),
        None,
    )
    assert (
        command_name
        == "Form.Command.ЗавершитьБлокерыОбновления36_14СвежейКопии"
    )
    command = find_named(
        form_root,
        "Command",
        "ЗавершитьБлокерыОбновления36_14СвежейКопии",
    )
    action = next(
        (child.text for child in command if local_name(child) == "Action"),
        None,
    )
    assert action == "ЗавершитьБлокерыОбновления36_14СвежейКопии"

    print(
        "PASS: v25-123.10; [25.4]=FreshCopyTarget-only sequential orchestrator; "
        "steps=24.3/24.5/24.7/24.1; child transactions=3; "
        "outer transaction=0; stop-on-first-error; "
        "form+background-dispatcher=connected"
    )


if __name__ == "__main__":
    main()
