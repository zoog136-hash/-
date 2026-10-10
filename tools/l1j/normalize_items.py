"""Extend an existing normalized registry from audited A3 rows, never a game database."""
from __future__ import annotations
import argparse
import collections
import copy
import json
from pathlib import Path


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def normalize(previous: Path, source: Path, output: Path):
    records = read(previous)
    indexed = {(r['source_type'], int(r['source_item_id'])): r for r in records}
    if len(indexed) != len(records):
        raise ValueError('Duplicate namespaced source IDs in previous registry')
    shops, drops = collections.defaultdict(list), collections.defaultdict(list)
    for row in read(source / 'shop.json'):
        shops[int(row['item_id'])].append(row)
    for row in read(source / 'droplist.json'):
        drops[int(row['itemId'])].append(row)
    result, corrections, source_keys = [], [], set()
    for table in ('weapon', 'armor', 'etcitem'):
        for raw in read(source / (table + '.json')):
            key = (table, int(raw['item_id']))
            if key in source_keys or key not in indexed:
                raise ValueError(f'Duplicate or previously missing source identity: {key}')
            source_keys.add(key)
            row = copy.deepcopy(indexed[key])
            if row['display_name'] != raw['desc_kr']:
                corrections.append({'source_id': row['canonical_candidate_id'],
                                    'previous_name': row['display_name'], 'source_name': raw['desc_kr']})
                row['previous_display_name'] = row['display_name']
            row['display_name'] = raw['desc_kr']
            # Preserve previous fields for provenance, but make audited SQL fields authoritative.
            row['stats'].update(raw)
            row['shop_records'] = shops[key[1]]
            row['drop_records'] = drops[key[1]]
            row['identity_status'] = 'CANDIDATE_UNVERIFIED'
            row['gameplay_stats_applied'] = False
            row['weight_units'] = 'SOURCE_L1J_RAW_NOT_GAME_GRAMS'
            row['slot_conversion_status'] = 'RAW_SOURCE_ONLY'
            row['grade_policy'] = 'PRESERVE_EXISTING_TWILIGHT_GRADE'
            result.append(row)
    if source_keys != set(indexed):
        raise ValueError('Current source and previous registry identities differ')
    ids = {key[1] for key in source_keys}
    unresolved = {'shops': [r for k, rows in shops.items() if k not in ids for r in rows],
                  'drops': [r for k, rows in drops.items() if k not in ids for r in rows]}
    report = {'items': len(result), 'name_corrections': corrections,
              'unresolved_reference_counts': {k: len(v) for k, v in unresolved.items()},
              'unresolved_references': unresolved, 'game_ids_changed': 0, 'game_stats_changed': 0}
    output.mkdir(parents=True, exist_ok=True)
    for name, value in [('a3_items_normalized.json', result), ('item_identity_check.json', report)]:
        (output / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in report.items() if k != 'unresolved_references'}, ensure_ascii=False))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--previous', type=Path, required=True)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    normalize(args.previous, args.source, args.output)
