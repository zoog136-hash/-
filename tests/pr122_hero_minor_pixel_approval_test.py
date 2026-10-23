"""User-authorized pixel exceptions never approve different or unreviewed art."""
import copy
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('hero_qa', ROOT / 'docs/remake/pr122-hero-parallel/check_artifacts.py')
qa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qa)


class MinorPixelApproval(unittest.TestCase):
    def setUp(self):
        self.detached = [dict(direction=6, phase=4, rgba_sha256='sealed-pose', components_8=[2469,188])]
        self.accepted = dict(status='APPROVED_MINOR_PIXEL_GAPS', findings=[dict(
            direction=6, phase=4, rgba_sha256='sealed-pose', component_sizes=[2469,188],
            empty_grid_gap_pixels=2, accepted_by_latest_user_policy=True)])

    def test_exact_manually_reviewed_pixels_pass(self):
        qa.require_approved_connectivity(self.detached, self.accepted)
        qa.require_approved_connectivity([])

    def test_unreviewed_pixels_are_still_rejected(self):
        with self.assertRaises(AssertionError):
            qa.require_approved_connectivity(self.detached)
        changed = copy.deepcopy(self.detached)
        changed[0]['rgba_sha256'] = 'different-pose'
        with self.assertRaises(AssertionError):
            qa.require_approved_connectivity(changed, self.accepted)

    def test_larger_gap_or_additional_detachment_is_rejected(self):
        changed = copy.deepcopy(self.accepted)
        changed['findings'][0]['empty_grid_gap_pixels'] = 3
        with self.assertRaises(AssertionError):
            qa.require_approved_connectivity(self.detached, changed)
        with self.assertRaises(AssertionError):
            qa.require_approved_connectivity(self.detached * 2, self.accepted)


if __name__ == '__main__':
    unittest.main()
