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

MARKER = "ORIGINAL_CLIENT_P0_P2_RESULT "


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-log", required=True, help="stdout of the Godot test run")
    parser.add_argument("--commit", required=True, help="implementation commit SHA the run was made on")
    parser.add_argument("--checklist", default="data/original_client/acceptance_checklist.json")
    parser.add_argument("--evidence", default="tests/original_client_contract_p0_p2_test.gd")
    args = parser.parse_args()

    report = None
    for line in Path(args.run_log).read_text(encoding="utf-8").splitlines():
        if line.startswith(MARKER):
            report = json.loads(line[len(MARKER):])
    if report is None:
        print("no result line found", file=sys.stderr)
        return 2
    if report.get("target_binary_executed") is not False:
        print("run claims a target binary was executed; refusing to record", file=sys.stderr)
        return 2

    path = Path(args.checklist)
    data = json.loads(path.read_text(encoding="utf-8"))
    ran = report["tests"]
    changed = 0
    for entry in data["tests"]:
        outcome = ran.get(entry["test_id"])
        if outcome is None:
            continue
        entry["result"] = "PASS" if outcome["pass"] else "FAIL"
        entry["execution_status"] = "RUN_ON_DESIGN_MODULE_FIXTURE"
        entry["implementation_commit"] = args.commit
        entry["fixture_hash"] = report["fixture_sha256"]
        entry["evidence_log"] = args.evidence + " :: " + ("; ".join(outcome["details"]) if outcome["details"] else "all checks passed")
        changed += 1
    data["note_result_scope_ko"] = (
        "result가 PASS인 항목은 DESIGN 모듈이 문서화된 계약을 fixture에서 따랐다는 뜻이다. "
        "원본 바이너리 실행·native 동등성·실제 화면 결과를 뜻하지 않는다. NOT_RUN_ON_IMPLEMENTATION 항목은 미실행이다."
    )
    data["recorded_run"] = {"commit": args.commit, "fixture_sha256": report["fixture_sha256"],
                            "source_lock_sha256": report["source_lock_sha256"], "executed": report["executed"]}
    path.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    failed = [e["test_id"] for e in data["tests"] if e.get("result") == "FAIL"]
    print(f"recorded {changed} tests; failed={failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
