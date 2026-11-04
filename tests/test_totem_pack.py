"""Optional source tests: TOTEM_SOURCE_ZIP and TOTEM_RESEARCH_ZIP select private inputs."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location("totem_builder", Path(__file__).resolve().parents[1] / "tools/totems/build_totem_pack.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


@unittest.skipUnless(os.getenv("TOTEM_SOURCE_ZIP") and os.getenv("TOTEM_RESEARCH_ZIP"), "private Totem input archives not selected")
class TotemSourceTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.source = Path(os.environ["TOTEM_SOURCE_ZIP"])
        self.research = Path(os.environ["TOTEM_RESEARCH_ZIP"])

    def tearDown(self):
        self.temp.cleanup()

    def changed_research(self, change):
        dest = self.root / "changed.zip"
        with zipfile.ZipFile(self.research) as src, zipfile.ZipFile(dest, "w") as out:
            for item in src.infolist():
                data = src.read(item.filename)
                if item.filename.endswith("source_row_evidence.json"):
                    rows = json.loads(data)
                    change(rows)
                    data = json.dumps(rows).encode()
                out.writestr(item.filename, data)
        return dest

    def test_actual_source_and_reproducible_output(self):
        first = builder.build(self.source, self.research, self.root / "first")
        second = builder.build(self.source, self.research, self.root / "second")
        self.assertEqual(first, second)
        self.assertEqual(first["evidence_rows"], 1294)
        self.assertEqual(len(first["table_counts"]), 43)
        body = json.loads((self.root / "first/totem_data.json").read_bytes())
        self.assertEqual(len(body["tables"]["TotemBonus"]), 94)
        self.assertEqual(sorted(len(v) for v in body["map_contexts"].values()), [2, 2, 3])

    def test_existing_pack_preserved(self):
        output = self.root / "existing"
        output.mkdir()
        (output / "sentinel").write_text("keep")
        with self.assertRaisesRegex(ValueError, "preserved"):
            builder.build(self.source, self.research, output)
        self.assertEqual((output / "sentinel").read_text(), "keep")

    def test_wrong_version_rejected(self):
        changed = self.changed_research(lambda rows: rows[0].update(version=508))
        with self.assertRaisesRegex(ValueError, "version"):
            builder.build(self.source, changed, self.root / "out")
        self.assertFalse((self.root / "out").exists())

    def test_wrong_coordinate_rejected(self):
        changed = self.changed_research(lambda rows: rows[0].update(source_row_1based=1))
        with self.assertRaisesRegex(ValueError, "mismatch"):
            builder.build(self.source, changed, self.root / "out")

    def test_modified_source_row_rejected(self):
        changed = self.changed_research(lambda rows: rows[0]["row"].update(Injected=1))
        with self.assertRaisesRegex(ValueError, "mismatch"):
            builder.build(self.source, changed, self.root / "out")

    def test_duplicate_coordinate_rejected(self):
        changed = self.changed_research(lambda rows: rows.append(rows[0]))
        with self.assertRaisesRegex(ValueError, "duplicate"):
            builder.build(self.source, changed, self.root / "out")


if __name__ == "__main__":
    unittest.main()
