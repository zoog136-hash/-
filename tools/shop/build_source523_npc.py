#!/usr/bin/env python3
"""Build a separate private NPC definition pack without changing the shop pack."""
import argparse
import hashlib
import json
from pathlib import Path

from audit_source523_npc_activation import audit
from build_source523_shop import SCHEMA, SOURCE_SHA256, strict_json


def build(source, shop_pack, shop_sha256):
    shop_bytes = Path(shop_pack).read_bytes()
    if hashlib.sha256(shop_bytes).hexdigest() != shop_sha256:
        raise ValueError("existing shop pack hash mismatch")
    catalog = strict_json(shop_bytes)
    if catalog.get("schema") != SCHEMA or catalog.get("source_zip_sha256") != SOURCE_SHA256:
        raise ValueError("existing shop pack is not patch523")
    report = audit(source)
    # All source links remain facts. Runtime owns the separately labelled local
    # availability policy; this compiler does not turn audit findings into grants.
    return {"schema": "twilight.source523.npc-definitions.v1", "revision":2, "patch": 523,
            "source_zip_sha256": SOURCE_SHA256, "shop_pack_sha256": shop_sha256,
            "delivery": "PRIVATE_LOCAL_ONLY", "evidence": report["evidence"],
            "source_semantics":report["source_semantics"], "merchants": report["merchants"]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("shop_pack", type=Path)
    parser.add_argument("shop_sha256")
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    destination = args.destination.resolve()
    if destination in [args.source.resolve(), args.shop_pack.resolve()]:
        raise ValueError("original source and existing shop pack must remain unchanged")
    if destination.is_relative_to(Path(__file__).resolve().parents[2]):
        raise ValueError("place the private NPC pack outside the Git working tree")
    payload = json.dumps(build(args.source, args.shop_pack, args.shop_sha256), ensure_ascii=False, separators=(",", ":"), allow_nan=False).encode()
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("xb") as out:
        out.write(payload)
    print(json.dumps({"path": str(destination), "bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest()}))
