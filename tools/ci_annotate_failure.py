#!/usr/bin/env python3
"""Surface the cause of a failed CI step as GitHub error annotations.

Job logs and artifacts live in blob storage that is not always reachable by
reviewers; annotations are readable from the checks API and the PR page.

  ci_annotate_failure.py --title "Android export" /tmp/export-android.txt
  ci_annotate_failure.py --title "L1J regression" --summary l1j-test-results

For plain log files: every SCRIPT ERROR/ERROR line (deduplicated) plus the
final lines. For a tools/test_project.py log directory: the failed, not-run
and timed-out checks from summary.json and the tail of each failed check log.
Always exits 0 so it never hides the original failure.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

MAX_ANNOTATIONS = 9   # GitHub keeps 10 error annotations per step
CHUNK_LINES = 25
TAIL_LINES = 60


def _escape(text: str) -> str:
    return text.replace("%", "%25").replace("\r", "").replace("\n", "%0A")


def emit(title: str, lines: list[str], budget: list[int]) -> None:
    for start in range(0, len(lines), CHUNK_LINES):
        if budget[0] <= 0:
            return
        chunk = "\n".join(line[:400] for line in lines[start:start + CHUNK_LINES])
        print(f"::error title={_escape(title)}::{_escape(chunk)}", flush=True)
        budget[0] -= 1


def read_lines(path: Path) -> list[str]:
    try:
        return path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError as exc:
        return [f"(cannot read {path}: {exc})"]


def annotate_log(title: str, path: Path, budget: list[int]) -> None:
    lines = read_lines(path)
    errors: list[str] = []
    seen: set[str] = set()
    for line in lines:
        if ("ERROR" in line or "Error" in line or "FAIL" in line) and line not in seen:
            seen.add(line)
            errors.append(line)
    if errors:
        emit(f"{title}: errors in {path.name}", errors[:CHUNK_LINES * 3], budget)
    emit(f"{title}: last lines of {path.name}", lines[-TAIL_LINES:] or ["(empty log)"], budget)


def annotate_summary(title: str, root: Path, budget: list[int]) -> None:
    summary_path = root / "summary.json"
    if not summary_path.is_file():
        emit(title, [f"no summary.json in {root}"], budget)
        return
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    failed = [str(name) for name in summary.get("failed", [])]
    head = [f"total={summary.get('total')} passed={summary.get('passed')} failed={len(failed)}",
            "failed: " + ", ".join(failed),
            "not_run: " + ", ".join(str(n) for n in summary.get("not_run", [])[:40])]
    emit(f"{title}: summary", head, budget)
    for name in failed:
        log = root / f"{name}.log"
        if log.is_file():
            emit(f"{title}: {name}", read_lines(log)[-CHUNK_LINES:], budget)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--title", required=True)
    parser.add_argument("--summary", type=Path, help="tools/test_project.py --logs directory")
    parser.add_argument("logs", nargs="*", type=Path)
    args = parser.parse_args()
    budget = [MAX_ANNOTATIONS]
    if args.summary is not None:
        annotate_summary(args.title, args.summary, budget)
    for path in args.logs:
        if path.exists():
            annotate_log(args.title, path, budget)
    if budget[0] == MAX_ANNOTATIONS:
        emit(args.title, ["failed before writing any log"], budget)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
