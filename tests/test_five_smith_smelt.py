"""Small fabricated tables exercise validation failures without redistributing originals."""
import importlib.util
from pathlib import Path
import unittest

MODULE = Path(__file__).resolve().parents[1] / "tools/equipment/five_smith_smelt.py"
spec = importlib.util.spec_from_file_location("five_smith_smelt", MODULE)
smith = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smith)


class SmithSmeltValidationTest(unittest.TestCase):
    def tables(self):
        return {
            "ItemClass": [{"ID": 1}], "Bonus": [{"ID": 2}],
            "ItemSmelt": [{"ID": 3}],
            "ItemSmeltEntity": [{"ID": 4, "ItemClassID": 1, "ItemSmeltID": 3}],
            "ItemSmeltBonus": [{"ID": 5, "ItemSmeltID": 3, "SlotNumber": 1, "BonusID": 2, "Prob": 10_000_000}],
        }

    def test_valid_pool_and_empty_grade_table(self):
        result = smith.validate(self.tables())
        self.assertEqual(result["probability_anomalies"]["ItemSmeltBonus"], [])
        self.assertTrue(result["empty_grade_bonus_is_preserved"])

    def test_bad_probability_is_reported_and_never_rewritten(self):
        tables = self.tables()
        tables["ItemSmeltBonus"][0]["Prob"] = 10_050_000
        result = smith.validate(tables)
        self.assertEqual(result["probability_anomalies"]["ItemSmeltBonus"][0]["total"], 10_050_000)
        self.assertEqual(tables["ItemSmeltBonus"][0]["Prob"], 10_050_000)

    def test_missing_bonus_fails(self):
        tables = self.tables()
        tables["Bonus"] = []
        with self.assertRaisesRegex(ValueError, "missing Bonus ID 2"):
            smith.validate(tables)

    def test_missing_target_fails(self):
        tables = self.tables()
        tables["ItemClass"] = []
        with self.assertRaisesRegex(ValueError, "missing ItemClass ID 1"):
            smith.validate(tables)

    def bless_tables(self):
        tables = self.tables()
        tables.update({
            "ItemBlessReinforcementGrade": [{"EquipSlotID": 8, "WeaponTypeID": 1, "GradeID": 4}],
            "ItemBlessReinforcementSlotAmount": [{"EquipSlotID": 8, "GradeID": 4, "SlotAmount": 1}],
            "ItemBlessReinforcement": [
                {"ID": 10, "EquipSlotID": 8, "WeaponTypeID": 1, "GradeID": 4, "IsTest": False},
                {"ID": 11, "EquipSlotID": 8, "WeaponTypeID": 1, "GradeID": 52, "IsTest": False},
                {"ID": 12, "EquipSlotID": 8, "WeaponTypeID": 1, "GradeID": 4, "IsTest": True},
            ],
            "ItemBlessReinforcementBonus": [
                {"ItemBlessReinforcementID": 10, "SlotNumber": 1, "BonusID": 2, "Prob1": 10_000_000},
                {"ItemBlessReinforcementID": 11, "SlotNumber": 1, "BonusID": 2, "Prob1": 10_050_000},
                {"ItemBlessReinforcementID": 12, "SlotNumber": 1, "BonusID": 2, "Prob1": 10_000_000},
            ],
        })
        return tables

    def test_unreachable_source_anomaly_does_not_block_active_configuration(self):
        result = smith.validate(self.bless_tables())["bless_eligibility"]
        self.assertEqual(result["configured_reachable_count"], 2)
        self.assertEqual(result["runtime_enabled_config_ids"], [10])
        self.assertEqual(result["runtime_executable_config_ids"], [10])
        self.assertEqual(result["unreachable_config_ids"], [11])
        self.assertEqual(result["active_probability_anomalies"], [])
        self.assertEqual(result["unreachable_source_probability_anomalies"][0]["group"], [11, 1])

    def test_active_anomaly_blocks_only_its_parent(self):
        tables = self.bless_tables()
        tables["ItemBlessReinforcementBonus"][0]["Prob1"] = 10_050_000
        result = smith.validate(tables)["bless_eligibility"]
        self.assertEqual(result["runtime_enabled_config_ids"], [10])
        self.assertEqual(result["runtime_executable_config_ids"], [])
        self.assertEqual(result["active_probability_anomalies"][0]["group"], [10, 1])

    def test_grade_match_includes_weapon_type(self):
        tables = self.bless_tables()
        tables["ItemBlessReinforcementGrade"][0]["WeaponTypeID"] = 2
        result = smith.validate(tables)["bless_eligibility"]
        self.assertEqual(result["configured_reachable_count"], 0)
        self.assertEqual(result["runtime_enabled_config_ids"], [])

    def test_negative_weight_fails(self):
        tables = self.tables()
        tables["ItemSmeltBonus"][0]["Prob"] = -1
        with self.assertRaisesRegex(ValueError, "negative probability"):
            smith.validate(tables)


if __name__ == "__main__":
    unittest.main()
