"""Malformed opaque/structural-input tests; no real parameters or image pixels.

PNG envelopes below deliberately contain an all-zero, invalid IHDR and an empty
IDAT. They cannot represent a decodable image, remain in memory, and exercise
chunk framing only. No image fixture is generated, saved, or passed to Pillow.
"""
import importlib.util
import copy
import json
from pathlib import Path
import struct
import tempfile
import unittest
import zlib


DECODER = Path(__file__).resolve().parents[1] / 'tools/images/decode_source523_image_dat.py'
spec = importlib.util.spec_from_file_location('strict_dat_decoder_under_test', DECODER)
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)


def record(path=b'Image/opaque', offset=0, size=16, kind=255):
    return struct.pack('<i', len(path)) + path + struct.pack('<iiB', offset, size, kind)


def footer(body_size=16, index_size=16, offset=None, flag=1, extra=b''):
    if offset is None:
        offset = body_size
    return bytes(body_size + index_size) + extra + struct.pack('<iiB', offset, index_size, flag)


def chunk(kind, payload=b''):
    return struct.pack('>I', len(payload)) + kind + payload + struct.pack('>I', zlib.crc32(kind + payload) & 0xffffffff)


SIGNATURE = b'\x89PNG\r\n\x1a\n'
INVALID_IHDR = chunk(b'IHDR', bytes(13))
EMPTY_IDAT = chunk(b'IDAT')
IEND = chunk(b'IEND')


class PaddingTests(unittest.TestCase):
    def test_opaque_padding_removed_exactly(self):
        self.assertEqual(d.strict_unpad(b'opaque-input' + bytes([4]) * 4), (b'opaque-input', 4))

    def test_whole_padding_block(self):
        self.assertEqual(d.strict_unpad(bytes([16]) * 16), (b'', 16))

    def test_malformed_padding_rejected(self):
        for payload in (b'', b'partial', bytes(16), bytes([17]) * 16, b'x' * 14 + b'\x01\x02'):
            with self.subTest(length=len(payload), last=payload[-1:] if payload else b''):
                with self.assertRaises(d.ValidationError):
                    d.strict_unpad(payload)


class CipherBoundsTests(unittest.TestCase):
    def test_partial_and_empty_ciphertext_rejected(self):
        # These are synthetic all-zero opaque values, never actual parameters.
        for size in (0, 1, 15, 17, 31):
            with self.subTest(size=size):
                with self.assertRaises(d.ValidationError):
                    d.decrypt(bytes(size), bytes(16), bytes(16))

    def test_wrong_key_or_iv_size_rejected(self):
        for key_size, iv_size in ((0, 16), (15, 16), (32, 16), (16, 0), (16, 15), (16, 17)):
            with self.subTest(key_size=key_size, iv_size=iv_size):
                with self.assertRaises(d.ValidationError):
                    d.decrypt(bytes(16), bytes(key_size), bytes(iv_size))


class FooterTests(unittest.TestCase):
    def test_exact_layout(self):
        parsed = d.read_footer(footer())
        self.assertEqual((parsed['index_offset'], parsed['index_bytes'], parsed['encrypted']), (16, 16, True))

    def test_any_nonzero_flag_is_encrypted_as_source_specifies(self):
        self.assertTrue(d.read_footer(footer(flag=255))['encrypted'])

    def test_truncated_container_rejected(self):
        for n in range(10):
            with self.subTest(n=n), self.assertRaises(d.ValidationError):
                d.read_footer(bytes(n))

    def test_negative_or_empty_extent_rejected(self):
        for offset, size in ((-1, 16), (16, -1), (16, 0)):
            with self.subTest(offset=offset, size=size), self.assertRaises(d.ValidationError):
                d.read_footer(bytes(32) + struct.pack('<iiB', offset, size, 1))

    def test_overrun_and_arithmetic_boundary_rejected(self):
        for offset, size in ((17, 16), (0x7fffffff, 16), (16, 0x7fffffff)):
            with self.subTest(offset=offset, size=size), self.assertRaises(d.ValidationError):
                d.read_footer(bytes(32) + struct.pack('<iiB', offset, size, 1))

    def test_gap_before_footer_rejected(self):
        with self.assertRaises(d.ValidationError):
            d.read_footer(footer(extra=b'x'))

    def test_partial_encrypted_extent_rejected(self):
        for body, size in ((15, 16), (16, 15)):
            with self.subTest(body=body, size=size), self.assertRaises(d.ValidationError):
                d.read_footer(footer(body, size))

    def test_plain_index_need_not_be_block_aligned(self):
        self.assertFalse(d.read_footer(footer(1, 1, flag=0))['encrypted'])


class PathTests(unittest.TestCase):
    def test_original_case_and_unicode_preserved(self):
        path = 'Image/BM/opaque_한글'
        self.assertEqual(d.safe_path(path.encode()), path)

    def test_invalid_utf8_rejected(self):
        for path in (b'Image/\xff', b'Image/\xc0\xaf', b'Image/\xed\xa0\x80'):
            with self.subTest(path=path), self.assertRaises(d.ValidationError):
                d.safe_path(path)

    def test_unsafe_paths_rejected(self):
        paths = (b'', b'/Image/a', b'Image\\a', b'C:Image/a', b'Image/../a', b'Image/./a',
                 b'Image//a', b'Image/a/', b'Image/\x00a', b'Image/\na', b'Other/a',
                 'Image/zero\u200bwidth'.encode())
        for path in paths:
            with self.subTest(path=path), self.assertRaises(d.ValidationError):
                d.safe_path(path)


class IndexTests(unittest.TestCase):
    def test_valid_opaque_record_and_uninterpreted_type(self):
        rows = d.parse_index(record(), body_end=16, encrypted=True)
        self.assertEqual(rows, [{'path': 'Image/opaque', 'offset': 0, 'encrypted_bytes': 16, 'type': 255}])

    def test_plain_unaligned_record(self):
        self.assertEqual(d.parse_index(record(offset=1, size=2), 3, False)[0]['offset'], 1)

    def test_empty_and_partial_record_rejected(self):
        for payload in (b'', b'\x01', b'\x01\x00\x00', struct.pack('<i', 10) + b'a', record()[:-1]):
            with self.subTest(length=len(payload)), self.assertRaises(d.ValidationError):
                d.parse_index(payload, 16, True)

    def test_invalid_path_lengths_rejected(self):
        for n in (0, -1, 501, 0x7fffffff):
            with self.subTest(n=n), self.assertRaises(d.ValidationError):
                d.parse_index(struct.pack('<i', n) + bytes(600), 16, True)

    def test_every_trailing_byte_is_rejected(self):
        for suffix in (b'x', b'xx', b'xxx', bytes(4), bytes([16]) * 16):
            with self.subTest(length=len(suffix)), self.assertRaises(d.ValidationError):
                d.parse_index(record() + suffix, 16, True)

    def test_bad_utf8_in_record_rejected(self):
        with self.assertRaises(d.ValidationError):
            d.parse_index(record(b'Image/\xff'), 16, True)

    def test_duplicate_and_casefold_duplicate_rejected(self):
        for second in (b'Image/opaque', b'Image/OPAQUE'):
            with self.subTest(second=second), self.assertRaises(d.ValidationError):
                d.parse_index(record() + record(second, 16, 16), 32, True)

    def test_invalid_member_extent_rejected(self):
        for offset, size in ((-1, 16), (0, -1), (0, 0), (16, 16), (0x7fffffff, 16), (0, 0x7fffffff)):
            with self.subTest(offset=offset, size=size), self.assertRaises(d.ValidationError):
                d.parse_index(record(offset=offset, size=size), 16, True)

    def test_encrypted_alignment_rejected(self):
        for offset, size in ((1, 16), (0, 15)):
            with self.subTest(offset=offset, size=size), self.assertRaises(d.ValidationError):
                d.parse_index(record(offset=offset, size=size), 32, True)

    def test_overlap_rejected_even_out_of_index_order(self):
        for first_offset, second_offset in ((0, 16), (16, 0)):
            with self.subTest(order=(first_offset, second_offset)), self.assertRaises(d.ValidationError):
                d.parse_index(record(offset=first_offset, size=32) + record(b'Image/second', second_offset, 32), 64, True)

    def test_adjacent_unsorted_ranges_accepted(self):
        rows = d.parse_index(record(offset=16) + record(b'Image/second', 0), 32, True)
        self.assertEqual(len(rows), 2)


class ExpectedCatalogTests(unittest.TestCase):
    def test_exact_member_set_required(self):
        with self.assertRaises(d.ValidationError):
            d.check_expected([{'path': 'Image/a', 'encrypted_bytes': 16}], {'Image/b': {'encrypted_bytes': 16}})

    def test_exact_stored_length_required(self):
        with self.assertRaises(d.ValidationError):
            d.check_expected([{'path': 'Image/a', 'encrypted_bytes': 16}], {'Image/a': {'encrypted_bytes': 32}})

    def test_duplicate_rows_rejected_even_with_matching_set(self):
        for duplicate in ('Image/a', 'Image/A'):
            with self.subTest(duplicate=duplicate), self.assertRaises(d.ValidationError):
                d.check_expected([{'path': 'Image/a', 'encrypted_bytes': 16}, {'path': duplicate, 'encrypted_bytes': 16}],
                                 {'Image/a': {'encrypted_bytes': 16}})


class OutputDestinationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='opaque-path-', dir=Path(__file__).parent)
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.decoded = self.base / 'decoded'
        self.decoded.mkdir()
        self.other = self.base / 'other'
        self.other.mkdir()

    def test_missing_safe_destination_preserves_exact_path(self):
        dest = d.output_destination(self.decoded, 'Image/BM/opaque')
        self.assertEqual(dest, self.decoded / 'Image/BM/opaque')
        self.assertFalse(dest.exists())

    def test_unsafe_logical_paths_rejected(self):
        for path in ('../opaque', '/Image/opaque', 'Image//opaque', 'Image/./opaque'):
            with self.subTest(path=path), self.assertRaises(d.ValidationError):
                d.output_destination(self.decoded, path)

    def test_symlink_root_rejected(self):
        link = self.base / 'linked-root'
        link.symlink_to(self.other, target_is_directory=True)
        with self.assertRaises(d.ValidationError):
            d.output_destination(link, 'Image/opaque')

    def test_symlink_directory_component_rejected(self):
        (self.decoded / 'Image').symlink_to(self.other, target_is_directory=True)
        with self.assertRaises(d.ValidationError):
            d.output_destination(self.decoded, 'Image/opaque')

    def test_symlink_to_inside_root_also_rejected(self):
        target = self.decoded / 'real'
        target.mkdir()
        (self.decoded / 'Image').symlink_to(target, target_is_directory=True)
        with self.assertRaises(d.ValidationError):
            d.output_destination(self.decoded, 'Image/opaque')

    def test_final_and_dangling_symlink_rejected(self):
        (self.decoded / 'Image').mkdir()
        target = self.other / 'opaque'
        target.write_bytes(b'opaque structural bytes')
        link = self.decoded / 'Image/opaque'
        link.symlink_to(target)
        with self.assertRaises(d.ValidationError):
            d.output_destination(self.decoded, 'Image/opaque')
        target.unlink()
        with self.assertRaises(d.ValidationError):
            d.output_destination(self.decoded, 'Image/opaque')


class ResumeTests(unittest.TestCase):
    """Exercise resume trust checks with metadata and opaque, non-image files."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='opaque-resume-', dir=Path(__file__).parent)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.payload = b'opaque structural output, never image data'
        self.original = b'opaque original container marker, no real DAT'
        self.parameters = {'test_only': 'opaque-no-secrets', 'source_provenance': {'fixture': 'structural'}}
        self.identity = {'sha256': d.sha256(self.original), 'bytes': len(self.original), 'current523_alignment': 'test-only'}
        self.rows = [{'path': 'Image/opaque', 'relative_output_path': 'decoded/Image/opaque',
                      'container': 'Client/Data/opaque.dat', 'original_container_sha256': self.identity['sha256'],
                      'encrypted_bytes': 64, 'plain_bytes': len(self.payload), 'sha256': d.sha256(self.payload),
                      'format': 'PNG', 'width': 1, 'height': 1, 'mode': 'opaque-metadata-only',
                      'png_chunk_count': 1, 'png_all_chunk_crc_verified': True,
                      'pkcs7_padding_verified': True, 'pillow_verify_and_load': True,
                      'original_bytes_preserved': True}]
        # Metadata labels exercise helper branches; payload is deliberately not
        # an image, and no image parsing or generation takes place in these tests.
        self.expected = {'Image/opaque': {field: self.rows[0][field] for field in
                         ('encrypted_bytes', 'plain_bytes', 'sha256', 'format', 'width', 'height', 'mode', 'png_chunk_count')}}
        self.summary = {'container': 'Client/Data/opaque.dat', 'sha256': self.identity['sha256'], 'encrypted': True,
                        'verified_images': 1, 'identity_basis': copy.deepcopy(self.identity),
                        'validation_context': d.validation_context(self.parameters, self.expected),
                        'extraction_decoder_sha256': d.sha256(b'opaque code-version marker')}
        self.refresh_records()
        output = self.root / self.rows[0]['relative_output_path']
        output.parent.mkdir(parents=True)
        output.write_bytes(self.payload)

    def refresh_records(self):
        self.records_bytes = b''.join(json.dumps(row, sort_keys=True).encode() + b'\n' for row in self.rows)
        self.summary['records_sha256'] = d.sha256(self.records_bytes)

    def validate(self):
        return d.validate_resume(self.summary, self.rows, self.records_bytes, self.original,
                                 self.identity, self.parameters, self.expected, self.root)

    def test_valid_opaque_resume_contract(self):
        self.validate()

    def test_plain_mode_resume_does_not_claim_padding(self):
        self.summary['encrypted'] = False
        self.rows[0]['pkcs7_padding_verified'] = False
        self.refresh_records()
        self.validate()

    def test_wrong_or_missing_encryption_mode_proof_rejected(self):
        for mode in (False, None, 'encrypted'):
            with self.subTest(mode=mode):
                self.summary['encrypted'] = mode
                with self.assertRaises(d.ValidationError):
                    self.validate()

    def test_parameter_mutation_rejected(self):
        self.parameters['test_only'] = 'changed'
        with self.assertRaises(d.ValidationError):
            self.validate()

    def test_catalog_mutation_invalidates_context(self):
        self.expected['Image/opaque']['width'] += 1
        with self.assertRaises(d.ValidationError):
            self.validate()

    def test_validation_contract_mutation_rejected(self):
        self.summary['validation_context']['validation_contract'] = 'unreviewed-contract'
        with self.assertRaises(d.ValidationError):
            self.validate()

    def test_missing_or_malformed_extraction_identity_rejected(self):
        for value in (None, '', 'abc', 'A' * 64):
            with self.subTest(value=value):
                if value is None:
                    self.summary.pop('extraction_decoder_sha256', None)
                else:
                    self.summary['extraction_decoder_sha256'] = value
                with self.assertRaises(d.ValidationError):
                    self.validate()

    def test_expected_identity_mutation_rejected(self):
        self.summary['identity_basis']['bytes'] += 1
        with self.assertRaises(d.ValidationError):
            self.validate()

    def test_raw_record_file_mutation_rejected(self):
        self.records_bytes += b' '
        with self.assertRaises(d.ValidationError):
            self.validate()

    def test_original_bytes_mutation_rejected(self):
        self.original += b'changed'
        with self.assertRaises(d.ValidationError):
            self.validate()

    def test_record_count_mutation_rejected(self):
        self.summary['verified_images'] = 2
        with self.assertRaises(d.ValidationError):
            self.validate()

    def test_member_set_revalidated_with_refreshed_context(self):
        self.expected['Image/second'] = copy.deepcopy(self.expected['Image/opaque'])
        self.summary['validation_context'] = d.validation_context(self.parameters, self.expected)
        with self.assertRaises(d.ValidationError):
            self.validate()

    def test_duplicate_rows_rejected_with_refreshed_records_hash(self):
        self.rows.append(copy.deepcopy(self.rows[0]))
        self.summary['verified_images'] = 2
        self.refresh_records()
        with self.assertRaises(d.ValidationError):
            self.validate()

    def test_casefold_duplicate_rows_rejected_without_retained_catalog(self):
        self.expected = None
        self.summary['validation_context'] = d.validation_context(self.parameters, self.expected)
        duplicate = copy.deepcopy(self.rows[0])
        duplicate['path'] = 'Image/OPAQUE'
        duplicate['relative_output_path'] = 'decoded/Image/OPAQUE'
        self.rows.append(duplicate)
        self.summary['verified_images'] = 2
        self.refresh_records()
        with self.assertRaises(d.ValidationError):
            self.validate()

    def test_unsafe_member_path_rejected(self):
        self.expected = None
        self.summary['validation_context'] = d.validation_context(self.parameters, self.expected)
        self.rows[0]['path'] = 'Image/../opaque'
        self.refresh_records()
        with self.assertRaises(d.ValidationError):
            self.validate()

    def test_output_path_must_match_exact_member_path(self):
        self.rows[0]['relative_output_path'] = '../opaque'
        self.refresh_records()
        with self.assertRaises(d.ValidationError):
            self.validate()

    def test_member_container_identity_rejected(self):
        for field, value in (('container', 'Client/Data/other.dat'), ('original_container_sha256', '0' * 64)):
            with self.subTest(field=field):
                before = self.rows[0][field]
                self.rows[0][field] = value
                self.refresh_records()
                with self.assertRaises(d.ValidationError):
                    self.validate()
                self.rows[0][field] = before

    def test_missing_strict_proofs_rejected(self):
        for field in ('pkcs7_padding_verified', 'pillow_verify_and_load', 'original_bytes_preserved', 'png_all_chunk_crc_verified'):
            with self.subTest(field=field):
                self.rows[0][field] = False
                self.refresh_records()
                with self.assertRaises(d.ValidationError):
                    self.validate()
                self.rows[0][field] = True

    def test_retained_fields_revalidated_even_with_updated_record_hash(self):
        for field in ('encrypted_bytes', 'plain_bytes', 'sha256', 'format', 'width', 'height', 'mode', 'png_chunk_count'):
            with self.subTest(field=field):
                before = self.rows[0][field]
                self.rows[0][field] = before + 1 if isinstance(before, int) else before + '-changed'
                self.refresh_records()
                with self.assertRaises(d.ValidationError):
                    self.validate()
                self.rows[0][field] = before

    def test_altered_output_rejected(self):
        (self.root / self.rows[0]['relative_output_path']).write_bytes(b'changed opaque output')
        with self.assertRaises(d.ValidationError):
            self.validate()

    def test_missing_output_rejected(self):
        (self.root / self.rows[0]['relative_output_path']).unlink()
        with self.assertRaises(d.ValidationError):
            self.validate()

    def test_symlink_output_rejected_even_when_bytes_match(self):
        path = self.root / self.rows[0]['relative_output_path']
        path.unlink()
        opaque_target = self.root / 'opaque-target'
        opaque_target.write_bytes(self.payload)
        path.symlink_to(opaque_target)
        with self.assertRaises(d.ValidationError):
            self.validate()


class PngFramingTests(unittest.TestCase):
    def test_bad_signature_rejected(self):
        with self.assertRaises(d.ValidationError):
            d.png_verify(b'opaque')

    def test_truncated_header_or_crc_rejected(self):
        for suffix in (b'', b'abc', b'abcdefghijk', chunk(b'IHDR', bytes(13))[:-1]):
            with self.subTest(length=len(suffix)), self.assertRaises(d.ValidationError):
                d.png_verify(SIGNATURE + suffix)

    def test_chunk_length_overrun_rejected(self):
        for n in (1, 0x7fffffff, 0x80000000, 0xffffffff):
            with self.subTest(n=n), self.assertRaises(d.ValidationError):
                d.png_verify(SIGNATURE + struct.pack('>I', n) + b'IHDR' + bytes(4))

    def test_bad_chunk_type_or_reserved_bit_rejected(self):
        for kind in (b'IH0R', b'IHdR'):
            with self.subTest(kind=kind), self.assertRaises(d.ValidationError):
                d.png_verify(SIGNATURE + chunk(kind, bytes(13)))

    def test_bad_crc_rejected(self):
        bad = bytearray(INVALID_IHDR)
        bad[-1] ^= 1
        with self.assertRaises(d.ValidationError):
            d.png_verify(SIGNATURE + bad)

    def test_missing_or_duplicate_ihdr_rejected(self):
        for body in (EMPTY_IDAT + IEND, INVALID_IHDR + INVALID_IHDR + EMPTY_IDAT + IEND):
            with self.subTest(length=len(body)), self.assertRaises(d.ValidationError):
                d.png_verify(SIGNATURE + body)

    def test_missing_idat_or_iend_rejected(self):
        for body in (INVALID_IHDR + IEND, INVALID_IHDR + EMPTY_IDAT):
            with self.subTest(length=len(body)), self.assertRaises(d.ValidationError):
                d.png_verify(SIGNATURE + body)

    def test_nonempty_iend_rejected(self):
        with self.assertRaises(d.ValidationError):
            d.png_verify(SIGNATURE + INVALID_IHDR + EMPTY_IDAT + chunk(b'IEND', b'opaque'))

    def test_trailing_bytes_and_second_iend_rejected(self):
        for suffix in (b'opaque', IEND):
            with self.subTest(length=len(suffix)), self.assertRaises(d.ValidationError):
                d.png_verify(SIGNATURE + INVALID_IHDR + EMPTY_IDAT + IEND + suffix)


if __name__ == '__main__':
    unittest.main()
