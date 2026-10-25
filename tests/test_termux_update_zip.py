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

    def test_large_github_tree_recovers_every_runtime_file(self):
        root_sha, assets_sha, maps_sha, docs_sha = ('a'*40, 'b'*40, 'c'*40, 'd'*40)
        head_sha = 'e'*40
        def blob(path):
            return {'type': 'blob', 'path': path, 'mode': '100644', 'size': 4, 'sha': 'f'*40}
        def directory(path, sha):
            return {'type': 'tree', 'path': path, 'mode': '040000', 'sha': sha}
        seen = []
        def respond(url):
            seen.append(url)
            if url.endswith('/commits/main'):
                return {'sha': head_sha, 'commit': {'tree': {'sha': root_sha}}}
            if url.endswith('/git/trees/'+root_sha):
                return {'sha': root_sha, 'truncated': False,
                        'tree': [blob('project.godot'), blob('Main.tscn'),
                                 directory('docs', docs_sha), directory('assets', assets_sha)]}
            if url.endswith('/git/trees/'+assets_sha+'?recursive=1'):
                return {'sha': assets_sha, 'truncated': True,
                        'tree': [blob('only_partial_not_to_use.png')]}
            if url.endswith('/git/trees/'+assets_sha):
                return {'sha': assets_sha, 'truncated': False,
                        'tree': [blob('icon.png'), directory('maps', maps_sha)]}
            if url.endswith('/git/trees/'+maps_sha+'?recursive=1'):
                return {'sha': maps_sha, 'truncated': False,
                        'tree': [blob('faith_01.png'), blob('faith_02.png')]}
            raise AssertionError('unexpected GitHub request: '+url)
        with mock.patch.object(updater, 'fetch_json', side_effect=respond):
            sha, inventory = updater.get_inventory()
        self.assertEqual(sha, head_sha)
        self.assertEqual(set(inventory), {'project.godot', 'Main.tscn',
                        'assets/icon.png', 'assets/maps/faith_01.png',
                        'assets/maps/faith_02.png'})
        self.assertFalse(any(docs_sha in url for url in seen))
        self.assertFalse(any('only_partial' in name for name in inventory))

    def test_prior_downloaded_docs_are_never_deleted(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            (root / 'project.godot').write_bytes(b'unchanged')
            (root / 'Main.tscn').write_bytes(b'scene')
            (root / 'docs').mkdir()
            (root / 'docs' / 'private-note.txt').write_text('keep')
            (root / updater.STATE_FILE).write_text(
                '{"tracked_files":["project.godot","Main.tscn","docs/private-note.txt"]}')
            inventory = {name: record((root / name).read_bytes())
                         for name in ('project.godot', 'Main.tscn')}
            with mock.patch.object(updater, 'get_inventory', return_value=('a'*40, inventory)):
                updater.update(root, assume_yes=True)
            self.assertEqual((root / 'docs' / 'private-note.txt').read_text(), 'keep')
            self.assertFalse(list(root.glob('.twilight_update_backup_*')))

    def test_inconsistent_subtree_blocks_update(self):
        root_sha, sub_sha = 'a'*40, 'b'*40
        def respond(url):
            if url.endswith('/commits/main'):
                return {'sha':'e'*40,'commit':{'tree':{'sha':root_sha}}}
            if url.endswith('/git/trees/'+root_sha):
                return {'sha':root_sha,'tree':[
                    {'type':'blob','path':'project.godot','mode':'100644','size':4,'sha':'f'*40},
                    {'type':'blob','path':'Main.tscn','mode':'100644','size':4,'sha':'f'*40},
                    {'type':'tree','path':'assets','mode':'040000','sha':sub_sha}]}
            if url.endswith('/git/trees/'+sub_sha+'?recursive=1'):
                return {'sha':'0'*40,'truncated':False,'tree':[]}
            raise AssertionError(url)
        with mock.patch.object(updater, 'fetch_json', side_effect=respond):
            with self.assertRaisesRegex(RuntimeError, 'inconsistent tree'):
                updater.get_inventory()



if __name__ == '__main__':
    unittest.main()
