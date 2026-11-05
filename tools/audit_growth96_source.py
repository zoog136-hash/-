#!/usr/bin/env python3
"""Verify the private input and write its complete growth reference closure.

The output contains private source rows. Keep it outside the Git worktree.
This audit proves conversion coverage; runtime and Main tests prove execution.
"""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

SIZE = 25_031_173
SHA256 = 'd5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'


def audit(source: Path) -> dict:
    payload = source.read_bytes()
    if len(payload) != SIZE or hashlib.sha256(payload).hexdigest() != SHA256:
        raise ValueError('The private source size or SHA-256 does not match.')
    with zipfile.ZipFile(source) as archive:
        if archive.testzip() is not None:
            raise ValueError('The private source failed ZIP CRC verification.')

        def rows(name):
            return json.loads(archive.read('content/' + name + '.json'))['rows']

        def indexed(name):
            return {row['ID']: row for row in rows(name)}

        points = indexed('GrowthMotivation')
        links = rows('GrowthMotivationReward')
        rewards = indexed('Reward')
        items = indexed('ItemClass')
        token_items = {row['ID']: row for row in rows('ItemBookItem')
                       if row['ItemClassID'] == 371128}
        card_links = [row for row in rows('ItemBookCardForItem')
                      if row['ItemBookItemID'] in token_items]
        cards = indexed('ItemBookCard')
        card_ids = {row['ItemBookCardID'] for row in card_links}
        membership = [row for row in rows('ItemBookCardForCollection')
                      if row['ItemBookCardID'] in card_ids]
        collection_ids = {row['ItemBookCollectionID'] for row in membership}
        collections = indexed('ItemBookCollection')
        slots = {row['ID']: row for row in rows('ItemBookCollectionSlot')
                 if row['ItemBookCollectionID'] in collection_ids}
        effect_links = [row for row in rows('ItemBookCollectionSlotBonus')
                        if row['ItemBookCollectionSlotID'] in slots]
        bonuses = indexed('Bonus')
        types = indexed('BonusType')
        units = indexed('Unit')
        ui_units = {row['UnitID']: row for row in rows('UIUnit')}
        descriptions = indexed('DescData_Korean')
        reward_ids = {row['RewardID'] for row in links}
        attributes = [row for row in rows('RewardAttribute') if row['RewardID'] in reward_ids]
        groups = [row for row in rows('RewardGroup') if row['RewardID'] in reward_ids]
        assert len(points) == 71 and len(links) == len(reward_ids) == 269
        assert not attributes and not groups
        growth = []
        for link in links:
            reward = rewards[link['RewardID']]
            assert reward['RewardTypeID'] == 2 and reward['RewardGetTimeTypeID'] == 2
            assert reward['CharacterClassID'] == reward['Ranking'] == 0
            assert reward['UseImmediately'] is False and reward['ClanOnly'] is False
            assert reward['RewardEnhancementTypeID'] == reward['ItemBlessCodeID'] == 1
            assert reward['Amount'] > 0
            growth.append({'point': points[link['GrowthMotivationID']], 'link': link,
                           'reward': reward, 'item': items[reward['RewardClassID']]})
        registrations = []
        for link in card_links:
            item = token_items[link['ItemBookItemID']]
            assert item['Amount'] == item['BlessCode'] == 1
            assert item['Enchant'] == item['ElementalType'] == item['ElementalEnchant'] == 0
            joined = [row for row in membership if row['ItemBookCardID'] == link['ItemBookCardID']]
            assert len(joined) == 1
            collection = collections[joined[0]['ItemBookCollectionID']]
            assert collection['Level'] == 96 and collection['ServerLimitSetID'] == 0
            assert collection['ExpireDateTimeID'] == 0 and collection['IsEvent'] is False
            registrations.append({'item': item, 'card_link': link,
                                  'card': cards[link['ItemBookCardID']],
                                  'membership': joined[0], 'collection': collection})
        effects = []
        for link in effect_links:
            bonus = bonuses[link['BonusID']]
            kind = types[bonus['BonusTypeID']]
            unit = units[kind['UnitID']]
            assert link['GameClassID'] == 0
            denominator = 1 if unit['Name'] == 'Value' else ui_units[kind['UnitID']]['Denominator']
            scoped = kind['Name'] == 'HitSpecialResistanceScale'
            assert (bonus['BonusApplicationTypeID'], bonus['BonusApplicationTargetID']) == ((252, 14) if scoped else (0, 0))
            effects.append({'slot': slots[link['ItemBookCollectionSlotID']], 'link': link,
                            'bonus': bonus, 'type': kind, 'unit': unit,
                            'ui_unit': ui_units.get(kind['UnitID']),
                            'description': descriptions.get(kind['DescID']),
                            'converted_value': bonus['Value'] / denominator})
        assert len(token_items) == len(card_ids) == len(registrations) == len(membership) == 63
        assert len(collection_ids) == 8 and len(effects) == 16
        new = [row for row in growth if row['point']['Level'] == 96]
        assert len(new) == 36 and len({row['point']['ID'] for row in new}) == 9
        assert all(row['link']['Version'] == 0 and row['reward']['Amount'] == 3 for row in new)
        assert {row['reward']['RewardClassID'] for row in new} == {96094, 96084, 254268, 371128}
        item_ids = {row['item']['ID'] for row in growth}
        # These columns are typed item references. Do not join unrelated NPC,
        # icon, craft or market IDs merely because their integers collide.
        item_references = {
            name: [row for row in rows(name) if row.get('ItemClassID') in item_ids]
            for name in ['ItemBonus', 'ItemBookItem', 'ItemCraftInput', 'ItemCraftOutputView',
                         'ItemCraftView', 'LuckyBagEntityView', 'NpcItemDropView']
        }
        item_references['Reward'] = [row for row in rewards.values()
                                     if row['RewardTypeID'] == 2 and row['RewardClassID'] in item_ids]
        item_references['CurrencyUnitClass'] = [row for row in rows('CurrencyUnitClass')
                                                if units[row['UnitID']]['Name'] == 'ItemClassID'
                                                and row['ClassID'] in item_ids]
        card_supply = {name: rows(name) for name in ['GotchaBuffCardList', 'BuffCardSourceView']}
        assert card_supply['GotchaBuffCardList'] == []
        return {'source_sha256': SHA256, 'source_bytes': SIZE,
                'zip_crc': 'all entries passed', 'constants': rows('GrowthMotivationConstant'),
                'coverage': {'points': len(points), 'reward_links': len(growth),
                             'requirements': len(registrations), 'collections': len(collection_ids),
                             'effects': len(effects)},
                'growth': growth, 'registrations': registrations, 'effects': effects,
                'reward_attributes': attributes, 'reward_groups': groups,
                'typed_item_reference_rows': item_references,
                'card_supply_reference_rows': card_supply,
                'consumer_scope': 'ItemBonus, crafting, drop and other achievement-token book references are preserved for review, not enabled as new services by this feature. LuckyBagEntityView describes bag outputs and does not establish an opener for these source boxes. The source card-draw list is empty, while the existing card-pack contract names six different authored tickets. No source box is silently mapped to those tickets or to same-name Inven records.',
                'runtime_scope': 'All growth links and token joins are executable. Version selection is an explicit local policy. Unrecovered percentage and target-group formulas require the separate opt-in TWILIGHT policy. Card boxes remain sealed because their supply identity is not established.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    if args.output.resolve().is_relative_to(root):
        raise ValueError('The private audit output must be outside the Git worktree.')
    result = audit(args.source)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print('GROWTH96_SOURCE_AUDIT', json.dumps(result['coverage']))


if __name__ == '__main__':
    main()
