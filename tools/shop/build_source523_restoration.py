#!/usr/bin/env python3
"""Compile three ordinary NPC recovery items without copying source rows."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

SOURCE = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"


def build(archive):
    if hashlib.sha256(archive.read_bytes()).hexdigest() != SOURCE:
        raise ValueError("source identity mismatch")
    with zipfile.ZipFile(archive) as pack:
        if pack.testzip() is not None:
            raise ValueError("source CRC error")
        def rows(table):
            return json.loads(pack.read("content/"+table+".json"))["rows"]
        bonuses = {r["ID"]: r for r in rows("Bonus")}
        types = {r["ID"]: r["Name"] for r in rows("BonusType")}
        items = {r["ID"]: r for r in rows("ItemClass")}
        labels = {r["ID"]: r["Description"] for r in rows("DescData_Korean")}
        values = {id: {} for id in [233, 237, 236]}
        for row in rows("ItemBonus"):
            if row["ItemClassID"] not in values:
                continue
            bonus = bonuses[row["BonusID"]]
            name = types[bonus["BonusTypeID"]]
            if row["IsPossession"] or bonus["BonusApplicationTypeID"] or bonus["BonusApplicationTargetID"] or name in values[row["ItemClassID"]]:
                raise ValueError("conditional/duplicate healing effect")
            if name not in ["HPRestoration", "HPRestorationDiceNumber", "HPRestorationDiceSpotCount", "ItemConsumeDelay", "ItemConsumeEffectSpriteID", "AutoUseRegistrable"]:
                raise ValueError("new unsupported recovery condition: "+name)
            values[row["ItemClassID"]][name] = bonus["Value"]
        output = {}
        for id, value in values.items():
            if items[id]["TestItem"] or value.get("ItemConsumeDelay") != 1000:
                raise ValueError("item/cooldown no longer compatible with existing shared potion consumer")
            output[str(id)] = {"name": labels[items[id]["DescID"]], "base": value["HPRestoration"], "dice_count": value["HPRestorationDiceNumber"], "dice_sides": value["HPRestorationDiceSpotCount"]}
        return {"schema": "twilight.source523.restoration.v1", "source_sha256": SOURCE, "dice_policy": "base_plus_uniform_dice", "origin": "원본 기본 회복·주사위 수/면 우선 · TWILIGHT 합산식과 기존 물약 보정/공유 대기 재사용", "items": output}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if args.output.resolve() == args.archive.resolve():
        raise ValueError("preserve source archive")
    args.output.write_text(json.dumps(build(args.archive), ensure_ascii=False, indent=2)+"\n")
    print("SOURCE_RECOVERY_ITEMS", 3)


if __name__ == "__main__":
    main()
