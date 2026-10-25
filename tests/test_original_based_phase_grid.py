"""Temporal grid metadata keeps the complete-source and duplicate guards."""
from pathlib import Path
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import import_original_based_motion as core


class PhaseGridTest(unittest.TestCase):
    def fixture(self, root, count=8, columns=4):
        pixels = np.zeros((((count + columns-1) // columns) * 96, columns*96, 4), dtype=np.uint8)
        for phase in range(count):
            x, y = (phase % columns) * 96 + 32, (phase // columns) * 96 + 25
            pixels[y:y+40, x:x+22] = [40+phase, 90, 180, 255]
        path = root / 'synthetic-metadata-fixture.png'
        Image.fromarray(pixels).save(path)
        return path, pixels

    def analyze(self, path, count=8, columns=4):
        return core.analyze(path, rows_count=count, directions=['E'],
            directions_axis='phase_grid'+str(columns), canvas_size=256)

    def test_two_columns_preserve_all_sixteen_phases_and_source_pixels(self):
        with tempfile.TemporaryDirectory() as tmp:
            path, _ = self.fixture(Path(tmp),16,columns=2)
            before=path.read_bytes()
            geometry=self.analyze(path,16,columns=2)
            core.require_complete_pose_regions(path,geometry)
            self.assertEqual(path.read_bytes(),before)
            self.assertEqual([f['row'] for f in geometry['frames']],list(range(16)))
            self.assertEqual([f['source_anchor'][0] for f in geometry['frames']],[48,144]*8)
            self.assertEqual(geometry['distinct_pixel_frames'],16)

    def test_three_columns_keep_six_walk_phases_and_source_bytes(self):
        with tempfile.TemporaryDirectory() as tmp:
            path, _ = self.fixture(Path(tmp), 6, columns=3)
            before = path.read_bytes()
            geometry = self.analyze(path, 6, columns=3)
            core.require_complete_pose_regions(path, geometry)
            self.assertEqual(path.read_bytes(), before)
            self.assertEqual(geometry['distinct_pixel_frames'], 6)
            self.assertEqual([f['source_anchor'][0] for f in geometry['frames']], [48,144,240]*2)
            # The same PNG must never be silently reinterpreted as a 2-column source.
            with self.assertRaises(ValueError):
                self.analyze(path, 6, columns=2)

    def test_three_columns_retain_whole_source_and_uniqueness_guards(self):
        for fault in ['omitted_piece', 'duplicate', 'clipping']:
            with self.subTest(fault=fault), tempfile.TemporaryDirectory() as tmp:
                path, pixels = self.fixture(Path(tmp), 6, columns=3)
                if fault == 'omitted_piece':
                    pixels[5:9, 5:9] = [255,255,255,255]
                elif fault == 'duplicate':
                    pixels[121:161, 224:246] = [40,90,180,255]
                else:
                    pixels[0:26,32:54] = [40,90,180,255]
                Image.fromarray(pixels).save(path)
                with self.assertRaises(ValueError):
                    geometry = self.analyze(path, 6, columns=3)
                    core.require_complete_pose_regions(path, geometry)

    def test_all_eight_phases_in_row_major_order_without_pixel_changes(self):
        with tempfile.TemporaryDirectory() as tmp:
            path, _ = self.fixture(Path(tmp))
            before = path.read_bytes()
            geometry = self.analyze(path)
            core.require_complete_pose_regions(path, geometry)
            self.assertEqual(path.read_bytes(), before)
            self.assertEqual(geometry['distinct_pixel_frames'], 8)
            self.assertEqual([f['row'] for f in geometry['frames']], list(range(8)))
            self.assertEqual([f['source_anchor'][0] for f in geometry['frames']],
                             [48, 144, 240, 336] * 2)

    def test_short_last_row_has_no_invented_pose(self):
        with tempfile.TemporaryDirectory() as tmp:
            path, _ = self.fixture(Path(tmp), 3)
            geometry = self.analyze(path, 3)
            core.require_complete_pose_regions(path, geometry)
            self.assertEqual(len(geometry['frames']), 3)

    def test_missing_or_duplicate_or_misassigned_body_is_rejected(self):
        for fault in ['missing', 'duplicate', 'wrong_cell']:
            with self.subTest(fault=fault), tempfile.TemporaryDirectory() as tmp:
                path, pixels = self.fixture(Path(tmp))
                pixels[121:161, 320:342] = 0
                if fault == 'duplicate':
                    pixels[121:161, 320:342] = [40, 90, 180, 255]
                elif fault == 'wrong_cell':
                    pixels[25:65, 60:82] = [47, 90, 180, 255]
                Image.fromarray(pixels).save(path)
                with self.assertRaises(ValueError):
                    self.analyze(path)

    def test_whole_source_guard_still_rejects_discarded_visible_piece(self):
        with tempfile.TemporaryDirectory() as tmp:
            path, pixels = self.fixture(Path(tmp))
            pixels[5:9, 5:9] = [255, 255, 255, 255]
            Image.fromarray(pixels).save(path)
            geometry = self.analyze(path)
            with self.assertRaisesRegex(ValueError, 'visible pixels outside'):
                core.require_complete_pose_regions(path, geometry)

    def test_multiple_directions_cannot_be_silently_reordered(self):
        with tempfile.TemporaryDirectory() as tmp:
            path, _ = self.fixture(Path(tmp))
            with self.assertRaisesRegex(ValueError, 'exactly one'):
                core.analyze(path, rows_count=4, directions=['E', 'SE'],
                    directions_axis='phase_grid4', canvas_size=256)


if __name__ == '__main__':
    unittest.main()
