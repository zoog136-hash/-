"""Synthetic fixtures only: these values are not observed LineageM listings."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

MODULE = Path(__file__).resolve().parents[1] / "tools/exchange/import_snapshot.py"
spec = importlib.util.spec_from_file_location("exchange_snapshot", MODULE)
exchange = importlib.util.module_from_spec(spec)
spec.loader.exec_module(exchange)


def synthetic_snapshot():
    return {
        "schema": exchange.SCHEMA, "status": "captured",
        "captured_at": "2026-01-01T20:00:00Z",
        "source_url": "https://example.invalid/synthetic-fixture",
        "coverage": {"scope": "all_servers", "expected_server_ids": ["fixture-a", "fixture-b"],
                     "completed_server_ids": ["fixture-b", "fixture-a"], "complete": True},
        "price_policy": "frozen_once", "reset": {"timezone": "Asia/Seoul", "hour": 5},
        "listings": [{"listing_id": "synthetic-1", "server_id": "fixture-a", "item_class_id": 1,
                      "item_name": "SYNTHETIC test item", "bundle_size": 7, "bundle_price": 13,
                      "initial_bundles": 3, "currency_unit_id": 34, "currency_class_id": 2,
                      "enchant": 0, "element": "", "element_level": 0, "attributes": {},
                      "evidence_url": "https://example.invalid/synthetic-fixture/listing/1"}],
    }


class FrozenExchangeImportTest(unittest.TestCase):
    def test_preserves_bundle_price_quantity_and_unknown_evidence(self):
        snapshot = synthetic_snapshot()
        snapshot["listings"][0]["extra_evidence"] = {"label": "synthetic only"}
        before = copy.deepcopy(snapshot)
        self.assertIs(exchange.validate(snapshot), snapshot)
        self.assertEqual(snapshot, before)
        self.assertEqual((snapshot["listings"][0]["bundle_price"], snapshot["listings"][0]["bundle_size"]), (13, 7))

    def test_not_captured_has_no_invented_data(self):
        snapshot = synthetic_snapshot()
        snapshot.update(status="not_captured", captured_at=None, listings=[])
        snapshot["coverage"].update(expected_server_ids=[], completed_server_ids=[], complete=False)
        exchange.validate(snapshot)
        for key, value in (("captured_at", "2026-01-01T20:00:00Z"), ("listings", synthetic_snapshot()["listings"])):
            broken = copy.deepcopy(snapshot)
            broken[key] = value
            with self.assertRaises(ValueError):
                exchange.validate(broken)

    def test_captured_empty_market_allowed_only_with_complete_coverage(self):
        snapshot = synthetic_snapshot()
        snapshot["listings"] = []
        exchange.validate(snapshot)
        snapshot["coverage"]["complete"] = False
        with self.assertRaises(ValueError):
            exchange.validate(snapshot)

    def test_rejects_partial_duplicate_or_unknown_servers(self):
        for field, value in (("completed_server_ids", ["fixture-a"]),
                             ("expected_server_ids", []),
                             ("completed_server_ids", ["fixture-a", "fixture-a"]),
                             ("expected_server_ids", ["fixture-a", "fixture-a"]),
                             ("complete", 1), ("scope", "some_servers")):
            with self.subTest(field=field, value=value):
                snapshot = synthetic_snapshot()
                snapshot["coverage"][field] = value
                with self.assertRaises(ValueError):
                    exchange.validate(snapshot)
        snapshot = synthetic_snapshot()
        snapshot["listings"][0]["server_id"] = "unknown"
        with self.assertRaises(ValueError):
            exchange.validate(snapshot)

    def test_listing_identity_scoped_by_server(self):
        snapshot = synthetic_snapshot()
        snapshot["listings"].append(copy.deepcopy(snapshot["listings"][0]))
        with self.assertRaisesRegex(ValueError, "duplicate listing"):
            exchange.validate(snapshot)
        snapshot["listings"][1]["server_id"] = "fixture-b"
        exchange.validate(snapshot)

    def test_rejects_invalid_numeric_fields(self):
        for field in ("bundle_price", "bundle_size", "initial_bundles", "item_class_id"):
            for value in (0, -1, True, 1.0, "1", None, exchange.MAX_INTEGER + 1):
                with self.subTest(field=field, value=value):
                    snapshot = synthetic_snapshot()
                    snapshot["listings"][0][field] = value
                    with self.assertRaises(ValueError):
                        exchange.validate(snapshot)
        for field in ("enchant", "element_level"):
            for value in (-1, True, 256, 1.0):
                snapshot = synthetic_snapshot()
                snapshot["listings"][0][field] = value
                with self.assertRaises(ValueError):
                    exchange.validate(snapshot)

    def test_checked_product_and_exact_integer_boundary(self):
        for field in ("bundle_price", "bundle_size"):
            snapshot = synthetic_snapshot()
            snapshot["listings"][0][field] = exchange.MAX_INTEGER
            with self.assertRaisesRegex(ValueError, "total exceeds"):
                exchange.validate(snapshot)
            snapshot["listings"][0]["initial_bundles"] = 1
            exchange.validate(snapshot)

    def test_invalid_timestamp_and_policy(self):
        for value in (None, "2026-01-01T20:00:00", "2026-01-02T05:00:00+09:00",
                      "2026-02-30T00:00:00Z", "2026-1-1T20:00:00Z", "2026-01-01T20:00:00.1Z"):
            snapshot = synthetic_snapshot()
            snapshot["captured_at"] = value
            with self.assertRaises(ValueError):
                exchange.validate(snapshot)
        for key, value in (("schema", "future"), ("price_policy", "live"), ("status", "partial"),
                           ("reset", {"timezone": "UTC", "hour": 5}), ("source_url", "http://example.invalid")):
            snapshot = synthetic_snapshot()
            snapshot[key] = value
            with self.assertRaises(ValueError):
                exchange.validate(snapshot)

    def test_invalid_listing_shapes_and_currency(self):
        for key, value in (("currency_unit_id", 4), ("currency_class_id", True), ("item_name", " "),
                           ("listing_id", ""), ("attributes", []), ("element", None),
                           ("evidence_url", "https://user:password@example.invalid"),
                           ("evidence_url", "http://example.invalid")):
            snapshot = synthetic_snapshot()
            snapshot["listings"][0][key] = value
            with self.assertRaises(ValueError):
                exchange.validate(snapshot)
        snapshot = synthetic_snapshot()
        snapshot["listings"] = [None]
        with self.assertRaises(ValueError):
            exchange.validate(snapshot)

    def test_nonfinite_attributes_rejected(self):
        snapshot = synthetic_snapshot()
        snapshot["listings"][0]["attributes"] = {"unknown": float("nan")}
        with self.assertRaises(ValueError):
            exchange.validate(snapshot)

    def test_import_and_reimport_preserve_frozen_file(self):
        with tempfile.TemporaryDirectory() as directory:
            source, destination = Path(directory) / "input.json", Path(directory) / "snapshot.json"
            source.write_text(json.dumps(synthetic_snapshot()), encoding="utf-8")
            exchange.import_snapshot(source, destination)
            before = destination.read_bytes()
            with self.assertRaises(FileExistsError):
                exchange.import_snapshot(source, destination)
            self.assertEqual(destination.read_bytes(), before)
            self.assertEqual(json.loads(before), synthetic_snapshot())
            self.assertEqual(list(Path(directory).glob(".exchange-*")), [])

    def test_invalid_input_never_changes_existing_file(self):
        with tempfile.TemporaryDirectory() as directory:
            source, destination = Path(directory) / "input.json", Path(directory) / "snapshot.json"
            destination.write_bytes(b"original bytes")
            for content in ("{", '{"schema":"one","schema":"two"}', "null"):
                source.write_text(content, encoding="utf-8")
                with self.assertRaises(ValueError):
                    exchange.import_snapshot(source, destination)
                self.assertEqual(destination.read_bytes(), b"original bytes")

    def test_publish_failure_leaves_no_partial_output(self):
        with tempfile.TemporaryDirectory() as directory:
            source, destination = Path(directory) / "input.json", Path(directory) / "snapshot.json"
            source.write_text(json.dumps(synthetic_snapshot()), encoding="utf-8")
            with patch.object(exchange.os, "link", side_effect=OSError("synthetic publication failure")):
                with self.assertRaises(OSError):
                    exchange.import_snapshot(source, destination)
            self.assertFalse(destination.exists())
            self.assertEqual(list(Path(directory).glob(".exchange-*")), [])

    def test_competing_publisher_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            source, destination = Path(directory) / "input.json", Path(directory) / "snapshot.json"
            source.write_text(json.dumps(synthetic_snapshot()), encoding="utf-8")
            link = exchange.os.link
            def competing_link(temporary, target):
                Path(target).write_bytes(b"other frozen snapshot")
                link(temporary, target)
            with patch.object(exchange.os, "link", side_effect=competing_link):
                with self.assertRaises(FileExistsError):
                    exchange.import_snapshot(source, destination)
            self.assertEqual(destination.read_bytes(), b"other frozen snapshot")

    def test_cli_validate_only(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "input.json"
            source.write_text(json.dumps(synthetic_snapshot()), encoding="utf-8")
            result = subprocess.run([sys.executable, str(MODULE), "--validate-only", str(source)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("evidence truth not independently verified", result.stdout)
            self.assertEqual(list(Path(directory).iterdir()), [source])


if __name__ == "__main__":
    unittest.main()
