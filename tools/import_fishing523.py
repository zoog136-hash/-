#!/usr/bin/env python3
"""Build a private runtime pack from a locally supplied, verified 523 archive.

The generated pack belongs outside the public repository. No source data is
embedded in this importer. It does not download or decrypt anything.
"""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile


def build(source):
    with zipfile.ZipFile(source) as z:
        index = json.loads(z.read('index.json'))
        assert len(index) == 1065 and all(r['version'] == 523 for r in index), 'Expected complete version 523.'
        inventory = {r['path']: r for r in index}
        def rows(name):
            path = 'content/' + name + '.json'
            data = z.read(path)
            assert hashlib.sha256(data).hexdigest() == inventory[path]['sha256'], name
            return json.loads(data)['rows']
        names = ['Fish', 'FishConstant', 'FishContest', 'FishContestRank', 'FishContestRankReward',
                 'FishContestRule', 'FishContestRuleType', 'FishDistribution', 'FishMiniGameAI',
                 'FishMiniGameAIList', 'FishMiniGameDifficulty', 'FishPoolProbability', 'FishSite',
                 'FishSize', 'FishStage', 'FishTerritory', 'FishMiniGameAIType', 'FishPool', 'UIHiddenFish', 'ExchangeSystemConstant', 'ExchangeSystemInput',
                 'ExchangeSystemInputBonus', 'ExchangeSystemInputBonusOutput', 'ExchangeSystemOutput',
                 'ExchangeSystemRule']
        tables = {n: rows(n) for n in names}
        rod_ids = {r['FishingRodID'] for r in tables['FishDistribution']} - {0}
        bonuses = [r for r in rows('ItemBonus') if r['ItemClassID'] in rod_ids]
        bonus_ids = {r['BonusID'] for r in bonuses}
        values = {r['ID']: r for r in rows('Bonus') if r['ID'] in bonus_ids}
        types = {r['ID']: r['Name'] for r in rows('BonusType')}
        rods = {}
        for r in bonuses:
            b = values[r['BonusID']]
            rods.setdefault(str(r['ItemClassID']), {})[types[b['BonusTypeID']]] = b['Value']
        items = rows('ItemClass')
        # Keep exact IDs and eligibility fields; do not match inventory by name.
        tables['ItemClass'] = [{k: r[k] for k in ['ID', 'Name', 'GradeID', 'CategoryID', 'IsTradable', 'MaxStackAmount', 'TestItem', 'Cost']}
                               for r in items]
        tables['MerchantGoods'] = [r for r in rows('MerchantGoods') if r['ItemClassID'] in rod_ids and r['MerchantsID'] == 2231]
        territories = {r['TerritoriesID'] for r in tables['FishTerritory']}
        tables['Territories'] = [r for r in rows('Territories') if r['ID'] in territories]
        groups = {r['WeeklyOpenTimeGroupID'] for r in tables['FishContest']}
        tables['WeeklyOpenTimeGroupSet'] = [r for r in rows('WeeklyOpenTimeGroupSet') if r['WeeklyOpenTimeGroupId'] in groups]
        times = {r['WeeklyOpenTimeId'] for r in tables['WeeklyOpenTimeGroupSet']}
        tables['WeeklyOpenTimeEntity'] = [r for r in rows('WeeklyOpenTimeEntity') if r['WeeklyOpenTimeID'] in times]
        reward_ids = {r['RewardID'] for r in tables['FishContestRankReward']}
        tables['Reward'] = [r for r in rows('Reward') if r['ID'] in reward_ids]
        effect_ids = rod_ids | {r['ItemClassID'] for r in tables['ExchangeSystemOutput'] if r['RuleID'] in {1, 11, 21}} | {r['ItemClassID'] for r in tables['Fish'] if r['ItemClassID'] > 0}
        all_item_bonuses = rows('ItemBonus')
        all_bonuses = {r['ID']: r for r in rows('Bonus')}
        effects = {}
        for r in all_item_bonuses:
            if r['ItemClassID'] not in effect_ids:
                continue
            b = all_bonuses[r['BonusID']]
            effects.setdefault(str(r['ItemClassID']), []).append({'type': types[b['BonusTypeID']], 'value': b['Value'], 'bonus_id': b['ID']})
        bag_ids = {int(e['value']) for es in effects.values() for e in es if e['type'] == 'LuckyBagClassID'}
        tables['LuckyBagClass'] = [r for r in rows('LuckyBagClass') if r['ID'] in bag_ids]
        tables['LuckyBagEntityView'] = [r for r in rows('LuckyBagEntityView') if r['LuckyBagClassID'] in bag_ids]
        card_ids = {int(e['value']) for es in effects.values() for e in es if e['type'] == 'BuffCardID'}
        tables['BuffCard'] = [r for r in rows('BuffCard') if r['ID'] in card_ids]
        buff_ids = {r['BuffClassID'] for r in tables['BuffCard']}
        tables['CardBuffBonus'] = [r for r in rows('BuffBonus') if r['BuffClassID'] in buff_ids]
        tables['CardBonus'] = [all_bonuses[r['BonusID']] for r in tables['CardBuffBonus']]
        tables['ContestDescriptions'] = [r for r in rows('DescData_Korean') if r['ID'] in {d[k] for d in tables['FishContestRuleType'] for k in ['RuleDescID', 'RuleAlterDescID', 'UnitDescID']} ]
        tables['LuckyBagEntityType'] = rows('LuckyBagEntityType')
        tables['CurrencyUnitClass'] = [r for r in rows('CurrencyUnitClass') if r['CurrencyID'] == 2561]
        tables['Currency'] = [r for r in rows('Currency') if r['ID'] == 2561]
        return {'version': 523, 'tables': tables, 'rods': rods, 'item_effects': effects}


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('source', type=Path)
    p.add_argument('destination', type=Path)
    args = p.parse_args()
    pack = build(args.source)
    args.destination.parent.mkdir(parents=True, exist_ok=True)
    args.destination.write_text(json.dumps(pack, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    print('Private runtime pack:', args.destination, args.destination.stat().st_size, 'bytes')
