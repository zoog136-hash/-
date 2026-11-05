#!/usr/bin/env python3
"""Raw-codec security/roundtrip tests; no copied original fixtures are stored.

Run synthetic tests:
  python3 tools/map_restore/test_current523_s32.py

Also verify all677 real originals and build/verify a temporary private pack:
  python3 tools/map_restore/test_current523_s32.py \
    --source-dir /private/selected_originals \
    --summary /private/all_Aden_map_structure_summary.json \
    --land-declaration /private/M_only_Land4_assetpath_and_explicit_zone_declarations.json
"""

import argparse
import copy
import json
import os
from pathlib import Path
import struct
import tempfile
import unittest
from unittest import mock

import current523_s32 as codec
import build_current523_aden_pack as builder

REAL = None
MEMBER = "Map/Aden/synthetic_raw.s32"


def synthetic(tail=b"\x00\xffopaque\x80\x00"):
    # High-bit packed references must survive as unsigned raw values.
    floor = struct.pack("<II", 0xffffffff, 0x800000ff) + bytes(codec.FLOOR_BYTES - 8)
    attributes = struct.pack("<HH", 0xffff, 0x8000) + bytes(codec.ATTRIBUTE_BYTES - 4)
    covers = struct.pack("<HBBI", 1, 255, 254, 0xffffffff)
    objects = struct.pack("<IHHBBBI", 1, 65535, 1, 255, 254, 253, 0x800000ff)
    opacity = struct.pack("<I", 1) + b"\xff\xff\x01\x80\xff"
    declared = struct.pack("<III", 2, 0xffffffff, 0x800000)
    return floor + covers + attributes + objects + opacity + declared + tail


def minimal():
    return bytes(codec.FLOOR_BYTES) + struct.pack("<H", 0) + bytes(codec.ATTRIBUTE_BYTES) + struct.pack("<III", 0, 0, 0)


class RawCodecTests(unittest.TestCase):
    def setUp(self):
        self.data = synthetic()
        self.row = codec.read_s32(self.data, MEMBER)

    def test_exact_unsigned_roundtrip_and_raw_offsets(self):
        self.assertEqual(codec.write_s32(self.row), self.data)
        self.assertEqual(struct.unpack_from("<II", self.row["floor_u32le"]), (0xffffffff, 0x800000ff))
        self.assertEqual(self.row["covers"], [(255, 254, 0xffffffff)])
        group = self.row["objects"][0]
        self.assertEqual(group["parts"], [(255, 254, 253, 0x800000ff)])
        self.assertEqual(self.data[group["offset"]:group["parts_offset"]], struct.pack("<HH", 65535, 1))
        self.assertEqual(self.row["declared_tile_ids"], [0xffffffff, 0x800000])
        end = 0
        for name in codec.SECTION_NAMES:
            section = self.row["sections"][name]
            self.assertEqual(section["offset"], end)
            end += section["bytes"]
            self.assertEqual(codec.sha256(self.data[section["offset"]:end]), section["sha256"])
        self.assertEqual(end, len(self.data))
        self.assertEqual(self.row["semantics"], codec.SEMANTICS)
        self.assertFalse(any("origin" in key or "coordinate" in key for key in self.row if key != "semantics"))

    def test_minimal_and_uninterpreted_tail(self):
        for data in (minimal(), synthetic(b""), synthetic(b"\xff\xffnot-a-tail-model\x00")):
            with self.subTest(size=len(data)):
                row = codec.read_s32(data, MEMBER)
                self.assertEqual(codec.write_s32(row), data)
                self.assertEqual(row["uninterpreted_tail"], data[row["core_end"]:])

    def test_truncation_at_each_core_record(self):
        sections = self.row["sections"]
        cuts = {0, 32767, 32768, 32769, sections["attributes"]["offset"] - 1,
                sections["attributes"]["offset"] + codec.ATTRIBUTE_BYTES - 1,
                sections["objects"]["records_offset"] - 1,
                self.row["objects"][0]["parts_offset"] - 1,
                sections["opacity"]["offset"] - 1, sections["opacity"]["records_offset"] - 1,
                sections["declared"]["offset"] - 1, sections["declared"]["records_offset"] - 1,
                self.row["core_end"] - 1}
        for cut in cuts:
            with self.subTest(cut=cut), self.assertRaises(ValueError):
                codec.read_s32(self.data[:cut], MEMBER)

    def test_counts_checked_against_remaining_bytes_before_records(self):
        for name, fmt, value in (("covers", "H", 65535), ("objects", "I", 0xffffffff),
                                  ("opacity", "I", 0xffffffff), ("declared", "I", 0xffffffff)):
            corrupt = bytearray(self.data)
            struct.pack_into("<" + fmt, corrupt, self.row["sections"][name]["offset"], value)
            with self.subTest(section=name), self.assertRaises(ValueError):
                codec.read_s32(corrupt, MEMBER)
        corrupt = bytearray(self.data)
        struct.pack_into("<H", corrupt, self.row["objects"][0]["offset"] + 2, 65535)
        with self.assertRaises(ValueError):
            codec.read_s32(corrupt, MEMBER)

    def test_aggregate_part_limit(self):
        # Each group is individually bounded; the aggregate must also be bounded.
        group = struct.pack("<HH", 1, 65535) + bytes(7 * 65535)
        raw = minimal()[:-12] + struct.pack("<I", 5) + group * 5 + struct.pack("<II", 0, 0)
        with self.assertRaisesRegex(ValueError, "object part count"):
            codec.read_s32(raw, MEMBER)

    def test_source_and_tail_size_limits(self):
        for data in (bytes(codec.MIN_BYTES - 1), bytes(codec.MAX_BYTES + 1),
                     minimal() + bytes(codec.MAX_TAIL_BYTES + 1)):
            with self.subTest(size=len(data)), self.assertRaises(ValueError):
                codec.read_s32(data, MEMBER)

    def test_version_edition_and_unsafe_literal_names(self):
        for edition, version in (("LineagePC", 523), ("LineageM", 508), ("LineageM", True), ("LineageM", "523")):
            with self.subTest(edition=edition, version=version), self.assertRaises(ValueError):
                codec.read_s32(self.data, MEMBER, edition=edition, cumulative_version=version)
        for member in ("../x.s32", "/Map/Aden/x.s32", "Map/Aden/../x.s32", "Map/Aden/x/y.s32",
                       "Map/Aden/..s32", "Map\\Aden\\x.s32", "Map/13225/x.s32", "Map/Aden/%2e.s32",
                       "Map/Aden/x.s32\x00", "Map/Aden/x.S32"):
            with self.subTest(member=member), self.assertRaises(ValueError):
                codec.validate_member_path(member)
        self.assertEqual(codec.validate_member_path("Map/Aden/800f7ff3e.s32"), "Map/Aden/800f7ff3e.s32")

    def test_writer_rejects_corrupt_fields_and_metadata(self):
        cases = []
        row = copy.deepcopy(self.row); row["opacity_raw"] += b"x"; cases.append(row)
        row = copy.deepcopy(self.row); row["covers"] = [(1, 2, -1)]; cases.append(row)
        row = copy.deepcopy(self.row); row["objects"][0]["parts"] = [(0, 0, 0, 0x100000000)]; cases.append(row)
        row = copy.deepcopy(self.row); row["floor_u32le"] = row["floor_u32le"][:-1]; cases.append(row)
        row = copy.deepcopy(self.row); row["source_sha256"] = "0" * 64; cases.append(row)
        row = copy.deepcopy(self.row); row["objects"][0]["offset"] += 1; cases.append(row)
        row = copy.deepcopy(self.row); row["semantics"]["movement"] = "walkable"; cases.append(row)
        for index, row in enumerate(cases):
            with self.subTest(case=index), self.assertRaises(ValueError):
                codec.write_s32(row)

    def test_manifest_sections_validate_offsets_counts_and_hashes(self):
        row = builder.member_metadata(self.row, {})
        codec._validate_sections(row)
        for section, field, value in (("floor", "bytes", codec.FLOOR_BYTES - 1), ("covers", "offset", 1),
                                       ("covers", "count", 2), ("attributes", "sha256", "bad"),
                                       ("objects", "part_count", 0), ("opacity", "records_offset", -1),
                                       ("declared", "count", True), ("tail", "bytes", codec.MAX_TAIL_BYTES + 1)):
            corrupt = copy.deepcopy(row)
            corrupt["sections"][section][field] = value
            with self.subTest(section=section, field=field), self.assertRaises(ValueError):
                codec._validate_sections(corrupt)

    def test_manifest_rejects_unexpected_counts_in_uncounted_sections(self):
        members = []
        for index in range(codec.SOURCE_COUNT):
            row = builder.member_metadata(self.row, {})
            row["member"] = row["source_path"] = f"Map/Aden/{index:08x}.s32"
            row["path"] = "originals/" + row["member"]
            members.append(row)
        digest = codec.inventory_sha256(members)
        manifest = {"schema": 1, "edition": "LineageM", "cumulative_version": 523, "land_id": 4,
                    "asset_path": "Aden/", "source_root": "Map/Aden/", "source_count": 677,
                    "source_inventory_sha256": digest, "semantics": dict(codec.SEMANTICS),
                    "land_declaration": {"ID": 4, "AssetPath": "Aden/"}, "delivery_status": "PRIVATE_LOCAL_ONLY",
                    "members": members}
        # Substitute only the inventory pin for this synthetic valid manifest;
        # the production pin and all section validation remain independently tested.
        with mock.patch.object(codec, "SOURCE_INVENTORY_SHA256", digest):
            codec.validate_manifest(manifest)
            for section in ("floor", "attributes", "tail"):
                for value in ([], {}):
                    corrupt = {**manifest, "members": members.copy()}
                    corrupt["members"][0] = copy.deepcopy(members[0])
                    corrupt["members"][0]["sections"][section]["count"] = value
                    with self.subTest(section=section, value=value), self.assertRaisesRegex(ValueError, "Unexpected count"):
                        codec.validate_manifest(corrupt)

    def test_inventory_is_format_independent_but_duplicate_safe(self):
        rows = [{"member": MEMBER, "bytes": len(self.data), "sha256": codec.sha256(self.data)},
                {"member": "Map/Aden/800f7ff3e.s32", "bytes": len(self.data), "sha256": codec.sha256(self.data)}]
        self.assertEqual(codec.inventory_sha256(rows), codec.inventory_sha256(rows[::-1]))
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            codec.inventory_sha256(rows + rows[:1])
        stale = [{"member": codec.CURRENT_ANCHOR, "source_bytes": 182625,
                  "source_sha256": "3fc1b2ddef0e2de4d1f2000aed2b79b9941f13bd7a242ce1c1ef703eee02fa00"}] * 677
        with self.assertRaises(ValueError):
            builder._summary_rows(stale)

    def test_manifest_rejects_identity_and_noncurrent_inventory(self):
        manifest = {"schema": 1, "edition": "LineageM", "cumulative_version": 523, "land_id": 4,
                    "asset_path": "Aden/", "source_root": "Map/Aden/", "source_count": 677,
                    "source_inventory_sha256": codec.SOURCE_INVENTORY_SHA256, "semantics": dict(codec.SEMANTICS),
                    "land_declaration": {"ID": 4, "AssetPath": "Aden/"}, "delivery_status": "PRIVATE_LOCAL_ONLY",
                    "members": []}
        for key, value in (("schema", True), ("edition", "PC"), ("cumulative_version", 508),
                           ("land_id", 45194), ("asset_path", "13225/"), ("source_count", 676),
                           ("land_declaration", {"ID": 45194, "AssetPath": "13225/"}),
                           ("delivery_status", "PUBLIC_COMPLETE"),
                           ("semantics", {**codec.SEMANTICS, "projection": "isometric"})):
            corrupt = {**manifest, key: value}
            with self.subTest(key=key), self.assertRaises(ValueError):
                codec.validate_manifest(corrupt)
        manifest["members"] = [builder.member_metadata(self.row, {})] * 677
        with self.assertRaises(ValueError):
            codec.validate_manifest(manifest)
        for key, value, message in (("land_declaration", {"ID": 45194, "AssetPath": "13225/"}, "direct Land4"),
                                    ("delivery_status", "PUBLIC_COMPLETE", "private local")):
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, message):
                codec.validate_manifest({**manifest, key: value})


class PrivateBuilderTests(unittest.TestCase):
    def test_direct_land4_declaration_only(self):
        self.assertEqual(builder._land({"Land4_raw": {"ID": 4, "AssetPath": "Aden/"}, "source_asset_root": "Map/Aden/"}),
                         {"ID": 4, "AssetPath": "Aden/"})
        for row in ({"ID": 45194, "AssetPath": "13225/"}, {"ID": 4, "AssetPath": "Aden"},
                    {"ID": True, "AssetPath": "Aden/"}, {"ID": 4, "AssetPath": "../Aden/"}):
            with self.subTest(row=row), self.assertRaises(ValueError):
                builder._land(row)

    def test_exact_inventory_rejects_missing_extra_nested_and_symlink(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            aden = root / "Map/Aden"
            aden.mkdir(parents=True)
            path = aden / "synthetic_raw.s32"
            path.write_bytes(minimal())
            builder._inventory(root, {MEMBER: {}})
            with self.assertRaises(ValueError):
                builder._inventory(root, {})
            with self.assertRaises(ValueError):
                builder._inventory(root, {MEMBER: {}, "Map/Aden/missing.s32": {}})
            extra = aden / "nested"
            extra.mkdir()
            with self.assertRaises(ValueError):
                builder._inventory(root, {MEMBER: {}})
            extra.rmdir()
            alias = aden / "linked.s32"
            alias.symlink_to(path)
            with self.assertRaises(ValueError):
                builder._inventory(root, {MEMBER: {}})
            with self.assertRaises(ValueError):
                builder._regular_child(root, "Map/Aden/linked.s32")
            with self.assertRaises(ValueError):
                builder._regular_child(root, "Map/Aden/../Aden/synthetic_raw.s32")

    def test_output_cannot_enter_git_or_replace_existing(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            repository = root / "checkout"
            repository.mkdir()
            (repository / ".git").write_text("gitdir: elsewhere\n")
            for output in (source / "pack", repository / "pack", source):
                with self.subTest(output=output), self.assertRaises(ValueError):
                    builder._output_path(output, source)
            self.assertEqual(builder._output_path(root / "private-pack", source), root / "private-pack")

    def test_atomic_publishing_does_not_replace_existing_directory(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            stage, destination = root / "stage", root / "published"
            stage.mkdir(); destination.mkdir()
            (stage / "raw").write_bytes(b"staged")
            with self.assertRaises(FileExistsError):
                builder._publish_directory(stage, destination)
            self.assertEqual((stage / "raw").read_bytes(), b"staged")
            self.assertEqual(list(destination.iterdir()), [])
            destination.rmdir()
            builder._publish_directory(stage, destination)
            self.assertFalse(stage.exists())
            self.assertEqual((destination / "raw").read_bytes(), b"staged")

    def test_duplicate_and_oversized_json(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "metadata.json"
            path.write_text('{"schema":1,"schema":523}')
            with self.assertRaisesRegex(ValueError, "Duplicate JSON key"):
                builder._json(path)
            with path.open("wb") as handle:
                handle.truncate(builder.MAX_METADATA_BYTES + 1)
            with self.assertRaises(ValueError):
                builder._json(path)

    @unittest.skipUnless(hasattr(os, "mkfifo"), "FIFO is unavailable on this platform")
    def test_pack_inventory_rejects_special_entries(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / codec.MANIFEST_NAME).write_text('{"members":[]}')
            os.mkfifo(root / "extra-fifo")
            with mock.patch.object(codec, "validate_manifest"), self.assertRaisesRegex(ValueError, "Nonregular"):
                builder.validate_pack(root)


@unittest.skipUnless(REAL, "Pass --source-dir, --summary and --land-declaration for all677 original verification")
class RealSourceTests(unittest.TestCase):
    def test_all677_current_originals_and_private_builder(self):
        summary, _ = builder._json(REAL.summary)
        evidence = builder._summary_rows(summary)
        self.assertEqual(len(evidence), 677)
        self.assertIn("Map/Aden/800f7ff3e.s32", evidence)
        builder._inventory(REAL.source_dir, evidence)
        for name, expected in evidence.items():
            with self.subTest(member=name):
                data = builder._bounded_source(builder._regular_child(REAL.source_dir, name))
                row = codec.read_s32(data, name)
                self.assertEqual(codec.write_s32(row), data)
                self.assertEqual(row["source_sha256"], expected["source_sha256"])
                self.assertEqual(row["sections"]["attributes"]["offset"], expected["attribute_byte_offset"])
                self.assertEqual(row["sections"]["attributes"]["sha256"], expected["attribute_sha256"])
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "private-pack"
            manifest = builder.build_pack(REAL.source_dir, REAL.summary, REAL.land_declaration, output)
            self.assertEqual(builder.validate_pack(output), manifest)
            codec.validate_manifest(manifest)
            for key, value in (("cumulative_version", 508), ("asset_path", "13225/"),
                               ("land_declaration", {"ID": 45194, "AssetPath": "13225/"}),
                               ("delivery_status", "PUBLIC_COMPLETE")):
                with self.subTest(key=key), self.assertRaises(ValueError):
                    codec.validate_manifest({**manifest, key: value})
            stale = copy.deepcopy(manifest)
            anchor = next(row for row in stale["members"] if row["member"] == codec.CURRENT_ANCHOR)
            anchor["bytes"] = 182625
            anchor["sha256"] = "3fc1b2ddef0e2de4d1f2000aed2b79b9941f13bd7a242ce1c1ef703eee02fa00"
            with self.assertRaises(ValueError):
                codec.validate_manifest(stale)
            for extra_or_missing in (manifest["members"] + manifest["members"][:1], manifest["members"][:-1]):
                with self.assertRaises(ValueError):
                    codec.validate_manifest({**manifest, "members": extra_or_missing})
            # A failing source check removes its staging tree and leaves no final output.
            failed_output = Path(temporary) / "failed-pack"
            real_read = builder._bounded_source
            def stale_anchor(path):
                data = real_read(path)
                return data[:-1] + bytes([data[-1] ^ 1]) if path.name == "800a8000.s32" else data
            with mock.patch.object(builder, "_bounded_source", side_effect=stale_anchor), self.assertRaises(ValueError):
                builder.build_pack(REAL.source_dir, REAL.summary, REAL.land_declaration, failed_output)
            self.assertFalse(failed_output.exists())
            self.assertEqual(list(Path(temporary).glob(".failed-pack.staging-*")), [])
            # Tamper only with the temporary private copy; originals are never edited.
            private_anchor = output / "originals" / codec.CURRENT_ANCHOR
            raw = private_anchor.read_bytes()
            private_anchor.write_bytes(raw[:-1] + bytes([raw[-1] ^ 1]))
            with self.assertRaisesRegex(ValueError, "SHA256/size mismatch"):
                builder.validate_pack(output)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--source-dir", type=Path)
    parser.add_argument("--summary", type=Path)
    parser.add_argument("--land-declaration", type=Path)
    args, remaining = parser.parse_known_args()
    supplied = (args.source_dir, args.summary, args.land_declaration)
    if any(supplied) and not all(supplied):
        parser.error("Real source verification requires --source-dir, --summary and --land-declaration together")
    if all(supplied):
        REAL = args
        RealSourceTests.__unittest_skip__ = False
    unittest.main(argv=[__file__, *remaining])
