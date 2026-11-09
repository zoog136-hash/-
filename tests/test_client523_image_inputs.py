#!/usr/bin/env python3
"""Complete-client image inputs: source index and container identity gates.

No image fixtures, keys or original bytes: tables and DATs below are opaque.
"""
import base64
import hashlib
import importlib.util
import io
import json
import pathlib
import tempfile
import unittest
import zipfile

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / 'tools/images/client523_image_inputs.py'
SPEC = importlib.util.spec_from_file_location('client523_image_inputs_under_test', SCRIPT)
INPUTS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(INPUTS)


class ClientImageInputs(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='client523-image-inputs-')
        self.root = pathlib.Path(self.temporary.name)
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, 'w') as archive:
            archive.writestr('content/AssetView.json', json.dumps({'rows': [{'AssetId': 1}, {'AssetId': 2}]}))
            archive.writestr('content/NotRows.json', json.dumps([1, 2]))
            archive.writestr('README.txt', 'opaque')
        self.tables = self.root / 'tables.zip'
        self.tables.write_bytes(buffer.getvalue())
        self.key = self.root / 'key.b64'
        self.key.write_text(base64.b64encode(bytes(16)).decode())
        (self.root / 'dat').mkdir()
        self.dat = b'opaque container bytes'
        (self.root / 'dat/Image1.dat').write_bytes(self.dat)

    def tearDown(self):
        self.temporary.cleanup()

    def files_info(self, digest=None, version=523):
        path = self.root / 'files_info.json'
        path.write_text(json.dumps({'version': version, 'files': [
            {'path': 'Client/Data/Image1.dat', 'hash': digest or hashlib.sha1(self.dat).hexdigest(),
             'size': len(self.dat), 'version': '521'}]}))
        return path

    def test_source_index_records_exact_table_identity(self):
        output = self.root / 'out'
        output.mkdir()
        index, written = INPUTS.source_tables(self.tables, output)
        raw = (output / 'tables/AssetView.json').read_bytes()
        self.assertEqual(written, {'AssetView': 2})
        self.assertEqual(index, [{'path': 'content/AssetView.json', 'version': 523, 'status': 'strict_json_pass',
                                  'member_crc_verified': True, 'bytes': len(raw),
                                  'sha256': hashlib.sha256(raw).hexdigest(), 'row_count': 2}])

    def test_container_must_match_files_info_before_decoding(self):
        with self.assertRaises(SystemExit):
            INPUTS.build(self.files_info('0' * 40), self.root / 'dat', self.tables, self.key, self.root / 'out')
        self.assertFalse((self.root / 'out/decoder/records').exists() and any((self.root / 'out/decoder/records').iterdir()))

    def test_only_version_523_and_new_output_are_accepted(self):
        with self.assertRaises(SystemExit):
            INPUTS.build(self.files_info(version=525), self.root / 'dat', self.tables, self.key, self.root / 'out')
        (self.root / 'existing').mkdir()
        with self.assertRaises(SystemExit):
            INPUTS.build(self.files_info(), self.root / 'dat', self.tables, self.key, self.root / 'existing')

    def test_params_file_is_private(self):
        try:
            INPUTS.build(self.files_info(), self.root / 'dat', self.tables, self.key, self.root / 'out')
        except Exception:
            pass  # the opaque container is not a real DAT; only the private params write is checked
        params = self.root / 'out/params.json'
        self.assertTrue(params.exists())
        self.assertEqual(params.stat().st_mode & 0o777, 0o600)


if __name__ == '__main__':
    unittest.main()
