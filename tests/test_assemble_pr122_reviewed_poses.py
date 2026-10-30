import hashlib
from pathlib import Path
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import assemble_pr122_reviewed_poses as assembler


class ReviewedPackingCellsTest(unittest.TestCase):
    def fixture(self, folder, width=80):
        poses = []
        for phase in range(6):
            image = Image.new('RGBA', (width + 64, 180))
            image.paste((30 + phase * 30, 90, 160, 255), (32, 40, width + 32, 130))
            image.putpixel((width // 2 + 32, 80), (phase + 7, 11, 13, 37))
            image.putpixel((width // 2 + 32, 81), (phase + 7, 11, 13, 7))
            path = folder / ('source-' + str(phase) + '.png')
            image.save(path)
            crop = image.crop((32, 40, width + 32, 130))
            poses.append(dict(path=str(path), source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                              region=[32, 40, width, 90], rgba_sha256=hashlib.sha256(crop.tobytes()).hexdigest(),
                              source_pose=phase, newly_authored=True, review_basis='Synthetic packing guard fixture only'))
        return dict(schema=assembler.SCHEMA, key='transform:fixture', direction='SE', role='hit', poses=poses)

    def check_exact_pixels(self, spec, output, width):
        with Image.open(output) as image:
            pixels = np.array(image.convert('RGBA'))
        self.assertEqual(int((pixels[:, :, 3] > 16).sum()), (width * 90 - 1) * 6)
        for phase, source in enumerate(spec['poses']):
            color = np.array([30 + phase * 30, 90, 160, 255], dtype=np.uint8)
            self.assertEqual(int(np.all(pixels == color, axis=2).sum()), width * 90 - 2)
            for alpha in (37, 7):
                partial = np.array([phase + 7, 11, 13, alpha], dtype=np.uint8)
                self.assertEqual(int(np.all(pixels == partial, axis=2).sum()), 1)
            self.assertEqual(hashlib.sha256(Path(source['path']).read_bytes()).hexdigest(), source['source_sha256'])

    def test_default_cell_output_and_exact_source_pixels(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            spec = self.fixture(folder)
            output = folder / 'atlas.png'
            proof = assembler.assemble_pose_map(spec, output)
            with Image.open(output) as image:
                self.assertEqual(image.size, (2560, 3840))
            self.assertEqual(proof['cell_size'], [1280, 1280])
            self.check_exact_pixels(spec, output, 80)

    def test_explicit_large_cell_preserves_wide_pose_without_resampling(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            spec = self.fixture(folder, width=1233)
            rejected = folder / 'default-rejected.png'
            with self.assertRaisesRegex(ValueError, 'never resize'):
                assembler.assemble_pose_map(spec, rejected)
            self.assertFalse(rejected.exists())
            output = folder / 'wide-atlas.png'
            proof = assembler.assemble_pose_map(spec, output, cell_size=1536)
            with Image.open(output) as image:
                self.assertEqual(image.size, (3072, 4608))
            self.assertEqual(proof['virtual_canvas_size'], 2048)
            self.assertEqual(proof['strict_importer'], 'PASS')
            self.assertFalse(proof['resampled'])
            self.assertEqual(proof['cleaned_pixels'], 0)
            self.check_exact_pixels(spec, output, 1233)

    def test_same_padding_guard_rejects_oversized_large_cell_pose(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            spec = self.fixture(folder, width=1473)
            with self.assertRaisesRegex(ValueError, 'never resize'):
                assembler.assemble_pose_map(spec, folder / 'reject.png', cell_size=1536)

    def test_only_explicit_integer_sizes_and_no_proof_overwrite(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            for size in (True, 1536.0, 1472, 2048):
                with self.assertRaisesRegex(ValueError, 'explicit'):
                    assembler.assemble_pose_map({}, folder / 'reject.png', cell_size=size)
            output = folder / 'guard.png'
            output.with_suffix('.assembly.json').write_text('preserved proof\n')
            with self.assertRaises(FileExistsError):
                assembler.assemble_pose_map({}, output, cell_size=1536)
            self.assertEqual(output.with_suffix('.assembly.json').read_text(), 'preserved proof\n')


if __name__ == '__main__':
    unittest.main()
