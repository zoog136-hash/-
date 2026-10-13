"""Guard exact reference identity, lossless import, and reviewed actual poses."""
import json
import copy
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import import_original_based_motion as importer
import audit_eight_direction_coverage as audit


class OriginalBasedImportTest(unittest.TestCase):
    def test_existing_family_aliases_share_only_the_same_rendered_original(self):
        targets = {row["key"]: row for row in json.loads((ROOT / "data/animation_authoring_sources.json").read_text())["targets"]}
        for names in [("고스트", "글루디오 던전 유령", "지옥의 고스트"), ("오우거", "기란 평원 오우거", "잊혀진 섬 고대오우거")]:
            first = targets["monster:" + names[0]]
            for name in names[1:]:
                self.assertEqual(importer.sharing_identity(first), importer.sharing_identity(targets["monster:" + name]))
            for field, value in [("attack_type", "magic"), ("visual_height", 1234), ("animation_profile", {"floating": False})]:
                other = copy.deepcopy(first)
                other["presentation_to_preserve"][field] = value
                self.assertNotEqual(importer.sharing_identity(first), importer.sharing_identity(other))
            other = copy.deepcopy(first)
            other["reference"]["sha256"] = "different original"
            self.assertNotEqual(importer.sharing_identity(first), importer.sharing_identity(other))
        atlas = next(row for row in targets.values() if row["reference"]["kind"] == "existing_project_atlas")
        other = copy.deepcopy(atlas)
        other["presentation_to_preserve"]["visual"]["variant"] = -999
        self.assertNotEqual(importer.sharing_identity(atlas), importer.sharing_identity(other))

    def test_all_source_references_remain_unchanged(self):
        plan = json.loads((ROOT / "data/animation_authoring_sources.json").read_text())
        self.assertEqual(len(plan["targets"]), 222)
        for target in plan["targets"]:
            reference = target["reference"]
            self.assertEqual(importer.sha(ROOT / reference["path"].removeprefix("res://")), reference["sha256"], target["key"])

    def test_actual_imports_have_separated_distinct_articulated_poses(self):
        for actor, specs in {"werewolf": [("poses.png", 13)], "ogre": [("poses.png", 13)],
                             "lava_golem": [("poses.png", 13)], "ice_golem": [("poses.png", 13)], "cockatrice": [("poses.png", 13)], "ghost": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "reaper_female": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "cyclops": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "spear_captain": [("poses-0.png", 8), ("poses-1.png", 5)]}.items():
            folder = ROOT / "assets/actors/eight_direction/original_based" / actor
            proof = json.loads((folder / "provenance.json").read_text())
            self.assertEqual(proof["distinct_pixel_frames"], 104)
            parts = []
            for index, (name, rows) in enumerate(specs):
                reference_rows = ([0, 1] if index == 0 else [1]) if len(specs) > 1 else None
                parts.append(importer.analyze(folder / name, rows, reference_rows, parts[0]["neutral_height"] if parts else None))
            self.assertEqual(sum(part["distinct_pixel_frames"] for part in parts), 104)
            for atlas in {entry["path"]: entry for role in proof["tracks"].values() for entry in role["atlas_files"]}.values():
                self.assertEqual(importer.sha(ROOT / atlas["path"].removeprefix("res://")), atlas["sha256"])

    def test_runtime_tracks_keep_all_real_frames_and_non_looping_actions(self):
        for actor in ("werewolf", "ghost", "reaper_female", "ogre", "lava_golem", "ice_golem", "cockatrice", "cyclops", "spear_captain"):
            path = ROOT / "assets/actors/eight_direction/original_based" / actor / "SpriteFrames.tres"
            _, frames, tracks = audit.read_spriteframes(path)
            self.assertEqual(len(frames), 104)
            self.assertEqual(len(tracks), 40)
            used = []
            for role, rows in importer.ROLES.items():
                for direction in range(8):
                    track = tracks[f"{role}_{direction}"]
                    self.assertEqual(len(track["frames"]), len(rows))
                    self.assertEqual(track["loop"], role in ("idle", "walk"))
                    used.extend(frame["texture"] for frame in track["frames"])
            self.assertEqual(len(set(used)), 104)

    def test_cannot_substitute_a_different_original_for_shared_output(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "data").mkdir()
            shutil.copy(ROOT / "data/animation_authoring_sources.json", root / "data")
            with self.assertRaisesRegex(ValueError, "different original"):
                importer.import_sheet(root, {}, "wrong_shared_actor", ["monster:늑대인간", "monster:고스트"], True)
            self.assertFalse((root / "assets").exists())

    def test_changed_original_cannot_be_used_or_overwritten(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            plan = json.loads((ROOT / "data/animation_authoring_sources.json").read_text())
            target = next(row for row in plan["targets"] if row["key"] == "monster:늑대인간")
            path = root / target["reference"]["path"].removeprefix("res://")
            path.parent.mkdir(parents=True)
            path.write_bytes(b"intentionally invalid test reference, never game art")
            (root / "data").mkdir()
            (root / "data/animation_authoring_sources.json").write_text(json.dumps(plan))
            with self.assertRaisesRegex(ValueError, "Original reference bytes changed"):
                importer.import_sheet(root, {}, "werewolf", [target["key"]], True)
            self.assertEqual(path.read_bytes(), b"intentionally invalid test reference, never game art")


if __name__ == "__main__":
    unittest.main()
