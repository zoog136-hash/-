#!/usr/bin/env python3
"""Overlap bounded read-only captures behind one audited HTTP start gate.

Each batch owns its existing immutable Collector cache. The gate measures the
start permit immediately before urllib's open call, not TCP packet timings.
No original definitions, credentials, player saves or production writes belong here.
"""
from __future__ import annotations

import argparse
from collections import Counter, namedtuple
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import re
import threading
import time
from urllib.error import HTTPError
from urllib.parse import urlsplit
from urllib.request import build_opener

try:
    from . import collect_snapshot as collect
except ImportError:
    import collect_snapshot as collect

Batch = namedtuple("Batch", "label category budget")
LABEL = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")


def batch_argument(value):
    parts = value.split(":")
    if len(parts) != 3 or not LABEL.fullmatch(parts[0]):
        raise argparse.ArgumentTypeError("batch must be SAFE_LABEL:POSITIVE_CATEGORY:POSITIVE_BUDGET")
    try:
        category, budget = int(parts[1]), int(parts[2])
    except ValueError as exc:
        raise argparse.ArgumentTypeError("batch category and request budget must be integers") from exc
    if category < 1 or budget < 1 or str(category) != parts[1] or str(budget) != parts[2]:
        raise argparse.ArgumentTypeError("batch category and explicit request budget must be positive canonical integers")
    return Batch(parts[0], category, budget)


class SharedAbort(collect.CaptureError):
    """No HTTP request was started because a peer encountered a hard stop."""


class StartGate:
    def __init__(self, audit_path, interval=1.0, *, clock=time.monotonic,
                 wait=None, utc_now=None, abort_event=None):
        if type(interval) not in (int, float) or not math.isfinite(interval) or not 1 <= interval <= 3600:
            raise ValueError("global HTTP start interval must be between 1 and 3600 seconds")
        self.audit_path = Path(audit_path)
        self.interval = float(interval)
        self.clock = clock
        self.abort_event = abort_event or threading.Event()
        self.wait = wait or self.abort_event.wait
        self.utc_now = utc_now or (lambda: datetime.now(timezone.utc).isoformat())
        self.lock = threading.Lock()
        self.last_start = None
        self.abort_reason = ""
        self.starts = Counter()
        self.invocations = Counter()
        self.opening_lock = threading.Lock()

    def stop(self, reason):
        with self.opening_lock:
            if not self.abort_event.is_set():
                self.abort_reason = str(reason)
            self.abort_event.set()

    def opening(self, label):
        # Establish an in-flight open boundary atomically against a peer stop.
        # It follows the audited permit and precedes the delegate's blocking I/O.
        with self.opening_lock:
            if self.abort_event.is_set():
                raise SharedAbort("Shared capture stop: " + self.abort_reason)
            self.invocations[label] += 1

    def start(self, url, label):
        parsed = urlsplit(url)
        if (parsed.scheme != "https" or parsed.netloc != "api-goats.plaync.com"
                or not parsed.path.startswith("/lms/v2.0/")):
            self.stop("Unapproved capture URL")
            raise SharedAbort(self.abort_reason)
        with self.lock:
            while True:
                if self.abort_event.is_set():
                    raise SharedAbort("Shared capture stop: " + self.abort_reason)
                now = self.clock()
                remaining = 0 if self.last_start is None else self.last_start + self.interval - now
                if remaining <= 0:
                    break
                self.wait(remaining)
            self.last_start = self.clock()
            self.starts[label] += 1
            event = {"utc": self.utc_now(), "monotonic": self.last_start,
                     "batch": label, "url": url,
                     "meaning": "HTTP open start permit; not transport packet timestamp"}
            self.audit_path.parent.mkdir(parents=True, exist_ok=True)
            with self.audit_path.open("a", encoding="utf-8") as audit:
                audit.write(json.dumps(event, ensure_ascii=False) + "\n")
                audit.flush()
            if self.abort_event.is_set():
                raise SharedAbort("Shared capture stop: " + self.abort_reason)
            return self.last_start


class GatedOpener:
    def __init__(self, opener, gate, label):
        self.opener, self.gate, self.label = opener, gate, label

    def open(self, request, timeout=30):
        self.gate.start(request.full_url, self.label)
        self.gate.opening(self.label)
        try:
            return self.opener.open(request, timeout=timeout)
        except HTTPError as exc:
            if exc.code in (403, 429):
                self.gate.stop(f"HTTP {exc.code} in {self.label}")
            # Preserve the original response body: probe_official owns writing it.
            raise
        except collect.probe.ProbeError:
            # NoRedirect raises this before following a redirect.
            self.gate.stop("Redirect refused in " + self.label)
            raise
        # TimeoutError intentionally propagates unchanged. Observe-live Collector
        # owns recording and soft-skipping it; the gate never retries a request.


def run_batches(output_parent, batches, *, server_id, world_id, workers=2, interval=1.0,
                max_stock_pages=2, blessed_type=1, collector_factory=collect.Collector,
                opener_factory=None, gate=None):
    batches = list(batches)
    if not batches or len({b.label for b in batches}) != len(batches):
        raise ValueError("Explicit uniquely labelled batches are required")
    if any(not LABEL.fullmatch(b.label) or type(b.category) is not int or b.category < 1
           or type(b.budget) is not int or b.budget < 1 for b in batches):
        raise ValueError("Invalid batch label, category or explicit request budget")
    if type(workers) is not int or not 1 <= workers <= 3:
        raise ValueError("workers must be 1..3")
    if (type(server_id) is not int or server_id < 1 or type(world_id) is not int or world_id < 1
            or type(max_stock_pages) is not int or max_stock_pages < 1
            or type(blessed_type) is not int or blessed_type not in (0, 1, 2, 3)):
        raise ValueError("Explicit server/world, page sample and blessing filters are invalid")
    if type(interval) not in (int, float) or not math.isfinite(interval) or not 1 <= interval <= 3600:
        raise ValueError("global HTTP start interval must be between 1 and 3600 seconds")
    parent = Path(output_parent)
    parent.mkdir(parents=True, exist_ok=True)
    if gate is None:
        gate = StartGate(parent / "http_start_times.jsonl", interval)
    elif gate.interval != float(interval):
        raise ValueError("Injected gate interval differs from requested interval")
    opener_factory = opener_factory or (lambda: build_opener(collect.probe.NoRedirect()))
    import fcntl
    results = {}

    def work(batch):
        if gate.abort_event.is_set():
            return {"label": batch.label, "result_code": 1, "status": "aborted_before_start",
                    "reason": gate.abort_reason, "actual_http_starts": 0}
        try:
            collector = collector_factory(
                parent / batch.label, batch.budget, delay=1.0,
                opener=GatedOpener(opener_factory(), gate, batch.label),
                server_ids=[server_id], world_ids=[world_id], observe_live=True,
                category1_ids=[batch.category], blessed_type=blessed_type,
                max_stock_pages=max_stock_pages,
            )
            code, report = collector.run()
            if code not in (0, 2):
                gate.stop(f"Collector hard stop in {batch.label}: {report.get('reason', 'code '+str(code))}")
            summary = {key: report[key] for key in (
                "status", "reason", "requests_this_run", "reused_receipts_this_run",
                "observed_stock_rows", "observed_stock_pages", "stock_groups",
                "observation_window", "transport_timeout_events") if key in report}
            return {"label": batch.label, "category1": batch.category,
                    "new_request_budget": batch.budget, "result_code": code,
                    "output": str(parent / batch.label), **summary,
                    "actual_http_starts": gate.invocations[batch.label]}
        except Exception as exc:
            gate.stop(f"Capture failure in {batch.label}: {type(exc).__name__}: {exc}")
            return {"label": batch.label, "result_code": 1, "status": "stopped_incomplete",
                    "reason": str(exc), "actual_http_starts": gate.invocations[batch.label]}

    with (parent / ".batch-run.lock").open("a") as lock:
        try:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise ValueError("Another batch orchestrator owns this output parent") from exc
        with ThreadPoolExecutor(max_workers=workers, thread_name_prefix="exchange-capture") as pool:
            futures = {pool.submit(work, batch): batch for batch in batches}
            try:
                for future in as_completed(futures):
                    result = future.result();results[result["label"]] = result
            except KeyboardInterrupt:
                gate.stop("Interrupted by caller")
                raise
        ordered = [results[b.label] for b in batches]
        code = 1 if gate.abort_event.is_set() else (2 if any(r["result_code"] == 2 for r in ordered) else 0)
        summary = {
            "schema": "twilight.exchange-capture-batches.v1",
            "status": "stopped_incomplete" if code == 1 else "bounded_partial" if code == 2 else "observed_batches_finished_unverified",
            "worker_count": workers, "global_minimum_http_start_interval_seconds": gate.interval,
            "audit": str(gate.audit_path), "actual_http_starts": sum(gate.invocations.values()),
            "http_start_permits": sum(gate.starts.values()),
            "unstarted_permits": sum(gate.starts.values()) - sum(gate.invocations.values()),
            "planned_new_request_budget": sum(batch.budget for batch in batches),
            "shared_abort": gate.abort_event.is_set(), "abort_reason": gate.abort_reason,
            "coverage_complete": False, "atomic_snapshot_verified": False,
            "production_import_performed": False, "batches": ordered,
        }
        temporary = parent / f".batch-summary-{os.getpid()}.tmp"
        try:
            with temporary.open("x", encoding="utf-8") as stream:
                json.dump(summary, stream, ensure_ascii=False, indent=2);stream.write("\n")
            temporary.replace(parent / "batch_summary.json")
        finally:
            temporary.unlink(missing_ok=True)
    return code, summary


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-parent", type=Path, required=True)
    parser.add_argument("--server-id", type=int, required=True)
    parser.add_argument("--world-id", type=int, required=True)
    parser.add_argument("--batch", type=batch_argument, action="append", required=True)
    parser.add_argument("--workers", type=int, default=2)
    parser.add_argument("--interval", type=float, default=1.0)
    parser.add_argument("--max-stock-pages", type=int, default=2)
    parser.add_argument("--blessed-type", type=int, choices=(0, 1, 2, 3), default=1)
    args = parser.parse_args(argv)
    try:
        code, summary = run_batches(args.output_parent, args.batch, server_id=args.server_id,
                                    world_id=args.world_id, workers=args.workers, interval=args.interval,
                                    max_stock_pages=args.max_stock_pages, blessed_type=args.blessed_type)
        print(json.dumps(summary, ensure_ascii=False, indent=2))
        return code
    except (OSError, ValueError) as exc:
        print("STOPPED:", exc)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
