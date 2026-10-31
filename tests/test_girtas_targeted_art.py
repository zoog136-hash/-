"""Guard targeted art replacement scope; this does not approve motion quality."""
import hashlib
import json
from pathlib import Path
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PATCH = ROOT / 'assets/actors/eight_direction/native_production/girtas_267/r004'


class GirtasTargetedArtContract(unittest.TestCase):
    def test_only_east_flight_pose_changes(self):
        spec = json.loads((PATCH / 'art_patch.json').read_text())
        base = ROOT / spec['base_frames']
        self.assertEqual(hashlib.sha256(base.read_bytes()).hexdigest(), spec['base_sha256'])
        expected = base.read_text().replace(spec['original_sheet'], spec['edited_sheet'])
        expected = expected.replace(
            'region = Rect2(1758, 3399, 1092, 1039)\nmargin = Rect2(376, 250, 956, 1009)',
            'region = Rect2(1536, 3072, 1286, 1223)\nmargin = Rect2(466, 294, 1146, 1209)')
        self.assertEqual((PATCH / 'SpriteFrames.tres').read_text(), expected)
        self.assertFalse(spec['visual_approval'])
        original = ROOT / spec['original_sheet']
        self.assertEqual(hashlib.sha256(original.read_bytes()).hexdigest(), spec['original_sha256'])
        with Image.open(original) as before, Image.open(ROOT / spec['edited_sheet']) as after:
            # Every source pixel outside the replaced cell is retained, including
            # the five unedited poses and their transparent margins.
            for box in [(0, 0, 3072, 3072), (0, 3072, 1536, 4608)]:
                self.assertEqual(before.crop(box).tobytes(), after.crop(box).tobytes())
            x, y, w, h = spec['new_phase5']['region']
            pose = after.crop((x, y, x+w, y+h))
            self.assertEqual(hashlib.sha256(pose.tobytes()).hexdigest(), spec['new_phase5']['rgba_sha256'])


if __name__ == '__main__':
    unittest.main()
