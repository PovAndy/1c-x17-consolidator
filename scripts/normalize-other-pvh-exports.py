#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
from collections import Counter, defaultdict
from pathlib import Path

REQUIRED_PVH = [
    'base_alias', 'ref', 'code', 'description', 'value_type', 'parent_ref', 'view_type_ref', 'deletion_mark'
]
REQUIRED_REG = [
    'base_alias', 'period', 'object_ref', 'object_name', 'char_ref', 'char_description', 'value_type', 'value_presentation'
]

RESTORE_MAP_FIELDS = [
    'broken_internal_key',
    'broken_uuid_guess',
    'target_description',
    'target_code',
    'target_ref',
    'target_base_alias',
    'comment',
]

KNOWN_BROKEN_KEYS = [
    {
        'broken_internal_key': 'ab78e89c257e84aa11f068788fea4cf4',
        'broken_uuid_guess': '8fea4cf4-6878-11f0-ab78-e89c257e84aa',
        'target_description': 'Марка прибора учёта',
        'target_code': '000000040',
        'target_ref': '',
        'target_base_alias': '',
        'comment': 'Автосид из анализа x17; если target_ref пуст, обработка ищет живой элемент по description+code.',
    },
]


def read_csv(path: Path, required: list[str]) -> list[dict[str, str]]:
    with path.open('r', encoding='utf-8-sig', newline='') as fh:
        reader = csv.DictReader(fh)
        if reader.fieldnames is None:
            raise SystemExit(f'Empty CSV: {path}')
        missing = [name for name in required if name not in reader.fieldnames]
        if missing:
            raise SystemExit(f'Missing columns in {path}: {", ".join(missing)}')
        rows = []
        for row in reader:
            rows.append({k: (v or '').strip() for k, v in row.items()})
        return rows


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('w', encoding='utf-8', newline='') as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--inbox', required=True)
    parser.add_argument('--out', required=True)
    args = parser.parse_args()

    inbox = Path(args.inbox)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    all_pvh: list[dict[str, str]] = []
    all_reg: list[dict[str, str]] = []

    for base_dir in sorted(p for p in inbox.iterdir() if p.is_dir()):
        pvh_path = base_dir / 'pvh_other.csv'
        reg_path = base_dir / 'reg_other_chars.csv'
        if pvh_path.exists():
            all_pvh.extend(read_csv(pvh_path, REQUIRED_PVH))
        if reg_path.exists():
            all_reg.extend(read_csv(reg_path, REQUIRED_REG))

    write_csv(out / 'all_pvh_other.csv', REQUIRED_PVH, all_pvh)
    write_csv(out / 'all_reg_other_chars.csv', REQUIRED_REG, all_reg)

    by_desc = Counter()
    by_code = Counter()
    by_ref_usage = Counter()
    desc_code_pairs = defaultdict(set)
    ref_to_desc = {}

    for row in all_pvh:
        desc = row['description']
        code = row['code']
        ref = row['ref']
        by_desc[desc] += 1
        by_code[code] += 1
        desc_code_pairs[desc].add(code)
        ref_to_desc[ref] = desc

    for row in all_reg:
        by_ref_usage[row['char_ref']] += 1

    summary_rows = []
    for ref, desc in sorted(ref_to_desc.items(), key=lambda x: (x[1], x[0])):
        summary_rows.append({
            'ref': ref,
            'description': desc,
            'code': next((r['code'] for r in all_pvh if r['ref'] == ref), ''),
            'base_alias': next((r['base_alias'] for r in all_pvh if r['ref'] == ref), ''),
            'value_type': next((r['value_type'] for r in all_pvh if r['ref'] == ref), ''),
            'usage_count': str(by_ref_usage.get(ref, 0)),
        })

    write_csv(
        out / 'pvh_usage_summary.csv',
        ['ref', 'description', 'code', 'base_alias', 'value_type', 'usage_count'],
        summary_rows,
    )

    desc_rows = []
    for desc, count in sorted(by_desc.items()):
        desc_rows.append({
            'description': desc,
            'pvh_rows': str(count),
            'codes_seen': ', '.join(sorted(desc_code_pairs[desc])),
            'register_rows': str(sum(by_ref_usage.get(r['ref'], 0) for r in all_pvh if r['description'] == desc)),
        })

    write_csv(
        out / 'description_summary.csv',
        ['description', 'pvh_rows', 'codes_seen', 'register_rows'],
        desc_rows,
    )

    restore_map_rows = []
    for row in KNOWN_BROKEN_KEYS:
        seeded = dict(row)
        matching_rows = [
            pvh_row for pvh_row in all_pvh
            if pvh_row['description'] == row['target_description']
            and pvh_row['code'] == row['target_code']
            and pvh_row['deletion_mark'].lower() not in ('true', 'истина', '1', 'yes')
        ]
        unique_refs = sorted({match['ref'] for match in matching_rows if match['ref']})
        unique_bases = sorted({match['base_alias'] for match in matching_rows if match['base_alias']})
        if len(unique_bases) == 1:
            seeded['target_base_alias'] = unique_bases[0]
        if not matching_rows:
            seeded['comment'] += ' В текущих выгрузках совпадение по description+code не найдено.'
        elif len(unique_refs) == 1:
            seeded['comment'] += f' В исходных выгрузках найден ref {unique_refs[0]}; target_ref оставлен пустым специально, чтобы обработка искала живой элемент уже в целевой базе.'
        else:
            seeded['comment'] += f' В выгрузках найдено несколько refs ({", ".join(unique_refs)}); target_ref оставлен пустым.'
        restore_map_rows.append(seeded)

    write_csv(out / 'restore_map.csv', RESTORE_MAP_FIELDS, restore_map_rows)

    notes = []
    notes.append('# Сводка по выгрузкам прочих характеристик ПУ')
    notes.append('')
    notes.append(f'- Баз обработано: {len([p for p in inbox.iterdir() if p.is_dir()])}')
    notes.append(f'- Элементов ПВХ: {len(all_pvh)}')
    notes.append(f'- Строк регистра: {len(all_reg)}')
    notes.append('')
    notes.append('## Подозрительные описания')
    notes.append('')
    for desc, count in sorted(by_desc.items(), key=lambda x: (-x[1], x[0])):
        if count > 1:
            notes.append(f'- {desc}: вариантов ПВХ={count}; коды={", ".join(sorted(desc_code_pairs[desc]))}')
    notes.append('')
    notes.append('## Дальше')
    notes.append('')
    notes.append('1. Сопоставить битые ключи полной базы с живыми описаниями/кодами из summary.')
    notes.append('2. Выбрать канонические refs.')
    notes.append('3. Проверить автоматически сгенерированный restore_map.csv и при необходимости дополнить его.')
    notes.append('4. Загрузить восстановление в обработку.')
    (out / 'README.md').write_text('\n'.join(notes) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
