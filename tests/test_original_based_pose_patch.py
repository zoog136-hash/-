"""One-for-one repair contract. Synthetic rectangles are NEVER game artwork."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import subprocess
import tempfile
import unittest
from unittest import mock

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import import_original_based_motion as importer
import original_based_pose_patch as patcher
import original_based_motion_import_test as fixtures


class PosePatchTest(unittest.TestCase):
    def fixture(self, root, walk_count=3):
        recipe, keys, _ = fixtures.OriginalBasedImportTest().prepare_synthetic_import(root)
        if walk_count != 3:
            # Actual complete synthetic source pixels, not a forged larger proof.
            sheet = recipe['sheets'][0]
            rows = walk_count + 5
            pixels = np.zeros((rows * 64, 512, 4), dtype=np.uint8)
            for row in range(rows):
                for direction in range(8):
                    x, y = direction * 64, row * 64
                    pixels[y+20:y+44, x+20:x+36] = (1+row*8+direction, 41, 91, 255)
            Image.fromarray(pixels).save(sheet['output_path'])
            sheet.update(rows=rows, roles={'idle':[0,1], 'walk':list(range(2,2+walk_count)),
                                          'attack':list(range(2+walk_count,5+walk_count))})
        recipe_path = root / "baseline-recipe.json"
        recipe_path.write_text(json.dumps(recipe))
        importer.import_sheet(root, recipe, "fixture_base", keys, False)
        base = root / "assets/actors/eight_direction/original_based/fixture_base"
        proof = json.loads((base / "provenance.json").read_text())
        attack_row = recipe['sheets'][0]['roles']['attack'][1]
        index = next(i for i, f in enumerate(proof["frames"]) if f["sheet"] == 0 and f["row"] == attack_row and f["direction"] == "E")
        source = root / "replacement.png"
        pixels = np.zeros((128, 128, 4), dtype=np.uint8)
        pixels[30:80, 40:70] = (220, 40, 90, 255)
        Image.fromarray(pixels).save(source)
        evidence = root / "failed-review-frame.png"
        Image.new("RGBA", (8, 8), (80, 30, 20, 255)).save(evidence)
        failure = {"target_key": keys[0], "baseline_provenance_sha256": importer.sha(base / "provenance.json"),
                   "slot": {"role": "attack", "direction": "E", "phase": 1},
                   "baseline_rgba_sha256": proof["frames"][index]["rgba_sha256"],
                   "decision": "FAIL", "reason": "Synthetic failure-record contract fixture; NOT actual game review",
                   "evidence": [{"path": str(evidence), "sha256": importer.sha(evidence)}]}
        failure_path = root / "failure.json"
        failure_path.write_text(json.dumps(failure))
        candidate = {"input_mode": "pose_patch_v1", "texture_binding": "immutable_baseline_one_for_one", "key": keys[0],
            "prompt": "Synthetic replacement contract fixture; never game artwork or completion",
            "review": copy.deepcopy(recipe["review"]),
            "baseline": {"root": str(root), "actor": "fixture_base", "candidate_path": str(recipe_path),
                "candidate_sha256": importer.sha(recipe_path), "provenance_sha256": importer.sha(base / "provenance.json"),
                "resource_sha256": importer.sha(base / "SpriteFrames.tres")},
            "patches": [{"id": "synthetic-rejected-impact", "role": "attack", "direction": "E", "phase": 1,
                "baseline_frame_index": index, "baseline_rgba_sha256": proof["frames"][index]["rgba_sha256"],
                "output_path": str(source), "source_sha256": importer.sha(source), "canvas_size": 256,
                "source_anchor": [55, 78], "scale_review_note": "Synthetic geometry only; no anatomy/art approval",
                "defect_record": str(failure_path), "defect_record_sha256": importer.sha(failure_path)}]}
        return candidate, keys, base, proof

    def snapshot(self, root):
        return {str(p.relative_to(root)): (p.stat().st_mtime_ns, importer.sha(p)) if p.is_file() else None for p in root.rglob("*")}

    def test_readonly_complete_matrix_and_profile_preflight(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            c, keys, _, _ = self.fixture(root)
            before = self.snapshot(root)
            result = importer.validate_candidate(root, c, "repaired", keys)
            self.assertEqual((result["poses"], result["retained_exact"], result["replaced"]), (104, 103, 1))
            self.assertTrue(result["read_only"] and result["profiles_checked"])
            self.assertFalse(result["applied"])
            self.assertEqual(result["completed_added"], 0)
            self.assertEqual(before, self.snapshot(root))

    def test_install_preserves_whole_baseline_and_other103_pixels_and_anchors(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            c, keys, base, old = self.fixture(root)
            old_bytes = {p.name: p.read_bytes() for p in base.iterdir()}
            catalog = (root / "data/combat_animation_profiles.json").read_bytes()
            importer.import_sheet(root, c, "repaired", keys, False)
            folder = base.parent / "repaired"
            new = json.loads((folder / "provenance.json").read_text())
            replaced = c["patches"][0]["baseline_frame_index"]
            for index, f in enumerate(old["frames"]):
                if index != replaced:
                    self.assertEqual({k: v for k, v in new["frames"][index].items() if k not in ["role", "phase", "pose_id"]}, f)
            for name, body in old_bytes.items():
                self.assertEqual((base / name).read_bytes(), body)
                if name.endswith(".png"):
                    self.assertEqual((folder / name).read_bytes(), body)
            self.assertEqual(new["baseline_history"]["retired_slots"][0]["original_frame"], old["frames"][replaced])
            self.assertEqual(new["baseline_history"]["full_original_provenance"], old)
            self.assertEqual((folder / "replacement-000.png").read_bytes(), Path(c["patches"][0]["output_path"]).read_bytes())
            self.assertEqual((root / "data/combat_animation_profiles.json").read_bytes(), catalog)

    def test_larger_gaits_keep_every_retained_pose_and_the_failed_source(self):
        for walk, total in [(6, 128), (8, 144)]:
            with self.subTest(walk=walk), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                candidate, keys, base, old = self.fixture(root, walk_count=walk)
                original_pngs = {p.name:p.read_bytes() for p in base.glob('*.png')}
                preview = importer.validate_candidate(root, candidate, 'repaired', keys)
                self.assertEqual((preview['poses'], preview['retained_exact']), (total, total-1))
                importer.import_sheet(root, candidate, 'repaired', keys, False)
                new = json.loads((base.parent/'repaired/provenance.json').read_text())
                retired = candidate['patches'][0]['baseline_frame_index']
                for index, frame in enumerate(old['frames']):
                    if index != retired:
                        self.assertEqual({k:v for k,v in new['frames'][index].items()
                                          if k not in ['role','phase','pose_id']}, frame)
                self.assertEqual(new['baseline_history']['retired_slots'][0]['original_frame'], old['frames'][retired])
                for name, pixels in original_pngs.items():
                    self.assertEqual((base/name).read_bytes(), pixels)
                    self.assertEqual((base.parent/'repaired'/name).read_bytes(), pixels)

    def test_rejects_changed_sources_ambiguous_slots_missing_evidence_and_review_without_writes(self):
        for failure in ["recipe", "proof", "resource", "baseline_png", "patch_png", "slot", "old_rgba", "duplicate_slot", "phase_bool", "review", "defect", "evidence", "island", "visible_duplicate", "unchanged_bad_pose", "retained_margin"]:
            with self.subTest(failure=failure), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                c, keys, base, proof = self.fixture(root)
                patch = c["patches"][0]
                if failure in ["recipe", "proof", "resource", "baseline_png", "patch_png", "evidence"]:
                    paths = {"recipe": Path(c["baseline"]["candidate_path"]), "proof": base / "provenance.json",
                        "resource": base / "SpriteFrames.tres", "baseline_png": base / "poses-0.png",
                        "patch_png": Path(patch["output_path"]), "evidence": root / "failed-review-frame.png"}
                    paths[failure].write_bytes(b"changed-preserved-input")
                elif failure == "slot": patch["phase"] = 2
                elif failure == "old_rgba": patch["baseline_rgba_sha256"] = "0" * 64
                elif failure == "duplicate_slot": c["patches"].append(copy.deepcopy(patch))
                elif failure == "phase_bool": patch["phase"] = True
                elif failure == "review": c["review"]["eight_views"] = False
                elif failure == "defect":
                    p = Path(patch["defect_record"])
                    d = json.loads(p.read_text()); d["decision"] = "UNVERIFIED"; p.write_text(json.dumps(d))
                    patch["defect_record_sha256"] = importer.sha(p)
                elif failure == "island":
                    p = Path(patch["output_path"])
                    pixels = np.asarray(Image.open(p)).copy(); pixels[10, 10] = (120, 120, 120, 255)
                    Image.fromarray(pixels).save(p); patch["source_sha256"] = importer.sha(p)
                elif failure in ["visible_duplicate", "unchanged_bad_pose"]:
                    f = proof["frames"][0 if failure == "visible_duplicate" else patch["baseline_frame_index"]]; x, y, w, h = f["region"]
                    with Image.open(base / "poses-0.png") as im: crop = im.crop((x, y, x+w, y+h))
                    pixels = Image.new("RGBA", (128, 128)); pixels.paste(crop, (30, 30)); pixels.save(patch["output_path"])
                    patch["source_sha256"] = importer.sha(Path(patch["output_path"])); patch["source_anchor"] = [40, 45]
                else:
                    p = base / "provenance.json"; proof["frames"][0]["margin"][0] += 1; p.write_text(json.dumps(proof))
                    c["baseline"]["provenance_sha256"] = importer.sha(p)
                before = self.snapshot(root)
                with self.assertRaises((ValueError, OSError)):
                    importer.validate_candidate(root, c, "repaired", keys)
                self.assertEqual(before, self.snapshot(root))

    def test_protected_native_profile_and_existing_outputs_refuse_readonly(self):
        for conflict in ["profile", "output"]:
            with self.subTest(conflict=conflict), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp); c, keys, base, _ = self.fixture(root)
                if conflict == "profile":
                    (root / "data/combat_animation_profiles.json").write_text(json.dumps({"profiles": {keys[0]: {
                        "layout": "directional8", "frames_path": "res://assets/actors/eight_direction/protected/SpriteFrames.tres"}}}))
                else:
                    folder = base.parent / "repaired"; folder.mkdir(); (folder / "provenance.json").write_bytes(b"prior-failure")
                before = self.snapshot(root)
                with self.assertRaises(ValueError): importer.validate_candidate(root, c, "repaired", keys)
                self.assertEqual(before, self.snapshot(root))

    def test_apply_requires_pinned_separate_final_main_and_visual_review(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); c, keys, _, _ = self.fixture(root); before = self.snapshot(root)
            with self.assertRaises(ValueError): importer.import_sheet(root, c, "repaired", keys, True)
            self.assertEqual(before, self.snapshot(root))

    def test_apply_pins_all_separate_evidence_and_changes_only_target_profile(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); c, keys, base, _ = self.fixture(root)
            profiles = root / "data/combat_animation_profiles.json"
            profiles.write_text(json.dumps({"schema": 1, "profiles": {"monster:protected": {"layout": "still", "pixel_scale": 2}}}))
            geometry = importer.validate_candidate(root, c, "repaired", keys)["geometry_sha256"]
            records = {
                "headless": {"checks": 1, "failures": [], "cases": [{"folder": "repaired"}]},
                "OpenGL": {"checks": 1, "failures": [], "cases": [{"folder": "repaired", "screenshots": 1}]},
                "temporal": {"checks": 1, "failures": [], "rendered": True,
                             "cases": [{"native_phases": 104, "rendered_native_phases": 104}]},
                "visual": {"decision": "PASS", "geometry_sha256": geometry,
                           "review_stage": "Synthetic CONTRACT ONLY; never game-art approval"}}
            evidence = []
            for role, record in records.items():
                path = root / (role + ".json"); path.write_text(json.dumps(record))
                evidence.append({"role": role, "path": str(path), "sha256": importer.sha(path)})
            final = {"geometry_sha256": geometry, "review_stage": "Synthetic contract fixture; no real game verification",
                     **dict.fromkeys(["static_review", "temporal_review", "Main_headless", "Main_OpenGL", "independent_visual_review"], "PASS"),
                     "evidence": evidence}
            path = root / "final.json"; path.write_text(json.dumps(final))
            c["final_review"] = {"path": str(path), "sha256": importer.sha(path)}
            # Merely recording PASS cannot hide missing/failed native evidence.
            temp = records["temporal"].copy(); temp["rendered"] = False
            temporal = root / "temporal.json"; temporal.write_text(json.dumps(temp)); final["evidence"][2]["sha256"] = importer.sha(temporal)
            path.write_text(json.dumps(final)); c["final_review"]["sha256"] = importer.sha(path)
            before = self.snapshot(root)
            with self.assertRaises(ValueError): importer.import_sheet(root, c, "repaired", keys, True)
            self.assertEqual(before, self.snapshot(root))
            temporal.write_text(json.dumps(records["temporal"])); final["evidence"][2]["sha256"] = importer.sha(temporal)
            path.write_text(json.dumps(final)); c["final_review"]["sha256"] = importer.sha(path)
            result = importer.import_sheet(root, c, "repaired", keys, True)
            actual = json.loads(profiles.read_text())["profiles"]
            self.assertEqual(actual["monster:protected"], {"layout": "still", "pixel_scale": 2})
            self.assertTrue(actual[keys[0]]["frames_path"].endswith("/repaired/SpriteFrames.tres"))
            self.assertEqual(result["completed_added"], 0)

    def test_cli_validate_with_apply_flag_stays_readonly(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); c, keys, _, _ = self.fixture(root)
            path = root / "patch.json"; path.write_text(json.dumps(c)); before = self.snapshot(root)
            result = subprocess.run([sys.executable, str(ROOT / "tools/import_original_based_motion.py"),
                "--root", str(root), "--validate-candidate", str(path), "--actor", "repaired", "--key", keys[0], "--apply"],
                capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(json.loads(result.stdout)["read_only"])
            self.assertEqual(before, self.snapshot(root))

    def test_copy_failure_rolls_back_without_touching_baseline_or_profiles(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); c, keys, _, _ = self.fixture(root); before = self.snapshot(root)
            with mock.patch.object(importer.shutil, "copyfile", side_effect=OSError("controlled copy failure")):
                with self.assertRaises(OSError): importer.import_sheet(root, c, "repaired", keys, False)
            self.assertEqual(before, self.snapshot(root))


if __name__ == "__main__":
    unittest.main()
