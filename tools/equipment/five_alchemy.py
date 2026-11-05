"""Validate private patch523 alchemy tables; never publish source rows."""

from collections import defaultdict

TABLES = [
    "AlchemyItem", "AlchemyRecipeType", "AlchemyResult", "AlchemyConstants",
    "AlchemyConstantByRecipeGroup", "AlchemyEnchantPriceGroup",
    "AlchemyElementalEnchantPriceGroup", "AlchemyBlessPriceGroup",
    "UIAlchemyRecipeMaterialItem", "UIAlchemyRecipeResultItem",
    "UIAlchemyDivinationProb", "Grade",
]


def validate(tables):
    """Return audit metadata, or fail before any private pack is emitted."""
    for name in TABLES:
        if not isinstance(tables.get(name), list) or not tables[name]:
            raise ValueError(f"alchemy: missing/non-array table {name}")
        ids = [row["ID"] for row in tables[name]]
        if len(ids) != len(set(ids)):
            raise ValueError(f"alchemy: duplicate ID in {name}")
    if not isinstance(tables.get("ItemClass"), list) or not tables["ItemClass"]:
        raise ValueError("alchemy: missing ItemClass table")
    items = {r["ID"] for r in tables["ItemClass"]}
    recipes = {r["ID"]: r for r in tables["AlchemyRecipeType"]}
    active = sorted(k for k, r in recipes.items() if r.get("IsEnabled"))
    if active != [63, 113]:
        raise ValueError("alchemy: patch523 must enable only Base63 and Law113")
    for name, keys in [
        ("AlchemyEnchantPriceGroup", ("GroupID", "Enchant")),
        ("AlchemyElementalEnchantPriceGroup", ("GroupID", "ElementalType", "Enchant")),
        ("AlchemyBlessPriceGroup", ("GroupID", "BlessCodeID")),
    ]:
        values = {}
        for row in tables[name]:
            key = tuple(row[k] for k in keys)
            if row["Price"] < 0 or (key in values and values[key] != row["Price"]):
                raise ValueError(f"alchemy: contradictory/negative price in {name}: {key}")
            values[key] = row["Price"]
    groups = {
        field: {r["GroupID"] for r in tables[name]}
        for field, name in [
            ("EnchantGroupID", "AlchemyEnchantPriceGroup"),
            ("ElementalEnchantGroupID", "AlchemyElementalEnchantPriceGroup"),
            ("BlessGroupID", "AlchemyBlessPriceGroup"),
        ]
    }
    seen = set()
    for row in tables["AlchemyItem"]:
        key = (row["ItemClassID"], row["RecipeTypeID"])
        if key in seen or key[0] not in items or key[1] not in recipes or row["BasePrice"] < 0:
            raise ValueError(f"alchemy: invalid material {key}")
        seen.add(key)
        for field, allowed in groups.items():
            if row[field] not in allowed:
                raise ValueError(f"alchemy: missing {field}: {row[field]}")
    pools = defaultdict(int)
    for row in tables["AlchemyResult"]:
        if (row["ItemClassID"] not in items or row["RecipeTypeID"] not in recipes
                or row["PriceLow"] < 0 or row["PriceHigh"] < row["PriceLow"]
                or row["Amount"] <= 0 or row["Probability"] < 0
                or row["ServerLimitSetID"] < 0):
            raise ValueError(f"alchemy: invalid result {row['ID']}")
        key = tuple(row[k] for k in ("RecipeTypeID", "PriceLow", "PriceHigh", "ServerLimitSetID"))
        pools[key] += row["Probability"]
    bad = {key: total for key, total in pools.items() if total != 10_000_000}
    if bad:
        raise ValueError(f"alchemy: result probability totals differ from 10000000: {bad}")
    recipe_groups = {r["GroupID"] for r in recipes.values()}
    for row in tables["AlchemyConstantByRecipeGroup"]:
        if row["GroupID"] not in recipe_groups or row["Value"] < 0:
            raise ValueError("alchemy: invalid recipe-group constant")
    return {
        "active_recipe_ids": active,
        "row_counts": {name: len(tables[name]) for name in TABLES},
        "result_pool_count": len(pools),
        "result_probability_total": 10_000_000,
        "formulas_verified": False,
        "evaluation_policy_required": True,
        "original_scope": "client content definitions; server evaluation/cost formula absent",
    }
