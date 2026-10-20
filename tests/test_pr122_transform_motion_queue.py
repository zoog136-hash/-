"""Queue the user's required actions without inventing missing WALK work."""
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import checkpoint_pr122_native_clip as checkpoint
import pr122_transform_motion_scope as scope
from test_pr122_native_production_approvals import ApprovalFixture


class TransformMotionQueueTest(unittest.TestCase):
    def test_only_lower_transformations_skip_walk_and_walk_prerequisites(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture = ApprovalFixture(root, approved=False)
            fixture.write(scope.POLICY.as_posix(),
                          (Path(__file__).resolve().parents[1] / scope.POLICY).read_bytes())
            for grade in ('신화', '유일'):
                fixture.default_catalog['변신'][0]['grade'] = grade
                fixture.write_json(scope.CATALOG.as_posix(), fixture.default_catalog)
                register = {}
                manifest = {'selected_locomotion_sheets': {}, 'selected_detailed_action_sheets': {}}
                with patch.dict(checkpoint.staging.ACTORS, {fixture.key: 'fixture'}, clear=True):
                    missing, core, _ = checkpoint.update_authoring_queue(register, manifest, root=root)
                self.assertEqual(missing, 8 if grade == '신화' else 16)
                self.assertEqual(core, 32)
                self.assertEqual(register['next_locomotion_source']['role'], 'run' if grade == '신화' else 'walk')
                if grade == '신화':
                    self.assertEqual(register['next_detailed_source']['role'], 'attack')
                else:
                    self.assertIsNone(register['next_detailed_source'])


if __name__ == '__main__':
    unittest.main()
