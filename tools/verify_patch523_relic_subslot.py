#!/usr/bin/env python3
"""Independently compare every exported relic reference with verified523 rows."""
import argparse
import collections
import hashlib
import json
import pathlib
import zipfile


def verify(source, artifact):
    data = json.loads(artifact.read_text())
    if hashlib.sha256(source.read_bytes()).hexdigest() != data['source_zip_sha256']:
        raise ValueError('Source ZIP SHA mismatch')
    tables = {}
    with zipfile.ZipFile(source) as archive:
        for name, expected in data['source_table_sha256'].items():
            raw = archive.read('content/' + name + '.json')
            if hashlib.sha256(raw).hexdigest() != expected:
                raise ValueError('Source table SHA mismatch: ' + name)
            tables[name] = json.loads(raw.decode('utf-8-sig'))['rows']
    by = {name: {row['ID']: row for row in rows if 'ID' in row}
          for name, rows in tables.items()}
    ui = {row['UnitID']: row for row in tables['UIUnit']}
    checks = 0

    def same(actual, expected, label):
        nonlocal checks
        checks += 1
        if actual != expected:
            raise ValueError('Source reference mismatch: ' + label)

    def effects(exported, table, owner_field, owner_id):
        expected = [r for r in tables[table] if r[owner_field] == owner_id]
        same([e['link'] for e in exported], expected, f'{table}:{owner_id}:complete_links')
        for entry in exported:
            link = entry['link']
            same(tables[entry['source_link_table']][entry['source_link_row_index_zero']],
                 link, 'source row index')
            same(entry['source_link_table'], table, 'typed owner table')
            bonus = by['Bonus'][link['BonusID']]
            typ = by['BonusType'][bonus['BonusTypeID']]
            same(entry['bonus'], bonus, 'Bonus')
            same(entry['type'], typ, 'BonusType')
            same(entry['unit'], by['Unit'][typ['UnitID']], 'Unit')
            same(entry['ui_unit'], ui.get(typ['UnitID'], {}), 'UIUnit')

    same(sorted(int(key.split(':')[1]) for key in data['cards']),
         sorted(r['ID'] for r in tables['BuffCard'] if r['BuffCardDeckID'] == 98),
         'all147 deck98 cards, including unused rows')
    for key, row in data['cards'].items():
        card = by['BuffCard'][int(key.split(':')[1])]
        same(row['card'], card, 'BuffCard')
        same(tables['BuffCard'][row['source_card_row_index_zero']], card, 'BuffCard row index')
        same(row['main_buff'], by['BuffClass'][card['BuffClassID']], 'main BuffClass')
        effects(row['main_effects'], 'BuffBonus', 'BuffClassID', card['BuffClassID'])
        links = [e for e in row['main_effects'] if e['type']['Name'] == 'SubSlotBuffClassID']
        if not links:
            same(row['effects'], [], 'no invented secondary graph')
            continue
        same(row['subslot_link'], links[0], 'typed SubSlotBuffClassID')
        sub_id = links[0]['bonus']['Value']
        same(row['subslot_buff'], by['BuffClass'][sub_id], 'secondary BuffClass')
        effects(row['effects'], 'BuffBonus', 'BuffClassID', sub_id)
        npc_bonus = [e['bonus'] for e in row['effects'] if e['type']['Name'] == 'BuffCardSummonNPCClassID']
        same(len(npc_bonus), 1, 'one typed summon')
        same((npc_bonus[0]['BonusApplicationTypeID'], npc_bonus[0]['BonusApplicationTargetID']),
             (461, 11), 'additional summon target')
        binding = row['summon_binding']
        same(binding['npc_class_id'], npc_bonus[0]['Value'], 'NPC reference value')
        same(binding['npc'], by['NpcClass'][binding['npc_class_id']], 'NpcClass')
        same(binding['sprite_id'], binding['npc']['Sprite'], 'NPC sprite reference')
        same(binding['display_sprite_verified'], binding['npc']['Sprite'] == card['DisplaySpriteID'],
             'direct NPC/display sprite equality')
    expected_groups = [r for r in tables['BuffCardOptionAwakenGroup']
                       if by['BuffCard'][r['BuffCardID']]['BuffCardDeckID'] == 98 and r['SlotIndex'] == 11]
    same(sorted(g['group']['ID'] for g in data['option_groups'].values()),
         sorted(g['ID'] for g in expected_groups), 'all58 relic secondary option groups')
    for entry in data['option_groups'].values():
        group = entry['group']
        same(group, by['BuffCardOptionAwakenGroup'][group['ID']], 'option group')
        same(entry['card'], by['BuffCard'][group['BuffCardID']], 'option card')
        effects(entry['effects'], 'BuffCardOptionAwakenLevelBonus',
                'BuffCardOptionAwakenGroupID', group['ID'])
    unlock = data['unlock_item']
    same(unlock['item'], by['ItemClass'][365748], 'unlock ItemClass')
    same(unlock['buff'], by['BuffClass'][95648], 'unlock BuffClass')
    same(unlock['category'], by['ItemCategory'][unlock['item']['CategoryID']], 'consumable category')
    same(unlock['grade'], by['Grade'][unlock['item']['GradeID']], 'unlock grade')
    effects(unlock['effects'], 'ItemBonus', 'ItemClassID', 365748)
    effects(unlock['buff_effects'], 'BuffBonus', 'BuffClassID', 95648)
    for desc_id, row in unlock['descriptions'].items():
        same(row, by['DescData_Korean'][int(desc_id)], 'unlock description')
    same(unlock['use_desc'], by['UseDesc'][unlock['item']['UseDescID']], 'unlock UseDesc')
    scroll = data['summon_item']
    same(scroll['item'], by['ItemClass'][365758], 'separate summon scroll')
    effects(scroll['effects'], 'ItemBonus', 'ItemClassID', 365758)
    same(data['deck'], by['BuffCardDeck'][98], 'source deck')
    for key, row in data['buff_groups'].items():
        same(row, by['BuffGroup'][int(key)], 'source buff group')
    for key, row in data['equip_slots'].items():
        same(row, by['EquipSlot'][int(key)], 'source equip slot')
    for key, row in data['equip_slot_configs'].items():
        same(row, by['EquipSlotConfig'][int(key)], 'source equip-slot capacity')
    limits = {r['card']['ServerLimitSetID'] for r in data['cards'].values()}
    limits.update(r['group']['ServerLimitsetID'] for r in data['option_groups'].values())
    same(data['source_server_limits'], [r for r in tables['ServerLimit'] if r['ServerLimitSetID'] in limits],
         'latest exact server tuples')
    for entry in data['ui_evidence']:
        same(entry['raw'], tables[entry['table']][entry['row_index_zero']], 'source UI help')
    print(json.dumps({'source_reference_checks': checks, 'errors': []}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, type=pathlib.Path)
    parser.add_argument('--artifact', default='data/cards/patch523_relic_subslot.json', type=pathlib.Path)
    args = parser.parse_args()
    verify(args.source, args.artifact)
