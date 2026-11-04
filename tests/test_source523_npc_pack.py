import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "shop"))
from build_source523_npc import build


class NpcPackProtectionTest(unittest.TestCase):
    def test_existing_shop_hash_is_required_before_reading_source(self):
        with tempfile.TemporaryDirectory() as directory:
            shop = Path(directory) / "shop.json"
            shop.write_bytes(b"original pack")
            with self.assertRaisesRegex(ValueError, "hash mismatch"):
                build("source-not-needed.zip", shop, "0" * 64)
            self.assertEqual(shop.read_bytes(), b"original pack")

    def test_cli_refuses_source_and_shop_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source.zip"
            shop = Path(directory) / "shop.json"
            source.write_bytes(b"original source")
            shop.write_bytes(b"original shop")
            for destination in [source, shop]:
                result = subprocess.run([sys.executable, str(ROOT / "tools/shop/build_source523_npc.py"), str(source), str(shop), "0" * 64, str(destination)], capture_output=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(b"must remain unchanged", result.stderr)
            self.assertEqual(source.read_bytes(), b"original source")
            self.assertEqual(shop.read_bytes(), b"original shop")

    def test_cli_refuses_private_definitions_inside_public_repo(self):
        destination = ROOT / "docs/shop/private-npc-should-not-exist.json"
        result = subprocess.run([sys.executable, str(ROOT / "tools/shop/build_source523_npc.py"), "missing.zip", "missing.json", "0" * 64, str(destination)], capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"outside the Git", result.stderr)
        self.assertFalse(destination.exists())

    @unittest.skipUnless(os.environ.get("SOURCE523_SHOP_ZIP") and os.environ.get("SOURCE523_SHOP_PACK"), "actual original source and existing shop pack not selected")
    def test_actual_pack_is_separate_and_preserves_paid_order_catalog_identity(self):
        source = Path(os.environ["SOURCE523_SHOP_ZIP"])
        shop = Path(os.environ["SOURCE523_SHOP_PACK"])
        source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
        shop_hash = hashlib.sha256(shop.read_bytes()).hexdigest()
        result = build(source, shop, shop_hash)
        self.assertEqual(result["shop_pack_sha256"], shop_hash)
        self.assertEqual(result["source_zip_sha256"], source_hash)
        self.assertEqual(len(result["merchants"]), 192)
        self.assertTrue(all(not r["activation_authorized"] for r in result["merchants"]))
        payload = json.dumps(result, ensure_ascii=False, separators=(",", ":"), allow_nan=False).encode()
        self.assertEqual(hashlib.sha256(payload).hexdigest(), "65d625bf16dcaf5aa280260082eee587801f3e2d2567d48b8444c0a14e84d2f3")
        self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), source_hash)
        self.assertEqual(hashlib.sha256(shop.read_bytes()).hexdigest(), shop_hash)


if __name__ == "__main__":
    unittest.main()
