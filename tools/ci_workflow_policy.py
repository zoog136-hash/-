#!/usr/bin/env python3
"""Fail-closed TWILIGHT Actions consolidation contract.

All historical workflow YAMLs are archived verbatim outside .github/workflows.
A change may not silently re-expand the active workflow fanout.
"""
from __future__ import annotations

import argparse
from pathlib import Path

ACTIVE = frozenset({
    "cancel-superseded-pr-ci.yml",
    "resource-integrity.yml",
    "godot-validate.yml",
    "twilight-integration-validate.yml",
    "animation-presentation-validate.yml",
    "twilight-android-playtest-apk.yml",
    "l1j-runtime-validate.yml",
    "godot-import-cache-contract.yml",
    "main-debug-audit.yml",
    "ci-consolidated-preflight.yml",
})
ARCHIVE = Path("docs/ci/workflow-archive-20261028")


def check(root: Path) -> dict[str, int]:
    paths = root / ".github/workflows"
    current = {p.name for p in paths.glob("*.yml")} | {p.name for p in paths.glob("*.yaml")}
    if len(current) > 10 or current != ACTIVE:
        raise ValueError(f"Unexpected active CI workflows; expected exactly 10: {sorted(current ^ ACTIVE)}")
    archive = root / ARCHIVE
    historical = {p.name for p in archive.glob("*.yml")} | {p.name for p in archive.glob("*.yaml")}
    if len(historical) != 84:
        raise ValueError(f"Expected all 84 archived source workflows, found {len(historical)}")
    if not (ACTIVE - {"ci-consolidated-preflight.yml"}) <= historical:
        raise ValueError("Missing preserved original of an active workflow")
    if not historical.isdisjoint({"ci-consolidated-preflight.yml"}):
        raise ValueError("New consolidated workflow incorrectly counted as legacy")
    workflow = (paths / "main-debug-audit.yml").read_text(encoding="utf-8")
    header = workflow.split("permissions:", 1)[0]
    if "workflow_dispatch:" not in header or "pull_request:" in header or "push:" in header:
        raise ValueError("Main Debug must be available manually, not duplicate every PR")
    return {"active_workflows": len(current), "archived_workflows": len(historical),
            "new_consolidated_workflows": 1}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("."))
    args = parser.parse_args()
    print("TWILIGHT_CI_CONSOLIDATION_OK", check(args.root.resolve()), flush=True)


if __name__ == "__main__":
    main()
