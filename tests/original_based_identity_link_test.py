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

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.folder = Path("assets/actors/eight_direction/original_based/asitagio")
        rows = json.loads((ROOT / "data/animation_authoring_sources.json").read_text())["targets"]
        self.targets = [copy.deepcopy(row) for row in rows if row["key"] in (self.SOURCE, self.TARGET)]
        (self.root / "data").mkdir()
        self.write_targets()
        source_profile = json.loads((ROOT / "data/combat_animation_profiles.json").read_text())["profiles"][self.SOURCE]
        document = {"schema": 1, "profiles": {self.SOURCE: source_profile, self.TARGET: {"name": "잔혹한 아시타지오", "custom_existing_setting": 17}}}
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
        self.assertEqual(profiles[self.TARGET]["authoring_reference"], "res://assets/external_l1j/monsters/16843.png")
        proof = json.loads((self.root / self.folder / "provenance.json").read_text())
        self.assertIn(self.TARGET, proof["target_keys"])
        self.assertEqual(proof["target_references"][self.TARGET]["path"], profiles[self.TARGET]["authoring_reference"])

    def test_same_pixels_with_different_body_are_rejected_without_writes(self):
        target = next(row for row in self.targets if row["key"] == self.TARGET)
        target["presentation_to_preserve"]["visual"]["body"] = "incompatible_body"
        self.write_targets()
        before = self.snapshot()
        with self.assertRaisesRegex(ValueError, "rendered presentation differs"):
            linker.link(self.root, self.SOURCE, [self.TARGET], apply=True)
        self.assertEqual(self.snapshot(), before)

    def test_independent_alias_source_sha_is_required_without_writes(self):
        target = next(row for row in self.targets if row["key"] == self.TARGET)
        image = self.root / target["reference"]["path"].removeprefix("res://")
        image.write_bytes(image.read_bytes() + b"changed")
        before = self.snapshot()
        with self.assertRaisesRegex(ValueError, "Original reference SHA changed"):
            linker.link(self.root, self.SOURCE, [self.TARGET], apply=True)
        self.assertEqual(self.snapshot(), before)


if __name__ == "__main__":
    unittest.main()
