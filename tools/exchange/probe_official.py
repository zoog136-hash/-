#!/usr/bin/env python3
"""Bounded, unauthenticated official market probes. Never a complete snapshot."""
import argparse
import hashlib
import json
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import HTTPRedirectHandler, Request, build_opener

BASE = "https://api-goats.plaync.com/lms/v2.0"
SCOPE = "partial_probe_only_not_a_production_snapshot"


class ProbeError(RuntimeError):
    pass


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ProbeError("Redirect refused: only the explicit official endpoint is allowed")


def utc_now():
    return datetime.now(timezone.utc).isoformat()


def positive(value):
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("must be positive")
    return number


def nonnegative(value):
    number = int(value)
    if number < 0:
        raise argparse.ArgumentTypeError("must be nonnegative")
    return number


def urls_for(args):
    """Construct only documented, explicitly allowlisted paths and query keys."""
    if args.pages > args.max_requests:
        raise ProbeError("pages must not exceed max-requests")
    if args.kind in ("servers", "worlds"):
        if args.pages != 1 or args.page != 1 or any(v is not None for v in
                (args.server_id, args.item_id, args.enchant_level, args.blessed_type)):
            raise ProbeError("servers/worlds accept no item, server or pagination filters")
        return [BASE + ("/game/server" if args.kind == "servers" else "/game/market/world")]
    if args.kind == "catalog":
        if any(v is not None for v in (args.item_id, args.enchant_level)):
            raise ProbeError("catalog does not accept item-id or enchant-level")
        path = "/price/search/item"
        params = {"size": 30, "sale": "true"}
        if args.server_id is not None:
            params["serverId"] = args.server_id
        if args.blessed_type is not None:
            params["blessedType"] = args.blessed_type
    else:
        if any(v is None for v in (args.item_id, args.server_id, args.enchant_level)):
            raise ProbeError("stock requires item-id, server-id and enchant-level")
        path = f"/price/search/item/{args.item_id}/stock"
        params = {"serverId": args.server_id, "enchantLevel": args.enchant_level,
                  "blessedType": args.blessed_type or 0, "size": 10}
    return [BASE + path + "?" + urlencode({**params, "page": page})
            for page in range(args.page, args.page + args.pages)]


def exclusive_write(path, data):
    with path.open("xb") as output:
        output.write(data)


def probe(url, output, opener):
    """Persist a response unchanged; reuse only a verified successful receipt."""
    key = hashlib.sha256(url.encode()).hexdigest()
    body_path = output / (key + ".json")
    receipt_path = output / (key + ".receipt.json")
    if receipt_path.exists():
        try:
            receipt = json.loads(receipt_path.read_bytes())
            body = body_path.read_bytes()
            if (receipt["url"] != url or receipt["scope"] != SCOPE or
                    receipt["http_status"] != 200 or receipt["valid_json"] is not True or
                    hashlib.sha256(body).hexdigest() != receipt["sha256"]):
                raise ProbeError("Existing response/receipt failed validation")
            json.loads(body)
        except (OSError, ValueError, KeyError, TypeError) as exc:
            raise ProbeError("Existing response/receipt is incomplete or invalid") from exc
        return "reused"
    # Refuse incomplete/racing writes. Do not overwrite or silently repair them.
    if body_path.exists():
        raise ProbeError("Orphan response exists without receipt; use a new output directory")
    started = utc_now()
    try:
        response = opener.open(Request(url, headers={"Accept": "application/json",
                                                     "User-Agent": "TWILIGHT-bounded-market-probe/1.0"}), timeout=30)
    except HTTPError as exc:
        response = exc  # Preserve error evidence, then stop without retrying.
    with response:
        body = response.read()
        status = response.code
        response_date = response.headers.get("Date")
        completed = utc_now()
    try:
        json.loads(body)
        valid_json = True
    except (ValueError, UnicodeDecodeError):
        valid_json = False
    receipt = {"scope": SCOPE, "url": url, "request_started_at_utc": started,
               "request_completed_at_utc": completed, "http_date": response_date,
               "http_status": status, "valid_json": valid_json,
               "sha256": hashlib.sha256(body).hexdigest(), "body_file": body_path.name}
    exclusive_write(body_path, body)
    exclusive_write(receipt_path, (json.dumps(receipt, indent=2) + "\n").encode())
    if status != 200 or not valid_json:
        raise ProbeError(f"Stopped on HTTP {status}, valid_json={valid_json}; evidence saved, no retries")
    return "captured"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kind", required=True, choices=("servers", "worlds", "catalog", "stock"))
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--server-id", type=positive)
    parser.add_argument("--item-id", type=positive)
    parser.add_argument("--enchant-level", type=nonnegative)
    parser.add_argument("--blessed-type", type=nonnegative)
    parser.add_argument("--page", type=positive, default=1)
    parser.add_argument("--pages", type=positive, default=1)
    parser.add_argument("--max-requests", type=positive, default=10)
    parser.add_argument("--delay", type=float, default=1.0)
    args = parser.parse_args(argv)
    try:
        if not 1.0 <= args.delay <= 3600:
            raise ProbeError("delay must be between 1 and 3600 seconds")
        urls = urls_for(args)
        args.output.mkdir(parents=True, exist_ok=True)
        opener = build_opener(NoRedirect())  # No cookies, account credentials or auth handlers.
        for index, url in enumerate(urls):
            if index:
                time.sleep(args.delay)
            print(probe(url, args.output, opener), url, flush=True)
        print(SCOPE + ": no coverage or atomic snapshot claim; no production import performed")
        return 0
    except (ProbeError, OSError, ValueError) as exc:
        print("STOPPED:", str(exc), flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
