"""Compiler regression fixtures only; never original-resource delivery."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from PIL import Image
from build_png_review_pack import compile_map


class CompileContract(unittest.TestCase):
    def test_integer_spawn_and_lossless_resume(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            png = root/'fixture.png'
            image = Image.new('RGBA', (128, 128), (12, 34, 56, 255))
            image.putpixel((40, 40), (99, 88, 77, 255));image.save(png)
            catalog = dict(png_sha256=hashlib.sha256(png.read_bytes()).hexdigest(), png_size=[128, 128])
            definition = dict(map_id='contract', source_map_id=111, source_sha256='fixture', origin=[0, 0],
                              spawn_source=[1, 2], coordinate_mapping=dict(basis_x=[24, -12], basis_y=[24, 12], translation=[0, 384]))
            out = root/'pack'
            args = (png, definition, catalog, out, [.0625, 0, 0, 0, .0625, 0], [0, 0, 32, 32], {'verified': False})
            compile_map(*args)
            manifest = json.loads((out/'manifest.json').read_text())
            self.assertEqual(manifest['review_spawn_cell'], [1, 2])
            part = out/manifest['regions'][0]['file'];stamp = part.stat().st_mtime_ns
            compile_map(*args)
            self.assertEqual(part.stat().st_mtime_ns, stamp)
            self.assertEqual(hashlib.sha256(part.read_bytes()).hexdigest(), manifest['regions'][0]['sha256'])
            changed = Image.open(part).convert('RGBA');changed.putpixel((1, 1), (255, 0, 0, 255));changed.save(part)
            with self.assertRaisesRegex(ValueError, 'Existing crop differs'):
                compile_map(*args)


if __name__ == '__main__':
    unittest.main()
