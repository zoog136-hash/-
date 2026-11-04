"""Small fixtures verify reconstruction failures without distributing M bytes."""
import contextlib
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    'review_transfer', Path(__file__).parents[1]/'tools/map_restore/reassemble_current523_review.py')
TRANSFER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TRANSFER)


class ReviewTransferTest(unittest.TestCase):
    @contextlib.contextmanager
    def fixture(self):
        with tempfile.TemporaryDirectory() as temporary, contextlib.ExitStack() as stack:
            root = Path(temporary)
            chunks = [b'header\x00', b'\xffpayload']
            for key, value in {
                'NAME': 'fixture.zip',
                'PARTS': tuple((len(b), hashlib.sha256(b).hexdigest()) for b in chunks),
                'ARCHIVE_BYTES': sum(map(len, chunks)),
                'ARCHIVE_SHA256': hashlib.sha256(b''.join(chunks)).hexdigest(),
            }.items():
                stack.enter_context(patch.object(TRANSFER, key, value))
            for index, chunk in enumerate(chunks, 1):
                (root/f'fixture.zip.part{index:02d}').write_bytes(chunk)
            yield root, b''.join(chunks)

    def test_exact_parts_publish_with_bin_suffix_supported(self):
        with self.fixture() as (root, expected):
            (root/'fixture.zip.part02').rename(root/'fixture.zip.part02.bin')
            output = TRANSFER.reassemble(root, root/'joined.zip')
            self.assertEqual(output.read_bytes(), expected)
            self.assertFalse(list(root.glob('*.pending-*')))

    def test_corrupt_same_size_part_leaves_no_output(self):
        with self.fixture() as (root, _):
            part = root/'fixture.zip.part02'
            part.write_bytes(b'X'*part.stat().st_size)
            with self.assertRaisesRegex(ValueError, 'SHA256 mismatch'):
                TRANSFER.reassemble(root, root/'bad.zip')
            self.assertFalse((root/'bad.zip').exists())
            self.assertFalse(list(root.glob('*.pending-*')))

    def test_missing_or_duplicate_part_rejects(self):
        with self.fixture() as (root, _):
            part = root/'fixture.zip.part02'
            extra = root/'fixture.zip.part02.bin'
            extra.write_bytes(part.read_bytes())
            with self.assertRaises(ValueError): TRANSFER.reassemble(root, root/'out.zip')
            part.unlink(); extra.unlink()
            with self.assertRaises(ValueError): TRANSFER.reassemble(root, root/'out.zip')
            self.assertFalse((root/'out.zip').exists())

    def test_existing_output_preserved(self):
        with self.fixture() as (root, _):
            output = root/'keep.zip'
            output.write_bytes(b'prior user output')
            with self.assertRaises(FileExistsError): TRANSFER.reassemble(root, output)
            self.assertEqual(output.read_bytes(), b'prior user output')

    def test_concurrent_output_creation_preserved(self):
        with self.fixture() as (root, _):
            output = root/'keep.zip'
            original_link = TRANSFER.os.link
            def competing_writer(source, target):
                output.write_bytes(b'other writer')
                return original_link(source, target)
            with patch.object(TRANSFER.os, 'link', competing_writer):
                with self.assertRaises(FileExistsError): TRANSFER.reassemble(root, output)
            self.assertEqual(output.read_bytes(), b'other writer')
            self.assertFalse(list(root.glob('*.pending-*')))


if __name__ == '__main__':
    unittest.main()
