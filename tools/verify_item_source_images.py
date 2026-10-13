#!/usr/bin/env python3
"""Compare existing catalog PNG bytes to their recorded source URLs, without importing art.

The output is evidence, never a redistribution licence or an automatic DB patch.
Only the two recorded Inven hosts are fetched. No downloaded image is retained.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import html
import json
import re
from pathlib import Path
import ssl
import urllib.parse
import urllib.request


def fetch(url: str, expected_host: str) -> bytes:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or parsed.hostname != expected_host:
        raise ValueError("unexpected source host or scheme")
    request = urllib.request.Request(url, headers={"User-Agent": "TWILIGHT-resource-audit/1.0"})
    with urllib.request.urlopen(request, timeout=20, context=ssl.create_default_context()) as response:
        if urllib.parse.urlparse(response.url).hostname != expected_host:
            raise ValueError("unexpected redirect host")
        data = response.read(2_000_001)
        if len(data) > 2_000_000:
            raise ValueError("source exceeds 2 MB audit limit")
        return data


def verify_image(job: tuple[str, list[dict], Path]) -> tuple[str, dict]:
    url, records, root = job
    try:
        remote = fetch(url, "static.inven.co.kr")
        digest = hashlib.sha256(remote).hexdigest()
        matches = {}
        for record in records:
            local = root / record["image_path"].removeprefix("res://")
            matches[str(record["sourceId"])] = local.is_file() and hashlib.sha256(local.read_bytes()).hexdigest() == digest
        return url, {"sha256": digest, "bytes": len(remote), "id_byte_matches": matches}
    except Exception as exc:
        return url, {"error": str(exc)}


def verify_record(record: dict) -> tuple[str, dict]:
    source_id = str(record["sourceId"])
    url = record["sourceUrl"]
    if urllib.parse.urlparse(url).path.rstrip("/") != "/db/item/" + source_id:
        return source_id, {"error": "sourceId does not match detail URL"}
    try:
        page = fetch(url, "lineagem.inven.co.kr").decode("utf-8", errors="replace")
        match = re.search(r'id="lineagemDbItem"\s+data-props="([^"]+)"', page)
        if not match:
            raise ValueError("item detail data-props missing; no generic page-text matching")
        props = json.loads(html.unescape(match[1]))
        item = props.get("item", {})
        return source_id, {"url": url, "verification": "structured_item_identity_v3",
                           "exact_id_found": str(item.get("code", "")) == source_id,
                           "exact_name_found": item.get("name") == record["name"],
                           "exact_image_found": item.get("icon") == record["sourceImageUrl"],
                           "page_sha256": hashlib.sha256(page.encode()).hexdigest()}
    except Exception as exc:
        return source_id, {"url": url, "error": str(exc)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--workers", type=int, default=6)
    parser.add_argument("--images-only", action="store_true")
    args = parser.parse_args()
    records = json.loads((args.root / "data/catalog_v19.json").read_text())["아이템"]
    groups: dict[str, list[dict]] = {}
    for record in records:
        groups.setdefault(record["sourceImageUrl"], []).append(record)
    report = {"schema": 1, "checked_date": "2026-10-12", "rights": "not_established_by_this_check",
              "images": {}, "records": {}, "catalog_rows": len(records)}
    if args.output.exists():
        previous = json.loads(args.output.read_text())
        report["images"] = previous.get("images", {})
        report["records"] = previous.get("records", {})
    args.output.parent.mkdir(parents=True, exist_ok=True)

    def save() -> None:
        temp = args.output.with_suffix(".tmp")
        temp.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
        temp.replace(args.output)

    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, min(8, args.workers))) as pool:
        jobs = [pool.submit(verify_image, (url, rows, args.root)) for url, rows in groups.items()
                if url not in report["images"]]
        for i, job in enumerate(concurrent.futures.as_completed(jobs), 1):
            url, result = job.result()
            report["images"][url] = result
            if i % 50 == 0:
                save()
                print(f"SOURCE_IMAGE_PROGRESS {len(report['images'])}/{len(groups)}", flush=True)
        save()
        if not args.images_only:
            jobs = [pool.submit(verify_record, record) for record in records
                    if report["records"].get(str(record["sourceId"]), {}).get("verification") != "structured_item_identity_v3"]
            for i, job in enumerate(concurrent.futures.as_completed(jobs), 1):
                source_id, result = job.result()
                report["records"][source_id] = result
                if i % 50 == 0:
                    save()
                    print(f"SOURCE_RECORD_PROGRESS {len(report['records'])}/{len(records)}", flush=True)
    report["summary"] = {
        "image_urls": len(groups), "fetched_images": len(report["images"]),
        "image_errors": sum("error" in v for v in report["images"].values()),
        "byte_matched_rows": sum(sum(v.get("id_byte_matches", {}).values()) for v in report["images"].values()),
        "detail_pages_checked": len(report["records"]),
        "id_name_image_confirmed": sum(v.get("exact_id_found", False) and v.get("exact_name_found", False) and v.get("exact_image_found", False)
                                       for v in report["records"].values()),
    }
    save()
    print(json.dumps(report["summary"], ensure_ascii=False))


if __name__ == "__main__":
    main()
