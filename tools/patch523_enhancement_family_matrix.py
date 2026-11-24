#!/usr/bin/env python3
"""Build exact, non-test enhancement family test fixtures from the pinned ZIP."""
import argparse
import hashlib
import itertools
import json
import zipfile
from collections import defaultdict
from pathlib import Path

SOURCE_SHA = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"


def matrix(archive: Path) -> dict:
    if hashlib.sha256(archive.read_bytes()).hexdigest() != SOURCE_SHA:
        raise ValueError("Original 523 ZIP does not match the pinned SHA")
    with zipfile.ZipFile(archive) as z:
        def rows(table):
            return json.loads(z.read(f"content/{table}.json"))["rows"]

        items = {r["ID"]: r for r in rows("ItemClass") if r["TestItem"] is False and not r["ServiceRegionCode"]}
        bonus = {r["ID"]: r for r in rows("Bonus")}
        def mapping(table, field):
            out = defaultdict(set)
            for row in rows(table):
                out[row[field]].add(row["ItemEnchantProbabilityGroupID"])
            return out

        equipmap = mapping("ItemEnchantEquipGroupMapping", "ItemEnchantEquipGroupID")
        scrollmap = mapping("ItemEnchantScrollGroupMapping", "ItemEnchantScrollGroupID")
        equip = defaultdict(set)
        scrolls = defaultdict(set)
        for link in rows("ItemBonus"):
            item = link["ItemClassID"]
            if item not in items:
                continue
            b = bonus[link["BonusID"]]
            if b["BonusTypeID"] == 2032:
                equip[item].update(equipmap[b["Value"]])
            if b["BonusTypeID"] == 2022:
                for bless in (1, 2):
                    scrolls[item, bless].update(scrollmap[b["Value"]])
            if b["BonusTypeID"] == 8352 and b["BonusApplicationTypeID"] == 202 and b["BonusApplicationTargetID"] in (1, 2):
                scrolls[item, b["BonusApplicationTargetID"]].update(scrollmap[b["Value"]])

        def selector(table):
            out = defaultdict(list)
            for row in rows(table):
                out[row["ItemEnchantProbabilityGroupID"], row["EnchantLevel"], row["TargetItemBlessCode"]].append(row)
            return out

        def chosen(table, group, level, blessing):
            candidates = table[group, level, blessing] or table[group, level, 0]
            return candidates[0] if len(candidates) == 1 else {}

        odds, costs = map(selector, ("BmItemEnchantProView", "ItemEnchantCostView"))
        def priority(item):
            r = items[item]
            return tuple(bool(r.get(k)) for k in ("EndDateTimeID", "StartDateTimeID", "LinkSeasonShopType")) + (item,)

        result = {}
        for group, level in sorted({(r["ItemEnchantProbabilityGroupID"], r["EnchantLevel"])
                                    for r in rows("ItemEnchantProbabilityView") if r["ServerLimitSetID"] == 0}):
            if group in result:
                continue
            for blessing in (1, 2):
                p = chosen(odds, group, level, blessing)
                c = chosen(costs, group, level, blessing)
                if not p or not c or sum(p[k] for k in ("Success", "Remain", "Vaporize", "SideEffect")) != 1_000_000 or p["Success"] + p["SideEffect"] <= 0 or c["Cost"] < 0:
                    continue
                ts = sorted((i for i, groups in equip.items() if group in groups), key=priority)
                ss = sorted((key for key, groups in scrolls.items() if group in groups), key=lambda key: (*priority(key[0]), key[1]))
                pairs = itertools.islice(((t, s, sb) for t in ts for s, sb in ss if equip[t] & scrolls[s, sb] == {group}), 180)
                fixtures = [dict(target=t, scroll=s, level=level, target_bless=blessing, scroll_bless=sb,
                                 cost=c["Cost"], count=c["ConsumeAmount"] or 1, success=p["Success"],
                                 destroy=p["Vaporize"], remain=p["Remain"], side=p["SideEffect"])
                            for t, s, sb in pairs]
                if fixtures:
                    result[group] = fixtures
                    break
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    rows = matrix(args.archive)
    args.output.write_text(json.dumps(rows, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"{len(rows)} groups with exact non-test target/scroll/level selectors")
    return 0 if len(rows) == 71 else 1


if __name__ == "__main__":
    raise SystemExit(main())
