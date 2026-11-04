"""Focused contract checks; no private original rows are embedded here."""
import copy
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("five_set_invoke", ROOT / "tools/equipment/five_set_invoke.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def fixture():
    return {
        "ItemClass": [{"ID": 91}], "ItemSet": [{"ID": 7}],
        "ItemForItemSet": [{"ItemSetID": 7, "ItemClassID": 91}],
        "ItemSetBonus": [{"ItemSetID": 7, "BonusID": 2, "CompletionDegree": 1}],
        "BonusType": [{"ID": 1, "Name": "InvokeOption", "UnitID": 3}],
        "Bonus": [{"ID": 2, "BonusTypeID": 1, "Value": 5000, "BonusApplicationTypeID": 10, "BonusApplicationTargetID": 8}],
        "InvokeOption": [{"ID": 8, "InvokeOptionTypeID": 1}],
        "ItemInvokeReplacement": [{"ID": 9}],
        "ItemInvokeReplacementBonusGroup": [{"ID": 10}, {"ID": 11}],
        "ItemInvokeReplacementEntityView": [
            {"ItemInvokeReplacementID": 9, "SlotNumber": 3, "ItemInvokeReplacementBonusGroupID": 10, "Prob": 300000},
            {"ItemInvokeReplacementID": 9, "SlotNumber": 3, "ItemInvokeReplacementBonusGroupID": 11, "Prob": 700000}],
        "ItemInvokeReplacementBonus": [{"ItemInvokeReplacementBonusGroupID": 10, "BonusID": 2, "EnchantLevel": 0, "BlessCode": 0}],
    }


class SourceJoinTests(unittest.TestCase):
    def test_empty_none_group_is_a_valid_outcome(self):
        data = fixture()
        self.assertEqual(MODULE.validate(data)["invoke_slots"], 1)

    def test_probability_is_checked_per_slot_not_across_weapon(self):
        data = fixture()
        other = copy.deepcopy(data["ItemInvokeReplacementEntityView"])
        for row in other:
            row["SlotNumber"] = 4
        data["ItemInvokeReplacementEntityView"].extend(other)
        self.assertEqual(MODULE.validate(data)["invoke_slots"], 2)
        data["ItemInvokeReplacementEntityView"][0]["Prob"] -= 1
        with self.assertRaisesRegex(ValueError, "sum"):
            MODULE.validate(data)

    def test_source_membership_cannot_be_guessed_from_names(self):
        data = fixture()
        data["ItemForItemSet"][0]["ItemClassID"] = 999
        with self.assertRaisesRegex(ValueError, "membership"):
            MODULE.validate(data)

    def test_untyped_invoke_probability_is_rejected(self):
        data = fixture()
        data["BonusType"][0]["UnitID"] = 1
        with self.assertRaisesRegex(ValueError, "typed invoke"):
            MODULE.validate(data)

    def test_negative_outcome_and_duplicate_membership_are_rejected(self):
        for mutation in ("weight", "member"):
            data = fixture()
            if mutation == "weight":
                data["ItemInvokeReplacementEntityView"][0]["Prob"] = -1
            else:
                data["ItemForItemSet"].append(data["ItemForItemSet"][0].copy())
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                MODULE.validate(data)


if __name__ == "__main__":
    unittest.main()
