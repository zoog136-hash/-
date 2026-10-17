"""Optional whole-PNG input tests. Synthetic rectangles are never game art.

The established sheet parser/fixtures/tests remain unchanged. These tests pin
the stronger global temporal contract and lossless metadata-only installation.
"""
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import import_original_based_motion as importer
import audit_eight_direction_coverage as audit


class PoseFileImportTest(unittest.TestCase):
    def fixture(self, root, walk=3):
        (root / "data").mkdir()
        reference = root / "assets/reference.png"
        reference.parent.mkdir()
        Image.new("RGBA", (16, 16), (80, 120, 160, 255)).save(reference)
        target = {"key": "monster:fixture", "name": "fixture", "group": "normal_monster",
                  "reference": {"kind": "existing_family_portrait", "path": "res://assets/reference.png",
                                "sha256": importer.sha(reference), "image_size": [16, 16]},
                  "presentation_to_preserve": {"visual": {"body": "fixture"}, "visual_height": 80}}
        (root / "data/animation_authoring_sources.json").write_text(json.dumps({"targets": [target]}))
        (root / "data/combat_animation_profiles.json").write_text(json.dumps({"schema": 1, "profiles": {}}))
        counts = {role: len(rows) for role, rows in importer.ROLES.items()}
        counts["walk"] = walk
        poses = []
        source_dir = root / "input"
        source_dir.mkdir()
        for role, count in counts.items():
            for direction in importer.DIRECTIONS:
                for phase in range(count):
                    pixels = np.zeros((96, 96, 4), dtype=np.uint8)
                    pixels[16:61, 32:56] = (20 + len(poses), 100, 160, 255)
                    path = source_dir / f"{role}-{direction}-{phase}.png"
                    Image.fromarray(pixels).save(path)
                    poses.append({"id": f"{role}-{direction}-{phase}", "role": role,
                                  "direction": direction, "phase": phase, "output_path": str(path),
                                  "source_sha256": importer.sha(path), "canvas_size": 128,
                                  "source_anchor": [48, 60],
                                  "scale_review_note": "Synthetic guard fixture, not an anatomy/art approval"})
        candidate = {"input_mode": "pose_files_v1", "texture_binding": "individual_png_metadata",
                     "key": target["key"], "prompt": "Synthetic immutable input fixture; never production artwork",
                     "phase_counts": counts, "expected_distinct_poses": len(poses), "poses": poses,
                     "display_height_basis": "max_living_frame",
                     "review": {"identity_preserved": True, "eight_views": True,
                                "motion_roles": True, "no_clipping": True,
                                "notes": "Synthetic contract fixture, never game-art completion"}}
        folder = root / "assets/actors/eight_direction/original_based/fixture"
        return candidate, [target["key"]], folder

    def snapshot(self, root):
        return {str(path.relative_to(root)): (path.stat().st_mtime_ns, importer.sha(path)) if path.is_file() else None
                for path in root.rglob("*")}

    def rejected_without_writes(self, root, candidate, keys, apply=True):
        before = self.snapshot(root)
        with self.assertRaises((ValueError, OSError)):
            importer.import_sheet(root, candidate, "fixture", keys, apply)
        self.assertEqual(self.snapshot(root), before)

    def alter_png(self, pose, edit):
        path = Path(pose["output_path"])
        with Image.open(path) as image:
            pixels = np.asarray(image).copy()
        edit(pixels)
        Image.fromarray(pixels).save(path)
        pose["source_sha256"] = importer.sha(path)

    def test_complete_104_and_112_copy_every_byte_and_audit_all_tracks(self):
        for walk, total in [(3, 104), (4, 112)]:
            with self.subTest(walk=walk), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                candidate, keys, folder = self.fixture(root, walk)
                inputs = {pose["id"]: Path(pose["output_path"]).read_bytes() for pose in candidate["poses"]}
                result = importer.import_sheet(root, candidate, "fixture", keys, True)
                self.assertEqual(result["poses"], total)
                self.assertEqual(result["completed_added"], 0)
                self.assertEqual(result["actual_Main"], "not_run")
                proof = json.loads((folder / "provenance.json").read_text())
                self.assertEqual(proof["input_representation"], "pose_files_v1")
                self.assertEqual(len(proof["pose_files"]), total)
                for pose in proof["pose_files"]:
                    output = root / pose["file"].removeprefix("res://")
                    self.assertEqual(output.read_bytes(), inputs[pose["id"]])
                    self.assertEqual(importer.sha(output), pose["source_sha256"])
                _, frames, tracks = audit.read_spriteframes(folder / "SpriteFrames.tres")
                self.assertEqual(len(frames), total)
                self.assertEqual(len(tracks), 40)
                used = []
                for role, count in candidate["phase_counts"].items():
                    for direction in range(8):
                        track = tracks[f"{role}_{direction}"]
                        self.assertEqual(len(track["frames"]), count)
                        self.assertEqual(track["loop"], role in ("idle", "walk"))
                        self.assertAlmostEqual(track["speed"], count / importer.SECONDS[role], places=7)
                        used.extend(frame["texture"] for frame in track["frames"])
                self.assertEqual(len(used), len(set(used)))
                tracked = {str(path.relative_to(root)) for path in root.rglob("*") if path.is_file()}
                resource_path = "res://" + str((folder / "SpriteFrames.tres").relative_to(root))
                checked = audit.audit_resource(root, resource_path, tracked)
                self.assertEqual(checked["errors"], [])
                self.assertEqual(checked["pixel_integrity"], "verified")
                profiles = json.loads((root / "data/combat_animation_profiles.json").read_text())["profiles"]
                self.assertAlmostEqual(profiles[keys[0]]["movement_fps"], walk / importer.SECONDS["walk"])

    def test_api_and_cli_validation_are_read_only_including_apply_flag(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidate, keys, folder = self.fixture(root)
            recipe = root / "candidate.json"
            recipe.write_text(json.dumps(candidate))
            before = self.snapshot(root)
            report = importer.validate_pose_files(root, candidate, "fixture", keys)
            self.assertTrue(report["read_only"] and report["profiles_checked"])
            self.assertFalse(report["applied"])
            self.assertEqual(len(report["output_files"]), 106)
            self.assertFalse(folder.exists())
            for extra in ([], ["--apply"]):
                result = subprocess.run([sys.executable, str(ROOT / "tools/import_original_based_motion.py"),
                                         "--root", str(root), "--validate-candidate", str(recipe),
                                         "--actor", "fixture", "--key", keys[0], *extra], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue(json.loads(result.stdout)["read_only"])
                self.assertEqual(self.snapshot(root), before)

    def test_existing_cli_without_apply_still_installs_only_assets(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidate, keys, folder = self.fixture(root)
            recipe = root / "candidate.json"
            recipe.write_text(json.dumps(candidate))
            catalog = root / "data/combat_animation_profiles.json"
            prior = catalog.read_bytes()
            result = subprocess.run([sys.executable, str(ROOT / "tools/import_original_based_motion.py"),
                                     "--root", str(root), "--candidate", str(recipe),
                                     "--actor", "fixture", "--key", keys[0]], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((folder / "SpriteFrames.tres").exists())
            self.assertEqual(catalog.read_bytes(), prior)

    def test_minima_missing_32_extra_noncontiguous_and_duplicate_slots_are_refused(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            good, keys, _ = self.fixture(root, 4)
            variants = []
            bad = copy.deepcopy(good); bad["poses"] = [p for p in bad["poses"] if p["role"] == "walk"]; variants.append(bad)
            bad = copy.deepcopy(good); bad["poses"].pop(); variants.append(bad)
            bad = copy.deepcopy(good); bad["poses"].append(copy.deepcopy(bad["poses"][0])); variants.append(bad)
            bad = copy.deepcopy(good); bad["poses"][1]["phase"] = 0; variants.append(bad)
            bad = copy.deepcopy(good); bad["poses"][0]["direction"] = "NW-ish"; variants.append(bad)
            bad = copy.deepcopy(good); bad["poses"][0]["phase"] = 4; variants.append(bad)
            for role in ("walk", "attack", "death"):
                bad = copy.deepcopy(good); bad["phase_counts"][role] = 2; variants.append(bad)
            bad = copy.deepcopy(good); bad["expected_distinct_poses"] = 104; variants.append(bad)
            bad = copy.deepcopy(good); bad["phase_counts"]["walk"] = True; variants.append(bad)
            bad = copy.deepcopy(good); bad["poses"][0]["role"] = "cast"; variants.append(bad)
            for bad in variants: self.rejected_without_writes(root, bad, keys)

    def test_modes_fields_canvas_anchors_pins_and_review_are_explicit(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            good, keys, _ = self.fixture(root)
            variants = []
            for mode in ("registered_direct_png", None):
                bad = copy.deepcopy(good); bad["texture_binding"] = mode; variants.append(bad)
            bad = copy.deepcopy(good); bad["sheets"] = []; variants.append(bad)
            bad = copy.deepcopy(good); bad["input_mode"] = "unknown"; variants.append(bad)
            bad = copy.deepcopy(good); bad["poses"][0]["source_sha256"] = "0" * 64; variants.append(bad)
            bad = copy.deepcopy(good); del bad["poses"][0]["source_sha256"]; variants.append(bad)
            for value in (63, 2049, True):
                bad = copy.deepcopy(good); bad["poses"][0]["canvas_size"] = value; variants.append(bad)
            for value in ([48, 90], [True, 60], [48, 60, 1]):
                bad = copy.deepcopy(good); bad["poses"][0]["source_anchor"] = value; variants.append(bad)
            bad = copy.deepcopy(good); bad["poses"][0]["scale_review_note"] = " "; variants.append(bad)
            bad = copy.deepcopy(good); bad["review"]["eight_views"] = False; variants.append(bad)
            bad = copy.deepcopy(good); bad["review"]["notes"] = ""; variants.append(bad)
            bad = copy.deepcopy(good); bad["poses"][1]["id"] = bad["poses"][0]["id"]; variants.append(bad)
            for bad in variants: self.rejected_without_writes(root, bad, keys)

    def test_global_visible_duplicates_cannot_hide_in_rgb_padding_or_file_encoding(self):
        for disguise in ("hidden_rgb", "padding", "png_metadata"):
            with self.subTest(disguise=disguise), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                candidate, keys, _ = self.fixture(root)
                source, target = candidate["poses"][0], candidate["poses"][-1]
                with Image.open(source["output_path"]) as image: pixels = np.asarray(image).copy()
                if disguise == "padding":
                    bigger = np.zeros((112, 112, 4), dtype=np.uint8)
                    bigger[8:104, 8:104] = pixels
                    pixels = bigger
                    target["source_anchor"] = [56, 68]
                else: pixels[pixels[:, :, 3] == 0] = [7, 23, 40, 0]
                Image.fromarray(pixels).save(target["output_path"], compress_level=1)
                target["source_sha256"] = importer.sha(Path(target["output_path"]))
                self.rejected_without_writes(root, candidate, keys)

    def test_reusing_same_file_or_raw_pixels_is_refused_globally(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            good, keys, _ = self.fixture(root)
            bad = copy.deepcopy(good)
            bad["poses"][-1]["output_path"] = bad["poses"][0]["output_path"]
            bad["poses"][-1]["source_sha256"] = bad["poses"][0]["source_sha256"]
            self.rejected_without_writes(root, bad, keys)
            bad = copy.deepcopy(good)
            Path(bad["poses"][-1]["output_path"]).write_bytes(Path(bad["poses"][0]["output_path"]).read_bytes())
            bad["poses"][-1]["source_sha256"] = bad["poses"][0]["source_sha256"]
            self.rejected_without_writes(root, bad, keys)

    def test_whole_png_geometry_rejects_multipose_clipping_empty_and_detached_pixels(self):
        for defect in ("multipose", "boundary", "empty", "small_outside", "island_inside"):
            with self.subTest(defect=defect), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                candidate, keys, _ = self.fixture(root)
                def edit(pixels):
                    if defect == "multipose": pixels[68:90, 65:85] = [200, 30, 20, 255]
                    elif defect == "boundary": pixels[0, 40] = [200, 30, 20, 255]
                    elif defect == "empty": pixels[:] = 0
                    elif defect == "small_outside": pixels[80:82, 80:82] = [200, 30, 20, 255]
                    else:
                        pixels[30:36, 32:38] = 0
                        pixels[32:34, 34:36] = [200, 30, 20, 255]
                self.alter_png(candidate["poses"][-1], edit)
                self.rejected_without_writes(root, candidate, keys)

    def test_real_rgba_png_and_plain_paths_are_required(self):
        for defect in ("rgb", "symlink", "traversal"):
            with self.subTest(defect=defect), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                candidate, keys, _ = self.fixture(root)
                pose = candidate["poses"][-1]
                path = Path(pose["output_path"])
                if defect == "rgb":
                    with Image.open(path) as image: image.convert("RGB").save(path)
                    pose["source_sha256"] = importer.sha(path)
                elif defect == "symlink":
                    link = root / "linked.png"; link.symlink_to(path); pose["output_path"] = str(link)
                else: pose["output_path"] = str(root / "input/../input" / path.name)
                self.rejected_without_writes(root, candidate, keys)

    def test_reference_and_presentation_sharing_remain_strict(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidate, keys, _ = self.fixture(root)
            plan_path = root / "data/animation_authoring_sources.json"
            plan = json.loads(plan_path.read_text())
            second = copy.deepcopy(plan["targets"][0])
            second["key"] = "monster:other"; second["name"] = "other"
            second["presentation_to_preserve"]["visual_height"] += 1
            plan["targets"].append(second); plan_path.write_text(json.dumps(plan))
            self.rejected_without_writes(root, candidate, keys + [second["key"]])
            reference = root / "assets/reference.png"
            Image.new("RGBA", (16, 16), (1, 2, 3, 255)).save(reference)
            self.rejected_without_writes(root, candidate, keys)

    def test_later_output_and_metadata_conflicts_are_atomic(self):
        for filename in ("pose-103-death-ne-2.png", "SpriteFrames.tres", "provenance.json"):
            with self.subTest(filename=filename), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                candidate, keys, folder = self.fixture(root)
                folder.mkdir(parents=True); (folder / filename).write_bytes(b"immutable prior output")
                self.rejected_without_writes(root, candidate, keys)

    def test_bad_catalog_and_completed_profiles_fail_before_any_outputs(self):
        for previous in ([], {"profiles": []}, {"profiles": {"monster:fixture": []}},
                         {"profiles": {"monster:fixture": {"frames_path": "res://assets/actors/eight_direction/native/SpriteFrames.tres", "layout": "directional8"}}}):
            with self.subTest(previous=previous), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                candidate, keys, _ = self.fixture(root)
                (root / "data/combat_animation_profiles.json").write_text(json.dumps(previous))
                self.rejected_without_writes(root, candidate, keys)

    def test_identical_reordered_reruns_preserve_all_bytes_and_mtimes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidate, keys, _ = self.fixture(root, 4)
            first = importer.import_pose_files(root, candidate, "fixture", keys, True)
            before = self.snapshot(root)
            reordered = copy.deepcopy(candidate); reordered["poses"].reverse()
            self.assertEqual(importer.import_sheet(root, reordered, "fixture", keys, True), first)
            self.assertEqual(self.snapshot(root), before)
            changed = copy.deepcopy(candidate); changed["prompt"] += " changed review"
            self.rejected_without_writes(root, changed, keys)

    def test_cast_alias_does_not_add_pixels_or_replace_mandatory_roles(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidate, keys, folder = self.fixture(root)
            candidate["action_aliases"] = {"cast": "attack"}
            self.rejected_without_writes(root, candidate, keys)
            candidate["review"]["cast_uses_authored_attack"] = True
            result = importer.import_pose_files(root, candidate, "fixture", keys, True)
            _, frames, tracks = audit.read_spriteframes(folder / "SpriteFrames.tres")
            self.assertEqual(len(frames), result["poses"])
            self.assertEqual(len(tracks), 48)
            for direction in range(8):
                self.assertEqual(tracks[f"cast_{direction}"]["frames"], tracks[f"attack_{direction}"]["frames"])

    def test_staging_copy_and_commit_failures_leave_no_partial_output(self):
        for operation in ("copy", "link"):
            with self.subTest(operation=operation), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                candidate, keys, _ = self.fixture(root)
                before = self.snapshot(root)
                original = importer.shutil.copyfile if operation == "copy" else importer.os.link
                calls = 0
                def interrupted(*args, **kwargs):
                    nonlocal calls
                    calls += 1
                    if calls == 2: raise OSError("synthetic interrupted transaction")
                    return original(*args, **kwargs)
                owner = importer.shutil if operation == "copy" else importer.os
                method = "copyfile" if operation == "copy" else "link"
                with mock.patch.object(owner, method, side_effect=interrupted):
                    with self.assertRaises(OSError): importer.import_pose_files(root, candidate, "fixture", keys, True)
                self.assertEqual(self.snapshot(root), before)

    def test_late_input_and_catalog_mutations_are_detected_before_commit(self):
        for changed in ("pose", "reference", "catalog"):
            with self.subTest(changed=changed), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                candidate, keys, folder = self.fixture(root)
                target = (Path(candidate["poses"][0]["output_path"]) if changed == "pose" else
                          root / ("assets/reference.png" if changed == "reference" else
                                  "data/combat_animation_profiles.json"))
                before = self.snapshot(root)
                original = importer.shutil.copyfile
                changed_once = False
                def external_mutation(*args, **kwargs):
                    nonlocal changed_once
                    result = original(*args, **kwargs)
                    if not changed_once:
                        changed_once = True
                        target.write_bytes(target.read_bytes() + b" ")
                    return result
                with mock.patch.object(importer.shutil, "copyfile", side_effect=external_mutation):
                    with self.assertRaises(ValueError):
                        importer.import_pose_files(root, candidate, "fixture", keys, True)
                after = self.snapshot(root)
                key = str(target.relative_to(root))
                self.assertNotEqual(after.pop(key), before.pop(key))
                self.assertEqual(after, before)
                self.assertFalse(folder.exists())

    def test_profile_commit_failure_rolls_back_new_assets(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidate, keys, _ = self.fixture(root)
            before = self.snapshot(root)
            with mock.patch.object(importer.os, "replace", side_effect=OSError("catalog install failed")):
                with self.assertRaises(OSError):
                    importer.import_pose_files(root, candidate, "fixture", keys, True)
            self.assertEqual(self.snapshot(root), before)


class MixedSourcesImportTest(unittest.TestCase):
    snapshot = PoseFileImportTest.snapshot
    rejected_without_writes = PoseFileImportTest.rejected_without_writes

    def fixture(self, root, walk=3):
        candidate, keys, folder = PoseFileImportTest().fixture(root, walk)
        sheets = []
        for role, rows in importer.ROLES.items():
            if role == "walk":
                continue
            pixels = np.zeros((len(rows) * 96, 8 * 96, 4), dtype=np.uint8)
            anchors = []
            for phase in range(len(rows)):
                for direction_index, direction in enumerate(importer.DIRECTIONS):
                    spec = next(p for p in candidate["poses"] if
                                (p["role"], p["direction"], p["phase"]) == (role, direction, phase))
                    with Image.open(spec["output_path"]) as image:
                        pixels[phase * 96:(phase + 1) * 96,
                               direction_index * 96:(direction_index + 1) * 96] = np.asarray(image)
                    anchors.append([direction_index * 96 + 48, phase * 96 + 60])
            path = root / "input" / (role + "-sheet.png")
            Image.fromarray(pixels).save(path)
            sheets.append({"id": role + "-sheet", "output_path": str(path),
                           "source_sha256": importer.sha(path), "rows": len(rows),
                           "directions": importer.DIRECTIONS.copy(), "roles": {role: list(range(len(rows)))},
                           "reference_rows": [0], "canvas_size": 128, "source_anchors": anchors,
                           "scale_review_note": "Synthetic sheet metadata, never production art approval"})
        candidate["input_mode"] = "mixed_sources_v1"
        candidate["texture_binding"] = "unchanged_png_metadata"
        candidate["sheets"] = sheets
        candidate["pose_files"] = [pose for pose in candidate.pop("poses") if pose["role"] == "walk"]
        return candidate, keys, folder

    def repack_synthetic_sheet(self, root, spec, axis, directions):
        """Synthetic fixture layout only; never process production authoring PNGs."""
        with Image.open(spec["output_path"]) as image: original = np.asarray(image).copy()
        rows = spec["rows"]
        width, height = ((rows, len(directions)) if axis == "rows" else
                         (4, rows * 2) if axis == "blocks4x2" else (len(directions), rows))
        pixels = np.zeros((height * 96, width * 96, 4), dtype=np.uint8)
        anchors = []
        for phase in range(rows):
            for local, direction in enumerate(directions):
                prior = spec["directions"].index(direction)
                row = local if axis == "rows" else phase * 2 + local // 4 if axis == "blocks4x2" else phase
                column = phase if axis == "rows" else local % 4 if axis == "blocks4x2" else local
                pixels[row * 96:(row + 1) * 96, column * 96:(column + 1) * 96] = original[
                    phase * 96:(phase + 1) * 96, prior * 96:(prior + 1) * 96]
                anchors.append([column * 96 + 48, row * 96 + 60])
        changed = copy.deepcopy(spec)
        changed["id"] += "-" + axis + "-" + "-".join(directions)
        path = root / "input" / (changed["id"] + ".png")
        Image.fromarray(pixels).save(path)
        changed.update(output_path=str(path), source_sha256=importer.sha(path),
                       directions=directions, directions_axis=axis, source_anchors=anchors)
        return changed

    def test_direction_subsets_and_all_established_sheet_axes_keep_exact_slots(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidate, keys, folder = self.fixture(root, 4)
            packed = []
            for spec in candidate["sheets"]:
                role = next(iter(spec["roles"]))
                if role == "idle":
                    for directions in (importer.DIRECTIONS[:4], importer.DIRECTIONS[4:]):
                        packed.append(self.repack_synthetic_sheet(root, spec, "columns", directions))
                elif role in ("attack", "death"):
                    axis = "rows" if role == "attack" else "blocks4x2"
                    packed.append(self.repack_synthetic_sheet(root, spec, axis, importer.DIRECTIONS.copy()))
                else: packed.append(spec)
            candidate["sheets"] = packed
            result = importer.import_mixed_sources(root, candidate, "fixture", keys, True)
            self.assertEqual(result["poses"], 112)
            tracked = {str(path.relative_to(root)) for path in root.rglob("*") if path.is_file()}
            checked = audit.audit_resource(root, "res://" + str((folder / "SpriteFrames.tres").relative_to(root)), tracked)
            self.assertEqual(checked["errors"], [])
            self.assertEqual(checked["pixel_integrity"], "verified")

    def test_full_104_and_112_union_preserves_pngs_and_existing_audit(self):
        for walk, total in [(3, 104), (4, 112)]:
            with self.subTest(walk=walk), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                candidate, keys, folder = self.fixture(root, walk)
                inputs = {spec["source_sha256"]: Path(spec["output_path"]).read_bytes()
                          for spec in candidate["sheets"] + candidate["pose_files"]}
                result = importer.import_sheet(root, candidate, "fixture", keys, True)
                proof = json.loads((folder / "provenance.json").read_text())
                self.assertEqual(result["poses"], total)
                self.assertEqual(result["completed_added"], 0)
                self.assertEqual(result["actual_Main"], "not_run")
                self.assertEqual(proof["input_representation"], "mixed_sources_v1")
                self.assertEqual(len(proof["source_poses"]), total)
                self.assertEqual(sum(s["analyzed_body_count"] for s in proof["source_files"]), total)
                self.assertEqual(sum(s["mandatory_usage_count"] for s in proof["source_files"]), total)
                for source in proof["source_files"]:
                    self.assertTrue(source["entire_png_complete"] and source["every_analyzed_body_used_once"])
                    self.assertEqual((root / source["path"].removeprefix("res://")).read_bytes(),
                                     inputs[source["sha256"]])
                _, frames, tracks = audit.read_spriteframes(folder / "SpriteFrames.tres")
                self.assertEqual(len(frames), total)
                self.assertEqual(len(tracks), 40)
                used = []
                for role, count in candidate["phase_counts"].items():
                    for direction in range(8):
                        track = tracks[f"{role}_{direction}"]
                        self.assertEqual(len(track["frames"]), count)
                        self.assertEqual(track["loop"], role in ("idle", "walk"))
                        self.assertAlmostEqual(track["speed"], count / importer.SECONDS[role], places=7)
                        used.extend(frame["texture"] for frame in track["frames"])
                self.assertEqual(len(used), len(set(used)))
                tracked = {str(path.relative_to(root)) for path in root.rglob("*") if path.is_file()}
                resource = "res://" + str((folder / "SpriteFrames.tres").relative_to(root))
                checked = audit.audit_resource(root, resource, tracked)
                self.assertEqual(checked["errors"], [])
                self.assertEqual(checked["pixel_integrity"], "verified")

    def test_readonly_api_and_cli_and_reordered_rerun_are_immutable(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidate, keys, folder = self.fixture(root, 4)
            recipe = root / "candidate.json"; recipe.write_text(json.dumps(candidate))
            before = self.snapshot(root)
            report = importer.validate_mixed_sources(root, candidate, "fixture", keys)
            self.assertTrue(report["read_only"] and report["profiles_checked"])
            self.assertFalse(report["applied"])
            self.assertEqual(self.snapshot(root), before)
            result = subprocess.run([sys.executable, str(ROOT / "tools/import_original_based_motion.py"),
                                     "--root", str(root), "--validate-candidate", str(recipe),
                                     "--actor", "fixture", "--key", keys[0], "--apply"], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(json.loads(result.stdout)["read_only"])
            self.assertEqual(self.snapshot(root), before)
            first = importer.import_mixed_sources(root, candidate, "fixture", keys, True)
            before = self.snapshot(root)
            candidate["sheets"].reverse(); candidate["pose_files"].reverse()
            self.assertEqual(importer.import_sheet(root, candidate, "fixture", keys, True), first)
            self.assertEqual(self.snapshot(root), before)
            self.assertTrue(folder.exists())

    def test_missing_overlap_gaps_minima_and_exclusion_fields_fail_without_writes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            good, keys, _ = self.fixture(root, 4)
            variants = []
            bad = copy.deepcopy(good); bad["sheets"] = []; variants.append(bad)
            bad = copy.deepcopy(good); bad["pose_files"] = []; variants.append(bad)
            bad = copy.deepcopy(good); bad["pose_files"].pop(); variants.append(bad)
            bad = copy.deepcopy(good); bad["pose_files"][0]["phase"] = 1; variants.append(bad)
            bad = copy.deepcopy(good); bad["pose_files"][0]["role"] = "idle"; variants.append(bad)
            bad = copy.deepcopy(good); bad["sheets"][0]["roles"]["idle"] = [0]; variants.append(bad)
            bad = copy.deepcopy(good); bad["sheets"][0]["roles"]["idle"] = [0, 0]; variants.append(bad)
            bad = copy.deepcopy(good); bad["sheets"][0]["excluded_rows"] = [0]; variants.append(bad)
            bad = copy.deepcopy(good); bad["sheets"][0]["phase_offset"] = 1; variants.append(bad)
            bad = copy.deepcopy(good); bad["pose_files"][0]["region"] = [0, 0, 96, 96]; variants.append(bad)
            bad = copy.deepcopy(good); bad["phase_counts"]["attack"] = 2; variants.append(bad)
            bad = copy.deepcopy(good); bad["review"]["eight_views"] = False; variants.append(bad)
            for bad in variants:
                self.rejected_without_writes(root, bad, keys)

    def test_extra_sheet_body_or_unused_row_and_standalone_multipose_are_refused(self):
        for defect in ("extra_body", "unused_row", "standalone_multipose", "detached", "clipping"):
            with self.subTest(defect=defect), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                candidate, keys, _ = self.fixture(root)
                spec = candidate["sheets"][0] if defect in ("extra_body", "unused_row") else candidate["pose_files"][0]
                path = Path(spec["output_path"])
                with Image.open(path) as image: pixels = np.asarray(image).copy()
                if defect == "unused_row":
                    extra = pixels[:96].copy(); extra[:, :, 0][extra[:, :, 3] > 0] += 1
                    pixels = np.concatenate((pixels, extra))
                    spec["rows"] = 3
                    spec["source_anchors"].extend([[i * 96 + 48, 252] for i in range(8)])
                elif defect in ("extra_body", "standalone_multipose"):
                    pixels[68:90, 65:85] = [240, 30, 20, 255]
                elif defect == "clipping": pixels[0, 40] = [240, 30, 20, 255]
                else: pixels[80:82, 80:82] = [240, 30, 20, 255]
                Image.fromarray(pixels).save(path); spec["source_sha256"] = importer.sha(path)
                self.rejected_without_writes(root, candidate, keys)

    def test_cross_kind_visible_duplicates_and_repeated_physical_sources_are_refused(self):
        for defect in ("visible_duplicate", "same_path", "same_file_bytes"):
            with self.subTest(defect=defect), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                candidate, keys, _ = self.fixture(root)
                sheet, pose = candidate["sheets"][0], candidate["pose_files"][0]
                if defect == "visible_duplicate":
                    with Image.open(sheet["output_path"]) as image: pixels = np.asarray(image)[:96, :96].copy()
                    pixels[pixels[:, :, 3] == 0] = [19, 23, 29, 0]
                    Image.fromarray(pixels).save(pose["output_path"])
                elif defect == "same_path": pose["output_path"] = sheet["output_path"]
                else: Path(pose["output_path"]).write_bytes(Path(sheet["output_path"]).read_bytes())
                pose["source_sha256"] = importer.sha(Path(pose["output_path"]))
                self.rejected_without_writes(root, candidate, keys)

    def test_bad_pins_metadata_reference_profile_and_output_conflicts_are_atomic(self):
        for defect in ("source_sha", "anchor", "canvas", "scale_note", "reference", "profile", "output"):
            with self.subTest(defect=defect), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                candidate, keys, folder = self.fixture(root)
                if defect == "source_sha": candidate["sheets"][0]["source_sha256"] = "0" * 64
                elif defect == "anchor": candidate["sheets"][0]["source_anchors"][0] = [0, 0]
                elif defect == "canvas": candidate["sheets"][0]["canvas_size"] = True
                elif defect == "scale_note": candidate["pose_files"][0]["scale_review_note"] = " "
                elif defect == "reference": (root / "assets/reference.png").write_bytes(b"changed reference")
                elif defect == "profile":
                    (root / "data/combat_animation_profiles.json").write_text(json.dumps({"profiles": {
                        keys[0]: {"frames_path": "res://assets/actors/eight_direction/native/SpriteFrames.tres", "layout": "directional8"}}}))
                else:
                    folder.mkdir(parents=True); (folder / "SpriteFrames.tres").write_bytes(b"immutable")
                self.rejected_without_writes(root, candidate, keys)

    def test_optional_transaction_rolls_back_mixed_commit_failure(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidate, keys, _ = self.fixture(root)
            before = self.snapshot(root)
            original = importer.os.link
            calls = 0
            def interrupted(*args, **kwargs):
                nonlocal calls
                calls += 1
                if calls == 2: raise OSError("mixed commit interrupted")
                return original(*args, **kwargs)
            with mock.patch.object(importer.os, "link", side_effect=interrupted):
                with self.assertRaises(OSError):
                    importer.import_mixed_sources(root, candidate, "fixture", keys, True)
            self.assertEqual(self.snapshot(root), before)


class OptionalTransactionRaceTest(unittest.TestCase):
    """Synthetic commit-boundary probes; never install real project artwork."""

    snapshot = PoseFileImportTest.snapshot

    def fixture(self, root, mode):
        owner = PoseFileImportTest() if mode == "pose_files_v1" else MixedSourcesImportTest()
        return owner.fixture(root)

    def assert_complete_installed_assets(self, root, candidate, keys, folder):
        proof = json.loads((folder / "provenance.json").read_text())
        self.assertEqual(proof["distinct_pixel_frames"], 104)
        sources = (candidate["poses"] if candidate["input_mode"] == "pose_files_v1"
                   else candidate["sheets"] + candidate["pose_files"])
        self.assertEqual(len(list(folder.glob("*.png"))), len(sources))
        self.assertEqual({importer.sha(path) for path in folder.glob("*.png")},
                         {source["source_sha256"] for source in sources})
        catalog = json.loads((root / "data/combat_animation_profiles.json").read_text())
        resource = catalog["profiles"][keys[0]]["frames_path"]
        self.assertTrue((root / resource.removeprefix("res://")).is_file())
        tracked = {str(path.relative_to(root)) for path in root.rglob("*") if path.is_file()}
        self.assertEqual(audit.audit_resource(root, resource, tracked)["errors"], [])
        self.assertFalse(list(root.glob(".pose-files-stage-*")))

    def test_interrupt_after_successful_asset_link_still_rolls_back_its_file(self):
        for mode in ("pose_files_v1", "mixed_sources_v1"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                candidate, keys, folder = self.fixture(root, mode)
                before = self.snapshot(root)
                original = importer.os.link

                def interrupted_after_link(*args, **kwargs):
                    original(*args, **kwargs)
                    raise KeyboardInterrupt("signal after successful asset link")

                with mock.patch.object(importer.os, "link", side_effect=interrupted_after_link):
                    with self.assertRaises(KeyboardInterrupt):
                        importer.import_sheet(root, candidate, "fixture", keys, True)
                self.assertEqual(self.snapshot(root), before)
                self.assertFalse(folder.exists())

    def test_catalog_writer_during_asset_links_is_preserved_and_new_assets_rollback(self):
        for mode in ("pose_files_v1", "mixed_sources_v1"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                candidate, keys, folder = self.fixture(root, mode)
                catalog = root / "data/combat_animation_profiles.json"
                before = self.snapshot(root)
                original = importer.os.link
                changed = False
                external_bytes = None

                def concurrent_writer(*args, **kwargs):
                    nonlocal changed, external_bytes
                    result = original(*args, **kwargs)
                    if not changed:
                        changed = True
                        document = json.loads(catalog.read_text())
                        document["profiles"]["monster:concurrent-writer"] = {"name": "keep external update"}
                        external_bytes = json.dumps(document).encode()
                        catalog.write_bytes(external_bytes)
                    return result

                with mock.patch.object(importer.os, "link", side_effect=concurrent_writer):
                    with self.assertRaisesRegex(ValueError, "catalog changed during asset installation"):
                        importer.import_sheet(root, candidate, "fixture", keys, True)
                self.assertEqual(catalog.read_bytes(), external_bytes)
                after = self.snapshot(root)
                before.pop("data/combat_animation_profiles.json")
                after.pop("data/combat_animation_profiles.json")
                self.assertEqual(after, before)
                self.assertFalse(folder.exists())

    def test_interrupt_after_successful_catalog_replace_keeps_referenced_assets(self):
        for mode in ("pose_files_v1", "mixed_sources_v1"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                candidate, keys, folder = self.fixture(root, mode)
                original = importer.os.replace

                def interrupted_after_commit(*args, **kwargs):
                    original(*args, **kwargs)
                    raise KeyboardInterrupt("signal after successful catalog replacement")

                with mock.patch.object(importer.os, "replace", side_effect=interrupted_after_commit):
                    with self.assertRaises(KeyboardInterrupt):
                        importer.import_sheet(root, candidate, "fixture", keys, True)
                self.assert_complete_installed_assets(root, candidate, keys, folder)

    def test_uncertain_catalog_after_attempted_commit_preserves_assets_and_reports_state(self):
        for mode in ("pose_files_v1", "mixed_sources_v1"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                candidate, keys, folder = self.fixture(root, mode)
                catalog = root / "data/combat_animation_profiles.json"
                original = importer.os.replace

                def interrupted_after_external_update(*args, **kwargs):
                    original(*args, **kwargs)
                    document = json.loads(catalog.read_text())
                    document["profiles"]["monster:concurrent-writer"] = {"name": "post-commit external update"}
                    catalog.write_text(json.dumps(document))
                    raise KeyboardInterrupt("signal after catalog changed again")

                with mock.patch.object(importer.os, "replace", side_effect=interrupted_after_external_update):
                    with self.assertRaisesRegex(RuntimeError, "catalog state is uncertain") as caught:
                        importer.import_sheet(root, candidate, "fixture", keys, True)
                self.assertIsInstance(caught.exception.__cause__, KeyboardInterrupt)
                self.assertIn("monster:concurrent-writer", json.loads(catalog.read_text())["profiles"])
                self.assert_complete_installed_assets(root, candidate, keys, folder)


if __name__ == "__main__":
    unittest.main()
