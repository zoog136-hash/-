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
    "l1j-runtime-validate.yml",
    "godot-import-cache-contract.yml",
    "main-debug-audit.yml",
    "ci-consolidated-preflight.yml",
})
ARCHIVE = Path("docs/ci/workflow-archive-20261028")
ARCHIVED_COUNT = 79
# Workflows added after the 84 -> 10 consolidation. Each must be listed here
# explicitly (never silently) and must stay path-filtered so it does not run on
# every pull request.
POST_CONSOLIDATION = frozenset({"auto-hunting523-validate.yml", "twilight-android-playtest-apk.yml",
                                # complete-523 client tool unit tests (#315, #318)
                                "client523-source-tool.yml", "client523-ui-tool.yml"})
# User-approved required merge gates (2026-11-02 transition policy, AGENTS.md,
# docs/CI_TRANSITION_POLICY.md). They must run on every pull request to main,
# so they are listed explicitly and exempt from the path-filter rule only.
REQUIRED_GATES = frozenset({"core-transition-validate.yml"})


def check(root: Path) -> dict[str, int]:
    paths = root / ".github/workflows"
    current = {p.name for p in paths.glob("*.yml")} | {p.name for p in paths.glob("*.yaml")}
    allowed = ACTIVE | POST_CONSOLIDATION | REQUIRED_GATES
    if not ACTIVE <= current or not current <= allowed:
        raise ValueError(f"Unexpected active CI workflows: {sorted(current ^ allowed)}")
    for name in current & POST_CONSOLIDATION:
        text = (paths / name).read_text(encoding="utf-8")
        trigger = text.split("jobs:", 1)[0]
        if "pull_request:" in trigger and "paths:" not in trigger:
            raise ValueError(f"{name} must stay path-filtered, not run on every PR")
    for name in REQUIRED_GATES:
        if name not in current:
            raise ValueError(f"Required merge gate workflow missing: {name}")
        trigger = (paths / name).read_text(encoding="utf-8").split("jobs:", 1)[0]
        if "pull_request:" not in trigger or "paths:" in trigger:
            raise ValueError(f"{name} must run on every pull request")
    archive = root / ARCHIVE
    historical = {p.name for p in archive.glob("*.yml")} | {p.name for p in archive.glob("*.yaml")}
    # 84 workflows were archived at consolidation; the five PR122 authoring
    # workflows were removed with the PR122 pipeline on 2026-11-07.
    if len(historical) != ARCHIVED_COUNT:
        raise ValueError(f"Expected all {ARCHIVED_COUNT} archived source workflows, found {len(historical)}")
    if not (ACTIVE - {"ci-consolidated-preflight.yml"}) <= historical:
        raise ValueError("Missing preserved original of an active workflow")
    if not historical.isdisjoint({"ci-consolidated-preflight.yml"}):
        raise ValueError("New consolidated workflow incorrectly counted as legacy")
    workflow = (paths / "main-debug-audit.yml").read_text(encoding="utf-8")
    header = workflow.split("permissions:", 1)[0]
    if "workflow_dispatch:" not in header or "pull_request:" in header or "push:" in header:
        raise ValueError("Main Debug must be available manually, not duplicate every PR")
    return {"active_workflows": len(current), "archived_workflows": len(historical),
            "new_consolidated_workflows": 1, "post_consolidation_workflows": len(current & POST_CONSOLIDATION),
            "required_gate_workflows": len(current & REQUIRED_GATES)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("."))
    args = parser.parse_args()
    print("TWILIGHT_CI_CONSOLIDATION_OK", check(args.root.resolve()), flush=True)


if __name__ == "__main__":
    main()
