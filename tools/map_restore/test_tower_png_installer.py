"""Code-only archive security fixtures, never counted as original-art proof."""
import json
import tempfile
import unittest
import zipfile
from pathlib import Path
from install_tower_png_pack import PACKS, install


class ArchiveSafety(unittest.TestCase):
    def test_traversal_and_corruption_preserve_existing_installations(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root/'data/maps').mkdir(parents=True)
            for name, receipt in PACKS.items():
                (root/'data/maps'/receipt).write_text(json.dumps({'index_sha256': '0'*64, 'maps': {}}))
                destination = root/'external_map_packs'/name
                destination.mkdir(parents=True)
                (destination/'index.json').write_text('existing '+name)
            archive = root/'unsafe.zip'
            for entries, message in [
                    ({'oman_png_v1/../../escape.json': '{}'}, 'Unsafe archive entry'),
                    ({'oman_png_v1/index.json': '{}', 'domination_png_v1/index.json': '{}'}, 'Index SHA mismatch')]:
                with zipfile.ZipFile(archive, 'w') as bundle:
                    for name, value in entries.items(): bundle.writestr(name, value)
                with self.assertRaisesRegex(ValueError, message): install(archive, root)
                self.assertFalse((root/'escape.json').exists())
                for name in PACKS:
                    self.assertEqual((root/'external_map_packs'/name/'index.json').read_text(), 'existing '+name)


if __name__ == '__main__': unittest.main()
