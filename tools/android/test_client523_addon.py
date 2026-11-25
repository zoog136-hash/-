"""Fixture tests for the 523 resource pack add-on builder (no original files)."""
import hashlib
import json
import struct
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
        (ui / "settings_frames_v1.bin").write_bytes(b"stale prepared file")
        out = self.base / "out-ui"
        self.assertEqual(addon.main(["--ui", str(ui), "--output", str(out)]), 0)
        report = json.loads((out / "source523_addon_report.json").read_text())
        self.assertEqual(report["file"], "twilight523-addon-ui.zip")
        with zipfile.ZipFile(out / report["file"]) as archive:
            descriptor = json.loads(archive.read("source523/source523_addon.json"))
            self.assertNotIn("source523/ui/settings_frames_v1.bin", archive.namelist())
            self.assertNotIn("settings_frames_sha256", descriptor["sections"]["ui"])
            self.assertEqual(descriptor["sections"]["ui"]["manifest"], "ui/original_ui.json")
            self.assertEqual(descriptor["sections"]["ui"]["manifest_sha256"], hashlib.sha256((ui / "original_ui.json").read_bytes()).hexdigest())
            self.assertEqual(archive.read("source523/ui/originals/UI/Main/Hud_ExpBar.csb"), b"csb-bytes")

    def test_prepared_frame_preserves_geometry_and_pma(self):
        try:
            from PIL import Image
            try:
                from compression.zstd import decompress
            except ImportError:
                from zstandard import ZstdDecompressor
                decompress = ZstdDecompressor().decompress
        except ImportError:
            self.skipTest("optional private UI preparation dependencies")

        ui = self._ui_pack()
        member = "UI/UI_Resource/Atlas_Common.png"
        path = ui / "originals" / member
        path.parent.mkdir(parents=True)
        page = Image.new("RGBA", (1, 2))
        page.putdata([(200, 100, 50, 127), (10, 20, 30, 255)])
        page.save(path)
        geometry = {"rect": [0, 0, 2, 1], "source_rect": [1, 0, 2, 1],
                    "source_size": [3, 2], "rotated": True}
        plist, name = member[:-4] + ".plist", "Btn_Blue_Off.png"
        manifest_path = ui / "original_ui.json"
        manifest = json.loads(manifest_path.read_bytes())
        manifest["scenes"]["UI/Option/Option_All.csb"] = {}
        manifest["files"][member] = {"bytes": path.stat().st_size, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        manifest["atlases"][plist] = {"page": member, "frames": {name: geometry}}
        manifest_path.write_text(json.dumps(manifest))
        out = self.base / "out-prepared"
        self.assertEqual(addon.main(["--ui", str(ui), "--output", str(out)]), 0)
        with zipfile.ZipFile(out / "twilight523-addon-ui.zip") as archive:
            section = json.loads(archive.read("source523/source523_addon.json"))["sections"]["ui"]
            blob = archive.read("source523/ui/settings_frames_v1.bin")
            self.assertEqual(hashlib.sha256(blob).hexdigest(), section["settings_frames_sha256"])
            size = struct.unpack_from("<I", blob)[0]
            index = json.loads(blob[4:4 + size])
            self.assertEqual(index["manifest_sha256"], hashlib.sha256(manifest_path.read_bytes()).hexdigest())
            record = json.loads(index["catalog"])[plist]["frames"][name]
            self.assertEqual(record["geometry"], [geometry["rect"], geometry["source_rect"], geometry["source_size"], True])
            offset, length = index["ranges"][record["rgba_sha256"]]
            raw = decompress(blob[4 + size + offset:4 + size + offset + length])
            self.assertEqual(raw, bytes(4) + bytes([100, 50, 25, 127, 10, 20, 30, 255]) + bytes(12))
            self.assertEqual(hashlib.sha256(raw).hexdigest(), record["rgba_sha256"])

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

    def test_optional_smelt_only_contains_one_stored_member(self):
        rules = self.base / "smelt"
        rules.mkdir()
        data = b"a" * addon.SMELT_BYTES
        (rules / "smelt.json").write_bytes(data)
        (rules / "not-shipped.txt").write_bytes(b"different resources must not be copied")
        pin = hashlib.sha256(data).hexdigest()
        addon.ADDON_SECTIONS["equipment_smelt"] = ("smelt.json", pin)
        out = self.base / "out-smelt"
        self.assertEqual(addon.main(["--equipment-smelt", str(rules), "--output", str(out)]), 0)
        with zipfile.ZipFile(out / "twilight523-addon-equipment-smelt.zip") as archive:
            names = archive.namelist()
            self.assertEqual(len(names), 3)
            self.assertEqual(names[-1], "source523/equipment_smelt/smelt.json")
            self.assertEqual(archive.getinfo(names[-1]).compress_type, zipfile.ZIP_STORED)
            self.assertEqual(archive.read(names[-1]), data)
        self.assertEqual(addon.main(["--equipment-smelt", str(rules), "--world-links", str(self.links), "--output", str(self.base / "mixed")]), 1)
        (rules / "smelt.json").write_bytes(b"b" * addon.SMELT_BYTES)
        self.assertEqual(addon.main(["--equipment-smelt", str(rules), "--output", str(self.base / "bad")]), 1)

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
