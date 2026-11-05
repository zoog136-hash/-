#!/usr/bin/env python3
"""Extract only Halphas' confirmed star-enchant contract; never infer server policy."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

ARCHIVE_SHA256 = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
TABLES = ("BuffCard", "BuffCardStarEnchantGroup", "BuffCardStarEnchantRule",
          "BuffCardStarEnchantBonus", "BuffCardSpriteCustomizingOption", "Grade",
          "Currency", "ServerLimit", "ConstantData", "ContentsControl", "Bonus", "BonusType", "Unit",
          "BonusApplicationType", "SpecialResistanceType", "UIUnit",
          "ChargeBonus", "ChargeEffectBonus", "SpellClass")


def build(archive: Path) -> dict:
    if hashlib.sha256(archive.read_bytes()).hexdigest() != ARCHIVE_SHA256:
        raise ValueError("Expected the byte-verified patch523 Content archive")
    tables, evidence = {}, {}
    with zipfile.ZipFile(archive) as z:
        for name in TABLES:
            member = "content/" + name + ".json"
            raw = z.read(member)  # ZIP reader validates each selected member's CRC.
            tables[name] = json.loads(raw.decode("utf-8-sig"))["rows"]
            evidence[name] = {"member": member, "bytes": len(raw),
                              "sha256": hashlib.sha256(raw).hexdigest()}
    def one(name, **fields):
        matches = [r for r in tables[name] if all(r.get(k) == v for k, v in fields.items())]
        if len(matches) != 1:
            raise ValueError(f"Ambiguous {name}: {fields}")
        return matches[0]
    card = one("BuffCard", ID=24504)
    if card["BuffCardDeckID"] != 1:
        raise ValueError("Halphas source deck changed")
    group = one("BuffCardStarEnchantGroup", BuffCardID=card["ID"])
    control = one("ContentsControl", Name="BuffCardStarEnchantPolymorph")
    if control["ServerLimitSetID"] != group["ServerLimitsetID"]:
        raise ValueError("Review changed source feature/group server scope")
    # Other groups must be reviewed separately even if a future source adds them.
    if len(tables["BuffCardStarEnchantGroup"]) != 1:
        raise ValueError("Review newly introduced source groups separately")
    rules = sorted([r for r in tables["BuffCardStarEnchantRule"] if r["GroupID"] == group["ID"]],
                   key=lambda r: r["Enchant"])
    if [r["Enchant"] for r in rules] != [1, 2, 3]:
        raise ValueError("Expected three distinct source stages")
    for r in rules:
        for field in ("Probability", "SourceGradeID", "SourceAmount", "CurrencyID", "CurrencyCost"):
            if type(r[field]) is not int or r[field] <= 0:
                raise ValueError("Invalid source rule: " + field)
    limits = {card["ServerLimitSetID"], group["ServerLimitsetID"]}
    limits.update(r["ServerLimitsetID"] for r in rules)
    limits.discard(0)
    limit_rows = [r for r in tables["ServerLimit"] if r["ServerLimitSetID"] in limits]
    unresolved = sorted(limits - {r["ServerLimitSetID"] for r in limit_rows})
    effects = []
    for link in tables["BuffCardStarEnchantBonus"]:
        if link["GroupID"] != group["ID"]:
            continue
        bonus = one("Bonus", ID=link["BonusID"])
        kind = one("BonusType", ID=bonus["BonusTypeID"])
        effects.append({"link": link, "bonus": bonus, "type": kind,
                        "unit": one("Unit", ID=kind["UnitID"]),
                        "ui_unit": one("UIUnit", UnitID=kind["UnitID"]),
                        "application_type": one("BonusApplicationType", ID=2) if bonus["BonusApplicationTypeID"] == 2 else {},
                        "application_target": one("SpecialResistanceType", ID=bonus["BonusApplicationTargetID"]) if bonus["BonusApplicationTypeID"] == 2 else {}})
    charge_steps = [r for r in tables["ChargeBonus"] if r["ChargeID"] == 21]
    charge_effects = []
    for link in tables["ChargeEffectBonus"]:
        steps = [r for r in charge_steps if r["ID"] == link["ChargeBonusID"]]
        if not steps or link["TargetSpellClassID"] != 82:
            continue
        bonus = one("Bonus", ID=link["BonusID"])
        typ = one("BonusType", ID=bonus["BonusTypeID"])
        charge_effects.append({"step": steps[0]["Step"], "link": link, "bonus": bonus, "type": typ})
    return {
        "schema": 1, "source_snapshot": "patch523", "archive_sha256": ARCHIVE_SHA256,
        "source_tables": evidence, "card": card, "group": group, "rules": rules,
        "content_control": control,
        "effects": effects,
        "charge": {"spell": one("SpellClass", ID=82), "steps": charge_steps, "effects": charge_effects,
                   "constants": [one("ConstantData", Name=n) for n in ["ChargeLongPressTriggerTime", "ChargeMaxTime", "ChargeMinTime"]]},
        "bonuses": [r for r in tables["BuffCardStarEnchantBonus"] if r["GroupID"] == group["ID"]],
        "sprite_options": [r for r in tables["BuffCardSpriteCustomizingOption"] if r["BuffCardID"] == card["ID"]],
        "grades": [one("Grade", ID=i) for i in sorted({r["SourceGradeID"] for r in rules})],
        "currencies": [one("Currency", ID=i) for i in sorted({r["CurrencyID"] for r in rules})],
        "max_level": one("ConstantData", Name="StarEnchantMaxLevel"),
        "server_limits": limit_rows, "unresolved_server_limit_sets": unresolved,
        "unresolved_semantics": ["probability_scale", "material_deck_and_duplicate_policy",
                                 "failure_stage_and_target_policy", "stage_bonus_aggregation"],
        "execution": "blocked_pending_source_semantics",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    data = build(args.archive)
    text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    if args.verify:
        if args.output.read_text(encoding="utf-8") != text:
            raise SystemExit("Halphas contract differs from original patch523 bytes")
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text, encoding="utf-8")
    print("HALPHAS_PATCH523_OK: 1 group, 3 stages; unresolved server sets:",
          data["unresolved_server_limit_sets"])


if __name__ == "__main__":
    main()
