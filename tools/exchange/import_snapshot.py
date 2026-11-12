#!/usr/bin/env python3
"""Validate and install a one-time exchange snapshot, without fetching market data.

This validates the supplied evidence contract, not the truth of its completeness
claim. A static client table is not evidence of currently registered listings.
No prices, bundle sizes, server coverage, or source observations are invented.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import tempfile
from urllib.parse import urlsplit

SCHEMA = "twilight.frozen-exchange.v1"
MAX_INTEGER = 9007199254740991


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def _text(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _integer(value: object, low: int = 1, high: int = MAX_INTEGER) -> bool:
    return type(value) is int and low <= value <= high


def _https(value: object) -> bool:
    if not _text(value) or any(c.isspace() for c in value):
        return False
    try:
        url = urlsplit(value)
        return url.scheme == "https" and bool(url.hostname) and not url.username and not url.password
    except ValueError:
        return False


def _servers(value: object, name: str) -> list[str]:
    _require(isinstance(value, list), f"{name} must be an array")
    _require(all(_text(item) for item in value), f"{name} must contain nonempty strings")
    _require(len(value) == len(set(value)), f"{name} contains duplicate servers")
    return value


def validate(snapshot: object) -> dict:
    """Return the unmodified validated snapshot or raise ValueError.

    Timestamps use canonical UTC seconds so Python and Godot use the same
    contract. Convert source timestamps before supplying this file; retain any
    original timestamp as an additional evidence field when appropriate.
    """
    _require(isinstance(snapshot, dict), "snapshot must be an object")
    try:
        json.dumps(snapshot, ensure_ascii=False, allow_nan=False)
    except (TypeError, ValueError) as exc:
        raise ValueError("snapshot must contain finite JSON data") from exc
    _require(snapshot.get("schema") == SCHEMA, "unsupported snapshot schema")
    _require(snapshot.get("status") in ("captured", "not_captured"), "invalid capture status")
    _require(snapshot.get("price_policy") == "frozen_once", "prices must remain frozen_once")
    reset = snapshot.get("reset")
    _require(isinstance(reset, dict) and reset.get("timezone") == "Asia/Seoul"
             and type(reset.get("hour")) is int and reset["hour"] == 5,
             "reset must be 05:00 Asia/Seoul")
    _require(_https(snapshot.get("source_url")), "source_url must be HTTPS")
    coverage = snapshot.get("coverage")
    _require(isinstance(coverage, dict) and coverage.get("scope") == "all_servers",
             "coverage scope must be all_servers")
    expected = _servers(coverage.get("expected_server_ids"), "expected_server_ids")
    completed = _servers(coverage.get("completed_server_ids"), "completed_server_ids")
    _require(type(coverage.get("complete")) is bool, "coverage complete must be boolean")
    listings = snapshot.get("listings")
    _require(isinstance(listings, list), "listings must be an array")
    _require("captured_at" in snapshot, "captured_at is required")
    if snapshot["status"] == "not_captured":
        _require(snapshot["captured_at"] is None and not expected and not completed
                 and coverage["complete"] is False and not listings,
                 "not_captured must have no timestamp, coverage, or listings")
        return snapshot
    _require(bool(expected) and set(expected) == set(completed) and coverage["complete"],
             "captured requires complete all-server coverage")
    timestamp = snapshot["captured_at"]
    _require(isinstance(timestamp, str), "captured_at must be canonical UTC YYYY-MM-DDTHH:MM:SSZ")
    try:
        parsed = datetime.strptime(timestamp, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
        _require(parsed.strftime("%Y-%m-%dT%H:%M:%SZ") == timestamp,
                 "captured_at must be canonical UTC YYYY-MM-DDTHH:MM:SSZ")
    except ValueError as exc:
        raise ValueError("captured_at must be canonical UTC YYYY-MM-DDTHH:MM:SSZ") from exc
    known = set(expected)
    seen = set()
    for index, row in enumerate(listings):
        prefix = f"listings[{index}]"
        _require(isinstance(row, dict), f"{prefix} must be an object")
        _require(_text(row.get("server_id")) and row["server_id"] in known,
                 f"{prefix} server_id not in captured coverage")
        _require(_text(row.get("listing_id")), f"{prefix} listing_id is required")
        key = (row["server_id"], row["listing_id"])
        _require(key not in seen, f"{prefix} duplicate listing within server")
        seen.add(key)
        _require(_text(row.get("item_name")), f"{prefix} item_name is required")
        for field in ("item_class_id", "bundle_size", "bundle_price", "initial_bundles"):
            _require(_integer(row.get(field)), f"{prefix} {field} must be a positive exact integer")
        for field, expected_value in (("currency_unit_id", 34), ("currency_class_id", 2)):
            _require(type(row.get(field)) is int and row[field] == expected_value,
                     f"{prefix} {field} must be {expected_value}")
        for field in ("enchant", "element_level"):
            _require(_integer(row.get(field), 0, 255), f"{prefix} {field} must be an integer from 0 to 255")
        _require(isinstance(row.get("element"), str), f"{prefix} element must be a string")
        _require(isinstance(row.get("attributes"), dict), f"{prefix} attributes must be an object")
        _require(_https(row.get("evidence_url")), f"{prefix} evidence_url must be HTTPS")
        for field in ("bundle_size", "bundle_price"):
            _require(row[field] * row["initial_bundles"] <= MAX_INTEGER,
                     f"{prefix} {field} total exceeds exact integer range")
    return snapshot


def _unique_object(pairs: list[tuple[str, object]]) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load_snapshot(path: Path) -> dict:
    with Path(path).open("r", encoding="utf-8") as handle:
        return validate(json.load(handle, object_pairs_hook=_unique_object))


def import_snapshot(source: Path, destination: Path) -> dict:
    """Atomically publish a validated new file; never replace a frozen snapshot.

    A same-directory temporary file is fsynced, then linked exclusively into
    place. Unlike an existence check followed by os.replace, this remains
    no-clobber if another importer publishes at the same time.
    """
    snapshot = load_snapshot(source)
    destination = Path(destination)
    if destination.exists() or destination.is_symlink():
        raise FileExistsError(f"frozen snapshot already exists: {destination}")
    payload = (json.dumps(snapshot, ensure_ascii=False, allow_nan=False, indent=2) + "\n").encode("utf-8")
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=destination.parent, prefix=".exchange-", suffix=".tmp", delete=False) as handle:
            temporary = Path(handle.name)
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.link(temporary, destination)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    return snapshot


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    if args.validate_only and args.output is not None:
        parser.error("--validate-only does not take an output")
    if not args.validate_only and args.output is None:
        parser.error("output is required unless --validate-only is used")
    try:
        snapshot = load_snapshot(args.input) if args.validate_only else import_snapshot(args.input, args.output)
    except (OSError, ValueError) as exc:
        parser.exit(1, f"Snapshot rejected: {exc}\n")
    print(f"Validated {snapshot['status']}: {len(snapshot['listings'])} listings; evidence truth not independently verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
