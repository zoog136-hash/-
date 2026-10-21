#!/usr/bin/env python3
"""Launch all main-targeting CI without path filters; never equate dispatch with PASS."""
from __future__ import annotations

import argparse
import datetime as dt
import fnmatch
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request

import yaml

# These are existing, read-only diagnostics, not data-generation/apply workflows.
EXTRA_CI = {
    "main-debug-audit.yml", "main-debug-followup.yml",
    "ui-renewal-validate.yml", "twilight-android-playtest-apk.yml",
}
REQUIRED_CI = {"godot-validate.yml", "monster-world-validate.yml", "resource-integrity.yml"} | EXTRA_CI


def permits_main(config: object) -> bool:
    if not isinstance(config, dict):
        return True
    patterns = config.get("branches")
    allowed = patterns is None
    for pattern in patterns or []:
        negative = str(pattern).startswith("!")
        if fnmatch.fnmatchcase("main", str(pattern).lstrip("!")):
            allowed = not negative
    return allowed and not any(fnmatch.fnmatchcase("main", str(p)) for p in config.get("branches-ignore", []))


def inventory(root: Path) -> tuple[list[dict], list[dict]]:
    selected, excluded, seen = [], [], set()
    for path in sorted((root / ".github/workflows").glob("*")):
        if path.suffix not in {".yml", ".yaml"}:
            continue
        # BaseLoader preserves the YAML 1.2 event key `on`, rather than bool True.
        doc = yaml.load(path.read_text(encoding="utf-8"), Loader=yaml.BaseLoader)
        if not isinstance(doc, dict) or not isinstance(doc.get("jobs"), dict):
            raise ValueError(f"Invalid workflow definition: {path.name}")
        events = doc.get("on", {})
        if isinstance(events, str):
            events = {events: {}}
        elif isinstance(events, list):
            events = {name: {} for name in events}
        if not isinstance(events, dict):
            raise ValueError(f"Invalid workflow events: {path.name}")
        active = any(name in events and permits_main(events[name]) for name in ("push", "pull_request"))
        row = {"file": path.name, "name": doc.get("name", path.stem)}
        if not active and path.name not in EXTRA_CI:
            row["reason"] = "Not main/PR CI; historical/manual apply or generation workflow"
            excluded.append(row)
            continue
        seen.add(path.name)
        row["blockers"] = []
        if "workflow_dispatch" not in events:
            row["blockers"].append("No workflow_dispatch trigger on audited main")
        dispatch = events.get("workflow_dispatch") or {}
        for name, field in dispatch.get("inputs", {}).items():
            if str(field.get("required", "false")).lower() == "true" and "default" not in field:
                row["blockers"].append(f"Required manual input has no default: {name}")
        selected.append(row)
    missing = REQUIRED_CI - seen
    if missing:
        raise ValueError("Required CI missing from inventory: " + ", ".join(sorted(missing)))
    if not selected:
        raise ValueError("Empty CI inventory is not success")
    return selected, excluded


class GitHub:
    def __init__(self, repo: str, token: str):
        self.base = "https://api.github.com/repos/" + repo
        self.token = token

    def request(self, path: str, data: dict | None = None):
        headers = {"Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"}
        if self.token:
            headers["Authorization"] = "Bearer " + self.token
        if data is not None:
            headers["Content-Type"] = "application/json"
        request = urllib.request.Request(self.base + path, data=None if data is None else json.dumps(data).encode(), headers=headers)
        # Never retry POST: an ambiguous response could cause duplicate CI runs.
        with urllib.request.urlopen(request, timeout=45) as response:
            raw = response.read()
        return json.loads(raw) if raw else None

    def pages(self, path: str, key: str) -> list[dict]:
        result = []
        for page in range(1, 101):
            sep = "&" if "?" in path else "?"
            response = self.request(f"{path}{sep}per_page=100&page={page}")
            items = response[key]
            result.extend(items)
            if len(items) < 100:
                return result
        raise RuntimeError("Pagination limit reached; refusing a partial CI result")

    def assert_main(self, sha: str) -> None:
        actual = self.request("/git/ref/heads/main")["object"]["sha"]
        if actual != sha:
            raise RuntimeError(f"main moved: expected {sha}, got {actual}; do not mix revisions")


def verdict(report: dict) -> str:
    rows = report.get("workflows", [])
    if report.get("errors") or not rows or any(r.get("blockers") for r in rows):
        return "BLOCKED"
    for row in rows:
        run = row.get("run")
        if not run or run.get("head_sha") != report["sha"] or run.get("head_branch") != "main":
            return "INCOMPLETE"
    if any(r["run"].get("conclusion") in {"failure", "cancelled", "timed_out", "action_required", "stale", "startup_failure"} for r in rows):
        return "FAIL"
    if any(r["run"].get("status") != "completed" for r in rows):
        return "INCOMPLETE"
    return "PASS" if all(r["run"].get("conclusion") == "success" for r in rows) else "FAIL"


def save(report: dict, output: Path) -> None:
    report["verdict"] = verdict(report)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def run_audit(api: GitHub, root: Path, sha: str, output: Path) -> dict:
    report = {"sha": sha, "ref": "main", "started_at": dt.datetime.now(dt.timezone.utc).isoformat(),
              "workflows": [], "excluded": [], "errors": [], "dispatch_is_validation": False}
    try:
        actual = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
        if actual != sha:
            raise ValueError(f"Checkout differs from requested main: {actual}")
        api.assert_main(sha)
        report["workflows"], report["excluded"] = inventory(root)
        registered = {w["path"].split("/")[-1]: w for w in api.pages("/actions/workflows", "workflows")}
        for row in report["workflows"]:
            workflow = registered.get(row["file"])
            if not workflow or workflow.get("state") != "active":
                row["blockers"].append("Workflow unregistered or disabled")
            else:
                row["workflow_id"] = workflow["id"]
        save(report, output)
        for row in report["workflows"]:
            if row["blockers"]:
                print("BLOCKED", row["file"], "; ".join(row["blockers"]), flush=True)
                continue
            api.assert_main(sha)
            path = f"/actions/workflows/{row['workflow_id']}/runs?event=workflow_dispatch&head_sha={sha}&branch=main"
            row["previous_ids"] = [r["id"] for r in api.pages(path, "workflow_runs")]
            try:
                api.request(f"/actions/workflows/{row['workflow_id']}/dispatches", {"ref": "main"})
                row["dispatch_accepted"] = True
                print("DISPATCHED", row["file"], sha, flush=True)
            except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as exc:
                row["blockers"].append(f"Dispatch not confirmed: {type(exc).__name__}: {exc}")
            save(report, output)
        # Registration only. Do not occupy a runner waiting hours for child jobs.
        for attempt in range(6):
            pending = [r for r in report["workflows"] if r.get("dispatch_accepted") and not r.get("run")]
            if not pending:
                break
            for row in pending:
                path = f"/actions/workflows/{row['workflow_id']}/runs?event=workflow_dispatch&head_sha={sha}&branch=main"
                candidates = [r for r in api.pages(path, "workflow_runs") if r["id"] not in row["previous_ids"]]
                if len(candidates) == 1:
                    row["run"] = {k: candidates[0].get(k) for k in ("id", "html_url", "head_sha", "head_branch", "status", "conclusion")}
                elif len(candidates) > 1:
                    row["blockers"].append("Ambiguous simultaneous runs; manual attribution required")
                save(report, output)
            if attempt < 5 and any(not r.get("run") for r in pending):
                time.sleep(5)
        api.assert_main(sha)
    except Exception as exc:
        report["errors"].append(f"{type(exc).__name__}: {exc}")
    save(report, output)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["dispatch", "verify"])
    parser.add_argument("--repo", default="zoog136-hash/-")
    parser.add_argument("--root", type=Path)
    parser.add_argument("--sha")
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    if args.repo != "zoog136-hash/-":
        parser.error("This audit is scoped to zoog136-hash/-")
    api = GitHub(args.repo, os.environ.get("GH_TOKEN", ""))
    if args.mode == "dispatch":
        if not args.root or not args.sha or not os.environ.get("GH_TOKEN"):
            parser.error("dispatch needs --root, --sha, and GH_TOKEN")
        report = run_audit(api, args.root, args.sha, args.report)
    else:
        report = json.loads(args.report.read_text())
        try:
            api.assert_main(report["sha"])
            for row in report["workflows"]:
                if row.get("run"):
                    data = api.request(f"/actions/runs/{row['run']['id']}")
                    row["run"] = {k: data.get(k) for k in ("id", "html_url", "head_sha", "head_branch", "status", "conclusion")}
        except Exception as exc:
            report.setdefault("errors", []).append(f"{type(exc).__name__}: {exc}")
        save(report, args.report)
    print("AUDIT_VERDICT", report["verdict"], flush=True)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as stream:
            stream.write(f"## Main audit: `{report['sha']}`\n\n**{report['verdict']} — dispatch is NOT CI success.**\n\n")
            for row in report["workflows"]:
                run = row.get("run", {})
                stream.write(f"- {row['file']}: {run.get('conclusion') or run.get('status') or 'NOT_CONFIRMED'} {run.get('html_url', '')}\n")
            for error in report.get("errors", []):
                stream.write(f"\nERROR: {error}\n")
    # Launcher success means launch only; verify is the strict, fail-closed gate.
    if args.mode == "verify":
        return 0 if report["verdict"] == "PASS" else 1
    return 0 if not report["errors"] and all(r.get("run") and not r["blockers"] for r in report["workflows"]) and report["workflows"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
