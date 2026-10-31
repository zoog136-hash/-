"""Preserve authored pixels/clocks while repairing five registration offsets.

These are resource contracts, not a visual animation approval.
"""
import hashlib
import json
from pathlib import Path
import re
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PATCH = ROOT / 'assets/actors/eight_direction/native_production/girtas_267/r003'


class GirtasRegistrationContract(unittest.TestCase):
    def test_only_reviewed_translations_change(self):
        spec = json.loads((PATCH / 'registration_patch.json').read_text())
        original = ROOT / spec['base_frames'].removeprefix('res://')
        self.assertEqual(hashlib.sha256(original.read_bytes()).hexdigest(), spec['base_sha256'])
        expected = original.read_text()
        for frame in spec['patches']:
            source = ROOT / frame['source']
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), frame['source_sha256'])
            # Same physical canvas dimensions: no frame-dependent scale change.
            self.assertEqual(frame['old_margin'][2:], frame['new_margin'][2:])
            pattern = (r'(\[sub_resource type="AtlasTexture" id="' + frame['subresource']
                       + r'"\][\s\S]*?margin = Rect2\()([^\n]+)(\))')
            match = re.search(pattern, expected)
            self.assertIsNotNone(match)
            self.assertEqual([int(v) for v in match[2].split(',')], frame['old_margin'])
            expected = expected[:match.start(2)] + ', '.join(map(str, frame['new_margin'])) + expected[match.end(2):]
        # Includes all textures, regions, attack/hit/death clips, durations and FPS.
        self.assertEqual((PATCH / 'SpriteFrames.tres').read_text(), expected)
        self.assertFalse(spec['visual_approval'])

    def test_east_planted_boots_reach_ground_without_moving_flight_poses(self):
        spec = json.loads((PATCH / 'registration_patch.json').read_text())
        east = [f for f in spec['patches'] if f['direction'] == 'E']
        self.assertEqual([f['phase'] for f in east], [0, 1])
        for frame in east:
            x, y, w, h = frame['region']
            with Image.open(ROOT / frame['source']) as image:
                alpha = image.crop((x, y, x+w, y+h)).getchannel('A')
                bounds = alpha.point(lambda value: 255 if value > 16 else 0).getbbox()
            sole = bounds[3] - 1
            canvas = frame['canvas'][1]
            old_y = -28.045441501663 + .219105011732 * 1024 / canvas * (frame['old_margin'][1] + sole - canvas / 2)
            new_y = -28.045441501663 + .219105011732 * 1024 / canvas * (frame['new_margin'][1] + sole - canvas / 2)
            self.assertLess(old_y, -3.5)  # Reproduces the old floating contact.
            self.assertLess(abs(new_y), .01)


if __name__ == '__main__':
    unittest.main()
