"""Bounded reader/ingest fixtures; real source-art coverage is a separate run."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock
import zipfile

TOOLS = Path(__file__).resolve().parents[1] / 'tools'
sys.path.insert(0, str(TOOLS))
spec = importlib.util.spec_from_file_location('inputs', TOOLS / 'source84_inputs.py')
inputs = importlib.util.module_from_spec(spec); spec.loader.exec_module(inputs)


class InputsTest(unittest.TestCase):
    def test_split_random_access_matches_one_file(self):
        data = bytes(range(256)) * 7
        with tempfile.TemporaryDirectory() as temp:
            paths = [Path(temp) / '001', Path(temp) / '002']
            paths[0].write_bytes(data[:431]); paths[1].write_bytes(data[431:])
            with inputs.JoinedFile(paths) as actual:
                expected = io.BytesIO(data)
                for offset, whence, length in [(420, 0, 80), (-20, 2, 99), (-49, 1, 17), (0, 0, -1), (9999, 0, 5)]:
                    self.assertEqual(actual.seek(offset, whence), expected.seek(offset, whence))
                    self.assertEqual(actual.read(length), expected.read(length))

    def test_original_and_split_zip_ingest_have_identical_outputs(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); archive = root / 'fixture.zip'; payload = b'fixture only'
            with zipfile.ZipFile(archive, 'w') as z: z.writestr('chunks/test.webp', payload)
            data = archive.read_bytes(); split = len(data) // 2
            parts = [root / 'fixture.zip.001', root / 'fixture.zip.002']
            parts[0].write_bytes(data[:split]); parts[1].write_bytes(data[split:])
            row = {'filename': archive.name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(), 'chunks': 1,
                   'parts': [{'filename': p.name, 'bytes': p.stat().st_size, 'sha256': inputs.digest(p)} for p in parts]}
            manifest = root / 'inputs.json'; manifest.write_text(json.dumps({'archives': [row]}))
            output_spec = {'files': {'chunks/test.webp': {'bytes': len(payload), 'sha256': hashlib.sha256(payload).hexdigest()}}}
            with mock.patch.object(inputs, 'INPUTS', manifest), mock.patch.object(inputs, 'inventory', return_value=output_spec):
                inputs.ingest(root, root / 'full', 1); archive.unlink()
                inputs.ingest(root, root / 'split', 1)
                self.assertEqual((root / 'full/art/chunks/test.webp').read_bytes(), (root / 'split/art/chunks/test.webp').read_bytes())
                parts[0].write_bytes(b'changed')
                with self.assertRaises(ValueError): inputs.ingest(root, root / 'bad', 1)
                self.assertFalse((root / 'bad').exists())


if __name__ == '__main__': unittest.main()
