#!/usr/bin/env python3
"""Resume bounded, immutable official market observations; never promote production.

Default --max-requests=0 replays verified local receipts without network access.
Use the SAME output directory to resume. A page is never requested twice after
its body/receipt was saved. No atomic snapshot token/listing ID is available:
even a finished traversal is NOT coverage.complete or an importable snapshot.
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
                 server_ids=(), world_ids=()):
        if (not isinstance(max_requests, int) or isinstance(max_requests, bool)
                or max_requests < 0 or not math.isfinite(delay) or not 1 <= delay <= 3600):
            raise CaptureError("Request budget must be nonnegative; delay must be 1..3600 seconds")
        self.output = Path(output)
        self.raw = self.output / "raw"
        self.max_requests, self.delay = max_requests, delay
        self.opener, self.sleep = opener, sleep
        self.requests = self.reused = 0
        self.filter_servers, self.filter_worlds = set(server_ids), set(world_ids)
        if any(not integer(x, 1) for x in self.filter_servers | self.filter_worlds):
            raise CaptureError("Selected scope IDs must be positive integers")
        self.report = {
            "schema": SCHEMA, "status": "partial", "coverage": {"complete": False},
            "atomic_snapshot_verified": False, "traversal_complete": False,
            "production_import_performed": False, "expected_scopes": [],
            "completed_scopes": [], "catalog_groups": 0, "stock_groups": 0,
            "observed_bundle_rows": 0, "stock_receipts": [],
            "limits": ["Live pages have no atomic snapshot token or stable listing ID.",
                       "Raw stock rows are observations; identical rows remain distinct.",
                       "Client ItemClass mapping and production promotion require separate review."],
        }

    def cursor(self):
        # Small crash checkpoint. Raw receipts are authoritative; queue replay
        # reconstructs counters without trusting mutable progress or refetching.
        keys = ("current_scope", "current_catalog_filters", "stock_queue_size",
                "stock_queue_position", "current_stock", "pending_url", "last_saved_url")
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

    def get(self, url):
        key = hashlib.sha256(url.encode()).hexdigest()
        receipt = self.raw / (key + ".receipt.json")
        body = self.raw / (key + ".json")
        cached = receipt.exists()
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
        result = probe.probe(url, self.raw, self.opener)
        if result == "reused":
            self.reused += 1
        else:
            self.report["last_saved_url"] = url
            self.report.pop("pending_url", None)
            self.cursor()
        return json.loads(body.read_bytes()), json.loads(receipt.read_bytes())

    def collect_pages(self, path, params, maximum_size, first=None):
        data, receipt = first or self.get(endpoint(path, **params, page=1))
        rows, p = page(data, 1, maximum_size)
        if p["total"] > p["limit"]:
            raise CaptureError("Search cap reached; no unverified truncation accepted")
        baseline = {k: p[k] for k in ("total", "size", "lastPage", "limit")}
        all_rows, receipts = list(rows), [receipt]
        for number in range(2, int(p["lastPage"]) + 1):
            data, receipt = self.get(endpoint(path, **params, page=number))
            rows, later = page(data, number, maximum_size)
            if {k: later[k] for k in baseline} != baseline:
                raise CaptureError("Live pagination changed during traversal; observations incomplete")
            all_rows.extend(rows)
            receipts.append(receipt)
        if len(all_rows) != p["total"]:
            raise CaptureError("Page traversal differs from declared total")
        return all_rows, receipts, int(p["total"])

    def catalog(self, scope, category_tree, filters=None):
        filters = filters or {}
        self.report["current_catalog_filters"] = filters
        path = "/price/search/item"
        params = {"serverId": scope["id"], "sale": "true", "size": 30, **filters}
        first = self.get(endpoint(path, **params, page=1))
        _, p = page(first[0], 1, 30)
        if p["total"] <= p["limit"]:
            return self.collect_pages(path, params, 30, first)
        if "category2" in filters:
            raise CaptureError("Leaf category still exceeds search cap; stop incomplete")
        if "category1" not in filters:
            partitions = [{"category1": key} for key, _ in category_tree]
        else:
            child_ids = dict(category_tree).get(filters["category1"], [])
            if not child_ids:
                raise CaptureError("Capped category has no official child partition")
            partitions = [{**filters, "category2": key} for key in child_ids]
        rows, receipts, total = [], [], 0
        for child in partitions:
            child_rows, child_receipts, child_total = self.catalog(scope, category_tree, child)
            rows.extend(child_rows)
            receipts.extend(child_receipts)
            total += child_total
        if total != p["total"]:
            raise CaptureError("Category totals do not partition parent; live capture incomplete")
        receipts.insert(0, first[1])
        return rows, receipts, total

    def selected_rows(self, rows, scope):
        selected, seen = [], set()
        for row in rows:
            key = item_key(row)
            if key in seen:
                raise CaptureError("Repeated catalog identity across pages/categories; stop incomplete")
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
        # Official unfiltered UI uses blessedType=0. Never infer "normal" from 0.
        params = {"serverId": server, "enchantLevel": enchant,
                  "blessedType": 0, "size": 10}
        path = f"/price/search/item/{item}/stock"
        rows, receipts, _ = self.collect_pages(path, params, 10)
        for stock in rows:
            if item_key(stock) != (server, item, enchant) or stock["world"] != row["world"]:
                raise CaptureError("Stock response changed catalog identity/scope")
            if not integer(stock.get("quantity"), 1) or not integer(stock.get("salePrice"), 1):
                raise CaptureError("Stock quantity/bundle price not a positive exact integer")
        # Do not deduplicate: equal quantity/price/attributes may be separate sales.
        self.report["stock_groups"] += 1
        self.report["observed_bundle_rows"] += len(rows)
        self.report["stock_receipts"].append({
            "server_id": server, "item_id": item, "enchant": enchant, "world": row["world"],
            "blessed_type_filter": 0, "bundle_rows": len(rows),
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
                chosen = [s for s in all_scopes if (
                    not self.filter_servers and not self.filter_worlds) or
                    s["id"] in (self.filter_servers if s["kind"] == "server" else self.filter_worlds)]
                actual_s = {s["id"] for s in chosen if s["kind"] == "server"}
                actual_w = {s["id"] for s in chosen if s["kind"] == "world"}
                if self.filter_servers - actual_s or self.filter_worlds - actual_w:
                    raise CaptureError("Selected scope is absent from official inventory")
                self.report["all_official_scopes"] = [f'{s["kind"]}:{s["id"]}' for s in all_scopes]
                self.report["expected_scopes"] = [f'{s["kind"]}:{s["id"]}' for s in chosen]
                self.report["scope_selection_is_all"] = len(chosen) == len(all_scopes)
                for scope in chosen:
                    self.report["current_scope"] = f'{scope["kind"]}:{scope["id"]}'
                    rows, _, _ = self.catalog(scope, tree)
                    local = self.selected_rows(rows, scope)
                    self.report["catalog_groups"] += len(local)
                    self.report["stock_queue_size"] = len(local)
                    for index, row in enumerate(local):
                        self.report["stock_queue_position"] = index
                        self.report["current_stock"] = list(item_key(row))
                        self.stock(row)
                        self.report["stock_queue_position"] = index + 1
                    self.report["completed_scopes"].append(f'{scope["kind"]}:{scope["id"]}')
                self.report["traversal_complete"] = True
                self.report["status"] = "traversed_unverified"
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
    parser.add_argument("--server-id", type=probe.positive, action="append", default=[])
    parser.add_argument("--world-id", type=probe.positive, action="append", default=[])
    args = parser.parse_args(argv)
    try:
        code, report = Collector(args.output, args.max_requests, args.delay,
                                 server_ids=args.server_id, world_ids=args.world_id).run()
    except (CaptureError, OSError) as exc:
        print("STOPPED:", exc, flush=True)
        return 1
    print(json.dumps({k: v for k, v in report.items() if k != "stock_receipts"},
                     ensure_ascii=False, indent=2), flush=True)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
