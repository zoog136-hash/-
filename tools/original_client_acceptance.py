#!/usr/bin/env python3
"""Record Godot test results into data/original_client/acceptance_checklist.json.

Only tests that appear in the run's JSON result are changed. Tests that were not
executed keep execution_status NOT_RUN_ON_IMPLEMENTATION; this tool never turns
an unexecuted test into PASS. A PASS here means the DESIGN module followed the
written contract on the fixture. It is not native equivalence or an on-screen result.
"""
import argparse
import json
import sys
from pathlib import Path

MARKER_PREFIX = "ORIGINAL_CLIENT_"
EVIDENCE = {
    "ORIGINAL_CLIENT_P0_P2_RESULT": "tests/original_client_contract_p0_p2_test.gd",
    "ORIGINAL_CLIENT_P2_LAYERS_CACHE_RESULT": "tests/original_client_p2_layers_cache_test.gd",
    "ORIGINAL_CLIENT_P3_RESULT": "tests/original_client_p3_map_input_test.gd",
    "ORIGINAL_CLIENT_P4_RESULT": "tests/original_client_p4_motion_effect_curve_test.gd",
    "ORIGINAL_CLIENT_P5_RESULT": "tests/original_client_p5_ui_state_test.gd",
    "ORIGINAL_CLIENT_P6_P7_RESULT": "tests/original_client_p6_p7_scene_test.gd",
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-log", required=True, action="append", help="stdout of a Godot test run (repeatable)")
    parser.add_argument("--commit", required=True, help="implementation commit SHA the run was made on")
    parser.add_argument("--checklist", default="data/original_client/acceptance_checklist.json")
    args = parser.parse_args()

    reports = []  # (marker, report)
    for log in args.run_log:
        for line in Path(log).read_text(encoding="utf-8").splitlines():
            if line.startswith(MARKER_PREFIX) and " {" in line:
                marker, payload = line.split(" ", 1)
                reports.append((marker, json.loads(payload)))
    if not reports:
        print("no result line found", file=sys.stderr)
        return 2
    for marker, report in reports:
        if report.get("target_binary_executed") is not False:
            print("run claims a target binary was executed; refusing to record", file=sys.stderr)
            return 2

    path = Path(args.checklist)
    data = json.loads(path.read_text(encoding="utf-8"))
    changed = 0
    executed = 0
    for marker, report in reports:
        evidence = EVIDENCE.get(marker, marker)
        fixture = report.get("fixture_sha256", "n/a")
        executed += report["executed"]
        for entry in data["tests"]:
            outcome = report["tests"].get(entry["test_id"])
            if outcome is None:
                continue
            entry["result"] = "PASS" if outcome["pass"] else "FAIL"
            entry["execution_status"] = "RUN_ON_DESIGN_MODULE_FIXTURE"
            entry["implementation_commit"] = args.commit
            entry["fixture_hash"] = fixture
            entry["evidence_log"] = evidence + " :: " + ("; ".join(outcome["details"]) if outcome["details"] else "all checks passed")
            changed += 1
    data["note_result_scope_ko"] = (
        "result가 PASS인 항목은 DESIGN 모듈이 문서화된 계약을 fixture에서 따랐다는 뜻이다. "
        "원본 바이너리 실행·native 동등성·실제 화면 결과를 뜻하지 않는다. NOT_RUN_ON_IMPLEMENTATION 항목은 미실행이다."
    )
    first = reports[0][1]
    data["recorded_run"] = {"commit": args.commit, "fixture_sha256": first.get("fixture_sha256"),
                            "source_lock_sha256": first.get("source_lock_sha256"), "executed": executed, "markers": [m for m, _ in reports]}
    path.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    failed = [e["test_id"] for e in data["tests"] if e.get("result") == "FAIL"]
    print(f"recorded {changed} tests; failed={failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
