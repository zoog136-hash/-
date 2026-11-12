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
from urllib.error import HTTPError, URLError
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


    def test_observe_live_catalog_drift_queues_duplicate_identity_once(self):
        def handler(path, q):
            if path.endswith("/stock"):
                item = int(path.split("/")[-2])
                return page([row(item, price=50)], size=10)
            if q["page"] == ["1"]:
                return page([row(i + 1) for i in range(30)], total=31)
            return page([row(1), row(31)], number=2, total=32)
        with tempfile.TemporaryDirectory() as d:
            api = Official(handler)
            code, report = self.run_capture(d, api, budget=50, server_ids=[1], observe_live=True)
            self.assertEqual(code, 0, report)
            self.assertEqual(report["catalog_duplicate_observations"], 1)
            self.assertEqual(report["stock_groups"], 31)
            self.assertEqual(report["observed_stock_rows"], 31)
            self.assertTrue(report["drift_events"])
            self.assertTrue(report["possible_overlap_events"])
            self.assertEqual(report["observation_mode"], "live_non_atomic")
            self.assertEqual(report["status"], "observed_traversal_unverified")
            self.assertFalse(report["coverage"]["complete"])
            self.assertFalse(report["atomic_snapshot_verified"])
            self.assertFalse(report["production_import_performed"])
            self.assertEqual(len([u for u in api.urls if "/item/1/stock?" in u]), 1)

    def test_observe_stock_drift_retains_every_equal_row_as_observations(self):
        def handler(path, q):
            if not path.endswith("/stock"):
                return page([row()])
            if q["page"] == ["1"]:
                return page([row(price=50)] * 10, size=10, total=11)
            return page([row(price=50)] * 2, number=2, size=10, total=12)
        with tempfile.TemporaryDirectory() as d:
            code, report = self.run_capture(d, Official(handler), server_ids=[1], observe_live=True)
            self.assertEqual(code, 0, report)
            self.assertEqual(report["observed_bundle_rows"], 12)
            self.assertEqual(report["observed_stock_rows"], 12)
            self.assertEqual(report["observed_stock_pages"], 2)
            group = report["stock_receipts"][0]
            self.assertEqual(group["first_reported_total"], 11)
            self.assertTrue(group["pagination_drift_observed"])
            self.assertFalse(group["distinct_listings_verified"])
            self.assertFalse(report["observed_stock_rows_distinct_listings_verified"])
            observed = []
            for r in group["pages"]:
                observed.extend(json.loads((Path(d) / "raw" / r["body_file"]).read_text())["contents"])
            self.assertEqual(len(observed), 12)
            self.assertTrue(all(r == observed[0] for r in observed))

    def test_observe_adaptive_page_highwater_handles_growth_and_shrink(self):
        for grow in (True, False):
            def handler(path, q):
                if path.endswith("/stock"):
                    return page([row(int(path.split("/")[-2]), price=50)], size=10)
                number = int(q["page"][0])
                if grow:
                    total = 2 if number == 1 else 3
                    return page([row(number)], number=number, size=1, total=total)
                total = 3 if number == 1 else 1
                return page([row(1)] if number == 1 else [], number=number, size=1, total=total)
            with self.subTest(grow=grow), tempfile.TemporaryDirectory() as d:
                api = Official(handler)
                code, report = self.run_capture(d, api, server_ids=[1], observe_live=True)
                self.assertEqual(code, 0, report)
                catalogs = [u for u in api.urls if "/price/search/item?" in u]
                self.assertEqual(len(catalogs), 3)
                self.assertEqual(report["stock_groups"], 3 if grow else 1)
                self.assertTrue(report["drift_events"])

    def test_observe_invalid_catalog_or_stock_identity_stops_immediately(self):
        for invalid_stock in (True, False):
            def handler(path, q):
                if path.endswith("/stock"):
                    return page([row(item=999, price=50)] * 10, size=10, total=11)
                return page([row()] if invalid_stock else [row(server=2)])
            with self.subTest(stock=invalid_stock), tempfile.TemporaryDirectory() as d:
                api = Official(handler)
                code, report = self.run_capture(d, api, server_ids=[1], observe_live=True)
                self.assertEqual(code, 1)
                self.assertIn("scope", report["reason"])
                self.assertEqual(len(api.urls), 5 if invalid_stock else 4)
                self.assertEqual(report["observed_stock_rows"], 0)

    def test_observe_hard_http_failure_is_not_retried(self):
        for status in (403, 429):
            with self.subTest(status=status), tempfile.TemporaryDirectory() as d:
                api = Mock()
                api.open.side_effect = HTTPError(collect.probe.BASE, status, "stop", {},
                                                BytesIO(b'{"error":"stop"}'))
                for _ in range(2):
                    code, report = self.run_capture(d, api, observe_live=True)
                    self.assertEqual(code, 1)
                    self.assertFalse(report["coverage"]["complete"])
                self.assertEqual(api.open.call_count, 1)

    def test_observe_stock_cap_keeps_accessible_rows_with_explicit_cap(self):
        def handler(path, q):
            if path.endswith("/stock"):
                return page([row(price=50)] * 10, size=10, total=11, limit=10)
            return page([row()])
        with tempfile.TemporaryDirectory() as d:
            code, report = self.run_capture(d, Official(handler), server_ids=[1], observe_live=True)
            self.assertEqual(code, 0, report)
            self.assertEqual(report["observed_stock_rows"], 10)
            self.assertEqual(report["stock_receipts"][0]["first_reported_total"], 11)
            self.assertEqual(report["cap_events"][0]["reported_total"], 11)
            self.assertFalse(report["coverage"]["complete"])

    def test_observe_partition_mismatch_and_overlap_continue_without_double_queue(self):
        def handler(path, q):
            if path.endswith("/stock"):
                return page([row(10, price=50)], size=10)
            if "category1" not in q:
                return page([row(1), row(2)], size=2, total=3, limit=2)
            return page([row(10)])
        with tempfile.TemporaryDirectory() as d:
            code, report = self.run_capture(d, Official(handler), server_ids=[1], observe_live=True)
            self.assertEqual(code, 0, report)
            self.assertEqual(report["stock_groups"], 1)
            self.assertEqual(report["catalog_duplicate_observations"], 1)
            self.assertTrue(any(e["kind"] == "category_partition_total_changed"
                                for e in report["drift_events"]))
            self.assertFalse(report["coverage"]["complete"])

    def test_observe_budget_preserves_partial_stock_count_and_resume(self):
        def handler(path, q):
            if not path.endswith("/stock"):
                return page([row()])
            n = int(q["page"][0])
            return page([row(price=50)] * (10 if n < 3 else 1), number=n, size=10, total=21)
        with tempfile.TemporaryDirectory() as d:
            api = Official(handler)
            code, report = self.run_capture(d, api, budget=5, server_ids=[1], observe_live=True)
            self.assertEqual(code, 2)
            self.assertEqual(report["observed_stock_rows"], 10)
            self.assertEqual(report["stock_groups"], 0)
            self.assertEqual(report["current_stock_observation"]["observed_rows"], 10)
            first_urls = list(api.urls)
            code, report = self.run_capture(d, api, budget=2, server_ids=[1], observe_live=True)
            self.assertEqual(code, 0, report)
            self.assertEqual(report["observed_stock_rows"], 21)
            self.assertEqual(report["observed_bundle_rows"], 21)
            self.assertEqual(api.urls[:5], first_urls)
            self.assertEqual(len(api.urls), 7)

    def test_category_selection_uses_only_official_selected_categories_and_labels_partial(self):
        def handler(path, q):
            if path.endswith("/stock"):
                return page([row(price=50)], size=10)
            self.assertEqual(q["category1"], ["2"])
            return page([row()])
        with tempfile.TemporaryDirectory() as d:
            code, report = self.run_capture(d, Official(handler), server_ids=[1],
                                             category1_ids=[2], observe_live=True)
            self.assertEqual(code, 0, report)
            self.assertFalse(report["scope_selection_is_all"])
            self.assertFalse(report["category_selection_is_all"])
            self.assertEqual(report["selection_label"], "representative_or_category_partial")
            self.assertEqual(report["selection"]["selected_market_scope_count"], 1)
            self.assertEqual(report["selection"]["available_market_scope_count"], 2)
            self.assertEqual(report["selection"]["selected_category1_ids"], [2])
        with tempfile.TemporaryDirectory() as d:
            api = Official()
            code, report = self.run_capture(d, api, server_ids=[1], category1_ids=[999])
            self.assertEqual(code, 1)
            self.assertIn("category1", report["reason"])
            self.assertEqual(len(api.urls), 3)

    def test_observe_cli_is_explicit_and_default_stays_offline(self):
        with tempfile.TemporaryDirectory() as d, patch.object(collect, "build_opener") as factory:
            self.assertEqual(collect.main(["--output", d, "--observe-live", "--category1", "1"]), 2)
            factory.assert_not_called()
            report = json.loads((Path(d) / "progress.json").read_text())
            self.assertEqual(report["observation_mode"], "live_non_atomic")
            self.assertFalse(report["coverage"]["complete"])


    def test_explicit_normal_filter_and_category_provenance_are_preserved(self):
        def handler(path, q):
            if path.endswith("/stock"):
                self.assertEqual(q["blessedType"], ["1"])
                return page([row(price=50)], size=10)
            self.assertIn(q["category1"][0], ("1", "2"))
            return page([row()])
        with tempfile.TemporaryDirectory() as d:
            api = Official(handler)
            code, report = self.run_capture(d, api, server_ids=[1], observe_live=True,
                                             category1_ids=[1, 2], blessed_type=1)
            self.assertEqual(code, 0, report)
            self.assertEqual(report["catalog_duplicate_observations"], 1)
            self.assertEqual(report["stock_groups"], 1)
            group = report["stock_receipts"][0]
            self.assertEqual(group["blessed_type_filter"], 1)
            self.assertEqual(group["category1_ids"], [1, 2])
            self.assertEqual(report["blessed_type_filter"], 1)
            self.assertEqual(report["selection"]["blessed_type_filter"], 1)
            self.assertIn("first_request_started_at_utc", report["observation_window"])
            self.assertIn("last_request_completed_at_utc", report["observation_window"])

    def test_normal_filter_does_not_reuse_unfiltered_stock_response(self):
        def handler(path, q):
            if path.endswith("/stock"):
                return page([row(price=50)] * (2 if q["blessedType"] == ["0"] else 1), size=10)
            return page([row()])
        with tempfile.TemporaryDirectory() as d:
            api = Official(handler)
            _, wildcard = self.run_capture(d, api, server_ids=[1], observe_live=True)
            self.assertEqual(wildcard["observed_stock_rows"], 2)
            before = len(api.urls)
            code, normal = self.run_capture(d, api, budget=2, server_ids=[1],
                                             observe_live=True, blessed_type=1)
            self.assertEqual(code, 0, normal)
            self.assertEqual(len(api.urls), before + 2)
            self.assertEqual(normal["observed_stock_rows"], 1)
            self.assertIn("blessedType=1", normal["stock_receipts"][0]["pages"][0]["url"])
        for invalid in (-1, 4, True, "1"):
            with self.subTest(invalid=invalid), tempfile.TemporaryDirectory() as d:
                with self.assertRaises(collect.CaptureError):
                    collect.Collector(d, blessed_type=invalid)


    def test_stock_page_sampling_keeps_whole_rows_then_continues_next_group(self):
        def handler(path, q):
            if not path.endswith("/stock"):
                return page([row(1), row(2)])
            item = int(path.split("/")[-2])
            n = int(q["page"][0])
            if item == 1:
                return page([row(1, price=50)] * (10 if n < 3 else 1),
                            number=n, size=10, total=21)
            return page([row(2, price=70)] * 2, size=10)
        for maximum in (1, 2):
            with self.subTest(maximum=maximum), tempfile.TemporaryDirectory() as d:
                api = Official(handler)
                code, report = self.run_capture(d, api, server_ids=[1], observe_live=True,
                                                 max_stock_pages=maximum)
                self.assertEqual(code, 0, report)
                self.assertEqual(report["stock_groups"], 2)
                self.assertEqual(report["observed_stock_rows"], maximum * 10 + 2)
                first = report["stock_receipts"][0]
                self.assertTrue(first["page_sampling_applied"])
                self.assertFalse(first["pagination_drift_observed"])
                self.assertEqual(report["drift_events"], [])
                self.assertEqual(first["max_stock_pages"], maximum)
                self.assertEqual(first["bundle_rows"], maximum * 10)
                self.assertFalse(report["stock_receipts"][1]["page_sampling_applied"])
                event = report["stock_page_sampling_events"][0]
                self.assertEqual(event["unrequested_page_range_at_last_observation"], [maximum + 1, 3])
                self.assertIsNone(event["omitted_pages"])
                self.assertIsNone(event["omitted_listing_count"])
                self.assertFalse(event["exact_omission_count_verified"])
                self.assertFalse(report["coverage"]["complete"])
                requested = [u for u in api.urls if "/item/1/stock?" in u]
                self.assertEqual(len(requested), maximum)
        for invalid in (0, -1, True):
            with self.subTest(invalid=invalid), tempfile.TemporaryDirectory() as d:
                with self.assertRaises(collect.CaptureError):
                    collect.Collector(d, observe_live=True, max_stock_pages=invalid)
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(collect.CaptureError):
                collect.Collector(d, max_stock_pages=1)

    def test_normal_blessing_filter_is_also_applied_to_catalog_queries(self):
        for blessed_type in (0, 1, 2, 3):
            def handler(path, q):
                if blessed_type:
                    self.assertEqual(q["blessedType"], [str(blessed_type)])
                elif not path.endswith("/stock"):
                    self.assertNotIn("blessedType", q)
                if path.endswith("/stock"):
                    return page([row(price=50)], size=10)
                return page([row()])
            with self.subTest(blessed_type=blessed_type), tempfile.TemporaryDirectory() as d:
                code, report = self.run_capture(d, Official(handler), server_ids=[1],
                                                 observe_live=True, blessed_type=blessed_type)
                self.assertEqual(code, 0, report)
                self.assertEqual(report["stock_receipts"][0]["blessed_type_filter"], blessed_type)


    def test_timeout_first_stock_page_is_unknown_and_resume_skips_without_retry(self):
        def handler(path, q):
            if not path.endswith("/stock"):
                return page([row(1), row(2)])
            if "/item/1/" in path:
                raise URLError(TimeoutError("actual transport timeout"))
            return page([row(2, price=50)], size=10)
        with tempfile.TemporaryDirectory() as d:
            api = Official(handler)
            code, report = self.run_capture(d, api, server_ids=[1], observe_live=True)
            self.assertEqual(code, 0, report)
            self.assertEqual(report["stock_groups"], 1)
            self.assertEqual(report["stock_groups_without_successful_response"], 1)
            failed = report["stock_receipts"][0]
            self.assertIsNone(failed["first_reported_total"])
            self.assertIsNone(failed["bundle_rows"])
            self.assertEqual(failed["pages"], [])
            self.assertEqual(failed["observation_status"], "no_successful_response_timeout")
            self.assertEqual(report["incomplete_scopes"], ["server:1"])
            self.assertEqual(report["completed_scopes"], [])
            failure_path = next((Path(d) / "failures").glob("*.json"))
            saved_bytes = failure_path.read_bytes()
            failure = json.loads(saved_bytes)
            self.assertEqual(failure["reason_type"], "TimeoutError")
            self.assertFalse(failure["raw_response_saved"])
            key = hashlib.sha256(failure["url"].encode()).hexdigest()
            self.assertFalse((Path(d) / "raw" / (key + ".json")).exists())
            before = len(api.urls)
            code, report = self.run_capture(d, api, budget=0, server_ids=[1], observe_live=True)
            self.assertEqual(code, 0, report)
            self.assertEqual(len(api.urls), before)
            self.assertTrue(report["transport_timeout_events"][0]["skipped_saved_failure"])
            self.assertEqual(failure_path.read_bytes(), saved_bytes)

    def test_timeout_middle_stock_page_preserves_successes_and_continues_known_pages(self):
        def handler(path, q):
            if not path.endswith("/stock"):
                return page([row()])
            n = int(q["page"][0])
            if n == 2:
                raise TimeoutError("actual socket timeout")
            return page([row(price=50)] * (10 if n == 1 else 1), number=n, size=10, total=21)
        with tempfile.TemporaryDirectory() as d:
            api = Official(handler)
            code, report = self.run_capture(d, api, server_ids=[1], observe_live=True)
            self.assertEqual(code, 0, report)
            group = report["stock_receipts"][0]
            self.assertEqual(group["bundle_rows"], 11)
            self.assertEqual(group["first_reported_total"], 21)
            self.assertEqual(group["observation_status"], "partial_observations_with_timeout")
            self.assertTrue(group["timeout_omission_observed"])
            self.assertFalse(group["pagination_drift_observed"])
            self.assertEqual(len(group["pages"]), 2)
            self.assertIn("page=3", group["pages"][1]["url"])
            self.assertEqual(report["observed_stock_rows"], 11)
            event = report["possible_omission_events"][0]
            self.assertEqual(event["page"], 2)
            self.assertIsNone(event["omitted_listing_count"])
            before = len(api.urls)
            code, report = self.run_capture(d, api, budget=0, server_ids=[1], observe_live=True)
            self.assertEqual(code, 0, report)
            self.assertEqual(len(api.urls), before)
            self.assertEqual(report["observed_stock_rows"], 11)

    def test_timeout_catalog_first_page_continues_other_category_without_zero_claim(self):
        def handler(path, q):
            if path.endswith("/stock"):
                return page([row(price=50)], size=10)
            if q["category1"] == ["1"]:
                raise URLError(TimeoutError("catalog transport timeout"))
            return page([row()])
        with tempfile.TemporaryDirectory() as d:
            api = Official(handler)
            code, report = self.run_capture(d, api, server_ids=[1], category1_ids=[1, 2],
                                             observe_live=True)
            self.assertEqual(code, 0, report)
            self.assertEqual(report["stock_groups"], 1)
            self.assertEqual(report["stock_receipts"][0]["category1_ids"], [2])
            event = report["possible_omission_events"][0]
            self.assertEqual(event["category_filters"], {"category1": 1})
            self.assertIsNone(event["first_reported_total"])
            self.assertFalse(report["coverage"]["complete"])
            before = len(api.urls)
            code, _ = self.run_capture(d, api, budget=0, server_ids=[1], category1_ids=[1, 2],
                                        observe_live=True)
            self.assertEqual(code, 0)
            self.assertEqual(len(api.urls), before)

    def test_timeout_middle_catalog_page_continues_later_known_page(self):
        def handler(path, q):
            if path.endswith("/stock"):
                return page([row(int(path.split("/")[-2]), price=50)], size=10)
            n = int(q["page"][0])
            if n == 2:
                raise TimeoutError("catalog page timeout")
            return page([row(n)], number=n, size=1, total=3)
        with tempfile.TemporaryDirectory() as d:
            code, report = self.run_capture(d, Official(handler), server_ids=[1], observe_live=True)
            self.assertEqual(code, 0, report)
            self.assertEqual(report["stock_groups"], 2)
            self.assertEqual([r["item_id"] for r in report["stock_receipts"]], [1, 3])
            self.assertEqual(report["possible_omission_events"][0]["query_kind"], "catalog")

    def test_timeout_is_soft_only_for_observe_and_not_lookalike_http_errors(self):
        for error in (URLError("403 timed out"), URLError("timed out"),
                      HTTPError(collect.probe.BASE, 403, TimeoutError("forbidden"), {},
                                BytesIO(b'{"error":"forbidden"}'))):
            def handler(path, q):
                if path.endswith("/stock"):
                    raise error
                return page([row()])
            with self.subTest(error=repr(error)), tempfile.TemporaryDirectory() as d:
                code, report = self.run_capture(d, Official(handler), server_ids=[1], observe_live=True)
                self.assertEqual(code, 1, report)
                self.assertEqual(report["transport_timeout_events"], [])
                self.assertFalse((Path(d) / "failures").exists())
        def handler(path, q):
            if path.endswith("/stock"):
                raise URLError(TimeoutError("strict timeout"))
            return page([row()])
        with tempfile.TemporaryDirectory() as d:
            api = Official(handler)
            code, report = self.run_capture(d, api, server_ids=[1])
            self.assertEqual(code, 1)
            self.assertEqual(len(api.urls), 5)
            self.assertFalse((Path(d) / "failures").exists())


if __name__ == "__main__":
    unittest.main()
