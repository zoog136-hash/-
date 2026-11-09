"""Fixture tests for the 523 resource pack add-on builder (no original files)."""
import hashlib
import json
import tempfile
import unittest
import zipfile
from pathlib import Path

import build_client523_addon as addon


class AddonTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.base = Path(self.temp.name)
        self.links = self.base / "world-links"
        (self.links / "lands").mkdir(parents=True)
        (self.links / "manifest.json").write_text('{"kind":"fixture"}')
        (self.links / "lands/4.json").write_text("{}")
        self.pin = hashlib.sha256(b'{"kind":"fixture"}').hexdigest()
        self.saved = dict(addon.ADDON_SECTIONS)
        addon.ADDON_SECTIONS["world_links"] = ("manifest.json", self.pin)

    def tearDown(self):
        addon.ADDON_SECTIONS.clear()
        addon.ADDON_SECTIONS.update(self.saved)
        self.temp.cleanup()

    def test_builds_one_installable_zip(self):
        out = self.base / "out"
        self.assertEqual(addon.main(["--world-links", str(self.links), "--output", str(out)]), 0)
        report = json.loads((out / "source523_addon_report.json").read_text())
        with zipfile.ZipFile(out / report["file"]) as archive:
            names = archive.namelist()
            self.assertEqual(names[:2], ["source523/source523_part.json", "source523/source523_addon.json"])
            index = json.loads(archive.read(names[0]))
            descriptor = json.loads(archive.read(names[1]))
            self.assertTrue(index["addon"])
            self.assertEqual((index["part"], index["parts"]), (1, 1))
            self.assertEqual(index["pack_id"], descriptor["addon_id"])
            self.assertEqual(sorted(m[0] for m in index["members"]), ["world_links/lands/4.json", "world_links/manifest.json"])
            self.assertEqual(descriptor["sections"]["world_links"], {"root": "world_links", "manifest": "world_links/manifest.json", "manifest_sha256": self.pin})
            self.assertEqual(archive.read("source523/world_links/lands/4.json"), b"{}")
        self.assertEqual(report["file"], "twilight523-addon-world-links.zip")

    def test_refuses_another_definitions_pack(self):
        (self.links / "manifest.json").write_text('{"kind":"other"}')
        self.assertEqual(addon.main(["--world-links", str(self.links), "--output", str(self.base / "out")]), 1)

    def _ui_pack(self, blockers=()):
        ui = self.base / "ui"
        (ui / "originals/UI/Main").mkdir(parents=True)
        raw = b"csb-bytes"
        (ui / "originals/UI/Main/Hud_ExpBar.csb").write_bytes(raw)
        manifest = {"schema": "twilight-original-ui-v1", "entries": [], "scenes": {}, "atlases": {},
                    "files": {"UI/Main/Hud_ExpBar.csb": {"sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw)}},
                    "blockers": list(blockers), "runtime_verified": False}
        (ui / "original_ui.json").write_text(json.dumps(manifest))
        return ui

    def test_builds_ui_addon(self):
        ui = self._ui_pack()
        out = self.base / "out-ui"
        self.assertEqual(addon.main(["--ui", str(ui), "--output", str(out)]), 0)
        report = json.loads((out / "source523_addon_report.json").read_text())
        self.assertEqual(report["file"], "twilight523-addon-ui.zip")
        with zipfile.ZipFile(out / report["file"]) as archive:
            descriptor = json.loads(archive.read("source523/source523_addon.json"))
            self.assertEqual(descriptor["sections"]["ui"]["manifest"], "ui/original_ui.json")
            self.assertEqual(descriptor["sections"]["ui"]["manifest_sha256"], hashlib.sha256((ui / "original_ui.json").read_bytes()).hexdigest())
            self.assertEqual(archive.read("source523/ui/originals/UI/Main/Hud_ExpBar.csb"), b"csb-bytes")

    def test_builds_combined_addon(self):
        ui = self._ui_pack()
        out = self.base / "out-both"
        self.assertEqual(addon.main(["--world-links", str(self.links), "--ui", str(ui), "--output", str(out)]), 0)
        report = json.loads((out / "source523_addon_report.json").read_text())
        self.assertEqual(report["file"], "twilight523-addon-ui-world-links.zip")
        self.assertEqual(sorted(report["sections"]), ["ui", "world_links"])

    def _world_map(self, offers=None):
        root = self.base / "world_map"
        root.mkdir()
        contract = {"schema": "twilight-source523-world-map-v1", "image_infos": [{"image_info": {}}],
                    "offered_worlds": offers if offers is not None else {"4": {"world_id": 5, "label": "아덴대륙"}}}
        (root / "contract.json").write_text(json.dumps(contract, ensure_ascii=False))
        return root

    def test_ui_and_world_map_ship_in_one_file(self):
        out = self.base / "out-map"
        self.assertEqual(addon.main(["--ui", str(self._ui_pack()), "--world-map", str(self._world_map()), "--output", str(out)]), 0)
        report = json.loads((out / "source523_addon_report.json").read_text())
        self.assertEqual(report["file"], "twilight523-addon-ui.zip")
        self.assertEqual(report["sections"]["world_map"]["manifest"], "world_map/contract.json")

    def test_refuses_world_map_without_offers(self):
        out = self.base / "out-map"
        self.assertEqual(addon.main(["--world-map", str(self._world_map(offers={})), "--output", str(out)]), 1)

    def test_refuses_ui_pack_with_blockers(self):
        ui = self._ui_pack(blockers=[{"member": "UI/x.png", "reason": "missing"}])
        self.assertEqual(addon.main(["--ui", str(ui), "--output", str(self.base / "out")]), 1)

    def test_refuses_ui_pack_with_changed_original(self):
        ui = self._ui_pack()
        (ui / "originals/UI/Main/Hud_ExpBar.csb").write_bytes(b"changed!!")
        self.assertEqual(addon.main(["--ui", str(ui), "--output", str(self.base / "out")]), 1)

    def test_refuses_output_inside_repository(self):
        repo = Path(addon.__file__).resolve().parents[2]
        with self.assertRaises(SystemExit):
            addon.main(["--world-links", str(self.links), "--output", str(repo / "build/addon-test")])


if __name__ == "__main__":
    unittest.main()
