"""Run all 24 playable region tests in isolated, complete family shards.

All assertions remain in tests/world_regions_test.gd. A shard only passes
when every expected map prints its completion marker and Godot reports zero
failures. Avoid one 540-second budget spanning 24 full world boots.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

from test_project_support import classify_result, run_isolated

FAMILIES = ("oman_", "domination_", "escaros_", "albino_", "faith_")
CHECKED = re.compile(r"^REGION CHECKED (\S+)\s*$", re.MULTILINE)
SUMMARY = re.compile(r"^REGION maps=(\d+) checks=(\d+) families=(\d+)\s*$", re.MULTILINE)


def expected_shards(index_path: Path) -> dict[str, list[str]]:
    entries = json.loads(index_path.read_text(encoding="utf-8"))
    if not isinstance(entries, list) or len(entries) != 24:
        raise ValueError("Expected exactly 24 registered playable regions")
    ids = [row["map_id"] for row in entries]
    if len(set(ids)) != len(ids) or not all(isinstance(i, str) for i in ids):
        raise ValueError("Duplicate or invalid region IDs")
    mapping = {prefix: [i for i in ids if i.startswith(prefix)] for prefix in FAMILIES}
    if not all(mapping.values()) or sorted(sum(mapping.values(), [])) != sorted(ids):
        raise ValueError("Regions are missing from family shard coverage")
    return mapping


def validate_output(prefix: str, expected_ids: list[str], returncode: int, output: str) -> tuple[bool, str, int]:
    passed, skipped = classify_result("world_regions_test", returncode, output)
    if skipped or not passed:
        return False, "Godot process failed, emitted errors, or skipped", 0
    checked = CHECKED.findall(output)
    if checked != expected_ids:
        return False, f"Completed {checked!r} instead of required {expected_ids!r}", 0
    reports = SUMMARY.findall(output)
    if len(reports) != 1:
        return False, "Missing or duplicated REGION summary", 0
    maps, checks, families = map(int, reports[0])
    if maps != len(expected_ids) or checks <= 0 or families != 1:
        return False, f"Invalid counts: maps={maps} checks={checks} families={families}", checks
    if output.splitlines().count("WORLD_REGIONS_OK") != 1:
        return False, "Missing or duplicate WORLD_REGIONS_OK marker", checks
    return True, "passed", checks


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--path", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--logs", type=Path, default=Path("test-results/world-region-shards"))
    parser.add_argument("--timeout", type=int, default=360, help="Seconds for each individual family shard")
    args = parser.parse_args()
    root = args.path.resolve()
    args.logs.mkdir(parents=True, exist_ok=True)
    if args.timeout < 1:
        parser.error("--timeout must be positive")
    try:
        coverage = expected_shards(root / "data/maps/field_index.json")
    except (ValueError, OSError, KeyError, TypeError) as exc:
        print("WORLD_REGIONS_FAILED: bad map index:", exc, flush=True)
        return 1
    findings = []
    total_checks = 0
    all_ok = True
    for prefix, ids in coverage.items():
        label = prefix.rstrip("_")
        env = os.environ.copy()
        with tempfile.TemporaryDirectory(prefix=f"twilight-test-world-{label}-") as user_data:
            for key in ("XDG_DATA_HOME", "APPDATA", "LOCALAPPDATA"):
                env[key] = user_data
            cmd = [args.godot, "--headless", "--path", str(root), "--script",
                   "res://tests/world_regions_test.gd", "--", f"--prefix={prefix}"]
            try:
                result = run_isolated(cmd, env=env, timeout=args.timeout, cwd=str(root))
                output = result.stdout + result.stderr
                code = result.returncode
                timed_out = False
            except subprocess.TimeoutExpired as exc:
                stdout = exc.stdout.decode(errors="replace") if isinstance(exc.stdout, bytes) else (exc.stdout or "")
                stderr = exc.stderr.decode(errors="replace") if isinstance(exc.stderr, bytes) else (exc.stderr or "")
                output = f"SHARD_TIMEOUT after {args.timeout}s\n" + stdout + stderr
                code = -1
                timed_out = True
            except OSError as exc:
                output = f"SHARD_START_FAILED: {exc}\n"
                code = -1
                timed_out = False
        (args.logs / f"{label}.log").write_text(output, encoding="utf-8")
        ok, reason, checks = validate_output(prefix, ids, code, output)
        if timed_out:
            reason = f"shard timed out after {args.timeout}s"
        total_checks += checks
        all_ok &= ok
        findings.append({"family": label, "expected_maps": ids, "completed_maps": CHECKED.findall(output),
                         "checks": checks, "passed": ok, "reason": reason, "timed_out": timed_out,
                         "exit_code": code})
        print(f"WORLD_SHARD_{'OK' if ok else 'FAILED'} {label} {len(ids)} maps {checks} checks: {reason}", flush=True)
        # Continue all shards: a failed family must not conceal regressions in other families.
    summary = {"expected_regions": 24, "completed_regions": sum(len(x["completed_maps"]) for x in findings),
               "total_checks": total_checks, "families": findings, "passed": all_ok}
    (args.logs / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if all_ok:
        print(f"WORLD_REGIONS_OK maps=24 families=5 checks={total_checks}", flush=True)
    else:
        print("WORLD_REGIONS_FAILED: at least one full regional shard failed", flush=True)
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
