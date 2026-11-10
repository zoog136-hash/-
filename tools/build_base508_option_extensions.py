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
    buff_rows = table('BuffBonus')
    by_buff = collections.defaultdict(list)
    for row in buff_rows:
        by_buff[row['BuffClassID']].append(row)
    subslot_targets = {bonuses[r['BonusID']]['Value'] for card in cards.values() if card['BuffCardDeckID'] == 2 for r in by_buff[card['BuffClassID']] if types[bonuses[r['BonusID']]['BonusTypeID']]['Name'] == 'SubSlotBuffClassID'}
    primary_buffs = {r['BuffClassID'] for r in cards.values() if r['BuffCardDeckID'] == 2}
    for row in buff_rows:
        if row['BuffClassID'] in subslot_targets | primary_buffs and types[bonuses[row['BonusID']]['BonusTypeID']]['Name'] == 'InvokeOption':
            invoke_ids.add(bonuses[row['BonusID']]['BonusApplicationTargetID'])
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
    for row in buff_rows:
        if row['BuffClassID'] in card_buffs and types[bonuses[row['BonusID']]['BonusTypeID']]['Name'] == 'SubSlotBuffClassID':
            card = card_buffs[row['BuffClassID']]
            target = bonuses[row['BonusID']]['Value']
            identity = f"source:m508:2:{card['ID']}"
            subslot_refs[identity] = {'card': card, 'link': effect(row), 'effects': [effect(x) for x in buff_rows if x['BuffClassID'] == target]}
    primary_refs = {f"source:m508:2:{card['ID']}": {'card': card, 'effects': [effect(r) for r in by_buff[card['BuffClassID']]]} for card in cards.values() if card['BuffCardDeckID'] == 2}
    npcs = {r['ID']: r for r in table('NpcClass')}
    npc_bindings = {}
    for identity, row in subslot_refs.items():
        primary_sprites = {npcs[bonuses[r['BonusID']]['Value']]['Sprite'] for r in by_buff[row['card']['BuffClassID']] if types[bonuses[r['BonusID']]['BonusTypeID']]['Name'] == 'BuffCardSummonNPCClassID'}
        extra = [r for r in row['effects'] if r['type']['Name'] == 'BuffCardSummonNPCClassID']
        assert len(extra) == 1
        npc_id = extra[0]['bonus']['Value']
        sprite_id = npcs[npc_id]['Sprite']
        display = row['card']['DisplaySpriteID']
        assert sprite_id == display or sprite_id in primary_sprites, 'Unverified source doll sprite relation'
        npc_bindings[identity] = {'npc_class_id': npc_id, 'sprite_id': sprite_id, 'display_sprite_id': display, 'primary_sprite_ids': sorted(primary_sprites), 'same_source_sprite_verified': sprite_id in primary_sprites, 'display_sprite_verified': sprite_id == display}
    expiry_ids = {e['bonus']['BonusApplicationTargetID'] for r in subslot_refs.values() for e in r['effects'] if e['type']['Name'] == 'DeleteTime' and e['bonus']['BonusApplicationTypeID'] == 298}
    expiry_dates = {name: [r for r in table(name) if r['ID'] in expiry_ids] for name in ['DateTimes', 'DateTimes_Korean']}
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
              'option_groups': groups, 'subslot_buffs': subslot_refs, 'primary_doll_buffs': primary_refs, 'subslot_npc_bindings': npc_bindings,
              'spell_material_types': table('SpellMaterialType'), 'buff_delete_datetimes': expiry_dates,
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
