"""Synthetic-fixture tests for client523_source.py (no original files needed)."""
import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

import client523_source as cs


def zbytes(entries, method=zipfile.ZIP_STORED):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, 'w', method) as archive:
        for name, body in entries.items():
            archive.writestr(name, body)
    return buffer.getvalue()


def row(path, body, version):
    return {'path': path, 'hash': hashlib.sha1(body).hexdigest(), 'size': len(body), 'version': version}


class ClientSourceTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        npc = json.dumps({'rows': [{'ID': 1, 'Sprite': 10}, {'ID': 2, 'Sprite': 11},
                                   {'ID': 3, 'Sprite': 99}, {'ID': 4, 'Sprite': 12, 'TestNPC': True}]})
        self.content = zbytes({'content/NpcClass.json': npc, 'content/Item.json': '{"rows":[]}'})
        old_sprite = zbytes({'Sprite/10-0.sp2': b'\xfe\x00old'})
        self.sprite = zbytes({'Sprite/10-0.sp2': b'\xfe\x00new', 'Sprite/10-8.sp2': b'\xfe\x00b'})
        self.lst = b'#10 16 ten\r\n\t0.walk(1 8,0.0:2)\r\n#11 16=10\r\n#99 1 missing\r\n'
        base = zbytes({'Client/Data/content1.dat': self.content,
                       'Client/Data/Sprite1.dat': old_sprite,
                       'Client/Text/list_0.spr': self.lst}, zipfile.ZIP_DEFLATED)
        cut = len(base) // 3
        self.parts = []
        for index, chunk in enumerate((base[:cut], base[cut:2 * cut], base[2 * cut:])):
            part = self.tmp / f'client{index + 1}.part'
            part.write_bytes(chunk)
            self.parts.append(part)
        patch = self.tmp / 'patch521.zip'
        patch.write_bytes(zbytes({'Client/Data/Sprite1.dat': self.sprite, 'unrelated.txt': b'x'}))
        self.patch = patch
        self.info = {'version': 523, 'files': [
            row('Client/Data/content1.dat', self.content, '508'),
            row('Client/Data/Sprite1.dat', self.sprite, '521'),
            row('Client/Text/list_0.spr', self.lst, '508')]}

    def run_source(self, **kw):
        source = cs.ClientSource(self.info, self.parts, [self.patch], **kw)
        try:
            return cs.write_outputs(source, self.tmp / 'out', None)
        finally:
            source.close()

    def test_split_parts_open_as_one_zip_and_patch_wins_by_hash(self):
        receipt, report = self.run_source()
        out = self.tmp / 'out'
        self.assertTrue(receipt['complete'])
        self.assertEqual(receipt['used']['Client/Data/Sprite1.dat']['from'], 'patch:patch521.zip')
        self.assertEqual(receipt['used']['Client/Data/content1.dat']['from'], 'client-zip')
        self.assertEqual((out / 'sp2/Sprite/10-0.sp2').read_bytes(), b'\xfe\x00new')
        self.assertEqual((out / 'spr/list_0.spr').read_bytes(), self.lst)
        self.assertFalse(receipt['password_recorded'])

    def test_alias_resolution_and_test_npc_exclusion(self):
        _, report = self.run_source()
        refs = report['table_references']
        self.assertEqual(refs['referenced_ids'], 3)  # 12 is TestNPC only
        self.assertEqual((refs['direct'], refs['via_alias'], refs['unresolved']), (1, 1, 1))
        self.assertEqual(refs['unresolved_ids'], [99])
        self.assertEqual(report['declarations']['sprite_aliases'], 1)

    def test_tables_zip_is_deterministic(self):
        receipt, _ = self.run_source()
        again = cs.deterministic_zip({'content/Item.json': b'{"rows":[]}',
                                      'content/NpcClass.json': zipfile.ZipFile(io.BytesIO(self.content)).read('content/NpcClass.json')})
        self.assertEqual(receipt['outputs']['tables_zip']['sha256'], hashlib.sha256(again).hexdigest())

    def test_missing_target_hash_is_reported_not_substituted(self):
        self.info['files'][1]['hash'] = '0' * 40
        receipt, _ = self.run_source()
        self.assertFalse(receipt['complete'])
        self.assertIn('Client/Data/Sprite1.dat', receipt['missing'])
        self.assertFalse((self.tmp / 'out/sp2/Sprite/10-0.sp2').exists())

    def test_output_must_be_empty(self):
        (self.tmp / 'out').mkdir()
        (self.tmp / 'out/keep').write_text('x')
        with self.assertRaises(cs.SourceError):
            self.run_source()

    def test_runtime_tables_zip_comparison(self):
        npc = zipfile.ZipFile(io.BytesIO(self.content)).read('content/NpcClass.json')
        same = self.tmp / 'same.zip'
        same.write_bytes(zbytes({'content/NpcClass.json': npc, 'content/Item.json': b'{"rows":[]}', 'index.json': b'[]'}))
        other = self.tmp / 'other.zip'
        other.write_bytes(zbytes({'content/NpcClass.json': b'{"rows":[]}'}))
        source = cs.ClientSource(self.info, self.parts, [self.patch])
        try:
            receipt, _ = cs.write_outputs(source, self.tmp / 'out', None, verify_tables_zip=same)
        finally:
            source.close()
        self.assertTrue(receipt['runtime_tables_zip_comparison']['equivalent'])
        self.assertEqual(cs.compare_tables_zip(other, {'content/NpcClass.json': npc})['different'], ['content/NpcClass.json'])


if __name__ == '__main__':
    unittest.main()
