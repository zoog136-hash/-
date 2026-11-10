#!/usr/bin/env python3
"""Compile the authorized 523 content ZIP into a separate, private runtime pack.

No original rows are embedded in this compiler. Output is never a public asset.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile
import zipfile

SOURCE_SHA = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
CORE = ("MasteryWeaponType", "MasteryWeaponStep", "MasteryWeaponLevelView",
        "MasteryBonusView", "MasteryGradeView", "MasteryGradeMatchingBonus",
        "MasteryPointPayment", "MasteryPointPurchaseView", "MasteryResetCost",
        "MasteryChangeLevelCost")

def compile_pack(source):
    raw = Path(source).read_bytes()
    if hashlib.sha256(raw).hexdigest() != SOURCE_SHA:
        raise ValueError("not the verified cumulative523 source ZIP")
    with zipfile.ZipFile(source) as z:
        if z.testzip() is not None:
            raise ValueError("source CRC mismatch")
        evidence = {}
        def read(name, unique_ids=True):
            member = "content/" + name + ".json"
            payload = z.read(member)
            evidence[name] = {"member": member, "sha256": hashlib.sha256(payload).hexdigest()}
            rows = json.loads(payload)["rows"]
            if unique_ids and len({r["ID"] for r in rows}) != len(rows):
                raise ValueError("duplicate source ID: " + name)
            evidence[name]["rows"] = len(rows)
            return rows
        tables = {name: read(name) for name in CORE}
        levels = {r["ID"]: r for r in tables["MasteryWeaponLevelView"]}
        weapons = {r["WeaponTypeID"] for r in levels.values()}
        if len(weapons) != 15 or len(levels) != 120:
            raise ValueError("unexpected 523 growth coverage")
        for weapon in weapons:
            ordered = sorted((r for r in levels.values() if r["WeaponTypeID"] == weapon), key=lambda r: r["Level"])
            if [r["Level"] for r in ordered] != list(range(1, 9)):
                raise ValueError("incomplete growth ladder")
            points = [r["CumulativePoint"] for r in ordered]
            if points != sorted(set(points)) or points[0] <= 0:
                raise ValueError("invalid growth thresholds")
        bonus_ids = {r["BonusID"] for name in ("MasteryBonusView", "MasteryGradeMatchingBonus") for r in tables[name]}
        tables["Bonus"] = [r for r in read("Bonus") if r["ID"] in bonus_ids]
        bonuses = {r["ID"]: r for r in tables["Bonus"]}
        if set(bonuses) != bonus_ids:
            raise ValueError("unresolved bonus")
        type_ids = {r["BonusTypeID"] for r in bonuses.values()}
        tables["BonusType"] = [r for r in read("BonusType") if r["ID"] in type_ids]
        unit_ids = {r["UnitID"] for r in tables["BonusType"]}
        tables["UIUnit"] = [r for r in read("UIUnit") if r["UnitID"] in unit_ids]
        for name in ("Class", "WeaponType", "Currency", "CurrencyUnitClass"):
            tables[name] = read(name)
        constants = read("ConstantData")
        item_rows = read("ItemClass")
        def one(name, key, value):
            matches = [r for r in read(name, False) if r.get(key) == value]
            if len(matches) != 1:
                raise ValueError("ambiguous operation row: " + name)
            return matches[0]
        purchase = one("MarketPurchase_Korean", "ID", 95441)
        payment = one("MarketPayment_Korean", "ID", purchase["MarketPaymentID"])
        link = one("MarketPurchaseProduct", "MarketPurchaseID", purchase["ID"])
        product = one("MarketProduct", "ID", link["MarketProductID"])
        powder_link = next(r for r in tables["CurrencyUnitClass"] if r["CurrencyID"] == 1682)
        powder = next(r for r in item_rows if r["ID"] == powder_link["ClassID"])
        if powder_link["UnitID"] != 4 or powder["ID"] != 117544 or payment["UnitID"] != 201 or payment["ClassID"] != 4 or purchase["AdditionalCurrencyID"] != 4 or product["UnitID"] != 281 or product["ClassID"] != 101 or product["Amount"] != 1:
            raise ValueError("unresolved material or independent mastery-service payment")
        reset_constant = next(r for r in constants if r["Name"] == "MasteryPointPurchaseResetScheduleType")
        schedule = next(r for r in read("ContentsResetScheduleType") if r["ID"] == int(reset_constant["Value"]))
        ticket_constant = next(r for r in constants if r["Name"] == "MasteryResetTicketCurrencyID")
        ticket_currency = next(r for r in tables["Currency"] if r["ID"] == int(ticket_constant["Value"]))
        ticket_link = next(r for r in tables["CurrencyUnitClass"] if r["CurrencyID"] == ticket_currency["ID"])
        ticket_item = next(r for r in item_rows if r["ID"] == ticket_link["ClassID"])
        ticket_category = next(r for r in read("ItemCategory") if r["ID"] == ticket_item["CategoryID"])
        ticket_grade = next(r for r in read("Grade") if r["ID"] == ticket_item["GradeID"])
        ticket_bonuses = [r for r in read("ItemBonus") if r["ItemClassID"] == ticket_item["ID"]]
        ticket_label = next(r["Description"] for r in read("DescData_Korean") if r["ID"] == ticket_item["IdentifiedDescID"])
        ticket_definition = {"constant":ticket_constant,"currency":ticket_currency,"currency_link":ticket_link,
                             "item":ticket_item,"category":ticket_category,"grade":ticket_grade,
                             "bonuses":ticket_bonuses,"bless_codes":read("ItemBlessCode"),"label":ticket_label}
        if ticket_currency["ID"] != 1814 or ticket_link["UnitID"] != 4 or ticket_item["ID"] != 184652 or ticket_item["TestItem"] or not ticket_category["IsStackable"] or ticket_category["IsConsumable"] or ticket_bonuses:
            raise ValueError("unresolved mastery reset ticket identity or restrictions")
        ticket_sha = hashlib.sha256(json.dumps(ticket_definition, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        operations = {"point_purchase": {"material": powder, "currency_link": powder_link,
                      "schedule_constant": reset_constant, "schedule": schedule,
                      "automatic_period_reset_verified": False},
                      "reset_ticket": {"definition":ticket_definition,"definition_sha256":ticket_sha},
                      "mastery_change": {"purchase": purchase, "payment": payment,
                      "product_link": link, "product": product,
                      "from": one("DateTimes_Korean", "ID", purchase["EffectiveFromId"]), "to": one("DateTimes_Korean", "ID", purchase["EffectiveToId"]),
                      "restrictions": [r for r in read("MarketPurchaseRestriction", False) if r.get("MarketPurchaseId") == purchase["ID"]],
                      "repeat_restriction_verified": False},
                      "reset_color_draws": [r for r in read("UIStaticTextData_Korean", False)
                          if r.get("TextDesc", "") in {
                              "MASTERY_POPUP_HELP\\ND_MASTERY_HELP01\\ND_STEP_3\\ND_TEXT\\TEXT_HELP",
                              "MASTERY_POPUP_HELP\\ND_MASTERY_HELP02\\ND_STEP_7\\ND_TEXT\\TEXT_HELP"}]}
        groups, probability, bucket_types = {}, {}, {}
        for row in tables["MasteryBonusView"]:
            level = levels[row["MasteryWeaponLevelID"]]
            weapon = level["WeaponTypeID"]
            group = groups.setdefault(row["ClassChangeMasteryBonusGroupID"], {})
            if weapon in group:
                raise ValueError("ambiguous option transfer")
            group[weapon] = (level["Level"], row["Slot"], bonuses[row["BonusID"]]["Value"], row["Probability"])
            key = (weapon, level["Level"], row["Slot"])
            probability[key] = probability.get(key, 0) + row["Probability"]
            bucket_types.setdefault(key, set()).add(bonuses[row["BonusID"]]["BonusTypeID"])
            if row["Slot"] not in (1, 2) or row["Probability"] <= 0:
                raise ValueError("invalid original slot or weight")
        if len(groups) != 36 or any(set(g) != weapons or len(set(g.values())) != 1 for g in groups.values()):
            raise ValueError("incomplete 36 by 15 correspondence")
        if any(len(types) != 1 for types in bucket_types.values()):
            raise ValueError("option name changes within a numerical-value bucket")
        if len(probability) != 240 or set(probability.values()) != {1000000}:
            raise ValueError("invalid option probability buckets")
        if sum(r["Probability"] for r in tables["MasteryGradeView"]) != 1000000:
            raise ValueError("invalid color probabilities")
        steps = {r["ID"]: r for r in tables["MasteryWeaponStep"]}
        grades = {r["GradeID"] for r in tables["MasteryGradeView"]}
        matching_keys = set()
        for row in tables["MasteryGradeMatchingBonus"]:
            key = (row["WeaponStepID"], row["GradeID"])
            if key in matching_keys or row["WeaponStepID"] not in steps or row["GradeID"] not in grades or row["BonusID"] not in bonuses:
                raise ValueError("invalid matching bonus reference or duplicate")
            matching_keys.add(key)
        if len(matching_keys) != len(steps)*len(grades):
            raise ValueError("missing matching bonus scope")
        return {"schema": "twilight.mastery523.v1", "source_sha256": SOURCE_SHA,
                "private_original_data": True, "tables": tables, "operations": operations, "evidence": evidence}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_zip", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    if args.output.resolve().is_relative_to(repo):
        parser.error("private pack must be outside the public repository")
    pack = compile_pack(args.source_zip)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=args.output.parent, prefix=".mastery-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(pack, f, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
            f.flush()
            os.fsync(f.fileno())
        os.replace(temporary, args.output)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    print(json.dumps({"path": str(args.output), "sha256": hashlib.sha256(args.output.read_bytes()).hexdigest(), "bytes": args.output.stat().st_size, "status": "PRIVATE_LOCAL_ONLY"}))

if __name__ == "__main__":
    main()
