"""Validate privately supplied smith/smelt tables; this module contains no raw dump."""
from collections import defaultdict

TABLES = [
    "ElementalSmith", "ElementalSmithAbleLevel", "ElementalSmithBonus",
    "ElementalSmithProbGroup", "ElementalSmithProbability",
    "ItemBlessReinforcement", "ItemBlessReinforcementBonus",
    "ItemBlessReinforcementGrade", "ItemBlessReinforcementGradeBonus",
    "ItemBlessReinforcementSlotAmount", "ItemSmelt", "ItemSmeltEntity",
    "ItemSpiritSmeltEntity", "ItemSmeltSlotActive", "ItemSmeltBonus",
    "ItemEquipSlot", "ItemBonus", "Bonus", "BonusType", "ItemClass", "ItemBlessCode",
]


def validate(tables):
    """Check foreign keys without rewriting weights or conflating zero with wildcard."""
    def rows(name):
        value = tables.get(name, [])
        return value.get("rows", []) if isinstance(value, dict) else value

    ids = {name: {int(r["ID"]) for r in rows(name) if "ID" in r} for name in TABLES}
    links = {
        "ElementalSmithProbability": [("ElementalSmithID", "ElementalSmith"), ("ElementalSmithProbGroupID", "ElementalSmithProbGroup")],
        "ElementalSmithBonus": [("ElementalSmithProbGroupID", "ElementalSmithProbGroup"), ("BonusID", "Bonus")],
        "ItemBlessReinforcementBonus": [("ItemBlessReinforcementID", "ItemBlessReinforcement"), ("BonusID", "Bonus")],
        "ItemSmeltEntity": [("ItemClassID", "ItemClass"), ("ItemSmeltID", "ItemSmelt")],
        "ItemSpiritSmeltEntity": [("ItemClassID", "ItemClass"), ("ItemSmeltID", "ItemSmelt")],
        "ItemSmeltSlotActive": [("ItemSmeltID", "ItemSmelt")],
        "ItemSmeltBonus": [("ItemSmeltID", "ItemSmelt"), ("BonusID", "Bonus")],
        "ItemBonus": [("ItemClassID", "ItemClass"), ("BonusID", "Bonus")],
    }
    for name, refs in links.items():
        for row in rows(name):
            for key, target in refs:
                if int(row[key]) not in ids[target]:
                    raise ValueError(f"{name}.{key}: missing {target} ID {row[key]}")
    totals = {}
    for name, group, weight in [
        ("ElementalSmithBonus", ("ElementalSmithProbGroupID", "ElementalTypeID"), "Probability"),
        ("ItemBlessReinforcementBonus", ("ItemBlessReinforcementID", "SlotNumber"), "Prob1"),
        ("ItemSmeltBonus", ("ItemSmeltID", "SlotNumber"), "Prob"),
    ]:
        sums = defaultdict(int)
        for row in rows(name):
            if int(row[weight]) < 0:
                raise ValueError(f"{name}: negative probability")
            sums[tuple(int(row[key]) for key in group)] += int(row[weight])
        totals[name] = [{"group": list(k), "total": v} for k, v in sums.items() if v != 10_000_000]
    # Parent probability rows are not an eligibility gate. Both independent
    # configuration joins must exist; unconfigured source pools remain audited.
    grade_keys = {(int(r["EquipSlotID"]), int(r["WeaponTypeID"]), int(r["GradeID"]))
                  for r in rows("ItemBlessReinforcementGrade")}
    slot_amounts = {(int(r["EquipSlotID"]), int(r["GradeID"])): int(r["SlotAmount"])
                    for r in rows("ItemBlessReinforcementSlotAmount")}
    bless_entries = {}
    for row in rows("ItemBlessReinforcement"):
        key = (int(row["EquipSlotID"]), int(row["WeaponTypeID"]), int(row["GradeID"]))
        amount = slot_amounts.get((key[0], key[2]), 0)
        grade_configured = key in grade_keys
        configured = grade_configured and amount > 0
        bless_entries[int(row["ID"])] = {
            "id": int(row["ID"]), "grade_configured": grade_configured,
            "slot_amount": amount, "configured_reachable": configured,
            "runtime_enabled": configured and not bool(row.get("IsTest", False)),
            "is_test": bool(row.get("IsTest", False)),
        }
    active_anomalies, unreachable_anomalies = [], []
    for anomaly in totals["ItemBlessReinforcementBonus"]:
        parent, slot = anomaly["group"]
        entry = bless_entries.get(parent, {})
        reachable = bool(entry.get("runtime_enabled", False)) and 1 <= slot <= entry.get("slot_amount", 0)
        anomaly["runtime_reachable"] = reachable
        anomaly["classification"] = "active_pool_anomaly" if reachable else "unreachable_source_pool_anomaly"
        (active_anomalies if reachable else unreachable_anomalies).append(anomaly.copy())
    blocked = {a["group"][0] for a in active_anomalies}
    runtime_ids = [i for i, e in bless_entries.items() if e["runtime_enabled"]]
    eligibility = {
        "gate": "exact_equip_slot_weapon_type_grade_and_slot_amount",
        "parent_count": len(bless_entries),
        "configured_reachable_count": sum(e["configured_reachable"] for e in bless_entries.values()),
        "runtime_enabled_config_ids": sorted(runtime_ids),
        "runtime_executable_config_ids": sorted(i for i in runtime_ids if i not in blocked),
        "unreachable_config_ids": sorted(i for i, e in bless_entries.items() if not e["configured_reachable"]),
        "entries": list(bless_entries.values()),
        "active_probability_anomalies": active_anomalies,
        "unreachable_source_probability_anomalies": unreachable_anomalies,
    }
    return {
        "bless_eligibility": eligibility,
        "row_counts": {n: len(rows(n)) for n in TABLES},
        "probability_anomalies": totals,
        "policies_required": ["costs", "bless_probability_column"],
        "spirit_bless_zero_default": "exact",
        "installed_expiry_bonus": "SmeltExpireDate",
        "consumable_expiry_bonus": "DeleteTime",
        "empty_grade_bonus_is_preserved": not rows("ItemBlessReinforcementGradeBonus"),
    }
