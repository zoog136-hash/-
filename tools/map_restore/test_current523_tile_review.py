#!/usr/bin/env python3
"""Synthetic candidate TI2 tests. Original-byte/733696-frame QA is builder CLI."""

import copy
import ctypes
import ctypes.util
from pathlib import Path
import struct
import tempfile
import unittest
from unittest import mock

import numpy as np
from PIL import Image

import base508_ti2 as reference
import current523_tile_review as review


def decoded_fixture(blocks=None, palette=(0, 0xffff, 0xf800, 0x07e0), extra_header=0):
    if blocks is None:
        blocks = [{"flags": 0, "offset": (0, 0), "runs": (), "pixels": b""} for _ in range(256)]
        blocks[0] = {"flags": 0xb4, "offset": (1, 2), "runs": (2 << 5, 1 | (1 << 5) | (1 << 10)), "pixels": bytes([0, 1, 2])}
        blocks[1] = {"flags": 65, "offset": (0, 0), "runs": (), "pixels": bytes([3]) * 288}
    out = bytearray(struct.pack("<I", 4096 | len(blocks) | extra_header))
    out += bytes([len(palette) % 256]) + struct.pack("<" + "H" * len(palette), *palette)
    out += bytes(block["flags"] for block in blocks)
    for block in blocks:
        if not block["flags"] & 64:
            out += struct.pack("<BBB", *block["offset"], len(block["runs"]))
            out += struct.pack("<" + "H" * len(block["runs"]), *block["runs"])
    return bytes(out) + b"".join(block["pixels"] for block in blocks)


def compress(raw):
    name = ctypes.util.find_library("brotlienc")
    if not name:
        raise unittest.SkipTest("Standard libbrotlienc required for synthetic compressed streams")
    lib = ctypes.CDLL(name)
    lib.BrotliEncoderMaxCompressedSize.argtypes = [ctypes.c_size_t]
    lib.BrotliEncoderMaxCompressedSize.restype = ctypes.c_size_t
    lib.BrotliEncoderCompress.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_size_t,
                                        ctypes.c_void_p, ctypes.POINTER(ctypes.c_size_t), ctypes.c_void_p]
    lib.BrotliEncoderCompress.restype = ctypes.c_int
    output = ctypes.create_string_buffer(lib.BrotliEncoderMaxCompressedSize(len(raw)))
    size = ctypes.c_size_t(len(output))
    if lib.BrotliEncoderCompress(5, 22, 0, len(raw), raw, ctypes.byref(size), output) != 1:
        raise RuntimeError("Synthetic Brotli compression failed")
    return output.raw[:size.value]


class TileReviewTests(unittest.TestCase):
    def setUp(self):
        self.raw = decoded_fixture(extra_header=0x80000000)
        self.row = review.parse_ti2(self.raw)

    def test_exact_raw_two_pass_roundtrip_and_unsigned_fields(self):
        self.assertEqual(review.write_ti2(self.row), self.raw)
        self.assertEqual(self.row["header"], 0x80001100)
        self.assertEqual(self.row["blocks"][0]["flags"], 0xb4)
        self.assertEqual(struct.unpack("<4H", self.row["palette_u16le"]), (0, 65535, 63488, 2016))
        sections = self.row["sections"]
        cursor = 0
        for name in ("header", "palette", "flags", "descriptors", "indices"):
            section = sections[name]
            self.assertEqual(section["offset"], cursor)
            cursor += section["bytes"]
            self.assertEqual(section["sha256"], review.sha256(self.raw[section["offset"]:cursor]))
        self.assertEqual(cursor, len(self.raw))
        self.assertGreaterEqual(self.row["blocks"][0]["pixels_offset"], sections["indices"]["offset"])

    def test_unknown_raw_span_high_bit_is_preserved(self):
        blocks = [{"flags": 0x80, "offset": (0, 0), "runs": (0x8420,), "pixels": b"\x02"}]
        raw = decoded_fixture(blocks)
        row = review.parse_ti2(raw)
        self.assertEqual(row["blocks"][0]["raw_runs"], (0x8420,))
        self.assertEqual(review.write_ti2(row), raw)
        np.testing.assert_array_equal(review.block_positions(row["blocks"][0]), [0])

    def test_palette_zero_count_means256(self):
        raw = decoded_fixture(palette=tuple(range(256)))
        row = review.parse_ti2(raw)
        self.assertEqual(raw[4], 0)
        self.assertEqual(len(row["palette_u16le"]), 512)
        self.assertEqual(review.write_ti2(row), raw)
        with self.assertRaises(ValueError):
            review.parse_ti2(raw[:4 + 1 + 511])

    def test_palette_truncations_and_invalid_indices(self):
        sections = self.row["sections"]
        for cut in (0, 3, 4, sections["flags"]["offset"] - 1, sections["descriptors"]["offset"] - 1,
                    sections["descriptors"]["offset"] + 2, sections["indices"]["offset"] - 1, len(self.raw) - 1):
            with self.subTest(cut=cut), self.assertRaises(ValueError):
                review.parse_ti2(self.raw[:cut])
        blocks = [{"flags": 0, "offset": (0, 0), "runs": (1 << 5,), "pixels": b"\x01"}]
        with self.assertRaisesRegex(ValueError, "index outside"):
            review.parse_ti2(decoded_fixture(blocks, palette=(0,)))
        without_palette = struct.pack("<I", 1) + b"\x00\x00\x00\x01" + struct.pack("<H", 1 << 5) + b"\x00"
        with self.assertRaisesRegex(ValueError, "index outside"):
            review.parse_ti2(without_palette)

    def test_decoded_tail_and_implicit_payload_truncation_reject(self):
        with self.assertRaisesRegex(ValueError, "Unconsumed"):
            review.parse_ti2(self.raw + b"extra")
        blocks = [{"flags": 64, "offset": (0, 0), "runs": (), "pixels": bytes(287)}]
        with self.assertRaisesRegex(ValueError, "Truncated"):
            review.parse_ti2(decoded_fixture(blocks))
        with self.assertRaises(ValueError):
            review.parse_ti2(bytes(review.MAX_BYTES + 1))

    def test_brotli_full_consumption_truncation_and_output_cap(self):
        compressed = compress(self.raw)
        self.assertEqual(review.strict_decompress(compressed), self.raw)
        self.assertEqual(review.strict_decompress(compressed, len(self.raw)), self.raw)
        for bad in (compressed[:-1], compressed + b"\x00", compressed + compress(b"another stream"), b"invalid"):
            with self.subTest(size=len(bad)), self.assertRaises(ValueError):
                review.strict_decompress(bad)
        for limit in (len(self.raw) - 1, 0, True, review.MAX_BYTES + 1):
            with self.subTest(limit=limit), self.assertRaises(ValueError):
                review.strict_decompress(compressed, limit)

    def test_coverage_alpha_keeps_black_and_ignores_viewer_flags(self):
        atlas = review.render_atlas(self.row)
        self.assertEqual(atlas.shape, (384, 384, 4))
        self.assertEqual(tuple(atlas[2, 1]), (0, 0, 0, 255))
        self.assertEqual(tuple(atlas[2, 2]), (255, 255, 255, 255))
        self.assertEqual(tuple(atlas[2, 4]), (255, 0, 0, 255))
        self.assertEqual(tuple(atlas[3, 1]), (0, 0, 0, 0))
        self.assertEqual(tuple(atlas[0, 24]), (0, 255, 0, 255))
        self.assertEqual(int(np.count_nonzero(atlas[:, :, 3])), 291)

    def test_vectorized_coverage_matches_separate_reference(self):
        atlas = review.render_atlas(self.row)
        expected = reference.parse(self.raw)
        for index in (0, 1, 2, 255):
            frame = atlas[(index // 16)*24:(index // 16+1)*24, (index % 16)*24:(index % 16+1)*24]
            self.assertEqual(frame.tobytes(), reference.render(expected["blocks"][index], expected["palette"], display_alpha=False).tobytes())

    def test_canvas_outside_and_duplicate_writes_reject(self):
        for offset, runs in (((23, 0), (2 << 5,)), ((0, 24), (1 << 5,)),
                             ((0, 0), ((1 << 5) | (31 << 10), 1 << 5))):
            block = {"flags": 0, "offset": offset, "raw_runs": runs, "pixels": bytes(sum((word >> 5) & 31 for word in runs))}
            with self.subTest(offset=offset), self.assertRaisesRegex(ValueError, "outside24|outside 24"):
                review.block_positions(block)
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            review._validate_positions(np.array([0, 0], dtype=np.int32))
        for positions in ([-1], [576]):
            with self.assertRaisesRegex(ValueError, "outside 24"):
                review._validate_positions(np.array(positions))
        with self.assertRaisesRegex(ValueError, "all256"):
            review.render_atlas(review.parse_ti2(decoded_fixture([])))

    def test_png_byte_hash_decoded_hash_and_dimensions(self):
        atlas = review.render_atlas(self.row)
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "coverage.png"
            Image.fromarray(atlas).save(path, format="PNG", compress_level=4)
            png_digest, rgba_digest = review.verify_atlas_png(path)
            self.assertEqual(png_digest, review.sha256(path.read_bytes()))
            self.assertEqual(rgba_digest, review.sha256(atlas.tobytes()))
            self.assertEqual(review.verify_atlas_png(path, png_digest, rgba_digest), (png_digest, rgba_digest))
            with self.assertRaisesRegex(ValueError, "RGBA hash"):
                review.verify_atlas_png(path, png_digest, "0" * 64)
            raw = path.read_bytes(); path.write_bytes(raw[:-1] + bytes([raw[-1] ^ 1]))
            with self.assertRaisesRegex(ValueError, "byte hash"):
                review.verify_atlas_png(path, png_digest, rgba_digest)
            Image.new("RGBA", (24, 24)).save(path)
            with self.assertRaisesRegex(ValueError, "RGBA384"):
                review.verify_atlas_png(path)
            Image.fromarray(atlas).save(path)
            oversized = bytearray(path.read_bytes())
            struct.pack_into(">II", oversized, 16, 65535, 65535)
            path.write_bytes(oversized)
            with mock.patch.object(review.Image, "open", side_effect=AssertionError("decoder must not run")):
                with self.assertRaisesRegex(ValueError, "before decoding"):
                    review.verify_atlas_png(path)

    def test_literal_members_and_trusted_records(self):
        self.assertEqual(review.member_id("Tile/0.ti2"), 0)
        self.assertEqual(review.member_id("Tile/16777215.ti2"), 16777215)
        for member in ("../Tile/1.ti2", "/Tile/1.ti2", "Tile/../1.ti2", "Tile/01.ti2", "Tile/1.ti2/x", "Tile/16777216.ti2", "Tile/1.ti2\x00"):
            with self.subTest(member=member), self.assertRaises(ValueError):
                review.member_id(member)
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "not-current.json"
            path.write_text("[]")
            with self.assertRaisesRegex(ValueError, "pinned evidence"):
                review.load_source_records(path)

    def test_writer_rejects_changed_unsigned_raw_fields(self):
        changed = copy.deepcopy(self.row)
        changed["blocks"][0]["raw_runs"] = (65536,)
        with self.assertRaises(ValueError):
            review.write_ti2(changed)
        changed = copy.deepcopy(self.row)
        changed["palette_u16le"] = changed["palette_u16le"][:-1]
        with self.assertRaises(ValueError):
            review.write_ti2(changed)

    def test_identity_and_interpretation_boundary(self):
        for key, value in (("schema", True), ("edition", "PC"), ("cumulative_version", 508)):
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, "identity mismatch"):
                review.validate_manifest({key: value})
        self.assertEqual(review.SEMANTICS["runtime_alpha"], "UNKNOWN")
        self.assertEqual(review.STATUS, "DISPLAY_HYPOTHESIS_COVERAGE_V1")

    def test_raw_evidence_metadata_is_validated_and_pinned(self):
        decoded = decoded_fixture()
        row = review.parse_ti2(decoded)
        atlas = review.render_atlas(row)
        base = {"source_bytes": 123, "source_sha256": "1" * 64, "decoded_bytes": len(decoded),
                "decoded_sha256": review.sha256(decoded), "atlas_bytes": 123, "atlas_sha256": "2" * 64,
                "atlas_rgba_sha256": review.sha256(atlas.tobytes()), "blocks": 256, "atlas_size": [384, 384],
                "stored_pixels": 291, "raw_header_u32": 4352, "palette_colors": 4,
                "palette_u16le_sha256": review.sha256(row["palette_u16le"]), "raw_sections": row["sections"],
                "raw_decoded_roundtrip": True}
        tiles = [{**base, "tile_id": index, "member": f"Tile/{index}.ti2",
                  "original_path": f"originals/Tile/{index}.ti2", "atlas_path": f"atlases/{index}.png"}
                 for index in range(review.SOURCE_COUNT)]
        source_pin, rgba_pin, raw_pin = review.source_inventory(tiles), review.rgba_inventory(tiles), review.raw_model_inventory(tiles)
        manifest = {"schema": 1, "edition": "LineageM", "cumulative_version": 523, "land_id": 4,
                    "asset_path": "Aden/", "source_root": "Tile/", "source_count": review.SOURCE_COUNT,
                    "status": review.STATUS, "delivery_status": "PRIVATE_LOCAL_ONLY", "semantics": dict(review.SEMANTICS),
                    "source_records_sha256": review.SOURCE_RECORDS_SHA256, "source_inventory_sha256": source_pin,
                    "atlas_rgba_inventory_sha256": rgba_pin, "raw_model_inventory_sha256": raw_pin,
                    "raw_decoded_roundtrip": True, "stored_pixels": 291 * review.SOURCE_COUNT, "tiles": tiles}
        # Isolate schema/metadata rejection using a valid synthetic pinned inventory.
        with mock.patch.multiple(review, SOURCE_INVENTORY_SHA256=source_pin,
                                 ATLAS_RGBA_INVENTORY_SHA256=rgba_pin, RAW_MODEL_INVENTORY_SHA256=raw_pin):
            review.validate_manifest(manifest)
            for key, value in (("raw_sections", "wrong"), ("stored_pixels", -1), ("raw_decoded_roundtrip", False),
                               ("decoded_sha256", "0" * 64), ("palette_u16le_sha256", "0" * 64)):
                changed = {**manifest, "tiles": tiles.copy()}
                changed["tiles"][0] = {**tiles[0], key: value}
                with self.subTest(key=key), self.assertRaises(ValueError):
                    review.validate_manifest(changed)
            changed = {**manifest, "tiles": tiles.copy()}
            changed["tiles"][0] = copy.deepcopy(tiles[0])
            changed["tiles"][0]["raw_sections"]["flags"]["sha256"] = "0" * 64
            with self.assertRaisesRegex(ValueError, "raw TI2 evidence inventory"):
                review.validate_manifest(changed)


if __name__ == "__main__":
    unittest.main()
