"""Structural rejection tests; synthetic bytes are not original-art evidence."""
import hashlib
import json
from pathlib import Path
import struct
import plistlib
import sys
import tempfile
import unittest
from xml.parsers.expat import ExpatError

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/ui'))
from read_source_csb import DecodeError, Reader
from build_original_ui_pack import Builder, source_path, particle_dictionary


def minimal_source():
    # A minimal FlatBuffer root with just its original version field.
    raw = bytearray(36)
    struct.pack_into('<I', raw, 0, 12)
    struct.pack_into('<HHH', raw, 4, 6, 8, 4)
    struct.pack_into('<iI', raw, 12, 8, 4)
    struct.pack_into('<I', raw, 20, 7)
    raw[24:32] = b'2.1.0.0\0'
    return raw


class DecoderTests(unittest.TestCase):
    def test_minimal_source_and_provenance(self):
        raw = minimal_source()
        tree = Reader(raw).parse()
        self.assertEqual(tree['version'], '2.1.0.0')
        self.assertEqual(tree['_source_sha256'], hashlib.sha256(raw).hexdigest())
        self.assertEqual(tree['_render_status'], 'NOT_RENDERED')

    def test_invalid_pointer_and_string_bounds(self):
        for offset, value in [(0, 999999), (16, 0), (20, 999999)]:
            with self.subTest(offset=offset):
                raw = minimal_source()
                struct.pack_into('<I', raw, offset, value)
                with self.assertRaises(DecodeError): Reader(raw).parse()
        raw = minimal_source()
        raw[31] = 1
        with self.assertRaises(DecodeError): Reader(raw).parse()

    def test_reject_other_source_version(self):
        raw = minimal_source()
        raw[24] = ord('9')
        with self.assertRaisesRegex(DecodeError, 'Unverified CSB version'):
            Reader(raw).parse()

    def test_missing_dependencies_cannot_report_ready(self):
        with tempfile.TemporaryDirectory() as folder:
            receipt = Builder({}).build(['UI/absent.csb'], Path(folder)/'pack')
            self.assertEqual(receipt['status'], 'BLOCKED')
            self.assertEqual(receipt['blockers'], 1)
            manifest = json.loads((Path(folder)/'pack/original_ui.json').read_text())
            self.assertFalse(manifest['runtime_verified'])
            self.assertEqual(manifest['blockers'][0]['reason'], 'source_not_received')

    def test_source_tampering_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/'source.csb'
            path.write_bytes(minimal_source())
            index = {'UI/source.csb': {'origin': str(path), 'sha256': '0'*64}}
            with self.assertRaisesRegex(ValueError, 'hash mismatch'):
                Builder(index).read('UI/source.csb')

    def test_public_output_and_path_traversal_rejected(self):
        for path in ['../private', '/absolute', 'UI/../escape', 'UI//empty', 'UI/a:b', 'UI/a\\b']:
            with self.subTest(path=path), self.assertRaises(ValueError): source_path(path)
        with self.assertRaisesRegex(ValueError, 'outside the public checkout'):
            Builder({}).build([], ROOT/'must-not-exist-original-ui')
        self.assertFalse((ROOT/'must-not-exist-original-ui').exists())

    def test_existing_pack_is_preserved(self):
        with tempfile.TemporaryDirectory() as folder:
            marker = Path(folder)/'original_ui.json'
            marker.write_text('preserved')
            with self.assertRaisesRegex(ValueError, 'existing packs are preserved'):
                Builder({}).build([], Path(folder))
            self.assertEqual(marker.read_text(), 'preserved')

    def test_complete_particle_root_compatibility_preserves_bytes(self):
        expected = {'textureFileName': 'original.png', 'maxParticles': 12}
        raw = plistlib.dumps(expected) + b'>t>ng>\r\n </dict>\r\n</plist>'
        before = hashlib.sha256(raw).hexdigest()
        value, mode = particle_dictionary(raw)
        self.assertEqual(value, expected)
        self.assertEqual(mode, 'cocos36_first_complete_plist')
        self.assertEqual(hashlib.sha256(raw).hexdigest(), before)
        with self.assertRaises((ValueError, ExpatError)):
            particle_dictionary(b'<plist><dict><key>missing</dict></plist>trailing')
        with self.assertRaisesRegex(ValueError, 'dictionary'):
            particle_dictionary(plistlib.dumps(['not', 'particle parameters']))


if __name__ == '__main__': unittest.main()
