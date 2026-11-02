import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("restore_retired", ROOT / "tools/restore_archived_authoring_inputs.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class RestoreArchivedInputsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.raw = b"original immutable authoring bytes\n"
        self.oid = hashlib.sha1(("blob " + str(len(self.raw)) + "\0").encode() + self.raw).hexdigest()
        self.path = "assets/actors/eight_direction/retired/unit/input.png"
        self.zip = self.root / "snapshot.zip"
        with zipfile.ZipFile(self.zip, "w") as archive:
            archive.writestr("objects/" + self.oid, self.raw)
        self.manifest = {"schema": 1, "kind": "twilight-retired-authored-assets", "backups": {
            "monster_snapshot": {"bytes": self.zip.stat().st_size, "sha256": module.digest(self.zip)}},
            "files": [{"path": self.path, "oid": self.oid, "sha256": hashlib.sha256(self.raw).hexdigest(),
                       "bytes": len(self.raw), "mode": "100644", "backup": "monster_snapshot"}]}

    def test_exact_archive_restore_to_new_private_cache(self):
        dest = self.root / "cache"
        result = module.restore(self.manifest, dest, monster_zip=self.zip)
        self.assertEqual((dest / self.path).read_bytes(), self.raw)
        self.assertFalse(result["runtime_pack_installed"])
        self.assertFalse(result["git_or_saves_changed"])

    def test_corrupt_blob_cannot_activate_partial_destination(self):
        broken = copy.deepcopy(self.manifest)
        broken["files"][0]["sha256"] = "0" * 64
        sentinel = self.root / "existing-pack"
        sentinel.write_bytes(b"keep")
        with self.assertRaises(ValueError):
            module.restore(broken, self.root / "cache", monster_zip=self.zip)
        self.assertFalse((self.root / "cache").exists())
        self.assertEqual(sentinel.read_bytes(), b"keep")
        self.assertEqual(list(self.root.glob(".twilight-retired-*")), [])

    def test_invalid_archive_digest_fails_before_output(self):
        self.zip.write_bytes(self.zip.read_bytes() + b"changed")
        with self.assertRaises(ValueError):
            module.restore(self.manifest, self.root / "cache", monster_zip=self.zip)
        self.assertFalse((self.root / "cache").exists())

    def test_existing_destination_is_preserved(self):
        dest = self.root / "cache"
        dest.mkdir()
        (dest / "save").write_bytes(b"keep-save")
        with self.assertRaises(ValueError):
            module.restore(self.manifest, dest, monster_zip=self.zip)
        self.assertEqual((dest / "save").read_bytes(), b"keep-save")

    def test_traversal_duplicate_and_symlink_modes_are_rejected(self):
        for path, mode in [("assets/actors/eight_direction/../escape", "100644"),
                           ("assets/actors/eight_direction/x/file", "120000")]:
            broken = copy.deepcopy(self.manifest)
            broken["files"][0].update(path=path, mode=mode)
            with self.assertRaises(ValueError):
                module.rows_for(broken)
        duplicate = copy.deepcopy(self.manifest)
        duplicate["files"] *= 2
        with self.assertRaises(ValueError):
            module.rows_for(duplicate)

    def test_unknown_selection_and_missing_backup_do_not_create_cache(self):
        with self.assertRaises(ValueError):
            module.restore(self.manifest, self.root / "cache", paths=["not-archived"])
        with self.assertRaises(ValueError):
            module.restore(self.manifest, self.root / "cache")
        self.assertFalse((self.root / "cache").exists())

    def test_git_blob_restore_needs_no_network_or_runtime_install(self):
        repo = self.root / "reference.git"
        subprocess.run(["git", "init", "--bare", "-q", str(repo)], check=True)
        oid = subprocess.check_output(["git", "-C", str(repo), "hash-object", "-w", "--stdin"], input=self.raw).decode().strip()
        self.assertEqual(oid, self.oid)
        manifest = copy.deepcopy(self.manifest)
        manifest["files"][0]["backup"] = "scoped_bundle"
        result = module.restore(manifest, self.root / "git-cache", reference_git=repo)
        self.assertEqual((self.root / "git-cache" / self.path).read_bytes(), self.raw)
        self.assertEqual(result["restored_paths"], 1)


if __name__ == "__main__":
    unittest.main()
