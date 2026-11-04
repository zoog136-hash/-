"""Focused compiler checks; real-source checks require the separately held ZIP."""
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
import zipfile

MODULE = Path(__file__).with_name("build_player_skills523.py")
spec = importlib.util.spec_from_file_location("skills523_builder", MODULE)
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)
ROOT = Path(__file__).resolve().parents[2]


class CompilerGuardTests(unittest.TestCase):
    def test_duplicate_ids_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "duplicate"):
            builder.unique([{"ID": 7}, {"ID": 7}], "synthetic")

    def test_non523_zip_is_rejected_before_parsing(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "not523.zip"
            path.write_bytes(b"synthetic unrelated source")
            with self.assertRaisesRegex(ValueError, "exact cumulative523"):
                builder.compile_pack(path, Path("unused"))


@unittest.skipUnless(os.environ.get("PLAYER_SKILLS523_SOURCE"), "private523 source not installed")
class ActualSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = Path(os.environ["PLAYER_SKILLS523_SOURCE"])
        cls.bindings_path = ROOT / "data/skills/player_skills523_bindings.json"
        cls.bindings = json.loads(cls.bindings_path.read_bytes())
        cls.pack = builder.compile_pack(cls.source, cls.bindings_path)

    def test_every_reviewed_profile_is_exact_and_learnable(self):
        self.assertEqual(len(self.pack["profiles"]), len(self.bindings["skills"]))
        with zipfile.ZipFile(self.source) as archive:
            spells = builder.unique(json.loads(archive.read("content/SpellClass.json"))["rows"], "SpellClass")
            limits = json.loads(archive.read("content/SpellLearnLimit.json"))["rows"]
            costs = json.loads(archive.read("content/SpellCost.json"))["rows"]
            for host_id, profile in self.pack["profiles"].items():
                spell_id = self.bindings["skills"][host_id]["spell_id"]
                self.assertEqual(profile["row"], spells[spell_id])
                self.assertEqual(json.loads(profile["row_json"]), spells[spell_id])
                self.assertEqual(builder.digest(profile["row_json"].encode()), self.bindings["skills"][host_id]["row_sha256"])
                self.assertEqual(profile["learn_limits"], [r for r in limits if r["SpellClassID"] == spell_id])
                self.assertEqual(profile["costs"], [r for r in costs if r["SpellClassID"] == spell_id])
                self.assertTrue(any(not r["IsTutorialSpell"] for r in profile["learn_limits"]))
        self.assertEqual(self.pack["profiles"]["lm_11ab17290e72e63f"]["row"]["ID"], 99841)
        self.assertEqual(self.pack["profiles"]["lm_f5125fc718ebf071"]["target_kind"]["Name"], "PCButMe")

    def test_bonus_links_keep_source_order_and_level_conditions(self):
        with zipfile.ZipFile(self.source) as archive:
            links = json.loads(archive.read("content/SpellBonus.json"))["rows"]
            bonus = builder.unique(json.loads(archive.read("content/Bonus.json"))["rows"], "Bonus")
            for profile in self.pack["profiles"].values():
                expected = [r for r in links if r["SpellClassID"] == profile["row"]["ID"]]
                self.assertEqual([e["link"] for e in profile["bonuses"]], expected)
                for entry in profile["bonuses"]:
                    self.assertEqual(entry["bonus"], bonus[entry["link"]["BonusID"]])
                    self.assertEqual(entry["type"]["ID"], entry["bonus"]["BonusTypeID"])
                    self.assertEqual(entry["unit"]["ID"], entry["type"]["UnitID"])

    def test_edited_binding_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            binding = copy.deepcopy(self.bindings)
            binding["skills"][next(iter(binding["skills"]))]["row_sha256"] = "0" * 64
            path = Path(tmp) / "bindings.json"
            path.write_text(json.dumps(binding))
            with self.assertRaisesRegex(ValueError, "unreviewed source row"):
                builder.compile_pack(self.source, path)


if __name__ == "__main__":
    unittest.main()
