#!/usr/bin/env python3
"""Auditable L1J SQL -> opt-in TWILIGHT equipment drop registry.

L1J 'chance' is a relative weight WITHIN an already-successful TWILIGHT
equipment-grade roll. It does not replace or multiply TWILIGHT grade odds.
Unmapped source IDs are never guessed.
"""
import argparse
import collections
import hashlib
import json
import re
from pathlib import Path
from zipfile import ZipFile

INSERT = re.compile(r'INSERT\s+INTO\s+`?droplist`?\s+VALUES\s*(.*?);', re.I | re.S)
ROW = re.compile(r'\(([^()]*)\)')

def parse_sql(sql):
    for statement in INSERT.finditer(sql):
        for match in ROW.finditer(statement.group(1)):
            source = match.group(1).strip()
            values = [v.strip().strip("'") for v in source.split(',')]
            if len(values) != 5 or not all(re.fullmatch(r'\d+', v) for v in values):
                raise ValueError('Unsupported SQL tuple: ' + source[:120])
            mob, item, lo, hi, chance = map(int, values)
            if mob <= 0 or item <= 0 or lo < 0 or hi < 0 or lo > 100000000 or hi > 100000000 or not 0 <= chance <= 1000000000:
                raise ValueError('Out of range SQL tuple: ' + source[:120])
            yield mob, item, lo, hi, chance

def convert(raw, id_map, source):
    rows = list(parse_sql(raw.decode('utf-8-sig')))
    monsters = id_map.get('monster_id_to_twilight', {})
    items = id_map.get('item_id_to_twilight', {})
    if not isinstance(monsters, dict) or not isinstance(items, dict):
        raise ValueError('Mapping requires monster_id_to_twilight and item_id_to_twilight dictionaries')
    registry = collections.defaultdict(list)
    rejected = collections.Counter()
    mob_ids, item_ids = set(), set()
    for mob, item, minimum, maximum, chance in rows:
        mob_ids.add(mob)
        item_ids.add(item)
        monster_name = monsters.get(str(mob))
        item_record = items.get(str(item))
        if not isinstance(monster_name, str) or not monster_name.strip():
            rejected['unmapped_monster'] += 1
            continue
        if not isinstance(item_record, dict) or not str(item_record.get('name', '')):
            rejected['unmapped_item'] += 1
            continue
        if item_record.get('kind') != 'equipment':
            rejected['non_equipment'] += 1
            continue
        if minimum <= 0 or maximum < minimum:
            rejected['invalid_quantity'] += 1
            continue
        if chance <= 0:
            rejected['zero_chance'] += 1
            continue
        registry[monster_name].append({
            'item_name': item_record['name'], 'weight': min(chance, 1000000),
            'min': min(minimum, 10000), 'max': min(maximum, 10000),
            'l1j_monster_id': mob, 'l1j_item_id': item
        })
    output = {'schema_version': 1, 'source': source, 'monsters': dict(sorted(registry.items()))}
    report = {
        'input_sha256': hashlib.sha256(raw).hexdigest(),
        'source': source, 'source_rows': len(rows),
        'source_chance_over_one_million': sum(chance > 1000000 for _, _, _, _, chance in rows),
        'unique_source_monster_ids': len(mob_ids), 'unique_source_item_ids': len(item_ids),
        'explicit_monster_id_mappings': len(monsters), 'explicit_item_id_mappings': len(items),
        'live_equipment_rows': sum(map(len, registry.values())),
        'live_monster_names': len(registry),
        'rejected_rows_by_reason': dict(sorted(rejected.items())),
        'unmapped_monster_ids_sample': sorted(mob_ids - {int(x) for x in monsters if str(x).isdigit()})[:50],
        'unmapped_item_ids_sample': sorted(item_ids - {int(x) for x in items if str(x).isdigit()})[:50],
        'notes': [
            'Never use fuzzy name matching',
            'TWILIGHT original rarity odds remain authoritative',
            'Non-equipment rows are excluded from the equipment roll',
            'Check input licenses before distribution',
        ]
    }
    return output, report

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--zip', required=True)
    p.add_argument('--sql-member', required=True)
    p.add_argument('--id-map', required=True)
    p.add_argument('--output', required=True)
    p.add_argument('--report', required=True)
    args = p.parse_args()
    with ZipFile(args.zip) as archive:
        raw = archive.read(args.sql_member)
    mapping = json.loads(Path(args.id_map).read_text(encoding='utf-8'))
    output, report = convert(raw, mapping, f'{Path(args.zip).name}:{args.sql_member}')
    Path(args.output).write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    Path(args.report).write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('Parsed', report['source_rows'], 'source rows;', report['live_equipment_rows'],
          'mapped equipment rows across', report['live_monster_names'], 'monsters')

if __name__ == '__main__':
    main()
