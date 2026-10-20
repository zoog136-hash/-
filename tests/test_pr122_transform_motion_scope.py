"""Boundaries for the user's transformation-only WALK omission."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import pr122_native_production_approvals as gate
import pr122_transform_motion_scope as scope
from test_pr122_native_production_approvals import ApprovalFixture

POLICY_BYTES = (Path(__file__).resolve().parents[1] / scope.POLICY).read_bytes()


class TransformWalkScopeTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.fixture = ApprovalFixture(self.root, approved=False)
        self.fixture.write(scope.POLICY.as_posix(), POLICY_BYTES)

    def grade(self, grade):
        self.fixture.default_catalog['변신'][0]['grade'] = grade
        self.fixture.write_json(gate.DEFAULT_CATALOG, self.fixture.default_catalog)

    def drop_role(self, role):
        f = self.fixture
        f.actor['tracks'] = [t for t in f.actor['tracks'] if t['role'] != role]
        f.actor['native_track_count'] = len(f.actor['tracks'])
        f.actor['native_pose_count'] = len(f.actor['tracks']) * 6
        for table in ('selected_locomotion_sheets', 'selected_detailed_action_sheets'):
            f.manifest[table] = {k: v for k, v in f.manifest[table].items() if not k.endswith(':' + role)}
        f.flush_data()

    def describe(self):
        return gate.describe_actor(self.root, self.fixture.key,
                                   manifest=self.fixture.manifest, register=self.fixture.register)

    def test_all_six_lower_grades_omit_only_walk(self):
        for grade in scope.EXCLUDED_GRADES:
            self.grade(grade)
            self.assertEqual(scope.required_roles(self.root, self.fixture.key), scope.FULL_ROLES - {'walk'})

    def test_unique_unknown_and_boss_keep_walk(self):
        for grade in ('유일', '', 'unknown'):
            self.grade(grade)
            self.assertTrue(scope.requires_walk(self.root, self.fixture.key))
        self.grade('신화')
        for key in ('monster:393', 'boss:393', 'class:393', 'transform:999999'):
            self.assertTrue(scope.requires_walk(self.root, key))

    def test_mythic_all_five_roles_and_six_poses_pass_scope(self):
        self.grade('신화')
        self.drop_role('walk')
        description = self.describe()
        self.assertEqual(len(description['tracks']), 40)
        self.assertEqual(description['pins']['motion_requirements']['authored_pose_count'], 240)
        self.assertFalse(self.fixture.actor['detailed_completed'])

    def test_unique_cannot_omit_walk(self):
        self.grade('유일')
        self.drop_role('walk')
        with self.assertRaises(gate.ApprovalError):
            self.describe()

    def test_every_other_missing_role_is_rejected(self):
        self.grade('신화')
        for role in scope.FULL_ROLES - {'walk'}:
            saved = json.loads(json.dumps((self.fixture.actor, self.fixture.manifest)))
            self.drop_role(role)
            with self.assertRaises(gate.ApprovalError):
                self.describe()
            self.fixture.actor.clear(); self.fixture.actor.update(saved[0])
            self.fixture.manifest.clear(); self.fixture.manifest.update(saved[1])

    def test_existing_walk_sources_are_retained_and_pinned(self):
        self.grade('신화')
        description = self.describe()
        self.assertEqual(len(description['tracks']), 48)
        self.assertEqual(description['pins']['motion_requirements']['required_track_count'], 40)
        self.assertEqual(description['pins']['motion_requirements']['authored_track_count'], 48)

    def test_five_role_certificate_still_requires_full_quality_and_default_main(self):
        self.fixture = ApprovalFixture(self.root, approved=True)
        self.grade('신화')
        self.drop_role('walk')
        f = self.fixture
        description = self.describe()
        pins = description['pins']
        f.quality['source_selection_sha256'] = pins['source_selection_sha256']
        f.quality['tracks'] = [t for t in f.quality['tracks'] if t['role'] != 'walk']
        f.main['pins'] = pins
        f.main['checks'].pop('all_48_tracks')
        f.main['checks']['all_required_tracks'] = 'PASS'
        f.write('evidence/main.log', (gate.default_main_marker(f.key, 40) + '\n').encode())
        f.main['log'] = f.pin('evidence/main.log')
        f.certificate['pins'] = pins
        f.flush_evidence()
        self.assertEqual(f.load().completed_count, 1)
        f.quality['checks']['attack_contact'] = 'HOLD'
        f.flush_evidence()
        with self.assertRaises(gate.ApprovalError):
            f.load()
        f.quality['checks']['attack_contact'] = 'PASS'
        f.main['candidate_injection'] = True
        f.flush_evidence()
        with self.assertRaises(gate.ApprovalError):
            f.load()

    def test_scope_cannot_omit_another_role_or_unique_or_boss(self):
        original = json.loads(POLICY_BYTES)
        for field, value in [('required_roles_without_walk', ['idle', 'run']),
                             ('walk_excluded_grades', ['유일']),
                             ('boss_walk_required', False),
                             ('omission_grants_approval', True)]:
            altered = dict(original); altered[field] = value
            self.fixture.write_json(scope.POLICY.as_posix(), altered)
            with self.assertRaises(ValueError):
                scope.required_roles(self.root, self.fixture.key)


if __name__ == '__main__':
    unittest.main()
