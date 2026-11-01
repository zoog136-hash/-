"""Source/clock preservation and measured stance displacement, not visual approval."""
import hashlib
import json
from pathlib import Path
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PATCH = ROOT / 'assets/actors/eight_direction/native_production/girtas_267/r006'


class GirtasSupportContact(unittest.TestCase):
    def test_replacement_is_only_east_support_pose(self):
        spec = json.loads((PATCH / 'support_contact_patch.json').read_text())
        base = ROOT / spec['base_frames']
        self.assertEqual(hashlib.sha256(base.read_bytes()).hexdigest(), spec['base_sha256'])
        expected = base.read_text().replace(spec['original_sheet'], spec['edited_sheet'])
        expected = expected.replace(
            'region = Rect2(1720, 203, 1167, 1177)\nmargin = Rect2(596, 474, 1393, 1383)',
            'region = Rect2(1536, 0, 1246, 1262)\nmargin = Rect2(663, 506, 1514, 1498)')
        self.assertEqual((PATCH / 'SpriteFrames.tres').read_text(), expected)
        with Image.open(ROOT / spec['original_sheet']) as old, Image.open(ROOT / spec['edited_sheet']) as new:
            for box in [(0, 0, 1536, 1536), (0, 1536, 3072, 4608)]:
                self.assertEqual(old.crop(box).tobytes(), new.crop(box).tobytes())
            x, y, w, h = spec['new_phase1']['region']
            self.assertEqual(hashlib.sha256(new.crop((x, y, x+w, y+h)).tobytes()).hexdigest(),
                             spec['new_phase1']['rgba_sha256'])
        self.assertFalse(spec['visual_approval'])

    def test_boot_moves_back_by_nearly_one_existing_pose_distance(self):
        spec = json.loads((PATCH / 'support_contact_patch.json').read_text())
        frame = spec['new_phase1']
        with Image.open(ROOT / spec['edited_sheet']) as image:
            x, y, w, h = frame['region']
            alpha = image.crop((x, y, x+w, y+h)).getchannel('A')
            roi = spec['calibration']['boot_roi']
            bound = alpha.crop(tuple(roi)).point(lambda v: 255 if v > 16 else 0).getbbox()
        sole_y = roi[1] + bound[3] - 1
        self.assertEqual(sole_y, 1219)
        self.assertEqual(frame['margin'][1] + sole_y, frame['foot'][1])
        target = spec['target']
        # A source-coordinate trajectory check, not a no-slip quality verdict.
        backward = target['old_E0_sole_world_x'] - target['new_E1_sole_world_x']
        self.assertGreater(backward, 14)
        self.assertLess(abs(target['pose_distance'] - backward), 2.1)


if __name__ == '__main__':
    unittest.main()
