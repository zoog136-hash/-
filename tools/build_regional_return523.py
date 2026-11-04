#!/usr/bin/env python3
"""Project the reviewed patch523 QuickSlotChange relations; no original art."""
import argparse
import hashlib
import json
from pathlib import Path


def build(content, archive):
    def rows(name):
        return json.loads((content / (name + '.json')).read_text(encoding='utf-8-sig'))['rows']
    groups, changes = rows('QuickSlotChange'), rows('QuickSlotChangeData')
    if len(groups) != 3 or len(changes) != 9:
        raise ValueError('unexpected snapshot: review new rows before projecting')
    if {r['ItemClassID'] for r in groups} != {239, 282783, 295514} or {r['ItemClassID'] for r in changes} != {126424}:
        raise ValueError('unexpected item identities')
    lands = {str(r['ID']): r for r in rows('Land') if r['ID'] in {44544, 44614, 47722}}
    if len(lands) != 3 or {r['LandID'] for r in changes} != {int(k) for k in lands}:
        raise ValueError('unexpected Land identities')
    descriptions = {r['ID']: r['Description'] for r in rows('DescData_Korean')}
    items = {r['ID']: r for r in rows('ItemClass')}
    grades = {r['ID']: descriptions[r['DescID']] for r in rows('Grade')}
    bonus_types = {r['ID']: r['Name'] for r in rows('BonusType')}
    bonuses = {r['ID']: r for r in rows('Bonus')}
    item_bonuses = rows('ItemBonus')
    projected = {}
    for item_id in [239, 282783, 295514, 126424]:
        infinite = any(r['ItemClassID'] == item_id and bonus_types[bonuses[r['BonusID']]['BonusTypeID']] == 'InfiniteAmount'
                       and bonuses[r['BonusID']]['Value'] == 1 for r in item_bonuses)
        projected[str(item_id)] = {'name': descriptions[items[item_id]['DescID']],
                                   'grade': grades[items[item_id]['GradeID']],
                                   'aliases': ['귀환 주문서'] if item_id == 239 else [], 'infinite': infinite}
    names = ['QuickSlotChange', 'QuickSlotChangeData', 'Land', 'ItemClass', 'DescData_Korean', 'ItemBonus', 'Bonus', 'BonusType', 'Grade']
    return {'schema': 1, 'source_snapshot': 'patch523', 'source_archive_sha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
            'table_sha256': {n: hashlib.sha256((content / (n + '.json')).read_bytes()).hexdigest() for n in names},
            'groups': groups, 'changes': changes, 'items': projected, 'lands': lands,
            'host_bindings': {'source_70': {'land_id': 44544, 'return_map': 'source_70', 'return_mode': 'spawn', 'estimated': True,
              'basis': 'TWILIGHT existing Forgotten Island name; separate PC coordinate layout, not M coordinate equivalence'}}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir', type=Path, required=True, help='directory containing original content/*.json')
    parser.add_argument('--archive', type=Path, required=True, help='the verified table archive, not the entire client')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = build(args.source_dir / 'content', args.archive)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print('REGIONAL_RETURN_SOURCE', len(result['groups']), len(result['changes']), len(result['lands']))


if __name__ == '__main__':
    main()
