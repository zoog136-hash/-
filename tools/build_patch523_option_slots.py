#!/usr/bin/env python3
"""Keep exact patch523 option groups keyed by deck, card AND slot.

This exports declarations only. It does not infer slot unlocks, awakening
probability denominators, collection completion or summon activation rules.
"""
import argparse
import collections
import hashlib
import json
import pathlib
import zipfile

SOURCE_SHA256 = 'd5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'


def signature(effect):
    bonus, typ = effect['bonus'], effect['type']
    return (typ['ID'], bonus['Value'], bonus['BonusApplicationTypeID'],
            bonus['BonusApplicationTargetID'], effect['link']['Level'],
            json.dumps(effect['unit'], sort_keys=True),
            json.dumps(effect['ui_unit'], sort_keys=True))


def build(source, base, output):
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    if digest != SOURCE_SHA256:
        raise ValueError('Expected the verified patch523 source ZIP')
    archive = zipfile.ZipFile(source)
    hashes = {}

    def table(name):
        raw = archive.read('content/' + name + '.json')
        hashes[name] = hashlib.sha256(raw).hexdigest()
        return json.loads(raw.decode('utf-8-sig'))['rows']

    cards = {r['ID']: r for r in table('BuffCard')}
    bonuses = {r['ID']: r for r in table('Bonus')}
    types = {r['ID']: r for r in table('BonusType')}
    units = {r['ID']: r for r in table('Unit')}
    ui_units = {r['UnitID']: r for r in table('UIUnit')}
    descriptions = {r['ID']: r['Description'] for r in table('DescData_Korean')}
    links = collections.defaultdict(list)
    for row in table('BuffCardOptionAwakenLevelBonus'):
        links[row['BuffCardOptionAwakenGroupID']].append(row)
    groups = {}
    referenced_bonus_ids = set()
    for group in table('BuffCardOptionAwakenGroup'):
        card = cards[group['BuffCardID']]
        deck, card_id, slot = card['BuffCardDeckID'], card['ID'], group['SlotIndex']
        if deck not in (1, 2, 98) or slot not in (1, 11):
            raise ValueError('Unreviewed source deck or slot')
        key = f'{deck}:{card_id}:{slot}'
        if key in groups or not links[group['ID']]:
            raise ValueError('Duplicate or empty source option group')
        groups[key] = {'card': card, 'group': group, 'links': links[group['ID']]}
        referenced_bonus_ids.update(r['BonusID'] for r in links[group['ID']])

    def effects(group):
        return [{'link': link, 'bonus': bonuses[link['BonusID']],
                 'type': types[bonuses[link['BonusID']]['BonusTypeID']],
                 'unit': units[types[bonuses[link['BonusID']]['BonusTypeID']]['UnitID']],
                 'ui_unit': ui_units.get(types[bonuses[link['BonusID']]['BonusTypeID']]['UnitID'], {})}
                for link in group['links']]

    compatible, changed = [], []
    for row in json.loads(base.read_text())['definitions']:
        old = row['native_source']
        card = old['card']
        key = f"{card['BuffCardDeckID']}:{card['ID']}:1"
        current = groups[key]
        old_set = collections.Counter(map(signature, old['effects']))
        new_set = collections.Counter(map(signature, effects(current)))
        if old_set != new_set:
            # Verified 508 -> 523 correction: Mariela's three economy links
            # changed from Level0 to Level1. No value/target/type is inferred.
            reviewed = json.loads(json.dumps(old['effects']))
            adjusted = set()
            for effect in reviewed:
                if effect['link']['ID'] in (23062, 23072, 23082) and effect['link']['Level'] == 0:
                    adjusted.add(effect['link']['ID'])
                    effect['link']['Level'] = 1
            if (key != '2:25002:1' or adjusted != {23062, 23072, 23082} or
                    collections.Counter(map(signature, reviewed)) != new_set):
                raise ValueError('Unreviewed primary effect change: ' + key)
            changed.append(key)
        if (old['group'] != current['group'] or
                any(card[field] != current['card'][field] for field in
                    ('BuffCardDeckID', 'GradeID', 'ServerLimitSetID', 'StartDateTimeID', 'EndDateTimeID'))):
            raise ValueError('Existing primary awakening needs separate review: ' + key)
        compatible.append(key)

    pair_checks = 0
    expected_removed = {
        2: ['ExperienceAdditionPercent', 'CarryPlus', 'EinasadSavingPercent'],
        98: ['ExperienceAdditionPercent', 'SpellCastDelayDecreasePercent'],
    }
    for key, group in groups.items():
        if group['group']['SlotIndex'] != 11:
            continue
        card = group['card']
        primary = groups[f"{card['BuffCardDeckID']}:{card['ID']}:1"]
        main = collections.Counter(map(signature, effects(primary)))
        extra = collections.Counter(map(signature, effects(group)))
        removed = main - extra
        names = sorted(types[entry[0]]['Name'] for entry, count in removed.items()
                       for _ in range(count))
        if extra - main or names != sorted(expected_removed[card['BuffCardDeckID']]):
            raise ValueError('Unreviewed primary/extra effect relation: ' + key)
        pair_checks += 1
    if len(groups) != 446 or sum(len(g['links']) for g in groups.values()) != 2392 or pair_checks != 141:
        raise ValueError('Patch523 group/link/pair counts changed')
    used_types = {bonuses[i]['BonusTypeID'] for i in referenced_bonus_ids}
    used_units = {types[i]['UnitID'] for i in used_types}
    result = {'schema': 1, 'source_snapshot': 'patch523', 'source_zip_sha256': digest,
              'source_table_sha256': hashes, 'groups': groups,
              'reviewed_primary_keys': sorted(compatible), 'changed_primary_keys': sorted(changed),
              'bonuses': {str(i): bonuses[i] for i in sorted(referenced_bonus_ids)},
              'types': {str(i): types[i] for i in sorted(used_types)},
              'units': {str(i): units[i] for i in sorted(used_units)},
              'ui_units': {str(i): ui_units[i] for i in sorted(used_units) if i in ui_units},
              'type_labels': {str(i): descriptions.get(types[i]['DescID']) or types[i]['Name']
                              for i in sorted(used_types)},
              'counts': {'cards': len({g['card']['ID'] for g in groups.values()}),
                         'groups': len(groups), 'effects': 2392, 'slot_pairs': pair_checks,
                         'compatible_primary_groups': len(compatible)}}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':')) + '\n')
    print(json.dumps(result['counts']))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=pathlib.Path, required=True)
    parser.add_argument('--base', type=pathlib.Path, required=True)
    parser.add_argument('--output', type=pathlib.Path, required=True)
    args = parser.parse_args()
    build(args.source, args.base, args.output)
