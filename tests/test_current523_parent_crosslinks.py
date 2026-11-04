"""Small authored records exercise crosslink provenance and namespace failures."""
import base64
import importlib.util
from pathlib import Path
import struct
import sys
import unittest

TOOLS = Path(__file__).parents[1] / "tools/map_restore"
sys.path.insert(0, str(TOOLS))
SPEC = importlib.util.spec_from_file_location("parent_crosslinks", TOOLS / "verify_current523_parent_crosslinks.py")
CROSS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CROSS)


def authored_record(member="Map/43/80008000.s32", target=47):
    label = b"fixture"
    x, y, packed = 2, 2, -65532
    raw = bytes([len(label)]) + label + struct.pack("<BBHi", x, y, target, packed)
    return {"member": member, "source_byte_offset": 50000,
            "raw_label_base64": base64.b64encode(label).decode("ascii"),
            "raw_x_u8": x, "raw_y_u8": y, "raw_target_u16": target,
            "raw_packed_i32": packed, "raw_hex": raw.hex()}


class ParentCrosslinksTest(unittest.TestCase):
    def test_numeric_asset_is_not_a_global_land_id_rule(self):
        lands = {43: {"ID": 43, "AssetPath": "43/"},
                 47: {"ID": 47, "AssetPath": "other/"},
                 12231: {"ID": 12231, "AssetPath": "47/"}}
        territories = {10: {"ID": 10, "LandID": 12231, "StartX": 32770, "EndX": 32770,
                            "StartY": 32767, "EndY": 32767}}
        portals = {601: {"ID": 601, "SourceLandID": 43, "SourceX": 32769,
                         "SourceY": 32770, "TargetTerritoryID": 10}}
        _, _, _, _, exact, direct, numeric, _ = CROSS.relations(authored_record(), lands, territories, portals)
        self.assertEqual([row["Portal"]["ID"] for row in exact], [601])
        self.assertEqual(direct, [])
        self.assertEqual([row["Portal"]["ID"] for row in numeric], [601])

    def test_aden_alias_and_shared_source_asset_use_exact_native_logical_land(self):
        lands = {4: {"ID": 4, "AssetPath": "Aden/"},
                 22803: {"ID": 22803, "AssetPath": "15/"},
                 22793: {"ID": 22793, "AssetPath": "15/"}}
        territories = {10: {"ID": 10, "LandID": 4, "StartX": 32770, "EndX": 32770,
                            "StartY": 32767, "EndY": 32767}}
        portals = {1: {"ID": 1, "SourceLandID": 22803, "SourceX": 32769,
                       "SourceY": 32770, "TargetTerritoryID": 10},
                   2: {"ID": 2, "SourceLandID": 22793, "SourceX": 32770,
                       "SourceY": 32770, "TargetTerritoryID": 10}}
        _, asset, source, target, exact, direct, numeric, contained = CROSS.relations(
            authored_record("Map/15/80008000.s32", 4), lands, territories, portals)
        self.assertEqual(asset, "15/")
        self.assertEqual(source, [32769, 32770])
        self.assertEqual(target, [32770, 32767])
        self.assertEqual(exact[0]["SourceLand"]["ID"], 22803)
        self.assertEqual([row["Portal"]["ID"] for row in direct], [1])
        self.assertEqual(numeric, [])
        self.assertEqual(contained, [1])

    def test_raw_fields_label_and_record_length_must_all_agree(self):
        record = authored_record()
        record["raw_label_base64"] = "wrong"
        with self.assertRaisesRegex(ValueError, "fields disagree"):
            CROSS.decode_record(record)
        record = authored_record()
        record["raw_hex"] += "00"
        with self.assertRaisesRegex(ValueError, "length"):
            CROSS.decode_record(record)
        record = authored_record("Map/43/800f7ff3e.s32")
        with self.assertRaisesRegex(ValueError, "Nonstandard"):
            CROSS.decode_record(record)

    def test_named_offset_is_a_record_boundary_and_duplicates_fail(self):
        record = authored_record()
        raw = bytes.fromhex(record["raw_hex"])
        decoded = {"uninterpreted_tail": struct.pack("<H", 1) + raw + b"opaque", "core_end": 50000}
        self.assertEqual(CROSS._named_offsets(decoded), {50002: raw})
        decoded["uninterpreted_tail"] = b"\xff\xff"
        with self.assertRaisesRegex(ValueError, "Unbounded"):
            CROSS._named_offsets(decoded)
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            CROSS.index([{"ID": 1}, {"ID": 1}], lambda row: row["ID"], "native ID")


if __name__ == "__main__":
    unittest.main()
