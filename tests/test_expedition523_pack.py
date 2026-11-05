"""Focused source-join regressions; original data stays outside Git."""
import copy
import hashlib
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "expedition_pack", Path(__file__).resolve().parents[1] / "tools/build_expedition523_pack.py")
pack = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pack)


class SourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = os.environ.get("TWILIGHT_EXPEDITION523_SOURCE")
        if not source:
            raise unittest.SkipTest("private cumulative523 source ZIP not installed")
        cls.compiled = pack.compile_pack(Path(source))

    def tables(self):
        return copy.deepcopy(self.compiled["tables"])

    def test_exact_source_and_deterministic_output(self):
        self.assertEqual(self.compiled["source_sha256"], pack.SOURCE_SHA256)
        self.assertEqual(pack.validate(self.tables())["event_rows"], 4487)
        self.assertEqual(hashlib.sha256(pack.encode(self.compiled)).hexdigest(),
                         "39f075e3aea122080b060c8682c81dc6b43e3cb97e886504bdefd9dfc2034991")

    def test_changed_weight_is_rejected(self):
        t = self.tables()
        t[pack.PREFIX+"SpotReward"][0]["Probability"] += 1
        with self.assertRaisesRegex(ValueError, "weight sum"):
            pack.validate(t)

    def test_reward_reference_is_required(self):
        t = self.tables()
        t[pack.PREFIX+"SpotReward"][0]["RewardID"] = -1
        with self.assertRaisesRegex(ValueError, "reward join"):
            pack.validate(t)

    def test_special_events_are_not_ordinary_pools(self):
        t = self.tables()
        pair = next((r[pack.PREFIX+"SpotID"], r[pack.PREFIX+"GroupID"])
                    for r in t[pack.PREFIX+"SpotReward"] if r["IsSpecial"])
        for r in t[pack.PREFIX+"SpotReward"]:
            if (r[pack.PREFIX+"SpotID"], r[pack.PREFIX+"GroupID"]) == pair:
                r["IsSpecial"] = False
        with self.assertRaisesRegex(ValueError, "special event"):
            pack.validate(t)

    def test_completion_scope_is_independent_of_entry_minimum(self):
        t = self.tables()
        self.assertEqual(pack.validate(t)["below_minimum_completion_pairs"], 18)
        for spot in t[pack.PREFIX+"Spot"]:
            if spot["ID"] == 202:
                spot["MinGrade"] = 0
        with self.assertRaisesRegex(ValueError, "coverage"):
            pack.validate(t)

    def test_completion_pair_duplication_is_rejected(self):
        t = self.tables()
        t[pack.PREFIX+"CompleteRewardView"].append(t[pack.PREFIX+"CompleteRewardView"][0].copy())
        with self.assertRaisesRegex(ValueError, "completion pairs"):
            pack.validate(t)

    def test_box_quantities_remain_separate_candidates(self):
        candidates = [r for r in self.compiled["tables"]["LuckyBagEntityView"]
                      if r["LuckyBagClassID"] == 37864 and r["ItemClassID"] == 3252]
        self.assertEqual(sorted(r["ItemAmount"] for r in candidates), [100, 1000])
        self.assertEqual(len({r["ID"] for r in candidates}), 2)

    def test_box_weight_mutation_is_rejected(self):
        t = self.tables()
        t["LuckyBagEntityView"][0]["Probability"] += 1
        with self.assertRaisesRegex(ValueError, "box raw weight"):
            pack.validate(t)


class MissingSourceTests(unittest.TestCase):
    def test_an_arbitrary_zip_is_not_cumulative523(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "untrusted.zip"
            source.write_bytes(b"not the verified original")
            with self.assertRaisesRegex(ValueError, "archive SHA256"):
                pack.compile_pack(source)


if __name__ == "__main__":
    unittest.main()
