#!/usr/bin/env python3
"""Consolidated offline validation of former single-topic CI preflights.

Only CPU/source checks run here. Godot gameplay remains verified by the full
TWILIGHT Integration suite, original pose rendering by Animation Presentation,
and Android export by the separate playtest workflow. No pass is synthesized.
"""
from __future__ import annotations
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

CHECKS = (
    ("CI workflow contract", ["tools/ci_workflow_policy.py"]),
    ("Godot cache contract", ["tools/test_ci_godot_png_cache.py"]),
    ("Resource integrity", ["tools/check_resource_integrity.py", "--root", "."]),
    ("Godot test-result parser contract", ["tools/test_project_runner_test.py"]),
    ("Godot test selection and sharding", ["tools/test_project_plan_test.py"]),
    ("L1J PR-targeted check selection", ["tools/l1j/test_select_pr_checks.py"]),
    ("Regional map shard coverage", ["tools/test_world_region_shards.py"]),
    ("Animation expansion planning", ["tests/animation_expansion_plan_test.py"]),
    ("Eight-direction real-art audit contract", ["tests/eight_direction_coverage_audit_test.py"]),
    ("Ground icon catalog", ["tools/ground_icons/build.py"]),
    ("Ground alpha masks and identity", ["tools/ground_alpha/test_alpha.py"]),
    ("Ground alpha subprocess/timeout behavior", ["tools/ground_alpha/test_verify_runner.py"]),
    ("Ground alpha prepared source", ["tools/ground_alpha/bake.py"]),
    ("Native PNG map source contracts", ["tools/map_restore/test_native_png_maps.py"]),
    ("Native map source bounds", ["tools/map_restore/test_map_source_pngs.py"]),
    ("Verified tracked PNG source decoding", ["tools/map_restore/verify_map_source_pngs.py", "--require-tracked", "--decode"]),
    ("Aden/Faith source pack contract", ["tools/map_restore/verify_native_png_pack.py",
         "--pack", "external_map_packs/aden_faith_png_v1",
         "--plan", "data/maps/aden_faith_png_plan.json"]),
    ("Inventory icon source/grade contracts", ["tools/inven_inventory/build.py"]),
    ("Android animation export scope", ["tests/android_animation_export_scope_test.py"]),
    ("Android unreachable revision exclusions", ["tests/android_runtime_reachability_test.py"]),
)


def main() -> int:
    problems: list[str] = []
    for label, args in CHECKS:
        begun = time.monotonic()
        print(f"CI_GROUP_START {label}", flush=True)
        try:
            subprocess.run([sys.executable, *args], cwd=ROOT, check=True, timeout=900)
            print(f"CI_GROUP_PASS {label} elapsed={time.monotonic() - begun:.1f}s", flush=True)
        except (OSError, subprocess.SubprocessError) as exc:
            print(f"CI_GROUP_FAIL {label}: {exc}", flush=True)
            problems.append(label)
            # Keep independent checks visible, but never claim an overall pass.
    print(f"CI_SPECIALIZED_RESULT checks={len(CHECKS)} failed={len(problems)}", flush=True)
    return 0 if not problems else 1


if __name__ == "__main__":
    raise SystemExit(main())
