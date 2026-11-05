#!/usr/bin/env python3
"""Read-only full shop/reference audit; output is private and never activation authority."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import zipfile

SOURCE_SHA = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
TABLES = ("DateTimes", "DateTimes_Korean", "MerchantGoods", "MarketPurchase_Korean", "MarketPayment_Korean", "MarketProduct", "MarketProductAdditional", "MarketPurchaseProduct", "MarketBonusForPurchase", "MarketPurchaseRestriction", "MarketDisplay", "CumulativePurchase", "CumulativePurchaseStep", "Reward", "ItemClass", "BuffCard", "Currency", "CurrencyUnitClass")


def audit(source):
    data = Path(source).read_bytes()
    if hashlib.sha256(data).hexdigest() != SOURCE_SHA:
        raise ValueError("unexpected source archive")
    with zipfile.ZipFile(source) as pack:
        if pack.testzip() is not None:
            raise ValueError("source CRC failure")
        tables = {name: json.loads(pack.read("content/"+name+".json").decode("utf-8-sig"))["rows"] for name in TABLES}
    dates = {row["ID"] for row in tables["DateTimes_Korean"]}
    items = {row["ID"] for row in tables["ItemClass"]}
    cards = {row["ID"] for row in tables["BuffCard"]}
    merchant = tables["MerchantGoods"]
    result = {"schema": "twilight.source523.shop-reference-audit.v1", "activation_authority": False,
              "source_sha256": SOURCE_SHA, "counts": {key: len(value) for key, value in tables.items()},
              "merchant_actions": dict(Counter(row["DialogActionTypeID"] for row in merchant)),
              "merchant_groups": len({row["MerchantsID"] for row in merchant}),
              "missing_merchant_item_ids": sorted({row["ItemClassID"] for row in merchant if row["ItemClassID"] not in items}),
              "card_conditions": {}, "date_refs": {}, "linked_market_products": {}, "other_references": {},
              "market_on_sale": dict(Counter(row["OnSale"] for row in tables["MarketPurchase_Korean"]))}
    for field in ["LimitBuffCardID", "LimitRepeatedBuyCardID"]:
        result["card_conditions"][field] = {"rows": sum(bool(row[field]) for row in merchant),
            "unresolved_ids": sorted({row[field] for row in merchant if row[field] and row[field] not in cards}),
            "execution": "definition presence is not ownership/qualification execution"}
    for table, fields in {"MarketPurchase_Korean": ["EffectiveFromId", "EffectiveToId"], "CumulativePurchase": ["StartTimeID", "EndTimeID"], "MerchantGoods": ["LimitStartTime", "LimitEndTime"]}.items():
        result["date_refs"][table] = {field: {"nonzero": sum(bool(row[field]) for row in tables[table]),
            "unresolved_ids": sorted({row[field] for row in tables[table] if row[field] and row[field] not in dates})} for field in fields}
    products = {row["ID"] for row in tables["MarketProduct"]}
    for table in ["MarketPurchaseProduct", "MarketBonusForPurchase"]:
        result["linked_market_products"][table] = {"rows": len(tables[table]),
            "unresolved_product_ids": sorted({row["MarketProductID"] for row in tables[table] if row["MarketProductID"] not in products})}
    payments = {row["ID"] for row in tables["MarketPayment_Korean"]}
    purchases = {row["ID"] for row in tables["MarketPurchase_Korean"]}
    rewards = {row["ID"] for row in tables["Reward"]}
    for table, field, definitions in [("MarketPurchase_Korean", "MarketPaymentID", payments), ("MarketPurchaseProduct", "MarketPurchaseID", purchases), ("MarketBonusForPurchase", "MarketPurchaseID", purchases), ("MarketDisplay", "PurchaseID", purchases), ("MarketPurchaseRestriction", "MarketPurchaseId", purchases), ("CumulativePurchase", "DailyRewardID", rewards), ("CumulativePurchaseStep", "RewardID", rewards)]:
        result["other_references"][table+"."+field] = {"nonzero": sum(bool(row[field]) for row in tables[table]), "unresolved_ids": sorted({row[field] for row in tables[table] if row[field] and row[field] not in definitions})}
    result["date_source"] = "DateTimes_Korean; empty common DateTimes does not imply missing date definitions"
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path);parser.add_argument("output", type=Path)
    args = parser.parse_args()
    target = args.output.resolve()
    if target == args.source.resolve() or target.exists() or target.is_relative_to(Path(__file__).resolve().parents[2]):
        raise ValueError("choose a new private audit output outside the Git working tree")
    result = audit(args.source)
    payload = (json.dumps(result, ensure_ascii=False, indent=2)+"\n").encode()
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open("xb") as out: out.write(payload)
    print(json.dumps({"counts": result["counts"], "bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest()}))


if __name__ == "__main__": main()
