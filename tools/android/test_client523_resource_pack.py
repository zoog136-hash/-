"""Synthetic-fixture tests for build_client523_resource_pack.py (no original files)."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

import build_client523_resource_pack as pack


class ResourcePackTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.tables = self.tmp / "tables.zip"
        self.tables.write_bytes(b"tables")
        self.saved = pack.TABLES_SHA256, pack.TABLES_BYTES
        pack.TABLES_SHA256 = hashlib.sha256(b"tables").hexdigest()
        pack.TABLES_BYTES = len(b"tables")
        self.roots = {}
        manifests = {"bank": ("manifest.json", {"kind": "current523_reference_sp2_action_bank"}),
                     "images": ("manifest.json", {"schema": 1}),
                     "maps": ("source523.json", {"kind": "current523_s32_source_pack", "cumulative_version": 523}),
                     "tiles": ("tilepack523.json", {"schema": 1})}
        for section, (name, body) in manifests.items():
            root = self.tmp / section
            (root / "raw").mkdir(parents=True)
            (root / name).write_text(json.dumps(body))
            for index in range(3):
                (root / "raw" / f"{index}.bin").write_bytes(bytes([index]) * (100 + index))
            self.roots[section] = root

    def tearDown(self):
        pack.TABLES_SHA256, pack.TABLES_BYTES = self.saved

    def args(self, output, **extra):
        argv = ["--tables", str(self.tables), "--output", str(output)]
        for section, root in self.roots.items():
            argv += [f"--{section}", str(root)]
        for key, value in extra.items():
            argv += [f"--{key.replace('_', '-')}", str(value)]
        return argv

    def build(self, **extra):
        output = self.tmp / "out"
        self.assertEqual(pack.main(self.args(output, **extra)), 0)
        return output, json.loads((output / "source523_pack_report.json").read_text())

    def test_parts_hold_every_member_unchanged_with_descriptor_in_part_one(self):
        output, report = self.build(part_entries=6)
        for part in report["parts"]:
            self.assertLessEqual(part["bytes"], pack.MAX_PART_BYTES)
        parts = sorted(output.glob("twilight523-resources-*.zip"))
        self.assertEqual(len(parts), len(report["parts"]))
        self.assertGreater(len(parts), 1)
        seen = {}
        for number, path in enumerate(parts, 1):
            with zipfile.ZipFile(path) as archive:
                index = json.loads(archive.read(pack.PREFIX + pack.PART_INDEX))
                self.assertEqual(archive.namelist()[0], pack.PREFIX + pack.PART_INDEX)
                self.assertEqual((index["part"], index["parts"], index["pack_id"]), (number, len(parts), report["pack_id"]))
                self.assertEqual(pack.PREFIX + pack.DESCRIPTOR in archive.namelist(), number == 1)
                for info in archive.infolist()[1:]:
                    text = info.filename.endswith(".json") and not info.filename.endswith(pack.DESCRIPTOR)
                    self.assertEqual(info.compress_type, zipfile.ZIP_DEFLATED if text else zipfile.ZIP_STORED, info.filename)
                self.assertLessEqual(len(archive.namelist()), 6)
                for name, size in index["members"]:
                    seen[name] = archive.read(pack.PREFIX + name)
                    self.assertEqual(len(seen[name]), size)
        self.assertEqual(seen["tables/source.zip"], b"tables")
        self.assertEqual(seen["maps/raw/2.bin"], (self.roots["maps"] / "raw/2.bin").read_bytes())
        self.assertEqual(len(seen), report["members"])
        with zipfile.ZipFile(parts[0]) as archive:
            descriptor = json.loads(archive.read(pack.PREFIX + pack.DESCRIPTOR))
        self.assertEqual(descriptor["schema"], pack.SCHEMA)
        self.assertEqual(descriptor["bank"], {"root": "bank", "manifest": "bank/manifest.json",
                                              "manifest_sha256": hashlib.sha256((self.roots["bank"] / "manifest.json").read_bytes()).hexdigest()})
        self.assertNotIn("ui", descriptor)
        self.assertEqual(descriptor["start_land_id"], 4)

    def test_icon_selection_section_is_relative(self):
        icons = self.tmp / "ui_icons"
        (icons / "icon_pack").mkdir(parents=True)
        (icons / "icon_pack/original_ui.json").write_text("{}")
        selection = {"schema": "source523-original-ui-icon-selection-v1", "packs": [{"root": "icon_pack", "manifest_sha256": "0" * 64}]}
        (icons / "icon-selection.json").write_text(json.dumps(selection))
        output, _ = self.build(ui_icons=icons)
        with zipfile.ZipFile(sorted(output.glob("*.zip"))[0]) as archive:
            descriptor = json.loads(archive.read(pack.PREFIX + pack.DESCRIPTOR))
        self.assertEqual(descriptor["ui_icons"]["manifest"], "ui_icons/icon-selection.json")
        selection["packs"][0]["root"] = "/abs/icon_pack"
        (icons / "icon-selection.json").write_text(json.dumps(selection))
        self.assertEqual(pack.main(self.args(self.tmp / "out3", ui_icons=icons)), 1)

    def test_pack_id_is_deterministic(self):
        _, first = self.build()
        again = self.tmp / "again"
        self.assertEqual(pack.main(self.args(again)), 0)
        self.assertEqual(json.loads((again / "source523_pack_report.json").read_text())["pack_id"], first["pack_id"])

    def test_wrong_tables_or_kind_is_refused(self):
        self.tables.write_bytes(b"other!")
        self.assertEqual(pack.main(self.args(self.tmp / "out1")), 1)
        self.tables.write_bytes(b"tables")
        (self.roots["maps"] / "source523.json").write_text(json.dumps({"kind": "other"}))
        self.assertEqual(pack.main(self.args(self.tmp / "out2")), 1)

    def test_output_inside_repository_is_refused(self):
        repo = Path(pack.__file__).resolve().parents[2]
        with self.assertRaises(SystemExit):
            pack.main(self.args(repo / "build" / "private-pack"))


if __name__ == "__main__":
    unittest.main()
