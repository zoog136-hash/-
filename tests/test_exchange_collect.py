"""Offline tests for bounded resumable observation capture, never production data."""
import hashlib
import importlib.util
from io import BytesIO
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch
from urllib.error import HTTPError
from urllib.parse import parse_qs, urlsplit

TOOLS = Path(__file__).parents[1] / "tools/exchange"
spec = importlib.util.spec_from_file_location("exchange_collect", TOOLS / "collect_snapshot.py")
collect = importlib.util.module_from_spec(spec)
sys.path.insert(0, str(TOOLS))
try:
    spec.loader.exec_module(collect)
finally:
    sys.path.pop(0)


SERVERS = [{"worldId": 10001, "servers": [{"serverId": 1}]}]
WORLDS = [{"serverId": 10001}]
CATEGORIES = [{"id": "1", "child": [{"id": "10"}, {"id": "11"}]},
              {"id": "2", "child": [{"id": "20"}]}]


def row(item=366, server=1, world=False, price=None):
    r = {"itemId": item, "itemName": "synthetic offline fixture", "serverId": server,
         "world": world, "enchantLevel": 0, "quantity": 10000}
    if price is not None:
        r["salePrice"] = price
    return r


def page(rows, number=1, size=30, total=None, limit=10000):
    total = len(rows) if total is None else total
    return {"contents": rows, "pagination": {
        "page": number, "size": size, "total": total, "limit": limit,
        "lastPage": (min(total, limit) + size - 1) // size}}


class Response(BytesIO):
    code = 200
    headers = {"Date": "Thu, 12 Nov 2026 12:00:00 GMT"}


class Official:
    def __init__(self, handler=None):
        self.urls = []
        self.handler = handler

    def open(self, request, timeout=30):
        self.urls.append(request.full_url)
        path = urlsplit(request.full_url).path
        query = parse_qs(urlsplit(request.full_url).query)
        if path.endswith("/game/server"):
            data = SERVERS
        elif path.endswith("/game/market/world"):
            data = WORLDS
        elif path.endswith("/game/market/category"):
            data = CATEGORIES
        elif self.handler:
            data = self.handler(path, query)
        elif path.endswith("/stock"):
            server = int(query["serverId"][0])
            data = page([row(server=server, world=server == 10001, price=50)] * 2,
                        size=10)
        else:
            server = int(query["serverId"][0])
            data = page([row(server=server, world=server == 10001)])
        return Response(json.dumps(data).encode())


class CollectTests(unittest.TestCase):
    def run_capture(self, directory, opener, budget=30, **kw):
        collector = collect.Collector(directory, budget, opener=opener,
                                      sleep=lambda _: None, **kw)
        return collector.run()

    def test_default_dry_run_makes_no_request_or_production_snapshot(self):
        with tempfile.TemporaryDirectory() as d, patch.object(collect, "build_opener") as factory:
            code, report = collect.Collector(d).run()
            self.assertEqual(code, 2)
            factory.assert_not_called()
            self.assertFalse(report["coverage"]["complete"])
            self.assertFalse(report["traversal_complete"])
            self.assertFalse(report["production_import_performed"])
            self.assertEqual(list((Path(d) / "raw").iterdir()), [])

    def test_scope_filtering_and_equal_stock_rows_are_preserved(self):
        def handler(path, q):
            if path.endswith("/stock"):
                return page([row(price=50), row(price=50)], size=10)
            return page([row(), row(server=10001, world=True)])
        with tempfile.TemporaryDirectory() as d:
            api = Official(handler)
            code, report = self.run_capture(d, api, server_ids=[1])
            self.assertEqual(code, 0, report)
            self.assertEqual(report["catalog_groups"], 1)
            self.assertEqual(report["observed_bundle_rows"], 2)
            self.assertEqual(report["stock_groups"], 1)
            self.assertTrue(report["traversal_complete"])
            self.assertFalse(report["coverage"]["complete"])
            self.assertFalse(report["scope_selection_is_all"])
            stocks = [u for u in api.urls if "/stock?" in u]
            self.assertEqual(len(stocks), 1)
            self.assertIn("blessedType=0", stocks[0])
            receipt = report["stock_receipts"][0]["pages"][0]
            raw = json.loads((Path(d) / "raw" / receipt["body_file"]).read_text())
            self.assertEqual(len(raw["contents"]), 2)

    def test_budget_resume_does_not_refetch_successful_pages(self):
        with tempfile.TemporaryDirectory() as d:
            api = Official()
            code, first = self.run_capture(d, api, budget=4, server_ids=[1])
            self.assertEqual(code, 2)
            self.assertIn("/stock?", first["next_url"])
            checkpoint = json.loads((Path(d) / "cursor.json").read_text())
            self.assertEqual(checkpoint["current_scope"], "server:1")
            self.assertFalse(checkpoint["coverage_complete"])
            first_urls = list(api.urls)
            code, second = self.run_capture(d, api, budget=1, server_ids=[1])
            self.assertEqual(code, 0, second)
            self.assertEqual(api.urls[:4], first_urls)
            self.assertEqual(len(api.urls), 5)
            self.assertEqual(second["requests_this_run"], 1)
            self.assertEqual(second["reused_receipts_this_run"], 4)

    def test_each_new_request_observes_minimum_delay_including_resume(self):
        with tempfile.TemporaryDirectory() as d:
            sleeps = []
            api = Official()
            c = collect.Collector(d, 2, opener=api, sleep=sleeps.append)
            c.run()
            self.assertEqual(sleeps, [1.0, 1.0])

    def test_pagination_drift_is_saved_and_never_called_complete(self):
        def handler(path, q):
            if q["page"] == ["1"]:
                return page([row(i + 1) for i in range(30)], total=31)
            return page([row(31), row(32)], number=2, total=32)
        with tempfile.TemporaryDirectory() as d:
            api = Official(handler)
            code, report = self.run_capture(d, api, server_ids=[1])
            self.assertEqual(code, 1)
            self.assertIn("changed", report["reason"])
            self.assertFalse(report["traversal_complete"])
            count = len(api.urls)
            code, _ = self.run_capture(d, api, server_ids=[1])
            self.assertEqual(code, 1)
            self.assertEqual(len(api.urls), count)

    def test_repeated_catalog_key_stops_before_stock_requests(self):
        def handler(path, q):
            if q["page"] == ["1"]:
                return page([row(i + 1) for i in range(30)], total=31)
            return page([row(1)], number=2, total=31)
        with tempfile.TemporaryDirectory() as d:
            api = Official(handler)
            code, report = self.run_capture(d, api, server_ids=[1])
            self.assertEqual(code, 1)
            self.assertIn("Repeated catalog", report["reason"])
            self.assertFalse(any("/stock?" in u for u in api.urls))

    def test_category_split_totals_must_equal_capped_parent(self):
        def handler(path, q):
            if "category1" not in q:
                return page([row(1), row(2)], size=2, total=3, limit=2)
            return page([row(10)] if q["category1"] == ["1"] else [])
        with tempfile.TemporaryDirectory() as d:
            api = Official(handler)
            code, report = self.run_capture(d, api, server_ids=[1])
            self.assertEqual(code, 1)
            self.assertIn("partition", report["reason"])
            self.assertFalse(any("/stock?" in u for u in api.urls))

    def test_two_level_category_partition_recovers_all_rows(self):
        def handler(path, q):
            if path.endswith("/stock"):
                item = int(path.split("/")[-2])
                return page([row(item, price=50)], size=10)
            if "category1" not in q:
                return page([row(1), row(2)], size=2, total=4, limit=2)
            if q["category1"] == ["2"]:
                return page([row(4)])
            if "category2" not in q:
                return page([row(1), row(2)], size=2, total=3, limit=2)
            return page([row(1), row(2)] if q["category2"] == ["10"] else [row(3)])
        with tempfile.TemporaryDirectory() as d:
            code, report = self.run_capture(d, Official(handler), server_ids=[1])
            self.assertEqual(code, 0, report)
            self.assertEqual(report["stock_groups"], 4)
            self.assertFalse(report["coverage"]["complete"])

    def test_stock_cap_or_invalid_price_cannot_be_accepted(self):
        for capped in (True, False):
            def handler(path, q):
                if path.endswith("/stock"):
                    return (page([row(price=50)] * 10, size=10, total=11, limit=10)
                            if capped else page([row(price=0.5)], size=10))
                return page([row()])
            with self.subTest(capped=capped), tempfile.TemporaryDirectory() as d:
                code, report = self.run_capture(d, Official(handler), server_ids=[1])
                self.assertEqual(code, 1)
                self.assertFalse(report["traversal_complete"])

    def test_tampered_cache_stops_without_network_or_overwrite(self):
        with tempfile.TemporaryDirectory() as d:
            api = Official()
            self.run_capture(d, api, budget=1)
            receipt = json.loads(next((Path(d) / "raw").glob("*.receipt.json")).read_text())
            body = Path(d) / "raw" / receipt["body_file"]
            body.write_text("[]")
            before = len(api.urls)
            code, report = self.run_capture(d, api)
            self.assertEqual(code, 1)
            self.assertIn("validation", report["reason"])
            self.assertEqual(len(api.urls), before)
            self.assertEqual(body.read_text(), "[]")

    def test_429_is_recorded_once_and_resume_does_not_retry(self):
        with tempfile.TemporaryDirectory() as d:
            api = Mock()
            api.open.side_effect = HTTPError(collect.probe.BASE, 429, "limit", {},
                                            BytesIO(b'{"error":"limit"}'))
            for _ in range(2):
                code, report = self.run_capture(d, api)
                self.assertEqual(code, 1)
                self.assertFalse(report["coverage"]["complete"])
            self.assertEqual(api.open.call_count, 1)

    def test_unknown_or_disagreeing_scope_inventory_fails(self):
        with tempfile.TemporaryDirectory() as d:
            code, report = self.run_capture(d, Official(), server_ids=[999])
            self.assertEqual(code, 1)
            self.assertIn("absent", report["reason"])
        with self.assertRaises(collect.CaptureError):
            collect.scopes(SERVERS, [{"serverId": 10002}])
        with self.assertRaises(collect.CaptureError):
            collect.scopes(SERVERS + SERVERS, WORLDS)


if __name__ == "__main__":
    unittest.main()
