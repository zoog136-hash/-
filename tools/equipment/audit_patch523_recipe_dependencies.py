#!/usr/bin/env python3
"""Audit ID-specific crafting prerequisites without registering or inventing items.

The output contains private source references and belongs outside the Git tree.
PR238 drop membership is evidence of an identity prerequisite, not proof that
another branch/pack has been installed in the current game.
"""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import zlib

from build_patch523_rules import read_source


def audit(tables, rules, catalog, drops):
    by_id, by_name = defaultdict(list), Counter()
    for record in catalog['아이템']:
        by_name[record['name']] += 1
        if record.get('source') == 'inven':
            by_id[str(record.get('sourceId', ''))].append(record)
    source_items = {str(row['ID']): row for row in tables['ItemClass']}
    descriptions = {row['ID']: row['Description'].strip() for row in tables['DescData_Korean']}
    drop_ids = {str(row['ItemClassID']) for row in drops}
    constraints = {row['ItemCraftID']: row for row in tables['ItemCraftView']}
    dependents, recipes = defaultdict(list), {}
    for craft_id, admission in rules['recipe_admission'].items():
        required = defaultdict(list)
        for direction in ('inputs', 'outputs'):
            for row in rules['raw_recipes'][direction].get(craft_id, []):
                key = str(row['ItemClassID'])
                if key in ('0', '26', '549') or key not in source_items:
                    continue
                records = by_id.get(key, [])
                if len(records) == 1 and by_name[records[0]['name']] == 1:
                    continue
                required[key].append({
                    'direction': direction, 'row_id': row['ID'],
                    'amount': row['Amount'], 'enchant': row['Enchant'],
                    'bless_code': row['ItemBlessCodeID'],
                    **({'slot_index': row['SlotIndex']} if direction == 'inputs' else {
                        'output_type': row['ItemCraftOutputTypeID'], 'probability': row['Probability']})})
        if not required:
            continue
        recipes[craft_id] = {
            'current_admission': admission,
            'required_item_ids': sorted(required, key=int),
            'original_server_limit_set_id': constraints[int(craft_id)]['ServerLimitSetID'],
            'original_restrictions_preserved': rules['raw_recipes']['restrictions'].get(craft_id, []),
            'all_missing_ids_in_pr238_drop_membership': set(required) <= drop_ids,
            'first_blocker_is_catalog': admission['reason'] == 'missing_or_ambiguous_catalog_identity',
        }
        for key, contracts in required.items():
            dependents[key].append({'craft_id': int(craft_id), 'contracts': contracts})
    dependencies = {}
    for key, consumers in sorted(dependents.items(), key=lambda pair: int(pair[0])):
        original = source_items.get(key, {})
        dependencies[key] = {
            'item_class_id': int(key),
            'source_name': descriptions.get(original.get('DescID'), ''),
            'current_catalog_status': 'missing_exact_id' if not by_id.get(key) else 'ambiguous_name_or_id',
            'pr238_source_drop_membership': key in drop_ids,
            'required_registered_source_id': 'm523:item:' + key if key in drop_ids else None,
            'pr238_contract': 'exact ID with separate ownership key; preserve blessing variants' if key in drop_ids else
                'not proved by drop membership; may be reward dependency; actual shared catalog required',
            'consumers': consumers,
        }
    return {
        'schema': 'patch523-recipe-dependencies-v1',
        'pr238_contract_sha': '58b07798753d56f87e08cd0cc95febffe694af37',
        'pr238_pack_bytes_verified_by_this_audit': False,
        'no_other_pr_merged': True,
        'summary': {
            'active_recipes': len(rules['recipes']), 'rejected_recipes': len(rules['recipe_admission']),
            'blocked_recipes_with_catalog_dependencies': len(recipes),
            'catalog_first_blocked_recipes': sum(r['first_blocker_is_catalog'] for r in recipes.values()),
            'catalog_first_all_missing_ids_in_pr238_drops': sum(r['first_blocker_is_catalog'] and r['all_missing_ids_in_pr238_drop_membership'] for r in recipes.values()),
            'missing_or_ambiguous_item_ids': len(dependencies),
            'item_ids_proved_in_pr238_drop_membership': sum(x['pr238_source_drop_membership'] for x in dependencies.values()),
        },
        'recipes': recipes, 'item_dependencies': dependencies,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--rules', type=Path, required=True)
    parser.add_argument('--catalog', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.resolve().is_relative_to(Path(__file__).resolve().parents[2]):
        raise ValueError('private source audit must remain outside public Git')
    tables, _ = read_source(args.source / 'content')
    raw = (args.source / 'content/NpcItemDropView.json').read_bytes()
    entry = next(row for row in json.loads((args.source / 'index.json').read_text(encoding='utf-8-sig'))
                 if row['path'] == 'content/NpcItemDropView.json')
    drops = json.loads(raw.decode('utf-8-sig'))['rows']
    if len(raw) != entry['bytes'] or hashlib.sha256(raw).hexdigest() != entry['sha256'] or f'{zlib.crc32(raw):08x}' != entry['crc32'] or len(drops) != entry['row_count']:
        raise ValueError('drop table differs from validated original index')
    rules = json.loads(args.rules.read_text())
    if rules.get('snapshot') != 'patch523' or rules.get('catalog_sha256') != hashlib.sha256(args.catalog.read_bytes()).hexdigest():
        raise ValueError('rules and current catalog do not match')
    result = audit(tables, rules, json.loads(args.catalog.read_text()), drops)
    result['source_drop_table_sha256'] = entry['sha256']
    result['rules_sha256'] = hashlib.sha256(args.rules.read_bytes()).hexdigest()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(result['summary'], ensure_ascii=False))


if __name__ == '__main__':
    main()
