"""Validate private 523 set and invoke-replacement joins without publishing rows.

The build owner supplies decoded tables. This module emits counts only; source
tables and their resolved spell contracts stay in the user's private pack.
"""
from collections import Counter, defaultdict

TABLES = (
    "ItemSet", "ItemForItemSet", "ItemSetBonus", "ItemBonus",
    "ItemInvokeReplacement", "ItemInvokeReplacementEntityView",
    "ItemInvokeReplacementBonusGroup", "ItemInvokeReplacementBonus",
    "InvokeOption", "InvokeOptionType", "SpellClass", "SpellBonus",
    "BuffClass", "BuffBonus", "SpellMaterialType",
)


def _index(tables, name):
    rows = tables.get(name, [])
    ids = [r["ID"] for r in rows]
    if len(ids) != len(set(ids)):
        raise ValueError(f"duplicate {name} ID")
    return dict(zip(ids, rows))


def validate(tables):
    """Reject dangling joins and incomplete probability slots before packing."""
    sets = _index(tables, "ItemSet")
    items = _index(tables, "ItemClass")
    bonuses = _index(tables, "Bonus")
    types = _index(tables, "BonusType")
    replacements = _index(tables, "ItemInvokeReplacement")
    groups = _index(tables, "ItemInvokeReplacementBonusGroup")
    invokes = _index(tables, "InvokeOption")
    members = set()
    for row in tables.get("ItemForItemSet", []):
        pair = (row["ItemSetID"], row["ItemClassID"])
        if pair in members or pair[0] not in sets or pair[1] not in items:
            raise ValueError("invalid or duplicate set membership")
        members.add(pair)
    for row in tables.get("ItemSetBonus", []):
        if row["ItemSetID"] not in sets or row["BonusID"] not in bonuses or row["CompletionDegree"] < 1:
            raise ValueError("invalid set bonus join")
    slots = defaultdict(int)
    seen = set()
    for row in tables.get("ItemInvokeReplacementEntityView", []):
        key = (row["ItemInvokeReplacementID"], row["SlotNumber"])
        candidate = (*key, row["ItemInvokeReplacementBonusGroupID"])
        if key[0] not in replacements or key[1] < 1 or candidate in seen or row["ItemInvokeReplacementBonusGroupID"] not in groups:
            raise ValueError("invalid replacement slot join")
        if not isinstance(row["Prob"], int) or not 0 <= row["Prob"] <= 1_000_000:
            raise ValueError("invalid replacement weight")
        slots[key] += row["Prob"]
        seen.add(candidate)
    if any(total != 1_000_000 for total in slots.values()):
        raise ValueError("replacement slot weights do not sum to 1000000")
    invoke_types = Counter()
    for row in tables.get("ItemInvokeReplacementBonus", []):
        if row["ItemInvokeReplacementBonusGroupID"] not in groups or row["BonusID"] not in bonuses or row["EnchantLevel"] < 0 or row["BlessCode"] not in (0, 1, 2):
            raise ValueError("invalid replacement bonus join")
        bonus = bonuses[row["BonusID"]]
        kind = types.get(bonus["BonusTypeID"], {})
        option = invokes.get(bonus["BonusApplicationTargetID"], {})
        if kind.get("Name") != "InvokeOption" or kind.get("UnitID") != 3 or bonus["BonusApplicationTypeID"] != 10 or not option:
            raise ValueError("replacement bonus is not a typed invoke")
        if not 0 <= bonus["Value"] <= 1_000_000:
            raise ValueError("invalid invoke probability")
        invoke_types[str(option["InvokeOptionTypeID"])] += 1
    return {
        "sets": len(sets), "set_memberships": len(members),
        "set_effect_rows": len(tables.get("ItemSetBonus", [])),
        "invoke_replacements": len(replacements), "invoke_slots": len(slots),
        "invoke_candidate_rows": len(tables.get("ItemInvokeReplacementEntityView", [])),
        "invoke_bonus_rows": len(tables.get("ItemInvokeReplacementBonus", [])),
        "invoke_types": dict(invoke_types),
    }
