"""Physical sizing invariants for source-resolution-independent native profiles."""
import copy
from pathlib import Path
import sys
import tempfile
import unittest

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from bind_pr122_native_locomotion_profiles import runtime_walk_reference_height


class RuntimeProfileSizingTest(unittest.TestCase):
    def fixture(self, root, *, factor=1, padding=0, canvas_factor=1):
        image = Image.new('RGBA', (200 * factor, 100 * factor))
        frames = []
        for phase, left in [(0, 10), (3, 100)]:
            image.paste((70, 80, 90, 255),
                        ((left + 10) * factor, 10 * factor,
                         (left + 30) * factor, 58 * factor))
            frames.append(dict(row=phase,
                region=[(left - padding) * factor, 0,
                        (60 + 2 * padding) * factor, (80 + padding) * factor],
                canvas_size=[128 * canvas_factor * factor] * 2))
        source = f'source-{factor}-{padding}-{canvas_factor}.png'
        image.save(root / source)
        return dict(canvas_size=[1024, 1024], tracks=[dict(
            direction='E', role='walk', source=source,
            geometry=dict(canvas_size=[128 * factor] * 2,
                          neutral_height=48 * factor, frames=frames))])

    def test_source_resolution_does_not_change_actor_display_size(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            low = runtime_walk_reference_height(root, self.fixture(root))[0]
            high = runtime_walk_reference_height(root, self.fixture(root, factor=2))[0]
            self.assertEqual(low, 384)
            self.assertEqual(high, low)
            self.assertEqual(110 / low, 110 / high)

    def test_transparent_reviewed_padding_does_not_change_display_size(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            plain = runtime_walk_reference_height(root, self.fixture(root))[0]
            padded = runtime_walk_reference_height(root, self.fixture(root, padding=8))[0]
            self.assertEqual(padded, plain)

    def test_effective_per_pose_canvas_and_authored_phases_are_used(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            actor = self.fixture(root)
            # Deliberately stale raw summary cannot override actual texture sizing.
            actor['tracks'][0]['geometry']['neutral_height'] = 99999
            actor['tracks'][0]['geometry']['frames'][1]['canvas_size'] = [256, 256]
            actor['tracks'][0]['geometry']['frames'].reverse()
            height, _ = runtime_walk_reference_height(root, actor)
            self.assertEqual(height, (384 + 192) / 2)

    def test_multiple_directions_use_the_same_runtime_units(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            actor = self.fixture(root)
            other = self.fixture(root, factor=2)['tracks'][0]
            other['direction'] = 'W'
            actor['tracks'].append(other)
            self.assertEqual(runtime_walk_reference_height(root, actor)[0], 384)

    def test_invalid_or_invisible_reference_cannot_produce_a_profile(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            actor = self.fixture(root)
            malformed = copy.deepcopy(actor)
            malformed['tracks'][0]['geometry']['frames'][0]['canvas_size'] = [0, 0]
            with self.assertRaises(ValueError):
                runtime_walk_reference_height(root, malformed)
            Image.new('RGBA', (200, 100)).save(root / actor['tracks'][0]['source'])
            with self.assertRaises(ValueError):
                runtime_walk_reference_height(root, actor)


if __name__ == '__main__':
    unittest.main()
