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

        def read(name):
            data = archive.read('content/' + name + '.json')
            rows = json.loads(data.decode('utf-8-sig'))['rows']
            evidence[name] = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(), 'rows': len(rows)}
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
        tables['Bonus'] = select('Bonus', {r['BonusID'] for r in tables['MonsterBookLevelBonus']})
        tables['BonusType'] = select('BonusType', {r['BonusTypeID'] for r in tables['Bonus']})
        tables['Reward'] = select('Reward', {r['RewardID'] for r in tables['MonsterBookLevelReward']})
        tables['RewardType'] = select('RewardType', {r['RewardTypeID'] for r in tables['Reward']})
        tables['Unit'] = select('Unit', {r['UnitID'] for r in tables['BonusType']})
        tables['ItemClass'] = select('ItemClass', {r['RewardClassID'] for r in tables['Reward'] if r['RewardTypeID'] == 2})
        tables['Currency'] = select('Currency', {r['CurrencyID'] for r in tables['MonsterBookLevel'] if r['CurrencyID']})
        date_ids = {r[k] for r in books for k in ['StartDateTimeID', 'CountingEndDateTimeID', 'EndDateTimeID'] if r[k]}
        tables['DateTimes_Korean'] = select('DateTimes_Korean', date_ids)
        desc_ids = {r[k] for n in ['BonusType', 'RewardType', 'Currency', 'ItemClass'] for r in tables[n] for k in ['DescID'] if r.get(k)}
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
