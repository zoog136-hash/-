#!/usr/bin/env python3
"""Select the full-suite checks the L1J workflow must run on pull requests.

TWILIGHT Integration Validate already runs every tests/*test.gd through
tools/test_project.py on every PR (test_project.py generates the synthetic L1J
CI fixtures itself). The L1J workflow additionally installs the *live* visual
fixture (tools/l1j/make_live_fixture.py), so on PRs it only needs to repeat the
checks whose code can observe L1J data: import, navigation bake and boot, plus
every test that references L1J resources, shops, loot, ground alpha or the
item/monster visual resolvers. Manual runs (workflow_dispatch) keep the full
suite on Linux and Windows.

Prints a comma-separated list for `tools/test_project.py --only`.
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

PREPARATION = ["import", "bake_navigation", "boot"]
# Code paths whose behaviour depends on the L1J fixtures or bindings. Keep in
# sync with the workflow's pull_request path filter.
L1J_SENSITIVE = re.compile(
    r"l1j|L1J|twilight_l1j|live_visual_bindings|reviewed_shop|ground_alpha|"
    r"item_visual_resolver|monster_art|renewal_shop|scripts/shop/|scripts/loot/|make_live_fixture"
)
MINIMUM_SELECTION = 20  # fail closed if the pattern silently stops matching


def select(root: Path) -> list[str]:
    tests = sorted((root / "tests").glob("*test.gd"))
    chosen = [p.stem for p in tests
              if L1J_SENSITIVE.search(p.stem) or L1J_SENSITIVE.search(p.read_text(encoding="utf-8", errors="ignore"))]
    if len(chosen) < MINIMUM_SELECTION:
        raise SystemExit(f"Only {len(chosen)} L1J-sensitive tests selected; refusing a near-empty PR suite")
    return PREPARATION + chosen


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("."))
    args = parser.parse_args()
    print(",".join(select(args.root.resolve())))


if __name__ == "__main__":
    main()
