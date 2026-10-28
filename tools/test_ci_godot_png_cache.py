"""Controlled file tests; do not claim that a simulated import is gameplay QA."""
from pathlib import Path
import tempfile
import unittest

from ci_godot_png_cache import SHARDS, MAX_SHARD_BYTES, eligible, restore, shard_of, stage


class ImportCacheContract(unittest.TestCase):
    def test_shared_import_deadlines_are_not_900_seconds(self):
        repo = Path(__file__).resolve().parents[1]
        project_runner = (repo / "tools/test_project.py").read_text()
        interactions = (repo / "tools/test_interactions.py").read_text()
        self.assertIn("default=1800", project_runner)
        self.assertIn('default=1800', interactions)
        self.assertNotIn('["--editor", "--import"], 900', interactions)

    def test_deterministic_shards_and_exact_files(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            imported = root / ".godot" / "imported"
            imported.mkdir(parents=True)
            names = [f"sheet-{i:03}.png-{i:032x}.ctex" for i in range(120)]
            for name in names:
                (imported / name).write_bytes(name.encode())
            (imported / "not-an-import.txt").write_text("unrelated")
            manifest = stage(root)
            self.assertEqual(sum(x[0] for x in manifest), len(names))
            self.assertTrue(all(0 < n < 120 for n, _ in manifest))
            self.assertTrue(all(size < MAX_SHARD_BYTES for _, size in manifest))
            self.assertEqual(shard_of(names[0]), shard_of(names[0]))
            for path in imported.iterdir():
                if path.name.endswith(".ctex"):
                    path.unlink()
            restored = restore(root)
            self.assertEqual(sum(n for n, _ in restored), len(names))
            self.assertEqual(sorted(p.name for p in imported.glob("*.ctex")), names)
            self.assertEqual(sum(n for n, _ in restore(root)), 0)

    def test_rejects_wrong_bucket_file_and_does_not_import_arbitrary_path(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            shard = root / ".ci-godot-cache" / "shard-0"
            shard.mkdir(parents=True)
            invalid = "staged.png-" + "a" * 32 + ".ctex"
            if shard_of(invalid) == 0:
                invalid = next(f"staged-{i}.png-{'a'*32}.ctex"
                               for i in range(100) if shard_of(f"staged-{i}.png-{'a'*32}.ctex") != 0)
            (shard / invalid).write_bytes(b"not trusted bucket")
            with self.assertRaisesRegex(ValueError, "Invalid PNG"):
                restore(root)

    def test_stage_refuses_missing_complete_import(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / ".godot/imported").mkdir(parents=True)
            with self.assertRaisesRegex(ValueError, "Missing expected PNG"):
                stage(root)


if __name__ == "__main__":
    unittest.main()
