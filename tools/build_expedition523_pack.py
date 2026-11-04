#!/usr/bin/env python3
"""Compile a private, read-only expedition catalogue from the verified 523 ZIP.

No original rows belong in Git. Output is installed separately and pinned by SHA.
"""
import argparse
import collections
import hashlib
import json
import os
from pathlib import Path
import tempfile
import zipfile
import zlib

SOURCE_SHA256 = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
SCHEMA = "twilight.expedition523.v1"
PREFIX = "MagicDollExpedition"
CORE = [PREFIX + n for n in (
    "Spot", "SpotAsset", "Group", "SpotReward", "SpotRewardType",
    "CompleteRewardView", "SpotEvent", "EventView", "Bonus", "BonusType",
    "Buff", "Monster")]
SYNERGY = ["BuffCardExpeditionSynergy" + n for n in ("", "Cards", "Bonus")]


def encode(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()


def keyed(rows):
    result = {r["ID"]: r for r in rows}
    if len(result) != len(rows):
        raise ValueError("duplicate ID")
    return result


def validate(t):
    """Check source joins without claiming server RNG or active service status."""
    spots, groups, grades = (keyed(t[n]) for n in (PREFIX+"Spot", PREFIX+"Group", "Grade"))
    cards = keyed(t["BuffCard"])
    events, bonuses = (keyed(t[PREFIX+n]) for n in ("EventView", "Bonus"))
    rewards = keyed(t["Reward"])
    completions = collections.defaultdict(list)
    pools = collections.defaultdict(list)
    special_pairs = set()
    for r in t[PREFIX+"SpotReward"]:
        s, g = spots[r[PREFIX+"SpotID"]], groups[r[PREFIX+"GroupID"]]
        if s["BuffCardDeckID"] != g["BuffCardDeckID"] or r["RewardID"] not in rewards:
            raise ValueError("reward join")
        if type(r["Probability"]) is not int or r["Probability"] < 0:
            raise ValueError("invalid raw weight")
        pools[s["ID"], g["ID"]].append(r)
        if r["IsSpecial"]:
            special_pairs.add((s["ID"], g["ID"]))
    if any(sum(r["Probability"] for r in rs) != 100_000_000 for rs in pools.values()):
        raise ValueError("event pool raw weight sum")
    for r in t[PREFIX+"CompleteRewardView"]:
        s, g = spots[r[PREFIX+"SpotID"]], groups[r[PREFIX+"GroupID"]]
        if (s["BuffCardDeckID"] != g["BuffCardDeckID"] or
                (r["GradeID"], r["GroupMinLevel"], r["GroupMaxLevel"]) !=
                (g["GradeID"], g["MinLevel"], g["MaxLevel"])):
            raise ValueError("completion scope")
        if rewards[r["RewardID"]]["RewardTypeID"] != 2:
            raise ValueError("completion must remain a typed item reward")
        completions[s["ID"], g["ID"]].append(r)
    expected = {(s["ID"], g["ID"]) for s in spots.values() for g in groups.values()
                if s["BuffCardDeckID"] == g["BuffCardDeckID"]}
    if set(completions) != expected or any(len(v) != 1 for v in completions.values()):
        raise ValueError("completion pairs missing or duplicated")
    expected_special = set()
    for r in t[PREFIX+"SpotEvent"]:
        s = spots[r[PREFIX+"SpotID"]]
        e = events[r[PREFIX+"EventID"]]
        b = bonuses[e[PREFIX+"BonusID"]]
        if b[PREFIX+"BonusTypeID"] == 141:
            expected_special.update((s["ID"], g["ID"]) for g in groups.values()
                if g["BuffCardDeckID"] == s["BuffCardDeckID"]
                and grades[g["GradeID"]]["GradeValue"] >= grades[e["MinGradeID"]]["GradeValue"]
                and g["MinLevel"] >= e["MinLevel"])
    if special_pairs != expected_special:
        raise ValueError("special event threshold mismatch")
    for r in t["BuffCardExpeditionSynergyCards"]:
        if r["BuffCardID"] not in cards:
            raise ValueError("missing synergy card")
    below_min = sum(grades[groups[g]["GradeID"]]["GradeValue"] < grades[spots[s]["MinGrade"]]["GradeValue"]
                    for s, g in completions)
    if (len(spots), len(groups), len(pools), len(completions), len(special_pairs), below_min) != (29, 30, 284, 290, 91, 18):
        raise ValueError("unexpected 523 coverage")
    bags = collections.defaultdict(list)
    for r in t["LuckyBagEntityView"]:
        bags[r["LuckyBagClassID"]].append(r)
    if len(bags) != 29 or any(sum(r["Probability"] for r in rs) != 10_000_000 for rs in bags.values()):
        raise ValueError("completion box raw weight sum")
    return {"spots": len(spots), "groups": len(groups), "event_rows": sum(map(len, pools.values())),
            "event_pools": len(pools), "completion_pairs": len(completions), "completion_boxes": len(bags),
            "completion_candidates": sum(map(len, bags.values())), "special_pairs": len(special_pairs),
            "below_minimum_completion_pairs": below_min}


def compile_pack(source):
    source = Path(source)
    if hashlib.sha256(source.read_bytes()).hexdigest() != SOURCE_SHA256:
        raise ValueError("expected validated cumulative523 archive SHA256")
    tables, proof = {}, {}
    with zipfile.ZipFile(source) as z:
        if z.testzip() is not None:
            raise ValueError("source CRC")
        index = {r["path"]: r for r in json.loads(z.read("index.json").decode("utf-8-sig"))}

        def read(name):
            member = "content/"+name+".json"
            raw = z.read(member)
            record = index[member]
            rows = json.loads(raw.decode("utf-8-sig"))["rows"]
            if (record["version"] != 523 or hashlib.sha256(raw).hexdigest() != record["sha256"]
                    or len(raw) != record["bytes"] or len(rows) != record["row_count"]
                    or f"{zlib.crc32(raw):08x}" != record["crc32"]):
                raise ValueError("table proof mismatch: "+name)
            proof[name] = {"member": member, "sha256": record["sha256"], "source_rows": len(rows)}
            return rows

        for n in CORE + SYNERGY + ["Grade", "BuffCard"]:
            tables[n] = read(n)
        tables["ConstantData"] = [r for r in read("ConstantData")
            if "Expedition" in r["Name"] or r["Name"] == "PolymorphDispatchLevel"]
        reward_ids = {r["RewardID"] for n in ("SpotReward", "CompleteRewardView") for r in tables[PREFIX+n]}
        tables["Reward"] = [r for r in read("Reward") if r["ID"] in reward_ids]
        item_ids = {r["RewardClassID"] for r in tables["Reward"] if r["RewardTypeID"] == 2}
        all_item_bonus, all_bonus = read("ItemBonus"), read("Bonus")
        bonus_types = read("BonusType")
        bag_type = {r["ID"] for r in bonus_types if r["Name"] == "LuckyBagClassID" and r["UnitID"] == 29}
        ib = [r for r in all_item_bonus if r["ItemClassID"] in item_ids]
        b_by_id = keyed(all_bonus)
        # Only the 29 completion boxes, not event packaging or linked market RNG.
        completion_items = {r["RewardClassID"] for r in tables["Reward"] if r["ID"] in
            {c["RewardID"] for c in tables[PREFIX+"CompleteRewardView"]}}
        bag_ids = {b_by_id[r["BonusID"]]["Value"] for r in ib
            if r["ItemClassID"] in completion_items and b_by_id[r["BonusID"]]["BonusTypeID"] in bag_type}
        tables["LuckyBagClass"] = [r for r in read("LuckyBagClass") if r["ID"] in bag_ids]
        tables["LuckyBagEntityView"] = [r for r in read("LuckyBagEntityView") if r["LuckyBagClassID"] in bag_ids]
        item_ids.update(r["ItemClassID"] for r in tables["LuckyBagEntityView"])
        tables["ItemClass"] = [r for r in read("ItemClass") if r["ID"] in item_ids]
        tables["ItemBonus"] = [r for r in all_item_bonus if r["ItemClassID"] in item_ids]
        bonus_ids = {r["BonusID"] for r in tables["ItemBonus"] + tables["BuffCardExpeditionSynergyBonus"]}
        tables["Bonus"] = [r for r in all_bonus if r["ID"] in bonus_ids]
        tables["BonusType"] = [r for r in bonus_types if r["ID"] in {b["BonusTypeID"] for b in tables["Bonus"]}]
        currency_ids = {r[k] for n, k in ((PREFIX+"Spot", "ExpeditionCostCurrencyID"),
            (PREFIX+"Buff", "CostCurrencyID")) for r in tables[n]}
        tables["Currency"] = [r for r in read("Currency") if r["ID"] in currency_ids]
        tables["CurrencyUnitClass"] = [r for r in read("CurrencyUnitClass") if r["CurrencyID"] in currency_ids]
    qa = validate(tables)
    for name, rows in tables.items():
        proof[name]["selected_rows"] = len(rows)
    return {"schema": SCHEMA, "source_sha256": SOURCE_SHA256, "source_tables": proof,
            "tables": tables, "coverage": qa}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_zip", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if args.output.resolve().is_relative_to(Path(__file__).resolve().parents[1]):
        raise SystemExit("output must be outside the Git checkout")
    pack = encode(compile_pack(args.source_zip))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=args.output.parent, delete=False) as f:
        temporary = f.name
        f.write(pack)
    try:
        os.chmod(temporary, 0o600)
        os.replace(temporary, args.output)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    print(json.dumps({"path": str(args.output), "bytes": len(pack),
                      "sha256": hashlib.sha256(pack).hexdigest(), "coverage": json.loads(pack)["coverage"]}))


if __name__ == "__main__":
    main()
