#!/usr/bin/env python3
"""Export exact verified523 relic main/additional buff graphs and unlock item.

Display names never establish a level gate or card ownership. This exporter
preserves declarations; the game supplies its existing save transaction.
"""
import argparse
import collections
import hashlib
import json
import pathlib
import zipfile

SOURCE_SHA256 = 'd5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'


def build(source, output):
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    if digest != SOURCE_SHA256:
        raise ValueError('Expected the verified patch523 source ZIP')
    hashes, indices = {}, {}
    with zipfile.ZipFile(source) as archive:
        def table(name):
            raw = archive.read('content/' + name + '.json')
            hashes[name] = hashlib.sha256(raw).hexdigest()
            values = json.loads(raw.decode('utf-8-sig'))['rows']
            indices[name] = {r['ID']: i for i, r in enumerate(values) if 'ID' in r}
            return values

        raw = {name: table(name) for name in (
            'BuffCard', 'BuffCardDeck', 'BuffClass', 'BuffGroup', 'BuffBonus',
            'Bonus', 'BonusType', 'Unit', 'UIUnit', 'BonusApplicationType',
            'NpcClass', 'ItemClass', 'ItemCategory', 'ItemBonus', 'Grade',
            'DescData_Korean', 'UseDesc', 'ServerLimit',
            'BuffCardOptionAwakenGroup', 'BuffCardOptionAwakenLevelBonus',
            'UIStaticTextData_Korean', 'EquipSlot', 'EquipSlotConfig')}
    indexed = {name: {r['ID']: r for r in values if 'ID' in r}
               for name, values in raw.items()}
    ui_units = {r['UnitID']: r for r in raw['UIUnit']}
    buff_links, item_links, option_links = (collections.defaultdict(list) for _ in range(3))
    for row in raw['BuffBonus']:
        buff_links[row['BuffClassID']].append(row)
    for row in raw['ItemBonus']:
        item_links[row['ItemClassID']].append(row)
    for row in raw['BuffCardOptionAwakenLevelBonus']:
        option_links[row['BuffCardOptionAwakenGroupID']].append(row)

    def effect(link, table_name):
        bonus = indexed['Bonus'][link['BonusID']]
        typ = indexed['BonusType'][bonus['BonusTypeID']]
        return {'link': link, 'bonus': bonus, 'type': typ,
                'unit': indexed['Unit'][typ['UnitID']],
                'ui_unit': ui_units.get(typ['UnitID'], {}),
                'source_link_table': table_name,
                'source_link_row_index_zero': indices[table_name][link['ID']]}

    def buff_effects(buff):
        return [effect(link, 'BuffBonus') for link in buff_links[buff]]

    cards, linked, npc_verified = {}, 0, 0
    for card in raw['BuffCard']:
        if card['BuffCardDeckID'] != 98:
            continue
        main = buff_effects(card['BuffClassID'])
        refs = [e for e in main if e['type']['Name'] == 'SubSlotBuffClassID']
        entry = {'card': card, 'source_card_row_index_zero': indices['BuffCard'][card['ID']],
                 'main_buff': indexed['BuffClass'][card['BuffClassID']],
                 'main_effects': main, 'effects': [], 'summon_binding': {}}
        if len(refs) > 1:
            raise ValueError('Ambiguous source SubSlotBuffClassID')
        if refs:
            ref = refs[0]
            if (ref['unit']['ID'] != 16 or ref['bonus']['BonusApplicationTypeID'] != 0
                    or ref['bonus']['BonusApplicationTargetID'] != 0):
                raise ValueError('Unreviewed source subslot link')
            buff_id = ref['bonus']['Value']
            entry.update(subslot_link=ref, subslot_buff=indexed['BuffClass'][buff_id],
                         effects=buff_effects(buff_id))
            summons = [e for e in entry['effects'] if e['type']['Name'] == 'BuffCardSummonNPCClassID']
            if len(summons) != 1 or any(summons[0]['bonus'][k] != v for k, v in
                    [('BonusApplicationTypeID', 461), ('BonusApplicationTargetID', 11)]):
                raise ValueError('Unreviewed additional-slot summon binding')
            npc = indexed['NpcClass'][summons[0]['bonus']['Value']]
            entry['summon_binding'] = {'source_snapshot': 'patch523', 'slot_index': 11,
                'npc_class_id': npc['ID'], 'sprite_id': npc['Sprite'], 'npc': npc,
                'display_sprite_verified': npc['Sprite'] == card['DisplaySpriteID']}
            npc_verified += entry['summon_binding']['display_sprite_verified']
            linked += 1
        cards[f"98:{card['ID']}"] = entry

    options = {}
    for group in raw['BuffCardOptionAwakenGroup']:
        card = indexed['BuffCard'][group['BuffCardID']]
        if card['BuffCardDeckID'] == 98 and group['SlotIndex'] == 11:
            options[f"98:{card['ID']}:11"] = {'card': card, 'group': group,
                'effects': [effect(link, 'BuffCardOptionAwakenLevelBonus')
                            for link in option_links[group['ID']]]}

    item = indexed['ItemClass'][365748]
    unlock = {'item': item, 'name': indexed['DescData_Korean'][item['DescID']]['Description'],
              'category': indexed['ItemCategory'][item['CategoryID']],
              'grade': indexed['Grade'][item['GradeID']],
              'effects': [effect(link, 'ItemBonus') for link in item_links[item['ID']]],
              'buff': indexed['BuffClass'][95648], 'buff_effects': buff_effects(95648),
              'use_desc': indexed['UseDesc'][item['UseDescID']]}
    desc_ids = {item[k] for k in ('DescID', 'IdentifiedDescID', 'StoryDescID', 'ProductDescID')}
    desc_ids.add(unlock['use_desc']['DescID'])
    unlock['descriptions'] = {str(i): indexed['DescData_Korean'][i] for i in sorted(desc_ids)}
    dispatch = [e for e in unlock['effects'] if e['type']['Name'] == 'BuffClassID']
    if not (len(dispatch) == 1 and dispatch[0]['bonus']['ID'] == 2357388
            and dispatch[0]['bonus']['Value'] == 95648
            and not dispatch[0]['link']['IsPossession']):
        raise ValueError('Unlock item dispatch changed')
    if {(e['type']['Name'], e['bonus']['Value']) for e in unlock['effects']} != {
            ('BuffClassID', 95648), ('ItemConsumeEffectSpriteID', 751), ('BuffDurationInfinite', 1)}:
        raise ValueError('Unlock item duration or presentation semantics changed')
    if {(e['type']['Name'], e['bonus']['Value']) for e in unlock['buff_effects']} != {
            ('SaveDB', 1), ('HolyStuffSubSlotOpened', 1)}:
        raise ValueError('Unlock buff semantics changed')

    # The scroll is a separate summon operation. Its existence does not create
    # an automatic equip fee, grant the unlock, or prove consumption timing.
    scroll = indexed['ItemClass'][365758]
    summon_item = {'item': scroll, 'effects': [effect(r, 'ItemBonus') for r in item_links[scroll['ID']]]}
    ui_evidence = [{'table': 'UIStaticTextData_Korean', 'row_index_zero': i, 'raw': row}
                   for i, row in enumerate(raw['UIStaticTextData_Korean'])
                   if row['TextDesc'].startswith('CHARACTERINFO_EQUIPSLOTSET_D\\PANEL\\ND_ADD\\')]
    relevant_limits = {r['card']['ServerLimitSetID'] for r in cards.values()}
    relevant_limits.update(g['group']['ServerLimitsetID'] for g in options.values())
    counts = {'cards': len(cards), 'subslot_links': linked,
              'unique_subslot_buffs': len({e['subslot_buff']['ID'] for e in cards.values() if 'subslot_buff' in e}),
              'verified_display_sprites': npc_verified, 'option_groups': len(options)}
    if counts != {'cards': 147, 'subslot_links': 145, 'unique_subslot_buffs': 144,
                  'verified_display_sprites': 145, 'option_groups': 58}:
        raise ValueError('Reviewed relic source counts changed: ' + str(counts))
    result = {'schema': 1, 'source_snapshot': 'patch523', 'source_zip_sha256': digest,
              'source_table_sha256': hashes, 'counts': counts, 'cards': cards,
              'option_groups': options, 'unlock_item': unlock, 'summon_item': summon_item,
              'deck': indexed['BuffCardDeck'][98],
              'buff_groups': {str(i): indexed['BuffGroup'][i] for i in (2768, 6028)},
              'equip_slots': {str(i): indexed['EquipSlot'][i] for i in (208, 328)},
              'equip_slot_configs': {str(i): indexed['EquipSlotConfig'][i] for i in (282, 708)},
              'source_server_limits': [r for r in raw['ServerLimit'] if r['ServerLimitSetID'] in relevant_limits],
              'ui_evidence': ui_evidence,
              'boundaries': ['No numeric use-level requirement is supplied by the unlock item or buff links.',
                             'Names containing 96 are reward labels, not an executable level condition.',
                             'No main-slot-presence dependency is supplied; existing main card/grade conflicts are checked.',
                             'No item grant, scroll debit, skill-level bonus or main-slot effect is inferred.']}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':')) + '\n')
    print(json.dumps(counts))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, type=pathlib.Path)
    parser.add_argument('--output', required=True, type=pathlib.Path)
    args = parser.parse_args()
    build(args.source, args.output)
