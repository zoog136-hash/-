"""APK authoring exclusions must never hide a selected/runtime dependency."""
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from android_animation_export_scope import ADEN_PREVIEW_RENDERER, OFFLINE_AUTHORING_JSON, DRAFT_EXPORT_PATTERN, DRAFT_ROOT, audit_authoring_exclusions


class AndroidAnimationExportScopeTest(unittest.TestCase):
    def fixture(self, root):
        (root / "export_presets.cfg").write_text('exclude_filter="docs/*,' + DRAFT_EXPORT_PATTERN + ',' + ADEN_PREVIEW_RENDERER + '"\n')
        (root / "data").mkdir()
        for name in ("combat_animation_profiles.json", "animation_presentation.json", "catalog_v19.json"):
            (root / "data" / name).write_text('{}\n')
        archive = root / DRAFT_ROOT / "transform_412/draft001/SpriteFrames.tres"
        archive.parent.mkdir(parents=True)
        archive.write_text('[gd_resource type="SpriteFrames" format=3]\n'
                           '[ext_resource type="Texture2D" path="res://docs/remake/evidence/'
                           'pr122-mythic-detailed/batch03/transform_412-S-attack-draft-v01.png" id="1"]\n')
        production = root / DRAFT_ROOT / "transform_412/native010/SpriteFrames.tres"
        production.parent.mkdir()
        production.write_text('[gd_resource type="SpriteFrames" format=3]\n')
        return archive, production

    def test_only_detached_archived_clips_are_excluded_without_writes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive, production = self.fixture(root)
            before = {p.relative_to(root): p.read_bytes() for p in root.rglob('*') if p.is_file()}
            report = audit_authoring_exclusions(root)
            self.assertEqual(report['excluded_count'], 1)
            self.assertEqual(report['production_resources_excluded'], 0)
            self.assertEqual(report['excluded_authoring_resources'][0]['path'], archive.relative_to(root).as_posix())
            self.assertNotEqual(report['excluded_authoring_resources'][0]['path'], production.relative_to(root).as_posix())
            self.assertEqual(before, {p.relative_to(root): p.read_bytes() for p in root.rglob('*') if p.is_file()})

    def test_selected_manifest_reference_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive, _ = self.fixture(root)
            (root / 'data/pr122_native_locomotion_staging.json').write_text(
                '{"frames": "res://' + archive.relative_to(root).as_posix() + '"}')
            with self.assertRaisesRegex(ValueError, 'selected staging'):
                audit_authoring_exclusions(root)

    def test_runtime_scene_script_or_resource_reference_fails(self):
        for path in ('Main.tscn', 'scripts/catalog.gd', 'assets/live.tres'):
            with self.subTest(path=path), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                archive, _ = self.fixture(root)
                reference = root / path
                reference.parent.mkdir(parents=True, exist_ok=True)
                reference.write_text('"res://' + archive.relative_to(root).as_posix() + '"')
                with self.assertRaisesRegex(ValueError, 'Exported code/resource references'):
                    audit_authoring_exclusions(root)

    def test_indirect_new_json_manifest_cannot_hide_archive_reference(self):
        for relative in ('data/extra_live_profiles.json', 'assets/live/extra.json'):
            with self.subTest(relative=relative), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                archive, _ = self.fixture(root)
                manifest = root / relative
                manifest.parent.mkdir(parents=True, exist_ok=True)
                manifest.write_text('{"frames": "res://' + archive.relative_to(root).as_posix() + '"}')
                loader = root / 'scripts/extra_loader.gd'
                loader.parent.mkdir()
                loader.write_text('var path = "res://' + relative + '"\n')
                with self.assertRaisesRegex(ValueError, 'selected staging manifest references'):
                    audit_authoring_exclusions(root)

    def test_broader_exclusion_cannot_hide_native_resources(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            (root / 'export_presets.cfg').write_text(
                'exclude_filter="' + DRAFT_EXPORT_PATTERN + ',assets/*"\n')
            with self.assertRaisesRegex(ValueError, 'Non-archive runtime resource excluded'):
                audit_authoring_exclusions(root)

    def test_aden_authoring_inputs_have_runtime_pack_and_live_reference_guards(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            preset = root / "export_presets.cfg"
            preset.write_text(preset.read_text().replace(
                DRAFT_EXPORT_PATTERN, DRAFT_EXPORT_PATTERN + ",assets/maps/aden_city_region/*"))
            layout = root / "assets/maps/aden_city_region/layout.json"
            layout.parent.mkdir(parents=True)
            layout.write_text('{"status": "REGISTERED_DISTRICT_REVIEW_NOT_PRODUCTION"}')
            original_png = layout.parent / "source/unused.png"
            original_png.parent.mkdir(parents=True)
            original_png.write_bytes(b"authoring input placeholder")
            with self.assertRaisesRegex(ValueError, "runtime pack manifest is missing"):
                audit_authoring_exclusions(root)

            runtime = root / "data/maps/aden_mobile_pack.json"
            runtime.parent.mkdir(parents=True)
            runtime.write_text('{"schema": 1, "map_id": "aden_world", "manifest_sha256": "'
                               + ("a" * 64) + '"}')
            self.assertEqual(audit_authoring_exclusions(root)['production_resources_excluded'], 0)

            new_catalog = layout.parent / "unexpected_live_catalog.json"
            new_catalog.write_text("{}")
            with self.assertRaisesRegex(ValueError, "Runtime catalog excluded"):
                audit_authoring_exclusions(root)
            new_catalog.unlink()

            live = root / "scripts/load_authoring.gd"
            live.parent.mkdir(parents=True)
            live.write_text('load("res://assets/maps/aden_city_region/layout.json")')
            with self.assertRaisesRegex(ValueError, "Exported code/resource references excluded Aden"):
                audit_authoring_exclusions(root)

    def test_two_offline_json_exclusions_preserve_live_runtime_guards(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            additions = sorted(OFFLINE_AUTHORING_JSON)
            preset = root / "export_presets.cfg"
            preset.write_text(preset.read_text().replace(
                DRAFT_EXPORT_PATTERN, DRAFT_EXPORT_PATTERN + "," + ",".join(additions)))
            for relative in additions:
                source = root / relative
                source.parent.mkdir(parents=True, exist_ok=True)
                source.write_text('{"schema": 1}')
            # The map's runtime manifest must still be shipped and valid.
            with self.assertRaisesRegex(ValueError, "runtime pack manifest is missing"):
                audit_authoring_exclusions(root)
            runtime = root / "data/maps/aden_mobile_pack.json"
            runtime.parent.mkdir(parents=True)
            runtime.write_text('{"schema": 1, "map_id": "aden_world", "manifest_sha256": "' + "a"*64 + '"}')
            self.assertEqual(audit_authoring_exclusions(root)["production_resources_excluded"], 0)
            # No other excluded JSON is allowed to masquerade as research.
            sneaky = root / "data/live_inventory.json"
            sneaky.write_text("{}")
            preset.write_text(preset.read_text().replace(
                ",".join(additions), ",".join(additions) + ",data/live_inventory.json"))
            with self.assertRaisesRegex(ValueError, "Runtime catalog excluded"):
                audit_authoring_exclusions(root)
            sneaky.unlink()
            preset.write_text(preset.read_text().replace(",data/live_inventory.json", ""))
            for relative in additions:
                with self.subTest(relative=relative):
                    loader = root / "scripts/live_loader.gd"
                    loader.parent.mkdir(exist_ok=True)
                    loader.write_text('var live = "res://' + relative + '"')
                    with self.assertRaisesRegex(ValueError, "excluded offline JSON"):
                        audit_authoring_exclusions(root)
                    loader.unlink()
                    manifest = root / "data/other_runtime_catalog.json"
                    manifest.write_text('{"path": "res://' + relative + '"}')
                    with self.assertRaisesRegex(ValueError, "excluded offline JSON"):
                        audit_authoring_exclusions(root)
                    manifest.unlink()

    def test_delivery_ledger_inventory_is_not_a_runtime_reference(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            relative = "data/map_remake/private/aden/effective_layouts_build.json"
            preset = root / "export_presets.cfg"
            preset.write_text(preset.read_text().replace(
                DRAFT_EXPORT_PATTERN, DRAFT_EXPORT_PATTERN + "," + relative))
            offline = root / relative
            offline.parent.mkdir(parents=True, exist_ok=True)
            offline.write_text("{}")
            runtime = root / "data/maps/aden_mobile_pack.json"
            runtime.parent.mkdir(parents=True, exist_ok=True)
            runtime.write_text('{"schema": 1, "map_id": "aden_world", "manifest_sha256": "' + "a"*64 + '"}')
            ledger = root / "data/resource_delivery_ledger.json"
            ledger.write_text('{"tracked_source": "' + relative + '"}')
            self.assertEqual(audit_authoring_exclusions(root)["production_resources_excluded"], 0)
            live = root / "data/another_runtime.json"
            live.write_text('{"load": "res://' + relative + '"}')
            with self.assertRaisesRegex(ValueError, "excluded offline JSON"):
                audit_authoring_exclusions(root)

    def test_offline_json_allowlist_and_live_reference_guard(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            relative = "data/map_remake/private/aden/effective_layouts_build.json"
            preset = root / "export_presets.cfg"
            preset.write_text(preset.read_text().replace(
                DRAFT_EXPORT_PATTERN, DRAFT_EXPORT_PATTERN + "," + relative))
            offline = root / relative
            offline.parent.mkdir(parents=True, exist_ok=True)
            offline.write_text("{}")
            ledger = root / "data/resource_delivery_ledger.json"
            ledger.write_text('{"tracked_source": "' + relative + '"}')
            # Verify the fail-closed guard, then supply the real export's pack
            # manifest in this otherwise intentionally minimal unit fixture.
            with self.assertRaisesRegex(ValueError, "runtime pack manifest is missing"):
                audit_authoring_exclusions(root)
            runtime_pack = root / "data/maps/aden_mobile_pack.json"
            runtime_pack.parent.mkdir(parents=True, exist_ok=True)
            runtime_pack.write_text('{"schema": 1, "map_id": "aden_world", "manifest_sha256": "' + "a"*64 + '"}')
            self.assertEqual(audit_authoring_exclusions(root)["production_resources_excluded"], 0)
            runtime = root / "scripts/map_loader.gd"
            runtime.parent.mkdir(parents=True, exist_ok=True)
            runtime.write_text('load("res://' + relative + '")')
            with self.assertRaisesRegex(ValueError, "excluded offline JSON"):
                audit_authoring_exclusions(root)
            runtime.unlink()
            unexpected = root / "data/unexpected_catalog.json"
            unexpected.write_text("{}")
            preset.write_text(preset.read_text().replace(relative, relative + ",data/unexpected_catalog.json"))
            with self.assertRaisesRegex(ValueError, "Runtime catalog excluded"):
                audit_authoring_exclusions(root)

    def test_each_offline_json_exclusion_is_checked(self):
        # Regress the real Android export failure: non-runtime source/build
        # manifests may be excluded, but a runtime dependency must fail closed.
        for relative in (
            "data/map_remake/private/aden/effective_layouts_build.json",
            "data/skills/research_inventory.json",
        ):
            with self.subTest(relative=relative), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                self.fixture(root)
                preset = root / "export_presets.cfg"
                preset.write_text(preset.read_text().replace(
                    DRAFT_EXPORT_PATTERN, DRAFT_EXPORT_PATTERN + "," + relative))
                offline = root / relative
                offline.parent.mkdir(parents=True, exist_ok=True)
                offline.write_text("{}\n")
                if relative == "data/map_remake/private/aden/effective_layouts_build.json":
                    with self.assertRaisesRegex(ValueError, "runtime pack manifest is missing"):
                        audit_authoring_exclusions(root)
                    runtime_pack = root / "data/maps/aden_mobile_pack.json"
                    runtime_pack.parent.mkdir(parents=True, exist_ok=True)
                    runtime_pack.write_text('{"schema": 1, "map_id": "aden_world", "manifest_sha256": "' + "a"*64 + '"}')
                self.assertEqual(audit_authoring_exclusions(root)["production_resources_excluded"], 0)

                runtime_manifest = root / "data/runtime_references_offline.json"
                runtime_manifest.write_text('{"resource": "' + relative + '"}\n')
                with self.assertRaisesRegex(ValueError, "excluded offline JSON"):
                    audit_authoring_exclusions(root)
                runtime_manifest.unlink()

                scene = root / "Main.tscn"
                scene.write_text('load("res://' + relative + '")\n')
                with self.assertRaisesRegex(ValueError, "excluded offline JSON"):
                    audit_authoring_exclusions(root)

    def test_unknown_archive_contents_fail_closed(self):
        for change in ('extra_png', 'different_source', 'different_type'):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                archive, _ = self.fixture(root)
                if change == 'extra_png':
                    (archive.parent / 'new-runtime.png').write_bytes(b'not-an-image')
                elif change == 'different_source':
                    archive.write_text(archive.read_text().replace('res://docs/', 'res://assets/'))
                else:
                    archive.write_text(archive.read_text().replace('type="SpriteFrames"', 'type="Resource"'))
                with self.assertRaises(ValueError):
                    audit_authoring_exclusions(root)

    def test_authoring_preview_is_excluded_only_with_no_runtime_references(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            preview = root / ADEN_PREVIEW_RENDERER
            preview.parent.mkdir(parents=True)
            preview.write_text(
                'extends Node2D\nvar source = "res://assets/maps/aden_modular_pilot/compiled/"\n'
            )
            self.assertEqual(audit_authoring_exclusions(root)["production_resources_excluded"], 0)

            scene = root / "Main.tscn"
            scene.write_text('path="res://' + ADEN_PREVIEW_RENDERER + '"\n')
            with self.assertRaisesRegex(ValueError, "excluded Aden preview renderer"):
                audit_authoring_exclusions(root)
            scene.unlink()

            catalog = root / "data/runtime_preview.json"
            catalog.write_text('{"script": "res://' + ADEN_PREVIEW_RENDERER + '"}\n')
            with self.assertRaisesRegex(ValueError, "excluded Aden preview renderer"):
                audit_authoring_exclusions(root)
            catalog.unlink()

            preset = root / "export_presets.cfg"
            preset.write_text(preset.read_text().replace("," + ADEN_PREVIEW_RENDERER, ""))
            with self.assertRaisesRegex(ValueError, "must explicitly exclude"):
                audit_authoring_exclusions(root)


if __name__ == '__main__':
    unittest.main()
