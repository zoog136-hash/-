import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import assemble_pr122_reviewed_poses as assembler
import pr122_reviewed_source_regions as regions


class PreservedAtlasFinalizationTest(unittest.TestCase):
    def fixture(self, folder):
        poses = []
        for phase in range(6):
            image = Image.new('RGBA', (144, 180))
            image.paste((30 + phase * 30, 90, 160, 255), (32, 40, 112, 130))
            if phase in (2, 5):
                image.putpixel((20, 70), (17, phase + 1, 23, 17 if phase == 2 else 19))
            path = folder / ('source-' + str(phase) + '.png')
            image.save(path)
            crop = image.crop((20, 40, 112, 130))
            poses.append(dict(path=str(path), source_sha256=assembler._sha(path),
                              region=[20, 40, 92, 90], rgba_sha256=assembler._rgba_sha(crop),
                              source_pose=phase, newly_authored=True,
                              review_basis='Synthetic AA ownership guard fixture only'))
        spec = dict(schema=assembler.SCHEMA, key='transform:fixture', direction='NE', role='walk', poses=poses)
        output = folder / 'atlas.png'
        with self.assertRaisesRegex(ValueError, 'foreground|regions|pixels|coverage'):
            assembler.assemble_pose_map(spec, output)
        self.assertTrue(output.is_file())
        self.assertFalse(output.with_suffix('.assembly.json').exists())
        self.assertTrue(output.with_suffix('.assembly-error.json').is_file())
        geometry = assembler.importer.analyze(output, rows_count=6, reference_rows=[0, 3],
                    directions_axis='phase_grid2', canvas_size=2048, directions=['NE'])
        pixels = np.array(Image.open(output))
        alpha = pixels[:, :, 3]
        owners, owner_proof = regions._foreground_owners(alpha, geometry['frames'])
        rectangles = []
        for phase, frame in enumerate(geometry['frames']):
            ys, xs = np.where((alpha > 16) & (owners == phase))
            x, y, width, height = frame['region']
            left, top = min(x, int(xs.min())), min(y, int(ys.min()))
            right, bottom = max(x + width, int(xs.max()) + 1), max(y + height, int(ys.max()) + 1)
            rectangles.append([left, top, right - left, bottom - top])
        review = dict(status=regions.STATUS, source_sha256=assembler._sha(output),
                      base_geometry_sha256=regions._digest(geometry), direction='NE',
                      review_basis='Retain exactly the two pinned AA fragments with their physical owners',
                      regions=rectangles, nearest_owner_sha256=owner_proof['nearest_owner_sha256'])
        return spec, output, review

    def test_exact_aa_finalization_preserves_png_error_and_refuses_overwrite(self):
        with tempfile.TemporaryDirectory() as temporary:
            spec, output, review = self.fixture(Path(temporary))
            error = output.with_suffix('.assembly-error.json')
            before = assembler._sha(output), assembler._sha(error)
            with self.assertRaises(FileExistsError):
                assembler.assemble_pose_map(spec, output)
            proof = assembler.finalize_preserved_pose_map(spec, output, review)
            self.assertEqual(before, (assembler._sha(output), assembler._sha(error)))
            self.assertEqual(proof['strict_importer'], 'PASS')
            self.assertFalse(proof['approval'])
            self.assertTrue(proof['atlas_and_original_error_unchanged'])
            self.assertEqual(proof['geometry']['distinct_pixel_frames'], 6)
            alpha = np.array(Image.open(output))[:, :, 3]
            self.assertEqual(int((alpha == 17).sum()), 1)
            self.assertEqual(int((alpha == 19).sum()), 1)
            assembler._complete_output(Image.open(output), proof['geometry'])
            saved = output.with_suffix('.assembly.json').read_bytes()
            with self.assertRaises(FileExistsError):
                assembler.finalize_preserved_pose_map(spec, output, review)
            self.assertEqual(saved, output.with_suffix('.assembly.json').read_bytes())

    def test_wrong_pins_and_incomplete_review_never_emit_success(self):
        with tempfile.TemporaryDirectory() as temporary:
            spec, output, review = self.fixture(Path(temporary))
            bad_spec = copy.deepcopy(spec)
            bad_spec['poses'][0]['source_sha256'] = '0' * 64
            with self.assertRaisesRegex(ValueError, 'SHA mismatch'):
                assembler.finalize_preserved_pose_map(bad_spec, output, review)
            bad_review = copy.deepcopy(review)
            bad_review['source_sha256'] = '0' * 64
            with self.assertRaisesRegex(ValueError, 'SHA256'):
                assembler.finalize_preserved_pose_map(spec, output, bad_review)
            bad_review = copy.deepcopy(review)
            bad_review['regions'][2][0] += 1
            bad_review['regions'][2][2] -= 1
            with self.assertRaises(ValueError):
                assembler.finalize_preserved_pose_map(spec, output, bad_review)
            self.assertFalse(output.with_suffix('.assembly.json').exists())

    def test_even_invisible_pixel_tampering_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            spec, output, review = self.fixture(Path(temporary))
            image = Image.open(output).copy()
            image.putpixel((0, 0), (1, 0, 0, 0))
            image.save(output)
            review['source_sha256'] = assembler._sha(output)
            with self.assertRaisesRegex(ValueError, 'differs from the exact pinned'):
                assembler.finalize_preserved_pose_map(spec, output, review)
            self.assertFalse(output.with_suffix('.assembly.json').exists())


if __name__ == '__main__':
    unittest.main()
