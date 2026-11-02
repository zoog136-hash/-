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
    ui_units = {r['UnitID']: r for r in table('UIUnit')}
    links = collections.defaultdict(list)
    for row in table('BuffCardOptionAwakenLevelBonus'):
        bonus = bonuses[row['BonusID']]
        typ = types[bonus['BonusTypeID']]
        links[row['BuffCardOptionAwakenGroupID']].append({
            'link': row, 'bonus': bonus, 'type': typ, 'unit': units[typ['UnitID']], 'ui_unit': ui_units.get(typ['UnitID'], {})})
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
    invoke_options = [r for r in table('InvokeOption') if r['ID'] in invoke_ids]
    spell_ids = {r['Param1'] for r in invoke_options if r['InvokeOptionTypeID'] in (1, 2)}
    def effect(link):
        bonus = bonuses[link['BonusID']]
        typ = types[bonus['BonusTypeID']]
        return {'link': link, 'bonus': bonus, 'type': typ, 'unit': units[typ['UnitID']], 'ui_unit': ui_units.get(typ['UnitID'], {})}
    spell_links = collections.defaultdict(list)
    for row in table('SpellBonus'):
        if row['SpellClassID'] in spell_ids:
            spell_links[row['SpellClassID']].append(effect(row))
    buff_ids = {e['bonus']['Value'] for effects in spell_links.values() for e in effects if e['type']['Name'] == 'BuffClassID'}
    buff_links = collections.defaultdict(list)
    for row in table('BuffBonus'):
        if row['BuffClassID'] in buff_ids:
            buff_links[str(row['BuffClassID'])].append(effect(row))
    spells = {str(r['ID']): {'source_spell': r, 'effects': spell_links[r['ID']]} for r in table('SpellClass') if r['ID'] in spell_ids}
    subslot_refs = {}
    card_buffs = {r['BuffClassID']: r for r in cards.values() if r['BuffCardDeckID'] == 2}
    buff_rows = table('BuffBonus')
    for row in buff_rows:
        if row['BuffClassID'] in card_buffs and types[bonuses[row['BonusID']]['BonusTypeID']]['Name'] == 'SubSlotBuffClassID':
            card = card_buffs[row['BuffClassID']]
            target = bonuses[row['BonusID']]['Value']
            identity = f"source:m508:2:{card['ID']}"
            subslot_refs[identity] = {'card': card, 'link': effect(row), 'effects': [effect(x) for x in buff_rows if x['BuffClassID'] == target]}
    item = next(r for r in table('ItemClass') if r['ID'] == 346901)
    category = next(r for r in table('ItemCategory') if r['ID'] == item['CategoryID'])
    description = next(r['Description'] for r in table('DescData_Korean') if r['ID'] == item['DescID'])
    grade = next(r for r in table('Grade') if r['ID'] == item['GradeID'])
    unlock_links = [effect(r) for r in table('ItemBonus') if r['ItemClassID'] == item['ID']]
    unlock_buffs = [effect(r) for r in buff_rows if r['BuffClassID'] == 91531]
    awaken_effects = table('BuffCardAwakenEffect')
    by_effect = {(r['BuffCardDeckID'], r['GradeID']): r for r in awaken_effects}
    status_chain_checks = 0
    for group in groups:
        for ref in group['effects']:
            if ref['type']['Name'] != 'StatusEffectID':
                continue
            key = (group['card']['BuffCardDeckID'], group['card']['GradeID'])
            assert by_effect[key]['StatusEffectID'] == ref['bonus']['Value'], 'Mismatched scoped awakening status'
            status_chain_checks += 1
    output = {'schema': 1, 'source_snapshot': 'base508', 'economy': dict(economy),
              'option_groups': groups, 'subslot_buffs': subslot_refs,
              'awaken_effects': awaken_effects, 'status_chain_verified_count': status_chain_checks,
              'subslot_unlock_item': {'item': item, 'category': category, 'grade': grade, 'name': description, 'effects': unlock_links, 'buff_effects': unlock_buffs},
              'status_effect_attrs': [r for r in table('StatusEffectAttr') if r['StatusEffectID'] in status_ids],
              'invoke_options': invoke_options, 'invoke_spells': spells, 'invoke_buffs': dict(buff_links),
              'invoke_types': table('InvokeOptionType'), 'table_sha256': hashes}
    args.output.write_text(json.dumps(output, ensure_ascii=False, separators=(',', ':')) + '\n')
    print(json.dumps({'option_groups': len(groups), 'secondary_slot11': sum(r['group']['SlotIndex'] == 11 for r in groups),
                      'economy_keys': len(economy), 'invoke_options': len(output['invoke_options'])}))


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--tables', type=pathlib.Path, required=True)
    p.add_argument('--output', type=pathlib.Path, required=True)
    build(p.parse_args())
