"""Container integrity/closure fixtures, not native pixel or game approval."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

SPEC = importlib.util.spec_from_file_location('bundle', Path(__file__).parents[1] / 'tools/monsters/package_patch523_resource_bundle.py')
BUNDLE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUNDLE)


class BundleTest(unittest.TestCase):
    def fixture(self, root):
        monsters = root / 'monsters'
        definitions = root / 'definitions'
        (monsters / 'actors').mkdir(parents=True)
        (monsters / 'sp2').mkdir()
        definitions.mkdir()
        pixel = b'EXPLICIT_CONTAINER_FIXTURE_NOT_SOURCE_PIXELS'
        (monsters / 'sp2/1.bin').write_bytes(pixel)
        model = BUNDLE.encode({'source_sprite_id': 1, 'tracks': {'fixture': {'directions': [[{'layers': [{'path': 'sp2/1.bin', 'sha256': BUNDLE.sha(pixel)}]}]]}}})
        (monsters / 'actors/1.json').write_bytes(model)
        manifest = {'kind': 'base508_monster_pack', 'source_snapshot': 'base508', 'records': {'1': {'sprite_id': 1, 'tracks_ref': 'actors/1.json', 'tracks_sha256': BUNDLE.sha(model)}}}
        (monsters / 'manifest.json').write_bytes(BUNDLE.encode(manifest))
        data = b'{}'
        (definitions / 'conditions.json').write_bytes(data)
        d = {'source_snapshot': 'patch523', 'conditions': {'file': 'conditions.json', 'bytes': len(data), 'sha256': BUNDLE.sha(data)}, 'lands': {}}
        (definitions / 'manifest.json').write_bytes(BUNDLE.encode(d))
        (monsters / 'unrelated-report.txt').write_text('Must not be published with resources')
        (definitions / 'unrelated-capture.png').write_bytes(b'not a resource')
        return monsters, definitions

    def build(self, monsters, definitions, output):
        return BUNDLE.build(monsters, definitions, BUNDLE.sha((monsters / 'manifest.json').read_bytes()),
                            BUNDLE.sha((definitions / 'manifest.json').read_bytes()), 'a' * 40, output)

    def test_only_resource_closure_and_reproducible_archive(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            m, d = self.fixture(root)
            self.build(m, d, root / 'one.zip')
            self.build(m, d, root / 'two.zip')
            self.assertEqual((root / 'one.zip').read_bytes(), (root / 'two.zip').read_bytes())
            with zipfile.ZipFile(root / 'one.zip') as archive:
                self.assertIsNone(archive.testzip())
                self.assertEqual(len(archive.namelist()), 7)
                self.assertNotIn('monsters/unrelated-report.txt', archive.namelist())
                self.assertNotIn('world-links/unrelated-capture.png', archive.namelist())
                inventory = json.loads(archive.read('bundle.json'))['files']
                self.assertEqual(len(inventory), 5)
                for name, row in inventory.items():
                    self.assertEqual(BUNDLE.sha(archive.read(name)), row['sha256'])

    def test_corrupt_pixel_rejected_before_output(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            m, d = self.fixture(root)
            (m / 'sp2/1.bin').write_bytes(b'changed')
            with self.assertRaises(ValueError): self.build(m, d, root / 'bad.zip')
            self.assertFalse((root / 'bad.zip').exists())

    def test_existing_output_and_input_roots_preserved(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            m, d = self.fixture(root)
            output = root / 'keep.zip'
            output.write_bytes(b'preserve')
            with self.assertRaises(ValueError): self.build(m, d, output)
            self.assertEqual(output.read_bytes(), b'preserve')
            with self.assertRaises(ValueError): self.build(m, d, m / 'inside.zip')
            self.assertFalse((m / 'inside.zip').exists())

    def test_traversal_and_wrong_manifest_pin_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            m, d = self.fixture(root)
            with self.assertRaises(ValueError):
                BUNDLE.build(m, d, '0' * 64, BUNDLE.sha((d / 'manifest.json').read_bytes()), 'a' * 40, root / 'bad.zip')
            self.assertFalse((root / 'bad.zip').exists())
            manifest = json.loads((m / 'manifest.json').read_bytes())
            manifest['records']['1']['tracks_ref'] = '../outside.json'
            (m / 'manifest.json').write_bytes(BUNDLE.encode(manifest))
            with self.assertRaises(ValueError): self.build(m, d, root / 'escape.zip')
            self.assertFalse((root / 'escape.zip').exists())


if __name__ == '__main__': unittest.main()
