"""Portal evidence failures tested with small authored bytes, never M payloads."""
import copy
import importlib.util
from pathlib import Path
import struct
import sys
import tempfile
import unittest

TOOLS = Path(__file__).parents[1] / "tools/map_restore"
sys.path.insert(0, str(TOOLS))
SPEC = importlib.util.spec_from_file_location("aden_portals", TOOLS / "build_current523_aden_portals.py")
PORTALS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PORTALS)


class AdenPortalsTest(unittest.TestCase):
    def record(self, *, member="Map/Aden/80008000.s32", x=2, y=2, target=4, point=(32771, 32772), label=b"gate"):
        packed = ((point[1] - 32768) & 65535) << 16 | ((point[0] - 32768) * 2 & 65535)
        signed = packed - 2**32 if packed >= 2**31 else packed
        raw = bytes([len(label)]) + label + struct.pack("<BBHi", x, y, target, signed)
        decoded = {"uninterpreted_tail": struct.pack("<H", 1) + raw + b"opaque",
                   "core_end": 50000, "member": member, "source_sha256": "a" * 64, "source_bytes": 60000}
        rows, metadata = PORTALS.extract_named(decoded)
        return rows[0], raw, metadata

    def fixture(self):
        lands = {4: {"ID": 4, "AssetPath": "Aden/"}, 75: {"ID": 75, "AssetPath": "75/"}}
        territory = {"ID": 100, "LandID": 4, "StartX": 32771, "StartY": 32772, "EndX": 32771, "EndY": 32772}
        portal = {"ID": 1, "SourceLandID": 4, "SourceX": 32769, "SourceY": 32770, "TargetTerritoryID": 100, "AssetID": 0}
        members = {"Map/Aden/80008000.s32": {"sha256": "a" * 64}}
        return lands, {100: territory}, {1: portal}, [self.record()[0]], members

    def test_raw_labels_words_offsets_and_opaque_remainder_preserved(self):
        record, raw, metadata = self.record(label=b"\xffgate")
        self.assertEqual(record["raw_hex"], raw.hex())
        self.assertEqual(record["raw_label_base64"], "/2dhdGU=")
        self.assertEqual(record["source_byte_offset"], 50002)
        self.assertEqual(record["raw_target_u16"], 4)
        self.assertEqual(metadata["remaining_bytes"], 6)
        self.assertEqual(metadata["remaining_sha256"], PORTALS.codec.sha256(b"opaque"))

    def test_namespace4_resolves_to_aden_and_still_needs_runtime_checks(self):
        args = self.fixture()
        portal = PORTALS.join_portals(*args)[0]
        self.assertTrue(portal["activation_candidate"])
        self.assertFalse(portal["activation_eligible"])
        self.assertEqual(args[3][0]["target_land_declaration"]["AssetPath"], "Aden/")
        self.assertEqual(portal["runtime_requirements"], PORTALS.RUNTIME_REQUIREMENTS)
        self.assertFalse(any(key in portal["portal"] for key in ("Fee", "Cost", "ConsumeItem")))

    def test_duplicate_label_destination_at_other_chunk_never_matches(self):
        args = self.fixture()
        args[3][:] = [self.record(member="Map/Aden/80018000.s32")[0]]
        portal = PORTALS.join_portals(*args)[0]
        self.assertFalse(portal["activation_candidate"])
        self.assertEqual(portal["exact_source_raw_record_ids"], [])
        self.assertIn("no_exact_source_and_namespace_raw_record", portal["blockers"])

    def test_namespace_mismatch_blocks_even_exact_source_and_target(self):
        args = self.fixture()
        args[3][0]["raw_target_u16"] = 75
        portal = PORTALS.join_portals(*args)[0]
        self.assertFalse(portal["activation_candidate"])
        self.assertEqual(args[3][0]["namespace_pair_portal_ids"], [])

    def test_portal350_style_raw_target_mismatch_is_retained_without_correction(self):
        args = self.fixture()
        args[3][:] = [self.record(point=(32774, 32774))[0]]
        portal = PORTALS.join_portals(*args)[0]
        self.assertFalse(portal["activation_candidate"])
        self.assertEqual(portal["source_position"], [32769, 32770])
        self.assertEqual(portal["landing_position"], [32771, 32772])
        self.assertEqual(args[3][0]["target_xy_candidates"][PORTALS.PRIMARY_TARGET_MODE], [32774, 32774])
        self.assertIn("raw_destination_outside_declared_territory", portal["blockers"])

    def test_rectangular_target_keeps_bounds_without_guessing_start_as_landing(self):
        args = self.fixture()
        args[1][100]["EndX"] += 3
        portal = PORTALS.join_portals(*args)[0]
        self.assertIsNone(portal["landing_position"])
        self.assertEqual(portal["target_territory"]["EndX"], 32774)
        self.assertFalse(portal["activation_candidate"])

    def test_other_land_source_and_missing_aden_member_stay_blocked(self):
        args = self.fixture()
        args[1][100]["LandID"] = 75
        args[3][0]["raw_target_u16"] = 75
        portal = PORTALS.join_portals(*args)[0]
        self.assertFalse(portal["activation_candidate"])
        self.assertIn("target_land_source_not_supplied", portal["blockers"])
        args = self.fixture()
        args[4].clear()
        portal = PORTALS.join_portals(*args)[0]
        self.assertIn("source_s32_not_verified", portal["blockers"])
        self.assertIn("target_s32_not_verified", portal["blockers"])

    def test_ambiguous_raw_matches_and_half_coordinates_stay_blocked(self):
        args = self.fixture()
        args[3].append(copy.deepcopy(args[3][0]))
        portal = PORTALS.join_portals(*args)[0]
        self.assertIn("ambiguous_raw_endpoint_records", portal["blockers"])
        args = self.fixture()
        args[3][:] = [self.record(x=3)[0]]
        self.assertFalse(PORTALS.join_portals(*args)[0]["activation_candidate"])
        self.assertIsNone(PORTALS.source_candidate("Map/Aden/800f7ff3e.s32", 2, 2))

    def test_bounded_tail_and_duplicate_table_ids_rejected(self):
        for raw in (b"\x01", b"\xff\xff", b"\x01\x00\x10short"):
            with self.assertRaises(ValueError):
                PORTALS.extract_named({"uninterpreted_tail": raw, "member": "Map/Aden/80008000.s32"})
        with self.assertRaisesRegex(ValueError, "duplicate"):
            PORTALS._indexed([{"ID": 4}, {"ID": 4}], "Land")

    def test_private_output_is_atomic_and_refuses_repository_or_overwrite(self):
        contract = {"counts": {"activated_portals": 0}}
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            output = root / "private.json"
            receipt = PORTALS.write_private(contract, output)
            self.assertEqual(receipt["sha256"], PORTALS.codec.sha256(output.read_bytes()))
            with self.assertRaisesRegex(ValueError, "exists"):
                PORTALS.write_private(contract, output)
            (root / ".git").mkdir()
            (root / ".git/HEAD").write_text("ref: refs/heads/main")
            with self.assertRaisesRegex(ValueError, "outside Git"):
                PORTALS.write_private(contract, root / "private2.json")
            self.assertFalse(list(root.glob(".aden-portals-*")))

    def test_native_json_bom_accepted_and_duplicate_keys_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "table.json"
            path.write_bytes(b'\xef\xbb\xbf{"rows":[]}')
            self.assertEqual(PORTALS.read_json(path)[0], {"rows": []})
            path.write_text('{"rows":[],"rows":[]}')
            with self.assertRaisesRegex(ValueError, "Duplicate JSON key"):
                PORTALS.read_json(path)


if __name__ == "__main__":
    unittest.main()
