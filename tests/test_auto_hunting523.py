"""Exact source joins and private pack delivery; no gameplay fixtures substituted."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('auto_hunting523', ROOT / 'tools/build_auto_hunting523.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class SourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = os.environ.get('TWILIGHT_523_SOURCE_ZIP')
        if not source:
            raise unittest.SkipTest('actual cumulative523 ZIP not configured')
        cls.source = Path(source)
        with tempfile.TemporaryDirectory() as directory:
            cls.receipt = builder.build(cls.source, Path(directory))
            cls.payload = json.loads((Path(directory) / builder.PACK_NAME).read_text())
        with zipfile.ZipFile(cls.source) as archive:
            cls.tables = {name: json.loads(archive.read('content/' + name + '.json').decode('utf-8-sig'))['rows']
                          for name in builder.TABLE_SHA256}

    def test_all_rows_and_multiland_destinations_preserved(self):
        entries = self.payload['entries']
        self.assertEqual([e['schedule'] for e in entries], self.tables['AutoScheduleLandTeleport'])
        self.assertEqual(len(entries), 80)
        self.assertEqual(sum(len(e['destinations']) for e in entries), 87)
        self.assertEqual(len({d['land']['ID'] for e in entries for d in e['destinations']}), 22)
        for entry in entries:
            tid = entry['schedule']['LandTeleportID']
            self.assertEqual([d['link'] for d in entry['destinations']],
                             [r for r in self.tables['LandTeleportTerritories'] if r['LandTeleportID'] == tid])
            for d in entry['destinations']:
                self.assertEqual(d['territory'], next(r for r in self.tables['Territories'] if r['ID'] == d['link']['TerritoryID']))
                self.assertEqual(d['land'], next(r for r in self.tables['Land'] if r['ID'] == d['territory']['LandID']))

    def test_zero_is_never_land_zero_hunting_region(self):
        entries = self.payload['entries']
        zero = [e for e in entries if e['schedule']['TerritoryID'] == 0]
        self.assertEqual(len(zero), 25)
        self.assertEqual(sum(len(e['destinations']) for e in zero), 32)
        for entry in zero:
            self.assertIsNone(entry['hunting_territory'])
            self.assertIsNone(entry['hunting_land'])
        self.assertEqual(self.payload['territory_zero_sentinel']['Name'], 'None')

    def test_hunt_and_landing_are_separate(self):
        first = self.payload['entries'][0]
        self.assertEqual(first['hunting_territory']['ID'], 1723)
        self.assertEqual(first['destinations'][0]['territory']['ID'], 113222)
        self.assertNotEqual(first['hunting_territory'], first['destinations'][0]['territory'])
        self.assertEqual(first['schedule']['RecommendLevel'], 19)
        self.assertEqual(first['prerequisites'], [])

    def test_all_raw_fields_costs_flags_and_conditions(self):
        for entry in self.payload['entries']:
            teleport = next(r for r in self.tables['LandTeleport'] if r['ID'] == entry['schedule']['LandTeleportID'])
            self.assertEqual(entry['teleport'], teleport)
            self.assertEqual(entry['category'], next(r for r in self.tables['AutoScheduleCategory'] if r['ID'] == entry['schedule']['AutoScheduleCategoryID']))
            links = [r for r in self.tables['LandTeleportPrerequisite'] if r['LandTeleportID'] == teleport['ID']]
            self.assertEqual([c['link'] for c in entry['prerequisites']], links)
            for condition in entry['prerequisites']:
                self.assertEqual(condition['definition'], next(r for r in self.tables['Prerequisite'] if r['ID'] == condition['link']['PrerequisiteID']))
                self.assertEqual(condition['type'], next(r for r in self.tables['PrerequisiteType'] if r['ID'] == condition['definition']['PrerequisiteTypeID']))
        self.assertEqual(sum(bool(e['prerequisites']) for e in self.payload['entries']), 19)

    def test_independent_deep_research_join_matches(self):
        path = os.environ.get('TWILIGHT_523_MOVEMENT_RESEARCH')
        if not path:
            self.skipTest('optional independent deep research not configured')
        research = json.loads(Path(path).read_text())
        for entry, independent in zip(self.payload['entries'], research, strict=True):
            self.assertEqual(entry['schedule'], independent['AutoScheduleLandTeleport'])
            self.assertEqual(entry['teleport'], independent['LandingRoutes']['LandTeleport'])
            self.assertEqual(entry['hunting_territory'], independent['HuntingRegion'].get('raw') if entry['schedule']['TerritoryID'] != 0 else None)
            self.assertEqual([d['territory'] for d in entry['destinations']],
                             [d['Territory']['raw'] for d in independent['LandingRoutes']['Destinations']])

    def test_repeat_is_exact_and_conflict_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory)
            first = builder.build(self.source, destination)
            self.assertEqual(builder.build(self.source, destination), first)
            target = destination / builder.PACK_NAME
            target.write_bytes(b'previous-installed-pack')
            with self.assertRaisesRegex(ValueError, 'refusing to overwrite'):
                builder.build(self.source, destination)
            self.assertEqual(target.read_bytes(), b'previous-installed-pack')


class RejectionTests(unittest.TestCase):
    def test_other_source_rejected_before_writing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'wrong.zip').write_bytes(b'not-cumulative523')
            with self.assertRaisesRegex(ValueError, 'exact validated'):
                builder.build(root / 'wrong.zip', root / 'output')
            self.assertFalse((root / 'output').exists())


if __name__ == '__main__':
    unittest.main()
