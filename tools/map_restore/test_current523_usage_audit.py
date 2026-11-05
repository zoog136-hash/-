import json
from pathlib import Path
import tempfile
import unittest
from current523_usage_audit import CATALOG_SHA, merge_observations, union_bytes


class OriginalUsageAccountingTest(unittest.TestCase):
    def test_overlapping_byte_ranges_are_not_added_twice(self):
        self.assertEqual(union_bytes([(0, 10), (5, 10), (0, 10), (20, 2)], 30), 17)

    def test_original_bounds_are_required(self):
        with self.assertRaises(ValueError):
            union_bytes([(25, 10)], 30)

    def test_duplicate_owner_observations_keep_partial_file_partial(self):
        row = {"member": "Sprite/example.sp2", "sha256": "a" * 64,
               "original_member_bytes": 1000, "whole_file_used": False,
               "original_member_bytes_fully_used_proven": 0,
               "origins": {"AUTOMATED_ACTUAL_MAIN": {
                   "units": {"stored-bit:0/frame:0": True}, "source_ranges": {}}}}
        snapshot = {"schema": 1, "inventory_JSONL_SHA256": CATALOG_SHA,
                    "members": {row["member"] + "|" + row["sha256"]: row}}
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "observation.json"
            path.write_text(json.dumps(snapshot))
            merged = merge_observations([path, path])
        self.assertEqual(len(merged), 1)
        event = next(iter(merged.values()))["origins"]["AUTOMATED_ACTUAL_MAIN"]
        self.assertEqual(len(event["units"]), 1)
        self.assertEqual(union_bytes(list(event["ranges"]), 1000), 0)

    def test_fixture_observations_are_rejected(self):
        snapshot = {"schema": 1, "inventory_JSONL_SHA256": CATALOG_SHA,
                    "members": {"Map/example|" + "a" * 64: {
                        "member": "Map/example", "sha256": "a" * 64,
                        "original_member_bytes": 100, "whole_file_used": False,
                        "original_member_bytes_fully_used_proven": 0,
                        "origins": {"FIXTURE": {"units": {}, "source_ranges": {}}}}}}
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "observation.json"
            path.write_text(json.dumps(snapshot))
            with self.assertRaises(ValueError):
                merge_observations([path])


if __name__ == "__main__":
    unittest.main()
