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


    def test_truncated_subtree_falls_back_without_losing_files(self):
        root_sha, assets_sha, sprite_sha, docs_sha = ('1'*40, '2'*40, '3'*40, '4'*40)
        commit_sha = 'f'*40
        blob_sha = 'a'*40
        def blob(name):
            return {'path': name, 'type': 'blob', 'mode': '100644',
                    'sha': blob_sha, 'size': 4}
        def directory(name, sha):
            return {'path': name, 'type': 'tree', 'mode': '040000',
                    'sha': sha}
        base = updater.API + '/git/trees/'
        replies = {
            updater.API + '/commits/main': {'sha': commit_sha,
                'commit': {'tree': {'sha': root_sha}}},
            base + root_sha: {'sha': root_sha, 'truncated': False,
                'tree': [blob('project.godot'), blob('Main.tscn'),
                         directory('assets', assets_sha),
                         directory('docs', docs_sha)]},
            # Simulate the HTTP 200 partial response that broke the phone.
            base + assets_sha + '?recursive=1': {'sha': assets_sha,
                'truncated': True, 'tree': [blob('partial-only.png')]},
            base + assets_sha: {'sha': assets_sha, 'truncated': False,
                'tree': [directory('sprites', sprite_sha)]},
            base + sprite_sha + '?recursive=1': {'sha': sprite_sha,
                'truncated': False, 'tree': [blob('hero.png')]},
        }
        accessed = []
        def fake_get(url):
            accessed.append(url)
            return replies[url]
        with mock.patch.object(updater, 'fetch_json', side_effect=fake_get):
            commit, inventory = updater.get_inventory()
        self.assertEqual(commit, commit_sha)
        self.assertEqual(set(inventory),
                         {'project.godot', 'Main.tscn',
                          'assets/sprites/hero.png'})
        self.assertNotIn('assets/partial-only.png', inventory)
        self.assertNotIn(base + docs_sha + '?recursive=1', accessed)

    def test_incomplete_direct_tree_still_fails_closed(self):
        root_sha = '1'*40
        replies = {
            updater.API + '/commits/main': {
                'sha': 'a'*40, 'commit': {'tree': {'sha': root_sha}}},
            updater.API + '/git/trees/' + root_sha: {
                'sha': root_sha, 'truncated': True, 'tree': []},
        }
        with mock.patch.object(updater, 'fetch_json',
                               side_effect=lambda url: replies[url]):
            with self.assertRaisesRegex(RuntimeError, 'Incomplete direct'):
                updater.get_inventory()

    def test_old_docs_stay_when_mobile_scope_is_narrowed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root/'project.godot').write_bytes(b'game')
            (root/'Main.tscn').write_bytes(b'scene')
            (root/'docs').mkdir()
            (root/'docs/old-report.txt').write_bytes(b'preserved')
            (root/'scripts').mkdir()
            (root/'scripts/removed.gd').write_bytes(b'retired')
            (root/updater.STATE_FILE).write_text(
                '{"tracked_files":["project.godot","Main.tscn",'
                '"docs/old-report.txt","scripts/removed.gd"]}')
            data = {'project.godot': b'game', 'Main.tscn': b'scene'}
            inventory = {name: record(data[name]) for name in data}
            with mock.patch.object(updater, 'get_inventory',
                                   return_value=('a'*40, inventory)):
                updater.update(root, assume_yes=True)
            self.assertEqual((root/'docs/old-report.txt').read_bytes(),
                             b'preserved')
            self.assertFalse((root/'scripts/removed.gd').exists())
            backups = list(root.glob('.twilight_update_backup_*'))
            self.assertEqual(len(backups), 1)
            self.assertEqual(
                (backups[0]/'scripts/removed.gd').read_bytes(), b'retired')

    def test_runtime_path_scope(self):
        for path in ('project.godot', 'Main.tscn', 'assets/terrain.png',
                     'external_map_packs/native_png_v5/index.json',
                     'external_map_packs/oman_png_v1/index.json',
                     'external_map_packs/.gdignore',
                     'data/visuals/runtime_manifest.json',
                     'data/maps/navigation/oman_01.nav',
                     'scripts/world.gd',
                     'assets/actors/eight_direction/native_production/a.tres',
                     'addons/twilight_l1j/plugin.cfg'):
            self.assertTrue(updater.is_runtime_path(path), path)
        for path in ('docs/archive.png', '.github/workflows/ci.yml',
                     'tests/world_test.gd', 'samples/example.txt',
                     'tools/android/termux_update_zip.py', 'export_presets.cfg',
                     'external_map_packs/source_pngs/13474.png',
                     'external_map_packs/oman_v2/effective_layouts.json',
                     'external_map_packs/TWILIGHT-map-remake-private-20261015-v2.zip',
                     'assets/maps/aden_world_draft/placements.json',
                     'assets/maps/aden_modular_pilot/compiled/tile.png',
                     'assets/original_sheets/reference_ui.jpg',
                     'assets/actors/eight_direction/native_locomotion_staging/transform_393/draft001/clip.tres',
                     'data/resource_delivery_ledger.json',
                     'data/animation_authoring_sources.json',
                     'data/pr122_native_locomotion_staging.json',
                     'data/visuals/pr80_original_asset_hashes.json',
                     'data/skills/research_inventory.json',
                     'scripts/world_v19_backup.gd.bak',
                     'scripts/maps/aden_modular_preview_renderer.gd',
                     'scenes/SkillVFXLab.tscn'):
            self.assertFalse(updater.is_runtime_path(path), path)
        self.assertFalse(updater.is_runtime_tree('tools'))
        self.assertFalse(updater.is_runtime_tree('external_map_packs/source_pngs'))
        self.assertFalse(updater.is_runtime_tree('assets/maps/aden_world_draft'))
        self.assertTrue(updater.is_runtime_tree('external_map_packs/native_png_v5'))
        self.assertTrue(updater.is_runtime_tree('assets/actors/eight_direction/native_production'))

    def test_new_scope_never_deletes_previously_downloaded_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'project.godot').write_bytes(b'game')
            (root / 'Main.tscn').write_bytes(b'scene')
            kept = ('tools/android/termux_update_zip.py',
                    'external_map_packs/source_pngs/13474.png',
                    'data/resource_delivery_ledger.json')
            for name in kept:
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(b'old but preserved')
            (root / updater.STATE_FILE).write_text(
                __import__('json').dumps({'tracked_files': list(kept) +
                                          ['project.godot', 'Main.tscn']}))
            inventory = {name: record(blob) for name, blob in
                         {'project.godot': b'game',
                          'Main.tscn': b'scene'}.items()}
            with mock.patch.object(updater, 'get_inventory',
                                   return_value=('a'*40, inventory)):
                updater.update(root, assume_yes=True)
            for name in kept:
                self.assertEqual((root / name).read_bytes(), b'old but preserved')


    def test_cleanup_preview_sees_old_zip_material_without_updater_state(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            (root / 'project.godot').write_bytes(b'game')
            (root / 'Main.tscn').write_bytes(b'scene')
            sample = {
                'docs/report/large.png': b'old report',
                'tools/build_report.py': b'print("test")',
                'external_map_packs/source_pngs/13474.png': b'original source',
                'data/pr122_native_locomotion_staging.json': b'work in progress',
                'assets/maps/aden_world_draft/preview.png': b'draft',
                'data/maps/navigation/oman_01.nav': b'active runtime',
                'external_map_packs/native_png_v5/index.json': b'active runtime',
                '.twilight_update_backup_20261027/scripts/world.gd': b'rollback',
                '.godot/imported/keep.ctex': b'Godot import',
                'local_save.json': b'custom user file',
            }
            for name, value in sample.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(value)
            with mock.patch('builtins.input', side_effect=AssertionError('must not prompt')):
                count, size = updater.cleanup_unused(root, delete=False)
            self.assertEqual(count, 5)
            self.assertEqual(size, sum(len(sample[p]) for p in (
                'docs/report/large.png', 'tools/build_report.py',
                'external_map_packs/source_pngs/13474.png',
                'data/pr122_native_locomotion_staging.json',
                'assets/maps/aden_world_draft/preview.png')))
            for name, value in sample.items():
                self.assertEqual((root/name).read_bytes(), value)

    def test_cleanup_requires_explicit_phrase_and_preserves_runtime(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            (root / 'project.godot').write_bytes(b'game')
            (root / 'Main.tscn').write_bytes(b'scene')
            old = root / 'external_map_packs/source_pngs/13474.png'
            old.parent.mkdir(parents=True)
            old.write_bytes(b'original source')
            report = root / 'docs/report.md'
            report.parent.mkdir()
            report.write_bytes(b'report')
            active = root / 'external_map_packs/native_png_v5/index.json'
            active.parent.mkdir()
            active.write_bytes(b'runtime')
            backup = root / '.twilight_update_backup_123/scripts/world.gd'
            backup.parent.mkdir(parents=True)
            backup.write_bytes(b'rollback')
            with mock.patch('builtins.input', return_value='YES'):
                updater.cleanup_unused(root, delete=True)
            self.assertTrue(old.exists())
            self.assertTrue(report.exists())
            with mock.patch('builtins.input', return_value='DELETE UNUSED'):
                count, size = updater.cleanup_unused(root, delete=True)
            self.assertEqual(count, 2)
            self.assertEqual(size, len(b'original source') + len(b'report'))
            self.assertFalse(old.exists())
            self.assertFalse(report.exists())
            self.assertEqual(active.read_bytes(), b'runtime')
            self.assertEqual(backup.read_bytes(), b'rollback')
            self.assertEqual((root/'project.godot').read_bytes(), b'game')

    def test_cleanup_aborts_before_deletion_if_file_modified_at_prompt(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            (root/'project.godot').write_bytes(b'game')
            (root/'Main.tscn').write_bytes(b'scene')
            old = root / 'docs/report.md'
            old.parent.mkdir()
            old.write_bytes(b'original')
            other = root / 'tools/old.py'
            other.parent.mkdir()
            other.write_bytes(b'unused')
            def mutate():
                old.write_bytes(b'changed since preview')
                return 'DELETE UNUSED'
            with mock.patch('builtins.input', side_effect=lambda *_: mutate()):
                with self.assertRaisesRegex(RuntimeError, 'changed since preview'):
                    updater.cleanup_unused(root, delete=True)
            self.assertEqual(old.read_bytes(), b'changed since preview')
            self.assertEqual(other.read_bytes(), b'unused')

    def test_cleanup_refuses_git_checkout_and_symlink_destinations(self):
        with tempfile.TemporaryDirectory() as t, tempfile.TemporaryDirectory() as outside:
            root = Path(t)
            (root/'project.godot').write_bytes(b'game')
            (root/'Main.tscn').write_bytes(b'scene')
            (root/'.git').mkdir()
            with self.assertRaisesRegex(RuntimeError, 'Git checkout'):
                updater.cleanup_unused(root)
            (root/'.git').rmdir()
            (root/'docs').symlink_to(outside, target_is_directory=True)
            external = Path(outside)/'custom.txt'
            external.write_bytes(b'do not touch')
            with mock.patch('builtins.input', side_effect=AssertionError('no prompt')):
                count, _ = updater.cleanup_unused(root, delete=False)
            self.assertEqual(count, 0)
            self.assertEqual(external.read_bytes(), b'do not touch')



    def test_fresh_install_restores_deleted_project_without_report_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'TWILIGHT_Play'
            files = {
                'project.godot': b'new Godot project',
                'Main.tscn': b'entry scene',
                'scripts/world.gd': b'gameplay',
                'external_map_packs/native_png_v5/index.json': b'active map',
            }
            inventory = {name: record(blob) for name, blob in files.items()}
            def fake_download(sha, name, row, destination):
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(files[name])
            with mock.patch.object(updater, 'get_inventory',
                                   return_value=('a'*40, inventory)), mock.patch.object(
                                       updater, 'download_verified', side_effect=fake_download):
                updater.update(root, assume_yes=True, install_fresh=True)
            for name, data in files.items():
                self.assertEqual((root/name).read_bytes(), data)
            self.assertFalse((root/'docs').exists())
            self.assertFalse((root/'tools').exists())
            self.assertFalse(list(root.glob('.twilight_update_backup_*')))
            self.assertTrue((root/updater.STATE_FILE).is_file())

    def test_fresh_install_refuses_nonempty_folder_without_modifying_it(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'TWILIGHT_Play'
            root.mkdir()
            user = root / 'important-user-data.txt'
            user.write_bytes(b'keep me')
            with mock.patch.object(updater, 'get_inventory',
                                   side_effect=AssertionError('must not fetch')):
                with self.assertRaisesRegex(RuntimeError, 'EMPTY'):
                    updater.update(root, assume_yes=True, install_fresh=True)
            self.assertEqual(user.read_bytes(), b'keep me')

    def test_fresh_install_failed_download_leaves_no_partial_game(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'TWILIGHT_Play'
            inventory = {
                'project.godot': record(b'project'),
                'Main.tscn': record(b'scene'),
            }
            with mock.patch.object(updater, 'get_inventory',
                                   return_value=('a'*40, inventory)), mock.patch.object(
                                       updater, 'download_verified', side_effect=RuntimeError('offline')):
                with self.assertRaisesRegex(RuntimeError, 'offline'):
                    updater.update(root, assume_yes=True, install_fresh=True)
            self.assertTrue(root.is_dir())
            self.assertFalse((root/'project.godot').exists())
            self.assertFalse((root/'Main.tscn').exists())
            self.assertFalse(list(root.glob('.twilight_update_backup_*')))


if __name__ == '__main__':
    unittest.main()
