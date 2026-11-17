import importlib.util
import pathlib
import unittest

SPEC = importlib.util.spec_from_file_location("check", pathlib.Path(__file__).resolve().parents[1] / "tools" / "check_no_legacy_resources.py")
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


class NoLegacyResources(unittest.TestCase):
    def test_allowed(self):
        self.assertEqual(CHECK.violations(["assets/fonts/NotoSansKR.ttf", "assets/boot/twilight_icon.png",
                                           "assets/boot/twilight_icon_192.png", "assets/maps/aden/ground.gdshader",
                                           "docs/README.md", "data/catalog_v19.json"]), [])

    def test_old_art_fails(self):
        for path in ["assets/external_l1j/items/1.png", "assets/catalog/a.png", "assets/skills/icons/x.png", "external_map_packs/source84_v3/maps/a.json", "samples/twilight-ui/dist/a.png", "assets/effects/awakening/lightning_arc_frames.png"]:
            self.assertEqual(CHECK.violations([path]), [path])

    def test_self_made_loading_backdrop_fails(self):
        self.assertEqual(CHECK.violations(["assets/boot/twilight_loading.png"]), ["assets/boot/twilight_loading.png"])

    def test_screenshots_anywhere_fail(self):
        for path in ["docs/object-placement-20261011/evidence/after/a.jpg", "tests/evidence/x.png", "docs/skills/vfx/y.webp"]:
            self.assertEqual(CHECK.violations([path]), [path])

    def test_code_naming_retired_file_fails(self):
        bad = CHECK.code_violations("scripts/hud.gd", 'var p := "res://assets/ui/potionRed.png"\n')
        self.assertEqual(len(bad), 1)
        self.assertIn("assets/ui/potionRed.png", bad[0])
        self.assertEqual(len(CHECK.code_violations("scripts/skills/x.gd", 'const S = "res://assets/skills/styled_icons/a.svg"')), 1)

    def test_code_exists_check_fails(self):
        self.assertEqual(len(CHECK.code_violations("scripts/ui/x.gd", "if ResourceLoader.exists(path): load(path)")), 1)
        self.assertEqual(CHECK.code_violations(CHECK.GATE, "return ResourceLoader.exists(path, type_hint)"), [])

    def test_code_kept_files_and_prefixes_pass(self):
        text = ('const F = preload("res://assets/fonts/NotoSansKR.ttf")\n'
                'shader = load("res://assets/maps/aden/ground.gdshader")\n'
                'if path.begins_with("res://assets/l1j/verified/"): return null\n')
        self.assertEqual(CHECK.code_violations("scripts/ui/x.gd", text), [])


if __name__ == "__main__":
    unittest.main()
