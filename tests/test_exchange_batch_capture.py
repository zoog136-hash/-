"""Offline scheduling tests; no external requests or player data."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import importlib.util
from io import BytesIO
import json
from pathlib import Path
import sys
import tempfile
import threading
import unittest
from urllib.error import HTTPError
from urllib.request import Request

TOOLS = Path(__file__).parents[1] / "tools/exchange"
spec = importlib.util.spec_from_file_location("exchange_batches", TOOLS / "run_capture_batches.py")
batches = importlib.util.module_from_spec(spec)
sys.path.insert(0, str(TOOLS))
try:
    spec.loader.exec_module(batches)
finally:
    sys.path.pop(0)

URL = "https://api-goats.plaync.com/lms/v2.0/game/server"


class Clock:
    def __init__(self): self.now = 0.0
    def monotonic(self): return self.now
    def wait(self, seconds): self.now += seconds;return False


class Response(BytesIO):
    code = 200
    headers = {}


class Opener:
    def __init__(self, error=None): self.calls = 0;self.error = error
    def open(self, request, timeout=30):
        self.calls += 1
        if self.error: raise self.error
        return Response(b"[]")


def gate(path, interval=1):
    clock = Clock()
    value = batches.StartGate(path, interval, clock=clock.monotonic,
                              wait=clock.wait, utc_now=lambda: "2026-11-12T00:00:00+00:00")
    return value


class BatchCaptureTests(unittest.TestCase):
    def test_two_openers_share_one_minimum_start_interval(self):
        with tempfile.TemporaryDirectory() as d:
            shared = gate(Path(d) / "audit.jsonl")
            openers = [batches.GatedOpener(Opener(), shared, label) for label in ("armor", "weapons")]
            barrier = threading.Barrier(2)
            def work(opener):
                barrier.wait()
                for _ in range(3):
                    with opener.open(Request(URL)): pass
            with ThreadPoolExecutor(max_workers=2) as pool:
                list(pool.map(work, openers))
            events = [json.loads(line) for line in shared.audit_path.read_text().splitlines()]
            self.assertEqual(len(events), 6)
            self.assertEqual(set(event["batch"] for event in events), {"armor", "weapons"})
            self.assertTrue(all(b["monotonic"] - a["monotonic"] >= 1 for a, b in zip(events, events[1:])))

    def test_interval_below_one_and_nonfinite_is_rejected(self):
        for value in (0.9, 0, -1, float("nan"), float("inf"), True):
            with self.subTest(value=value), tempfile.TemporaryDirectory() as d:
                with self.assertRaises(ValueError): gate(Path(d) / "audit.jsonl", value)

    def test_http_403_is_preserved_and_stops_peer_before_new_request(self):
        with tempfile.TemporaryDirectory() as d:
            shared = gate(Path(d) / "audit.jsonl")
            error = HTTPError(URL, 403, "forbidden", {}, BytesIO(b'{"error":"forbidden"}'))
            blocked = batches.GatedOpener(Opener(error), shared, "armor")
            raw = Path(d) / "raw";raw.mkdir()
            with self.assertRaises(batches.collect.probe.ProbeError):
                batches.collect.probe.probe(URL, raw, blocked)
            receipt = json.loads(next(raw.glob("*.receipt.json")).read_text())
            self.assertEqual(receipt["http_status"], 403)
            self.assertEqual((raw / receipt["body_file"]).read_bytes(), b'{"error":"forbidden"}')
            peer = Opener()
            with self.assertRaises(batches.SharedAbort):
                batches.GatedOpener(peer, shared, "weapons").open(Request(URL))
            self.assertEqual(peer.calls, 0)
            self.assertEqual(sum(shared.starts.values()), 1)

    def test_http_429_and_redirect_both_abort_new_requests(self):
        for error in (HTTPError(URL, 429, "limited", {}, BytesIO(b"{}")),
                      batches.collect.probe.ProbeError("Redirect refused")):
            with self.subTest(error=type(error).__name__), tempfile.TemporaryDirectory() as d:
                shared = gate(Path(d) / "audit.jsonl")
                with self.assertRaises(type(error)):
                    batches.GatedOpener(Opener(error), shared, "armor").open(Request(URL))
                self.assertTrue(shared.abort_event.is_set())

    def test_peer_stop_during_audit_write_prevents_delegate_open(self):
        with tempfile.TemporaryDirectory() as d:
            shared = gate(Path(d) / "audit.jsonl")
            class Audit:
                @property
                def parent(self): return self
                def mkdir(self, **kwargs): pass
                def open(self, *args, **kwargs): return self
                def __enter__(self): return self
                def __exit__(self, *args): pass
                def write(self, line): shared.stop("peer HTTP 403 while audit flushes")
                def flush(self): pass
            shared.audit_path = Audit()
            delegate = Opener()
            with self.assertRaises(batches.SharedAbort):
                batches.GatedOpener(delegate, shared, "weapons").open(Request(URL))
            self.assertEqual(delegate.calls, 0)
            self.assertEqual(sum(shared.invocations.values()), 0)

    def test_transport_timeout_propagates_without_shared_abort(self):
        with tempfile.TemporaryDirectory() as d:
            shared = gate(Path(d) / "audit.jsonl")
            with self.assertRaises(TimeoutError):
                batches.GatedOpener(Opener(TimeoutError("read timeout")), shared, "armor").open(Request(URL))
            self.assertFalse(shared.abort_event.is_set())

    def test_safe_labels_and_explicit_positive_budgets(self):
        self.assertEqual(batches.batch_argument("server1-armor:11:100"), batches.Batch("server1-armor", 11, 100))
        for value in ("../escape:11:10", "foo/bar:11:10", "..:11:10", "name:11:0", "name:11:-1",
                      "name:11", "name:11:01", "name:11:2:extra"):
            with self.subTest(value=value), self.assertRaises(argparse.ArgumentTypeError):
                batches.batch_argument(value)

    def test_budget_partial_does_not_abort_next_batch(self):
        class FakeCollector:
            def __init__(self, output, budget, **kwargs):
                self.output, self.budget, self.kwargs = output, budget, kwargs
                self.opener = kwargs["opener"]
            def run(self):
                with self.opener.open(Request(URL)): pass
                return 2, {"status": "bounded_partial", "requests_this_run": 1}
        with tempfile.TemporaryDirectory() as d:
            shared = gate(Path(d) / "audit.jsonl")
            code, report = batches.run_batches(d, [batches.Batch("armor", 11, 2),
                batches.Batch("weapons", 1, 2), batches.Batch("accessories", 21, 2)],
                server_id=1, world_id=10001, workers=2, gate=shared,
                collector_factory=FakeCollector, opener_factory=Opener)
            self.assertEqual(code, 2)
            self.assertFalse(report["shared_abort"])
            self.assertEqual(report["actual_http_starts"], 3)
            self.assertEqual([r["result_code"] for r in report["batches"]], [2, 2, 2])
            self.assertFalse(report["coverage_complete"])
            self.assertFalse(report["production_import_performed"])

    def test_collector_identity_hard_stop_prevents_queued_batch(self):
        class HardCollector:
            def __init__(self, *args, **kwargs): pass
            def run(self): return 1, {"status": "stopped_incomplete", "reason": "wrong item identity"}
        with tempfile.TemporaryDirectory() as d:
            shared = gate(Path(d) / "audit.jsonl")
            code, report = batches.run_batches(d, [batches.Batch("armor", 11, 2), batches.Batch("weapons", 1, 2)],
                server_id=1, world_id=10001, workers=1, gate=shared,
                collector_factory=HardCollector, opener_factory=Opener)
            self.assertEqual(code, 1)
            self.assertTrue(report["shared_abort"])
            self.assertEqual(report["batches"][1]["status"], "aborted_before_start")
            self.assertEqual(report["actual_http_starts"], 0)

    def test_duplicate_batch_labels_are_rejected_before_opener_creation(self):
        with tempfile.TemporaryDirectory() as d:
            def forbidden(): self.fail("No network opener should be created")
            with self.assertRaises(ValueError):
                batches.run_batches(d, [batches.Batch("same", 11, 1), batches.Batch("same", 1, 1)],
                                    server_id=1, world_id=10001, opener_factory=forbidden)


if __name__ == "__main__": unittest.main()
