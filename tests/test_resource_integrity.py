"""Negative regression tests: missing, changed and untracked resources must fail."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

MODULE = Path(__file__).resolve().parents[1] / "tools/check_resource_integrity.py"
spec = importlib.util.spec_from_file_location("resource_integrity", MODULE)
resource = importlib.util.module_from_spec(spec)
spec.loader.exec_module(resource)


class ResourceIntegrityTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        self.asset = self.root / "assets/catalog_motion/transform/01.webp"
        self.asset.parent.mkdir(parents=True, exist_ok=True)
        self.asset.write_bytes(b"RIFF" + bytes([0]) * 4 + b"WEBP" + b"x" * 200)
        self.manifest = self.root / "data/visuals/runtime_manifest.json"
        self.manifest.parent.mkdir(parents=True, exist_ok=True)
        self.record = {"schema": 1, "catalog": {"transform:01": {
            "atlas": "res://assets/catalog_motion/transform/01.webp",
            "atlas_sha256": resource.sha256_file(self.asset), "tracks": [{"count": 2}]}}}
        self.manifest.write_text(json.dumps(self.record))
        self.ledger = self.root / "data/resource_delivery_ledger.json"
        self.ledger.write_text(json.dumps({"schema": 1, "generated_atlases": {"state": "committed_and_hashed"},
            "original_monsters_items": {"state": "not_delivered"},
            "original_map_tiles": {"state": "not_delivered"},
            "source_archives": {"state": "session_only", "files": [{
                "filename": "a1.zip", "bytes": 200, "sha256": "a" * 64,
                "availability": "conversation_session_only"}]}}))
        self.git_add()

    def git_add(self):
        subprocess.run(["git", "-C", str(self.root), "add", "."], check=True)

    def audit(self):
        return resource.check_catalog(self.root, {"transform": 1}, 2)

    def test_valid_committed_asset_passes(self):
        self.assertEqual(self.audit()["atlases"], 1)
        resource.check_ledger(self.root)

    def test_missing_asset_fails(self):
        self.asset.unlink()
        with self.assertRaisesRegex(resource.AuditError, "MISSING ATLAS"):
            self.audit()

    def test_modified_asset_hash_fails(self):
        self.asset.write_bytes(self.asset.read_bytes() + b"tampered")
        with self.assertRaisesRegex(resource.AuditError, "HASH MISMATCH"):
            self.audit()

    def test_generated_but_not_git_added_fails(self):
        subprocess.run(["git", "-C", str(self.root), "rm", "--cached", "-q",
                        "assets/catalog_motion/transform/01.webp"], check=True)
        with self.assertRaisesRegex(resource.AuditError, "NOT IN GIT"):
            self.audit()

    def test_unproven_delivery_claim_fails(self):
        ledger = json.loads(self.ledger.read_text())
        ledger["original_monsters_items"]["state"] = "delivered"
        self.ledger.write_text(json.dumps(ledger))
        with self.assertRaisesRegex(resource.AuditError, "UNPROVEN PUBLIC DELIVERY CLAIM"):
            resource.check_ledger(self.root)

    def test_no_receipt_means_no_release(self):
        with self.assertRaisesRegex(resource.AuditError, "MISSING JSON"):
            resource.verify_release(self.root, self.root)


if __name__ == "__main__":
    unittest.main()
