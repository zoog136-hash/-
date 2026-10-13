"""Identity and rollback cases for the offline production sprite selector."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import build_animation_expansion as expansion


class ExpansionPlanTest(unittest.TestCase):
    def test_real_weapon_and_body_regressions(self):
        result = expansion.plan(ROOT)
        selected = result["bindings"]
        self.assertTrue(selected["transform:131"]["actor"].endswith("female_plate_plate_helm_longsword"))
        self.assertTrue(selected["transform:135"]["actor"].endswith("female_leather_head_long_longbow"))
        self.assertTrue(selected["transform:137"]["actor"].endswith("female_mage_mage_hood_staff"))
        # Generic reviewed body labels must not override an explicit weapon.
        self.assertTrue(selected["transform:283"]["actor"].endswith("longsword"))
        self.assertEqual(selected["monster:데스나이트"]["actor"], "expanded/skeleton_knight_boss")
        self.assertTrue(selected["monster:아틀란티스 심해마녀"]["actor"].startswith("expanded/female_"))
        for key in ("transform:412", "transform:258", "monster:천상계 천사궁수", "monster:아틀란티스 심해창병"):
            self.assertIn(key, result["unmatched"])
            self.assertNotIn(key, selected)
        targets = [r for r in expansion.read(ROOT / "data/catalog_v19.json")["변신"] if r["grade"] in expansion.GRADES]
        self.assertEqual(len(targets), sum(k.startswith("transform:") for k in selected) + sum(k.startswith("transform:") for k in result["unmatched"]))

    def test_rejected_owned_mapping_restores_prior_art_without_touching_other_art(self):
        prior = {"motion_style": "heavy", "attack_hit_ratio": .56, "frames_path": "res://assets/legacy.tres"}
        external = {"frames_path": "res://assets/other_feature.tres", "attack_hit_ratio": .34}
        profiles = {"schema": 1, "profiles": {
            "monster:known": {"frames_path": "res://assets/actors/eight_direction/expanded/one/SpriteFrames.tres", "prior_visual_profile": prior},
            "monster:local_addition": {"frames_path": "res://assets/actors/eight_direction/expanded/two/SpriteFrames.tres", "prior_visual_profile": None},
            "monster:external": external,
            "class:0": {"frames_path": "res://assets/actors/eight_direction/knight/SpriteFrames.tres"},
        }}
        recipe = {"actors": {}, "bindings": {}, "unmatched": {"monster:known": {}, "monster:local_addition": {}, "monster:external": {}}}
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "data/combat_animation_profiles.json"
            path.parent.mkdir()
            path.write_text(json.dumps(profiles))
            expansion.apply(root, recipe)
            after = expansion.read(path)["profiles"]
            self.assertEqual(after["monster:known"], prior)
            self.assertNotIn("monster:local_addition", after)
            self.assertEqual(after["monster:external"], external)
            self.assertEqual(after["class:0"], profiles["profiles"]["class:0"])
            expansion.apply(root, recipe)
            self.assertEqual(expansion.read(path)["profiles"], after)


if __name__ == "__main__":
    unittest.main()
