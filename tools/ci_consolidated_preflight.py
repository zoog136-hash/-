#!/usr/bin/env python3
"""Consolidated offline validation of former single-topic CI preflights.

Only CPU/source checks run here. Godot gameplay remains verified by the full
TWILIGHT Integration suite, original pose rendering by Animation Presentation,
and Android export by the separate playtest workflow. No pass is synthesized.
"""
from __future__ import annotations
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from test_project_support import failure_annotation  # noqa: E402

CHECKS = (
    ("CI workflow contract", ["tools/ci_workflow_policy.py"]),
    ("Godot cache contract", ["tools/test_ci_godot_png_cache.py"]),
    ("Godot test-result parser contract", ["tools/test_project_runner_test.py"]),
    ("Godot test selection and sharding", ["tools/test_project_plan_test.py"]),
    # Pre-November resource checks (L1J, region maps, eight-direction art,
    # ground icons/alpha, PNG maps, inventory icons, animation scopes) were
    # removed with those resources (user decision 2026-11-10).
)


def main() -> int:
    problems: list[str] = []
    for label, args in CHECKS:
        begun = time.monotonic()
        print(f"CI_GROUP_START {label}", flush=True)
        output = ""
        try:
            result = subprocess.run([sys.executable, *args], cwd=ROOT, timeout=900,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace")
            output = result.stdout
            sys.stdout.write(output)
            if result.returncode != 0:
                raise subprocess.CalledProcessError(result.returncode, result.args)
            print(f"CI_GROUP_PASS {label} elapsed={time.monotonic() - begun:.1f}s", flush=True)
        except (OSError, subprocess.SubprocessError) as exc:
            if isinstance(exc, subprocess.TimeoutExpired) and exc.stdout:
                output = exc.stdout if isinstance(exc.stdout, str) else exc.stdout.decode(errors="replace")
                sys.stdout.write(output)
            print(f"CI_GROUP_FAIL {label}: {exc}", flush=True)
            if os.environ.get("GITHUB_ACTIONS") == "true":
                print(failure_annotation(label, output + "\n" + str(exc)), flush=True)
            problems.append(label)
            # Keep independent checks visible, but never claim an overall pass.
    print(f"CI_SPECIALIZED_RESULT checks={len(CHECKS)} failed={len(problems)}", flush=True)
    return 0 if not problems else 1


if __name__ == "__main__":
    raise SystemExit(main())
