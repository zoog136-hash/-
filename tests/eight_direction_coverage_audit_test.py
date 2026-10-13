"""Ensure the coverage audit rejects duplicated poses and changed runtime art."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import audit_eight_direction_coverage as audit


class CoverageAuditTest(unittest.TestCase):
    def test_recorded_main_does_not_promote_untested_aliases_or_pose_samples(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "main.json"
            report = {"failures":[], "checks":10, "setup":{"scene":"Main.tscn"},
                      "monster":[{"name":"one", "compass":"N", "facing":6, "walk":True, "attack":True, "contacts":1}],
                      "pose_samples":[{"track":"attack_2", "frame":1}]}
            path.write_text(json.dumps(report))
            result = {"identities":[{"key":"monster:one"}, {"key":"monster:alias"}]}
            rows = [{"id":key, "direction":direction, "actual_gameplay":"not_run"} for key in ("monster:one", "monster:alias") for direction in audit.DIRECTIONS]
            audit.attach_gameplay_evidence(result, rows, [path], root)
            self.assertEqual(sum(row["actual_gameplay"] == "recorded_Main_sample" for row in rows), 1)
            self.assertEqual(result["identities"][1]["actual_gameplay"], "not_run")
            report["failures"] = ["attack failed"]
            path.write_text(json.dumps(report))
            with self.assertRaisesRegex(ValueError, "Not a successful"):
                audit.attach_gameplay_evidence(result, rows, [path], root)
            report["failures"] = []
            report["setup"]["synthetic_fixture"] = True
            path.write_text(json.dumps(report))
            with self.assertRaisesRegex(ValueError, "Synthetic fixture"):
                audit.attach_gameplay_evidence(result, rows, [path], root)

    def build_pack(self, root, repeated=False):
        folder = root / "assets/actors/eight_direction/test"
        folder.mkdir(parents=True)
        image = Image.new("RGBA", (2, 1))
        image.putdata([(200, 0, 0, 255), (0, 200, 0, 255)])
        image.save(folder / "poses.png")
        path = "res://assets/actors/eight_direction/test/SpriteFrames.tres"
        atlas_path = "res://assets/actors/eight_direction/test/poses.png"
        header = '[gd_resource type="SpriteFrames" format=3]\n[ext_resource type="Texture2D" path="' + atlas_path + '" id="atlas"]\n'
        header += '\n'.join('[sub_resource type="AtlasTexture" id="pose_%d"]\natlas = ExtResource("atlas")\nregion = Rect2(%d, 0, 1, 1)\nmargin = Rect2(0, 0, 1, 1)\n' % (index, index) for index in range(2))
        tracks = []
        for role in audit.REQUIRED_ROLES:
            for direction in range(8):
                tracks.append({"frames": [{"duration": 1.0, "texture": "pose_0"}, {"duration": 1.0, "texture": "pose_0" if repeated else "pose_1"}],
                               "loop": role in ("idle", "walk"), "name": f"{role}_{direction}", "speed": 8.0})
        block = json.dumps(tracks).replace('"pose_0"', 'SubResource("pose_0")').replace('"pose_1"', 'SubResource("pose_1")')
        (folder / "SpriteFrames.tres").write_text(header + '\n[resource]\nanimations = ' + block + '\n')
        sha = hashlib.sha256((folder / "poses.png").read_bytes()).hexdigest()
        proof = {"source": "test fixture, never production coverage", "tracks": {role: {"atlas_files": [{"path": atlas_path, "sha256": sha}],
                        "direction_unique_frames": {direction: 2 for direction in audit.DIRECTIONS}} for role in audit.REQUIRED_ROLES}}
        (folder / "provenance.json").write_text(json.dumps(proof))
        tracked = {str(file.relative_to(root)) for file in folder.iterdir()}
        return folder, path, tracked

    def test_reconstructs_distinct_source_canvas(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            _, path, tracked = self.build_pack(root)
            result = audit.audit_resource(root, path, tracked)
            self.assertEqual(result["errors"], [])
            self.assertEqual(result["tracks"]["attack_6"]["distinct_rgba"], 2)
            self.assertEqual(result["actual_gameplay"], "not_run")
            self.assertEqual(result["compass_semantics"], "source_metadata_only")

    def test_repeated_slots_cannot_count_as_motion(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            _, path, tracked = self.build_pack(root, repeated=True)
            result = audit.audit_resource(root, path, tracked)
            self.assertEqual(result["pixel_integrity"], "failed")
            self.assertIn("missing real sequential motion: attack_0", result["errors"])

    def test_changed_runtime_png_fails_delivery_integrity(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            folder, path, tracked = self.build_pack(root)
            image = Image.open(folder / "poses.png").convert("RGBA")
            image.putpixel((0, 0), (0, 0, 255, 255))
            image.save(folder / "poses.png")
            result = audit.audit_resource(root, path, tracked)
            self.assertEqual(result["pixel_integrity"], "failed")
            self.assertTrue(any("atlas SHA-256 differs" in error for error in result["errors"]))

    def test_untracked_actual_art_cannot_count_as_delivered(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            _, path, tracked = self.build_pack(root)
            tracked.remove("assets/actors/eight_direction/test/poses.png")
            result = audit.audit_resource(root, path, tracked)
            self.assertFalse(result["tracked"])
            self.assertEqual(result["pixel_integrity"], "failed")


if __name__ == "__main__":
    unittest.main()
