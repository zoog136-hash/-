"""Controlled subprocess tests of the shard runner, not proof of Godot gameplay."""
from __future__ import annotations
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from world_region_shards import expected_shards, validate_output


class RegionShardingTests(unittest.TestCase):
    def test_main_index_partition_is_exact(self):
        parts = expected_shards(ROOT / "data/maps/field_index.json")
        self.assertEqual([len(parts[k]) for k in parts], [10, 1, 5, 2, 4])
        self.assertEqual(len(set(sum(parts.values(), []))), 22)

    def test_output_needs_every_map_and_full_success(self):
        ids = ["oman_01", "oman_02"]
        output = "REGION CHECKED oman_01\nREGION CHECKED oman_02\nREGION maps=2 checks=89 families=1\nWORLD_REGIONS_OK\n"
        self.assertTrue(validate_output("oman_", ids, 0, output)[0])
        for invalid in [
            output.replace("REGION CHECKED oman_02\n", ""),
            output.replace("WORLD_REGIONS_OK", ""),
            output + "REGION FAIL: unexpected\n",
            output.replace("families=1", "families=0"),
            output.replace("checks=89", "checks=0"),
            output.replace("REGION CHECKED oman_02", "REGION CHECKED oman_01"),
        ]:
            self.assertFalse(validate_output("oman_", ids, 0, invalid)[0])
        self.assertFalse(validate_output("oman_", ids, 1, output)[0])

    def test_counted_variant_summary_matches_current_godot_producer(self):
        ids = ["oman_01", "oman_02"]
        output = "REGION CHECKED oman_01\nREGION CHECKED oman_02\nREGION maps=2 checks=89 families=1 authored_variant_probes=1\nWORLD_REGIONS_OK\n"
        self.assertEqual(validate_output("oman_", ids, 0, output), (True, "passed", 89))
        for invalid in [
            output.replace("authored_variant_probes=1", "authored_variant_probes=3"),
            output.replace("authored_variant_probes=1", "authored_variant_probes=-1"),
            output.replace("authored_variant_probes=1", "authored_variant_probes=oops"),
            output.replace("authored_variant_probes=1", "authored_variant_probes=1 ignored=true"),
            output + "REGION maps=2 checks=89 families=1 authored_variant_probes=1\n",
            output.replace("REGION CHECKED oman_02\n", ""),
            output + "REGION FAIL: invalid physical footprint\n",
            output.replace("checks=89", "checks=0"),
            output.replace("WORLD_REGIONS_OK", ""),
        ]:
            with self.subTest(output=invalid):
                self.assertFalse(validate_output("oman_", ids, 0, invalid)[0])
        self.assertFalse(validate_output("oman_", ids, 1, output)[0])

    def test_controlled_shards_cover_all_22_in_ten_processes(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            (home / "data/maps").mkdir(parents=True)
            original = json.loads((ROOT / "data/maps/field_index.json").read_text())
            (home / "data/maps/field_index.json").write_text(json.dumps(original))
            fake = home / "fake_godot.py"
            fake.write_text("""#!/usr/bin/env python3
import json,pathlib,sys
root=pathlib.Path(sys.argv[sys.argv.index('--path')+1])
index=json.loads((root/'data/maps/field_index.json').read_text())
prefix=next(a.split('=',1)[1] for a in sys.argv if a.startswith('--prefix='))
selected=next(a.split('=',1)[1].split(',') for a in sys.argv if a.startswith('--map-ids='))
actual=[r['map_id'] for r in index if r['map_id'].startswith(prefix) and r['map_id'] in selected]
for map_id in actual: print('REGION CHECKED', map_id)
print('REGION maps=%d checks=100 families=1'%len(actual))
print('WORLD_REGIONS_OK')
""")
            fake.chmod(0o755)
            result = subprocess.run([
                sys.executable, str(ROOT / "tools/world_region_shards.py"), "--godot", str(fake),
                "--path", str(home), "--logs", str(home / "logs"), "--timeout", "10"
            ], capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("WORLD_REGIONS_OK maps=22 families=5 checks=1000", result.stdout)
            report = json.loads((home / "logs/summary.json").read_text())
            self.assertTrue(report["passed"])
            self.assertEqual(report["completed_regions"], 22)
            self.assertEqual([f["expected_maps"] for f in report["families"][:5]],
                             [[f"oman_{i:02d}"] for i in range(1, 6)])
            self.assertEqual(report["families"][5]["expected_maps"],
                             [f"oman_{i:02d}" for i in range(6, 11)])
            self.assertEqual(len(report["families"]), 10)
            self.assertEqual(report["shard_count"], 10)


if __name__ == "__main__":
    unittest.main()
