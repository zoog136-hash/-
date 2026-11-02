#!/usr/bin/env python3
"""Typed native option rules; skill-book rules remain a separate transaction."""
import argparse, collections, hashlib, json, pathlib, zipfile


def build(args):
    archive = zipfile.ZipFile(args.tables)
    hashes = {}
    def table(name):
        raw = archive.read('content/' + name + '.json')
        hashes[name] = hashlib.sha256(raw).hexdigest()
        return json.loads(raw.decode('utf-8-sig'))['rows']
    names = {r['ID']: r['Name'] for r in table('BuffCardOptionAwakenValueType')}
    economy = collections.defaultdict(dict)
    for row in table('BuffCardOptionAwakenValue'):
        key = f"{row['BuffCardDeckID']}:{row['GradeID']}"
        name = names[row['BuffCardOptionAwakenValueTypeID']]
        if name in economy[key]:
            raise ValueError('Duplicate typed native rule')
        economy[key][name] = row
    cards = {r['ID']: r for r in table('BuffCard')}
    bonuses = {r['ID']: r for r in table('Bonus')}
    types = {r['ID']: r for r in table('BonusType')}
    units = {r['ID']: r for r in table('Unit')}
    links = collections.defaultdict(list)
    for row in table('BuffCardOptionAwakenLevelBonus'):
        bonus = bonuses[row['BonusID']]
        typ = types[bonus['BonusTypeID']]
        links[row['BuffCardOptionAwakenGroupID']].append({
            'link': row, 'bonus': bonus, 'type': typ, 'unit': units[typ['UnitID']]})
    groups = []
    status_ids, invoke_ids = set(), set()
    for group in table('BuffCardOptionAwakenGroup'):
        card = cards[group['BuffCardID']]
        if card['BuffCardDeckID'] not in (1, 2, 98):
            continue
        effects = links[group['ID']]
        for effect in effects:
            if effect['type']['Name'] == 'StatusEffectID':
                status_ids.add(effect['bonus']['Value'])
            if effect['type']['Name'] == 'InvokeOption':
                invoke_ids.add(effect['bonus']['BonusApplicationTargetID'])
        groups.append({'identity': f"source:m508:{card['BuffCardDeckID']}:{card['ID']}",
                       'card': card, 'group': group, 'effects': effects})
    output = {'schema': 1, 'source_snapshot': 'base508', 'economy': dict(economy),
              'option_groups': groups,
              'status_effect_attrs': [r for r in table('StatusEffectAttr') if r['StatusEffectID'] in status_ids],
              'invoke_options': [r for r in table('InvokeOption') if r['ID'] in invoke_ids],
              'invoke_types': table('InvokeOptionType'), 'table_sha256': hashes}
    args.output.write_text(json.dumps(output, ensure_ascii=False, separators=(',', ':')) + '\n')
    print(json.dumps({'option_groups': len(groups), 'secondary_slot11': sum(r['group']['SlotIndex'] == 11 for r in groups),
                      'economy_keys': len(economy), 'invoke_options': len(output['invoke_options'])}))


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--tables', type=pathlib.Path, required=True)
    p.add_argument('--output', type=pathlib.Path, required=True)
    build(p.parse_args())
