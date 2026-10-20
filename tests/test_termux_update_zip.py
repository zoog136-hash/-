"""Offline regression tests for the Termux ZIP updater; no GitHub network required."""
import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from tools.android import termux_update_zip as updater


def record(blob):
    return {'size': len(blob), 'sha': hashlib.sha1(b'blob ' + str(len(blob)).encode() + b'\0' + blob).hexdigest(), 'mode': '100644'}


class ZipUpdaterTest(unittest.TestCase):
    def test_reject_traversal_and_symlinks(self):
        for bad in ('../project.godot', '/etc/passwd', 'a//b', '.git/HEAD', '.godot/cache', 'x\\y'):
            with self.subTest(path=bad), self.assertRaises(ValueError):
                updater.safe_path(bad)
        with tempfile.TemporaryDirectory() as t, tempfile.TemporaryDirectory() as outside:
            root = Path(t)
            (root / 'assets').symlink_to(outside)
            with self.assertRaises(ValueError):
                updater.ensure_not_symlink(root, updater.safe_path('assets/a.txt'))

    def test_incremental_update_with_backup(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            (root / 'project.godot').write_bytes(b'old')
            (root / 'Main.tscn').write_bytes(b'scene')
            (root / 'my_local_save.json').write_bytes(b'untouched')
            data = {'project.godot': b'new', 'Main.tscn': b'scene', 'external_map_packs/native_png_v5/index.json': b'png'}
            inventory = {name: record(blob) for name, blob in data.items()}
            def fake_download(sha, name, row, destination):
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(data[name])
            with mock.patch.object(updater, 'get_inventory', return_value=('a'*40, inventory)), mock.patch.object(updater, 'download_verified', side_effect=fake_download):
                updater.update(root, assume_yes=True)
                updater.update(root, assume_yes=True)
            self.assertEqual((root / 'project.godot').read_bytes(), b'new')
            self.assertEqual((root / 'my_local_save.json').read_bytes(), b'untouched')
            self.assertEqual(next(root.glob('.twilight_update_backup_*/project.godot')).read_bytes(), b'old')
            self.assertEqual(len(list(root.glob('.twilight_update_backup_*'))), 1)

    def test_failed_download_changes_no_game_files(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            (root / 'project.godot').write_bytes(b'old')
            (root / 'Main.tscn').write_bytes(b'scene')
            inventory = {'project.godot': record(b'new'), 'Main.tscn': record(b'scene')}
            with mock.patch.object(updater, 'get_inventory', return_value=('a'*40, inventory)), mock.patch.object(updater, 'download_verified', side_effect=RuntimeError('offline')):
                with self.assertRaises(RuntimeError):
                    updater.update(root, assume_yes=True)
            self.assertEqual((root / 'project.godot').read_bytes(), b'old')
            self.assertFalse(list(root.glob('.twilight_update_backup_*')))


if __name__ == '__main__':
    unittest.main()
