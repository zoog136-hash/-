#!/usr/bin/env python3
"""Build a frozen representative snapshot from verified, observed responses only.

No network requests, prices, quantities or original item definitions are generated.
Live observations are approximate; an observation ID is never a verified listing ID.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import tempfile
from urllib.parse import parse_qs, urlencode, urlsplit, urlunsplit
import zipfile

DEFINITION_SHA = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
BASE_PATH = "/lms/v2.0"
MAX_INTEGER = 9007199254740991
STOCK_PATH = re.compile(r"^/lms/v2\.0/price/search/item/([1-9][0-9]*)/stock$")
KNOWN_STOCK_FIELDS = {"itemId", "itemName", "serverId", "enchantLevel", "image",
                      "salePrice", "grade", "quantity", "world", "blessingLevel"}


class BuildError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise BuildError(message)


def integer(value, minimum=0, maximum=MAX_INTEGER):
    return (type(value) in (int, float) and minimum <= value <= maximum
            and math.isfinite(value) and int(value) == value)


def stamp(value):
    require(isinstance(value, str), "Receipt has no request timestamp")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise BuildError("Invalid receipt timestamp") from exc
    require(parsed.tzinfo is not None, "Receipt timestamp has no timezone")
    return parsed.astimezone(timezone.utc)


def official_url(url):
    require(isinstance(url, str), "Missing official URL")
    parsed = urlsplit(url)
    require(parsed.scheme == "https" and parsed.netloc == "api-goats.plaync.com"
            and parsed.path.startswith(BASE_PATH + "/") and not parsed.fragment,
            "Unapproved official response URL")
    query = parse_qs(parsed.query, keep_blank_values=True)
    require(all(len(values) == 1 for values in query.values()), "Ambiguous query parameters")
    return parsed, {key: values[0] for key, values in query.items()}


def normalized_url(url):
    parsed, query = official_url(url)
    return urlunsplit((parsed.scheme, parsed.netloc, parsed.path,
                       urlencode(sorted(query.items())), ""))


def receipt_records(directories, unusable=None):
    """Reject tampering, unsuccessful responses and receipts pointing outside their directory."""
    records = []
    seen_paths = set()
    for directory in directories:
        for path in sorted(Path(directory).rglob("*.receipt.json")):
            path = path.resolve()
            if path in seen_paths:
                continue
            seen_paths.add(path)
            receipt = json.loads(path.read_bytes())
            official_url(receipt.get("url"))
            name = receipt.get("body_file", path.name.replace(".receipt.json", ".json"))
            require(isinstance(name, str) and Path(name).name == name,
                    "Receipt body_file must be a basename")
            body_path = path.parent / name
            raw = body_path.read_bytes()
            digest = hashlib.sha256(raw).hexdigest()
            require(digest == receipt.get("sha256"), "Response/receipt SHA-256 mismatch")
            start = stamp(receipt.get("request_started_at_utc", receipt.get("started_at_utc")))
            end = stamp(receipt.get("request_completed_at_utc", receipt.get("completed_at_utc")))
            require(start <= end, "Receipt timestamp order is invalid")
            if receipt.get("http_status") != 200 or receipt.get("valid_json", True) is not True:
                if unusable is not None:
                    unusable.append({"url": receipt["url"], "sha256": digest,
                                     "http_status": receipt.get("http_status"),
                                     "reason": "unsuccessful_response_not_used_as_market_data"})
                continue
            records.append({"url": receipt["url"], "key": normalized_url(receipt["url"]),
                            "sha256": digest, "data": json.loads(raw), "receipt": receipt,
                            "receipt_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                            "path": path, "body_file": name, "start": start, "end": end})
    require(records, "No verified observation receipts found")
    return sorted(records, key=lambda record: (record["start"], str(record["path"])))


def original_names(path, expected_sha=DEFINITION_SHA):
    raw = Path(path).read_bytes()
    require(hashlib.sha256(raw).hexdigest() == expected_sha, "Original definition ZIP SHA-256 mismatch")
    with zipfile.ZipFile(path) as archive:
        require(archive.testzip() is None, "Original definition ZIP CRC failure")
        items = json.loads(archive.read("content/ItemClass.json"))["rows"]
        labels = json.loads(archive.read("content/DescData_Korean.json"))["rows"]
    require(isinstance(items, list) and isinstance(labels, list), "Original definition table shape error")
    descriptions = {int(row["ID"]): row["Description"] for row in labels
                    if integer(row.get("ID"), 1) and isinstance(row.get("Description"), str)}
    result = {}
    for row in items:
        if integer(row.get("ID"), 1) and row.get("TestItem") is False:
            label = descriptions.get(row.get("DescID"))
            if isinstance(label, str) and label.strip():
                require(int(row["ID"]) not in result, "Duplicate original ItemClass ID")
                result[int(row["ID"])] = label.strip()
    return result


def inventory(records):
    observed = next((r for r in records if urlsplit(r["url"]).path == BASE_PATH + "/game/server"), None)
    require(observed is not None and isinstance(observed["data"], list), "Official server inventory is required")
    servers = {}
    for world in observed["data"]:
        require(integer(world.get("worldId"), 1) and isinstance(world.get("servers"), list),
                "Invalid official server inventory")
        for server in world["servers"]:
            sid = server.get("serverId")
            require(integer(sid, 1) and int(sid) not in servers, "Duplicate/invalid official server ID")
            servers[int(sid)] = {"world_id": int(world["worldId"]),
                                 "server_name": server.get("serverName"),
                                 "world_name": world.get("worldName")}
    return observed, servers


def catalog_key(row):
    require(isinstance(row, dict) and integer(row.get("serverId"), 1)
            and integer(row.get("itemId"), 1) and integer(row.get("enchantLevel"), 0, 255)
            and type(row.get("world")) is bool, "Invalid observed item identity")
    return int(row["serverId"]), int(row["itemId"]), int(row["enchantLevel"]), row["world"]


def survey_coverage(path, records, selected_server_id=None):
    source = json.loads(Path(path).read_bytes())
    ranking = source.get("ranking")
    require(isinstance(ranking, list) and ranking, "Survey ranking is required")
    by_file = defaultdict(list)
    for record in records:
        by_file[record["body_file"]].append(record)
    candidates = []
    seen = set()
    for item in ranking:
        sid, wid = item.get("server_id"), item.get("world_id")
        require(integer(sid, 1) and integer(wid, 1) and int(sid) not in seen,
                "Survey has invalid/duplicate candidate IDs")
        seen.add(int(sid))
        local_records = by_file.get(item.get("combined_response_body"), [])
        world_records = by_file.get(item.get("shared_world_response_body"), [])
        require(local_records and world_records, "Survey response evidence is missing")
        local, world = local_records[0], world_records[0]
        for record, scope_id in [(local, sid), (world, wid)]:
            parsed, query = official_url(record["url"])
            require(parsed.path == BASE_PATH + "/price/search/item"
                    and query.get("serverId") == str(int(scope_id)) and query.get("page") == "1"
                    and query.get("sale") == "true" and set(query) <= {"serverId", "sale", "size", "page"},
                    "Survey URL must be the candidate's unfiltered first catalog page")
        total = local["data"].get("pagination", {}).get("total")
        shared = world["data"].get("pagination", {}).get("total")
        require(integer(total) and integer(shared), "Invalid survey response totals")
        # A negative difference is an observed temporal inconsistency, not a candidate score.
        if total < shared:
            continue
        require(item.get("combined_catalog_group_total") == total
                and item.get("shared_world_catalog_group_total") == shared
                and item.get("derived_local_catalog_group_count_proxy") == total - shared,
                "Survey summary differs from its original response totals")
        candidates.append({"server_id": f"server:{int(sid)}", "world_id": f"world:{int(wid)}",
                           "reported_total": int(total), "world_reported_total": int(shared),
                           "local_group_count": int(total - shared),
                           "evidence_url": local["url"], "sha256": local["sha256"],
                           "world_evidence_url": world["url"], "world_sha256": world["sha256"]})
    require(candidates, "Survey has no valid nonnegative candidate")
    chosen = max(candidates, key=lambda candidate: candidate["local_group_count"])
    if selected_server_id is not None:
        chosen = next((candidate for candidate in candidates
                       if candidate["server_id"] == f"server:{selected_server_id}"), None)
        require(chosen is not None and chosen["local_group_count"] == max(c["local_group_count"] for c in candidates),
                "Requested representative is not a maximum surveyed local-group proxy")
    return {"scope": "surveyed_candidates_only", "metric": "reported_local_catalog_group_count",
            "selected_server_id": chosen["server_id"], "candidates": candidates}, chosen


def load_categories(records):
    observed = next((record for record in records
                     if urlsplit(record["url"]).path == BASE_PATH + "/game/market/category"), None)
    require(observed and isinstance(observed["data"], list), "Official category inventory is required")
    result = {}
    for row in observed["data"]:
        value = row.get("id")
        require(str(value).isascii() and str(value).isdigit() and int(value) > 0
                and int(value) not in result and isinstance(row.get("name"), str) and row["name"].strip(),
                "Invalid official category inventory")
        result[int(value)] = row["name"]
    return result


def build_snapshot(capture_dirs, survey_path, definitions, *, category_ids=(), selected_server_id=None,
                   expected_definition_sha=DEFINITION_SHA):
    capture_dirs = [Path(path) for path in capture_dirs]
    # Include survey receipts for ranking verification, not as sale-row inputs.
    unusable = []
    records = receipt_records([*capture_dirs, Path(survey_path).parent], unusable)
    survey, chosen = survey_coverage(survey_path, records, selected_server_id)
    proof, servers = inventory(records)
    sid = int(chosen["server_id"].split(":")[1])
    wid = int(chosen["world_id"].split(":")[1])
    require(sid in servers and servers[sid]["world_id"] == wid, "Survey world differs from official server inventory")
    categories = load_categories(records)
    names = original_names(definitions, expected_definition_sha)
    capture_records = [r for r in records if any(r["path"].is_relative_to(path.resolve()) for path in capture_dirs)]
    group_categories = defaultdict(set)
    requested = set(category_ids)
    progresses = []
    explicit_categories = bool(category_ids)
    for directory in capture_dirs:
        progress_path = directory / "progress.json"
        if not progress_path.exists():
            continue
        progress = json.loads(progress_path.read_bytes()); progresses.append(progress)
        if not explicit_categories:
            requested.update(progress.get("selection", {}).get("selected_category1_ids", []))
        for group in progress.get("stock_receipts", []):
            key = (group.get("server_id"), group.get("item_id"), group.get("enchant"), group.get("world"))
            group_categories[key].update(group.get("category1_ids", []))
    for record in capture_records:
        parsed, query = official_url(record["url"])
        if parsed.path == BASE_PATH + "/price/search/item" and "category1" in query:
            require(query["category1"].isdigit() and int(query["category1"]) in categories,
                    "Catalog category is not in official inventory")
            category = int(query["category1"])
            for row in record["data"].get("contents", []):
                group_categories[catalog_key(row)].add(category)
    if not requested:
        requested = {value for values in group_categories.values() for value in values}
    require(requested and all(type(value) is int and value in categories for value in requested),
            "Selected categories must come from official observed filters")
    selected = sorted(requested)
    allowed = {(sid, False), (wid, True)}
    report = {"scope": "representative_observed_frozen_snapshot", "atomic_snapshot_verified": False,
              "distinct_listings_verified": False, "coverage_complete": False,
              "selected_server_id": chosen["server_id"], "selected_world_id": chosen["world_id"],
              "input_receipts": len(capture_records), "excluded_response_receipts": unusable,
              "observed_stock_rows": 0,
              "included_rows": 0, "omitted_rows": [], "duplicate_response_references": 0,
              "later_response_versions_ignored": [], "equal_value_rows_preserved": 0,
              "limits": ["The selected server maximizes a sampled catalog-group proxy, not a proved all-server listing census.",
                         "Live page positions may overlap or omit registrations; observation IDs are not verified listing IDs.",
                         "Identical stock rows are preserved; no value-based listing deduplication is performed."]}
    pagination_history = {}
    raw_drift_events = []
    for record in capture_records:
        parsed, query = official_url(record["url"])
        if parsed.path != BASE_PATH + "/price/search/item" and not STOCK_PATH.fullmatch(parsed.path):
            continue
        pagination = record["data"].get("pagination", {})
        if not all(integer(pagination.get(field)) for field in ("total", "size", "lastPage", "limit")):
            continue
        group_url = urlunsplit((parsed.scheme, parsed.netloc, parsed.path,
                               urlencode(sorted((k, v) for k, v in query.items() if k != "page")), ""))
        current = {field: pagination[field] for field in ("total", "size", "lastPage", "limit")}
        previous = pagination_history.get(group_url)
        if previous is not None and previous != current:
            raw_drift_events.append({"url": record["url"], "sha256": record["sha256"],
                                     "previous": previous, "current": current})
        pagination_history[group_url] = current
    report["observed_pagination_drift_events"] = raw_drift_events
    report["stock_page_sampling_events"] = [event for progress in progresses
                                           for event in progress.get("stock_page_sampling_events", [])]
    first_response = {}
    listings, windows, fingerprints = [], [], Counter()
    for record in capture_records:
        parsed, query = official_url(record["url"])
        match = STOCK_PATH.fullmatch(parsed.path)
        if not match:
            continue
        require(set(query) <= {"serverId", "enchantLevel", "blessedType", "size", "page"}
                and all(query.get(k, "").isdigit() for k in ("serverId", "enchantLevel", "blessedType", "size", "page")),
                "Invalid stock query identity")
        identity = (int(query["serverId"]), int(match[1]), int(query["enchantLevel"]))
        require(int(query["page"]) > 0 and int(query["size"]) > 0 and int(query["blessedType"]) in range(4),
                "Invalid stock query numbers")
        previous = first_response.get(record["key"])
        if previous:
            if previous["sha256"] == record["sha256"]:
                report["duplicate_response_references"] += 1
            else:
                report["later_response_versions_ignored"].append({"url": record["url"], "sha256": record["sha256"],
                                                                  "first_sha256": previous["sha256"]})
            continue
        first_response[record["key"]] = record
        rows = record["data"].get("contents")
        require(isinstance(rows, list), "Stock response has no row array")
        pagination = record["data"].get("pagination", {})
        require(all(integer(pagination.get(field)) for field in ("page", "size", "lastPage", "total", "limit"))
                and pagination["page"] == int(query["page"]) and 1 <= pagination["size"] <= 10
                and pagination["limit"] > 0, "Invalid stock pagination identity")
        accessible = min(int(pagination["total"]), int(pagination["limit"]))
        expected_pages = math.ceil(accessible / pagination["size"])
        require(pagination["lastPage"] == expected_pages or
                (accessible == 0 and pagination["lastPage"] == 1), "Invalid stock last page")
        expected_rows = min(pagination["size"], max(0, accessible -
                            (pagination["page"] - 1) * pagination["size"]))
        require(len(rows) == expected_rows, "Stock row count differs from its observed page")
        for index, row in enumerate(rows):
            report["observed_stock_rows"] += 1
            key = catalog_key(row)
            require(key[:3] == identity, "Stock row identity differs from request")
            omission = {"url": record["url"], "sha256": record["sha256"], "row_index": index,
                        "item_id": key[1], "observed_item_name": row.get("itemName")}
            if (key[0], key[3]) not in allowed:
                report["omitted_rows"].append({**omission, "reason": "outside_selected_market"}); continue
            category_set = group_categories.get(key, set()).intersection(requested)
            if not category_set:
                report["omitted_rows"].append({**omission, "reason": "category_not_proven_by_observation"}); continue
            canonical = names.get(key[1])
            expected_name = (f"+{key[2]} " if key[2] else "") + (canonical or "")
            if not canonical or row.get("itemName") != expected_name:
                report["omitted_rows"].append({**omission, "reason": "original_id_label_or_exact_enchant_prefix_unmatched"}); continue
            if not integer(row.get("quantity"), 1) or not integer(row.get("salePrice"), 1):
                report["omitted_rows"].append({**omission, "reason": "nonpositive_or_noninteger_observed_bundle"}); continue
            attributes = {"blessed_type": int(query["blessedType"])}
            if attributes["blessed_type"] == 0:
                attributes = {"unverified_blessed_type_filter": 0}
            if not integer(row.get("blessingLevel")) or row.get("blessingLevel") != 0:
                attributes["api_blessing_level"] = row.get("blessingLevel")
            unknown = {k: value for k, value in row.items() if k not in KNOWN_STOCK_FIELDS}
            if unknown:
                attributes["unmapped_api_fields"] = unknown
            observation_id = hashlib.sha256((record["key"] + "\n" + record["sha256"] + "\n" + str(index)).encode()).hexdigest()
            listings.append({"server_id": f"{'world' if key[3] else 'server'}:{key[0]}",
                             "listing_id": "observation:" + observation_id,
                             "item_class_id": key[1], "item_name": canonical,
                             "observed_item_name": row["itemName"],
                             "bundle_size": int(row["quantity"]), "bundle_price": int(row["salePrice"]),
                             "initial_bundles": 1, "currency_unit_id": 34, "currency_class_id": 2,
                             "enchant": key[2], "element": "", "element_level": 0,
                             "attributes": attributes, "evidence_url": record["url"],
                             "category1_ids": sorted(category_set),
                             "observation": {"body_file": record["body_file"], "receipt_file": record["path"].name,
                                             "body_sha256": record["sha256"], "receipt_sha256": record["receipt_sha256"],
                                             "row_index": index, "listing_identity_verified": False,
                                             "request_started_at_utc": record["start"].isoformat(),
                                             "request_completed_at_utc": record["end"].isoformat(),
                                             "raw_row": row}})
            windows.append(record)
            fingerprints[json.dumps(row, sort_keys=True, ensure_ascii=False)] += 1
    require(listings, "No observed rows have verified source identity and selected category provenance")
    report["included_rows"] = len(listings)
    report["equal_value_rows_preserved"] = sum(n - 1 for n in fingerprints.values())
    report["category_observed_rows"] = {str(c): sum(c in row["category1_ids"] for row in listings) for c in selected}
    start = min(record["start"] for record in windows); end = max(record["end"] for record in windows)
    drift = (bool(raw_drift_events or report["later_response_versions_ignored"])
             or any(p.get("drift_events") or p.get("possible_overlap_events") for p in progresses))
    coverage = {"scope": "representative_server", "expected_server_ids": [chosen["server_id"]],
                "completed_server_ids": [chosen["server_id"]], "complete": False, "approximate": True,
                "selected_categories": [{"id": c, "name": categories[c]} for c in selected],
                "omitted_categories": [{"id": c, "name": categories[c]} for c in sorted(set(categories) - requested)],
                "live_drift_recorded": bool(drift), "survey": survey,
                "scope_proof": {"server_id": chosen["server_id"], "world_id": chosen["world_id"],
                                "evidence_url": proof["url"], "sha256": proof["sha256"]}}
    for field in ("server_name", "world_name"):
        if isinstance(servers[sid].get(field), str): coverage[field] = servers[sid][field]
    snapshot = {"schema": "twilight.frozen-exchange.v1", "status": "captured", "test_fixture": False,
                "captured_at": end.strftime("%Y-%m-%dT%H:%M:%SZ"),
                "source_url": "https://lineagem.plaync.com/price/itemprice/index", "coverage": coverage,
                "source_collection_window": {"started_at_utc": start.isoformat(), "completed_at_utc": end.isoformat(),
                                             "atomic_snapshot_verified": False},
                "price_policy": "frozen_once", "reset": {"timezone": "Asia/Seoul", "hour": 5},
                "collection_quality": {"atomic_snapshot_verified": False,
                                       "distinct_listings_verified": False,
                                       "stock_page_sampling_recorded": bool(report["stock_page_sampling_events"]),
                                       "exact_omission_count_verified": False},
                "listing_id_policy": "observed_response_url_body_sha256_row_index_not_verified_listing_id",
                "listings": listings}
    module_path = Path(__file__).with_name("import_snapshot.py")
    spec = importlib.util.spec_from_file_location("representative_snapshot_validator", module_path)
    validator = importlib.util.module_from_spec(spec);spec.loader.exec_module(validator)
    validator.validate(snapshot)
    return snapshot, report


def write_new(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    require(not path.exists(), "Refusing to overwrite existing output")
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
            temporary = Path(stream.name)
            stream.write((json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode())
            stream.flush();os.fsync(stream.fileno())
        os.link(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture-dir", type=Path, action="append", required=True)
    parser.add_argument("--survey", type=Path, required=True)
    parser.add_argument("--definitions", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--category1", type=int, action="append", default=[])
    parser.add_argument("--server-id", type=int)
    args = parser.parse_args(argv)
    report_path = args.report or args.output.with_suffix(args.output.suffix + ".report.json")
    try:
        require(not args.output.exists() and not report_path.exists(), "Refusing to overwrite an existing snapshot or report")
        snapshot, report = build_snapshot(args.capture_dir, args.survey, args.definitions,
                                          category_ids=args.category1, selected_server_id=args.server_id)
        write_new(args.output, snapshot);write_new(report_path, report)
        print(json.dumps({"snapshot": str(args.output), "report": str(report_path),
                          "representative": report["selected_server_id"], "observed_rows": report["included_rows"],
                          "coverage_complete": False}, ensure_ascii=False))
        return 0
    except (BuildError, OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile) as exc:
        print("STOPPED:", exc)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
