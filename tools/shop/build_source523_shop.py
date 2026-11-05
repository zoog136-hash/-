#!/usr/bin/env python3
"""Build an external, hash-pinned 523 commerce catalog. No game data writes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile
import zipfile

SOURCE_SHA256 = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
SCHEMA = "twilight.source523.shop.v1"
TABLES = (
    "MerchantGoods", "MarketPurchase_Korean", "MarketPayment_Korean",
    "MarketPurchaseProduct", "MarketProduct", "MarketProductAdditional",
    "MarketBonusForPurchase", "MarketPurchaseRestriction", "MarketDisplay",
    "MarketDisplayCategoryType", "MarketPurchaseGroup", "MarketPurchaseServerLimitGroup",
    "Currency", "CurrencyUnitClass", "CurrencyDiscountRate", "CurrencyCode", "Unit",
    "ServerLimit", "DateTimes_Korean", "CumulativePurchase", "CumulativePurchaseStep",
    "ItemClass", "IntangibleItemClass", "Class", "BuffCard", "Reward", "RewardType",
)


def strict_json(raw):
    def pairs(values):
        result = {}
        for key, value in values:
            if key in result:
                raise ValueError(f"duplicate object key: {key}")
            result[key] = value
        return result
    return json.loads(raw.decode("utf-8-sig"), object_pairs_hook=pairs,
                      parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))


def build(source):
    raw = Path(source).read_bytes()
    if hashlib.sha256(raw).hexdigest() != SOURCE_SHA256:
        raise ValueError("expected the verified patch523 Library source ZIP")
    tables, provenance = {}, {}
    with zipfile.ZipFile(source) as archive:
        if archive.testzip() is not None:
            raise ValueError("source ZIP CRC failed")
        for name in (*TABLES, "DescData_Korean"):
            member = f"content/{name}.json"
            payload = archive.read(member)
            rows = strict_json(payload)["rows"]
            if not isinstance(rows, list) or not all(isinstance(row, dict) for row in rows):
                raise ValueError(f"invalid rows: {name}")
            tables[name] = rows
            provenance[name] = {"member": member, "bytes": len(payload),
                                "sha256": hashlib.sha256(payload).hexdigest(), "source_rows": len(rows)}
    # Keep complete rows, in source order. Labels alone are a referenced subset;
    # their source byte hash and original row count remain explicit.
    label_ids = {0, 1}
    for name in TABLES:
        for row in tables[name]:
            for key, value in row.items():
                if key.endswith("DescID") or key.endswith("DescId"):
                    label_ids.add(value)
    tables["DescData_Korean"] = [row for row in tables["DescData_Korean"] if row["ID"] in label_ids]
    for name, rows in tables.items():
        provenance[name]["packed_rows"] = len(rows)
    return {"schema": SCHEMA, "patch": 523, "source_zip_sha256": SOURCE_SHA256,
            "delivery": "PRIVATE_LOCAL_ONLY", "tables": tables, "provenance": provenance}


def write_pack(source, destination):
    destination = Path(destination).resolve()
    if destination == Path(source).resolve():
        raise ValueError("source archive must remain unchanged")
    repo_root = Path(__file__).resolve().parents[2]
    if destination.is_relative_to(repo_root):
        raise ValueError("place original commerce rows outside the Git working tree")
    pack = build(source)
    payload = json.dumps(pack, ensure_ascii=False, separators=(",", ":"), allow_nan=False).encode()
    destination.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".shop523-", dir=destination.parent)
    try:
        with os.fdopen(fd, "wb") as out:
            out.write(payload)
            out.flush()
            os.fsync(out.fileno())
        os.replace(temporary, destination)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    return {"path": str(destination), "bytes": len(payload),
            "sha256": hashlib.sha256(payload).hexdigest(),
            "tables": {name: len(rows) for name, rows in pack["tables"].items()}}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_zip", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    print(json.dumps(write_pack(args.source_zip, args.destination), ensure_ascii=False, indent=2))
