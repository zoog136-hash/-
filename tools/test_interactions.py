"""Run the focused input/loot regressions with a separate save directory per test.

No player's save is opened. Nonzero exit, script errors, missing success markers,
or reported failures fail closed. Use test_project.py for the full project suite.
"""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from test_project_support import classify_result, run_isolated

DEFAULT_TESTS = ["eight_interactions_test", "ui_pointer_transfer_test",
                 "ground_loot_system_test", "ui_navigation_preservation_test",
                 "quickslot_smoke_test", "equipment_slot_smoke_test",
                 "consumable_smoke_test"]

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--logs", default="test-results/interactions")
    parser.add_argument("--prepare", action="store_true")
    parser.add_argument("--import-timeout", type=int, default=1800,
                        help="Full imported PNG project deadline; not a test bypass")
    parser.add_argument("--test", action="append", choices=DEFAULT_TESTS)
    args = parser.parse_args()
    if args.import_timeout < 1:
        parser.error("--import-timeout must be positive")
    root = Path(__file__).resolve().parents[1]
    logs = Path(args.logs).resolve()
    logs.mkdir(parents=True, exist_ok=True)
    cases = []
    if args.prepare:
        cases += [("import", ["--editor", "--import"], args.import_timeout),
                  ("bake_navigation", ["--script", "res://tools/bake_hunting_navigation.gd"], 300),
                  ("boot", ["--quit-after", "30"], 150)]
    cases += [(name, ["--script", f"res://tests/{name}.gd"], 300) for name in (args.test or DEFAULT_TESTS)]
    report = []
    for name, extra, budget in cases:
        started = time.monotonic()
        with tempfile.TemporaryDirectory(prefix="twilight-interaction-") as data:
            env = dict(os.environ, XDG_DATA_HOME=data, APPDATA=data,
                       LOCALAPPDATA=data, GODOT_SILENCE_ROOT_WARNING="1")
            try:
                process = run_isolated([args.godot, "--headless", "--path", str(root), *extra],
                                       env=env, timeout=budget, cwd=str(root))
                output = process.stdout + process.stderr
                passed, skipped = classify_result(name, process.returncode, output)
                passed = passed and not skipped
            except (OSError, subprocess.TimeoutExpired) as exc:
                output = f"INTERACTION_RUNNER_ERROR {exc}\n"
                passed = False
        (logs / f"{name}.log").write_text(output, encoding="utf-8")
        report.append({"test": name, "passed": passed, "seconds": round(time.monotonic()-started, 2)})
        print(("PASS " if passed else "FAIL ") + name, flush=True)
        if not passed and name in ("import", "bake_navigation"):
            break
    (logs / "summary.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    return 0 if len(report) == len(cases) and all(row["passed"] for row in report) else 1

if __name__ == "__main__":
    raise SystemExit(main())
