#!/usr/bin/env python3
"""Complete CI coverage for an immutable PR candidate, without merging or duplicate runs.

A successful launch means run registration, NOT successful validation.
Use `verify` on the resulting report for a fail-closed validation verdict.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import fnmatch
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen

import yaml

REPO = "zoog136-hash/-"
MANUAL_CI = {
    "main-debug-audit.yml", "main-debug-followup.yml",
    "ui-renewal-validate.yml", "twilight-android-playtest-apk.yml",
}
PUBLISHERS = {"restore-pr80-original-assets.yml", "restore-pr80-visual-assets.yml"}
REQUIRED = MANUAL_CI | {
    "godot-validate.yml", "monster-world-validate.yml", "resource-integrity.yml",
    "equipment-collections-runtime.yml", "ground-full-matte.yml",
    "hit-feedback-validate.yml", "potion-feedback-validate.yml",
    "shop-consumables-validate.yml", "termux-zip-update-check.yml",
    "monster-capture-regression.yml", "reviewed-shop-regression.yml",
}
RUN_KEYS = ("id", "html_url", "head_sha", "head_branch", "event", "status", "conclusion", "run_attempt")
BAD = {"failure", "cancelled", "timed_out", "action_required", "stale", "startup_failure"}


def targets_main(config: object) -> bool:
    if not isinstance(config, dict):
        return True
    patterns = config.get("branches")
    result = patterns is None
    for pattern in patterns or []:
        if fnmatch.fnmatchcase("main", str(pattern).lstrip("!")):
            result = not str(pattern).startswith("!")
    return result and not any(fnmatch.fnmatchcase("main", p) for p in config.get("branches-ignore", []))


def inventory(root: Path) -> tuple[list[dict], list[dict]]:
    selected, excluded = [], []
    for path in sorted((root / ".github/workflows").glob("*")):
        if path.suffix not in {".yml", ".yaml"}:
            continue
        text = path.read_text(encoding="utf-8")
        data = yaml.load(text, Loader=yaml.BaseLoader)
        if not isinstance(data, dict) or not isinstance(data.get("jobs"), dict):
            raise ValueError(f"Malformed workflow: {path.name}")
        events = data.get("on", {})
        if isinstance(events, str):
            events = {events: {}}
        elif isinstance(events, list):
            events = {name: {} for name in events}
        if not isinstance(events, dict):
            raise ValueError(f"Malformed triggers: {path.name}")
        row = {"file": path.name, "name": data.get("name", path.stem),
               "definition_sha256": hashlib.sha256(text.encode()).hexdigest(), "blockers": []}
        active = any(e in events and targets_main(events[e]) for e in ("push", "pull_request"))
        if path.name in PUBLISHERS:
            excluded.append({"file": path.name, "reason": "Historical resource publisher; may push to main, not CI"})
            continue
        if not active and path.name not in MANUAL_CI:
            excluded.append({"file": path.name, "reason": "Historical/manual apply or non-main workflow, not main validation"})
            continue
        row["dispatchable"] = "workflow_dispatch" in events
        dispatch = events.get("workflow_dispatch") or {}
        for name, field in dispatch.get("inputs", {}).items():
            if str(field.get("required", "false")).lower() == "true" and "default" not in field:
                row["dispatchable"] = False
                row["input_requirement"] = name
        selected.append(row)
    missing = REQUIRED - {r["file"] for r in selected}
    if missing:
        raise ValueError("Required validation omitted: " + ", ".join(sorted(missing)))
    return selected, excluded


class GitHub:
    def __init__(self, token: str):
        self.token = token

    def request(self, path: str, data: dict | None = None):
        headers = {"Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"}
        if self.token:
            headers["Authorization"] = "Bearer " + self.token
        payload = None if data is None else json.dumps(data).encode()
        if payload is not None:
            headers["Content-Type"] = "application/json"
        request = Request("https://api.github.com/repos/" + REPO + path, data=payload, headers=headers)
        # Do not retry an ambiguous POST and accidentally create duplicate jobs.
        with urlopen(request, timeout=45) as response:
            raw = response.read()
        return json.loads(raw) if raw else None

    def pages(self, path: str, key: str) -> list[dict]:
        result = []
        for page in range(1, 101):
            separator = "&" if "?" in path else "?"
            batch = self.request(f"{path}{separator}per_page=100&page={page}")[key]
            result.extend(batch)
            if len(batch) < 100:
                return result
        raise RuntimeError("Pagination limit reached; partial coverage is not success")


def assert_refs(api: GitHub, report: dict) -> None:
    for ref, expected in (("main", report["base_sha"]), (report["ref"], report["sha"])):
        actual = api.request("/git/ref/heads/" + quote(ref, safe="/"))["object"]["sha"]
        if actual != expected:
            raise RuntimeError(f"Ref moved: {ref}: expected {expected}, got {actual}")
    pr = api.request(f"/pulls/{report['pr']}")
    if pr["state"] != "open" or pr.get("merged") or pr["base"]["ref"] != "main":
        raise RuntimeError("Candidate PR is no longer open against main")
    if pr["head"]["sha"] != report["sha"] or pr["base"]["sha"] != report["base_sha"]:
        raise RuntimeError("PR head/base changed; refusing to mix revisions")


def matching_run(run: dict, workflow_id: int, report: dict) -> bool:
    if (run.get("workflow_id") != workflow_id or run.get("head_sha") != report["sha"]
            or run.get("head_branch") != report["ref"]):
        return False
    if run.get("event") == "workflow_dispatch":
        return True
    if run.get("event") != "pull_request":
        return False
    # A PR check on an older merge base is not proof for the current candidate.
    return any(p.get("number") == report["pr"] and p.get("base", {}).get("sha") == report["base_sha"]
               and p.get("head", {}).get("sha") == report["sha"] for p in run.get("pull_requests", []))


def choose_run(runs: list[dict], workflow_id: int, report: dict) -> dict | None:
    eligible = [r for r in runs if matching_run(r, workflow_id, report)]
    if not eligible:
        return None
    # Use the newest attempt/run, never cherry-pick an earlier green result.
    return max(eligible, key=lambda r: (r["id"], r.get("run_attempt", 1)))


def verdict(report: dict) -> str:
    rows = report.get("workflows", [])
    if report.get("errors") or not rows or any(r.get("blockers") for r in rows):
        return "BLOCKED"
    if any(not r.get("run") for r in rows):
        return "INCOMPLETE"
    runs = [r["run"] for r in rows]
    if any(r.get("head_sha") != report["sha"] or r.get("head_branch") != report["ref"] for r in runs):
        return "BLOCKED"
    if any(r.get("conclusion") in BAD for r in runs):
        return "FAIL"
    if any(r.get("status") != "completed" for r in runs):
        return "INCOMPLETE"
    return "PASS" if all(r.get("conclusion") == "success" for r in runs) else "FAIL"


def save(report: dict, output: Path) -> None:
    report["verdict"] = verdict(report)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def run_path(report: dict) -> str:
    return "/actions/runs?" + urlencode({"head_sha": report["sha"], "branch": report["ref"]})


def launch(api: GitHub, root: Path, report: dict, output: Path, sleep=time.sleep) -> None:
    try:
        sha = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
        if sha != report["sha"]:
            raise RuntimeError("Checkout differs from candidate SHA")
        subprocess.run(["git", "-C", str(root), "diff", "--exit-code", "--", ".github/workflows"], check=True)
        assert_refs(api, report)
        report["workflows"], report["excluded"] = inventory(root)
        registered = {w["path"].split("/")[-1]: w for w in api.pages("/actions/workflows", "workflows")}
        initial = api.pages(run_path(report), "workflow_runs")
        for row in report["workflows"]:
            workflow = registered.get(row["file"])
            if not workflow or workflow.get("state") != "active":
                row["blockers"].append("Workflow unregistered/disabled")
                continue
            row["workflow_id"] = workflow["id"]
            previous = choose_run(initial, workflow["id"], report)
            if previous:
                row["run"] = {k: previous.get(k) for k in RUN_KEYS}
                row["origin"] = "reused exact candidate/base"
                print("REUSED", row["file"], previous["id"], previous.get("conclusion") or previous["status"], flush=True)
                continue
            if not row["dispatchable"]:
                row["blockers"].append("No reusable run and no input-free manual trigger")
                continue
            assert_refs(api, report)
            row["previous_ids"] = [r["id"] for r in initial if r.get("workflow_id") == workflow["id"]]
            try:
                api.request(f"/actions/workflows/{workflow['id']}/dispatches", {"ref": report["ref"]})
                row["origin"] = "new dispatch"
                row["dispatch_accepted"] = True
                print("DISPATCHED", row["file"], report["sha"], flush=True)
            except Exception as exc:
                row["blockers"].append(f"Dispatch not confirmed: {type(exc).__name__}: {exc}")
            save(report, output)
        for attempt in range(6):
            pending = [r for r in report["workflows"] if r.get("dispatch_accepted") and not r.get("run")]
            if not pending:
                break
            recent = api.pages(run_path(report), "workflow_runs")
            for row in pending:
                created = [r for r in recent if r["id"] not in row["previous_ids"]
                           and r.get("event") == "workflow_dispatch"
                           and matching_run(r, row["workflow_id"], report)]
                if len(created) == 1:
                    row["run"] = {k: created[0].get(k) for k in RUN_KEYS}
                elif len(created) > 1:
                    row["blockers"].append("Ambiguous simultaneous dispatches; manual attribution required")
            save(report, output)
            if attempt < 5 and any(not r.get("run") for r in pending):
                sleep(5)
        assert_refs(api, report)
    except Exception as exc:
        report["errors"].append(f"{type(exc).__name__}: {exc}")
    finally:
        save(report, output)


def verify(api: GitHub, report: dict, output: Path) -> None:
    try:
        assert_refs(api, report)
        for row in report["workflows"]:
            if row.get("run"):
                run = api.request(f"/actions/runs/{row['run']['id']}")
                row["run"] = {k: run.get(k) for k in RUN_KEYS}
        assert_refs(api, report)
    except Exception as exc:
        report["errors"].append(f"{type(exc).__name__}: {exc}")
    save(report, output)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("launch", "verify"))
    parser.add_argument("--root", type=Path)
    parser.add_argument("--sha")
    parser.add_argument("--ref")
    parser.add_argument("--base-sha")
    parser.add_argument("--pr", type=int)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    api = GitHub(os.environ.get("GH_TOKEN", ""))
    if args.mode == "launch":
        if not all((args.root, args.sha, args.ref, args.base_sha, args.pr, api.token)):
            parser.error("launch requires root, immutable head/base, ref, PR number and GH_TOKEN")
        report = {"sha": args.sha, "ref": args.ref, "base_sha": args.base_sha, "pr": args.pr,
                  "started_at": datetime.now(timezone.utc).isoformat(), "workflows": [],
                  "excluded": [], "errors": [], "launcher_success_is_ci_success": False}
        launch(api, args.root, report, args.report)
    else:
        report = json.loads(args.report.read_text(encoding="utf-8"))
        verify(api, report, args.report)
    print("VALIDATION_VERDICT", report["verdict"], flush=True)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as stream:
            stream.write(f"## Exact candidate `{report['sha']}` on main `{report['base_sha']}`\n\n")
            stream.write(f"**Validation: {report['verdict']}. Launcher success is not CI success.**\n\n")
            for row in report["workflows"]:
                run = row.get("run", {})
                stream.write(f"- {row['file']}: {run.get('conclusion') or run.get('status') or 'NOT_CONFIRMED'} {run.get('html_url', '')}\n")
            for error in report["errors"]:
                stream.write(f"\nERROR: {error}\n")
    if args.mode == "verify":
        return 0 if report["verdict"] == "PASS" else 1
    registered = bool(report["workflows"]) and all(r.get("run") and not r["blockers"] for r in report["workflows"])
    return 0 if registered and report["verdict"] in {"PASS", "INCOMPLETE"} else 1


if __name__ == "__main__":
    raise SystemExit(main())
