"""Exercise identity reuse without changing the production checkout."""
import copy
import hashlib
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import link_original_based_identity as linker


class OriginalIdentityLinkTest(unittest.TestCase):
    SOURCE = "monster:아시타지오"
    TARGET = "monster:잔혹한 아시타지오"
    FOLDER = "asitagio"
    REFERENCE = "res://assets/external_l1j/monsters/16843.png"
    MISMATCH_ERROR = "rendered presentation differs"

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.folder = Path("assets/actors/eight_direction/original_based") / self.FOLDER
        rows = json.loads((ROOT / "data/animation_authoring_sources.json").read_text())["targets"]
        existing_keys = json.loads((ROOT / self.folder / "provenance.json").read_text())["target_keys"]
        self.targets = [copy.deepcopy(row) for row in rows if row["key"] in set(existing_keys + [self.SOURCE, self.TARGET])]
        (self.root / "data").mkdir()
        self.write_targets()
        shutil.copyfile(ROOT / "data/animation_presentation.json", self.root / "data/animation_presentation.json")
        actual_profiles = json.loads((ROOT / "data/combat_animation_profiles.json").read_text())["profiles"]
        source_profile = actual_profiles[self.SOURCE]
        target_name = next(row["name"] for row in self.targets if row["key"] == self.TARGET)
        document = {"schema": 1, "profiles": {self.SOURCE: source_profile, self.TARGET: {"name": target_name, "custom_existing_setting": 17}}}
        for key in existing_keys:
            if key not in document["profiles"]:
                document["profiles"][key] = copy.deepcopy(actual_profiles[key])
        (self.root / "data/combat_animation_profiles.json").write_text(json.dumps(document))
        (self.root / self.folder).mkdir(parents=True)
        for path in (ROOT / self.folder).iterdir():
            if path.suffix in {".png", ".tres", ".json"}:
                shutil.copyfile(path, self.root / self.folder / path.name)
        proof_path = self.root / self.folder / "provenance.json"
        proof = json.loads(proof_path.read_text())
        proof["target_keys"] = [key for key in proof["target_keys"] if key != self.TARGET]
        for field in ("target_references", "target_presentations"):
            proof.get(field, {}).pop(self.TARGET, None)
        proof_path.write_text(json.dumps(proof))
        for target in self.targets:
            path = Path(target["reference"]["path"].removeprefix("res://"))
            (self.root / path).parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / path, self.root / path)

    def write_targets(self):
        (self.root / "data/animation_authoring_sources.json").write_text(json.dumps({"targets": self.targets}))

    def snapshot(self):
        return {str(path.relative_to(self.root)): hashlib.sha256(path.read_bytes()).hexdigest()
                for path in self.root.rglob("*") if path.is_file()}

    def test_same_source_reuse_preserves_motion_and_target_history(self):
        before = self.snapshot()
        preview = linker.link(self.root, self.SOURCE, [self.TARGET])
        self.assertFalse(preview["applied"])
        self.assertEqual(self.snapshot(), before)
        result = linker.link(self.root, self.SOURCE, [self.TARGET], apply=True)
        self.assertEqual(result["actual_gameplay"], "not_run_by_linker")
        for name, sha in result["existing_resource_sha256"].items():
            self.assertEqual(hashlib.sha256((self.root / self.folder / name).read_bytes()).hexdigest(), sha)
        profiles = json.loads((self.root / "data/combat_animation_profiles.json").read_text())["profiles"]
        self.assertEqual(profiles[self.TARGET]["custom_existing_setting"], 17)
        self.assertEqual(profiles[self.TARGET]["prior_visual_profile"]["custom_existing_setting"], 17)
        self.assertEqual(profiles[self.TARGET]["authoring_reference"], self.REFERENCE)
        proof = json.loads((self.root / self.folder / "provenance.json").read_text())
        self.assertIn(self.TARGET, proof["target_keys"])
        self.assertEqual(proof["target_references"][self.TARGET]["path"], profiles[self.TARGET]["authoring_reference"])
        target = next(row for row in self.targets if row["key"] == self.TARGET)
        self.assertEqual(proof["target_presentations"][self.TARGET], target["presentation_to_preserve"])

    def test_same_pixels_with_different_body_are_rejected_without_writes(self):
        target = next(row for row in self.targets if row["key"] == self.TARGET)
        target["presentation_to_preserve"]["visual"]["body"] = "incompatible_body"
        self.write_targets()
        before = self.snapshot()
        with self.assertRaisesRegex(ValueError, self.MISMATCH_ERROR):
            linker.link(self.root, self.SOURCE, [self.TARGET], apply=True)
        self.assertEqual(self.snapshot(), before)

    def test_first_per_target_map_keeps_every_preexisting_alias(self):
        path = self.root / self.folder / "provenance.json"
        proof = json.loads(path.read_text())
        proof.pop("target_references", None)
        path.write_text(json.dumps(proof))
        profiles_path = self.root / "data/combat_animation_profiles.json"
        before = json.loads(profiles_path.read_text())["profiles"]
        linker.link(self.root, self.SOURCE, [self.TARGET], apply=True)
        proof = json.loads(path.read_text())
        self.assertEqual(set(proof["target_references"]), set(proof["target_keys"]))
        self.assertEqual(set(proof["target_presentations"]), set(proof["target_keys"]))
        after = json.loads(profiles_path.read_text())["profiles"]
        for target in self.targets:
            self.assertEqual(proof["target_references"][target["key"]], target["reference"])
            if target["key"] != self.TARGET:
                self.assertEqual(before[target["key"]], after[target["key"]])

    def test_independent_alias_source_sha_is_required_without_writes(self):
        target = next(row for row in self.targets if row["key"] == self.TARGET)
        image = self.root / target["reference"]["path"].removeprefix("res://")
        image.write_bytes(image.read_bytes() + b"changed")
        before = self.snapshot()
        with self.assertRaisesRegex(ValueError, "Original reference SHA changed"):
            linker.link(self.root, self.SOURCE, [self.TARGET], apply=True)
        self.assertEqual(self.snapshot(), before)


class ReviewedHarpyIdentityLinkTest(OriginalIdentityLinkTest):
    SOURCE = "monster:하피"
    TARGET = "monster:블루 하피"
    FOLDER = "harpy"
    REFERENCE = "res://assets/external_l1j/monsters/1024.png"
    MISMATCH_ERROR = "Reviewed source presentation changed"

    def test_changed_live_source_body_rejects_the_link_without_writes(self):
        path = self.root / "data/animation_presentation.json"
        presentation = json.loads(path.read_text())
        presentation["monster_sources"][self.REFERENCE]["body"] = "different rendered body"
        path.write_text(json.dumps(presentation))
        before = self.snapshot()
        with self.assertRaisesRegex(ValueError, "Reviewed source presentation override changed"):
            linker.link(self.root, self.SOURCE, [self.TARGET], apply=True)
        self.assertEqual(self.snapshot(), before)


if __name__ == "__main__":
    unittest.main()
