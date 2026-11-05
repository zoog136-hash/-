"""Synthetic effects-extension builder regressions. No original rows are fixtures."""
from copy import deepcopy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

TOOLS = Path(__file__).resolve().parents[1] / "tools" / "equipment"
sys.path.insert(0, str(TOOLS))
import build_five_effects as builder
from build_five_systems import effect


def fixture_tables():
    def bonus(identity, kind, value, app=0, target=0):
        return dict(ID=identity, BonusTypeID=kind, Value=value,
                    BonusApplicationTypeID=app, BonusApplicationTargetID=target)
    kinds = [(1, "InvokeOption", 3), (2, "HPIntervalBonus", 10674),
             (3, "BuffClassID", 16), (4, "SpellDebuffMinDuration", 17),
             (5, "SpellDebuffMaxDuration", 17), (6, "MeleeDamage", 1),
             (7, "NextSpellClassID", 12), (8, "PVPDamageReduction", 1),
             (9, "CounterAssult", 3), (10, "FixedDesc", 41)]
    definitions = [dict(ID=i, Name=name, UnitID=unit, DescID=0) for i, name, unit in kinds]
    spells = [dict(ID=i, TargettingTypeID=1, TargetKindID=0, SiegeTargetKindID=0,
                   ElementalTypeID=0, CastGroupID=1, SpellGroupID=1, MPCostUnit=1)
              for i in [100, 101, 102, 200]]
    return {
        "BonusType": definitions,
        "Bonus": [bonus(10,1,500000,10,1000), bonus(20,2,200),
                  bonus(21,1,1000000,10,1001), bonus(30,3,400),
                  bonus(31,4,3), bonus(32,5,4), bonus(33,6,-5),
                  bonus(34,3,401), bonus(35,8,-10), bonus(36,7,102), bonus(37,3,402),
                  bonus(40,9,15,381,194),bonus(41,10,1,72,99)],
        "InvokeOption": [dict(ID=1000, InvokeOptionTypeID=1, Param1=100, AttackTypeID=0),
                         dict(ID=1001, InvokeOptionTypeID=2, Param1=101, AttackTypeID=0)],
        "InvokeOptionType": [dict(ID=i, Name="Synthetic", Param1Unit=12) for i in [1,2]],
        "SpellClass": spells,
        "SpellBonus": [dict(ID=i, SpellClassID=spell, BonusID=bonus_id, MinSpellLevel=0)
                       for i,spell,bonus_id in [(1,100,30),(2,100,31),(3,100,32),
                                                (4,101,34),(5,101,36),(6,102,37)]],
        "BuffClass": [dict(ID=i, BuffGroupID=1, Name="Synthetic") for i in [9,400,401,402]],
        "BuffBonus": [dict(ID=1, BuffClassID=400, BonusID=33),
                      dict(ID=2, BuffClassID=401, BonusID=40)],
        "BuffGroup": [dict(ID=1, Name="Synthetic")],
        "BuffStack": [dict(ID=10, BuffClassID=401, StackCount=1)],
        "BuffStackBonus": [dict(ID=11, BuffStackID=10, BonusID=35)],
        "IntervalBonusCategory": [dict(ID=200, Name="Synthetic")],
        "IntervalBonus": [dict(ID=201, IntervalBonusCategory=200, Low=0, High=20, BonusID=21)],
        "Unit": [dict(ID=i, Name=name) for i,name in [(1,"Value"),(3,"Percentage"),
                    (12,"SpellClassID"),(16,"BuffClassID"),(17,"Seconds"),
                    (20,"TrueFalse"),(41,"DescID"),(10674,"IntervalBonusCategoryID"),(10431,"AttackTypeID")]],
        "BonusApplicationType": [dict(ID=0,Name="Character"),dict(ID=10,Name="InvokeOption"),
                                 dict(ID=381,Name="UniversalGroup"),dict(ID=72,Name="Desc")],
        "TargettingType": [dict(ID=1,Name="Self")],
        "TargetKind": [dict(ID=0,Name="None")],
        "AttackType": [dict(ID=0,Name="All"),dict(ID=1,Name="Melee")],
        "UniversalGroupSet": [dict(ID=50,GroupID=194,UnitID=10431,Value=1)],
        "ElementalType": [dict(ID=0,Name="None")],
        "SpellCastGroup": [dict(ID=1,Name="Synthetic")],
        "SpellGroup": [dict(ID=1,Name="Synthetic")],
        "DescData_Korean": [dict(ID=99,Description="Synthetic source caption")],
    }


class EffectsBuilderTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="synthetic-equipment-effects-")
        self.root = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def prepare(self, tables=None, mutate_base=None):
        tables = deepcopy(tables or fixture_tables())
        archive = self.root / "synthetic.zip"
        content = self.root / "content"
        content.mkdir(exist_ok=True)
        with zipfile.ZipFile(archive,"w") as z:
            for name, rows in tables.items():
                data = ("\ufeff" + json.dumps({"rows":rows})).encode()
                z.writestr("content/"+name+".json",data)
                (content/(name+".json")).write_bytes(data)
        source_sha = builder.sha256(archive.read_bytes())
        raw = next(r for r in tables["Bonus"] if r["ID"] == 20)
        kind = next(r for r in tables["BonusType"] if r["ID"] == raw["BonusTypeID"])
        base = {"schema":builder.BASE_SCHEMA,"source_sha256":source_sha,
                "tables":{"ItemInvokeReplacementEntityView":[
                    {"ID":1,"ItemInvokeReplacementID":1,"SlotNumber":1,"ItemInvokeReplacementBonusGroupID":1,"Prob":500000},
                    {"ID":2,"ItemInvokeReplacementID":1,"SlotNumber":1,"ItemInvokeReplacementBonusGroupID":2,"Prob":500000}],
                    "ItemInvokeReplacementBonus":[{"ID":1,"ItemInvokeReplacementBonusGroupID":1,"BonusID":10}],
                    "ItemSetBonus":[{"ID":1,"ItemSetID":1,"BonusID":20},{"ID":2,"ItemSetID":1,"BonusID":41}],
                    "ItemSet":[{"ID":1,"BuffClassID":9}],
                    "Bonus":[deepcopy(raw)],"BonusType":[deepcopy(kind)]},
                "bonuses":{"20":effect(deepcopy(raw),deepcopy(kind),{})}}
        caption = next(r for r in tables["Bonus"] if r["ID"] == 41)
        caption_kind = next(r for r in tables["BonusType"] if r["ID"] == caption["BonusTypeID"])
        base["tables"]["Bonus"].append(deepcopy(caption))
        base["tables"]["BonusType"].append(deepcopy(caption_kind))
        base["bonuses"]["41"] = effect(deepcopy(caption),deepcopy(caption_kind),{})
        if mutate_base: mutate_base(base)
        base_path = self.root / "base.json"
        base_path.write_text(json.dumps(base))
        pins = {"BASE_SHA":builder.sha256(base_path.read_bytes()),
                "BASE_BYTES":base_path.stat().st_size,"SOURCE_SHA":source_sha}
        return base_path,archive,content,pins

    def build(self, prepared, output=None, content=True):
        base,archive,extraction,pins = prepared
        output = output or self.root / "extension.json"
        with patch.multiple(builder,**pins):
            result = builder.build_extension(base,archive,output,extraction if content else None)
        return result,json.loads(output.read_text())

    def test_typed_recursive_closure_and_immutable_base(self):
        prepared = self.prepare()
        before = prepared[0].read_bytes()
        receipt, extension = self.build(prepared)
        self.assertEqual(prepared[0].read_bytes(),before)
        self.assertEqual(extension["schema"],"patch523-equipment-effects-v1")
        self.assertEqual(extension["base_sha256"],prepared[3]["BASE_SHA"])
        self.assertEqual(extension["audit"]["roots"]["variable_debuff_spell_ids"],[100])
        self.assertEqual(extension["audit"]["missing_references"],[])
        self.assertEqual({r["ID"] for r in extension["tables"]["SpellClass"]},{100,101,102})
        self.assertEqual({r["ID"] for r in extension["tables"]["BuffClass"]},{9,400,401,402})
        self.assertEqual(extension["tables"]["BuffStackBonus"][0]["BonusID"],35)
        self.assertNotIn("20",extension["bonuses"])
        self.assertNotIn(20,{r["ID"] for r in extension["tables"]["Bonus"]})
        self.assertFalse(extension["audit"]["base_cache_rebuilt"])
        self.assertFalse(extension["audit"]["source_execution_equivalent"])
        self.assertEqual(receipt["sha256"],builder.sha256((self.root/"extension.json").read_bytes()))

    def test_same_integer_does_not_cross_typed_namespace(self):
        _,extension = self.build(self.prepare())
        self.assertIn(200,{r["ID"] for r in extension["tables"]["IntervalBonusCategory"]})
        self.assertNotIn(200,{r["ID"] for r in extension["tables"]["SpellClass"]})
        self.assertEqual(next(r for r in extension["tables"]["InvokeOption"] if r["ID"] == 1001)["InvokeOptionTypeID"],2)
        self.assertEqual(extension["tables"]["UniversalGroupSet"],[dict(ID=50,GroupID=194,UnitID=10431,Value=1)])
        self.assertEqual(next(r for r in extension["tables"]["Bonus"] if r["ID"] == 40)["Value"],15)

    def test_source_caption_is_carried_without_inventing_an_extra_proc(self):
        _,extension = self.build(self.prepare())
        self.assertEqual(extension["tables"]["DescData_Korean"],[dict(ID=99,Description="Synthetic source caption")])
        self.assertEqual(len(extension["tables"]["InvokeOption"]),1)

    def test_original_empty_shell_and_missing_reference_are_not_fabricated(self):
        tables = fixture_tables()
        tables["BuffClass"] = [r for r in tables["BuffClass"] if r["ID"] != 400]
        _,extension = self.build(self.prepare(tables))
        self.assertTrue(any(r["table"] == "BuffClass" and r["identity"] == 400
                            for r in extension["audit"]["missing_references"]))
        self.assertNotIn(400,{r["ID"] for r in extension["tables"]["BuffClass"]})
        self.assertTrue(any(r["table"] == "BuffBonus" and r["identity"] == 9 and r["source_row_count"] == 0
                            for r in extension["audit"]["empty_relationships"]))
        self.assertFalse(any(r["BuffClassID"] == 9 for r in extension["tables"].get("BuffBonus",[])))

    def test_source_base_raw_conflict_preserves_existing_output(self):
        prepared = self.prepare(mutate_base=lambda b:b["tables"]["Bonus"][0].update(Value=999))
        output = self.root/"extension.json"
        output.write_bytes(b"previous-private-output")
        before = prepared[0].read_bytes()
        with patch.multiple(builder,**prepared[3]), self.assertRaisesRegex(ValueError,"row conflict"):
            builder.build_extension(prepared[0],prepared[1],output)
        self.assertEqual(output.read_bytes(),b"previous-private-output")
        self.assertEqual(prepared[0].read_bytes(),before)

    def test_existing_classification_cannot_be_overridden(self):
        prepared = self.prepare(mutate_base=lambda b:b["bonuses"]["20"]["record"].update(atk=123))
        with patch.multiple(builder,**prepared[3]), self.assertRaisesRegex(ValueError,"classified bonus conflict"):
            builder.build_extension(prepared[0],prepared[1],self.root/"extension.json")

    def test_input_hash_pins_fail_before_output(self):
        prepared = self.prepare()
        base,archive,_,pins = prepared
        for changed in [{"BASE_SHA":"0"*64},{"BASE_BYTES":1},{"SOURCE_SHA":"0"*64}]:
            with self.subTest(changed=changed), patch.multiple(builder,**(pins|changed)), self.assertRaises(ValueError):
                builder.build_extension(base,archive,self.root/"extension.json")
        self.assertFalse((self.root/"extension.json").exists())

    def test_extraction_must_match_canonical_member_bytes(self):
        prepared = self.prepare()
        (prepared[2]/"Bonus.json").write_text('{"rows":[]}')
        with patch.multiple(builder,**prepared[3]), self.assertRaisesRegex(ValueError,"differs from canonical"):
            builder.build_extension(prepared[0],prepared[1],self.root/"extension.json",prepared[2])

    def test_public_repository_and_input_overwrite_are_rejected(self):
        base,archive,_,_ = self.prepare()
        for output in [base,archive,TOOLS.parents[1]/"data"/"private-leak.json"]:
            with self.subTest(output=output), self.assertRaises(ValueError):
                builder.require_private_output(output,base,archive)
        connected = self.root/"connected"
        (connected/".git").mkdir(parents=True)
        (connected/".git"/"config").write_text('[remote "origin"]\nurl = https://example.invalid/repository\n')
        with self.assertRaises(ValueError): builder.require_private_output(connected/"leak.json",base,archive)

    def test_duplicate_source_identity_conflict_is_rejected(self):
        tables = fixture_tables()
        tables["Bonus"].append(dict(tables["Bonus"][0],Value=999))
        prepared = self.prepare(tables)
        with patch.multiple(builder,**prepared[3]), self.assertRaisesRegex(ValueError,"conflicting original ID"):
            builder.build_extension(prepared[0],prepared[1],self.root/"extension.json")

    def test_repeated_conversion_is_deterministic_and_output_ids_are_unique(self):
        prepared = self.prepare()
        _,extension = self.build(prepared)
        first = (self.root/"extension.json").read_bytes()
        self.build(prepared)
        self.assertEqual((self.root/"extension.json").read_bytes(),first)
        for name,rows in extension["tables"].items():
            with self.subTest(table=name):
                ids = [r["ID"] for r in rows]
                self.assertEqual(len(ids),len(set(ids)))
                self.assertTrue(all(type(identity) is int and identity >= 0 for identity in ids))


if __name__ == "__main__":
    unittest.main()
