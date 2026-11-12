#!/usr/bin/env python3
"""Resume bounded, immutable official market observations; never promote production.

Default --max-requests=0 replays verified local receipts without network access.
Use the SAME output directory to resume. A page is never requested twice after
its body/receipt was saved. No atomic snapshot token/listing ID is available:
even a finished traversal is NOT coverage.complete or an importable snapshot.
--observe-live explicitly retains drifted/possibly overlapping observations;
the default strict mode still stops on drift. Neither mode promotes production.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import build_opener

try:
    from . import probe_official as probe
except ImportError:
    import probe_official as probe

SCHEMA = "twilight.exchange-observations.v1"


class CaptureError(RuntimeError):
    pass


class BudgetExhausted(CaptureError):
    pass


class ObservationTimeout(CaptureError):
    def __init__(self, record):
        self.record = record
        super().__init__("Recorded transport timeout; URL skipped without retry: " + record["url"])


def transport_timeout(error):
    # HTTP status errors remain hard failures even if their reason looks like a timeout.
    return (not isinstance(error, HTTPError) and
            (isinstance(error, TimeoutError) or
             isinstance(error, URLError) and isinstance(error.reason, TimeoutError)))


def integer(value, minimum=0, maximum=9007199254740991):
    return (isinstance(value, (int, float)) and not isinstance(value, bool)
            and minimum <= value <= maximum and math.isfinite(value)
            and int(value) == value)


def endpoint(path, **params):
    return probe.BASE + path + ("?" + urlencode(params) if params else "")


def page(data, number, maximum_size):
    if not isinstance(data, dict) or not isinstance(data.get("contents"), list):
        raise CaptureError("Unexpected official page shape")
    p = data.get("pagination")
    if not isinstance(p, dict) or any(not integer(p.get(k)) for k in
                                     ("page", "size", "total", "lastPage", "limit")):
        raise CaptureError("Missing or invalid official pagination")
    if p["page"] != number or not 1 <= p["size"] <= maximum_size or p["limit"] < 1:
        raise CaptureError("Official page number, size or limit mismatch")
    pages = math.ceil(p["total"] / p["size"])
    if p["lastPage"] != min(pages, math.ceil(p["limit"] / p["size"])):
        if not (p["total"] == 0 and p["lastPage"] in (0, 1)):
            raise CaptureError("Official pagination cannot cover declared total")
    expected = min(p["size"], max(0, min(p["total"], p["limit"]) -
                                (number - 1) * p["size"]))
    if len(data["contents"]) != expected:
        raise CaptureError("Official row count differs from pagination")
    return data["contents"], p


def item_key(row):
    if not isinstance(row, dict) or any(not integer(row.get(k), 1) for k in
                                       ("serverId", "itemId")):
        raise CaptureError("Invalid catalog identity")
    if not integer(row.get("enchantLevel"), 0, 255) or not isinstance(row.get("world"), bool):
        raise CaptureError("Invalid catalog enchant/scope")
    return row["serverId"], row["itemId"], row["enchantLevel"]


def scopes(servers, worlds):
    if not isinstance(servers, list) or not isinstance(worlds, list):
        raise CaptureError("Unexpected official server/world inventory")
    local, world_ids = {}, set()
    for w in servers:
        if not isinstance(w, dict) or not integer(w.get("worldId"), 1) or not isinstance(w.get("servers"), list):
            raise CaptureError("Invalid official world/server row")
        if w["worldId"] in world_ids:
            raise CaptureError("Duplicate official world ID")
        world_ids.add(w["worldId"])
        for s in w["servers"]:
            if not isinstance(s, dict) or not integer(s.get("serverId"), 1) or s["serverId"] in local:
                raise CaptureError("Duplicate/invalid official local server ID")
            local[s["serverId"]] = w["worldId"]
    market_ids = []
    for w in worlds:
        if not isinstance(w, dict) or not integer(w.get("serverId"), 1):
            raise CaptureError("Invalid official market-world ID")
        market_ids.append(w["serverId"])
    if (not local or len(set(market_ids)) != len(market_ids)
            or set(market_ids) != world_ids or set(local) & world_ids):
        raise CaptureError("Official local/world inventories disagree")
    return ([{"kind": "server", "id": s, "world_id": w}
             for s, w in sorted(local.items())] +
            [{"kind": "world", "id": w, "world_id": w} for w in sorted(world_ids)])


def categories(data):
    if not isinstance(data, list) or not data:
        raise CaptureError("Missing official market categories")
    out, seen = [], set()
    for row in data:
        if not isinstance(row, dict) or not str(row.get("id", "")).isdigit() or not isinstance(row.get("child"), list):
            raise CaptureError("Invalid official category tree")
        key = int(row["id"])
        if key < 1 or key in seen:
            raise CaptureError("Duplicate official category")
        seen.add(key)
        children = []
        for child in row["child"]:
            if not isinstance(child, dict) or not str(child.get("id", "")).isdigit():
                raise CaptureError("Invalid official child category")
            value = int(child["id"])
            if value < 1 or value in children:
                raise CaptureError("Duplicate official child category")
            children.append(value)
        out.append((key, children))
    return out


class Collector:
    def __init__(self, output, max_requests=0, delay=1.0, opener=None, sleep=time.sleep,
                 server_ids=(), world_ids=(), observe_live=False, category1_ids=(), blessed_type=0, max_stock_pages=None):
        if (not isinstance(max_requests, int) or isinstance(max_requests, bool)
                or max_requests < 0 or not math.isfinite(delay) or not 1 <= delay <= 3600):
            raise CaptureError("Request budget must be nonnegative; delay must be 1..3600 seconds")
        self.output = Path(output)
        self.raw = self.output / "raw"
        self.max_requests, self.delay = max_requests, delay
        self.opener, self.sleep = opener, sleep
        self.requests = self.reused = 0
        if not isinstance(observe_live, bool):
            raise CaptureError("observe_live must be a boolean")
        self.observe_live = observe_live
        if max_stock_pages is not None:
            if not integer(max_stock_pages, 1) or not observe_live:
                raise CaptureError("max_stock_pages must be positive and requires observe_live")
            max_stock_pages = int(max_stock_pages)
        self.max_stock_pages = max_stock_pages
        self.filter_categories = set(category1_ids)
        if not integer(blessed_type, 0, 3):
            raise CaptureError("blessed_type must be one of the official filters 0,1,2,3")
        self.blessed_type = int(blessed_type)
        self.catalog_categories = {}
        self.timeout_urls = set()
        self.filter_servers, self.filter_worlds = set(server_ids), set(world_ids)
        if any(not integer(x, 1) for x in self.filter_servers | self.filter_worlds | self.filter_categories):
            raise CaptureError("Selected scope IDs must be positive integers")
        self.report = {
            "schema": SCHEMA, "status": "partial", "coverage": {"complete": False},
            "atomic_snapshot_verified": False, "traversal_complete": False,
            "production_import_performed": False, "expected_scopes": [],
            "completed_scopes": [], "catalog_groups": 0, "stock_groups": 0,
            "observed_bundle_rows": 0, "stock_receipts": [],
            "observation_mode": "live_non_atomic" if observe_live else "strict",
            "blessed_type_filter": self.blessed_type,
            "run_started_at_utc": probe.utc_now(),
            "drift_events": [], "possible_overlap_events": [], "cap_events": [],
            "max_stock_pages_per_group": self.max_stock_pages,
            "stock_page_sampling_events": [],
            "transport_timeout_events": [], "possible_omission_events": [],
            "stock_groups_without_successful_response": 0,
            "visited_scopes": [], "incomplete_scopes": [],
            "observed_stock_rows": 0, "observed_stock_pages": 0,
            "observed_stock_rows_distinct_listings_verified": False,
            "catalog_duplicate_observations": 0,
            "limits": ["Live pages have no atomic snapshot token or stable listing ID.",
                       "Raw stock rows are observations; identical rows remain distinct.",
                       "Client ItemClass mapping and production promotion require separate review."],
        }

    def cursor(self):
        # Small crash checkpoint. Raw receipts are authoritative; queue replay
        # reconstructs counters without trusting mutable progress or refetching.
        keys = ("current_scope", "current_catalog_filters", "stock_queue_size",
                "stock_queue_position", "current_stock", "pending_url", "last_saved_url",
                "observation_mode", "blessed_type_filter", "current_stock_observation")
        data = {k: self.report[k] for k in keys if k in self.report}
        data.update(schema=SCHEMA, coverage_complete=False,
                    requests_this_run=self.requests, updated_at_utc=probe.utc_now())
        path = self.output / f".cursor-{os.getpid()}.tmp"
        try:
            with path.open("x") as stream:
                json.dump(data, stream, indent=2)
                stream.write("\n")
            os.replace(path, self.output / "cursor.json")
        finally:
            if path.exists():
                path.unlink()

    def remember_timeout(self, record, skipped_saved_failure):
        if record["url"] not in self.timeout_urls:
            self.timeout_urls.add(record["url"])
            self.report["transport_timeout_events"].append({
                **record, "skipped_saved_failure": skipped_saved_failure})
        self.report.pop("pending_url", None)

    def save_timeout(self, url, error, occurred_at_utc=None):
        if not transport_timeout(error):
            raise CaptureError("Only typed transport timeouts may be saved as skipped failures")
        record = {
            "schema": "twilight.exchange-transport-timeout.v1",
            "kind": "transport_timeout", "url": url,
            "occurred_at_utc": occurred_at_utc or probe.utc_now(),
            "error_type": type(error).__name__,
            "reason_type": type(error.reason).__name__ if isinstance(error, URLError) else None,
            "error": str(error), "raw_response_saved": False,
            "failed_page_reported_total": None, "retry_policy": "skip_without_retry",
        }
        folder = self.output / "failures"
        folder.mkdir(parents=True, exist_ok=True)
        path = folder / (hashlib.sha256(url.encode()).hexdigest() + ".json")
        with path.open("x") as stream:
            json.dump(record, stream, indent=2, ensure_ascii=False)
            stream.write("\n")
        return record

    def omitted_timeout(self, error, **details):
        self.report["possible_omission_events"].append({
            "kind": "transport_timeout_no_response", "url": error.record["url"],
            "failure_file": "failures/" + hashlib.sha256(error.record["url"].encode()).hexdigest() + ".json",
            "omitted_listing_count": None, "exact_omission_count_verified": False,
            **details})

    def get(self, url):
        key = hashlib.sha256(url.encode()).hexdigest()
        receipt = self.raw / (key + ".receipt.json")
        body = self.raw / (key + ".json")
        cached = receipt.exists()
        failure_path = self.output / "failures" / (key + ".json")
        if failure_path.exists():
            record = json.loads(failure_path.read_bytes())
            if (record.get("schema") != "twilight.exchange-transport-timeout.v1" or
                    record.get("kind") != "transport_timeout" or record.get("url") != url or
                    record.get("retry_policy") != "skip_without_retry" or
                    record.get("raw_response_saved") is not False or cached or body.exists()):
                raise CaptureError("Saved timeout failure metadata is invalid or conflicts with raw evidence")
            self.remember_timeout(record, True)
            raise ObservationTimeout(record)
        if not cached:
            if body.exists():
                raise CaptureError("Orphan raw body: stop instead of overwriting")
            if self.requests >= self.max_requests:
                self.report["next_url"] = url
                raise BudgetExhausted("Request budget reached; resume the same output directory")
            self.sleep(self.delay)
            if self.opener is None:
                self.opener = build_opener(probe.NoRedirect())
            self.requests += 1
            self.report["pending_url"] = url
            self.cursor()
        # This validates cached URL/status/JSON/hash and refuses saved HTTP errors.
        try:
            result = probe.probe(url, self.raw, self.opener)
        except (TimeoutError, URLError) as error:
            if not self.observe_live or not transport_timeout(error):
                raise
            record = self.save_timeout(url, error)
            self.remember_timeout(record, False)
            self.cursor()
            raise ObservationTimeout(record) from error
        if result == "reused":
            self.reused += 1
        else:
            self.report["last_saved_url"] = url
            self.report.pop("pending_url", None)
            self.cursor()
        raw_receipt = json.loads(receipt.read_bytes())
        window = self.report.setdefault("observation_window", {})
        started = raw_receipt["request_started_at_utc"]
        completed = raw_receipt["request_completed_at_utc"]
        window["first_request_started_at_utc"] = min(started, window.get("first_request_started_at_utc", started))
        window["last_request_completed_at_utc"] = max(completed, window.get("last_request_completed_at_utc", completed))
        return json.loads(body.read_bytes()), raw_receipt

    def collect_pages(self, path, params, maximum_size, first=None, validate_rows=None):
        if self.observe_live:
            return self.collect_observed_pages(path, params, maximum_size, first, validate_rows)
        data, receipt = first or self.get(endpoint(path, **params, page=1))
        rows, p = page(data, 1, maximum_size)
        if validate_rows:
            validate_rows(rows)
        if p["total"] > p["limit"]:
            raise CaptureError("Search cap reached; no unverified truncation accepted")
        baseline = {k: p[k] for k in ("total", "size", "lastPage", "limit")}
        all_rows, receipts = list(rows), [receipt]
        for number in range(2, int(p["lastPage"]) + 1):
            data, receipt = self.get(endpoint(path, **params, page=number))
            rows, later = page(data, number, maximum_size)
            if validate_rows:
                validate_rows(rows)
            if {k: later[k] for k in baseline} != baseline:
                raise CaptureError("Live pagination changed during traversal; observations incomplete")
            all_rows.extend(rows)
            receipts.append(receipt)
        if len(all_rows) != p["total"]:
            raise CaptureError("Page traversal differs from declared total")
        return all_rows, receipts, int(p["total"])

    def observation(self, collection, receipt, **details):
        event = {"url": receipt["url"], "body_file": receipt["body_file"],
                 "sha256": receipt["sha256"], **details}
        self.report[collection].append(event)

    def collect_observed_pages(self, path, params, maximum_size, first=None, validate_rows=None):
        is_stock = path.endswith("/stock")
        try:
            data, receipt = first or self.get(endpoint(path, **params, page=1))
        except ObservationTimeout as error:
            self.omitted_timeout(error, query_kind="stock" if is_stock else "catalog",
                                 page=1, first_reported_total=None)
            if is_stock:
                self.report["current_stock_observation"] = {
                    "query": endpoint(path, **params), "observed_rows": None, "pages": [],
                    "first_reported_total": None, "no_successful_response": True,
                    "stock_population_complete": False}
            return [], [], None
        rows, p = page(data, 1, maximum_size)
        if validate_rows:
            validate_rows(rows)
        initial_total = int(p["total"])
        previous = {k: p[k] for k in ("total", "size", "lastPage", "limit")}
        all_rows, receipts = list(rows), [receipt]
        highwater = int(p["lastPage"])
        sampled = False
        omitted_page = False

        def record_page(received, meta, ref):
            if meta["total"] > meta["limit"]:
                self.observation("cap_events", ref, kind="page_search_cap",
                                 reported_total=meta["total"], result_limit=meta["limit"],
                                 resolution="retain_accessible_observations_only")
            if is_stock:
                self.report["observed_stock_rows"] += len(received)
                self.report["observed_stock_pages"] += 1
                self.report["current_stock_observation"] = {
                    "query": endpoint(path, **params), "observed_rows": len(all_rows),
                    "pages": [{"body_file": r["body_file"], "sha256": r["sha256"],
                               "url": r["url"]} for r in receipts],
                    "distinct_listings_verified": False,
                    "blessed_type_filter": self.blessed_type,
                    "page_highwater": highwater,
                }

        record_page(rows, p, receipt)
        number = 2
        while number <= highwater:
            if is_stock and self.max_stock_pages is not None and number > self.max_stock_pages:
                self.observation("stock_page_sampling_events", receipts[-1],
                                 kind="stock_page_sample_stopped",
                                 stock_query=endpoint(path, **params),
                                 included_pages=len(receipts), observed_rows=len(all_rows),
                                 max_stock_pages=self.max_stock_pages,
                                 observed_page_highwater=highwater,
                                 unrequested_page_range_at_last_observation=[number, highwater],
                                 omitted_pages=None, omitted_listing_count=None,
                                 exact_omission_count_verified=False,
                                 stock_population_complete=False)
                sampled = True
                self.report["current_stock_observation"]["page_sampling_applied"] = True
                self.report["current_stock_observation"]["omitted_pages"] = None
                break
            try:
                data, receipt = self.get(endpoint(path, **params, page=number))
            except ObservationTimeout as error:
                omitted_page = True
                self.omitted_timeout(error, query_kind="stock" if is_stock else "catalog",
                                     page=number, first_reported_total=initial_total,
                                     observed_page_highwater=highwater)
                number += 1
                continue
            rows, later = page(data, number, maximum_size)
            if validate_rows:
                validate_rows(rows)
            current = {k: later[k] for k in previous}
            if current != previous:
                self.observation("drift_events", receipt, kind="pagination_changed",
                                 query_kind="stock" if is_stock else "catalog",
                                 previous=previous, current=current, page=number)
                self.observation("possible_overlap_events", receipt,
                                 kind="live_page_positions_may_overlap_or_omit",
                                 query_kind="stock" if is_stock else "catalog", page=number)
            highwater = max(highwater, int(later["lastPage"]))
            all_rows.extend(rows)
            receipts.append(receipt)
            record_page(rows, later, receipt)
            previous = current
            number += 1
        if len(all_rows) != initial_total and not sampled and not omitted_page:
            self.observation("drift_events", receipts[-1],
                             kind="observed_rows_differ_from_first_reported_total",
                             query_kind="stock" if is_stock else "catalog",
                             first_reported_total=initial_total, observed_rows=len(all_rows))
        return all_rows, receipts, initial_total

    @staticmethod
    def validate_catalog_rows(rows, scope):
        for row in rows:
            item_key(row)
            if scope["kind"] == "server" and row["world"]:
                if row["serverId"] != scope["world_id"]:
                    raise CaptureError("Unexpected shared-world row in local catalog")
            elif row["serverId"] != scope["id"] or row["world"] != (scope["kind"] == "world"):
                raise CaptureError("Catalog returned an unexpected market scope")

    def tagged_catalog(self, result, filters):
        category = filters.get("category1")
        if category is not None:
            for row in result[0]:
                self.catalog_categories.setdefault(item_key(row), set()).add(category)
        return result

    def catalog(self, scope, category_tree, filters=None):
        filters = filters or {}
        self.report["current_catalog_filters"] = filters
        path = "/price/search/item"
        params = {"serverId": scope["id"], "sale": "true", "size": 30, **filters}
        if self.blessed_type:
            params["blessedType"] = self.blessed_type
        try:
            first = self.get(endpoint(path, **params, page=1))
        except ObservationTimeout as error:
            if not self.observe_live:
                raise
            self.omitted_timeout(error, query_kind="catalog", page=1,
                                 scope=f'{scope["kind"]}:{scope["id"]}',
                                 category_filters=filters, first_reported_total=None)
            return [], [], None
        first_rows, p = page(first[0], 1, 30)
        self.validate_catalog_rows(first_rows, scope)
        validator = lambda received: self.validate_catalog_rows(received, scope)
        if p["total"] <= p["limit"]:
            return self.tagged_catalog(self.collect_pages(path, params, 30, first, validator), filters)
        if self.observe_live:
            self.observation("cap_events", first[1], kind="catalog_search_cap",
                             reported_total=p["total"], result_limit=p["limit"],
                             filters=filters, resolution="try_official_category_partition")
        if "category2" in filters:
            if self.observe_live:
                return self.tagged_catalog(self.collect_pages(path, params, 30, first, validator), filters)
            raise CaptureError("Leaf category still exceeds search cap; stop incomplete")
        if "category1" not in filters:
            partitions = [{"category1": key} for key, _ in category_tree]
        else:
            child_ids = dict(category_tree).get(filters["category1"], [])
            if not child_ids:
                if self.observe_live:
                    return self.tagged_catalog(self.collect_pages(path, params, 30, first, validator), filters)
                raise CaptureError("Capped category has no official child partition")
            partitions = [{**filters, "category2": key} for key in child_ids]
        rows, receipts, total = [], [], 0
        unknown_child_total = False
        for child in partitions:
            child_rows, child_receipts, child_total = self.catalog(scope, category_tree, child)
            rows.extend(child_rows)
            receipts.extend(child_receipts)
            if child_total is None:
                unknown_child_total = True
            else:
                total += child_total
        if unknown_child_total:
            receipts.insert(0, first[1])
            return rows, receipts, None
        if total != p["total"]:
            if not self.observe_live:
                raise CaptureError("Category totals do not partition parent; live capture incomplete")
            self.observation("drift_events", first[1], kind="category_partition_total_changed",
                             parent_total=p["total"], child_total_sum=total, filters=filters)
            self.observation("possible_overlap_events", first[1],
                             kind="category_partition_may_overlap_or_omit", filters=filters)
        receipts.insert(0, first[1])
        return rows, receipts, total

    def selected_rows(self, rows, scope):
        selected, seen = [], set()
        for row in rows:
            key = item_key(row)
            if key in seen:
                if not self.observe_live:
                    raise CaptureError("Repeated catalog identity across pages/categories; stop incomplete")
                self.report["catalog_duplicate_observations"] += 1
                self.report["possible_overlap_events"].append({
                    "kind": "repeated_catalog_identity_queued_once",
                    "scope": f'{scope["kind"]}:{scope["id"]}', "item_key": list(key)})
                continue
            seen.add(key)
            if scope["kind"] == "server" and row["world"]:
                if row["serverId"] != scope["world_id"]:
                    raise CaptureError("Unexpected shared-world row in local catalog")
                continue
            if row["serverId"] != scope["id"] or row["world"] != (scope["kind"] == "world"):
                raise CaptureError("Catalog returned an unexpected market scope")
            selected.append(row)
        return selected

    def stock(self, row):
        server, item, enchant = item_key(row)
        # Official filters: 0 unfiltered; 1 normal; 2 blessed; 3 cursed.
        # An unfiltered response never proves that a row is normal.
        params = {"serverId": server, "enchantLevel": enchant,
                  "blessedType": self.blessed_type, "size": 10}
        path = f"/price/search/item/{item}/stock"

        def validate_stock(received):
            for stock in received:
                if item_key(stock) != (server, item, enchant) or stock["world"] != row["world"]:
                    raise CaptureError("Stock response changed catalog identity/scope")
                if not integer(stock.get("quantity"), 1) or not integer(stock.get("salePrice"), 1):
                    raise CaptureError("Stock quantity/bundle price not a positive exact integer")

        drift_start = len(self.report["drift_events"])
        sampling_start = len(self.report["stock_page_sampling_events"])
        omission_start = len(self.report["possible_omission_events"])
        rows, receipts, first_total = self.collect_pages(path, params, 10, validate_rows=validate_stock)
        # Equal rows can be separate sales or live-page overlap. Keep every row.
        if receipts:
            self.report["stock_groups"] += 1
        else:
            self.report["stock_groups_without_successful_response"] += 1
        self.report["observed_bundle_rows"] += len(rows)
        self.report["stock_receipts"].append({
            "server_id": server, "item_id": item, "enchant": enchant, "world": row["world"],
            "blessed_type_filter": self.blessed_type, "bundle_rows": len(rows) if receipts else None,
            "category1_ids": sorted(self.catalog_categories.get((server, item, enchant), set())),
            "category_provenance": "official_catalog_query_filters_not_guessed",
            "first_reported_total": first_total,
            "observation_status": ("no_successful_response_timeout" if not receipts else
                "partial_observations_with_timeout" if
                len(self.report["possible_omission_events"]) != omission_start else "observed"),
            "timeout_omission_observed": len(self.report["possible_omission_events"]) != omission_start,
            "distinct_listings_verified": False,
            "pagination_drift_observed": len(self.report["drift_events"]) != drift_start,
            "page_sampling_applied": len(self.report["stock_page_sampling_events"]) != sampling_start,
            "max_stock_pages": self.max_stock_pages,
            "pages": [{"body_file": r["body_file"], "sha256": r["sha256"],
                       "url": r["url"]} for r in receipts],
        })

    def run(self):
        self.raw.mkdir(parents=True, exist_ok=True)
        # A process lock prevents two resumptions from racing exclusive raw writes.
        import fcntl
        with (self.output / ".capture.lock").open("a") as lock:
            try:
                fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError as exc:
                raise CaptureError("Another collector is using this output directory") from exc
            code = 0
            try:
                servers, _ = self.get(endpoint("/game/server"))
                worlds, _ = self.get(endpoint("/game/market/world"))
                category_data, _ = self.get(endpoint("/game/market/category"))
                all_scopes = scopes(servers, worlds)
                tree = categories(category_data)
                category_ids = {key for key, _ in tree}
                if self.filter_categories - category_ids:
                    raise CaptureError("Selected category1 is absent from official inventory")
                chosen = [s for s in all_scopes if (
                    not self.filter_servers and not self.filter_worlds) or
                    s["id"] in (self.filter_servers if s["kind"] == "server" else self.filter_worlds)]
                actual_s = {s["id"] for s in chosen if s["kind"] == "server"}
                actual_w = {s["id"] for s in chosen if s["kind"] == "world"}
                if self.filter_servers - actual_s or self.filter_worlds - actual_w:
                    raise CaptureError("Selected scope is absent from official inventory")
                self.report["all_official_scopes"] = [f'{s["kind"]}:{s["id"]}' for s in all_scopes]
                self.report["expected_scopes"] = [f'{s["kind"]}:{s["id"]}' for s in chosen]
                category_is_all = not self.filter_categories or self.filter_categories == category_ids
                self.report["market_scope_selection_is_all"] = len(chosen) == len(all_scopes)
                self.report["category_selection_is_all"] = category_is_all
                self.report["scope_selection_is_all"] = len(chosen) == len(all_scopes) and category_is_all
                self.report["selection_label"] = ("all_official_scopes_unverified" if
                    self.report["scope_selection_is_all"] else "representative_or_category_partial")
                self.report["selection"] = {
                    "selected_market_scope_count": len(chosen),
                    "available_market_scope_count": len(all_scopes),
                    "selected_category1_ids": sorted(self.filter_categories or category_ids),
                    "available_category1_ids": sorted(category_ids),
                    "blessed_type_filter": self.blessed_type,
                }
                for scope in chosen:
                    scope_omissions = len(self.report["possible_omission_events"])
                    self.report["current_scope"] = f'{scope["kind"]}:{scope["id"]}'
                    if self.filter_categories:
                        rows = []
                        for category_id in sorted(self.filter_categories):
                            category_rows, _, _ = self.catalog(scope, tree, {"category1": category_id})
                            rows.extend(category_rows)
                    else:
                        rows, _, _ = self.catalog(scope, tree)
                    local = self.selected_rows(rows, scope)
                    self.report["catalog_groups"] += len(local)
                    self.report["stock_queue_size"] = len(local)
                    for index, row in enumerate(local):
                        self.report["stock_queue_position"] = index
                        self.report["current_stock"] = list(item_key(row))
                        self.stock(row)
                        self.report["stock_queue_position"] = index + 1
                    scope_name = f'{scope["kind"]}:{scope["id"]}'
                    self.report["visited_scopes"].append(scope_name)
                    if len(self.report["possible_omission_events"]) != scope_omissions:
                        self.report["incomplete_scopes"].append(scope_name)
                    else:
                        self.report["completed_scopes"].append(scope_name)
                self.report["traversal_complete"] = True
                self.report["status"] = ("observed_traversal_unverified" if self.observe_live
                                         else "traversed_unverified")
            except BudgetExhausted as exc:
                self.report["status"], self.report["reason"], code = "bounded_partial", str(exc), 2
            except (CaptureError, probe.ProbeError, OSError, ValueError, KeyError, TypeError) as exc:
                self.report["status"], self.report["reason"], code = "stopped_incomplete", str(exc), 1
            self.report["requests_this_run"] = self.requests
            self.report["reused_receipts_this_run"] = self.reused
            self.report["updated_at_utc"] = probe.utc_now()
            temp = self.output / f".progress-{os.getpid()}.tmp"
            try:
                with temp.open("x") as stream:
                    json.dump(self.report, stream, indent=2, ensure_ascii=False)
                    stream.write("\n")
                os.replace(temp, self.output / "progress.json")
            finally:
                if temp.exists():
                    temp.unlink()
        return code, self.report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--max-requests", type=int, default=0,
                        help="New GET request budget; default 0 means offline receipt replay")
    parser.add_argument("--delay", type=float, default=1.0)
    parser.add_argument("--max-stock-pages", type=probe.positive,
                        help="Observe-live only: retain first N stock pages per group; omissions remain unknown")
    parser.add_argument("--blessed-type", type=int, choices=(0, 1, 2, 3), default=0,
                        help="Official stock filter: 0 unfiltered, 1 normal, 2 blessed, 3 cursed")
    parser.add_argument("--observe-live", action="store_true",
                        help="Keep drifted/possibly overlapping live observations; never assert completeness")
    parser.add_argument("--category1", type=probe.positive, action="append", default=[],
                        help="Official top-level category ID; repeat to select a partial category scope")
    parser.add_argument("--server-id", type=probe.positive, action="append", default=[])
    parser.add_argument("--world-id", type=probe.positive, action="append", default=[])
    args = parser.parse_args(argv)
    try:
        code, report = Collector(args.output, args.max_requests, args.delay,
                                 server_ids=args.server_id, world_ids=args.world_id,
                                 observe_live=args.observe_live, category1_ids=args.category1,
                                 blessed_type=args.blessed_type,
                                 max_stock_pages=args.max_stock_pages).run()
    except (CaptureError, OSError) as exc:
        print("STOPPED:", exc, flush=True)
        return 1
    print(json.dumps({k: v for k, v in report.items() if k != "stock_receipts"},
                     ensure_ascii=False, indent=2), flush=True)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
