import importlib.util
from pathlib import Path
import hashlib
import tempfile
import unittest
import zipfile

MODULE = Path(__file__).resolve().parents[1] / 'tools/source84_delivery.py'
spec = importlib.util.spec_from_file_location('delivery', MODULE)
delivery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(delivery)


class DeliveryTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'source'
        self.source.mkdir()
        self.payload = b'bounded installer fixture, not source art\n'
        (self.source / 'index.json').write_bytes(self.payload)
        self.spec = {'files': {'index.json': {'bytes': len(self.payload),
                     'sha256': hashlib.sha256(self.payload).hexdigest()}},
                     'total_bytes': len(self.payload)}

    def test_missing_pack_rejected(self):
        with self.assertRaises(ValueError):
            delivery.verify(self.root / 'missing', self.spec)

    def test_archive_install_and_idempotence(self):
        archive = self.root / 'private.zip'
        delivery.package(self.source, archive, self.spec)
        target = self.root / 'fresh-project/external_map_packs/source84_v3'
        delivery.install(target, self.spec, archive=archive)
        self.assertEqual((target / 'index.json').read_bytes(), self.payload)
        delivery.install(target, self.spec, archive=archive)

    def test_damaged_existing_pack_is_preserved(self):
        target = self.root / 'existing'
        target.mkdir(); (target / 'save.json').write_text('keep')
        with self.assertRaises(ValueError):
            delivery.install(target, self.spec, source=self.source)
        self.assertEqual((target / 'save.json').read_text(), 'keep')

    def test_tampered_zip_rejected_before_destination(self):
        archive = self.root / 'bad.zip'
        with zipfile.ZipFile(archive, 'w') as z:
            z.writestr('index.json', b'x' * len(self.payload))
        target = self.root / 'fresh'
        with self.assertRaises(ValueError): delivery.install(target, self.spec, archive=archive)
        self.assertFalse(target.exists())

    def test_traversal_and_extra_files_rejected(self):
        archive = self.root / 'bad.zip'
        with zipfile.ZipFile(archive, 'w') as z:
            z.writestr('index.json', self.payload); z.writestr('../escape', b'x')
        with self.assertRaises(ValueError): delivery.check_archive(archive, self.spec)
        self.assertFalse((self.root / 'escape').exists())

    def test_symlink_rejected(self):
        (self.source / 'index.json').unlink()
        (self.root / 'outside').write_bytes(self.payload)
        (self.source / 'index.json').symlink_to(self.root / 'outside')
        with self.assertRaises(ValueError): delivery.verify(self.source, self.spec)


if __name__ == '__main__': unittest.main()
