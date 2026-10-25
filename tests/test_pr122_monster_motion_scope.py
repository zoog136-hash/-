"""Monster scope can omit new WALK/death views without losing approved art."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import pr122_monster_motion_scope as monster
import pr122_transform_motion_scope as scope


class MonsterScopeTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / 'data').mkdir()
        self.policy = {
            'schema': 'pr122-monster-motion-scope-v1', 'new_walk_required': False,
            'new_death_directions': ['S'], 'preserve_existing_walk': True,
            'preserve_existing_directional_death': True, 'omission_grants_approval': False,
            'monsters': [
                {'id': 'monster:일반', 'preserved_status': 'NOT_AUTHORED', 'existing_death_directions': []},
                {'id': 'monster:보스', 'preserved_status': 'IN_PROGRESS', 'existing_death_directions': []},
                {'id': 'monster:기존보스', 'preserved_status': 'VERIFIED_COMPLETED', 'existing_death_directions': ['E', 'S', 'N']},
            ]}
        self.save()

    def save(self):
        (self.root / monster.POLICY).write_text(json.dumps(self.policy))

    def test_new_normal_and_boss_have_33_required_tracks(self):
        for key in ('monster:일반', 'monster:보스'):
            self.assertFalse(scope.requires_walk(self.root, key))
            self.assertEqual(len(scope.required_tracks(self.root, key)), 33)
            self.assertEqual(scope.authoring_directions(self.root, key, 'death'), ('S',))
            for role in ('idle', 'run', 'attack', 'hit'):
                self.assertEqual(scope.required_directions(self.root, key, role), scope.DIRECTIONS)

    def test_existing_approved_death_views_stay_required(self):
        self.assertEqual(scope.required_directions(self.root, 'monster:기존보스', 'death'), ('E', 'S', 'N'))
        self.assertEqual(scope.authoring_directions(self.root, 'monster:기존보스', 'death'), ('S',))

    def test_unknown_monster_and_transform_preserve_legacy_contract(self):
        for key in ('monster:unknown', 'boss:unknown', 'transform:unknown'):
            self.assertEqual(len(scope.required_tracks(self.root, key)), 48)

    def test_scope_cannot_grant_approval_or_drop_preservation(self):
        for field in ('omission_grants_approval', 'preserve_existing_walk', 'preserve_existing_directional_death'):
            original = self.policy[field]
            self.policy[field] = not original
            self.save()
            with self.assertRaises(ValueError):
                scope.required_tracks(self.root, 'monster:보스')
            self.policy[field] = original


if __name__ == '__main__':
    unittest.main()
