"""Small synthetic validator regressions; no third-party source data."""
import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools" / "equipment"))
import five_alchemy


def fixture():
    tables = {name: [{"ID": 0}] for name in five_alchemy.TABLES}
    tables.update({
        "ItemClass": [{"ID": 501}, {"ID": 1001}],
        "AlchemyRecipeType": [
            {"ID": 63, "GroupID": 3, "IsEnabled": True},
            {"ID": 74, "GroupID": 3, "IsEnabled": False},
            {"ID": 113, "GroupID": 13, "IsEnabled": True},
        ],
        "AlchemyItem": [{"ID": 1, "ItemClassID": 501, "RecipeTypeID": 63,
                         "BasePrice": 7, "EnchantGroupID": 1,
                         "ElementalEnchantGroupID": 1, "BlessGroupID": 1}],
        "AlchemyEnchantPriceGroup": [{"ID": 1, "GroupID": 1, "Enchant": 1, "Price": 0}],
        "AlchemyElementalEnchantPriceGroup": [
            {"ID": 1, "GroupID": 1, "ElementalType": 1, "Enchant": 1, "Price": 0}],
        "AlchemyBlessPriceGroup": [{"ID": 1, "GroupID": 1, "BlessCodeID": 1, "Price": 0}],
        "AlchemyConstantByRecipeGroup": [{"ID": 1, "GroupID": 3, "Value": 100000}],
        "AlchemyResult": [{"ID": 1, "ItemClassID": 1001, "RecipeTypeID": 63,
                           "PriceLow": 20, "PriceHigh": 29, "Amount": 1,
                           "Probability": 10000000, "ServerLimitSetID": 0}],
    })
    return tables


class AlchemyValidationTests(unittest.TestCase):
    def test_metadata_and_source_not_mutated(self):
        tables = fixture()
        before = copy.deepcopy(tables)
        result = five_alchemy.validate(tables)
        self.assertEqual(result["active_recipe_ids"], [63, 113])
        self.assertEqual(result["result_pool_count"], 1)
        self.assertFalse(result["formulas_verified"])
        self.assertEqual(tables, before)

    def test_identical_bless_rows_preserved_and_conflicts_rejected(self):
        tables = fixture()
        tables["AlchemyBlessPriceGroup"].append(
            {"ID": 2, "GroupID": 1, "BlessCodeID": 1, "Price": 0})
        result = five_alchemy.validate(tables)
        self.assertEqual(result["row_counts"]["AlchemyBlessPriceGroup"], 2)
        tables["AlchemyBlessPriceGroup"][1]["Price"] = 7
        with self.assertRaisesRegex(ValueError, "contradictory"):
            five_alchemy.validate(tables)

    def test_exact_pool_key_includes_server_and_interval(self):
        tables = fixture()
        for row_id, server, low, high in [(2, 999, 20, 29), (3, 0, 21, 30)]:
            row = dict(tables["AlchemyResult"][0], ID=row_id, ServerLimitSetID=server,
                       PriceLow=low, PriceHigh=high)
            tables["AlchemyResult"].append(row)
        self.assertEqual(five_alchemy.validate(tables)["result_pool_count"], 3)
        tables["AlchemyResult"][1]["Probability"] = 9000000
        with self.assertRaisesRegex(ValueError, "probability totals"):
            five_alchemy.validate(tables)

    def test_recipe_specific_materials_retained(self):
        tables = fixture()
        tables["AlchemyItem"].append(dict(tables["AlchemyItem"][0], ID=2, RecipeTypeID=113))
        self.assertEqual(five_alchemy.validate(tables)["row_counts"]["AlchemyItem"], 2)
        tables["AlchemyItem"][1]["RecipeTypeID"] = 63
        with self.assertRaisesRegex(ValueError, "invalid material"):
            five_alchemy.validate(tables)

    def test_invalid_references_disabled_rules_and_groups_fail(self):
        mutations = [
            lambda t: t["AlchemyItem"][0].update(ItemClassID=999),
            lambda t: t["AlchemyItem"][0].update(EnchantGroupID=999),
            lambda t: t["AlchemyResult"][0].update(RecipeTypeID=999),
            lambda t: t["AlchemyRecipeType"][1].update(IsEnabled=True),
            lambda t: t["AlchemyResult"][0].update(PriceHigh=19),
            lambda t: t["AlchemyResult"][0].update(Amount=0),
        ]
        for mutation in mutations:
            tables = fixture()
            mutation(tables)
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                five_alchemy.validate(tables)


if __name__ == "__main__":
    unittest.main()
