import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools" / "boot"))
from build_startup_bake_reuse import build
from build_startup_bakes import BAKE_SCHEMA, INDEX, REQUIRED, SCHEMA


def bundle(root, entries):
    root.mkdir()
    index = json.dumps({"schema": SCHEMA, "files": {
        name: {"key": key, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
        for name, (key, data) in entries.items()
    }}).encode()
    archive = root / "twilight523-startup-bakes.zip"
    with zipfile.ZipFile(archive, "x") as out:
        out.writestr(INDEX, index)
        for name, (_, data) in entries.items():
            out.writestr(f"data/{name}/0", data)
    (root / "startup_bake_pin.json").write_text(json.dumps({
        "archive_bytes": archive.stat().st_size,
        "archive_sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
        "index_sha256": hashlib.sha256(index).hexdigest(),
    }))
    return archive


def device_cache(root, key, suffix=b""):
    root.mkdir()
    for name in REQUIRED:
        payload = name.encode() + (suffix if name == "native_item_templates" else b"")
        (root / (name + ".bin")).write_bytes(payload)
        (root / (name + ".json")).write_text(json.dumps({
            "schema": BAKE_SCHEMA, "key": key, "bytes": len(payload),
            "sha256": hashlib.sha256(payload).hexdigest(),
        }))


class StartupBakeReuseTest(unittest.TestCase):
    def setUp(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.old = Path(folder.name) / "old"
        self.new = Path(folder.name) / "new"
        self.source = "f" * 64
        self.engine = "engine|commit"
        self.archive = bundle(self.old, {
            "unchanged_bytes": ("a" * 64, b"persist"), "changed_bytes": ("a" * 64, b"first"),
            "exact_key": ("c" * 64, b"same"),
        })
        bundle(self.new, {
            "unchanged_bytes": ("b" * 64, b"persist"), "changed_bytes": ("b" * 64, b"later"),
            "exact_key": ("c" * 64, b"same"), "added": ("d" * 64, b"new"),
        })

    def test_only_equal_bytes_with_a_new_key(self):
        proof = build(self.old, self.new, self.source, self.source, self.engine)
        self.assertEqual(list(proof["files"]), ["unchanged_bytes"])
        self.assertEqual(proof["files"]["unchanged_bytes"]["previous_key"], "a" * 64)
        self.assertEqual(proof["files"]["unchanged_bytes"]["key"], "b" * 64)

    def test_different_original_precludes_reuse(self):
        with self.assertRaisesRegex(ValueError, "original inputs differ"):
            build(self.old, self.new, self.source, "e" * 64, self.engine)

    def test_existing_device_cache_can_be_proven_without_a_seed_archive(self):
        old = self.old.parent / "old-cache"
        new = self.old.parent / "new-cache"
        device_cache(old, "a" * 64)
        device_cache(new, "b" * 64, b"changed")
        proof = build(old, new, self.source, self.source, self.engine, device_caches=True)
        self.assertEqual(proof["index_sha256"], "")
        self.assertEqual(set(proof["files"]), REQUIRED - {"native_item_templates"})
        path = old / "card_slot_relic523_records.bin"
        path.write_bytes(b"x" * path.stat().st_size)
        with self.assertRaisesRegex(ValueError, "device cache bytes"):
            build(old, new, self.source, self.source, self.engine, device_caches=True)

    def test_archive_and_index_pins_are_required(self):
        pin_path = self.old / "startup_bake_pin.json"
        original_pin = pin_path.read_text()
        pin = json.loads(original_pin)
        pin["index_sha256"] = "e" * 64
        pin_path.write_text(json.dumps(pin))
        with self.assertRaisesRegex(ValueError, "index SHA-256"):
            build(self.old, self.new, self.source, self.source, self.engine)
        pin_path.write_text(original_pin)
        data = self.archive.read_bytes()
        self.archive.write_bytes(bytes([data[0] ^ 1]) + data[1:])
        with self.assertRaisesRegex(ValueError, "archive SHA-256"):
            build(self.old, self.new, self.source, self.source, self.engine)


if __name__ == "__main__":
    unittest.main()
