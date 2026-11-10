import importlib.util
import pathlib
import unittest

SPEC = importlib.util.spec_from_file_location("check", pathlib.Path(__file__).resolve().parents[1] / "tools" / "check_no_legacy_resources.py")
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


class NoLegacyResources(unittest.TestCase):
    def test_allowed(self):
        self.assertEqual(CHECK.violations(["assets/fonts/NotoSansKR.ttf", "assets/boot/twilight_icon.png", "assets/maps/aden/ground.gdshader"]), [])

    def test_old_art_fails(self):
        for path in ["assets/external_l1j/items/1.png", "assets/catalog/a.png", "assets/skills/icons/x.png", "external_map_packs/source84_v3/maps/a.json", "samples/twilight-ui/dist/a.png", "assets/effects/awakening/lightning_arc_frames.png"]:
            self.assertEqual(CHECK.violations([path]), [path])


if __name__ == "__main__":
    unittest.main()
