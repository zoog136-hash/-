import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "shop"))
import audit_source523_npc_activation as npc_audit


class AuditProtectionTest(unittest.TestCase):
    def test_rejects_unverified_archive(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source.zip"
            source.write_bytes(b"not an original")
            with self.assertRaisesRegex(ValueError, "verified patch523"):
                npc_audit.audit(source)
            self.assertEqual(source.read_bytes(), b"not an original")

    def test_refuses_source_overwrite_before_reading(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source.zip"
            source.write_bytes(b"preserve original")
            with self.assertRaisesRegex(ValueError, "remain unchanged"):
                npc_audit.write_audit(source, source)
            self.assertEqual(source.read_bytes(), b"preserve original")

    def test_private_relations_cannot_be_written_into_public_repo(self):
        destination = ROOT / "docs" / "shop" / "private-relations-should-not-exist.json"
        self.assertFalse(destination.exists())
        with self.assertRaisesRegex(ValueError, "outside the Git"):
            npc_audit.write_audit("missing.zip", destination)
        self.assertFalse(destination.exists())

    def test_similar_numeric_ids_are_not_a_unit_definition(self):
        # Presence of a numeric code is insufficient: validate its namespace name.
        with self.assertRaisesRegex(ValueError, "namespace"):
            npc_audit.analyze({"Unit": [{"ID": 25, "Name": "OtherNamespace"},
                                         {"ID": 201, "Name": "CurrencyID"}]}, [])


@unittest.skipUnless(os.environ.get("SOURCE523_SHOP_ZIP"), "actual 523 ZIP not selected")
class OriginalActivationAuditTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = Path(os.environ["SOURCE523_SHOP_ZIP"])
        cls.before_sha = hashlib.sha256(cls.source.read_bytes()).hexdigest()
        cls.report = npc_audit.audit(cls.source)
        cls.merchants = {r["merchant_id"]: r for r in cls.report["merchants"]}

    def test_complete_inventory_and_goods_coverage(self):
        self.assertEqual(self.report["summary"], {
            "inventory_tables": 1065, "goods_rows": 4328, "merchant_groups": 192,
            "groups_with_explicit_object_reference": 121,
            "groups_without_explicit_object_reference": 71,
            "zero_hour_rows": 4328, "positive_count_limit_rows": 1428,
        })
        ids = [i for r in self.merchants.values() for i in r["goods_ids"]]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual(sum(len(r["zero_hour_goods_ids"]) for r in self.merchants.values()), 4328)
        self.assertTrue(all(not r["activation_authorized"] for r in self.merchants.values()))

    def test_real_currency_link_uses_unit_25_then_unit_201(self):
        merchant = self.merchants[13]
        self.assertIn(1952, merchant["goods_ids"])
        serin = next(x for x in merchant["object_links"] if x["earth_object_id"] == 27)
        self.assertEqual(serin["merchant_link_row_id"], 9)
        self.assertEqual(serin["currency_ids"], [1])
        self.assertEqual(serin["currency_names"], ["Adena"])
        self.assertIn(4, [r["ID"] for r in serin["spawns"]])
        self.assertEqual(self.merchants[91]["object_links"][0]["currency_ids"], [21])

    def test_numeric_id_collision_does_not_bind_another_npc(self):
        # EarthObjectClass 28 exists, but its MerchantsID is 52, not 28.
        self.assertEqual(self.merchants[28]["object_links"], [])
        self.assertIn(28, [r["earth_object_id"] for r in self.merchants[52]["object_links"]])
        # Merchant 123 is the inner-castle object 893, not EarthObjectClass 123.
        self.assertEqual([r["earth_object_id"] for r in self.merchants[123]["object_links"]], [893])

    def test_defined_event_object_without_spawn_remains_distinct(self):
        obj = self.merchants[372]["object_links"][0]
        self.assertEqual(obj["earth_object_id"], 1902)
        self.assertTrue(obj["object_defined"])
        self.assertEqual(obj["spawns"], [])
        self.assertIn("INCOMPLETE_OBJECT_CURRENCY_ACTION_OR_SPAWN_CHAIN", self.merchants[372]["blockers"])

    def test_missing_hour_rule_and_unrelated_refresh_enum_are_not_guessed(self):
        self.assertTrue(all("UNVERIFIED_ZERO_HOUR_EXECUTION_RULE" in r["blockers"] for r in self.merchants.values()))
        names = self.report["contents_reset_schedule_names_not_a_verified_merchant_foreign_key"]
        self.assertNotIn(31, names)
        self.assertEqual(self.report["refresh_type_ids"][31], 3675)
        self.assertFalse(self.report["activation_authorized"])

    def test_private_report_receipt_and_original_byte_preservation(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "audit.json"
            receipt = npc_audit.write_audit(self.source, path)
            data = path.read_bytes()
            self.assertEqual(receipt["bytes"], len(data))
            self.assertEqual(receipt["sha256"], hashlib.sha256(data).hexdigest())
            self.assertEqual(json.loads(data), json.loads(json.dumps(self.report)))
        self.assertEqual(hashlib.sha256(self.source.read_bytes()).hexdigest(), self.before_sha)


if __name__ == "__main__":
    unittest.main()
