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

    def test_refuses_output_inside_repository(self):
        repo = Path(addon.__file__).resolve().parents[2]
        with self.assertRaises(SystemExit):
            addon.main(["--world-links", str(self.links), "--output", str(repo / "build/addon-test")])


if __name__ == "__main__":
    unittest.main()
