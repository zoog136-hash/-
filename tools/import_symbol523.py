#!/usr/bin/env python3
"""Project patch523 tables; separate original rows from authorized local models."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

SYMBOL_IDS = {"eva": 14, "sayha": 34, "maphr": 54, "paagrio": 64,
              "grankain": 81, "einhasad": 112, "shilen": 124}
# Explicit adapters to TWILIGHT's existing units. Unknown/conditional bonuses
# remain complete source records; they must never fall through to another stat.
ADAPTERS = {
    "HPPlus": ("max_hp:flat", 1), "MPPlus": ("max_mp:flat", 1),
    "HPPotionIncreasePercent": ("potion_percent:percent", .0001),
    "HPPotionIncreaseStatic": ("potion_flat:flat", 1),
    "ExperienceAdditionPercent": ("experience_bonus:percent", .0001),
    "EinasadSavingPercent": ("blessing_consumption:percent", .0001),
    "PotionConsumeDelayDecreasePercent": ("potion_cooldown:percent", .0001),
    "CarryPlus": ("weight_bonus:flat", .01),
    "MeleeDamage": ("melee_damage:flat", 1), "MeleeHit": ("melee_hit:flat", 1),
    "RangeDamage": ("ranged_damage:flat", 1), "RangeHit": ("ranged_hit:flat", 1),
    "SpellPower": ("sp:flat", 1), "MagicDamage": ("magic_damage:flat", 1),
    "MeleeCritical": ("melee_critical_rate:percent", 1),
    "RangeCritical": ("ranged_critical_rate:percent", 1),
    "RegenMP": ("mp_regeneration:flat", 1), "MagicResist": ("mr:flat", 1),
    "ArmorClass": ("ac:flat", -1), "DamageReduction": ("damage_reduction:flat", 1),
    "DamageReductionPercent": ("incoming_reduction:percent", .0001),
    "EinasadBlessAbsolutePercent": ("blessing_charge:percent", 1),
    "HPHealIncreasePercent": ("magic_heal:percent", .0001),
    "AttackDrainHP": ("hp_drain:flat", 1),
    "KarmaLife": ("life:flat", 1),
    "CriticalDamageReduction": ("critical_reduction:flat", 1),
    "CriticalMeleeDamage": ("melee_critical_damage:flat", 1),
    "CriticalRangeDamage": ("ranged_critical_damage:flat", 1),
    "CriticalMagicDamage": ("magic_critical_damage:flat", 1),
    "TeleportControl": ("teleport_control:flag", 1),
}

# Existing main world._normalize_option_policies converts PvP numerical
# options to PvE for the offline game. Keep this separate from native units.
SINGLE_PLAYER_ADAPTERS = {
    "PVPDamageReduction": ("pve_damage_reduction:flat", 1),
    "PVPDamageReductionPercent": ("pve_damage_reduction:percent", .0001),
    "PVPMeleeAdditionDamage": ("pve_melee_damage:flat", 1),
    "PVPRangeAdditionDamage": ("pve_ranged_damage:flat", 1),
    "PVPMagicAdditionDamage": ("pve_magic_damage:flat", 1),
    "PierceMeleeDamageReduction": ("melee_reduction_ignore:flat", 1),
    "PierceRangeDamageReduction": ("ranged_reduction_ignore:flat", 1),
    "PierceMagicDamageReduction": ("magic_reduction_ignore:flat", 1),
    "PiercePVPDamageReduction": ("pve_reduction_ignore:flat", 1),
    "PVPPierceMeleeEvasion": ("melee_evasion_ignore:flat", 1),
    "PVPPierceRangeEvasion": ("ranged_evasion_ignore:flat", 1),
}

ESTIMATED_ADAPTERS = {
    "KarmaDeath": ("local_death:flat", 1),
    "DamageDampOption": ("local_damage_damp:percent", .0001),
    "IgnoreDamageReductionPercent": ("local_ignore:percent", .0001),
    "IgnorePVPDamageReductionPercent": ("local_ignore:percent", .0001),
    "IgnoreMeleeDamageReductionPercent": ("local_melee_ignore:percent", .0001),
    "IgnoreRangeDamageReductionPercent": ("local_ranged_ignore:percent", .0001),
    "IgnoreMagicDamageReductionPercent": ("local_magic_ignore:percent", .0001),
    "AttackedMeleeDamageScaleForArmorBreak": ("local_armorbreak_melee:percent", -.0001),
    "AttackedDarkDamageScaleForArmorBreak": ("local_armorbreak_dark:percent", -.0001),
    "AttackedMeleeMagicDamageScaleForArmorBreak": ("local_armorbreak_magic:percent", -.0001),
    "ResistIgnoreDamageReductionPercent": ("local_reduction_efficiency:percent", .0001),
}


def build(source: Path, crosslinks: Path) -> dict:
    with zipfile.ZipFile(source) as archive, zipfile.ZipFile(crosslinks) as links:
        assert archive.testzip() is None and links.testzip() is None
        used = {}

        def table(name):
            raw = archive.read(f"content/{name}.json")
            used[name] = {"sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw)}
            return json.loads(raw.decode("utf-8-sig"))["rows"]

        def cross(name):
            return json.loads(links.read(f"symbol-guardian-crosslinks-523/{name}.json"))

        bonuses = {r["ID"]: r for r in table("Bonus")}
        types = {r["ID"]: r for r in table("BonusType")}
        units = {r["ID"]: r for r in table("Unit")}
        desc = {r["ID"]: r for r in table("DescData_Korean")}
        normal, absolute = table("SymbolBonus"), table("SymbolAbsoluteBonusView")
        costs = table("SymbolEnchantCost")
        symbols = table("SymbolType")
        resistance_types = {r["ID"]: r for r in table("SpecialResistanceType")}
        intervals = table("IntervalBonus")
        interval_categories = {r["ID"]: r for r in table("IntervalBonusCategory")}
        invoke = next(r for r in table("InvokeOption") if r["ID"] == 15333)
        invoke_type = next(r for r in table("InvokeOptionType") if r["ID"] == invoke["InvokeOptionTypeID"])
        assert invoke_type["Name"] == "Defence_DamageReduction" and invoke["Param1"] == 300 and invoke["Param3"] == invoke["Param6"] == 0

        def detail(row):
            bonus = bonuses[row["BonusID"]]
            kind = types[bonus["BonusTypeID"]]
            adapter = ADAPTERS.get(kind["Name"])
            local_policy = ""
            if adapter is None and kind["Name"] in SINGLE_PLAYER_ADAPTERS:
                adapter = SINGLE_PLAYER_ADAPTERS[kind["Name"]]
                local_policy = ("TWILIGHT existing offline PvP numerical bonus to PvE"
                                if kind["Name"].startswith("PVP") or kind["Name"] == "PiercePVPDamageReduction"
                                else "TWILIGHT existing offline flat-ignore extra damage")
            if adapter is None and kind["Name"] in ESTIMATED_ADAPTERS:
                adapter = ESTIMATED_ADAPTERS[kind["Name"]]
                local_policy = "estimate: configurable TWILIGHT combat model; not original server formula"
            mapped = {}
            if adapter and bonus["BonusApplicationTypeID"] == 0 and bonus["BonusApplicationTargetID"] == 0:
                mapped[adapter[0]] = round(bonus["Value"] * adapter[1], 6)
            nested = []
            application_target = {}
            display_name = desc.get(kind["DescID"], {}).get("Description", kind["Name"])
            if kind["Name"] == "InvokeOption" and bonus["BonusApplicationTypeID"] == 10 and bonus["BonusApplicationTargetID"] == 15333:
                mapped["veil_proc:percent"] = bonus["Value"] / 10000
                display_name = "실렌의 장막 · 피격 리덕션300 발동률"
            if kind["Name"] == "DamageReductionForSpellAttackWeapon" and bonus["BonusApplicationTypeID"] == 221 and bonus["BonusApplicationTargetID"] == 1:
                mapped["local_rapid_reduction:flat"] = bonus["Value"]
                local_policy = "estimate: boss volley as rapid-fire context"
            if kind["Name"] == "DamageDampOption" and bonus["BonusApplicationTypeID"] == 14 and bonus["BonusApplicationTargetID"] == 13:
                mapped["local_damage_damp:percent"] = bonus["Value"] / 10000
                local_policy = "estimate: category13 has no exported implementation; configured consecutive-hit window"
            if bonus["BonusApplicationTypeID"] == 2:
                target = resistance_types.get(bonus["BonusApplicationTargetID"], {})
                application_target = target
                if kind["Name"] == "SpecialResistance" and target.get("Name") in {"Stun", "Fear"}:
                    mapped[{"Stun":"stun_resistance:percent", "Fear":"fear_resistance:percent"}[target["Name"]]] = bonus["Value"] / 10000
                    display_name = desc[target["DescID"]]["Description"] + " 내성"
                elif kind["Name"] == "HitSpecialResistance" and target.get("Name") == "Stun":
                    mapped["stun_hit:percent"] = bonus["Value"] / 10000
                    display_name = desc[target["DescID"]]["Description"] + " 적중"
                elif kind["Name"] == "DamageReductionForSpecialDebuff" and target.get("Name") == "Stun":
                    mapped["stunned_reduction:flat"] = bonus["Value"]
            if kind["Name"] == "HPIntervalBonus" and bonus["Value"] == 12:
                for interval in intervals:
                    if interval["IntervalBonusCategory"] != 12: continue
                    reward = bonuses[interval["BonusID"]]
                    assert types[reward["BonusTypeID"]]["Name"] == "DamageReductionPercent"
                    assert reward["BonusApplicationTypeID"] == reward["BonusApplicationTargetID"] == 0
                    nested.append({"row":interval,"bonus":reward,"bonus_type":types[reward["BonusTypeID"]],"category":interval_categories[12]})
                assert len(nested) == 1 and nested[0]["row"]["Low"] == 0 and nested[0]["row"]["High"] == 30
                mapped["low_hp_reduction:percent"] = nested[0]["bonus"]["Value"] / 10000
            return {"row": row, "bonus": bonus, "bonus_type": kind,
                    "unit": units[kind["UnitID"]],
                    "description": desc.get(kind["DescID"], {}),
                    "effects": mapped, "status": "applied" if mapped else "deferred",
                    "local_policy": local_policy if mapped else "",
                    "display_name":display_name, "nested_intervals":nested,
                    "application_target":application_target}

        emblems = {}
        for local, sid in SYMBOL_IDS.items():
            definition = next(r for r in symbols if r["ID"] == sid)
            ns = [detail(r) for r in normal if r["SymbolTypeID"] == sid]
            absolutes = [detail(r) for r in absolute if r["SymbolTypeID"] == sid]
            totals, stages = {}, [{}]
            for stage in range(1, 31):
                for record in ns:
                    if record["row"]["Enchant"] == stage:
                        for key, value in record["effects"].items():
                            totals[key] = round(totals.get(key, 0) + value, 6)
                stages.append(dict(totals))
            grade_records = {}
            for grade in range(1, 6):
                records = [r for r in absolutes if r["row"]["Grade"] == grade]
                payment = [r["row"] for r in records if r["row"]["OpenCost"] > 0]
                assert len(payment) == 1
                grade_records[str(grade)] = {"payment": payment[0], "options": records}
            symbol_costs = sorted((r for r in costs if r["SymbolTypeID"] == sid), key=lambda r: r["EnchantCount"])
            assert [r["EnchantCount"] for r in symbol_costs] == list(range(20))
            emblems[local] = {"definition": definition, "costs": symbol_costs,
                              "normal": ns, "effects": stages, "absolute": grade_records}

        recharge = cross("blesspoint_recharge_paths")
        backing = cross("currency_backing_and_legacy_items")
        shop = cross("blesspoint_shop_paths")
        item_ids = {r["ItemClassID"] for r in recharge} | {349704, 352334, 352344}
        item_ids |= set(backing["current_Currency712_item_ids"])
        items = {r["ID"]: r for r in table("ItemClass") if r["ID"] in item_ids}
        grade_ids = {r["GradeID"] for r in items.values()}
        grades = {str(r["ID"]): {"row": r, "name_ko": desc.get(r["DescID"], {}).get("Description", r["Name"])}
                  for r in table("Grade") if r["ID"] in grade_ids}
        item_bonus = [r for r in table("ItemBonus") if r["ItemClassID"] in item_ids]
        application_types = {r["ID"]: r for r in table("BonusApplicationType")}
        delete_values = {bonuses[r["BonusID"]]["BonusApplicationTargetID"] for r in item_bonus
                         if types[bonuses[r["BonusID"]]["BonusTypeID"]]["Name"] == "DeleteTime"
                         and bonuses[r["BonusID"]]["BonusApplicationTypeID"] == 298}
        date_rows = [r for r in table("DateTimes_Korean") if r["ID"] in delete_values]
        return {
            "schema": 1, "source_snapshot": "patch523",
            "source_archives": [{"name": p.name, "bytes": p.stat().st_size,
                                 "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in (source, crosslinks)],
            "tables": used, "emblems": emblems,
            "constants": table("SymbolConstant"), "probabilities": table("SymbolEnchantProbability"),
            "payments": table("SymbolPayment"), "enchant_levels": table("SymbolEnchant"),
            "recharge": recharge, "shop": shop, "currency_backing": backing,
            "items": {str(k): v for k, v in items.items()},
            "item_names": {str(k): desc.get(v["DescID"], {}).get("Description", v["Name"]) for k, v in items.items()},
            "item_grades": grades,
            "item_bonuses": [{"row": r, "bonus": bonuses[r["BonusID"]],
                              "type": types[bonuses[r["BonusID"]]["BonusTypeID"]]}
                             for r in item_bonus],
            "dates": date_rows,
            "delete_time_application": application_types[298],
            "ui_evidence": cross("relevant_ui_source"),
            "local_adapters": ADAPTERS,
            "single_player_adapters": SINGLE_PLAYER_ADAPTERS,
            "estimated_adapters": ESTIMATED_ADAPTERS,
            "veil_invoke": {"option": invoke, "type": invoke_type},
            "unresolved": ["ServerLimitSet1294 and shop512 direction/context",
                           "daily reset count/reset time",
                           "probability range sampling denominator and special-route event ordering",
                           "saved enhancement restoration payment/current availability",
                           "original server death/percent-ignore/damp/rapid-fire/armorbreak/efficiency formulas; explicit local models execute instead"],
        }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("crosslinks", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    result = build(args.source, args.crosslinks)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, separators=(",", ":")) + "\n")
    print("SYMBOL523_PROJECTED", len(result["emblems"]), len(result["recharge"]), len(result["probabilities"]))
