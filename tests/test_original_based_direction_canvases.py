"""Optional direction scales on immutable whole PNGs; synthetic fixtures only."""
import copy
import json
import re
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))
import test_original_based_pose_files as fixtures

importer, audit = fixtures.importer, fixtures.audit


class DirectionCanvasTest(unittest.TestCase):
    def fixture(self, root, walk=3):
        candidate, keys, folder = fixtures.MixedSourcesImportTest().fixture(root, walk)
        sizes = dict(zip(importer.DIRECTIONS, (160, 168, 176, 184, 192, 200, 96, 208)))
        for spec in candidate["sheets"]:
            spec["canvas_size"] = max(sizes.values())
            spec["canvas_sizes_by_direction"] = sizes.copy()
        return candidate, keys, folder

    def checked(self, root, folder):
        tracked = {str(path.relative_to(root)) for path in root.rglob("*") if path.is_file()}
        return audit.audit_resource(root, "res://" + str((folder / "SpriteFrames.tres").relative_to(root)), tracked)

    def reject(self, root, candidate, keys):
        fixtures.PoseFileImportTest().rejected_without_writes(root, candidate, keys)

    def test_full_104_and_112_preserve_whole_pngs_and_actual_direction_canvases(self):
        for walk, total in ((3, 104), (4, 112)):
            with self.subTest(walk=walk), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                candidate, keys, folder = self.fixture(root, walk)
                inputs = {s["source_sha256"]: Path(s["output_path"]).read_bytes()
                          for s in candidate["sheets"] + candidate["pose_files"]}
                importer.import_sheet(root, candidate, "fixture", keys, True)
                proof = json.loads((folder / "provenance.json").read_text())
                _, actual, _ = audit.read_spriteframes(folder / "SpriteFrames.tres")
                self.assertEqual(len(actual), total)
                self.assertEqual(sum(s["mandatory_usage_count"] for s in proof["source_files"]), total)
                self.assertAlmostEqual(proof["display_reference_height"], 51 * 256 / 96)
                for source in proof["source_files"]:
                    self.assertEqual((root / source["path"].removeprefix("res://")).read_bytes(), inputs[source["sha256"]])
                for index, (frame, record) in enumerate(zip(proof["frames"], proof["source_poses"])):
                    source = proof["source_files"][frame["sheet"]]
                    if "canvas_sizes_by_direction" not in source:
                        self.assertNotIn("canvas_size", frame)
                        continue
                    size = source["canvas_sizes_by_direction"][frame["direction"]]
                    self.assertEqual(frame["canvas_size"], [size, size])
                    self.assertEqual(frame["foot"], [size // 2, size * 5 // 8])
                    self.assertEqual(record["canvas_size"], size)
                    self.assertEqual(actual[f"pose_{index}"]["region"][2] + actual[f"pose_{index}"]["margin"][2], size)
                    self.assertEqual(actual[f"pose_{index}"]["region"][3] + actual[f"pose_{index}"]["margin"][3], size)
                self.assertEqual(self.checked(root, folder)["errors"], [])

    def test_local_frame_order_layouts_and_direction_subsets(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            candidate, keys, folder = self.fixture(root)
            packed = []
            helper = fixtures.MixedSourcesImportTest()
            for spec in candidate["sheets"]:
                role = next(iter(spec["roles"]))
                if role == "idle":
                    for selected in (importer.DIRECTIONS[:4], importer.DIRECTIONS[4:]):
                        part = helper.repack_synthetic_sheet(root, spec, "columns", selected)
                        part["canvas_sizes_by_direction"] = {d: spec["canvas_sizes_by_direction"][d] for d in selected}
                        part["canvas_size"] = max(part["canvas_sizes_by_direction"].values())
                        packed.append(part)
                else:
                    axis = "rows" if role == "attack" else "blocks4x2" if role == "death" else "columns"
                    packed.append(helper.repack_synthetic_sheet(root, spec, axis, importer.DIRECTIONS.copy()))
            candidate["sheets"] = list(reversed(packed))
            candidate["pose_files"].reverse()
            importer.import_sheet(root, candidate, "fixture", keys, True)
            self.assertEqual(self.checked(root, folder)["errors"], [])
            first = (folder / "SpriteFrames.tres").read_bytes(), (folder / "provenance.json").read_bytes()
            candidate["sheets"].reverse()
            candidate["pose_files"].reverse()
            importer.import_sheet(root, candidate, "fixture", keys, True)
            self.assertEqual(first, ((folder / "SpriteFrames.tres").read_bytes(), (folder / "provenance.json").read_bytes()))

    def test_rejects_wrong_keys_types_limits_and_ambiguous_max_without_writes(self):
        mutations = [lambda s: s.update(canvas_sizes_by_direction=None),
                     lambda s: s["canvas_sizes_by_direction"].pop("N"),
                     lambda s: s["canvas_sizes_by_direction"].update(UP=128),
                     lambda s: s.update(canvas_size=128)]
        for bad in (True, 96.0, "96", 63, 2049, [96, 96], {"phase0": 96}):
            mutations.append(lambda s, bad=bad: s["canvas_sizes_by_direction"].update(N=bad))
        for mutation in mutations:
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                candidate, keys, _ = self.fixture(root)
                mutation(candidate["sheets"][0])
                self.reject(root, candidate, keys)

    def test_smaller_declared_canvas_and_bad_anchor_cannot_escape_max_analysis(self):
        for bad_anchor in (False, True):
            with self.subTest(bad_anchor=bad_anchor), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                candidate, keys, _ = self.fixture(root)
                spec = candidate["sheets"][0]
                if bad_anchor:
                    spec["source_anchors"][0] = [0, 0]
                else:
                    spec["canvas_sizes_by_direction"]["N"] = 64
                self.reject(root, candidate, keys)

    def test_directional_field_is_for_whole_sheets_only_and_no_phase_overrides(self):
        for field in ("canvas_sizes_by_direction", "canvas_sizes_by_phase", "feet_by_direction", "foot"):
            with self.subTest(field=field), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                candidate, keys, _ = self.fixture(root)
                target = candidate["pose_files"][0] if field == "canvas_sizes_by_direction" else candidate["sheets"][0]
                target[field] = {"N": 128}
                self.reject(root, candidate, keys)

    def test_read_only_preflight_keeps_candidate_sources_and_outputs_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            candidate, keys, folder = self.fixture(root)
            before = fixtures.PoseFileImportTest().snapshot(root)
            original = copy.deepcopy(candidate)
            result = importer.validate_mixed_sources(root, candidate, "fixture", keys, True)
            self.assertTrue(result["read_only"])
            self.assertEqual(before, fixtures.PoseFileImportTest().snapshot(root))
            self.assertEqual(candidate, original)
            self.assertFalse(folder.exists())

    def test_independent_auditor_rejects_map_frame_foot_anchor_and_record_tampering(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            candidate, keys, folder = self.fixture(root)
            importer.import_sheet(root, candidate, "fixture", keys, True)
            path = folder / "provenance.json"
            original = json.loads(path.read_text())
            mapped = next(i for i, f in enumerate(original["frames"]) if "canvas_size" in f)
            mutations = [lambda p: p["source_files"][0]["canvas_sizes_by_direction"].update(N=104),
                         lambda p: p["source_files"][0]["canvas_sizes_by_direction"].pop("N"),
                         lambda p: p["frames"][mapped]["canvas_size"].__setitem__(0, 129),
                         lambda p: p["frames"][mapped]["foot"].__setitem__(1, 999),
                         lambda p: p["frames"][mapped]["source_anchor"].__setitem__(0, 0),
                         lambda p: p["source_poses"][mapped].update(canvas_size=99),
                         lambda p: p["source_poses"][mapped].update(source_frame=999),
                         lambda p: p["tracks"]["idle"]["atlas_files"][0]["canvas_sizes_by_direction"].update(N=104),
                         lambda p: p["frames"][-1].update(canvas_size=[128, 128], foot=[64, 80])]
            for mutation in mutations:
                with self.subTest(mutation=mutation):
                    changed = copy.deepcopy(original)
                    mutation(changed)
                    path.write_text(json.dumps(changed))
                    self.assertTrue(self.checked(root, folder)["errors"])
            path.write_text(json.dumps(original))
            self.assertEqual(self.checked(root, folder)["errors"], [])

    def test_actual_atlas_margin_tampering_fails_independently_of_pixels(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            candidate, keys, folder = self.fixture(root)
            importer.import_sheet(root, candidate, "fixture", keys, True)
            path = folder / "SpriteFrames.tres"
            text = path.read_text()
            self.assertIn("margin = Rect2(", text)
            changed = re.sub(r"(margin = Rect2\([^,]+,[^,]+, )(-?\d+)",
                             lambda match: match[1] + str(int(match[2]) + 8), text, count=1)
            self.assertNotEqual(changed, text)
            path.write_text(changed)
            self.assertTrue(any("provenance and actual AtlasTexture differ" in error
                                for error in self.checked(root, folder)["errors"]))

    def test_all_mixed_resources_require_exact_unique_runtime_normalization(self):
        for mapped in (False, True):
            with self.subTest(mapped=mapped), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                factory = self.fixture if mapped else fixtures.MixedSourcesImportTest().fixture
                candidate, keys, folder = factory(root)
                importer.import_sheet(root, candidate, "fixture", keys, True)
                self.assertEqual(self.checked(root, folder)["errors"], [])
                path = folder / "SpriteFrames.tres"
                text = path.read_text()
                entry = "metadata/twilight_canvas_size = Vector2(256, 256)\n"
                self.assertIn(entry, text)
                for changed in (text.replace(entry, ""),
                                text.replace(entry, "metadata/twilight_canvas_size = Vector2(512, 512)\n"),
                                text + entry,
                                text.replace(entry, "").replace("[resource]", entry + "[resource]")):
                    path.write_text(changed)
                    self.assertTrue(any("normalization metadata" in error
                                        for error in self.checked(root, folder)["errors"]))
                path.write_text(text)
                self.assertEqual(self.checked(root, folder)["errors"], [])

    def test_stripping_direction_tags_cannot_disguise_actual_variable_canvases(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            candidate, keys, folder = self.fixture(root)
            importer.import_sheet(root, candidate, "fixture", keys, True)
            path = folder / "provenance.json"
            proof = json.loads(path.read_text())
            for source in proof["source_files"]:
                for key in ("canvas_sizes_by_direction", "feet_by_direction", "canvas_size_basis"):
                    source.pop(key, None)
            for track in proof["tracks"].values():
                for source in track["atlas_files"]:
                    for key in ("canvas_sizes_by_direction", "feet_by_direction", "canvas_size_basis"):
                        source.pop(key, None)
            for frame, record in zip(proof["frames"], proof["source_poses"]):
                frame.pop("canvas_size", None)
                frame.pop("foot", None)
                record["canvas_size"] = proof["source_files"][frame["sheet"]]["canvas_size"][0]
            path.write_text(json.dumps(proof))
            self.assertTrue(any("foot-anchored canvas" in error
                                for error in self.checked(root, folder)["errors"]))

    def test_actual_fractional_rectangles_are_rejected_without_changing_legacy_reader(self):
        for mapped in (False, True):
            with self.subTest(mapped=mapped), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                factory = self.fixture if mapped else fixtures.MixedSourcesImportTest().fixture
                candidate, keys, folder = factory(root)
                importer.import_sheet(root, candidate, "fixture", keys, True)
                path = folder / "SpriteFrames.tres"
                original = path.read_text()
                baseline = audit.read_spriteframes(path)
                for field in ("region", "margin"):
                    changed = re.sub(r"(" + field + r" = Rect2\()(-?\d+)",
                                     lambda match: match[1] + str(float(match[2]) + .75), original, count=1)
                    self.assertNotEqual(changed, original)
                    path.write_text(changed)
                    # The unchanged older reader truncates; the optional audit
                    # must inspect the raw actual resource and reject it.
                    self.assertEqual(audit.read_spriteframes(path), baseline)
                    self.assertTrue(any("integer-valued" in error
                                        for error in self.checked(root, folder)["errors"]))

    def test_mixed_only_metadata_cannot_escape_by_mislabeling_representation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            candidate, keys, folder = self.fixture(root)
            importer.import_sheet(root, candidate, "fixture", keys, True)
            path = folder / "provenance.json"
            original = json.loads(path.read_text())
            for representation in (None, "pose_files_v1", "legacy"):
                proof = copy.deepcopy(original)
                proof["input_representation"] = representation
                path.write_text(json.dumps(proof))
                self.assertTrue(any("requires mixed_sources_v1" in error
                                    for error in self.checked(root, folder)["errors"]))

    def test_bad_actual_canvas_is_rejected_before_virtual_pixel_allocation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            candidate, keys, folder = self.fixture(root)
            importer.import_sheet(root, candidate, "fixture", keys, True)
            path = folder / "SpriteFrames.tres"
            changed = re.sub(r"(margin = Rect2\([^,]+,[^,]+, )(-?\d+)",
                             lambda match: match[1] + "999999999", path.read_text(), count=1)
            path.write_text(changed)
            with mock.patch.object(audit.Image, "new", side_effect=AssertionError("allocation preceded metadata gate")):
                self.assertTrue(any("provenance and actual AtlasTexture differ" in error
                                    for error in self.checked(root, folder)["errors"]))


if __name__ == "__main__":
    unittest.main()
