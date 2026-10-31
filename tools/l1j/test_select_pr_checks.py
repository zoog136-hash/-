#!/usr/bin/env python3
"""Contract for the L1J workflow's pull-request selection (select_pr_checks.py)."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tools" / "l1j"))

from select_pr_checks import PREPARATION, select  # noqa: E402
from test_project_support import select_checks  # noqa: E402


class SelectPrChecksTest(unittest.TestCase):
    def setUp(self) -> None:
        self.selected = select(ROOT)
        self.discovered = [p.stem for p in sorted((ROOT / "tests").glob("*test.gd"))]

    def test_preparation_first_and_every_l1j_test_included(self) -> None:
        self.assertEqual(self.selected[:3], PREPARATION)
        l1j_tests = [name for name in self.discovered if name.startswith("l1j_")]
        self.assertTrue(l1j_tests)
        self.assertTrue(set(l1j_tests) <= set(self.selected))
        for name in ["ground_alpha_test", "shop_buyback_test", "item_visual_test"]:
            if name in self.discovered:
                self.assertIn(name, self.selected)

    def test_selection_is_a_strict_subset_accepted_by_the_runner(self) -> None:
        checks = [(name, []) for name in PREPARATION] + [(name, []) for name in self.discovered]
        result, _plan = select_checks(checks, ",".join(self.selected))
        self.assertEqual([name for name, _ in result], self.selected)
        self.assertLess(len(self.selected), len(checks))
        self.assertEqual(len(self.selected), len(set(self.selected)))


if __name__ == "__main__":
    unittest.main()
