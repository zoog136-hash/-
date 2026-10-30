"""New S death production preserves all existing directions and approvals."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import pr122_transform_motion_scope as scope

POLICY = (Path(__file__).resolve().parents[1] / scope.POLICY).read_bytes()


class DeathScopeTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'data').mkdir()
        (self.root / scope.POLICY).write_bytes(POLICY)
        self.catalog = {'변신': [{'sourceId': 999, 'grade': '신화'},
                                {'sourceId': 413, 'grade': '신화'},
                                {'sourceId': 267, 'grade': '유일'},
                                {'sourceId': 393, 'grade': '유일'}]}
        self.save_catalog()

    def save_catalog(self):
        (self.root / scope.CATALOG).write_text(json.dumps(self.catalog))

    def test_new_unique_mythic_and_legendary_author_only_s(self):
        for grade in ('유일', '신화', '전설'):
            with self.subTest(grade=grade):
                self.catalog['변신'][0]['grade'] = grade
                self.save_catalog()
                self.assertEqual(scope.authoring_directions(self.root, 'transform:999', 'death'), ('S',))
                self.assertEqual(scope.required_directions(self.root, 'transform:999', 'death'), ('S',))
                for role in ('idle', 'walk', 'run', 'attack', 'hit'):
                    self.assertEqual(scope.required_directions(self.root, 'transform:999', role), scope.DIRECTIONS)

    def test_existing_five_deaths_and_unfinished_s_are_preserved(self):
        self.assertEqual(set(scope.required_directions(self.root, 'transform:413', 'death')),
                         {'E', 'SE', 'S', 'NW', 'N', 'NE'})
        ledger = scope.load_policy(self.root)['death_source_ledger']['transform:413']
        self.assertEqual(ledger['existing_connected_source_count'], 5)
        self.assertEqual(ledger['additional_new_source_count'], 0)
        self.assertEqual(ledger['remaining_source_completion_directions'], ['S'])
        self.assertEqual(ledger['preserved_S_source']['status'], 'HOLD_NOT_APPROVED')
        self.assertEqual(len(scope.required_tracks(self.root, 'transform:413')), 38)

    def test_both_previously_approved_actors_keep_all_48_requirements(self):
        for key in ('transform:267', 'transform:393'):
            self.assertEqual(scope.required_directions(self.root, key, 'death'), scope.DIRECTIONS)
            self.assertEqual(len(scope.required_tracks(self.root, key)), 48)

    def test_existing_four_views_remain_required_without_new_diagonal_art(self):
        policy = json.loads(POLICY)
        policy['death_source_ledger']['transform:999'] = {
            'existing_connected_directions': ['N', 'E', 'S', 'W']}
        (self.root / scope.POLICY).write_text(json.dumps(policy))
        self.assertEqual(set(scope.required_directions(self.root, 'transform:999', 'death')),
                         {'N', 'E', 'S', 'W'})
        self.assertEqual(scope.authoring_directions(self.root, 'transform:999', 'death'), ('S',))

    def test_legacy_fixture_and_unknown_boss_keep_strict_directions(self):
        self.assertEqual(scope.required_directions(self.root, 'monster:99', 'death'), scope.DIRECTIONS)
        (self.root / scope.POLICY).unlink()
        self.assertEqual(len(scope.required_tracks(self.root, 'transform:999')), 48)

    def test_four_view_new_death_policy_is_rejected(self):
        policy = json.loads(POLICY)
        policy['death_direction_policy']['신화']['direction_names'] = ['N', 'E', 'S', 'W']
        (self.root / scope.POLICY).write_text(json.dumps(policy))
        with self.assertRaises(ValueError):
            scope.load_policy(self.root)


if __name__ == '__main__':
    unittest.main()
