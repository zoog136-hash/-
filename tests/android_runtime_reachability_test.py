"""Unreachable actor revisions may leave the APK; anything the game loads may not."""
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from android_runtime_reachability import (OFFLINE_PROVENANCE_JSON, generated_patterns, check_generated, unreachable_actor_folders,
                                          write_preset, preset_patterns)
from android_animation_export_scope import DRAFT_EXPORT_PATTERN, audit_authoring_exclusions

ACTOR = "assets/actors/eight_direction/native_locomotion_staging/hero"


class AndroidRuntimeReachabilityTest(unittest.TestCase):
    def fixture(self, root: Path) -> None:
        def write(relative: str, text: str) -> None:
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
        write("export_presets.cfg", 'exclude_filter="docs/*,' + DRAFT_EXPORT_PATTERN + '"\n')
        for name in ("combat_animation_profiles.json", "animation_presentation.json"):
            write("data/" + name, "{}\n")
        # Live chain: script -> catalog JSON -> SpriteFrames -> PNG.
        write("scripts/catalog.gd", 'const CATALOG = "res://data/catalog_v19.json"\n')
        write("data/catalog_v19.json", '{"frames": "res://' + ACTOR + '/r002/SpriteFrames.tres"}\n')
        write(ACTOR + "/r002/SpriteFrames.tres", '[gd_resource type="SpriteFrames" format=3]\n'
              '[ext_resource type="Texture2D" path="res://' + ACTOR + '/r002/S-run.png" id="1"]\n')
        (root / ACTOR / "r002/S-run.png").write_bytes(b"png")
        # Dead revision, mentioned only by a validation ledger nothing loads.
        write(ACTOR + "/r001/SpriteFrames.tres", '[gd_resource type="SpriteFrames" format=3]\n'
              '[ext_resource type="Texture2D" path="res://' + ACTOR + '/r001/S-run.png" id="1"]\n')
        (root / ACTOR / "r001/S-run.png").write_bytes(b"png")
        write(ACTOR + "/r001/provenance.json", "{}\n")
        write("data/pr122_native_locomotion_staging.json",
              '{"rows": ["res://' + ACTOR + '/r001/SpriteFrames.tres"]}\n')

    def test_only_the_unloaded_revision_is_listed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            self.assertEqual(unreachable_actor_folders(root), [ACTOR + "/r001"])

    def test_write_then_both_audits_pass_and_count_the_folder(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            self.assertTrue(write_preset(root, unreachable_actor_folders(root)))
            patterns = preset_patterns((root / "export_presets.cfg").read_text())
            self.assertIn(ACTOR + "/r001/*", patterns)
            self.assertIn(DRAFT_EXPORT_PATTERN, patterns)
            self.assertEqual(check_generated(root, patterns)["excluded_unreachable_folders"], [ACTOR + "/r001"])
            report = audit_authoring_exclusions(root)
            self.assertEqual(report["excluded_unreachable_folder_count"], 1)
            self.assertEqual(report["production_resources_excluded"], 0)
            # Writing again changes nothing.
            self.assertFalse(write_preset(root, unreachable_actor_folders(root)))

    def assert_exclusion_rejected(self, root: Path, pattern: str, message: str) -> None:
        preset = root / "export_presets.cfg"
        preset.write_text(preset.read_text().replace(DRAFT_EXPORT_PATTERN, DRAFT_EXPORT_PATTERN + "," + pattern))
        with self.assertRaisesRegex(ValueError, message):
            check_generated(root, preset_patterns(preset.read_text()))
        with self.assertRaisesRegex(ValueError, message):
            audit_authoring_exclusions(root)

    def test_excluding_a_loaded_revision_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            self.assert_exclusion_rejected(root, ACTOR + "/r002/*", "Runtime-reachable resource excluded")

    def test_newly_loaded_ledger_makes_its_revision_live(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            (root / "scripts/staging.gd").write_text('const P = "res://data/pr122_native_locomotion_staging.json"\n')
            self.assertEqual(unreachable_actor_folders(root), [])
            self.assert_exclusion_rejected(root, ACTOR + "/r001/*", "Runtime-reachable resource excluded")

    def test_scene_or_reached_resource_reference_keeps_folder(self):
        for relative in ("Main.tscn", "scenes/boss.tscn", "assets/ui/panel.tscn"):
            with self.subTest(relative=relative), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                self.fixture(root)
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('path="res://' + ACTOR + '/r001/S-run.png"\n')
                self.assertEqual(unreachable_actor_folders(root), [])

    def test_folder_prefix_that_could_build_paths_keeps_folder(self):
        for literal in (ACTOR + "/r001/", ACTOR + "/", "assets/actors/eight_direction/", "assets/"):
            with self.subTest(literal=literal), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                self.fixture(root)
                (root / "scripts/builder.gd").write_text('var path = "res://' + literal + '" + name\n')
                self.assertEqual(unreachable_actor_folders(root), [])
                self.assert_exclusion_rejected(root, ACTOR + "/r001/*", "Runtime-reachable resource excluded")

    def test_begins_with_guard_is_not_a_load(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            (root / "scripts/guard.gd").write_text('if not path.begins_with("res://assets/"): return\n')
            self.assertEqual(unreachable_actor_folders(root), [ACTOR + "/r001"])

    def test_family_root_and_wildcards_are_rejected(self):
        cases = (("assets/actors/eight_direction/native_locomotion_staging/*", "family roots"),
                 (ACTOR + "/r00*/*", "exact folder"),
                 (ACTOR + "/r404/*", "does not exist"))
        for pattern, message in cases:
            with self.subTest(pattern=pattern), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                self.fixture(root)
                self.assert_exclusion_rejected(root, pattern, message)

    def test_offline_provenance_files_are_not_generated_exclusions(self):
        records = sorted(OFFLINE_PROVENANCE_JSON)
        folder = "assets/actors/eight_direction/boss_draft_first/x/r001/*"
        self.assertEqual(generated_patterns([*records, folder, DRAFT_EXPORT_PATTERN]), [folder])

    def test_unlisted_dead_folder_only_reports(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            patterns = preset_patterns((root / "export_presets.cfg").read_text())
            self.assertEqual(check_generated(root, patterns)["excluded_unreachable_folders"], [])
            self.assertEqual(audit_authoring_exclusions(root)["excluded_unreachable_folder_count"], 0)


if __name__ == "__main__":
    unittest.main()
