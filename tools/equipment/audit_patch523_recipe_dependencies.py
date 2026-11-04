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


def audit(tables, rules, catalog, drops, binding_catalog=None):
    by_id, by_name = defaultdict(list), Counter()
    for record in catalog['아이템']:
        by_name[record['name']] += 1
        if record.get('source') == 'inven':
            by_id[str(record.get('sourceId', ''))].append(record)
    for record in (binding_catalog or {}).get('아이템', []):
        value = record.get('source_item_class_id')
        if isinstance(value,bool) or not isinstance(value,(int,float)) or value<=0 or value!=int(value):
            continue
        key = str(int(value))
        canonical = rules.get('items', {}).get(key, {}).get('catalog_record', {})
        if (record.get('source')=='lineagem_patch523' and record.get('source_m_native_item') is True
            and canonical.get('source_m_native_item') is True
            and record.get('sourceId')==canonical.get('sourceId')=='m523:item:'+key
            and record.get('name')==canonical.get('name')):
            by_id[key]=[record]
            by_name[record['name']]+=1
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
    dates = {r['ID']:r for r in tables.get('DateTimes_Korean',[])}
    bonuses = {r['ID']:r for r in tables['Bonus']}
    bonus_types = {r['ID']:r for r in tables['BonusType']}
    permanent_titles = defaultdict(list)
    for link in tables['ItemBonus']:
        bonus = bonuses[link['BonusID']]
        if bonus_types[bonus['BonusTypeID']]['Name']=='ItemCraftPermanentAppellationID':
            permanent_titles[str(link['ItemClassID'])].append({'item_bonus_id':link['ID'],'bonus':bonus})
    rejected_detail = {}
    # Every rejected recipe is classified, including ones whose first error
    # precedes a separate catalog/server/date prerequisite. Flags overlap.
    for craft_id, admission in rules['recipe_admission'].items():
        view = constraints[int(craft_id)]
        required_ids = {str(r['ItemClassID']) for direction in ('inputs','outputs')
                        for r in rules['raw_recipes'][direction].get(craft_id,[]) if r['ItemClassID']>0}
        flags = {}
        missing_source = sorted(required_ids-source_items.keys(),key=int)
        tests = sorted((i for i in required_ids if source_items.get(i,{}).get('TestItem')),key=int)
        if missing_source: flags['missing_source_item_class_ids'] = missing_source
        if tests: flags['source_test_item_ids'] = tests
        if view['ServerLimitSetID']: flags['source_server_limit_set_id'] = view['ServerLimitSetID']
        for field in ('IsCoalitionItem','NoRepeat','IsBelowLevelLimit'):
            if view.get(field): flags[field] = view[field]
        if view.get('LevelLimitValue'): flags['source_level_limit_value'] = view['LevelLimitValue']
        restrictions = rules['raw_recipes']['restrictions'].get(craft_id,[])
        if restrictions: flags['source_restriction_contracts'] = restrictions
        if (view['EffectiveFrom'],view['EffectiveTo'],view['CraftTimeTypeID']) != (1,3,1):
            flags['source_calendar'] = {'from_id':view['EffectiveFrom'],'to_id':view['EffectiveTo'],
                'craft_time_type_id':view['CraftTimeTypeID'],
                'from_row':dates.get(view['EffectiveFrom']), 'to_row':dates.get(view['EffectiveTo']),
                'timezone_in_source':False, 'server_reset_inferred':False}
        protection = sorted((i for i in required_ids if source_items.get(i,{}).get('CategoryID')==10204),key=int)
        if protection: flags['source_protection_category_item_ids'] = protection
        titles = {i:permanent_titles[i] for i in sorted(required_ids,key=int) if i in permanent_titles}
        if titles: flags['requires_source_title_acquisition_and_ownership_contract'] = titles
        rejected_detail[craft_id] = {'current_admission':admission,'source_flags':flags,
            'missing_catalog_ids':recipes.get(craft_id,{}).get('required_item_ids',[]),
            'input_output_source_ids':sorted(required_ids,key=int),
            'executable_not_claimed':True}
    result = {
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
        'all_rejected_recipes': rejected_detail,
    }
    result['summary'].update(all_rejected_recipes_classified=len(rejected_detail),
        rejection_first_reason_counts=dict(Counter(r['current_admission']['reason'] for r in rejected_detail.values())),
        overlapping_source_flag_counts=dict(Counter(k for r in rejected_detail.values() for k in r['source_flags'])),
        source_calendar_rows_present=sum(bool(r['source_flags'].get('source_calendar',{}).get('from_row')) and bool(r['source_flags'].get('source_calendar',{}).get('to_row')) for r in rejected_detail.values()))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--rules', type=Path, required=True)
    parser.add_argument('--catalog', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--binding-catalog', type=Path)
    parser.add_argument('--native-bin', type=Path)
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
    binding = None
    if rules.get('binding_catalog_sha256'):
        if args.binding_catalog is None or hashlib.sha256(args.binding_catalog.read_bytes()).hexdigest()!=rules['binding_catalog_sha256']:
            raise ValueError('actual registered binding catalog is required and must match')
        binding=json.loads(args.binding_catalog.read_text())
    result = audit(tables, rules, json.loads(args.catalog.read_text()), drops, binding)
    if args.native_bin:
        native=args.native_bin.read_bytes()
        if len(native)!=1806317 or hashlib.sha256(native).hexdigest()!='bec901d26a7766f2c77e9781ce636f17c14e7ba1b33617840eb5a5d5123bafd3':
            raise ValueError('shared native BIN differs from approved input')
        result['pr238_pack_bytes_verified_by_this_audit']=True
    if binding is not None: result['actual_registered_catalog_sha256']=rules['binding_catalog_sha256']
    result['source_drop_table_sha256'] = entry['sha256']
    result['rules_sha256'] = hashlib.sha256(args.rules.read_bytes()).hexdigest()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(result['summary'], ensure_ascii=False))


if __name__ == '__main__':
    main()
