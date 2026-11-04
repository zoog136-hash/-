#!/usr/bin/env python3
"""Read-only NPC activation audit; its output never authorizes a transaction."""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
import os
from pathlib import Path
import tempfile
import zipfile

from build_source523_shop import SOURCE_SHA256, strict_json

TABLES = (
    "MerchantGoods", "Unit", "EarthObjectUnit", "EarthObjectClass",
    "EarthObjectCategory", "EarthObjectDialogActions", "DialogActionType",
    "EarthObjectSpawn", "EarthObjectAttribute", "EarthObjectAttributeType",
    "UIMapEarthObjectInfo", "Currency", "CurrencyUnitClass",
    "ContentsResetScheduleType", "ConstantData", "DateTimes_Korean", "ServerLimit", "ItemBlessCode",
)


def grouped(rows, key):
    result = defaultdict(list)
    for row in rows:
        result[row[key]].append(row)
    return result


def analyze(tables, inventory):
    """Expose source links and evidence gaps, without inventing zero sentinels."""
    units = {r["ID"]: r["Name"] for r in tables["Unit"]}
    if units.get(25) != "MerchantsID" or units.get(201) != "CurrencyID":
        raise ValueError("source Unit namespace does not identify merchant/currency links")
    action_types = {r["ID"]: r["Name"] for r in tables["DialogActionType"]}
    if action_types.get(1) != "SellList":
        raise ValueError("source dialog action does not identify SellList")
    objects = {r["ID"]: r for r in tables["EarthObjectClass"]}
    currencies = {r["ID"]: r for r in tables["Currency"]}
    object_units = grouped(tables["EarthObjectUnit"], "EarthObjectClassID")
    actions = grouped(tables["EarthObjectDialogActions"], "EarthObjectClassID")
    spawns = grouped(tables["EarthObjectSpawn"], "EarthObjectClassID")
    attributes = grouped(tables["EarthObjectAttribute"], "EarthObjectClassID")
    attribute_types = {r["ID"]: r["Name"] for r in tables["EarthObjectAttributeType"]}
    goods = grouped(tables["MerchantGoods"], "MerchantsID")
    references = grouped([r for r in tables["EarthObjectUnit"] if r["UnitID"] == 25], "Value")
    refresh_names = {r["ID"]: r["Name"] for r in tables["ContentsResetScheduleType"]}
    result = []
    for merchant_id, offers in sorted(goods.items()):
        links = []
        for link in references.get(merchant_id, []):
            object_id = link["EarthObjectClassID"]
            obj = objects.get(object_id)
            currency_links = [r for r in object_units[object_id] if r["UnitID"] == 201]
            currency_ids = sorted({r["Value"] for r in currency_links})
            source_spawns = spawns.get(object_id, [])
            links.append({
                "earth_object_id": object_id,
                "merchant_link_row_id": link["ID"],
                "name": obj["Name"] if obj else None,
                "object_defined": obj is not None,
                "currency_ids": currency_ids,
                "currency_names": [currencies.get(i, {}).get("Name") for i in currency_ids],
                "currency_defined_and_unique": len(currency_ids) == 1 and currency_ids[0] in currencies,
                "sell_action_row_ids": [r["ID"] for r in actions.get(object_id, []) if r["EarthActionTypeID"] == 1],
                "spawns": [{k: r[k] for k in ["ID", "Name", "ServerLimitSetID", "SpawnManually", "WarTaxOn", "SiegeTaxOn", "TerritoriesID"]} for r in source_spawns],
                "attributes": [{"id": r["EarthObjectAttributeTypeID"], "name": attribute_types.get(r["EarthObjectAttributeTypeID"]), "value": r["Value"]} for r in attributes.get(object_id, [])],
            })
        blockers = []
        if not links:
            blockers.append("MISSING_MERCHANT_TO_EARTH_OBJECT_REFERENCE")
        elif not any(r["object_defined"] and r["currency_defined_and_unique"] and r["sell_action_row_ids"] and r["spawns"] for r in links):
            blockers.append("INCOMPLETE_OBJECT_CURRENCY_ACTION_OR_SPAWN_CHAIN")
        zero_hours = [r["ID"] for r in offers if r["LimitStartHour"] == r["LimitEndHour"] == 0]
        if zero_hours:
            blockers.append("UNVERIFIED_ZERO_HOUR_EXECUTION_RULE")
        if any(r["LimitCount"] > 0 for r in offers):
            blockers.append("LIMIT_REFRESH_NAMESPACE_AND_COUNTER_SCOPE_REQUIRE_IMPLEMENTATION")
        if any(r["LimitServerCount"] > 0 for r in offers):
            blockers.append("SERVER_SHARED_STOCK_AUTHORITY_UNAVAILABLE")
        if any(any(r[k] for k in ["ClanLevelMin", "LimitMinClanLevel", "DaysAfterClanJoin", "LimitDaysAfterClanJoin", "LimitClanMemberRank"]) for r in offers):
            blockers.append("CLAN_CONDITIONS_PRESENT_BUT_EXCLUDED_FROM_THIS_GAME_SCOPE")
        if any(r["LimitBuffCardID"] or r["LimitRepeatedBuyCardID"] for r in offers):
            blockers.append("CARD_QUALIFICATION_RULES_NOT_IMPLEMENTED")
        result.append({"merchant_id": merchant_id, "goods_ids": [r["ID"] for r in offers],
                       "zero_hour_goods_ids": zero_hours, "object_links": links,
                       "refresh_type_ids_with_count_limit": sorted({r["LimitCountRefreshTypeID"] for r in offers if r["LimitCount"] > 0}),
                       "blockers": blockers, "activation_authorized": False})
    merchant_fields = [(r["path"], field) for r in inventory for field in r["fields"] if "Merchant" in field]
    return {
        "schema": "twilight.source523.npc-activation-audit.v1",
        "delivery": "PRIVATE_LOCAL_ONLY", "activation_authorized": False,
        "summary": {
            "inventory_tables": len(inventory), "goods_rows": sum(map(len, goods.values())),
            "merchant_groups": len(result), "groups_with_explicit_object_reference": sum(bool(r["object_links"]) for r in result),
            "groups_without_explicit_object_reference": sum(not r["object_links"] for r in result),
            "zero_hour_rows": sum(len(r["zero_hour_goods_ids"]) for r in result),
            "positive_count_limit_rows": sum(r["LimitCount"] > 0 for r in tables["MerchantGoods"]),
        },
        "merchant_named_field_locations": merchant_fields,
        "refresh_type_ids": dict(sorted(Counter(r["LimitCountRefreshTypeID"] for r in tables["MerchantGoods"]).items())),
        # These names belong to a DIFFERENT field namespace. Equal IDs are not
        # sufficient evidence to reinterpret LimitCountRefreshTypeID.
        "contents_reset_schedule_names_not_a_verified_merchant_foreign_key": refresh_names,
        "not_proven": ["meaning of LimitStartHour=LimitEndHour=0", "merchant refresh type 0/31 enum and binding to ContentsResetScheduleType", "UIMapEarthObjectInfo has no EarthObjectSpawnID; matching row counts/order are not a foreign key", "current live-server activation, shared stock and castle/clan entitlement"],
        "merchants": result,
    }


def audit(source):
    source = Path(source)
    if hashlib.sha256(source.read_bytes()).hexdigest() != SOURCE_SHA256:
        raise ValueError("expected the verified patch523 Library source ZIP")
    tables, evidence = {}, {}
    with zipfile.ZipFile(source) as archive:
        if archive.testzip() is not None:
            raise ValueError("source ZIP CRC failed")
        inventory = strict_json(archive.read("index.json"))
        by_path = {r["path"]: r for r in inventory}
        for name in TABLES:
            member = f"content/{name}.json"
            payload = archive.read(member)
            digest = hashlib.sha256(payload).hexdigest()
            if digest != by_path[member]["sha256"]:
                raise ValueError(f"source index hash mismatch: {member}")
            tables[name] = strict_json(payload)["rows"]
            if len(tables[name]) != by_path[member]["row_count"]:
                raise ValueError(f"source index row count mismatch: {member}")
            evidence[name] = {"member": member, "bytes": len(payload), "sha256": digest, "rows": len(tables[name])}
    result = analyze(tables, inventory)
    result["source_semantics"]={
        "item_bless_codes":{str(r["ID"]):r["Name"] for r in tables["ItemBlessCode"]},
        "reset_schedule_types":{str(r["ID"]):r["Name"] for r in tables["ContentsResetScheduleType"]},
        "refresh_constants":{r["Name"]:r["Value"] for r in tables["ConstantData"] if r["Name"] in ["ContentsRefreshHour","ContentsRefreshMinute","ContentsRefreshSecond"]},
    }
    result.update(source_zip_sha256=SOURCE_SHA256, evidence=evidence)
    return result


def write_audit(source, destination):
    source, destination = Path(source).resolve(), Path(destination).resolve()
    if destination == source:
        raise ValueError("source archive must remain unchanged")
    if destination.is_relative_to(Path(__file__).resolve().parents[2]):
        raise ValueError("place the private source-derived audit outside the Git working tree")
    payload = json.dumps(audit(source), ensure_ascii=False, indent=2, allow_nan=False).encode() + b"\n"
    destination.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".npc-audit-", dir=destination.parent)
    try:
        with os.fdopen(fd, "wb") as out:
            out.write(payload)
            out.flush()
            os.fsync(out.fileno())
        os.replace(temporary, destination)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    return {"path": str(destination), "bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest()}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    print(json.dumps(write_audit(args.source, args.destination), ensure_ascii=False))
