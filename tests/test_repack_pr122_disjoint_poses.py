#!/usr/bin/env python3
"""Lossless partial-source isolation guards using synthetic temporary art only."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

TOOLS = Path(__file__).resolve().parents[1] / 'tools'
sys.path.insert(0, str(TOOLS))
import repack_pr122_disjoint_poses as splitter


def crossing_fixture(path, pose_count, *, odd=True):
    rows = pose_count // 2
    pixels = np.zeros((rows * 220 + int(odd and rows > 1), 400 + int(odd), 4), np.uint8)
    masks = []
    for phase in range(pose_count):
        row, column = divmod(phase, 2)
        y = row * 220
        mask = np.zeros(pixels.shape[:2], bool)
        if column == 0:
            mask[y + 20:y + 171, 30:71] = True
            mask[y + 20:y + 51, 30:241] = True
        else:
            mask[y + 60:y + 191, 330:371] = True
            mask[y + 160:y + 191, 150:371] = True
        pixels[mask] = [30 + phase * 25, 70 + phase * 17, 160 - phase * 13, 255]
        masks.append(mask)
    Image.fromarray(pixels).save(path)
    return pixels, masks


class RepackDisjointPosesTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='twilight-partial-repack-')
        self.root = Path(self.directory.name)
        self.source = self.root / 'source.png'
        self.output = self.root / 'isolated.png'

    def tearDown(self):
        self.directory.cleanup()

    def assert_lossless(self, pixels, masks, audit):
        result = np.array(Image.open(self.output).convert('RGBA'))
        self.assertEqual(audit['foreground_pixels'], int((pixels[:, :, 3] > 16).sum()))
        self.assertEqual(sum(p['foreground_pixels'] for p in audit['poses']),
                         audit['foreground_pixels'])
        for mask, proof in zip(masks, audit['poses']):
            ys, xs = np.where(mask)
            dx, dy = proof['translation']
            self.assertTrue(np.array_equal(result[ys + dy, xs + dx], pixels[ys, xs]))
        self.assertEqual(audit['newly_authored_poses'], 0)
        self.assertFalse(audit['resampled'])
        self.assertFalse(audit['recolored'])
        self.assertEqual(audit['visual_approval'], 'NOT_RUN')

    def test_two_and_four_disjoint_bodies_with_crossing_rectangles(self):
        for count in (2, 4):
            with self.subTest(pose_count=count):
                source = self.root / f'source-{count}.png'
                self.output = self.root / f'isolated-{count}.png'
                pixels, masks = crossing_fixture(source, count)
                with self.assertRaisesRegex(ValueError, 'another body'):
                    splitter.importer.analyze(source, rows_count=count,
                                              reference_rows=[0, min(3, count - 1)],
                                              directions_axis='phase_grid2',
                                              canvas_size=1024, directions=['N'])
                audit = splitter.repack(source, self.output, 'N', pose_count=count)
                self.assert_lossless(pixels, masks, audit)
                self.assertEqual(audit['pose_count'], count)
                self.assertEqual(audit['temporal_rows'], count // 2)
                self.assertEqual([p['phase'] for p in audit['poses']], list(range(count)))
                self.assertEqual(audit['approvals_added'], 0)

    def test_large_odd_width_two_pose_source_needs_explicit_large_layout(self):
        pixels = np.zeros((928, 1695, 4), np.uint8)
        masks = []
        for phase in range(2):
            mask = np.zeros(pixels.shape[:2], bool)
            if phase == 0:
                mask[120:781, 100:281] = True
                mask[120:261, 100:971] = True
            else:
                mask[200:821, 1420:1601] = True
                mask[680:821, 660:1601] = True
            pixels[mask] = [90 + phase * 80, 110, 40, 255]
            masks.append(mask)
        Image.fromarray(pixels).save(self.source)
        with self.assertRaises(AssertionError):
            splitter.repack(self.source, self.output, 'NW', pose_count=2)
        self.assertFalse(self.output.exists())
        audit = splitter.repack(self.source, self.output, 'NW', pose_count=2,
                                canvas_size=2048, cell_width=1280)
        self.assert_lossless(pixels, masks, audit)
        self.assertEqual(audit['output_canvas'], [2560, 928])
        self.assertEqual(audit['importer_canvas_size'], 2048)

    def test_default_six_preserves_legacy_schema_and_layout(self):
        pixels, masks = crossing_fixture(self.source, 6, odd=False)
        audit = splitter.repack(self.source, self.output, 'N')
        self.assert_lossless(pixels, masks, audit)
        self.assertEqual(audit['output_canvas'], [1536, 660])
        self.assertEqual(audit['body_seed_alpha'], 16)
        self.assertEqual(audit['removed_background_pixels'], 0)
        self.assertEqual(set(audit), {
            'source_sha256', 'output_sha256', 'source', 'output',
            'preserved_foreground_rgba', 'source_canvas', 'output_canvas',
            'resampled', 'recolored', 'newly_authored_poses',
            'foreground_alpha_threshold', 'retained_fringe_distance',
            'body_seed_alpha', 'maximum_foreground_distance',
            'removed_background_pixels', 'maximum_removed_alpha',
            'foreground_pixels', 'poses', 'strict_importer', 'visual_approval'})

    def test_missing_and_extra_bodies_are_not_invented_or_dropped(self):
        for alteration in ('missing', 'extra'):
            with self.subTest(alteration=alteration):
                pixels, masks = crossing_fixture(self.source, 2)
                if alteration == 'missing':
                    pixels[masks[1]] = 0
                else:
                    pixels[10:30, 275:300] = [220, 110, 20, 255]
                Image.fromarray(pixels).save(self.source)
                with self.assertRaisesRegex(ValueError, 'Require 2 separate bodies'):
                    splitter.repack(self.source, self.output, 'N', pose_count=2)
                self.assertFalse(self.output.exists())

    def test_strong_source_boundary_clipping_is_never_repaired_with_padding(self):
        pixels, _ = crossing_fixture(self.source, 2)
        pixels[50, 0] = [230, 110, 20, 101]
        Image.fromarray(pixels).save(self.source)
        with self.assertRaisesRegex(AssertionError, 'Clipped source'):
            splitter.repack(self.source, self.output, 'N', pose_count=2,
                            canvas_size=2048, cell_width=1280)
        self.assertFalse(self.output.exists())

    def test_far_strong_or_faint_foreground_is_rejected(self):
        for alpha in (17, 33, 255):
            with self.subTest(alpha=alpha):
                pixels, _ = crossing_fixture(self.source, 2)
                pixels[210, 390] = [220, 110, 20, alpha]
                Image.fromarray(pixels).save(self.source)
                with self.assertRaises(ValueError):
                    splitter.repack(self.source, self.output, 'N', pose_count=2)
                self.assertFalse(self.output.exists())

    def test_only_bounded_low_alpha_background_can_be_removed(self):
        pixels, masks = crossing_fixture(self.source, 2)
        pixels[210, 390] = [220, 110, 20, 16]
        Image.fromarray(pixels).save(self.source)
        audit = splitter.repack(self.source, self.output, 'N', pose_count=2)
        self.assert_lossless(pixels, masks, audit)
        self.assertEqual(audit['removed_background_pixels'], 1)
        self.assertEqual(audit['maximum_removed_alpha'], 16)

    def test_existing_bounded_seed32_bridge_preserves_every_foreground_pixel(self):
        pixels = np.zeros((220, 400, 4), np.uint8)
        pixels[60:161, 80:197] = [90, 120, 30, 255]
        pixels[70:171, 202:321] = [180, 120, 30, 255]
        pixels[110, 197:202] = [200, 100, 20, 20]
        Image.fromarray(pixels).save(self.source)
        audit = splitter.repack(self.source, self.output, 'N', pose_count=2)
        self.assertEqual(audit['body_seed_alpha'], 32)
        self.assertLessEqual(audit['maximum_foreground_distance'], 5)
        output = np.array(Image.open(self.output).convert('RGBA'))
        for color in ([90, 120, 30, 255], [180, 120, 30, 255], [200, 100, 20, 20]):
            self.assertEqual(int(np.all(pixels == color, axis=2).sum()),
                             int(np.all(output == color, axis=2).sum()))

    def test_invalid_layout_parameters_and_boolean_counts_have_no_outputs(self):
        crossing_fixture(self.source, 2)
        bad = ([{'pose_count': value} for value in (0, 1, 3, 5, True, False, 2.0, '2')]
               + [{'canvas_size': value} for value in (512, 4096, True, 2048.0, '2048')]
               + [{'cell_width': value} for value in (800, 1024, True, 1280.0, '1280')])
        for kwargs in bad:
            with self.subTest(kwargs=kwargs), self.assertRaises(ValueError):
                splitter.repack(self.source, self.output, 'N', **kwargs)
        self.assertFalse(self.output.exists())
        self.assertFalse(self.output.with_suffix('.repack.json').exists())

    def test_output_and_proof_are_exclusive_and_original_source_is_untouched(self):
        crossing_fixture(self.source, 2)
        source_digest = hashlib.sha256(self.source.read_bytes()).hexdigest()
        self.output.write_bytes(b'existing output')
        with self.assertRaises(AssertionError):
            splitter.repack(self.source, self.output, 'N', pose_count=2)
        self.assertEqual(self.output.read_bytes(), b'existing output')
        other = self.root / 'new.png'
        other.with_suffix('.repack.json').write_bytes(b'existing proof')
        with self.assertRaisesRegex(AssertionError, 'existing proof'):
            splitter.repack(self.source, other, 'N', pose_count=2)
        self.assertFalse(other.exists())
        self.assertEqual(other.with_suffix('.repack.json').read_bytes(), b'existing proof')
        self.assertEqual(hashlib.sha256(self.source.read_bytes()).hexdigest(), source_digest)

    def test_cli_accepts_only_explicit_partial_layout_and_records_actual_count(self):
        crossing_fixture(self.source, 2)
        completed = subprocess.run([
            sys.executable, str(TOOLS / 'repack_pr122_disjoint_poses.py'),
            str(self.source), str(self.output), '--direction', 'NW',
            '--pose-count', '2', '--canvas-size', '2048', '--cell-width', '1280'],
            capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(completed.stdout)['strict_importer'], 'PASS')
        audit = json.loads(self.output.with_suffix('.repack.json').read_text())
        self.assertEqual(audit['pose_count'], 2)
        self.assertEqual(len(audit['poses']), 2)
        self.assertTrue(audit['partial_source'])


if __name__ == '__main__':
    unittest.main()
