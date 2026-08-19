#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import re
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path

NS = {
    'v8': 'http://v8.1c.ru/8.1/data/enterprise/current-config',
    'core': 'http://v8.1c.ru/data',
}
XSI_TYPE = '{http://www.w3.org/2001/XMLSchema-instance}type'

PVH_FIELDS = ['base_alias','ref','code','description','value_type','parent_ref','view_type_ref','deletion_mark']
REG_FIELDS = ['base_alias','period','object_ref','object_name','char_ref','char_description','value_type','value_presentation']


def normalize_base_alias(name: str) -> str:
    stem = Path(name).stem
    stem = re.sub(r'^Слой\d+_', '', stem, flags=re.IGNORECASE)
    stem = stem.replace('х', 'x').replace('Х', 'x')
    stem = stem.replace('+', '_').replace('-', '_')
    stem = re.sub(r'__+', '_', stem)
    return stem.lower()


def strip_ns(tag: str) -> str:
    return tag.split('}', 1)[1] if '}' in tag else tag


def first_text(elem: ET.Element | None, path: str) -> str:
    if elem is None:
        return ''
    found = elem.find(path, NS)
    if found is None or found.text is None:
        return ''
    return found.text.strip()


def format_value_type(value_type_elem: ET.Element | None) -> str:
    if value_type_elem is None:
        return ''
    types = []
    for child in value_type_elem:
        if strip_ns(child.tag) == 'Type' and child.text:
            txt = child.text.strip()
            txt = txt.replace('v8:', '').replace('xs:', '')
            types.append(txt)
    return ' | '.join(types)


def parse_xml_file(path: Path):
    base_alias = normalize_base_alias(path.name)
    pvh_rows = []
    reg_rows = []
    object_names: dict[str, str] = {}
    pvh_meta: dict[str, tuple[str,str]] = {}

    parser = ET.iterparse(path, events=('start', 'end'))
    depth = 0
    for event, elem in parser:
        if event == 'start':
            depth += 1
            continue

        tag = strip_ns(elem.tag)

        if tag in {'CatalogObject.икИндивидуальныеПриборыУчета', 'CatalogObject.икКоллективныеПриборыУчета', 'CatalogObject.икПриборыУчетаГИСЖКХ'}:
            ref = first_text(elem, 'v8:Ref')
            desc = first_text(elem, 'v8:Description') or first_text(elem, 'v8:Наименование') or first_text(elem, 'v8:Name')
            if ref:
                object_names[ref] = desc
            if depth <= 2:
                elem.clear()
            depth -= 1
            continue

        if tag == 'ChartOfCharacteristicTypesObject.икХарактеристикиПрочихОбъектов':
            ref = first_text(elem, 'v8:Ref')
            row = {
                'base_alias': base_alias,
                'ref': ref,
                'code': first_text(elem, 'v8:Code'),
                'description': first_text(elem, 'v8:Description'),
                'value_type': format_value_type(elem.find('v8:ValueType', NS)),
                'parent_ref': first_text(elem, 'v8:Parent'),
                'view_type_ref': first_text(elem, 'v8:ВидОбъекта'),
                'deletion_mark': first_text(elem, 'v8:DeletionMark').lower() or 'false',
            }
            if ref:
                pvh_rows.append(row)
                pvh_meta[ref] = (row['description'], row['value_type'])
            if depth <= 2:
                elem.clear()
            depth -= 1
            continue

        if tag == 'InformationRegisterRecordSet.икХарактеристикиПрочихОбъектов':
            record = elem.find('v8:Record', NS)
            if record is not None:
                obj_ref = first_text(record, 'v8:Объект')
                char_ref = first_text(record, 'v8:Характеристика')
                value_elem = record.find('v8:Значение', NS)
                value_type = ''
                value_presentation = ''
                if value_elem is not None:
                    value_type = value_elem.attrib.get(XSI_TYPE, '').replace('v8:', '').replace('xs:', '')
                    value_presentation = (value_elem.text or '').strip()
                char_description = ''
                if char_ref in pvh_meta:
                    char_description = pvh_meta[char_ref][0]
                row = {
                    'base_alias': base_alias,
                    'period': '',
                    'object_ref': obj_ref,
                    'object_name': object_names.get(obj_ref, ''),
                    'char_ref': char_ref,
                    'char_description': char_description,
                    'value_type': value_type,
                    'value_presentation': value_presentation,
                }
                if char_ref or obj_ref or value_presentation:
                    reg_rows.append(row)
            if depth <= 2:
                elem.clear()
            depth -= 1
            continue

        if depth <= 2:
            elem.clear()
        depth -= 1

    for row in reg_rows:
        if not row['char_description'] and row['char_ref'] in pvh_meta:
            row['char_description'] = pvh_meta[row['char_ref']][0]
        if not row['object_name'] and row['object_ref'] in object_names:
            row['object_name'] = object_names[row['object_ref']]

    return base_alias, pvh_rows, reg_rows


def write_csv(path: Path, fields, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def dedupe_rows(rows, key_fields):
    seen = set()
    out = []
    for row in rows:
        key = tuple(row.get(k, '') for k in key_fields)
        if key in seen:
            continue
        seen.add(key)
        out.append(row)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--xml-dir', required=True)
    ap.add_argument('--out-inbox', required=True)
    args = ap.parse_args()

    xml_dir = Path(args.xml_dir)
    out_inbox = Path(args.out_inbox)

    grouped_pvh = defaultdict(list)
    grouped_reg = defaultdict(list)

    for xml_path in sorted(xml_dir.glob('*.xml')):
        base_alias, pvh_rows, reg_rows = parse_xml_file(xml_path)
        grouped_pvh[base_alias].extend(pvh_rows)
        grouped_reg[base_alias].extend(reg_rows)

    for base_alias in sorted(set(grouped_pvh) | set(grouped_reg)):
        base_dir = out_inbox / base_alias
        pvh_rows = dedupe_rows(grouped_pvh[base_alias], ['ref','code','description','value_type','parent_ref','view_type_ref','deletion_mark'])
        reg_rows = dedupe_rows(grouped_reg[base_alias], ['object_ref','char_ref','value_type','value_presentation'])
        write_csv(base_dir / 'pvh_other.csv', PVH_FIELDS, pvh_rows)
        write_csv(base_dir / 'reg_other_chars.csv', REG_FIELDS, reg_rows)
        print(f'{base_alias}: pvh={len(pvh_rows)} reg={len(reg_rows)}')


if __name__ == '__main__':
    main()
