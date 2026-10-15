"""Guard exact reference identity, lossless import, and reviewed actual poses."""
import json
import copy
import hashlib
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import import_original_based_motion as importer
import audit_eight_direction_coverage as audit


class OriginalBasedImportTest(unittest.TestCase):
    def prepare_synthetic_import(self, root):
        """Small import fixtures; these colored rectangles are never game art."""
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
        sheets = []
        for index, rows in enumerate((8, 5)):
            pixels = np.zeros((rows * 64, 512, 4), dtype=np.uint8)
            for row in range(rows):
                for direction in range(8):
                    x, y = direction * 64, row * 64
                    pixels[y + 20:y + 44, x + 20:x + 36] = [30 + index * 64 + row * 8 + direction, 100, 160, 255]
            path = root / f"synthetic-{index}.png"
            Image.fromarray(pixels).save(path)
            roles = {"idle": [0, 1], "walk": [2, 3, 4], "attack": [5, 6, 7]} if index == 0 else {"hit": [0, 1], "death": [2, 3, 4]}
            sheets.append({"output_path": str(path), "rows": rows, "roles": roles, "reference_rows": [0, 1]})
        candidate = {"sheets": sheets, "prompt": "Synthetic import preservation fixture, never game art",
                     "review": {"identity_preserved": True, "eight_views": True, "motion_roles": True,
                                "no_clipping": True, "notes": "Synthetic guard fixture, not a visual art approval"}}
        return candidate, [target["key"]], root / "assets/actors/eight_direction/original_based/fixture"

    def import_snapshot(self, root):
        return {str(path.relative_to(root)): importer.sha(path) if path.is_file() else None
                for path in root.rglob("*")}

    def duplicate_synthetic_visible_pose_with_hidden_rgb(self, candidate, target_sheet=0, target_row=1):
        """Copy a test rectangle with a transparent hole, never game art."""
        source_path = Path(candidate["sheets"][0]["output_path"])
        target_path = Path(candidate["sheets"][target_sheet]["output_path"])
        with Image.open(source_path) as image:
            source = np.asarray(image).copy()
        source[28:30, 26:28] = [80, 33, 45, 0]
        cell = source[:64, :64].copy()
        cell[cell[:, :, 3] == 0] = [17, 23, 47, 0]
        if target_path == source_path:
            target = source
        else:
            with Image.open(target_path) as image:
                target = np.asarray(image).copy()
        target[target_row * 64:(target_row + 1) * 64, :64] = cell
        Image.fromarray(source).save(source_path)
        if target_path != source_path:
            Image.fromarray(target).save(target_path)

    def test_invisible_rgb_cannot_disguise_repeated_visible_pose_in_analysis_or_import(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidate, keys, _output = self.prepare_synthetic_import(root)
            self.duplicate_synthetic_visible_pose_with_hidden_rgb(candidate)
            path = Path(candidate["sheets"][0]["output_path"])
            with Image.open(path) as image:
                pixels = np.asarray(image)
            self.assertNotEqual(hashlib.sha256(pixels[17:47, 17:39].tobytes()).hexdigest(),
                                hashlib.sha256(pixels[81:111, 17:39].tobytes()).hexdigest(),
                                "The old raw-RGBA guard must be bypassed by this regression fixture")
            with self.assertRaisesRegex(ValueError, "repeated visible pose"):
                importer.analyze(path, 8, reference_rows=[0, 1])
            self.assert_import_rejected_without_writes(root, candidate, keys)

    def test_invisible_rgb_cannot_disguise_global_idle_hit_duplicate_before_writes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidate, keys, _output = self.prepare_synthetic_import(root)
            self.duplicate_synthetic_visible_pose_with_hidden_rgb(candidate, target_sheet=1, target_row=0)
            parts = [importer.analyze(Path(spec["output_path"]), spec["rows"], reference_rows=[0, 1])
                     for spec in candidate["sheets"]]
            self.assertNotEqual(parts[0]["frames"][0]["rgba_sha256"], parts[1]["frames"][0]["rgba_sha256"])
            before = self.import_snapshot(root)
            mtimes = {str(path.relative_to(root)): path.stat().st_mtime_ns for path in root.rglob("*")}
            for apply in (False, True):
                with self.subTest(apply=apply), self.assertRaisesRegex(ValueError, "Duplicate visible pose across source sheets"):
                    importer.import_sheet(root, candidate, "fixture", keys, apply)
                self.assertEqual(self.import_snapshot(root), before)
                self.assertEqual({str(path.relative_to(root)): path.stat().st_mtime_ns for path in root.rglob("*")}, mtimes)

    def test_different_transparent_border_widths_cannot_disguise_visible_duplicates(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidate, keys, _output = self.prepare_synthetic_import(root)
            self.duplicate_synthetic_visible_pose_with_hidden_rgb(candidate)
            path = Path(candidate["sheets"][0]["output_path"])
            with Image.open(path) as image:
                pixels = np.asarray(image).copy()
            body = pixels[20:44, 20:36].copy()
            pixels[:64, :64] = 0
            pixels[20:44, 1:17] = body
            Image.fromarray(pixels).save(path)
            # The leftmost body's3px crop clamps at x0, leaving a different
            # transparent border width but exactly the same rendered body.
            with self.assertRaisesRegex(ValueError, "repeated visible pose"):
                importer.analyze(path, 8, reference_rows=[0, 1])
            self.assert_import_rejected_without_writes(root, candidate, keys)

    def test_visible_motion_and_nonzero_alpha_changes_keep_raw_provenance_and_rerun(self):
        for change in ("articulated_arm", "alpha_one"):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                candidate, keys, output = self.prepare_synthetic_import(root)
                self.duplicate_synthetic_visible_pose_with_hidden_rgb(candidate)
                path = Path(candidate["sheets"][0]["output_path"])
                with Image.open(path) as image:
                    pixels = np.asarray(image).copy()
                if change == "articulated_arm":
                    pixels[94:98, 36:44] = [30, 100, 160, 255]
                else:
                    pixels[92, 26] = [17, 23, 47, 1]
                Image.fromarray(pixels).save(path)
                result = importer.import_sheet(root, candidate, "fixture", keys, True)
                proof = json.loads((output / "provenance.json").read_text())
                self.assertEqual(result["poses"], 104)
                self.assertEqual((output / "poses-0.png").read_bytes(), path.read_bytes())
                for frame in proof["frames"]:
                    if frame.get("sheet", 0) != 0:
                        continue
                    x, y, width, height = frame["region"]
                    self.assertEqual(frame["rgba_sha256"], hashlib.sha256(pixels[y:y + height, x:x + width].tobytes()).hexdigest())
                    self.assertEqual(set(frame), {"row", "direction", "region", "margin", "source_anchor", "rgba_sha256", "sheet"})
                before = self.import_snapshot(root)
                mtimes = {str(path.relative_to(root)): path.stat().st_mtime_ns for path in root.rglob("*")}
                self.assertEqual(importer.import_sheet(root, candidate, "fixture", keys, True), result)
                self.assertEqual(self.import_snapshot(root), before)
                self.assertEqual({str(path.relative_to(root)): path.stat().st_mtime_ns for path in root.rglob("*")}, mtimes)

    def prepare_direction_subset_import(self, root, groups=None, axes=None):
        """Partition 104 synthetic poses; no production artwork is transformed."""
        candidate, keys, output = self.prepare_synthetic_import(root)
        source_pixels = []
        for spec in candidate["sheets"]:
            with Image.open(spec["output_path"]) as source:
                source_pixels.append(np.asarray(source).copy())
        phases = np.concatenate(source_pixels, axis=0)
        groups = groups or [["E", "SE", "S"], ["SW"], ["W", "NW"], ["N", "NE"]]
        axes = axes or ["columns" if index % 2 == 0 else "rows" for index in range(len(groups))]
        sheets = []
        for index, (directions, axis) in enumerate(zip(groups, axes)):
            width, height = (13 * 64, len(directions) * 64) if axis == "rows" else (len(directions) * 64, 13 * 64)
            pixels = np.zeros((height, width, 4), dtype=np.uint8)
            for phase in range(13):
                for local, direction in enumerate(directions):
                    original = importer.DIRECTIONS.index(direction)
                    cell = phases[phase * 64:(phase + 1) * 64, original * 64:(original + 1) * 64]
                    x, y = (phase * 64, local * 64) if axis == "rows" else (local * 64, phase * 64)
                    pixels[y:y + 64, x:x + 64] = cell
            path = root / f"synthetic-subset-{index}.png"
            Image.fromarray(pixels).save(path)
            sheets.append({"output_path": str(path), "rows": 13, "roles": copy.deepcopy(importer.ROLES),
                           "directions": list(directions), "directions_axis": axis, "reference_rows": [0, 1],
                           "canvas_size": 256, "scale_review_note": "Synthetic equal-scale fixture; never game art"})
        candidate["sheets"] = sheets
        return candidate, keys, output

    def assert_import_rejected_without_writes(self, root, candidate, keys):
        before = self.import_snapshot(root)
        mtimes = {str(path.relative_to(root)): path.stat().st_mtime_ns for path in root.rglob("*")}
        for apply in (False, True):
            with self.subTest(apply=apply):
                with self.assertRaises(ValueError):
                    importer.import_sheet(root, candidate, "fixture", keys, apply)
                self.assertEqual(self.import_snapshot(root), before)
                self.assertEqual({str(path.relative_to(root)): path.stat().st_mtime_ns for path in root.rglob("*")}, mtimes)

    def assert_audited_mandatory_poses_complete(self, audited):
        self.assertEqual(audited["pixel_integrity"], "verified", audited["errors"])
        mandatory = {name: track for name, track in audited["tracks"].items()
                     if name.rpartition("_")[0] in importer.ROLES}
        self.assertEqual(len(mandatory), 40)
        for role, rows in importer.ROLES.items():
            for direction in range(8):
                track = mandatory[f"{role}_{direction}"]
                self.assertEqual(track["frames"], len(rows))
                self.assertEqual(track["distinct_rgba"], len(rows))
        self.assertEqual(sum(track["distinct_rgba"] for track in mandatory.values()), 104)

    def test_direction_subset_analysis_keeps_physical_packing_canonical_names_and_foot(self):
        for axis in ("columns", "rows"):
            with self.subTest(axis=axis), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                selected = ["E", "S", "N"]
                candidate, _keys, _output = self.prepare_direction_subset_import(root, [selected], [axis])
                path = Path(candidate["sheets"][0]["output_path"])
                digest = importer.sha(path)
                geometry = importer.analyze(path, 13, [0, 1], directions_axis=axis,
                                            canvas_size=256, directions=selected)
                importer.require_complete_pose_regions(path, geometry)
                self.assertEqual(geometry["distinct_pixel_frames"], 39)
                with Image.open(path) as source:
                    pixels = np.asarray(source).copy()
                anchors = []
                for phase in range(13):
                    for local, direction in enumerate(selected):
                        x, y = (phase * 64, local * 64) if axis == "rows" else (local * 64, phase * 64)
                        frame = geometry["frames"][phase * len(selected) + local]
                        self.assertEqual((frame["row"], frame["direction"]), (phase, direction))
                        self.assertEqual(frame["region"], [x + 17, y + 17, 22, 30])
                        self.assertEqual(frame["source_anchor"], [x + (32 if axis == "rows" else 28), y + 43])
                        self.assertEqual(frame["rgba_sha256"], hashlib.sha256(pixels[y + 17:y + 47, x + 17:x + 39].tobytes()).hexdigest())
                        self.assertEqual([frame["margin"][0] + frame["source_anchor"][0] - frame["region"][0],
                                          frame["margin"][1] + frame["source_anchor"][1] - frame["region"][1]], geometry["foot"])
                        anchors.append([x + 29, y + 42])
                anchored = importer.analyze(path, 13, [0, 1], directions_axis=axis, canvas_size=256,
                                            source_anchors=anchors, directions=selected)
                self.assertEqual([frame["source_anchor"] for frame in anchored["frames"]], anchors)
                self.assertEqual(importer.sha(path), digest)

    def test_direction_subsets_merge_all_runtime_tracks_and_complete_per_direction_provenance(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidate, keys, output = self.prepare_direction_subset_import(root)
            candidate["sheets"] = [candidate["sheets"][index] for index in (3, 0, 2, 1)]
            candidate["sheets"][-1]["roles"] = {role: list(reversed(rows)) for role, rows in importer.ROLES.items()}
            digests = [importer.sha(Path(spec["output_path"])) for spec in candidate["sheets"]]
            result = importer.import_sheet(root, candidate, "fixture", keys, True)
            proof = json.loads((output / "provenance.json").read_text())
            self.assertEqual(result["poses"], 104)
            self.assertEqual(proof["distinct_pixel_frames"], 104)
            paths = ["res://" + str((output / f"poses-{index}.png").relative_to(root)) for index in range(len(candidate["sheets"]))]
            external, resources, tracks = audit.read_spriteframes(output / "SpriteFrames.tres")
            self.assertEqual(list(external.values()), paths)
            self.assertEqual(len(tracks), 40)
            for role, rows in importer.ROLES.items():
                track = proof["tracks"][role]
                self.assertNotIn("source_rows", track, "Split rows must not misleadingly name one atlas")
                self.assertEqual([atlas["path"] for atlas in track["atlas_files"]], paths)
                expected_sources = {}
                for index, spec in enumerate(candidate["sheets"]):
                    atlas = track["atlas_files"][index]
                    self.assertEqual(atlas["sha256"], digests[index])
                    self.assertEqual(atlas["directions"], spec["directions"])
                    self.assertEqual(atlas["source_direction_indices"], [importer.DIRECTIONS.index(d) for d in spec["directions"]])
                    self.assertEqual(atlas["scale_review_note"], spec["scale_review_note"])
                    source_rows = spec["roles"][role]
                    for direction in spec["directions"]:
                        expected_sources[direction] = {"atlas_path": paths[index], "source_rows": source_rows}
                        runtime = tracks[f"{role}_{importer.DIRECTIONS.index(direction)}"]
                        self.assertEqual(len(runtime["frames"]), len(rows))
                        self.assertEqual(runtime["loop"], role in ("idle", "walk"))
                        for row, runtime_frame in zip(source_rows, runtime["frames"]):
                            source_frame = next(frame for frame in proof["frames"]
                                                if frame["sheet"] == index and frame["row"] == row and frame["direction"] == direction)
                            rendered = resources[runtime_frame["texture"]]
                            self.assertEqual(rendered["path"], paths[index])
                            self.assertEqual(rendered["region"], tuple(source_frame["region"]))
                self.assertEqual(track["source_rows_by_direction"], expected_sources)
                self.assertEqual(track["direction_unique_frames"], dict.fromkeys(importer.DIRECTIONS, len(rows)))
            for index, spec in enumerate(candidate["sheets"]):
                self.assertEqual(importer.sha(output / f"poses-{index}.png"), digests[index])
                self.assertEqual(importer.sha(Path(spec["output_path"])), digests[index])
            tracked = {str(path.relative_to(root)) for path in root.rglob("*") if path.is_file()}
            audited = audit.audit_resource(root, "res://" + str((output / "SpriteFrames.tres").relative_to(root)), tracked)
            self.assert_audited_mandatory_poses_complete(audited)
            snapshot = self.import_snapshot(root)
            mtimes = {str(path.relative_to(root)): path.stat().st_mtime_ns for path in root.rglob("*")}
            self.assertEqual(importer.import_sheet(root, candidate, "fixture", keys, True), result)
            self.assertEqual(self.import_snapshot(root), snapshot)
            self.assertEqual({str(path.relative_to(root)): path.stat().st_mtime_ns for path in root.rglob("*")}, mtimes)

    def test_eight_single_direction_sheets_make_104_real_poses_and_forty_tracks(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidate, keys, output = self.prepare_direction_subset_import(root, [[direction] for direction in importer.DIRECTIONS])
            self.assertEqual(importer.import_sheet(root, candidate, "fixture", keys, True)["poses"], 104)
            proof = json.loads((output / "provenance.json").read_text())
            _external, resources, tracks = audit.read_spriteframes(output / "SpriteFrames.tres")
            self.assertEqual(len(resources), 104)
            self.assertEqual(len(tracks), 40)
            for direction, name in enumerate(importer.DIRECTIONS):
                self.assertEqual({frame["direction"] for frame in proof["frames"] if frame["sheet"] == direction}, {name})
                for role, rows in importer.ROLES.items():
                    self.assertEqual(len(tracks[f"{role}_{direction}"]["frames"]), len(rows))
                    self.assertEqual(len(proof["tracks"][role]["atlas_files"]), 8)
            tracked = {str(path.relative_to(root)) for path in root.rglob("*") if path.is_file()}
            audited = audit.audit_resource(root, "res://" + str((output / "SpriteFrames.tres").relative_to(root)), tracked)
            self.assert_audited_mandatory_poses_complete(audited)

    def test_split_attack_cast_alias_inherits_all_atlases_and_direction_sources(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidate, keys, output = self.prepare_direction_subset_import(root)
            candidate["action_aliases"] = {"cast": "attack"}
            candidate["review"]["cast_uses_authored_attack"] = True
            self.assertEqual(importer.import_sheet(root, candidate, "fixture", keys, True)["poses"], 104)
            proof = json.loads((output / "provenance.json").read_text())
            cast = proof["tracks"]["cast"].copy()
            self.assertEqual(cast.pop("alias_of"), "attack")
            self.assertEqual(cast, proof["tracks"]["attack"])
            _external, _resources, tracks = audit.read_spriteframes(output / "SpriteFrames.tres")
            for direction in range(8):
                for field in ("frames", "speed", "loop"):
                    self.assertEqual(tracks[f"cast_{direction}"][field], tracks[f"attack_{direction}"][field])

    def test_single_e_walk_preview_analyzes_but_incomplete_candidate_cannot_import(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidate, keys, _output = self.prepare_direction_subset_import(root, [["E"]], ["columns"])
            spec = candidate["sheets"][0]
            path = Path(spec["output_path"])
            with Image.open(path) as source:
                pixels = np.asarray(source).copy()[2 * 64:5 * 64]
            Image.fromarray(pixels).save(path)
            spec.update({"rows": 3, "roles": {"walk": [0, 1, 2]}})
            geometry = importer.analyze(path, 3, [0, 1], canvas_size=256, directions=["E"])
            importer.require_complete_pose_regions(path, geometry)
            self.assertEqual(geometry["distinct_pixel_frames"], 3)
            self.assertEqual([(frame["direction"], frame["row"]) for frame in geometry["frames"]], [("E", 0), ("E", 1), ("E", 2)])
            self.assert_import_rejected_without_writes(root, candidate, keys)

    def test_forty_role_direction_sheets_keep_only_each_roles_atlases_and_local_rows(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidate, keys, output = self.prepare_direction_subset_import(root, [[direction] for direction in importer.DIRECTIONS])
            whole_sheets = candidate["sheets"]
            sheets = []
            order = (7, 0, 6, 1, 5, 2, 4, 3)
            for role, rows in importer.ROLES.items():
                for direction in order:
                    spec = copy.deepcopy(whole_sheets[direction])
                    with Image.open(spec["output_path"]) as source:
                        pixels = np.asarray(source).copy()
                    if spec["directions_axis"] == "rows":
                        pixels = np.concatenate([pixels[:, row * 64:(row + 1) * 64] for row in rows], axis=1)
                    else:
                        pixels = np.concatenate([pixels[row * 64:(row + 1) * 64] for row in rows], axis=0)
                    path = root / f"synthetic-role-{role}-{direction}.png"
                    Image.fromarray(pixels).save(path)
                    spec.update({"output_path": str(path), "rows": len(rows), "roles": {role: list(range(len(rows)))}})
                    sheets.append(spec)
            candidate["sheets"] = sheets
            candidate["action_aliases"] = {"cast": "attack"}
            candidate["review"]["cast_uses_authored_attack"] = True
            self.assertEqual(importer.import_sheet(root, candidate, "fixture", keys, True)["poses"], 104)
            proof = json.loads((output / "provenance.json").read_text())
            external, resources, tracks = audit.read_spriteframes(output / "SpriteFrames.tres")
            self.assertEqual(len(external), 40)
            self.assertEqual(len(resources), 104)
            self.assertEqual(len(tracks), 48)
            for role_index, (role, rows) in enumerate(importer.ROLES.items()):
                indices = list(range(role_index * 8, (role_index + 1) * 8))
                paths = ["res://" + str((output / f"poses-{index}.png").relative_to(root)) for index in indices]
                track = proof["tracks"][role]
                self.assertEqual([atlas["path"] for atlas in track["atlas_files"]], paths)
                self.assertNotIn("source_rows", track)
                for local, direction in enumerate(order):
                    name = importer.DIRECTIONS[direction]
                    self.assertEqual(track["source_rows_by_direction"][name], {"atlas_path": paths[local], "source_rows": list(range(len(rows)))})
                    runtime = tracks[f"{role}_{direction}"]
                    self.assertEqual(len(runtime["frames"]), len(rows))
                    for phase, runtime_frame in enumerate(runtime["frames"]):
                        frame = next(frame for frame in proof["frames"] if frame["sheet"] == indices[local] and frame["row"] == phase)
                        self.assertEqual(frame["direction"], name)
                        self.assertEqual(resources[runtime_frame["texture"]]["path"], paths[local])
                        self.assertEqual(resources[runtime_frame["texture"]]["region"], tuple(frame["region"]))
            alias = proof["tracks"]["cast"].copy()
            self.assertEqual(alias.pop("alias_of"), "attack")
            self.assertEqual(alias, proof["tracks"]["attack"])
            tracked = {str(path.relative_to(root)) for path in root.rglob("*") if path.is_file()}
            audited = audit.audit_resource(root, "res://" + str((output / "SpriteFrames.tres").relative_to(root)), tracked)
            self.assert_audited_mandatory_poses_complete(audited)

    def test_explicit_full_directions_preserve_legacy_geometry_metadata_and_mtimes(self):
        for axis in ("columns", "rows", "blocks4x2"):
            with self.subTest(axis=axis), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                candidate, keys, _output = self.prepare_synthetic_import(root)
                if axis == "blocks4x2":
                    self.repack_synthetic_candidate_as_blocks4x2(candidate)
                elif axis == "rows":
                    for spec in candidate["sheets"]:
                        with Image.open(spec["output_path"]) as source:
                            pixels = np.asarray(source).copy()
                        packed = np.zeros((512, spec["rows"] * 64, 4), dtype=np.uint8)
                        for phase in range(spec["rows"]):
                            for direction in range(8):
                                packed[direction * 64:(direction + 1) * 64, phase * 64:(phase + 1) * 64] = pixels[phase * 64:(phase + 1) * 64, direction * 64:(direction + 1) * 64]
                        Image.fromarray(packed).save(spec["output_path"])
                        spec["directions_axis"] = "rows"
                first = importer.import_sheet(root, candidate, "fixture", keys, True)
                snapshot = self.import_snapshot(root)
                mtimes = {str(path.relative_to(root)): path.stat().st_mtime_ns for path in root.rglob("*")}
                for spec in candidate["sheets"]:
                    default = importer.analyze(Path(spec["output_path"]), spec["rows"], [0, 1], directions_axis=axis)
                    explicit = importer.analyze(Path(spec["output_path"]), spec["rows"], [0, 1], directions_axis=axis,
                                                directions=list(importer.DIRECTIONS))
                    self.assertEqual(explicit, default)
                    spec["directions"] = list(importer.DIRECTIONS)
                self.assertEqual(importer.import_sheet(root, candidate, "fixture", keys, True), first)
                self.assertEqual(self.import_snapshot(root), snapshot)
                self.assertEqual({str(path.relative_to(root)): path.stat().st_mtime_ns for path in root.rglob("*")}, mtimes)

    def test_invalid_direction_declarations_fail_analysis_and_import_before_writes(self):
        for invalid in (None, [], "E", [1], ["Q"], ["E", "E"], ["S", "E"], ["NE", "N"]):
            with self.subTest(directions=invalid), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                candidate, keys, _output = self.prepare_synthetic_import(root)
                spec = candidate["sheets"][-1]
                spec["directions"] = invalid
                with self.assertRaises(ValueError):
                    importer.analyze(Path(spec["output_path"]), spec["rows"], directions=invalid)
                self.assert_import_rejected_without_writes(root, candidate, keys)

    def test_partial_sheet_requires_explicit_canvas_and_nonempty_string_scale_review(self):
        for field, value, remove in (("canvas_size", None, True), ("canvas_size", None, False),
                                     ("scale_review_note", None, True), ("scale_review_note", None, False),
                                     ("scale_review_note", "", False), ("scale_review_note", " \t", False),
                                     ("scale_review_note", 123, False), ("scale_review_note", False, False)):
            with self.subTest(field=field, value=value, remove=remove), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                candidate, keys, _output = self.prepare_direction_subset_import(root)
                if remove:
                    candidate["sheets"][-1].pop(field)
                else:
                    candidate["sheets"][-1][field] = value
                self.assert_import_rejected_without_writes(root, candidate, keys)

    def test_blocks4x2_rejects_partial_direction_sheets_before_writes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidate, keys, _output = self.prepare_direction_subset_import(root)
            candidate["sheets"][-1]["directions_axis"] = "blocks4x2"
            spec = candidate["sheets"][-1]
            with self.assertRaises(ValueError):
                importer.analyze(Path(spec["output_path"]), 13, directions_axis="blocks4x2", directions=spec["directions"])
            self.assert_import_rejected_without_writes(root, candidate, keys)

    def test_split_roles_reject_missing_overlapping_or_inconsistent_direction_phases(self):
        for problem in ("missing_directions", "overlapping_directions", "missing_role_direction", "missing_role",
                        "unequal_phase_count", "one_phase", "repeated_phase", "reused_other_role"):
            with self.subTest(problem=problem), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                candidate, keys, _output = self.prepare_direction_subset_import(root)
                if problem == "missing_directions":
                    candidate["sheets"].pop()
                elif problem == "overlapping_directions":
                    candidate["sheets"][-1]["directions"] = ["NW", "NE"]
                elif problem == "missing_role_direction":
                    candidate["sheets"][-1]["roles"].pop("death")
                elif problem == "missing_role":
                    for spec in candidate["sheets"]:
                        spec["roles"].pop("death")
                elif problem == "unequal_phase_count":
                    candidate["sheets"][-1]["roles"]["walk"] = [2, 3]
                elif problem == "one_phase":
                    candidate["sheets"][-1]["roles"]["idle"] = [0]
                elif problem == "repeated_phase":
                    candidate["sheets"][-1]["roles"]["idle"] = [0, 0]
                else:
                    candidate["sheets"][-1]["roles"]["hit"] = [0, 1]
                self.assert_import_rejected_without_writes(root, candidate, keys)

    def test_later_partial_sheet_pixel_failures_are_atomic_for_import_and_apply(self):
        for problem in ("global_duplicate", "foreign_crop", "visible_omission"):
            with self.subTest(problem=problem), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                groups = [["E", "SE"], ["S", "SW"], ["W", "NW"], ["N", "NE"]]
                candidate, keys, _output = self.prepare_direction_subset_import(root, groups, ["columns"] * 4)
                spec = candidate["sheets"][-1]
                path = Path(spec["output_path"])
                with Image.open(path) as source:
                    pixels = np.asarray(source).copy()
                if problem == "global_duplicate":
                    with Image.open(candidate["sheets"][0]["output_path"]) as source:
                        pixels[20:44, 20:36] = np.asarray(source)[20:44, 20:36]
                elif problem == "foreign_crop":
                    pixels[20:44, :128] = 0
                    pixels[20:44, 12:63] = [220, 100, 160, 255]
                    pixels[20:44, 64:112] = [221, 100, 160, 255]
                else:
                    pixels[52:56, 52:56] = [220, 100, 160, 255]
                Image.fromarray(pixels).save(path)
                self.assert_import_rejected_without_writes(root, candidate, keys)

    def blocks4x2_fixture_pixels(self, phases=3):
        pixels = np.zeros((phases * 128, 256, 4), dtype=np.uint8)
        for phase in range(phases):
            for direction in range(8):
                x, y = direction % 4 * 64, (phase * 2 + direction // 4) * 64
                pixels[y + 20:y + 44, x + 20:x + 36] = [10 + phase * 8 + direction, 100, 160, 255]
        return pixels

    def repack_synthetic_candidate_as_blocks4x2(self, candidate):
        # Test-only repacking of colored rectangles, never production art.
        for spec in candidate["sheets"]:
            path = Path(spec["output_path"])
            with Image.open(path) as source:
                packed = Image.new("RGBA", (256, spec["rows"] * 128))
                for phase in range(spec["rows"]):
                    for direction in range(8):
                        cell = source.crop((direction * 64, phase * 64, (direction + 1) * 64, (phase + 1) * 64))
                        packed.paste(cell, (direction % 4 * 64, (phase * 2 + direction // 4) * 64))
                packed.save(path)
            spec["directions_axis"] = "blocks4x2"

    def test_blocks4x2_normalizes_logical_phases_directions_and_foot_without_rewriting(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "synthetic-blocks.png"
            pixels = self.blocks4x2_fixture_pixels()
            Image.fromarray(pixels).save(path)
            before = importer.sha(path)
            geometry = importer.analyze(path, 3, directions_axis="blocks4x2")
            importer.require_complete_pose_regions(path, geometry)
            self.assertEqual(geometry["distinct_pixel_frames"], 24)
            anchors = []
            for phase in range(3):
                for direction in range(8):
                    frame = geometry["frames"][phase * 8 + direction]
                    x, y = direction % 4 * 64, (phase * 2 + direction // 4) * 64
                    self.assertEqual((frame["row"], frame["direction"]), (phase, importer.DIRECTIONS[direction]))
                    self.assertEqual(frame["region"], [x + 17, y + 17, 22, 30])
                    self.assertEqual(frame["source_anchor"], [x + 32, y + 43])
                    self.assertEqual(frame["rgba_sha256"], hashlib.sha256(pixels[y + 17:y + 47, x + 17:x + 39].tobytes()).hexdigest())
                    self.assertEqual([frame["margin"][0] + frame["source_anchor"][0] - frame["region"][0],
                                      frame["margin"][1] + frame["source_anchor"][1] - frame["region"][1]], geometry["foot"])
                    anchors.append([x + 29, y + 42])
            reviewed = importer.analyze(path, 3, directions_axis="blocks4x2", source_anchors=anchors)
            self.assertEqual([frame["source_anchor"] for frame in reviewed["frames"]], anchors)
            self.assertEqual(importer.sha(path), before)

    def test_blocks4x2_rejects_duplicate_cells_repeated_poses_and_unsafe_crops(self):
        for problem, message in [("cell_collision", "Each blocks4x2 cell"),
                                 ("repeated_pose", "repeated still"),
                                 ("foreign_crop", "rectangle includes another body"),
                                 ("boundary", "image boundary"),
                                 ("detached_piece", "16 visible pixels outside pose regions")]:
            with self.subTest(problem=problem), tempfile.TemporaryDirectory() as temporary:
                pixels = self.blocks4x2_fixture_pixels()
                if problem == "cell_collision":
                    pixels[20:44, 44:60] = pixels[20:44, 84:100]
                    pixels[20:44, 84:100] = 0
                elif problem == "repeated_pose":
                    pixels[20:44, 84:100] = pixels[20:44, 20:36]
                elif problem == "foreign_crop":
                    pixels[20:44, :128] = 0
                    pixels[20:44, 12:63] = [10, 100, 160, 255]
                    pixels[20:44, 64:112] = [11, 100, 160, 255]
                elif problem == "boundary":
                    pixels[0, 30] = [220, 100, 160, 255]
                else:
                    pixels[52:56, 52:56] = [220, 100, 160, 255]
                path = Path(temporary) / "unsafe-blocks.png"
                Image.fromarray(pixels).save(path)
                before = importer.sha(path)
                with self.assertRaisesRegex(ValueError, message):
                    importer.require_complete_pose_regions(path, importer.analyze(path, 3, directions_axis="blocks4x2"))
                self.assertEqual(importer.sha(path), before)

    def test_blocks4x2_import_retains_source_bytes_provenance_and_audited_runtime_tracks(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidate, keys, output = self.prepare_synthetic_import(root)
            self.repack_synthetic_candidate_as_blocks4x2(candidate)
            original_hashes = [importer.sha(Path(spec["output_path"])) for spec in candidate["sheets"]]
            result = importer.import_sheet(root, candidate, "fixture", keys, True)
            proof = json.loads((output / "provenance.json").read_text())
            self.assertEqual(result["poses"], 104)
            self.assertEqual(proof["directions"], importer.DIRECTIONS)
            for index, digest in enumerate(original_hashes):
                self.assertEqual(importer.sha(output / f"poses-{index}.png"), digest)
                self.assertEqual(importer.sha(Path(candidate["sheets"][index]["output_path"])), digest)
            for role, track in proof["tracks"].items():
                self.assertEqual(track["atlas_files"][0]["directions_axis"], "blocks4x2", role)
            tracked = {str(path.relative_to(root)) for path in root.rglob("*") if path.is_file()}
            resource = "res://" + str((output / "SpriteFrames.tres").relative_to(root))
            audited = audit.audit_resource(root, resource, tracked)
            self.assertEqual(audited["pixel_integrity"], "verified", audited["errors"])
            self.assertEqual(len(audited["tracks"]), 40)
            before = self.import_snapshot(root)
            self.assertEqual(importer.import_sheet(root, candidate, "fixture", keys, True), result)
            self.assertEqual(self.import_snapshot(root), before)

    def test_legacy_column_and_row_geometry_and_resources_remain_byte_identical(self):
        for actor in ("werewolf", "spear_guard_green"):
            with self.subTest(actor=actor):
                folder = ROOT / "assets/actors/eight_direction/original_based" / actor
                proof = json.loads((folder / "provenance.json").read_text())
                atlas_paths = list(dict.fromkeys(atlas["path"] for track in proof["tracks"].values() for atlas in track["atlas_files"]))
                atlases = {atlas["path"]: atlas for track in proof["tracks"].values() for atlas in track["atlas_files"]}
                frames, offsets = [], []
                for index, path in enumerate(atlas_paths):
                    committed = [frame for frame in proof["frames"] if frame.get("sheet", 0) == index]
                    atlas = atlases[path]
                    geometry = importer.analyze(ROOT / path.removeprefix("res://"), len(committed) // 8,
                                                directions_axis=atlas.get("directions_axis", "columns"),
                                                canvas_size=atlas.get("canvas_size", [256, 256])[0], source_anchors=[frame["source_anchor"] for frame in committed])
                    offsets.append(len(frames))
                    for frame in geometry["frames"]:
                        if len(atlas_paths) > 1:
                            frame["sheet"] = index
                    frames.extend(geometry["frames"])
                self.assertEqual(frames, proof["frames"], "All legacy crop, pixel hash, phase, direction and foot metadata must remain identical")
                roles = {}
                for role, track in proof["tracks"].items():
                    sheet_index = atlas_paths.index(track["atlas_files"][0]["path"])
                    roles[role] = [[offsets[sheet_index] + row * 8 + direction for row in track["source_rows"]] for direction in range(8)]
                self.assertEqual(importer.spriteframes(atlas_paths, {"frames": frames}, roles).encode(), (folder / "SpriteFrames.tres").read_bytes())

    def test_later_sheet_conflict_cannot_leave_an_earlier_copied_sheet(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidate, keys, output = self.prepare_synthetic_import(root)
            output.mkdir(parents=True)
            (output / "poses-1.png").write_bytes(b"preserve existing reviewed art")
            before = self.import_snapshot(root)
            for apply in (False, True):
                with self.subTest(apply=apply):
                    with self.assertRaisesRegex(ValueError, "Existing authored output differs"):
                        importer.import_sheet(root, candidate, "fixture", keys, apply)
                    self.assertEqual(self.import_snapshot(root), before)

    def test_existing_resource_and_provenance_are_never_overwritten(self):
        for filename in ("SpriteFrames.tres", "provenance.json"):
            with self.subTest(filename=filename), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                candidate, keys, output = self.prepare_synthetic_import(root)
                importer.import_sheet(root, candidate, "fixture", keys, True)
                (output / filename).write_bytes(b"preserve existing reviewed metadata")
                # A missing first sheet must not be recreated before finding
                # a later resource/proof conflict.
                (output / "poses-0.png").unlink()
                before = self.import_snapshot(root)
                with self.assertRaisesRegex(ValueError, "Existing authored output differs"):
                    importer.import_sheet(root, candidate, "fixture", keys, True)
                self.assertEqual(self.import_snapshot(root), before)

    def test_changed_review_cannot_rewrite_completed_provenance(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidate, keys, output = self.prepare_synthetic_import(root)
            importer.import_sheet(root, candidate, "fixture", keys, True)
            candidate["review"]["notes"] = "A different review requires an explicitly versioned output"
            before = self.import_snapshot(root)
            with self.assertRaisesRegex(ValueError, "provenance.json"):
                importer.import_sheet(root, candidate, "fixture", keys, True)
            self.assertEqual(self.import_snapshot(root), before)

    def test_invalid_proof_and_apply_catalog_fail_before_any_output(self):
        for invalid in ("missing_prompt", "catalog_shape", "profile_shape"):
            with self.subTest(invalid=invalid), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                candidate, keys, output = self.prepare_synthetic_import(root)
                if invalid == "missing_prompt":
                    del candidate["prompt"]
                    expected = KeyError
                else:
                    profiles = [] if invalid == "catalog_shape" else {keys[0]: []}
                    (root / "data/combat_animation_profiles.json").write_text(json.dumps({"schema": 1, "profiles": profiles}))
                    expected = ValueError
                before = self.import_snapshot(root)
                with self.assertRaises(expected):
                    importer.import_sheet(root, candidate, "fixture", keys, True)
                self.assertEqual(self.import_snapshot(root), before)
                self.assertFalse(output.exists())

    def test_completed_runtime_profile_cannot_be_replaced_by_new_art(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidate, keys, output = self.prepare_synthetic_import(root)
            profiles = {keys[0]: {"frames_path": "res://assets/actors/eight_direction/original_based/reviewed/SpriteFrames.tres"}}
            (root / "data/combat_animation_profiles.json").write_text(json.dumps({"schema": 1, "profiles": profiles}))
            before = self.import_snapshot(root)
            with self.assertRaisesRegex(ValueError, "Existing authored runtime profile differs"):
                importer.import_sheet(root, candidate, "fixture", keys, True)
            self.assertEqual(self.import_snapshot(root), before)
            self.assertFalse(output.exists())

    def test_completed_native_pack_profiles_cannot_be_replaced_by_original_based_art(self):
        for layout in ("sequential8", "directional8"):
            with self.subTest(layout=layout), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                candidate, keys, output = self.prepare_synthetic_import(root)
                importer.import_sheet(root, candidate, "fixture", keys, False)
                native_folder = root / "assets/actors/eight_direction/expanded/native_fixture"
                shutil.copytree(output, native_folder)
                native_path = "res://" + str((native_folder / "SpriteFrames.tres").relative_to(root))
                tracked = {str(path.relative_to(root)) for path in root.rglob("*") if path.is_file()}
                self.assertEqual(audit.audit_resource(root, native_path, tracked)["pixel_integrity"], "verified",
                                 "The protected synthetic native resource must satisfy actual coverage checks")
                profiles = {keys[0]: {"name": "existing completed native pack", "frames_path": native_path, "layout": layout}}
                (root / "data/combat_animation_profiles.json").write_text(json.dumps({"schema": 1, "profiles": profiles}))
                before = self.import_snapshot(root)
                with self.assertRaisesRegex(ValueError, "Existing authored runtime profile differs"):
                    importer.import_sheet(root, candidate, "fixture", keys, True)
                self.assertEqual(self.import_snapshot(root), before)

    def test_unfinished_legacy_profiles_can_receive_new_reviewed_art_and_rerun(self):
        for path, layout in (("res://assets/legacy/fixture.png", "still"),
                             ("res://assets/directional/fixture.png", "directional4")):
            with self.subTest(layout=layout), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                candidate, keys, output = self.prepare_synthetic_import(root)
                previous = {"name": "existing legacy fallback", "frames_path": path, "layout": layout}
                (root / "data/combat_animation_profiles.json").write_text(json.dumps({"schema": 1, "profiles": {keys[0]: previous}}))
                result = importer.import_sheet(root, candidate, "fixture", keys, True)
                profile = json.loads((root / "data/combat_animation_profiles.json").read_text())["profiles"][keys[0]]
                self.assertEqual(profile["prior_visual_profile"], previous)
                self.assertEqual(profile["layout"], "directional8")
                self.assertEqual(profile["frames_path"], "res://" + str((output / "SpriteFrames.tres").relative_to(root)))
                before = self.import_snapshot(root)
                self.assertEqual(importer.import_sheet(root, candidate, "fixture", keys, True), result)
                self.assertEqual(self.import_snapshot(root), before)

    def test_identical_import_rerun_preserves_all_bytes_and_mtimes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidate, keys, output = self.prepare_synthetic_import(root)
            first = importer.import_sheet(root, candidate, "fixture", keys, True)
            before = self.import_snapshot(root)
            modified = {str(path.relative_to(root)): path.stat().st_mtime_ns for path in root.rglob("*")}
            self.assertEqual(importer.import_sheet(root, candidate, "fixture", keys, True), first)
            self.assertEqual(self.import_snapshot(root), before)
            self.assertEqual({str(path.relative_to(root)): path.stat().st_mtime_ns for path in root.rglob("*")}, modified)

    def test_reviewed_cast_alias_preserves_pixels_counts_and_contact_frame(self):
        target = next(row for row in json.loads((ROOT / "data/animation_authoring_sources.json").read_text())["targets"]
                      if row["key"] == "monster:늑대인간")
        image = ROOT / "assets/actors/eight_direction/original_based/werewolf/poses.png"
        candidate = {"output_path": str(image), "prompt": "Temporary importer regression fixture, never game art",
                     "action_aliases": {"cast": "attack"},
                     "review": {"identity_preserved": True, "eight_views": True, "motion_roles": True,
                                "no_clipping": True, "cast_uses_authored_attack": True,
                                "notes": "Test explicit action sharing without adding pixels or bypassing mandatory roles"}}
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "data").mkdir()
            (root / "data/animation_authoring_sources.json").write_text(json.dumps({"targets": [target]}))
            (root / "data/combat_animation_profiles.json").write_text(json.dumps({"schema": 1, "profiles": {}}))
            reference = Path(target["reference"]["path"].removeprefix("res://"))
            (root / reference).parent.mkdir(parents=True)
            shutil.copyfile(ROOT / reference, root / reference)
            # Invalid aliases must fail before even creating an actor directory.
            for aliases, reviewed in [({"death": "idle"}, True), ({"cast": "cast"}, True),
                                      ({"cast": "missing"}, True), ({"cast": "attack"}, False)]:
                bad = copy.deepcopy(candidate)
                bad["action_aliases"] = aliases
                bad["review"]["cast_uses_authored_attack"] = reviewed
                with self.subTest(aliases=aliases, reviewed=reviewed):
                    with self.assertRaises(ValueError):
                        importer.import_sheet(root, bad, "cast_fixture", [target["key"]], True)
                    self.assertFalse((root / "assets/actors").exists())
                    self.assertEqual(json.loads((root / "data/combat_animation_profiles.json").read_text()), {"schema": 1, "profiles": {}})
            result = importer.import_sheet(root, candidate, "cast_fixture", [target["key"]], True)
            actor = Path(result["resource"])
            proof = json.loads((actor / "provenance.json").read_text())
            self.assertEqual((actor / "poses.png").read_bytes(), image.read_bytes())
            self.assertEqual(result["poses"], 104)
            self.assertEqual(len(proof["frames"]), 104)
            self.assertEqual(proof["tracks"]["cast"]["alias_of"], "attack")
            _external, _frames, tracks = audit.read_spriteframes(actor / "SpriteFrames.tres")
            for direction in range(8):
                cast, attack = tracks[f"cast_{direction}"], tracks[f"attack_{direction}"]
                self.assertEqual(cast["frames"], attack["frames"])
                self.assertEqual(cast["speed"], attack["speed"])
                self.assertFalse(cast["loop"])
            profile = json.loads((root / "data/combat_animation_profiles.json").read_text())["profiles"][target["key"]]
            self.assertEqual(profile["action_hit_frames"], {"attack": 1, "cast": 1})

    def test_reviewed_cast_alias_rerun_preserves_completed_outputs_and_profiles(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidate, keys, output = self.prepare_synthetic_import(root)
            candidate["action_aliases"] = {"cast": "attack"}
            candidate["review"]["cast_uses_authored_attack"] = True
            first = importer.import_sheet(root, candidate, "fixture", keys, True)
            before = self.import_snapshot(root)
            modified = {str(path.relative_to(root)): path.stat().st_mtime_ns for path in root.rglob("*")}
            self.assertEqual(importer.import_sheet(root, candidate, "fixture", keys, True), first)
            self.assertEqual(self.import_snapshot(root), before)
            self.assertEqual({str(path.relative_to(root)): path.stat().st_mtime_ns for path in root.rglob("*")}, modified)
            proof = json.loads((output / "provenance.json").read_text())
            self.assertEqual(proof["tracks"]["cast"]["alias_of"], "attack")
            self.assertEqual(first["poses"], 104)
            # An approved cast track is part of the completed animation.
            # A rerun cannot silently remove it from the runtime or proof.
            changed = copy.deepcopy(candidate)
            del changed["action_aliases"]
            with self.assertRaisesRegex(ValueError, "Existing authored runtime profile differs"):
                importer.import_sheet(root, changed, "fixture", keys, True)
            self.assertEqual(self.import_snapshot(root), before)

    def test_single_sheet_nonstandard_canvas_preserves_world_foot(self):
        path = ROOT / "assets/actors/eight_direction/original_based/werewolf/poses.png"
        geometry = importer.analyze(path, canvas_size=384)
        importer.require_complete_pose_regions(path, geometry)
        resource = importer.spriteframes("res://" + str(path.relative_to(ROOT)), geometry)
        self.assertTrue("metadata/twilight_canvas_size = Vector2(256, 256)" in resource,
                        "Nonstandard single-sheet canvases need runtime normalization")
        # The runtime scales the virtual canvas to 256 before applying the
        # profile's -32 world-space foot offset. Inspect every actual pose.
        for frame in geometry["frames"]:
            region = np.array(frame["region"])
            margin = np.array(frame["margin"])
            canvas = region[2:] + margin[2:]
            local_foot = margin[:2] + np.array(frame["source_anchor"]) - region[:2] - canvas / 2
            world_foot = np.array([0, -32]) + local_foot * 256 / canvas
            np.testing.assert_allclose(world_foot, [0, 0], atol=1e-9)

    def test_existing_256_single_sheet_output_is_byte_identical(self):
        for actor in ("werewolf", "ogre", "succubus", "harpy", "lycanthrope",
                      "lava_golem", "ice_golem", "cockatrice"):
            with self.subTest(actor=actor):
                folder = ROOT / "assets/actors/eight_direction/original_based" / actor
                proof = json.loads((folder / "provenance.json").read_text())
                resource = importer.spriteframes("res://" + str((folder / "poses.png").relative_to(ROOT)),
                                                 {"frames": proof["frames"]})
                self.assertEqual(resource.encode(), (folder / "SpriteFrames.tres").read_bytes())

    def test_detached_pixels_in_later_sheet_abort_before_any_output(self):
        target = next(row for row in json.loads((ROOT / "data/animation_authoring_sources.json").read_text())["targets"]
                      if row["key"] == "monster:늑대인간")
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "data").mkdir()
            (root / "data/animation_authoring_sources.json").write_text(json.dumps({"targets": [target]}))
            (root / "data/combat_animation_profiles.json").write_text(json.dumps({"profiles": {}}))
            reference = Path(target["reference"]["path"].removeprefix("res://"))
            (root / reference).parent.mkdir(parents=True)
            shutil.copyfile(ROOT / reference, root / reference)
            sheets = []
            for index, rows in enumerate((8, 5)):
                pixels = np.zeros((rows * 64, 512, 4), dtype=np.uint8)
                for row in range(rows):
                    for direction in range(8):
                        x, y = direction * 64, row * 64
                        pixels[y + 20:y + 44, x + 20:x + 36] = [30 + index * 64 + row * 8 + direction, 100, 160, 255]
                if index == 1:
                    # A distinct visible piece, outside the main body's crop.
                    pixels[30:34, 44:48] = [220, 100, 60, 255]
                path = root / f"synthetic-coverage-{index}.png"
                Image.fromarray(pixels).save(path)
                roles = {"idle": [0, 1], "walk": [2, 3, 4], "attack": [5, 6, 7]} if index == 0 else {"hit": [0, 1], "death": [2, 3, 4]}
                sheets.append({"output_path": str(path), "rows": rows, "roles": roles, "reference_rows": [0, 1]})
            candidate = {"sheets": sheets, "prompt": "Synthetic coverage guard fixture, never game art",
                         "review": {"identity_preserved": True, "eight_views": True, "motion_roles": True,
                                    "no_clipping": True, "notes": "Synthetic test of an incorrectly approved detached piece"}}
            before = {str(path.relative_to(root)): importer.sha(path) if path.is_file() else None
                      for path in root.rglob("*")}
            for apply in (False, True):
                with self.subTest(apply=apply):
                    with self.assertRaisesRegex(ValueError, "16 visible pixels outside pose regions"):
                        importer.import_sheet(root, candidate, "coverage_fixture", [target["key"]], apply)
                    after = {str(path.relative_to(root)): importer.sha(path) if path.is_file() else None
                             for path in root.rglob("*")}
                    self.assertEqual(after, before, "Rejected imports must not create or change any file or directory")

    def test_existing_family_aliases_share_only_the_same_rendered_original(self):
        targets = {row["key"]: row for row in json.loads((ROOT / "data/animation_authoring_sources.json").read_text())["targets"]}
        for names in [("고스트", "글루디오 던전 유령", "지옥의 고스트"), ("오우거", "기란 평원 오우거", "잊혀진 섬 고대오우거"),
                      ("아이언 골렘", "지옥의 아이언골렘"), ("글루디오 던전 구울", "불사의 구울"), ("도마뱀", "알비노 도마뱀"),
                      ("크랩맨", "에바 왕국 크랩맨"), ("아시타지오", "오만한 아시타지오"),
                      ("알비노 개구리", "알비노 뿔 개구리"), ("파이어 에그", "공포의 파이어 에그"),
                      ("혼 켈베로스", "잔혹한 혼 켈베로스"),
                      ("샤벨 타이거", "잔혹한 샤벨타이거"),
                      ("용의 계곡 본 드래곤", "불멸의 본 드래곤", "지옥의 본 드래곤")]:
            first = targets["monster:" + names[0]]
            for name in names[1:]:
                self.assertEqual(importer.sharing_identity(first), importer.sharing_identity(targets["monster:" + name]))
            other_attack_type = "melee" if first["presentation_to_preserve"]["attack_type"] == "magic" else "magic"
            for field, value in [("attack_type", other_attack_type), ("visual_height", 1234), ("animation_profile", {"floating": False})]:
                other = copy.deepcopy(first)
                other["presentation_to_preserve"][field] = value
                self.assertNotEqual(importer.sharing_identity(first), importer.sharing_identity(other))
            other = copy.deepcopy(first)
            other["reference"]["sha256"] = "different original"
            self.assertNotEqual(importer.sharing_identity(first), importer.sharing_identity(other))
            other = copy.deepcopy(first)
            other["presentation_to_preserve"]["visual"]["body"] = "different anatomy"
            self.assertNotEqual(importer.sharing_identity(first), importer.sharing_identity(other))
            other = copy.deepcopy(first)
            other["reference"]["image_size"] = [1, 2]
            self.assertNotEqual(importer.sharing_identity(first), importer.sharing_identity(other))
        atlas = next(row for row in targets.values() if row["reference"]["kind"] == "existing_project_atlas")
        other = copy.deepcopy(atlas)
        other["presentation_to_preserve"]["visual"]["variant"] = -999
        self.assertNotEqual(importer.sharing_identity(atlas), importer.sharing_identity(other))
        other = copy.deepcopy(atlas)
        other["reference"]["path"] = "res://assets/different-atlas.png"
        self.assertNotEqual(importer.sharing_identity(atlas), importer.sharing_identity(other))

    def test_named_reviewed_body_aliases_preserve_original_metadata(self):
        targets = {row["key"]: row for row in json.loads((ROOT / "data/animation_authoring_sources.json").read_text())["targets"]}
        for source_key, alias_key in [("monster:하피", "monster:블루 하피"),
                                      ("monster:질투의 좀비 메이드", "monster:질투의 좀비 나이트")]:
            source, alias = targets[source_key], targets[alias_key]
            before = copy.deepcopy([source, alias])
            self.assertNotEqual(source["presentation_to_preserve"]["visual"]["body"],
                                alias["presentation_to_preserve"]["visual"]["body"])
            self.assertEqual(importer.sharing_identity(source), importer.sharing_identity(alias))
            self.assertEqual([source, alias], before, "Comparison must retain each target's actual metadata")
            unreviewed = copy.deepcopy(alias)
            unreviewed.update(key="monster:unreviewed alias", name="unreviewed alias")
            self.assertNotEqual(importer.sharing_identity(source), importer.sharing_identity(unreviewed))
        self.assertEqual(importer.sharing_identity(targets["monster:하피"]),
                         importer.sharing_identity(targets["monster:풍룡의 둥지 하피"]))

    def test_reviewed_body_aliases_reject_future_reference_and_presentation_changes(self):
        targets = {row["key"]: row for row in json.loads((ROOT / "data/animation_authoring_sources.json").read_text())["targets"]}
        for reviewed in importer.REVIEWED_BODY_EQUIVALENCES:
            for key in reviewed["fallback_bodies"]:
                original = targets[key]
                changes = [("group", "boss"), ("name", "different name"),
                           ("reference.sha256", "different source"), ("reference.image_size", [1, 2]),
                           ("reference.path", "res://assets/external_l1j/monsters/different.png"),
                           ("presentation_to_preserve.visual.body", "different anatomy"),
                           ("presentation_to_preserve.visual_height", 1234),
                           ("presentation_to_preserve.attack_type", "magic"),
                           ("presentation_to_preserve.animation_profile.floating", not reviewed["floating"])]
                for field, value in changes:
                    with self.subTest(key=key, field=field):
                        changed = copy.deepcopy(original)
                        node = changed
                        components = field.split(".")
                        for component in components[:-1]: node = node[component]
                        node[components[-1]] = value
                        with self.assertRaisesRegex(ValueError, "Reviewed source presentation changed"):
                            importer.sharing_identity(changed)

    def test_reviewed_body_aliases_check_the_selected_roots_live_source_override(self):
        targets = {row["key"]: row for row in json.loads((ROOT / "data/animation_authoring_sources.json").read_text())["targets"]}
        data = json.loads((ROOT / "data/animation_presentation.json").read_text())
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "data").mkdir()
            path = root / "data/animation_presentation.json"
            for reviewed in importer.REVIEWED_BODY_EQUIVALENCES:
                keys = list(reviewed["fallback_bodies"])
                for field, value in [("body", "different rendered body"), ("sha256", "different reviewed source")]:
                    with self.subTest(path=reviewed["path"], field=field):
                        changed = copy.deepcopy(data)
                        changed["monster_sources"][reviewed["path"]][field] = value
                        path.write_text(json.dumps(changed))
                        for key in keys:
                            with self.assertRaisesRegex(ValueError, "Reviewed source presentation override changed"):
                                importer.sharing_identity(targets[key], root=root)
                path.write_text(json.dumps(data))
                self.assertEqual(importer.sharing_identity(targets[keys[0]], root=root),
                                 importer.sharing_identity(targets[keys[1]], root=root))
            path.unlink()
            with self.assertRaisesRegex(ValueError, "Reviewed source presentation cannot be verified"):
                importer.sharing_identity(targets["monster:블루 하피"], root=root)

    def test_byte_identical_portrait_alias_checks_each_actual_source_before_writing(self):
        plan = json.loads((ROOT / "data/animation_authoring_sources.json").read_text())
        targets = {row["key"]: row for row in plan["targets"]}
        keys = ["monster:샤벨 타이거", "monster:잔혹한 샤벨타이거"]
        references = [targets[key]["reference"] for key in keys]
        self.assertNotEqual(references[0]["path"], references[1]["path"])
        self.assertEqual(importer.sharing_identity(targets[keys[0]]), importer.sharing_identity(targets[keys[1]]))
        self.assertEqual(*(importer.sha(ROOT / ref["path"].removeprefix("res://")) for ref in references))
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "data").mkdir()
            (root / "data/animation_authoring_sources.json").write_text(json.dumps(plan))
            for ref in references:
                path = root / ref["path"].removeprefix("res://")
                path.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / ref["path"].removeprefix("res://"), path)
            secondary = root / references[1]["path"].removeprefix("res://")
            secondary.write_bytes(b"intentionally different secondary reference, never game art")
            with self.assertRaisesRegex(ValueError, "Original reference bytes changed"):
                importer.import_sheet(root, {}, "tiger_alias", keys, True)
            self.assertFalse((root / "assets/actors").exists())
            self.assertFalse((root / "data/combat_animation_profiles.json").exists())
            self.assertEqual(importer.sha(root / references[0]["path"].removeprefix("res://")), references[0]["sha256"])
            self.assertEqual(secondary.read_bytes(), b"intentionally different secondary reference, never game art")

    def test_all_source_references_remain_unchanged(self):
        plan = json.loads((ROOT / "data/animation_authoring_sources.json").read_text())
        self.assertEqual(len(plan["targets"]), 222)
        for target in plan["targets"]:
            reference = target["reference"]
            self.assertEqual(importer.sha(ROOT / reference["path"].removeprefix("res://")), reference["sha256"], target["key"])

    def test_actual_imports_have_separated_distinct_articulated_poses(self):
        for actor, specs in {"werewolf": [("poses.png", 13)], "ogre": [("poses.png", 13)],
                             "succubus": [("poses.png", 13)], "harpy": [("poses.png", 13)], "lycanthrope": [("poses.png", 13)],
                             "bugbear": [("poses-0.png", 8), ("poses-1.png", 5)], "sand_worm": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "reaper_male": [("poses-0.png", 7), ("poses-1.png", 5)],
                             "iron_golem": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "ghoul": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "lizard": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "crabman": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "asitagio": [("poses-0.png", 8), ("poses-1.png", 4)],
                             "albino_frog": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "fire_egg": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "horn_cerberus": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "mummy_lord": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "seer_boss": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "salah": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "bone_dragon": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "king_bugbear": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "ettin": [("poses-0.png", 8), ("poses-1.png", 4)],
                             "ancient_penguin": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "albino_giant_crab": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "kraken_transform": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "snowman": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "yeti": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "ice_man": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "scorpion": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "dire_wolf": [("poses-0.png", 8), ("poses-1.png", 4)],
                             "saber_tiger": [("poses-0.png", 8), ("poses-1.png", 4)],
                             "basilisk": [("poses-0.png", 8), ("poses-1.png", 4)],
                             "lava_golem": [("poses.png", 13)], "ice_golem": [("poses.png", 13)], "cockatrice": [("poses.png", 13)], "ghost": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "reaper_female": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "cyclops": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "spear_captain": [("poses-0.png", 8), ("poses-1.png", 5)]}.items():
            folder = ROOT / "assets/actors/eight_direction/original_based" / actor
            proof = json.loads((folder / "provenance.json").read_text())
            expected_poses = 96 if actor in {"reaper_male", "asitagio", "ettin", "dire_wolf", "saber_tiger", "basilisk"} else 104
            self.assertEqual(proof["distinct_pixel_frames"], expected_poses)
            parts = []
            for index, (name, rows) in enumerate(specs):
                reference_rows = ([0, 1] if index == 0 else [1]) if len(specs) > 1 else None
                parts.append(importer.analyze(folder / name, rows, reference_rows, parts[0]["neutral_height"] if parts else None))
            self.assertEqual(sum(part["distinct_pixel_frames"] for part in parts), expected_poses)
            for atlas in {entry["path"]: entry for role in proof["tracks"].values() for entry in role["atlas_files"]}.values():
                self.assertEqual(importer.sha(ROOT / atlas["path"].removeprefix("res://")), atlas["sha256"])

    def test_runtime_tracks_keep_all_real_frames_and_non_looping_actions(self):
        for actor in ("werewolf", "ghost", "reaper_female", "ogre", "lava_golem", "ice_golem", "cockatrice", "cyclops", "spear_captain", "succubus", "harpy", "lycanthrope", "bugbear", "sand_worm", "reaper_male", "iron_golem", "ghoul", "lizard", "crabman", "asitagio", "spear_guard_green", "spear_guard", "spear_guard_red", "albino_frog", "fire_egg", "horn_cerberus", "mummy_lord", "seer_boss", "salah", "bone_dragon", "king_bugbear", "ettin", "ancient_penguin", "pan", "albino_giant_crab", "kraken_transform", "snowman", "yeti", "ice_man", "scorpion", "dire_wolf", "saber_tiger", "basilisk"):
            path = ROOT / "assets/actors/eight_direction/original_based" / actor / "SpriteFrames.tres"
            _, frames, tracks = audit.read_spriteframes(path)
            expected_poses = 96 if actor in {"reaper_male", "asitagio", "ettin", "dire_wolf", "saber_tiger", "basilisk"} else 104
            self.assertEqual(len(frames), expected_poses)
            self.assertEqual(len(tracks), 40)
            used = []
            for role, rows in importer.ROLES.items():
                for direction in range(8):
                    track = tracks[f"{role}_{direction}"]
                    reviewed_counts = {("reaper_male", "walk"): 2, ("asitagio", "death"): 2, ("ettin", "death"): 2,
                                       ("dire_wolf", "death"): 2, ("saber_tiger", "death"): 2, ("basilisk", "death"): 2}
                    self.assertEqual(len(track["frames"]), reviewed_counts.get((actor, role), len(rows)))
                    self.assertEqual(track["loop"], role in ("idle", "walk"))
                    used.extend(frame["texture"] for frame in track["frames"])
            self.assertEqual(len(set(used)), expected_poses)
            if actor == "reaper_male":
                profile = json.loads((ROOT / "data/combat_animation_profiles.json").read_text())["profiles"]["transform:258"]
                self.assertAlmostEqual(profile["movement_fps"], 2 / importer.SECONDS["walk"])

    def test_tiger_alias_retains_each_original_path_with_one_native_resource(self):
        folder = ROOT / "assets/actors/eight_direction/original_based/saber_tiger"
        proof = json.loads((folder / "provenance.json").read_text())
        profiles = json.loads((ROOT / "data/combat_animation_profiles.json").read_text())["profiles"]
        targets = {row["key"]: row for row in json.loads((ROOT / "data/animation_authoring_sources.json").read_text())["targets"]}
        keys = ["monster:샤벨 타이거", "monster:잔혹한 샤벨타이거"]
        self.assertEqual(proof["target_keys"], keys)
        self.assertEqual(proof["target_references"], {key: targets[key]["reference"] for key in keys})
        self.assertEqual(profiles[keys[0]]["frames_path"], profiles[keys[1]]["frames_path"])
        self.assertEqual(profiles[keys[0]]["pixel_scale"], profiles[keys[1]]["pixel_scale"])
        for key in keys:
            self.assertEqual(profiles[key]["authoring_reference"], targets[key]["reference"]["path"])
        _, textures, tracks = audit.read_spriteframes(folder / "SpriteFrames.tres")
        self.assertEqual(len(textures), 96)
        self.assertEqual(len(tracks), 40)
        self.assertEqual(len({frame["path"] for frame in textures.values()}), 2)

    def test_pan_keeps_separate_real_spear_phases_and_original_identity(self):
        folder = ROOT / "assets/actors/eight_direction/original_based/pan"
        proof = json.loads((folder / "provenance.json").read_text())
        target = next(row for row in json.loads((ROOT / "data/animation_authoring_sources.json").read_text())["targets"]
                      if row["key"] == "transform:218")
        self.assertEqual(proof["reference"], target["reference"])
        self.assertEqual(proof["target_keys"], ["transform:218"])
        _, textures, tracks = audit.read_spriteframes(folder / "SpriteFrames.tres")
        hashes = set()
        for index, (phases, canvas) in enumerate([(5, 320), (3, 392), (5, 240)]):
            path = folder / f"poses-{index}.png"
            result = importer.analyze(path, phases, reference_rows=[0, 1], canvas_size=canvas)
            self.assertEqual(result["distinct_pixel_frames"], phases * 8)
            hashes.update(frame["rgba_sha256"] for frame in result["frames"])
        self.assertEqual(len(hashes), 104)
        for direction in range(8):
            for role, sheet in [("idle", 0), ("walk", 0), ("attack", 1), ("hit", 2), ("death", 2)]:
                frames = [textures[slot["texture"]] for slot in tracks[f"{role}_{direction}"]["frames"]]
                self.assertTrue(all(frame["path"].endswith(f"/poses-{sheet}.png") for frame in frames))
                self.assertEqual(len(frames), 2 if role in {"idle", "hit"} else 3)

    def test_guard_attack_uses_source_direction_rows_without_transposing_pixels(self):
        folder = ROOT / "assets/actors/eight_direction/original_based/spear_guard_green"
        proof = json.loads((folder / "provenance.json").read_text())
        _, textures, tracks = audit.read_spriteframes(folder / "SpriteFrames.tres")
        attack_atlas = proof["tracks"]["attack"]["atlas_files"][0]
        self.assertEqual(attack_atlas["directions_axis"], "rows")
        with self.assertRaises(ValueError):
            importer.analyze(folder / "poses-1.png", 3)
        anchors = [frame["source_anchor"] for frame in proof["frames"] if frame["sheet"] == 1]
        attack = importer.analyze(folder / "poses-1.png", 3, directions_axis="rows",
                                  canvas_size=224, source_anchors=anchors)
        self.assertEqual(attack["distinct_pixel_frames"], 24)
        previous_contact_y = -1
        for direction in range(8):
            frames = [textures[frame["texture"]] for frame in tracks[f"attack_{direction}"]["frames"]]
            self.assertTrue(all(frame["path"].endswith("/poses-1.png") for frame in frames))
            centers_x = [frame["region"][0] + frame["region"][2] / 2 for frame in frames]
            self.assertEqual(centers_x, sorted(centers_x))
            self.assertGreater(frames[1]["region"][1], previous_contact_y)
            previous_contact_y = frames[1]["region"][1]
        atlases = {a["path"]: a for track in proof["tracks"].values() for a in track["atlas_files"]}
        self.assertEqual(len(atlases), 3)
        for path, atlas in atlases.items():
            self.assertEqual(importer.sha(ROOT / path.removeprefix("res://")), atlas["sha256"])

    def test_guard_variants_keep_their_own_original_and_distinct_artwork(self):
        profiles = json.loads((ROOT / "data/combat_animation_profiles.json").read_text())["profiles"]
        sources = {row["key"]: row["reference"] for row in json.loads((ROOT / "data/animation_authoring_sources.json").read_text())["targets"]}
        atlas_hashes = set()
        for actor, key, canvases in [("spear_guard_green", "transform:167", [392, 224, 480]),
                                     ("spear_guard", "transform:2", [256, 352, 264]),
                                     ("spear_guard_red", "transform:110", [384, 416, 408])]:
            folder = ROOT / "assets/actors/eight_direction/original_based" / actor
            proof = json.loads((folder / "provenance.json").read_text())
            self.assertEqual(proof["reference"], sources[key])
            self.assertEqual(proof["target_keys"], [key])
            self.assertTrue(profiles[key]["frames_path"].endswith(f"/{actor}/SpriteFrames.tres"))
            for index, phases in enumerate([5, 3, 5]):
                path = folder / f"poses-{index}.png"
                digest = importer.sha(path)
                self.assertNotIn(digest, atlas_hashes, "Distinct original palettes must not share one replacement image")
                atlas_hashes.add(digest)
                anchors = [frame["source_anchor"] for frame in proof["frames"] if frame["sheet"] == index]
                result = importer.analyze(path, phases, reference_rows=[0, 1] if index != 1 else None,
                                          directions_axis="rows" if index == 1 else "columns",
                                          canvas_size=canvases[index], source_anchors=anchors)
                self.assertEqual(result["distinct_pixel_frames"], phases * 8)

    def test_guard_attack_body_size_matches_reviewed_idle_anatomy(self):
        # Helmet-to-boot landmarks were reviewed in the source sheets and Main.
        # Include the body, excluding the much longer upright/thrust spear.
        # The former 280/336 attack canvases enlarged these bodies by >20%.
        for actor, idle_height, attack_heights in [("spear_guard", 76, (101, 99)),
                                                   ("spear_guard_red", 82, (91, 89))]:
            folder = ROOT / "assets/actors/eight_direction/original_based" / actor
            _, textures, tracks = audit.read_spriteframes(folder / "SpriteFrames.tres")
            idle = textures[tracks["idle_2"]["frames"][0]["texture"]]
            idle_canvas = idle["region"][3] + idle["margin"][3]
            for direction, body_height in zip([2, 6], attack_heights):
                attack = textures[tracks[f"attack_{direction}"]["frames"][1]["texture"]]
                attack_canvas = attack["region"][3] + attack["margin"][3]
                relative_height = (body_height / attack_canvas) / (idle_height / idle_canvas)
                self.assertGreater(relative_height, .88, actor)
                self.assertLess(relative_height, 1.12, actor)

    def test_guard_first_sheet_normalization_keeps_original_display_height(self):
        folder = ROOT / "assets/actors/eight_direction/original_based/spear_guard_green"
        _, textures, tracks = audit.read_spriteframes(folder / "SpriteFrames.tres")
        profile = json.loads((ROOT / "data/combat_animation_profiles.json").read_text())["profiles"]["transform:167"]
        with Image.open(folder / "poses-0.png") as image:
            pixels = np.asarray(image)
            for direction in range(8):
                for slot in tracks[f"idle_{direction}"]["frames"]:
                    frame = textures[slot["texture"]]
                    x, y, width, height = map(int, frame["region"])
                    canvas_height = height + frame["margin"][3]
                    self.assertEqual(canvas_height, 392)
                    occupied = np.nonzero(pixels[y:y + height, x:x + width, 3] > 100)[0]
                    visible = (int(occupied.max()) - int(occupied.min()) + 1) * 256 / canvas_height * profile["pixel_scale"]
                    self.assertGreater(visible, 90)
                    self.assertLess(visible, 110)

    def test_living_poses_fit_the_existing_visual_height(self):
        # Long directional bodies and casting flames must fit the existing
        # nameplate budget with one scale; independently measure real alpha.
        cases = [("lizard", "monster:도마뱀", "monster:알비노 도마뱀", .93),
                 ("albino_frog", "monster:알비노 개구리", "monster:알비노 뿔 개구리", .85),
                 ("fire_egg", "monster:파이어 에그", "monster:공포의 파이어 에그", .85),
                 ("horn_cerberus", "monster:혼 켈베로스", "monster:잔혹한 혼 켈베로스", .85)]
        for actor, primary, alias, minimum_visible_ratio in cases:
            with self.subTest(actor=actor):
                folder = ROOT / "assets/actors/eight_direction/original_based" / actor
                proof = json.loads((folder / "provenance.json").read_text())
                self.assertEqual(proof["display_height_basis"], "max_living_frame")
                profiles = json.loads((ROOT / "data/combat_animation_profiles.json").read_text())["profiles"]
                scale = profiles[primary]["pixel_scale"]
                self.assertEqual(scale, profiles[alias]["pixel_scale"])
                budget = proof["presentation_to_preserve"]["visual_height"]
                atlases = {atlas["path"]: atlas for track in proof["tracks"].values() for atlas in track["atlas_files"]}
                pixels = {}
                for path in atlases:
                    with Image.open(ROOT / path.removeprefix("res://")) as source:
                        pixels[path] = np.asarray(source).copy()
                measured = []
                for role, track in proof["tracks"].items():
                    if role == "death":
                        continue
                    atlas = track["atlas_files"][0]
                    sheet = list(atlases).index(atlas["path"])
                    for frame in proof["frames"]:
                        if frame.get("sheet", 0) != sheet or frame["row"] not in track["source_rows"]:
                            continue
                        x, y, width, height = frame["region"]
                        occupied_rows = np.nonzero(pixels[atlas["path"]][y:y + height, x:x + width, 3] > 100)[0]
                        self.assertGreater(len(occupied_rows), 0)
                        visible_height = (int(occupied_rows.max()) - int(occupied_rows.min()) + 1) * 256 / atlas["canvas_size"][1] * scale
                        self.assertLessEqual(visible_height, budget + .001, (role, frame["direction"]))
                        measured.append(visible_height)
                self.assertEqual(len(measured), 80)
                self.assertGreater(max(measured), budget * minimum_visible_ratio)

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
