"""Synthetic rule-admission regressions; actual-source checks are opt-in."""
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('patch523_builder', Path(__file__).resolve().parents[1] / 'tools/equipment/build_patch523_rules.py')
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


def fixture():
    # Deliberately synthetic IDs and names, never original-source assertions.
    tables = {name: [] for name in BUILDER.SOURCE_SHA256}
    tables['ItemClass'] = [dict(ID=i, DescID=i, IdentifiedDescID=i, CategoryID=1, TestItem=False,
                               ServiceRegionCode='', LevelLimitMin=0, LevelLimitMax=0) for i in [101, 102]]
    tables['DescData_Korean'] = [dict(ID=i, Description=n) for i, n in [(101,'fixture_old'),(102,'fixture_new')]]
    tables['ItemCategory'] = [dict(ID=1, IsStackable=False)]
    tables['ItemCraftInput'] = [dict(ID=1, ItemCraftID=17, SlotIndex=1, ItemClassID=101,
                                    Amount=1, Enchant=8, ItemBlessCodeID=2, ItemHoningEpithetID=0)]
    tables['ItemCraftOutputView'] = [dict(ID=2, ItemCraftID=17, ItemCraftOutputTypeID=1, ItemClassID=102,
                                         Amount=1, Enchant=7, ItemBlessCodeID=1, Probability=1000000,
                                         ClanItemClassID=0, ClanAmount=0)]
    tables['ItemCraftView'] = [dict(ItemCraftID=17, ItemClassID=102, Amount=1, Enchant=7, ItemBlessCodeID=1,
                                   AlwaysSuccess=1, ServerLimitSetID=0, IsCoalitionItem=False, NoRepeat=False,
                                   IsBelowLevelLimit=False, LevelLimitValue=0, EffectiveFrom=1, EffectiveTo=3,
                                   CraftTimeTypeID=1, PopupText=0)]
    catalog = {'아이템':[dict(name=n, source='inven', sourceId=str(i), slot='earring')
                        for i,n in [(101,'fixture_old'),(102,'fixture_new')]]}
    return tables, catalog


class AdmissionTest(unittest.TestCase):
    def setUp(self):
        self.tables, self.catalog = fixture()

    def compile(self):
        return BUILDER.compile_rules(self.tables, {}, json.dumps(self.catalog).encode())

    def rejected(self):
        self.assertEqual(self.compile()['recipes'], {})

    def test_explicit_state_not_inherited(self):
        r = self.compile()['recipes']['patch523:17']
        self.assertEqual((r['materials'][0]['level'],r['materials'][0]['bless_code']), (8,2))
        self.assertEqual((r['result']['level'],r['result']['bless_code']), (7,1))

    def test_candidates_preserved_and_require_explicit_choice(self):
        self.tables['ItemCraftInput'].append({**self.tables['ItemCraftInput'][0], 'ID':3, 'ItemBlessCodeID':1})
        result = self.compile()
        self.assertTrue(result['recipes']['patch523:17']['requires_material_selection'])
        self.assertEqual(len(result['recipes']['patch523:17']['material_slots'][0]['candidates']),2)
        self.assertEqual(len(result['raw_recipes']['inputs']['17']), 2)

    def test_viewless_output_not_exposed(self):
        self.tables['ItemCraftView'] = []
        self.rejected()
        self.assertEqual(len(self.compile()['raw_recipes']['outputs']['17']), 1)

    def test_unresolved_restriction_is_not_ignored(self):
        self.tables['ItemCraftRestriction'] = [dict(ItemCraftID=17,ServiceTypeID=52,Value=1,RefreshUnitID=111)]
        self.rejected()

    def test_server_calendar_and_time_guards(self):
        original = copy.deepcopy(self.tables)
        for key,value in [('ServerLimitSetID',772),('EffectiveFrom',123),('CraftTimeTypeID',2),('NoRepeat',True),('LevelLimitValue',80)]:
            with self.subTest(key=key):
                self.tables = copy.deepcopy(original)
                self.tables['ItemCraftView'][0][key] = value
                self.rejected()

    def test_full_probability_and_view_output_agreement(self):
        self.tables['ItemCraftOutputView'][0]['Probability'] = 999999
        self.rejected()
        self.tables['ItemCraftOutputView'][0]['Probability'] = 1000000
        self.tables['ItemCraftView'][0]['Enchant'] = 8
        self.rejected()

    def test_id_collision_requires_exact_localized_identity(self):
        self.tables['DescData_Korean'][0]['Description'] = 'different_source_item'
        self.rejected()

    def test_ambiguous_inventory_name_rejected(self):
        self.catalog['아이템'].append(dict(name='fixture_old',source='inven',sourceId='900',slot='earring'))
        self.rejected()

    def test_unknown_item_state_and_tests_rejected(self):
        self.tables['ItemClass'][0]['TestItem'] = True
        self.rejected()
        self.tables['ItemClass'][0]['TestItem'] = False
        self.tables['ItemCraftInput'][0]['ItemHoningEpithetID'] = 7
        self.rejected()

    def test_item_use_conditions_are_not_craft_restrictions(self):
        self.tables['Class'] = [dict(ID=3,DescID=300)]
        self.tables['DescData_Korean'].append(dict(ID=300,Description='마법사'))
        self.tables['ItemClassLimit'] = [dict(ItemClassID=102,ClassID=3)]
        self.tables['ItemClass'][1]['LevelLimitMin'] = 68
        result=self.compile()
        self.assertIn('patch523:17',result['recipes'])
        use=result['items']['102']['use_conditions']
        self.assertEqual((use['min_level'],use['class_ids'],use['class_names']),(68,[3],['마법사']))
        self.tables['ItemClassLimit'][0]['ClassID']=999
        self.rejected()

    def test_original_large_currency_is_not_replaced_by_host_cap(self):
        self.tables['ItemClass'].append(dict(ID=26,DescID=26,IdentifiedDescID=26,CategoryID=1,TestItem=False,ServiceRegionCode='',LevelLimitMin=0,LevelLimitMax=0))
        self.tables['DescData_Korean'].append(dict(ID=26,Description='아데나'))
        self.tables['ItemCraftInput'].append(dict(ID=4,ItemCraftID=17,SlotIndex=2,ItemClassID=26,Amount=500000000,Enchant=0,ItemBlessCodeID=1,ItemHoningEpithetID=0))
        self.assertEqual(self.compile()['recipes']['patch523:17']['adena'],500000000)

    def test_wallet_candidates_preserve_deliberate_alternative(self):
        self.tables['ItemClass'].append(dict(ID=26,DescID=26,IdentifiedDescID=26,CategoryID=1,TestItem=False,ServiceRegionCode='',LevelLimitMin=0,LevelLimitMax=0))
        self.tables['DescData_Korean'].append(dict(ID=26,Description='아데나'))
        self.tables['ItemCraftInput'].append(dict(ID=4,ItemCraftID=17,SlotIndex=1,ItemClassID=26,Amount=500000000,Enchant=0,ItemBlessCodeID=1,ItemHoningEpithetID=0))
        recipe=self.compile()['recipes']['patch523:17']
        self.assertEqual(recipe['adena'],0)
        self.assertTrue(recipe['requires_material_selection'])
        self.assertEqual([(m['source_id'],m['wallet']) for m in recipe['material_slots'][0]['candidates']],[('101',False),('26',True)])

    def test_wrong_source_bytes_rejected_before_projection(self):
        saved = BUILDER.SOURCE_SHA256
        try:
            with tempfile.TemporaryDirectory() as directory:
                p=Path(directory)/'Fixture.json'
                p.write_bytes(b'{"rows":[]}')
                BUILDER.SOURCE_SHA256 = {'Fixture':hashlib.sha256(b'different bytes').hexdigest()}
                with self.assertRaisesRegex(ValueError,'pinned current523'):
                    BUILDER.read_source(Path(directory))
        finally:
            BUILDER.SOURCE_SHA256 = saved

    @unittest.skipUnless(os.environ.get('TWILIGHT_PATCH523_CONTENT'), 'actual private source not installed')
    def test_actual_pinned_tables_and_all_raw_rows(self):
        directory=Path(os.environ['TWILIGHT_PATCH523_CONTENT'])
        tables,evidence=BUILDER.read_source(directory)
        catalog=(Path(__file__).resolve().parents[1]/'data/catalog_v19.json').read_bytes()
        result=BUILDER.compile_rules(tables,evidence,catalog)
        self.assertEqual(len(result['recipes']),345)
        self.assertEqual(set(result['guaranteed_boxes']),{'30701','130611'})
        self.assertEqual(len(result['source_files']),29)
        for table,key in [('ItemCraftInput','inputs'),('ItemCraftOutputView','outputs'),('ItemCraftView','views'),('ItemCraftRestriction','restrictions')]:
            restored=[row for rows in result['raw_recipes'][key].values() for row in rows]
            self.assertEqual(sorted(restored,key=lambda r:json.dumps(r,sort_keys=True)), sorted(tables[table],key=lambda r:json.dumps(r,sort_keys=True)))
        self.assertTrue(result['recipes']['patch523:258618']['requires_material_selection'])
        self.assertNotIn('patch523:261764',result['recipes'])
        self.assertEqual(result['recipes']['patch523:77552']['result']['bless_code'],2)


if __name__ == '__main__':
    unittest.main()
