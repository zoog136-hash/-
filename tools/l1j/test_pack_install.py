"""Meaningful installation safety cases: late corruption/conflicts must write nothing."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('installer', Path(__file__).with_name('install_verified_pack.py'))
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class InstallationSafety(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.root = self.directory / 'game'
        self.root.mkdir()

    def pack(self, name, entries):
        path = self.directory / name
        with zipfile.ZipFile(path, 'w', zipfile.ZIP_STORED) as z:
            for target, data in entries:
                z.writestr(target, data)
        return path

    def test_valid_pack_is_idempotent(self):
        pack = self.pack('valid.zip', [('assets/l1j/verified/a.png', b'original')])
        installer.install(self.root, [pack])
        installer.install(self.root, [pack])
        self.assertEqual((self.root / 'assets/l1j/verified/a.png').read_bytes(), b'original')

    def test_existing_data_is_never_overwritten(self):
        old = self.root / 'data/l1j/registry/source.json'
        old.parent.mkdir(parents=True)
        old.write_bytes(b'user-version')
        pack = self.pack('conflict.zip', [('assets/l1j/new.png', b'valid'),
                                          ('data/l1j/registry/source.json', b'other-version')])
        with self.assertRaises(ValueError):
            installer.install(self.root, [pack])
        self.assertEqual(old.read_bytes(), b'user-version')
        self.assertFalse((self.root / 'assets').exists())

    def test_late_crc_failure_leaves_no_partial_install(self):
        pack = self.pack('corrupt.zip', [('assets/l1j/a.png', b'first'),
                                        ('assets/l1j/b.png', b'unique-corrupt-payload')])
        blob = pack.read_bytes().replace(b'unique-corrupt-payload', b'unique-CORRUPT-payload', 1)
        pack.write_bytes(blob)
        with self.assertRaises(zipfile.BadZipFile):
            installer.install(self.root, [pack])
        self.assertEqual(list(self.root.iterdir()), [])

    def test_conflicting_packs_are_rejected_together(self):
        one = self.pack('one.zip', [('assets/l1j/a.png', b'one')])
        two = self.pack('two.zip', [('assets/l1j/a.png', b'two')])
        with self.assertRaises(ValueError):
            installer.install(self.root, [one, two])
        self.assertEqual(list(self.root.iterdir()), [])

    def test_path_traversal_and_code_files_are_rejected(self):
        for index, target in enumerate(('assets/l1j/../../outside.png', 'scripts/world.gd', 'assets/l1j/plugin.gd')):
            pack = self.pack(str(index) + '.zip', [(target, b'untrusted')])
            with self.assertRaises(ValueError):
                installer.install(self.root, [pack])
        self.assertEqual(list(self.root.iterdir()), [])

    def test_symlink_cannot_redirect_a_pack(self):
        outside = self.directory / 'outside'
        outside.mkdir()
        (self.root / 'assets').symlink_to(outside, target_is_directory=True)
        pack = self.pack('link.zip', [('assets/l1j/a.png', b'untrusted')])
        with self.assertRaises(ValueError):
            installer.install(self.root, [pack])
        self.assertEqual(list(outside.iterdir()), [])


if __name__ == '__main__':
    unittest.main()
