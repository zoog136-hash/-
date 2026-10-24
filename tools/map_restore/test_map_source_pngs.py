"""Small code fixtures; these are not real-map gameplay validation."""
import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from PIL import Image
from verify_map_source_pngs import PLANS, SOURCE, verify


class SourceBytesTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / 'repo'
        source = self.root / SOURCE
        source.mkdir(parents=True)
        buffer = io.BytesIO()
        Image.new('RGBA', (3, 2), (34, 56, 78, 200)).save(buffer, format='PNG')
        self.original = buffer.getvalue()
        spec = {'bytes': len(self.original), 'sha256': hashlib.sha256(self.original).hexdigest(),
                'size': [3, 2], 'mode': 'RGBA', 'alpha': True}
        for i, plan in enumerate(PLANS):
            path = self.root / plan
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps({'sources': {'Aden.png': spec} if i == 0 else {}}))
        pieces = [self.original[:31], self.original[31:]]
        parts = []
        for i, data in enumerate(pieces):
            name = f'Aden.png.part{i + 1:03d}'
            (source / name).write_bytes(data)
            parts.append({'file': name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
        self.manifest = {'schema': 1, 'original_files': 1, 'original_bytes': len(self.original),
                         'sources': [dict(spec, file='Aden.png', parts=parts)]}
        self.save_manifest()

    def save_manifest(self):
        (self.root / SOURCE / 'manifest.json').write_text(json.dumps(self.manifest))

    def test_exact_restore_and_decode_without_overwrite(self):
        output = Path(self.temporary.name) / 'restored'
        report = verify(self.root, output, decode=True)
        self.assertEqual((output / 'Aden.png').read_bytes(), self.original)
        self.assertTrue(report['all_pngs_fully_decoded'])
        with self.assertRaises(ValueError):
            verify(self.root, output)
        self.assertEqual((output / 'Aden.png').read_bytes(), self.original)

    def test_corrupt_part_cannot_publish_restored_source(self):
        (self.root / SOURCE / 'Aden.png.part002').write_bytes(b'corrupt bytes')
        output = Path(self.temporary.name) / 'restored'
        with self.assertRaises(ValueError):
            verify(self.root, output)
        self.assertFalse(output.exists())

    def test_unsafe_part_path_rejected(self):
        self.manifest['sources'][0]['parts'][0]['file'] = '../outside.png'
        self.save_manifest()
        with self.assertRaises(ValueError):
            verify(self.root)

    def test_manifest_cannot_replace_authenticated_original(self):
        self.manifest['sources'][0]['sha256'] = '0' * 64
        self.save_manifest()
        with self.assertRaises(ValueError):
            verify(self.root)


if __name__ == '__main__':
    unittest.main()
