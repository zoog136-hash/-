import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("shop_compiler", ROOT / "tools/shop/build_source523_shop.py")
COMPILER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(COMPILER)


class ShopCompilerTest(unittest.TestCase):
    def test_duplicate_json_keys_rejected(self):
        with self.assertRaisesRegex(ValueError, "duplicate"):
            COMPILER.strict_json(b'{"rows": [], "rows": []}')

    def test_nonfinite_json_rejected(self):
        for value in [b"NaN", b"Infinity", b"-Infinity"]:
            with self.assertRaises(ValueError):
                COMPILER.strict_json(value)

    def test_unverified_source_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / "unverified.zip"
            source.write_bytes(b"unverified")
            with self.assertRaisesRegex(ValueError, "verified patch523"):
                COMPILER.build(source)

    def test_original_rows_cannot_be_written_into_repo(self):
        with self.assertRaisesRegex(ValueError, "outside"):
            COMPILER.write_pack(Path("unused.zip"), ROOT / "data/shop523-unsafe.json")

    def test_source_archive_cannot_be_overwritten(self):
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / "source.zip"
            source.write_bytes(b"original")
            with self.assertRaisesRegex(ValueError, "unchanged"):
                COMPILER.write_pack(source, source)
            self.assertEqual(source.read_bytes(), b"original")


@unittest.skipUnless(os.environ.get("SOURCE523_SHOP_ZIP"), "original Library ZIP not selected")
class OriginalShopRoundtripTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = Path(os.environ["SOURCE523_SHOP_ZIP"])
        cls.pack = COMPILER.build(cls.source)

    def test_every_original_row_and_order(self):
        with zipfile.ZipFile(self.source) as archive:
            for name in COMPILER.TABLES:
                with self.subTest(table=name):
                    expected = COMPILER.strict_json(archive.read(f"content/{name}.json"))["rows"]
                    self.assertEqual(expected, self.pack["tables"][name])
            original_labels = COMPILER.strict_json(archive.read("content/DescData_Korean.json"))["rows"]
            selected = {row["ID"] for row in self.pack["tables"]["DescData_Korean"]}
            self.assertEqual([row for row in original_labels if row["ID"] in selected],
                             self.pack["tables"]["DescData_Korean"])

    def test_private_pack_is_deterministic_and_byte_checked(self):
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / "shop.json"
            first = COMPILER.write_pack(self.source, target)
            original = target.read_bytes()
            second = COMPILER.write_pack(self.source, target)
            self.assertEqual(first, second)
            self.assertEqual(original, target.read_bytes())
            self.assertEqual(first["bytes"], target.stat().st_size)
            self.assertEqual(json.loads(original), self.pack)


if __name__ == "__main__":
    unittest.main()
