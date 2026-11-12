#!/usr/bin/env python3
"""Run focused exchange contracts with real committed resources and isolated saves.

This adds exchange validation without changing the required core gate's test
list. Synthetic listing contracts and the actual Main's absent-capture path
remain distinct; this runner does not prove all-server capture or original art.
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

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))
import ci_core
from test_project_support import (
    ERROR, ISOLATION_FLAG_VARIABLES, ISOLATION_ROOT_VARIABLES,
)

CHECKS = (
    ("frozen_exchange_test", "FROZEN_EXCHANGE_RESULT", "scalar"),
    ("frozen_exchange_main_test", "FROZEN_EXCHANGE_MAIN_RESULT", "scalar"),
    ("core_runtime_save_test", "CORE_RUNTIME_SAVE_RESULT", "json"),
)


def receipt_passes(output: str, marker: str, kind: str) -> bool:
    """A zero process exit alone is insufficient; require the suite's receipt."""
    if ERROR.search(output):
        return False
    receipts = [line[len(marker) + 1:] for line in output.splitlines()
                if line.startswith(marker + " ")]
    if len(receipts) != 1:
        return False
    if kind == "scalar":
        match = re.match(r"checks=([1-9][0-9]*) failures=0(?:\s|$)", receipts[0])
        return match is not None
    try:
        report = json.loads(receipts[0])
    except (ValueError, TypeError):
        return False
    return (isinstance(report, dict)
            and type(report.get("checks")) is int and report["checks"] > 0
            and report.get("failures") == [])


def isolated_env(profile: str) -> dict:
    env = os.environ.copy()
    env.update(
        XDG_DATA_HOME=profile + "/data",
        XDG_CONFIG_HOME=profile + "/config",
        XDG_CACHE_HOME=profile + "/cache",
        APPDATA=profile + "/appdata",
        LOCALAPPDATA=profile + "/localappdata",
    )
    for key in ISOLATION_ROOT_VARIABLES:
        env[key] = profile
    for key in ISOLATION_FLAG_VARIABLES:
        env[key] = "1"
    return env


def run(command: list[str], target: Path, log: Path, timeout: int,
        marker: str = "", kind: str = "") -> None:
    with tempfile.TemporaryDirectory(prefix="twilight-exchange-check-") as profile:
        with log.open("w", encoding="utf-8") as stream:
            try:
                result = subprocess.run(
                    command, cwd=target, env=isolated_env(profile),
                    stdout=stream, stderr=subprocess.STDOUT, timeout=timeout,
                )
            except subprocess.TimeoutExpired:
                stream.write("\nEXCHANGE_CHECK_FAILED: timeout\n")
                raise RuntimeError(f"{log.name}: timed out after {timeout}s")
    output = log.read_text(encoding="utf-8", errors="replace")
    if result.returncode or ERROR.search(output) or (
            marker and not receipt_passes(output, marker, kind)):
        for line in output.splitlines()[-15:]:
            print(line, flush=True)
        raise RuntimeError(
            f"{log.name}: exit={result.returncode}; "
            "engine errors or missing/invalid completion receipt"
        )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=TOOLS.parent)
    parser.add_argument("--stage", type=Path, required=True)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--logs", type=Path, required=True)
    args = parser.parse_args()
    root, target, logs = args.root.resolve(), args.stage.resolve(), args.logs.resolve()
    pack = os.environ.get("TWILIGHT_SOURCE_MAP_PACK")
    if not pack or not Path(pack).exists():
        raise ValueError("TWILIGHT_SOURCE_MAP_PACK must name the prepared current map input path")
    logs.mkdir(parents=True, exist_ok=True)
    summary = {
        "scope": "synthetic exchange contracts; actual Main absent-capture path; save preservation",
        "checks": [name for name, _, _ in CHECKS],
        "passed": [], "failed": [], "not_run": [name for name, _, _ in CHECKS],
        "status": "running",
    }

    def save_summary() -> None:
        (logs / "summary.json").write_text(
            json.dumps(summary, indent=2) + "\n", encoding="utf-8"
        )

    save_summary()
    try:
        original_checks = ci_core.CHECKS
        try:
            # Only this disposable stage gets the extra graph roots. The
            # original required core CHECKS stays unchanged on disk/in memory.
            ci_core.CHECKS = [(name, []) for name, _, _ in CHECKS]
            manifest = ci_core.stage(root, target)
        finally:
            ci_core.CHECKS = original_checks
        (logs / "resource-paths.json").write_text(
            json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
        )
        run(
            [args.godot, "--headless", "--path", str(target),
             "--editor", "--import", "--quit"],
            target, logs / "import.txt", 1800,
        )
        for name, marker, kind in CHECKS:
            try:
                run(
                    [args.godot, "--headless", "--path", str(target),
                     "--script", "res://tests/" + name + ".gd"],
                    target, logs / (name + ".txt"), 180, marker, kind,
                )
            except Exception:
                summary["failed"].append(name)
                raise
            finally:
                summary["not_run"].remove(name)
                save_summary()
            summary["passed"].append(name)
            save_summary()
            print("EXCHANGE_CHECK_OK", name, flush=True)
        summary["status"] = "passed"
        print("FOCUSED_EXCHANGE_CHECKS_RESULT checks=3 failures=0", flush=True)
    except Exception as exc:
        summary["status"] = "failed"
        summary["error"] = str(exc)
        raise
    finally:
        save_summary()


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        message = str(error).replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
        print("::error title=Focused exchange checks::" + message, flush=True)
        raise
