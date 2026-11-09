"""Fixture tests for the over-the-air update identity (no Godot needed)."""
import hashlib
import json
import tempfile
import unittest
from pathlib import Path

import update_pack


class UpdatePackTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / ".godot").mkdir()
        (self.root / "scripts/boot").mkdir(parents=True)
        (self.root / "project.godot").write_text('[application]\nconfig/version="523.1"\nrun/max_fps=30\n')
        (self.root / ".godot/global_script_class_cache.cfg").write_text("list=[]\n")
        (self.root / "scripts/boot/updater.gd").write_text("extends Node\n")

    def tearDown(self):
        self.temp.cleanup()

    def key(self):
        return update_pack.compat_key(self.root, "4.7.2.stable.official")

    def test_version_line_does_not_change_the_key(self):
        first = self.key()
        (self.root / "project.godot").write_text('[application]\nconfig/version="523.99"\nrun/max_fps=30\n')
        self.assertEqual(first, self.key())

    def test_settings_classes_updater_and_engine_change_the_key(self):
        first = self.key()
        for name, text in [("project.godot", '[application]\nrun/max_fps=60\n'), (".godot/global_script_class_cache.cfg", "list=[{}]\n"), ("scripts/boot/updater.gd", "extends Node\n#x\n")]:
            original = (self.root / name).read_text()
            (self.root / name).write_text(text)
            self.assertNotEqual(first, self.key(), name)
            (self.root / name).write_text(original)
        self.assertNotEqual(first, update_pack.compat_key(self.root, "4.8.stable"))

    def test_missing_input_refuses(self):
        (self.root / ".godot/global_script_class_cache.cfg").unlink()
        with self.assertRaises(SystemExit):
            self.key()

    def test_build_info_and_feed(self):
        update_pack.main(["--root", str(self.root), "build-info", "--version-code", "7", "--version-name", "523.7", "--commit", "abc", "--godot-version", "4.7.2"])
        info = json.loads((self.root / "build_info.json").read_text())
        self.assertEqual((info["version_code"], info["version_name"], info["commit"]), (7, "523.7", "abc"))
        pack = self.root / "x.pck"
        pack.write_bytes(b"pack-bytes")
        out = self.root / "update.json"
        update_pack.main(["--root", str(self.root), "feed", "--pack", str(pack), "--base-url", "https://h/r/", "--apk-url", "https://h/a.apk", "--output", str(out)])
        record = json.loads(out.read_text())
        self.assertEqual(record["file"], "twilight-update-7.pck")
        self.assertEqual(record["url"], "https://h/r/twilight-update-7.pck")
        self.assertEqual(record["size"], 10)
        self.assertEqual(record["sha256"], hashlib.sha256(b"pack-bytes").hexdigest())
        self.assertEqual(record["compat_key"], info["compat_key"])
        self.assertEqual(record["apk_url"], "https://h/a.apk")

    def test_version_code_must_be_positive(self):
        with self.assertRaises(SystemExit):
            update_pack.main(["--root", str(self.root), "build-info", "--version-code", "0", "--version-name", "x", "--commit", "c", "--godot-version", "4"])


if __name__ == "__main__":
    unittest.main()
