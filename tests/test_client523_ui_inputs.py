"""Synthetic-fixture tests for the 523 client UI inputs, pack and icon selection.

No original files: tiny ZIP DATs, synthetic scene trees and synthetic packs.
"""
import hashlib
import io
import json
import os
from pathlib import Path
import stat
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/ui'))
import client523_ui_inputs as inputs  # noqa: E402
import build_original_ui_pack as pack  # noqa: E402
import build_client523_icon_scene_selection as selection  # noqa: E402


def zbytes(entries):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, 'w', zipfile.ZIP_STORED) as archive:
        for name, body in entries.items():
            archive.writestr(name, body)
    return buffer.getvalue()


def row(path, body, version='523'):
    return {'path': path, 'hash': hashlib.sha1(body).hexdigest(), 'size': str(len(body)), 'version': version}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def resource(path, plist=''):
    return {'_type': 'ResourceData', 'path': path, 'plistFile': plist, 'resourceType': 1 if plist else 0}


def tree(*references, clips=('normal',)):
    children = [{'_offset': 20 + i, 'classname': 'Sprite', 'children': [],
                 'options': {'nodeOptions': {'name': f'S{i}'}, 'fileNameData': ref}}
                for i, ref in enumerate(references)]
    return {'_decode_blockers': [], 'version': '2.1.0.0',
            'animationList': [{'name': name, 'startIndex': 0, 'endIndex': 10} for name in clips],
            'nodeTree': {'_offset': 10, 'classname': 'Node', 'options': {'nodeOptions': {'name': 'Node'}},
                         'children': children}}


class FakeBuilder(pack.Builder):
    """Builder whose CSB decoding returns synthetic trees keyed by member bytes."""
    trees = {}

    def _parse(self, raw):
        value = json.loads(json.dumps(self.trees[raw]))
        value['_source_sha256'] = sha(raw)
        return value

    def closure(self, member):
        probe = FakeBuilder(self.index, self.link_originals)
        probe.files, probe.atlases, probe._trees = self.files, self.atlases, self._trees
        probe.scene(member)
        return probe


class UiInputsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.dat_dir = self.tmp / 'Data'
        self.dat_dir.mkdir()
        self.ui1 = zbytes({'UI/A.csb': b'scene-a', 'UI/a.png': b'png-a'})
        self.ui2 = zbytes({'UI/CsbFile/icon/Fx.csb': b'scene-icon'})
        (self.dat_dir / 'UI1.dat').write_bytes(self.ui1)
        (self.dat_dir / 'UI2.dat').write_bytes(self.ui2)
        self.info = {'version': 523, 'files': [row('Client/Data/UI1.dat', self.ui1),
                                               row('Client/Data/UI2.dat', self.ui2, '519'),
                                               row('Client/Data/Image1.dat', b'other')]}
        self.info_path = self.tmp / 'files_info.json'
        self.info_path.write_text(json.dumps(self.info))

    def test_verified_index_members_and_scene_list(self):
        result = inputs.build(self.info_path, self.dat_dir, self.tmp / 'out')
        self.assertEqual((result['containers'], result['members'], result['csb_scenes']), (2, 3, 2))
        index = json.loads((self.tmp / 'out/source-index.json').read_text())
        entry = index['source_files']['UI/a.png']
        self.assertEqual(entry['sha256'], sha(b'png-a'))
        self.assertEqual(entry['container'], 'Client/Data/UI1.dat')
        self.assertEqual(index['containers']['Client/Data/UI2.dat']['files_info_version'], 519)
        self.assertEqual(Path(entry['origin']).read_bytes(), b'png-a')
        self.assertEqual(stat.S_IMODE(os.stat(entry['origin']).st_mode), 0o400)
        self.assertEqual((self.tmp / 'out/csb-scenes.txt').read_text().split(),
                         ['UI/A.csb', 'UI/CsbFile/icon/Fx.csb'])

    def test_changed_or_absent_dat_stops(self):
        (self.dat_dir / 'UI2.dat').write_bytes(self.ui2 + b'x')
        with self.assertRaises(SystemExit):
            inputs.build(self.info_path, self.dat_dir, self.tmp / 'out')
        (self.dat_dir / 'UI2.dat').unlink()
        with self.assertRaises(SystemExit):
            inputs.build(self.info_path, self.dat_dir, self.tmp / 'out2')

    def test_duplicate_member_across_dats_stops(self):
        twin = zbytes({'UI/a.png': b'png-b'})
        (self.dat_dir / 'UI2.dat').write_bytes(twin)
        self.info['files'][1] = row('Client/Data/UI2.dat', twin)
        self.info_path.write_text(json.dumps(self.info))
        with self.assertRaisesRegex(SystemExit, 'duplicate UI member'):
            inputs.build(self.info_path, self.dat_dir, self.tmp / 'out')

    def test_output_must_be_new(self):
        (self.tmp / 'out').mkdir()
        with self.assertRaises(SystemExit):
            inputs.build(self.info_path, self.dat_dir, self.tmp / 'out')


class PackTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        files = {'UI/Good.csb': b'good', 'UI/Bad.csb': b'bad', 'UI/a.png': b'png-a'}
        self.index = {}
        for name, body in files.items():
            path = self.tmp / 'members' / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(body)
            self.index[name] = {'origin': str(path), 'sha256': sha(body)}
        FakeBuilder.trees = {b'good': tree(resource('a.png')),
                             b'bad': tree(resource('a.png'), resource('absent.png'))}

    def test_complete_scenes_only_lists_and_leaves_out_incomplete(self):
        builder = FakeBuilder(self.index, link_originals=True)
        kept, excluded = builder.complete_scenes(['UI/Good.csb', 'UI/Bad.csb'])
        self.assertEqual(kept, ['UI/Good.csb'])
        self.assertEqual(excluded['UI/Bad.csb'], [{'member': 'UI/absent.png', 'reason': 'source_not_received'}])
        receipt = builder.build(kept, self.tmp / 'pack')
        self.assertEqual(receipt['status'], 'DEPENDENCIES_RESOLVED_NOT_RENDERED')
        self.assertEqual((receipt['entries'], receipt['incomplete_source_scenes']), (1, 1))
        manifest = json.loads((self.tmp / 'pack/original_ui.json').read_text())
        self.assertEqual(sorted(manifest['files']), ['UI/Good.csb', 'UI/a.png'])  # Bad.csb not packed
        self.assertEqual(manifest['blockers'], [])
        self.assertIn('UI/Bad.csb', manifest['incomplete_source_scenes'])

    def test_link_originals_hardlinks_unchanged_bytes(self):
        builder = FakeBuilder(self.index, link_originals=True)
        builder.build(['UI/Good.csb'], self.tmp / 'pack')
        packed = self.tmp / 'pack/originals/UI/a.png'
        self.assertEqual(os.stat(packed).st_ino, os.stat(self.index['UI/a.png']['origin']).st_ino)
        copied = FakeBuilder(self.index)
        copied.build(['UI/Good.csb'], self.tmp / 'pack2')
        self.assertNotEqual(os.stat(self.tmp / 'pack2/originals/UI/a.png').st_ino,
                            os.stat(self.index['UI/a.png']['origin']).st_ino)

    def test_shared_cache_still_reports_absent_atlas_page(self):
        plist = (b'<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>frames</key><dict/>'
                 b'<key>metadata</key><dict><key>format</key><integer>2</integer>'
                 b'<key>textureFileName</key><string>gone.png</string></dict></dict></plist>')
        path = self.tmp / 'members/UI/atlas.plist'
        path.write_bytes(plist)
        self.index['UI/atlas.plist'] = {'origin': str(path), 'sha256': sha(plist)}
        FakeBuilder.trees = {b'good': tree(resource('f.png', 'atlas.plist')), b'bad': tree(resource('f.png', 'atlas.plist'))}
        builder = FakeBuilder(self.index)
        kept, excluded = builder.complete_scenes(['UI/Good.csb', 'UI/Bad.csb'])
        self.assertEqual(kept, [])
        for member in ('UI/Good.csb', 'UI/Bad.csb'):
            reasons = {b['reason'] for b in excluded[member]}
            self.assertEqual(reasons, {'source_not_received', 'exact_frame_absent'})


class SelectionTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.ui = self.tmp / 'ui'
        self.ui.mkdir()
        icon_sha = sha(b'icon-scene')
        scenes = {'UI/CsbFile/icon/Fx_A.csb': dict(tree(), _source_sha256=icon_sha),
                  'UI/CsbFile/icon/Fx_B.csb': dict(tree(clips=('idle',)), _source_sha256=sha(b'b'))}
        self.ui_manifest = {'schema': 'twilight-original-ui-v1', 'scenes': scenes, 'atlases': {}, 'blockers': [],
                            'files': {'UI/CsbFile/icon/Fx_A.csb': {'sha256': icon_sha, 'bytes': 10},
                                      'UI/CsbFile/icon/Fx_B.csb': {'sha256': sha(b'b'), 'bytes': 1}}}
        (self.ui / 'original_ui.json').write_text(json.dumps(self.ui_manifest))
        self.images = {'source_snapshot': 'patch523', 'source_version': 523,
                       'assets': [{'asset_id': 7, 'asset_type_id': 101, 'path': 'UI/CsbFile/icon/Fx_A.csb', 'status': 'unsupported_csb'},
                                  {'asset_id': 8, 'asset_type_id': 101, 'path': 'UI/CsbFile/icon/Fx_B.csb', 'status': 'unsupported_csb'},
                                  {'asset_id': 9, 'asset_type_id': 101, 'path': 'UI/CsbFile/icon/Fx_C.csb', 'status': 'unsupported_csb'},
                                  {'asset_id': 10, 'asset_type_id': 2, 'path': 'icon/x.png', 'status': 'verified_original'}],
                       'icons': [{'id': 1, 'asset_id': 7}, {'id': 2, 'asset_id': 8}, {'id': 3, 'asset_id': 9}, {'id': 4, 'asset_id': 10}],
                       'consumers': {'ItemClass': [{'id': 5, 'roles': {'IconID': 1}}, {'id': 6, 'roles': {'IconID': 3}}],
                                     'SpellClass': [{'id': 7, 'roles': {'IconID': 1, 'ActivateIconID': 4}}]}}
        self.image_path = self.tmp / 'manifest.json'
        self.image_path.write_text(json.dumps(self.images))

    def test_client_normal_loop_bindings(self):
        out = self.tmp / 'sel' / 'selection.json'
        out.parent.mkdir()
        result = selection.build(self.image_path, self.ui, out)
        self.assertEqual(result['icons_bound'], 1)
        self.assertEqual(result['icons_unresolved'], {'client_normal_clip_not_unique': 1, 'csb_absent_from_ui_pack': 1})
        self.assertEqual(result['consumer_references_bound'], {'ItemClass.IconID': 1, 'SpellClass.IconID': 1})
        self.assertEqual(result['consumer_references_unresolved'], {'ItemClass.IconID': 1})
        document = json.loads(out.read_text())
        self.assertEqual(document['schema'], 'source523-original-ui-icon-selection-v1')
        self.assertFalse(document['estimate_missing_repeat'])
        ui_sha = sha((self.ui / 'original_ui.json').read_bytes())
        self.assertEqual(document['packs'], [{'root': '../ui', 'manifest_sha256': ui_sha}])
        spec = document['document']['source_icon_scenes']['icons']['1']
        self.assertEqual((spec['member'], spec['file_path'], spec['asset_id'], spec['asset_type_id']),
                         ('UI/CsbFile/icon/Fx_A.csb', 'icon/Fx_A.csb', 7, 101))
        self.assertEqual((spec['clip'], spec['repeat'], spec['original_repeat_declared'], spec['original_policy_confirmed']),
                         ('normal', True, True, True))
        self.assertEqual(spec['current523_scene_sha256'], sha(b'icon-scene'))
        self.assertEqual(spec['reviewed_current523_manifest_sha256'], ui_sha)

    def test_pack_with_blockers_is_refused(self):
        self.ui_manifest['blockers'] = [{'member': 'UI/x.png', 'reason': 'source_not_received'}]
        (self.ui / 'original_ui.json').write_text(json.dumps(self.ui_manifest))
        with self.assertRaises(SystemExit):
            selection.build(self.image_path, self.ui, self.tmp / 'selection.json')
        self.assertFalse((self.tmp / 'selection.json').exists())

    def test_existing_selection_is_preserved(self):
        out = self.tmp / 'selection.json'
        out.write_text('keep')
        with self.assertRaises(SystemExit):
            selection.build(self.image_path, self.ui, out)
        self.assertEqual(out.read_text(), 'keep')


if __name__ == '__main__':
    unittest.main()
