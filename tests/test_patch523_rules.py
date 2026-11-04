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

    def invoke_fixture(self):
        self.tables['BonusType']=[dict(ID=71,Name='EnchantBonusGroupID',UnitID=15),dict(ID=3091,Name='InvokeOption',UnitID=3)]
        self.tables['Bonus']=[dict(ID=11,BonusTypeID=71,Value=3,BonusApplicationTypeID=0,BonusApplicationTargetID=0),dict(ID=12,BonusTypeID=3091,Value=12345,BonusApplicationTypeID=10,BonusApplicationTargetID=99)]
        self.tables['ItemBonus']=[dict(ID=1,ItemClassID=101,BonusID=11)]
        self.tables['ItemEnchantBonus']=[dict(ID=7,EnchantLevel=4,ItemEnchantBonusGroupID=3,BonusID=12,BlessCode=0)]
        option={key:0 for key in ['Param2','Param3','Param4','Param5','Param6','MaterialTypeID','MaterialAmount','WeaponGroupID','ShieldTypeID','SuccessedInvokeOptionID','TargetKind','SiegeTargetKind']}
        option.update(ID=99,InvokeOptionTypeID=3,AttackTypeID=0,Param1=17,BySpellAttack=False)
        self.tables['InvokeOption']=[option]
        return option

    def test_numeric_invoke_keeps_probability_and_exact_bless_family(self):
        self.invoke_fixture()
        normal=self.compile()['equipment_runtime']['101']['invokes']['1']['4']
        self.assertEqual([(x['kind'],x['probability'],x['option']['Param1']) for x in normal],[('attack_fixed_damage',12345,17)])
        self.tables['Bonus'].append({**self.tables['Bonus'][1], 'ID':13,'Value':20000})
        self.tables['ItemEnchantBonus'].append({**self.tables['ItemEnchantBonus'][0],'ID':8,'BonusID':13,'BlessCode':2})
        blessed=self.compile()['equipment_runtime']['101']['invokes']['2']['4']
        self.assertEqual([x['probability'] for x in blessed],[20000])
        self.assertEqual(self.compile()['equipment_runtime']['101']['invokes']['1']['3'],[])

    def test_invoke_spell_formula_cost_and_unrepresented_attack_guards(self):
        option=self.invoke_fixture()
        for key,value in [('InvokeOptionTypeID',1),('Param2',42),('MaterialAmount',1),('IsAmmoAttack',True),('AttackTypeID',62),('SuccessedInvokeOptionID',12)]:
            with self.subTest(key=key):
                self.tables['InvokeOption']=[{**option,key:value}]
                runtime=self.compile()['equipment_runtime']['101']
                self.assertEqual(runtime['invokes']['1']['4'],[])
                self.assertIn(7,runtime['unconnected_effect_row_ids'])

    def test_ranged_defensive_invoke_remains_attack_scoped(self):
        option=self.invoke_fixture()
        self.tables['InvokeOption']=[{**option,'InvokeOptionTypeID':5,'AttackTypeID':2}]
        effect=self.compile()['equipment_runtime']['101']['invokes']['1']['4'][0]
        self.assertEqual((effect['kind'],effect['option']['AttackTypeID']),('defence_flat_reduction',2))

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
        for key,value in [('ServerLimitSetID',772),('EffectiveFrom',123),('CraftTimeTypeID',2),('NoRepeat',True),('IsBelowLevelLimit',True)]:
            with self.subTest(key=key):
                self.tables = copy.deepcopy(original)
                self.tables['ItemCraftView'][0][key] = value
                self.rejected()

    def test_source_craft_level_is_preserved_for_runtime_enforcement(self):
        self.tables['ItemCraftView'][0]['LevelLimitValue']=68
        recipe=self.compile()['recipes']['patch523:17']
        self.assertEqual(recipe['craft_conditions']['min_level'],68)
        self.assertEqual(recipe['craft_conditions']['source_level_fields'],dict(IsBelowLevelLimit=False,LevelLimitValue=68))
        self.tables['ItemCraftView'][0]['ServerLimitSetID']=772
        self.rejected()

    def test_verified_weekly_limit_does_not_admit_other_restrictions(self):
        policy=json.loads((Path(__file__).resolve().parents[1]/'data/crafting/patch523_crafting_policy.json').read_text())
        restriction=policy['verified_craft_constraints']['142364']['source_restriction']
        for name in ['ItemCraftInput','ItemCraftOutputView','ItemCraftView']:
            self.tables[name][0]['ItemCraftID']=142364
        self.tables['ItemCraftRestriction']=[copy.deepcopy(restriction)]
        recipe=self.compile()['recipes']['patch523:142364']
        self.assertEqual(recipe['craft_conditions']['quota']['limit'],10)
        self.assertEqual(recipe['craft_conditions']['quota']['source_restriction'],restriction)
        for key,value in [('Value',11),('ServiceTypeID',23),('RefreshUnitID',111),('isMultiCount',False)]:
            with self.subTest(key=key):
                self.tables['ItemCraftRestriction']=[{**restriction,key:value}]
                self.rejected()

    def test_full_probability_and_view_output_agreement(self):
        self.tables['ItemCraftOutputView'][0]['Probability'] = 999999
        self.rejected()
        self.tables['ItemCraftOutputView'][0]['Probability'] = 1000000
        self.tables['ItemCraftView'][0]['Enchant'] = 8
        self.rejected()

    def test_complete_original_critical_contract_is_not_normalized_or_relabelled_public(self):
        self.tables['ItemCraftOutputView'][0]['Probability']=990000
        self.tables['ItemCraftOutputView'].append({**self.tables['ItemCraftOutputView'][0],
            'ID':3,'ItemClassID':101,'ItemCraftOutputTypeID':2,'Probability':10000})
        recipe=self.compile()['recipes']['patch523:17']
        self.assertEqual([r['probability'] for r in recipe['outcomes']],[990000,10000])
        self.assertIn('개별 공개 표 미대조',recipe['probability_origin'])
        self.tables['ItemCraftOutputView'][1]['Probability']=9999
        self.rejected()
        self.tables['ItemCraftOutputView'][1]['Probability']=10000
        self.tables['ItemCraftOutputView'][1]['ItemCraftOutputTypeID']=12
        self.rejected()

    def test_character_max_level_condition_stays_separate_from_craft_level(self):
        self.tables['ItemClass'][1]['MaxLevelLimitMin']=68
        result=self.compile()
        self.assertEqual(result['items']['102']['use_conditions']['min_level'],68)
        self.assertNotIn('craft_conditions',result['recipes']['patch523:17'])

    def test_only_explicit_zero_item_failure_is_a_valid_empty_outcome(self):
        self.tables['ItemCraftOutputView'][0]['Probability']=800000
        self.tables['ItemCraftOutputView'].append({**self.tables['ItemCraftOutputView'][0],
            'ID':3,'ItemClassID':0,'Amount':0,'Enchant':0,'ItemBlessCodeID':1,
            'ItemCraftOutputTypeID':0,'Probability':200000})
        result=self.compile()['recipes']['patch523:17']['outcomes']
        self.assertTrue(result[1]['empty_result'])
        self.assertEqual((result[1]['source_id'],result[1]['quantity'],result[1]['probability']),('0',0,200000))
        self.tables['ItemCraftOutputView'][1]['Amount']=1
        self.rejected()

    def test_id_collision_requires_exact_localized_identity(self):
        self.tables['DescData_Korean'][0]['Description'] = 'different_source_item'
        self.rejected()

    def test_ambiguous_inventory_name_rejected(self):
        self.catalog['아이템'].append(dict(name='fixture_old',source='inven',sourceId='900',slot='earring'))
        self.rejected()

    def test_registered_native_binding_requires_exact_metadata_and_keeps_base_sha(self):
        records=[]
        for item in self.tables['ItemClass']:
            key=str(item['ID']); label='fixture_old' if key=='101' else 'fixture_new'
            records.append(dict(name=label+' · 원본#'+key,source_display_name=label,source='lineagem_patch523',
                source_snapshot='patch523',sourceId='m523:item:'+key,source_item_class_id=float(item['ID']),
                source_m_native_item=True,source_test_item=False,source_is_stackable=False,
                source_level_limit_min=0,source_level_limit_max=0,source_class_ids=[],source_equip_slot_ids=[],slot='earring'))
        original=json.dumps({'아이템':[]}).encode()
        bindings=json.dumps({'아이템':records}).encode()
        r=BUILDER.compile_rules(self.tables,{},original,bindings)
        self.assertIn('patch523:17',r['recipes'])
        self.assertEqual(r['catalog_sha256'],hashlib.sha256(original).hexdigest())
        self.assertEqual(r['binding_catalog_sha256'],hashlib.sha256(bindings).hexdigest())
        self.assertEqual(r['recipes']['patch523:17']['materials'][0]['item'],'fixture_old · 원본#101')
        for key,value in [('sourceId','m523:item:999'),('source_snapshot','base508'),('source_display_name','wrong'),('source_is_stackable',True),('source_class_ids',[9]),('source_equip_slot_ids',[293]),('source_bless_raw',2)]:
            with self.subTest(key=key):
                damaged=copy.deepcopy(records);damaged[0][key]=value
                self.assertFalse(BUILDER.compile_rules(self.tables,{},original,json.dumps({'아이템':damaged}).encode())['recipes'])
        # Supplementing a catalog must not replace an existing unique Inven identity.
        r=BUILDER.compile_rules(self.tables,{},json.dumps(self.catalog).encode(),json.dumps({'아이템':self.catalog['아이템']+records}).encode())
        self.assertEqual(r['items']['101']['catalog_record']['source'],'inven')
        replaced=BUILDER.compile_rules(self.tables,{},json.dumps(self.catalog).encode(),bindings)
        self.assertEqual(replaced['items']['101']['catalog_record']['source'],'lineagem_patch523')

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
        self.assertEqual(len(result['recipes']),352)
        self.assertEqual({k for k,r in result['recipes'].items() if any(o.get('empty_result') for o in r.get('outcomes',[]))},
                         {'patch523:150468','patch523:150478','patch523:150488','patch523:150498','patch523:172613'})
        self.assertEqual(set(result['guaranteed_boxes']),{'30701','130611'})
        self.assertEqual(len(result['source_files']),37)
        for name in ['ItemBlessBonus','Material','Unit','UIUnit','ItemEnchantEquipGroupMapping','ItemEnchantScrollGroupMapping','BmItemEnchantProView','ItemEnchantCostView','ItemEnchantProbabilityView','ItemBlessEnchantProbability','InvokeOption','InvokeOptionType','BonusApplicationType','AttackType']:
            self.assertEqual(result['enchantment'][name],tables[name])
        # Every enchant row of every bound item remains available verbatim;
        # unsupported conditions/procs must never become a flat numeric stat.
        bonuses={str(row['ID']):row for row in tables['Bonus']}
        for iid,item in result['items'].items():
            groups={bonuses[str(link['BonusID'])]['Value'] for link in item['item_bonuses'] if bonuses[str(link['BonusID'])]['BonusTypeID']==71}
            self.assertEqual(sorted(item['enchant_effects'],key=lambda r:r['ID']),sorted([r for r in tables['ItemEnchantBonus'] if r['ItemEnchantBonusGroupID'] in groups],key=lambda r:r['ID']))
        for table,key in [('ItemCraftInput','inputs'),('ItemCraftOutputView','outputs'),('ItemCraftView','views'),('ItemCraftRestriction','restrictions')]:
            restored=[row for rows in result['raw_recipes'][key].values() for row in rows]
            self.assertEqual(sorted(restored,key=lambda r:json.dumps(r,sort_keys=True)), sorted(tables[table],key=lambda r:json.dumps(r,sort_keys=True)))
        self.assertTrue(result['recipes']['patch523:258618']['requires_material_selection'])
        self.assertNotIn('patch523:261764',result['recipes'])
        self.assertEqual(result['recipes']['patch523:77552']['result']['bless_code'],2)


if __name__ == '__main__':
    unittest.main()
