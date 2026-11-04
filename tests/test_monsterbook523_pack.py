"""Focused original-data pack audit; requires the separately materialized 523 ZIP."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
import zipfile

SPEC = importlib.util.spec_from_file_location('monsterbook523_build_pack', Path(__file__).parents[1] / 'tools/monsterbook523/build_pack.py')
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


@unittest.skipUnless(os.environ.get('MONSTERBOOK523_SOURCE_ZIP'), 'external original source required')
class SourcePackTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = Path(os.environ['MONSTERBOOK523_SOURCE_ZIP'])
        cls.pack = BUILDER.compile_pack(cls.source)
        with zipfile.ZipFile(cls.source) as archive:
            cls.raw = {name: json.loads(archive.read('content/' + name + '.json').decode('utf-8-sig'))['rows'] for name in cls.pack['tables']}

    def test_source_rows_retained_exactly(self):
        for name in ['MonsterBook', 'MonsterBookLevel', 'MonsterBookLevelBonus', 'MonsterBookLevelReward']:
            self.assertEqual(self.raw[name], self.pack['tables'][name])
        for name, rows in self.pack['tables'].items():
            if name == 'NpcClassForNpcGroup':
                groups = {r['NpcGroupID'] for r in self.raw['MonsterBook'] if r['NpcGroupID']}
                self.assertEqual(rows, [r for r in self.raw[name] if r['NpcGroupID'] in groups])
            else:
                selected = {r['ID'] for r in rows}
                self.assertEqual(rows, [r for r in self.raw[name] if r['ID'] in selected])

    def test_current_population(self):
        tables = self.pack['tables']
        books = [r for r in tables['MonsterBook'] if r['NpcGroupID']]
        self.assertEqual((len(tables['MonsterBook']), len(books), len(tables['NpcClassForNpcGroup'])), (557, 33, 944))
        self.assertEqual(len({r['NpcClassID'] for r in tables['NpcClassForNpcGroup']}), 944)
        book_ids = {r['ID'] for r in books}
        self.assertEqual(sum(r['MonsterBookID'] in book_ids for r in tables['MonsterBookLevel']), 97)
        self.assertTrue(all(r['ServerLimitSetID'] == 0 for r in tables['NpcClassForNpcGroup']))

    def test_daily_and_period_boundaries(self):
        tables = self.pack['tables']
        self.assertEqual([r for r in tables['MonsterBookLevelBonus'] if r['MonsterBookLevelID'] == 16423], [])
        book = next(r for r in tables['MonsterBook'] if r['ID'] == 6013)
        dates = {r['ID']: r for r in tables['DateTimes_Korean']}
        self.assertNotEqual(dates[book['CountingEndDateTimeID']], dates[book['EndDateTimeID']])
        self.assertEqual(dates[book['CountingEndDateTimeID']]['Day'], 28)
        self.assertEqual(dates[book['EndDateTimeID']]['Day'], 4)
        self.assertEqual(tables['Currency'][0]['Name'], 'Gem')

    def test_reference_closure_and_source_hashes(self):
        with zipfile.ZipFile(self.source) as archive:
            for name, evidence in self.pack['source_tables'].items():
                data = archive.read('content/' + name + '.json')
                self.assertEqual(hashlib.sha256(data).hexdigest(), evidence['sha256'])
                self.assertEqual(len(data), evidence['bytes'])
        self.assertEqual({r['BonusID'] for r in self.pack['tables']['MonsterBookLevelBonus']} | {r['BonusID'] for r in self.pack['tables']['ItemBonus']}, {r['ID'] for r in self.pack['tables']['Bonus']})
        self.assertEqual({r['RewardID'] for r in self.pack['tables']['MonsterBookLevelReward']}, {r['ID'] for r in self.pack['tables']['Reward']})

    def test_wrong_snapshot_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'wrong.zip'
            path.write_bytes(b'not the cumulative523 source')
            with self.assertRaisesRegex(ValueError, 'cumulative523'):
                BUILDER.compile_pack(path)


if __name__ == '__main__':
    unittest.main()
