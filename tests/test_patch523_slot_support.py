"""Focused exporter/source checks; no game, CI, save or private upload."""
import contextlib
import copy
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("slot_builder", ROOT / "tools/build_patch523_slot_support.py")
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)
REPOSITORY = Path(os.environ.get("TWILIGHT_SLOT_TEST_REPOSITORY", ROOT))
SOURCE_ZIP = Path(os.environ["TWILIGHT_SLOT_SOURCE_ZIP"]) if os.environ.get("TWILIGHT_SLOT_SOURCE_ZIP") else None
V1_PACK = Path(os.environ["TWILIGHT_SLOT_V1_PACK"]) if os.environ.get("TWILIGHT_SLOT_V1_PACK") else None


@unittest.skipUnless(SOURCE_ZIP is not None and V1_PACK is not None,
                     "Explicit private source ZIP and existing v1 pack required")
class SlotSupportTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="twilight-slot-export-")
        cls.v1_path = Path(cls.temporary.name) / "v1.json"
        cls.v2_path = Path(cls.temporary.name) / "v2.json"
        with contextlib.redirect_stdout(io.StringIO()):
            cls.v1 = BUILDER.build(cls.v1_path, 1, REPOSITORY)
            cls.v2 = BUILDER.build(cls.v2_path, 2, REPOSITORY, SOURCE_ZIP)
        cls.slots, _ = BUILDER.source("patch523_option_slots", REPOSITORY)
        cls.base = json.loads(BUILDER.git_bytes("data/cards/base508_option_awakening.json", REPOSITORY, BUILDER.REGISTRY_COMMIT)[0])
        catalog = json.loads(BUILDER.git_bytes("data/lineagem_base508/cards_patch523.json", REPOSITORY, BUILDER.REGISTRY_COMMIT)[0])
        cls.registry = {r["sourceId"]: r for rows in catalog["catalog"].values() for r in rows}

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def test_v1_is_the_existing_installed_bytes(self):
        self.assertEqual(self.v1_path.read_bytes(), V1_PACK.read_bytes())
        self.assertEqual(hashlib.sha256(self.v1_path.read_bytes()).hexdigest(), BUILDER.V1_SHA256)

    def test_v2_loader_pin_matches_generated_private_artifact(self):
        loader = (ROOT / "scripts/cards/patch523_slot_data.gd").read_text()
        digest = re.search(r'const SHA256_V2: String="([0-9a-f]{64})"', loader).group(1)
        self.assertEqual(hashlib.sha256(self.v2_path.read_bytes()).hexdigest(), digest)
        self.assertIn('const SHA256: String="' + BUILDER.V1_SHA256 + '"', loader)

    def test_complete_option_graph_is_preserved(self):
        expected = copy.deepcopy(self.slots)
        expected["projection_source"] = self.v2["options"]["projection_source"]
        self.assertEqual(self.v2["options"], expected)
        self.assertEqual(self.v2["options"]["counts"], {"cards": 305, "groups": 446,
            "effects": 2392, "slot_pairs": 141, "compatible_primary_groups": 289})

    def test_v1_non_option_sections_are_unchanged(self):
        for key in ("new_cards", "relic", "relic_combat", "source_commit"):
            self.assertEqual(self.v1[key], self.v2[key])

    def test_one_primary_replacement_does_not_add_ownership(self):
        self.assertEqual(self.v2["options"]["changed_primary_keys"], ["2:25002:1"])
        self.assertEqual(len(self.registry), 720)
        overlays = [r for rows in self.v2["new_cards"]["catalog"].values() for r in rows]
        self.assertEqual(len(overlays), 16)
        self.assertTrue(all(row["sourceId"] in self.registry for row in overlays))
        self.assertEqual(len({row["sourceId"] for row in overlays}), 16)

    def test_original_archive_and_all_embedded_table_pins_checked(self):
        proof = self.v2["verification"]
        self.assertTrue(proof["zip_crc_checked"])
        self.assertEqual(proof["source_zip_sha256"], BUILDER.SOURCE_SHA256)
        self.assertGreaterEqual(proof["verified_table_count"], 32)
        self.assertEqual(len(proof["source_table_sha256"]), proof["verified_table_count"])
        self.assertGreaterEqual(proof["verified_embedded_rows"], 2559+556)

    def test_acquisition_rows_remain_exact_private_projections(self):
        for name in ("card_acquisition", "relic_acquisition"):
            original, _ = BUILDER.source("patch523_" + name, REPOSITORY)
            original["projection_source"] = self.v2[name]["projection_source"]
            self.assertEqual(self.v2[name], original)
            self.assertNotIn(name, self.v1)

    def test_typed_acquisition_row_must_match_original_index(self):
        document, _ = BUILDER.source("patch523_card_acquisition", REPOSITORY)
        document["guaranteed_nemesis"]["inputs"][0]["link"]["raw"]["Amount"] -= 1
        with self.assertRaisesRegex(ValueError, "Embedded original row mismatch"):
            BUILDER.verify_original(SOURCE_ZIP, [self.slots, document], self.slots, self.registry)

    def test_unknown_primary_correction_is_rejected(self):
        slots = copy.deepcopy(self.slots)
        slots["groups"]["2:25002:1"]["links"][3]["Level"] = 2
        with self.assertRaisesRegex(ValueError, "Unreviewed primary effect change"):
            BUILDER.validate_options(slots, self.base, self.registry)

    def test_unknown_secondary_bonus_is_rejected(self):
        slots = copy.deepcopy(self.slots)
        key = "2:25002:11"
        slots["groups"][key]["links"][0]["BonusID"] = 2299302
        with self.assertRaisesRegex(ValueError, "Unreviewed primary/secondary relation"):
            BUILDER.validate_options(slots, self.base, self.registry)

    def test_changed_primary_whitelist_cannot_expand(self):
        slots = copy.deepcopy(self.slots)
        slots["changed_primary_keys"].append("1:1:1")
        with self.assertRaisesRegex(ValueError, "replacement boundary"):
            BUILDER.validate_options(slots, self.base, self.registry)

    def test_unverified_original_rows_are_rejected(self):
        slots = copy.deepcopy(self.slots)
        slots["bonuses"]["2307562"]["Value"] += 1
        with self.assertRaisesRegex(ValueError, "Raw option value differs"):
            BUILDER.verify_original(SOURCE_ZIP, [slots], slots, self.registry)

    def test_wrong_source_archive_is_rejected(self):
        path = Path(self.temporary.name) / "unverified.zip"
        path.write_bytes(b"unverified source")
        with self.assertRaisesRegex(ValueError, "verified patch523"):
            BUILDER.verify_original(path, [self.slots], self.slots, self.registry)

    def test_v2_cannot_be_built_without_original_verification(self):
        with self.assertRaisesRegex(ValueError, "requires the verified original"):
            BUILDER.build(Path(self.temporary.name) / "unverified-v2.json", 2, REPOSITORY)


if __name__ == "__main__":
    unittest.main()
