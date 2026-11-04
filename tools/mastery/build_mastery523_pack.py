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
        "ClassChangeMasteryLevelCost", "ClassChangeMasteryWeaponType", "MasteryChangeLevelCost")

def compile_pack(source):
    raw = Path(source).read_bytes()
    if hashlib.sha256(raw).hexdigest() != SOURCE_SHA:
        raise ValueError("not the verified cumulative523 source ZIP")
    with zipfile.ZipFile(source) as z:
        if z.testzip() is not None:
            raise ValueError("source CRC mismatch")
        evidence = {}
        def read(name):
            member = "content/" + name + ".json"
            payload = z.read(member)
            evidence[name] = {"member": member, "sha256": hashlib.sha256(payload).hexdigest()}
            rows = json.loads(payload)["rows"]
            if len({r["ID"] for r in rows}) != len(rows):
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
        groups, probability = {}, {}
        for row in tables["MasteryBonusView"]:
            level = levels[row["MasteryWeaponLevelID"]]
            weapon = level["WeaponTypeID"]
            group = groups.setdefault(row["ClassChangeMasteryBonusGroupID"], {})
            if weapon in group:
                raise ValueError("ambiguous option transfer")
            group[weapon] = (level["Level"], row["Slot"], bonuses[row["BonusID"]]["Value"], row["Probability"])
            key = (weapon, level["Level"], row["Slot"])
            probability[key] = probability.get(key, 0) + row["Probability"]
        if len(groups) != 36 or any(set(g) != weapons or len(set(g.values())) != 1 for g in groups.values()):
            raise ValueError("incomplete 36 by 15 correspondence")
        if len(probability) != 240 or set(probability.values()) != {1000000}:
            raise ValueError("invalid option probability buckets")
        if sum(r["Probability"] for r in tables["MasteryGradeView"]) != 1000000:
            raise ValueError("invalid color probabilities")
        classes = {r["ID"] for r in tables["Class"]}
        if len(tables["ClassChangeMasteryWeaponType"]) != 29 or any(r["ToCharacterClass"] not in classes or r["ToWeaponType"] not in weapons for r in tables["ClassChangeMasteryWeaponType"]):
            raise ValueError("unresolved class destination")
        return {"schema": "twilight.mastery523.v1", "source_sha256": SOURCE_SHA,
                "private_original_data": True, "tables": tables, "evidence": evidence}

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
