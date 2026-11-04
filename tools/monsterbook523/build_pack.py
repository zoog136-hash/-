#!/usr/bin/env python3
"""Compile exact patch523 MonsterBook joins to an external, private runtime pack."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile
import zipfile

SOURCE_SHA256 = 'd5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'
SCHEMA = 'twilight.monsterbook523.v1'


def compile_pack(source: Path) -> dict:
    if hashlib.sha256(source.read_bytes()).hexdigest() != SOURCE_SHA256:
        raise ValueError('expected validated cumulative523 source ZIP (not base508)')
    with zipfile.ZipFile(source) as archive:
        if archive.testzip() is not None:
            raise ValueError('ZIP CRC failure')
        evidence = {}
        cache = {}

        def read(name):
            if name in cache:
                return cache[name]
            data = archive.read('content/' + name + '.json')
            rows = json.loads(data.decode('utf-8-sig'))['rows']
            evidence[name] = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(), 'rows': len(rows)}
            cache[name] = rows
            return rows

        def select(name, ids):
            rows = [r for r in read(name) if r['ID'] in ids]
            if {r['ID'] for r in rows} != ids:
                raise ValueError('missing references in ' + name)
            return rows

        tables = {n: read(n) for n in ['MonsterBook', 'MonsterBookLevel', 'MonsterBookLevelBonus', 'MonsterBookLevelReward']}
        books = tables['MonsterBook']
        groups = {r['NpcGroupID'] for r in books if r['NpcGroupID'] != 0}
        tables['NpcClassForNpcGroup'] = [r for r in read('NpcClassForNpcGroup') if r['NpcGroupID'] in groups]
        reward_ids = {x['RewardID'] for x in tables['MonsterBookLevelReward']}
        rewards_by_id = {r['ID']: r for r in read('Reward')}
        item_ids = {r['RewardClassID'] for r in read('Reward') if r['RewardTypeID'] == 2 and r['ID'] in reward_ids}
        current_book_ids = {r['ID'] for r in books if r['NpcGroupID']}
        current_level_ids = {r['ID'] for r in tables['MonsterBookLevel'] if r['MonsterBookID'] in current_book_ids}
        current_reward_ids = {r['RewardID'] for r in tables['MonsterBookLevelReward'] if r['MonsterBookLevelID'] in current_level_ids}
        action_roots = {rewards_by_id[i]['RewardClassID'] for i in current_reward_ids if rewards_by_id[i]['RewardTypeID'] == 2}
        bonuses_by_id = {r['ID']: r for r in read('Bonus')}
        types_by_id = {r['ID']: r for r in read('BonusType')}
        pending, visited = list(action_roots), set()
        select_ids, market_ids, intangible_ids = set(), set(), set()
        while pending:
            item_id = pending.pop()
            if item_id in visited:
                continue
            visited.add(item_id)
            for link in read('ItemBonus'):
                if link['ItemClassID'] != item_id:
                    continue
                bonus = bonuses_by_id[link['BonusID']]
                kind = types_by_id[bonus['BonusTypeID']]['Name']
                if kind == 'MarketPurchaseID':
                    market_ids.add(bonus['Value'])
                elif kind == 'IntangibleItemClassID':
                    intangible_ids.add(bonus['Value'])
                elif kind == 'SelectRewardClassID':
                    parent = rewards_by_id[bonus['Value']]
                    if parent['RewardTypeID'] != 111:
                        raise ValueError('unexpected nested selection reward type')
                    reward_ids.add(parent['ID'])
                    select_ids.add(parent['RewardClassID'])
                    for entity in read('SelectRewardEntity'):
                        if entity['SelectRewardID'] != parent['RewardClassID']:
                            continue
                        reward_ids.add(entity['RewardID'])
                        child = rewards_by_id[entity['RewardID']]
                        if child['RewardTypeID'] == 2:
                            item_ids.add(child['RewardClassID'])
                            pending.append(child['RewardClassID'])
        tables['SelectReward'] = select('SelectReward', select_ids)
        tables['SelectRewardEntity'] = [r for r in read('SelectRewardEntity') if r['SelectRewardID'] in select_ids]
        tables['MarketPurchase_Korean'] = select('MarketPurchase_Korean', market_ids)
        tables['MarketPurchaseProduct'] = [r for r in read('MarketPurchaseProduct') if r['MarketPurchaseID'] in market_ids]
        product_ids = {r['MarketProductID'] for r in tables['MarketPurchaseProduct']}
        tables['MarketProduct'] = select('MarketProduct', product_ids)
        # Additional products/bonuses must not disappear from a pack silently.
        tables['MarketProductAdditional'] = [r for r in read('MarketProductAdditional') if r['MarketProductID'] in product_ids]
        tables['MarketBonusForPurchase'] = [r for r in read('MarketBonusForPurchase') if r['MarketPurchaseID'] in market_ids]
        gotcha_ids = {r['ClassID'] for r in tables['MarketProduct'] if r['UnitID'] == 35}
        tables['GotChaEntityView'] = [r for r in read('GotChaEntityView') if r['GotChaClassID'] in gotcha_ids]
        tables['BuffCard'] = select('BuffCard', {r['ClassID'] for r in tables['GotChaEntityView'] if r['UnitID'] == 33})
        tables['IntangibleItemClass'] = select('IntangibleItemClass', intangible_ids)
        tables['ItemBonus'] = [r for r in read('ItemBonus') if r['ItemClassID'] in item_ids]
        tables['Bonus'] = select('Bonus', {r['BonusID'] for r in tables['MonsterBookLevelBonus']} | {r['BonusID'] for r in tables['ItemBonus']})
        tables['BonusType'] = select('BonusType', {r['BonusTypeID'] for r in tables['Bonus']})
        tables['BonusApplicationType'] = select('BonusApplicationType', {r['BonusApplicationTypeID'] for r in tables['Bonus']})
        tables['SpecialResistanceType'] = select('SpecialResistanceType', {r['BonusApplicationTargetID'] for r in tables['Bonus'] if r['BonusApplicationTypeID'] == 2})
        tables['Reward'] = select('Reward', reward_ids)
        tables['RewardType'] = select('RewardType', {r['RewardTypeID'] for r in tables['Reward']})
        tables['Unit'] = select('Unit', {r['UnitID'] for r in tables['BonusType']} | {r['UnitID'] for r in tables['MarketProduct']} | {r['UnitID'] for r in tables['GotChaEntityView']})
        unit_ids = {r['ID'] for r in tables['Unit']}
        tables['UIUnit'] = [r for r in read('UIUnit') if r['UnitID'] in unit_ids]
        tables['ItemClass'] = select('ItemClass', item_ids)
        tables['ItemCategory'] = select('ItemCategory', {r['CategoryID'] for r in tables['ItemClass']})
        tables['Grade'] = select('Grade', {r['GradeID'] for r in tables['ItemClass']} | {r['GradeID'] for r in tables['BuffCard']})
        tables['Currency'] = select('Currency', {r['CurrencyID'] for r in tables['MonsterBookLevel'] if r['CurrencyID']})
        date_ids = {r[k] for r in books for k in ['StartDateTimeID', 'CountingEndDateTimeID', 'EndDateTimeID'] if r[k]}
        date_ids |= {r['BonusApplicationTargetID'] for r in tables['Bonus'] if r['BonusApplicationTypeID'] == 298 and r['BonusApplicationTargetID']}
        tables['DateTimes_Korean'] = select('DateTimes_Korean', date_ids)
        desc_ids = {r[k] for n in ['BonusType', 'RewardType', 'Currency', 'ItemClass', 'ItemCategory', 'Grade', 'SpecialResistanceType', 'IntangibleItemClass', 'BuffCard'] for r in tables[n] for k in ['DescID'] if r.get(k)}
        tables['DescData_Korean'] = select('DescData_Korean', desc_ids)
        ids = {r['ID'] for r in books}
        levels = tables['MonsterBookLevel']
        level_ids = {r['ID'] for r in levels}
        if not all(r['MonsterBookID'] in ids for r in levels):
            raise ValueError('orphan stage')
        for name in ['MonsterBookLevelBonus', 'MonsterBookLevelReward']:
            if not all(r['MonsterBookLevelID'] in level_ids for r in tables[name]):
                raise ValueError('orphan stage link')
        current = {r['ID'] for r in books if r['NpcGroupID']}
        if (len(books), len(current), len(tables['NpcClassForNpcGroup'])) != (557, 33, 944):
            raise ValueError('patch523 target population mismatch')
        if len([r for r in levels if r['MonsterBookID'] in current]) != 97:
            raise ValueError('patch523 stage count mismatch')
        return {'schema': SCHEMA, 'source_sha256': SOURCE_SHA256, 'source_tables': evidence, 'tables': tables}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-zip', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True, help='private path outside the checkout')
    args = parser.parse_args()
    checkout = Path(__file__).resolve().parents[2]
    if args.output.resolve().is_relative_to(checkout):
        parser.error('runtime source tables must remain outside the public checkout')
    pack = compile_pack(args.source_zip)
    data = (json.dumps(pack, ensure_ascii=False, separators=(',', ':')) + '\n').encode()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fd, temp = tempfile.mkstemp(dir=args.output.parent, prefix='.monsterbook523-')
    try:
        with os.fdopen(fd, 'wb') as out:
            out.write(data)
            out.flush()
            os.fsync(out.fileno())
        os.replace(temp, args.output)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)
    print(json.dumps({'output': str(args.output), 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
                      'tables': {k: len(v) for k, v in pack['tables'].items()}, 'delivery': 'PRIVATE_LOCAL_ONLY'}))


if __name__ == '__main__':
    main()
