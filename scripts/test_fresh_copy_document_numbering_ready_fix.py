#!/usr/bin/env python3
"""Статический контракт [18.8] для свежей копии FreshCopyTarget.

Проверяет только XML/BSL-исходники. Он не подключается к 1С и не выполняет запись.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OBJECT_MODULE = ROOT / "src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная/Ext/ObjectModule.bsl"
FORM_MODULE = ROOT / "src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная/Forms/Форма/Ext/Form/Module.bsl"
FORM_XML = ROOT / "src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная/Forms/Форма/Ext/Form.xml"
FUNCTION = "Адапт_ИсправитьREADYНумерациюДокументовСвежейКопии"


def function_body(source: str, name: str) -> str:
    match = re.search(
        rf"^Функция {re.escape(name)}\(\) Экспорт\n(?P<body>.*?)^КонецФункции$",
        source,
        re.MULTILINE | re.DOTALL,
    )
    if not match:
        raise AssertionError(f"Не найдена функция {name}")
    return match.group("body")


def require(text: str, fragment: str, reason: str) -> None:
    if fragment not in text:
        raise AssertionError(f"{reason}: отсутствует {fragment!r}")


def main() -> int:
    object_module = OBJECT_MODULE.read_text(encoding="utf-8-sig")
    form_module = FORM_MODULE.read_text(encoding="utf-8-sig")
    form_xml = FORM_XML.read_text(encoding="utf-8-sig")
    body = function_body(object_module, FUNCTION)

    require(object_module, 'Возврат "v25-123.10";', "Версия обработки")
    require(body, 'ОжидаемыйMD5 = "DE9795874164AA1A85F4E2296F00DB3F";', "public sample MD5 [18.0]")
    for fragment in (
        "ОжидаетсяДокументовПлана = 3;",
        "ОжидаетсяREADY = 3;",
        "ОжидаетсяKEEP = 0;",
        "ОжидаетсяREVIEW = 0;",
        "ОжидаетсяSTOP = 0;",
        "ОжидаетсяОстатокПланаПосле = 0;",
        "ОжидаетсяREVIEWПосле = 0;",
        "ОжидаетсяSTOPПосле = 0;",
        'ОжидаемыйMD5После = "452B7D0F1046EEDD1BE5498A8D401D4F";',
        "РазмерПакета = 500;",
    ):
        require(body, fragment, "Неполный доказанный baseline")

    require(
        body,
        "Адапт_ЭтоКонтурPostgres3ДляСвежейКопии()",
        "Запись вне целевого контура",
    )
    require(body, "Если ОбъектДокумента.Метаданные().Имя", "Защита типа документа")
    require(
        body,
        '"икОткрытиеЛицевогоСчета"',
        "Защита бизнес-номеров лицевых счетов",
    )
    require(
        body,
        "STOP_LS_OPENING_NUMBER",
        "Отказ от записи номера открытия ЛС",
    )
    require(
        body,
        "ОбъектДокумента.Номер = СтрокаПлана.ЦелевойНомер;",
        "Точная запись номера",
    )
    require(
        body,
        "ОбъектДокумента.Записать(РежимЗаписиДокумента.Запись);",
        "Штатная объектная запись",
    )
    require(body, "НачатьТранзакцию();", "Пакетная транзакция")
    require(body, "ОтменитьТранзакцию();", "Откат ошибочного пакета")
    require(body, "ЗафиксироватьТранзакцию();", "Фиксация корректного пакета")
    require(body, "STOP_POSTWRITE", "Адресный постконтроль записи")
    require(body, "STOP_POSTCONTROL", "Постконтроль полного плана")
    require(body, "ПланУжеПрименен", "Защита от повторной записи")
    require(body, "PARTIAL_ALREADY_APPLIED", "Отчет о доказанном постсостоянии")
    if "ОжидаетсяОстатокПлана = 1547;" in body:
        raise AssertionError("Устаревший постконтроль 1547 не должен оставаться в [18.8]")
    if body.count("Адапт_СформироватьАдресныйPreviewНумерацииДокументов(") != 2:
        raise AssertionError("Должны быть ровно preflight и полный постконтроль")
    if 'Результат.Вставить("ТаблицаПлана"' in body:
        raise AssertionError("Нельзя передавать ТаблицаЗначений через результат длительной операции")
    for forbidden in (
        "РежимЗаписиДокумента.Проведение",
        ".Провести(",
        "Выполнить(",
    ):
        if forbidden in body:
            raise AssertionError(f"Запрещенная операция в [18.8]: {forbidden}")

    command = "ИсправитьREADYНумерациюДокументовСвежейКопии"
    server_operation = command + "НаСервере"
    require(form_xml, f'name="{command}Тесты"', "Кнопка [18.8]")
    require(form_xml, f'name="{command}"', "Команда формы [18.8]")
    require(form_xml, "[18.8] Исправить READY FreshCopyTarget", "Название кнопки")
    require(form_module, f"Процедура {command}(Команда)", "Клиентская команда")
    require(form_module, f'"{server_operation}"', "Фоновый запуск")
    require(form_module, f"Функция {server_operation}()", "Серверный мост")
    require(
        object_module,
        f'КодОперации =\n\t\t"{server_operation}"',
        "Диспетчер длительной операции",
    )

    print("PASS: [18.8] FreshCopyTarget READY numbering repair static contract")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        raise SystemExit(1)
