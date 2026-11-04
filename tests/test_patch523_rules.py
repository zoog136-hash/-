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

    def test_elemental_flat_amount_requires_unit_and_explicit_target(self):
        self.tables['BonusType']=[dict(ID=71,Name='EnchantBonusGroupID',UnitID=15),dict(ID=799,Name='ElementalDamage',UnitID=1)]
        self.tables['Bonus']=[dict(ID=11,BonusTypeID=71,Value=3,BonusApplicationTypeID=0,BonusApplicationTargetID=0),dict(ID=12,BonusTypeID=799,Value=3,BonusApplicationTypeID=3,BonusApplicationTargetID=1)]
        self.tables['ItemBonus']=[dict(ID=1,ItemClassID=101,BonusID=11)]
        self.tables['ItemEnchantBonus']=[dict(ID=7,EnchantLevel=4,ItemEnchantBonusGroupID=3,BonusID=12,BlessCode=0)]
        self.assertEqual(self.compile()['equipment_runtime']['101']['extra_options']['1']['4'],{'source_elemental_flat_fire':3})
        for target in [0,5,999]:
            self.tables['Bonus'][1]['BonusApplicationTargetID']=target
            self.assertIn(7,self.compile()['equipment_runtime']['101']['unconnected_effect_row_ids'])
        self.tables['Bonus'][1]['BonusApplicationTargetID']=1
        self.tables['BonusType'][1]['UnitID']=3
        self.assertIn(7,self.compile()['equipment_runtime']['101']['unconnected_effect_row_ids'])

    def test_exact_source_calendar_is_a_live_window_not_removed_restriction(self):
        self.tables['ItemCraftView'][0].update(EffectiveFrom=10,EffectiveTo=11)
        self.tables['DateTimes_Korean']=[dict(ID=10,Year=2020,Month=1,Day=1,Hour=0,Minute=0),dict(ID=11,Year=2030,Month=1,Day=1,Hour=0,Minute=0)]
        compiled=self.compile()
        condition=compiled['recipes']['patch523:17']['craft_conditions']['active_window']
        self.assertEqual(condition['source_start'],self.tables['DateTimes_Korean'][0])
        self.assertEqual(condition['source_end'],self.tables['DateTimes_Korean'][1])
        self.assertEqual(condition['utc_offset_minutes'],540)
        self.assertEqual(condition['boundary'],'start_inclusive_end_exclusive')
        self.assertLess(condition['start_unix'],condition['end_unix'])
        self.tables['DateTimes_Korean'][0]['Month']=13
        self.assertNotIn('patch523:17',self.compile()['recipes'])
        self.tables['DateTimes_Korean'][0]['Month']=1
        self.tables['ItemCraftView'][0]['ServerLimitSetID']=772
        self.assertNotIn('patch523:17',self.compile()['recipes'])

    def test_fixed_description_stays_spell_scoped_evidence_not_global_seconds(self):
        self.tables['BonusType']=[dict(ID=71,Name='EnchantBonusGroupID',UnitID=15),dict(ID=6582,Name='FixedDesc',UnitID=41)]
        self.tables['Bonus']=[dict(ID=11,BonusTypeID=71,Value=3,BonusApplicationTypeID=0,BonusApplicationTargetID=0),dict(ID=12,BonusTypeID=6582,Value=1111192,BonusApplicationTypeID=72,BonusApplicationTargetID=1111182)]
        self.tables['ItemBonus']=[dict(ID=1,ItemClassID=101,BonusID=11)]
        self.tables['ItemEnchantBonus']=[dict(ID=7,EnchantLevel=8,ItemEnchantBonusGroupID=3,BonusID=12,BlessCode=0)]
        self.tables['DescData_Korean'] += [dict(ID=1111182,Description='스턴 시간 감소'),dict(ID=1111192,Description='1초')]
        self.assertIn(7,self.compile()['equipment_runtime']['101']['unconnected_effect_row_ids'])
        self.assertNotIn('source_stun_duration_reduction_seconds',self.compile()['equipment_runtime']['101']['extra_options']['1']['8'])
        self.tables['DescData_Korean'][-1]['Description']='2초'
        self.assertIn(7,self.compile()['equipment_runtime']['101']['unconnected_effect_row_ids'])

    def test_stun_magic_damage_does_not_accept_fear_or_wrong_units(self):
        self.tables['BonusType']=[dict(ID=71,Name='EnchantBonusGroupID',UnitID=15),dict(ID=4,Name='MagicDamage',UnitID=1)]
        self.tables['Bonus']=[dict(ID=11,BonusTypeID=71,Value=3,BonusApplicationTypeID=0,BonusApplicationTargetID=0),dict(ID=12,BonusTypeID=4,Value=5,BonusApplicationTypeID=2,BonusApplicationTargetID=6)]
        self.tables['SpecialResistanceType']=[dict(ID=6,Name='Stun'),dict(ID=8,Name='Fear')]
        self.tables['ItemBonus']=[dict(ID=1,ItemClassID=101,BonusID=11)]
        self.tables['ItemEnchantBonus']=[dict(ID=7,EnchantLevel=7,ItemEnchantBonusGroupID=3,BonusID=12,BlessCode=0)]
        self.assertEqual(self.compile()['equipment_runtime']['101']['extra_options']['1']['7'],{'source_stun_magic_damage':5})
        self.tables['Bonus'][1]['BonusApplicationTargetID']=8
        self.assertIn(7,self.compile()['equipment_runtime']['101']['unconnected_effect_row_ids'])
        self.tables['Bonus'][1]['BonusApplicationTargetID']=6
        self.tables['BonusType'][1]['UnitID']=3
        self.assertIn(7,self.compile()['equipment_runtime']['101']['unconnected_effect_row_ids'])

    def test_nonactivating_source_material_keeps_unresolved_use_class_reference(self):
        self.tables['ItemClass'][0]['ID']=188384
        self.tables['ItemClass'][0]['CategoryID']=2
        self.tables['ItemCategory'].append(dict(ID=2,IsStackable=True,IsActivatable=False))
        self.tables['ItemClassLimit']=[dict(ID=1,ItemClassID=188384,ClassID=0)]
        self.tables['ItemCraftInput'][0].update(ItemClassID=188384,Enchant=0,ItemBlessCodeID=1)
        self.catalog['아이템'][0].update(sourceId='188384',slot='material')
        value=self.compile()
        self.assertIn('patch523:17',value['recipes'])
        self.assertEqual(value['items']['188384']['use_conditions']['class_ids'],[0])
        self.assertEqual(value['items']['188384']['craft_material_only_class_references']['scope'],'source_input_only')
        self.tables['ItemCategory'][-1]['IsActivatable']=True
        self.assertNotIn('patch523:17',self.compile()['recipes'])

    def test_final_blow_source_unit_and_independent_probability_amplification(self):
        self.tables['BonusType']=[dict(ID=71,Name='EnchantBonusGroupID',UnitID=15),dict(ID=6121,Name='FinalBlowProbability',UnitID=3),dict(ID=6111,Name='FinalBlowAdditionalScale',UnitID=3)]
        self.tables['Bonus']=[dict(ID=11,BonusTypeID=71,Value=3,BonusApplicationTypeID=0,BonusApplicationTargetID=0),dict(ID=12,BonusTypeID=6121,Value=100000,BonusApplicationTypeID=0,BonusApplicationTargetID=0),dict(ID=13,BonusTypeID=6111,Value=300000,BonusApplicationTypeID=0,BonusApplicationTargetID=0)]
        self.tables['ItemBonus']=[dict(ID=1,ItemClassID=101,BonusID=11)]
        self.tables['ItemEnchantBonus']=[dict(ID=7,EnchantLevel=7,ItemEnchantBonusGroupID=3,BonusID=12,BlessCode=0),dict(ID=8,EnchantLevel=7,ItemEnchantBonusGroupID=3,BonusID=13,BlessCode=0)]
        runtime=self.compile()['equipment_runtime']['101']
        self.assertEqual(runtime['extra_options']['1']['7'],{'source_final_blow_chance_pct':10,'source_final_blow_amp_pct':30})
        self.tables['BonusType'][1]['UnitID']=1
        self.assertIn(7,self.compile()['equipment_runtime']['101']['unconnected_effect_row_ids'])
        self.tables['BonusType'][1]['UnitID']=3
        self.tables['Bonus'][1]['BonusApplicationTypeID']=2
        self.tables['Bonus'][1]['BonusApplicationTargetID']=6
        self.tables['SpecialResistanceType']=[dict(ID=6,Name='Stun')]
        self.assertEqual(self.compile()['equipment_runtime']['101']['extra_options']['1']['7']['source_final_blow_stun_chance_pct'],10)
        self.tables['Bonus'][1]['BonusApplicationTargetID']=8
        self.assertIn(7,self.compile()['equipment_runtime']['101']['unconnected_effect_row_ids'])

    def test_damage_percent_units_and_adena_exact_item_qualifier(self):
        self.tables['BonusType']=[dict(ID=71,Name='EnchantBonusGroupID',UnitID=15),dict(ID=4073,Name='PierceDamageReductionPercent',UnitID=3),dict(ID=6322,Name='IncreaseNpcItemDropAmount',UnitID=211)]
        self.tables['Bonus']=[dict(ID=11,BonusTypeID=71,Value=3,BonusApplicationTypeID=0,BonusApplicationTargetID=0),dict(ID=12,BonusTypeID=4073,Value=25000,BonusApplicationTypeID=0,BonusApplicationTargetID=0),dict(ID=13,BonusTypeID=6322,Value=7,BonusApplicationTypeID=5,BonusApplicationTargetID=26)]
        self.tables['ItemBonus']=[dict(ID=1,ItemClassID=101,BonusID=11)]
        self.tables['ItemEnchantBonus']=[dict(ID=7,EnchantLevel=4,ItemEnchantBonusGroupID=3,BonusID=12,BlessCode=0),dict(ID=8,EnchantLevel=4,ItemEnchantBonusGroupID=3,BonusID=13,BlessCode=0)]
        runtime=self.compile()['equipment_runtime']['101']
        self.assertEqual(runtime['extra_options']['1']['4'],{'damage_amp_pct':2.5,'adena_drop_pct':7})
        adena_bonus=self.tables['Bonus'][-1].copy()
        for key,value in [('BonusApplicationTypeID',0),('BonusApplicationTargetID',999)]:
            with self.subTest(key=key):
                self.tables['Bonus'][-1]={**adena_bonus,key:value}
                guarded=self.compile()['equipment_runtime']['101']
                self.assertNotIn('adena_drop_pct',guarded['extra_options']['1']['4'])
                self.assertIn(8,guarded['unconnected_effect_row_ids'])

    def test_status_targets_require_the_exact_source_enum(self):
        self.tables['SpecialResistanceType']=[dict(ID=6,Name='Stun'),dict(ID=7,Name='Hold'),dict(ID=54,Name='Polymorph')]
        self.tables['BonusType']=[dict(ID=71,Name='EnchantBonusGroupID',UnitID=15),dict(ID=5782,Name='HitSpecialResistance',UnitID=3),dict(ID=145,Name='SpecialResistance',UnitID=3)]
        self.tables['Bonus']=[dict(ID=11,BonusTypeID=71,Value=3,BonusApplicationTypeID=0,BonusApplicationTargetID=0),dict(ID=12,BonusTypeID=5782,Value=30000,BonusApplicationTypeID=2,BonusApplicationTargetID=6),dict(ID=13,BonusTypeID=145,Value=70000,BonusApplicationTypeID=2,BonusApplicationTargetID=7)]
        self.tables['ItemBonus']=[dict(ID=1,ItemClassID=101,BonusID=11)]
        self.tables['ItemEnchantBonus']=[dict(ID=7,EnchantLevel=4,ItemEnchantBonusGroupID=3,BonusID=12,BlessCode=0),dict(ID=8,EnchantLevel=4,ItemEnchantBonusGroupID=3,BonusID=13,BlessCode=0)]
        self.assertEqual(self.compile()['equipment_runtime']['101']['extra_options']['1']['4'],{'stun_accuracy':3,'hold_resistance':7})
        for target in [0,54,999]:
            self.tables['Bonus'][1]['BonusApplicationTargetID']=target
            runtime=self.compile()['equipment_runtime']['101']
            self.assertNotIn('stun_accuracy',runtime['extra_options']['1']['4'])
            self.assertIn(7,runtime['unconnected_effect_row_ids'])

    def test_status_plus_zero_keeps_base_subtraction_contract(self):
        self.tables['SpecialResistanceType']=[dict(ID=6,Name='Stun')]
        self.tables['BonusType']=[dict(ID=71,Name='EnchantBonusGroupID',UnitID=15),dict(ID=145,Name='SpecialResistance',UnitID=3)]
        self.tables['Bonus']=[dict(ID=11,BonusTypeID=71,Value=3,BonusApplicationTypeID=0,BonusApplicationTargetID=0),dict(ID=12,BonusTypeID=145,Value=70000,BonusApplicationTypeID=2,BonusApplicationTargetID=6)]
        self.tables['ItemBonus']=[dict(ID=1,ItemClassID=101,BonusID=11)]
        self.tables['ItemEnchantBonus']=[dict(ID=7,EnchantLevel=0,ItemEnchantBonusGroupID=3,BonusID=12,BlessCode=0)]
        value=self.compile()['equipment_runtime']['101']['options']['1']['0']['stun_resistance']
        self.assertEqual(value,{'total':7,'base_key':'stun_resistance','scale':1})

    def test_complete_multiple_success_views_preserve_all_qualifications(self):
        first=self.tables['ItemCraftOutputView'][0]
        first['Probability']=600000
        second={**first,'ID':3,'ItemClassID':101,'Probability':300000}
        empty={**first,'ID':4,'ItemClassID':0,'Amount':0,'Probability':100000,'ItemCraftOutputTypeID':0,'Enchant':0,'ItemBlessCodeID':1}
        self.tables['ItemCraftOutputView']=[first,second,empty]
        view=self.tables['ItemCraftView'][0]
        self.tables['ItemCraftView']=[view,{**view,'ItemClassID':101}]
        recipe=self.compile()['recipes']['patch523:17']
        self.assertEqual(recipe['source_success_view_count'],2)
        self.assertEqual([o['probability'] for o in recipe['outcomes']],[600000,300000,100000])
        self.assertTrue(recipe['outcomes'][2]['empty_result'])
        for field,value in [('LevelLimitValue',77),('ServerLimitSetID',772),('EffectiveTo',9),('PopupText',99)]:
            with self.subTest(field=field):
                self.tables['ItemCraftView'][1]={**view,'ItemClassID':101,field:value}
                self.assertNotIn('patch523:17',self.compile()['recipes'])

    def test_multiple_success_views_cannot_hide_or_duplicate_a_branch(self):
        first=self.tables['ItemCraftOutputView'][0]
        self.tables['ItemCraftOutputView']=[{**first,'Probability':600000},{**first,'ID':3,'ItemClassID':101,'Probability':400000}]
        view=self.tables['ItemCraftView'][0]
        for rows in [[view,view],[view,{**view,'ItemClassID':999}],[view,{**view,'ItemClassID':101},{**view,'ItemClassID':101}]]:
            self.tables['ItemCraftView']=rows
            self.assertNotIn('patch523:17',self.compile()['recipes'])

    def test_source_drain_zero_totals_subtract_existing_flag_aliases(self):
        self.tables['BonusType']=[dict(ID=71,Name='EnchantBonusGroupID',UnitID=15),dict(ID=432,Name='AttackDrainHP',UnitID=1),dict(ID=442,Name='AttackDrainMP',UnitID=1),dict(ID=10222,Name='StrengthScale',UnitID=3)]
        self.tables['Bonus']=[dict(ID=11,BonusTypeID=71,Value=3,BonusApplicationTypeID=0,BonusApplicationTargetID=0),dict(ID=12,BonusTypeID=432,Value=1,BonusApplicationTypeID=0,BonusApplicationTargetID=0),dict(ID=13,BonusTypeID=442,Value=1,BonusApplicationTypeID=0,BonusApplicationTargetID=0),dict(ID=14,BonusTypeID=10222,Value=50000,BonusApplicationTypeID=0,BonusApplicationTargetID=0)]
        self.tables['ItemBonus']=[dict(ID=1,ItemClassID=101,BonusID=11)]
        self.tables['ItemEnchantBonus']=[dict(ID=i,EnchantLevel=0,ItemEnchantBonusGroupID=3,BonusID=b,BlessCode=0) for i,b in [(7,12),(8,13),(9,14)]]
        extra=self.compile()['equipment_runtime']['101']['extra_options']['1']['0']
        self.assertEqual(extra['source_attack_drain_hp'],{'total':1,'base_key':'hpAbsorption','scale':1})
        self.assertEqual(extra['source_attack_drain_mp'],{'total':1,'base_key':'mpAbsorption','scale':1})
        self.assertEqual(extra['strPercent'],{'total':5,'base_key':'strPercent','scale':1})

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

    def test_native_non_equipment_preserves_nonstackable_flag_without_gear_instances(self):
        self.tables['ItemCraftInput'][0].update(Enchant=0,ItemBlessCodeID=1)
        self.tables['ItemCraftOutputView'][0]['Enchant']=0
        self.tables['ItemCraftView'][0]['Enchant']=0
        records=[]
        for item in self.tables['ItemClass']:
            key=str(item['ID']); label='fixture_old' if key=='101' else 'fixture_new'
            records.append(dict(name=label+' · 원본#'+key,source_display_name=label,source='lineagem_patch523',source_snapshot='patch523',sourceId='m523:item:'+key,source_item_class_id=item['ID'],source_m_native_item=True,source_test_item=False,source_is_stackable=False,source_level_limit_min=0,source_level_limit_max=0,source_class_ids=[],source_equip_slot_ids=[],source_equipment_status='no_source_equip_slot',slot='material'))
        def compiled(): return BUILDER.compile_rules(self.tables,{},'{"아이템":[]}'.encode(),json.dumps({'아이템':records}).encode())
        value=compiled()
        self.assertFalse(value['recipes']['patch523:17']['materials'][0]['physical'])
        self.assertFalse(value['recipes']['patch523:17']['result']['physical'])
        self.assertFalse(value['items']['102']['catalog_record']['source_is_stackable'])
        self.tables['ItemCraftInput'][0]['Enchant']=1
        self.assertNotIn('patch523:17',compiled()['recipes'])
        self.tables['ItemCraftInput'][0]['Enchant']=0
        self.tables['ItemEquipSlot']=[dict(ItemClassID=101,EquipSlotID=23)]
        records[0]['source_equip_slot_ids']=[23]
        self.assertNotIn('patch523:17',compiled()['recipes'])

    def test_partial_source_success_keeps_raw_rows_and_labels_derived_failure(self):
        for table in ['ItemCraftInput','ItemCraftOutputView','ItemCraftView']:
            for row in self.tables[table]:row['ItemCraftID']=38494
        self.tables['ItemCraftView'][0]['AlwaysSuccess']=0
        self.tables['ItemCraftOutputView'][0]['Probability']=600000
        value=self.compile();recipe=value['recipes']['patch523:38494']
        self.assertEqual(len(value['raw_recipes']['outputs']['38494']),1)
        self.assertEqual(value['raw_recipes']['outputs']['38494'][0]['Probability'],600000)
        self.assertEqual([r['probability'] for r in recipe['outcomes']],[600000,400000])
        self.assertTrue(recipe['outcomes'][1]['empty_result'])
        self.assertTrue(recipe['outcomes'][1]['twilight_missing_failure'])
        self.assertIn('TWILIGHT',recipe['probability_origin'])
        self.tables['ItemCraftOutputView'][0]['Probability']=599999
        self.assertNotIn('patch523:38494',self.compile()['recipes'])

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

    def test_blessed_stack_requires_actually_registered_exact_variant(self):
        self.tables['ItemCategory'][0]['IsStackable']=True
        self.tables['ItemCraftInput'][0]['Enchant']=0
        self.tables['ItemCraftOutputView'][0]['Enchant']=0
        self.tables['ItemCraftView'][0]['Enchant']=0
        records=[]
        for item in self.tables['ItemClass']:
            key=str(item['ID']);label='fixture_old' if key=='101' else 'fixture_new'
            records.append(dict(name=label+' · 원본#'+key,source_display_name=label,source='lineagem_patch523',
                source_snapshot='patch523',sourceId='m523:item:'+key,source_item_class_id=item['ID'],
                source_m_native_item=True,source_test_item=False,source_is_stackable=True,source_bless_raw=1,
                source_level_limit_min=0,source_level_limit_max=0,source_class_ids=[],source_equip_slot_ids=[],slot='material'))
        def compile_records(rows):
            return BUILDER.compile_rules(self.tables,{},'{"아이템":[]}'.encode(),json.dumps({'아이템':rows}).encode())
        self.assertFalse(compile_records(records)['recipes'])
        variant={**records[0],'name':records[0]['name']+' · 축복','sourceId':records[0]['sourceId']+':bless:2','source_bless_raw':2}
        rows=records+[variant]
        result=compile_records(rows)
        self.assertEqual(result['recipes']['patch523:17']['materials'][0]['item'],variant['name'])
        self.assertEqual(result['items']['101']['stack_variants']['2']['sourceId'],variant['sourceId'])
        for key,value in [('sourceId','m523:item:101:bless:3'),('name',records[0]['name']),('source_bless_raw',1),('source_class_ids',[9])]:
            with self.subTest(key=key):
                self.assertFalse(compile_records(records+[{**variant,key:value}])['recipes'])
        self.assertFalse(compile_records(rows+[variant])['recipes'])

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
        self.assertEqual(len(result['recipes']),398)
        self.assertEqual(sum('active_window' in r.get('craft_conditions',{}) for r in result['recipes'].values()),44)
        self.assertEqual({k for k,r in result['recipes'].items() if 'missing_failure_policy' in r},{'patch523:216232'})
        self.assertEqual({k for k,r in result['recipes'].items() if any(o.get('empty_result') for o in r.get('outcomes',[]))},
                         {'patch523:150468','patch523:150478','patch523:150488','patch523:150498','patch523:172613',
                          'patch523:207754','patch523:207764','patch523:207774','patch523:216232'})
        self.assertEqual(set(result['guaranteed_boxes']),{'30701','130611'})
        self.assertEqual(len(result['source_files']),38)
        descriptions={r['ID']:r['Description'] for r in tables['DescData_Korean']}
        types={r['ID']:r for r in tables['BonusType']}
        for tid,unit,label in [(4073,3,'대미지 증가'),(11124,3,'PVE 대미지 증가'),(231,3,'대미지 감소'),(6322,211,'아데나 드롭량')]:
            self.assertEqual(types[tid]['UnitID'],unit)
            self.assertEqual(descriptions[types[tid]['DescID']],label)
        adena=next(r for r in tables['ItemClass'] if r['ID']==26)
        self.assertEqual(descriptions[adena['DescID']],'아데나')
        for name in ['ItemBlessBonus','Material','Unit','UIUnit','ItemEnchantEquipGroupMapping','ItemEnchantScrollGroupMapping','BmItemEnchantProView','ItemEnchantCostView','ItemEnchantProbabilityView','ItemBlessEnchantProbability','InvokeOption','InvokeOptionType','BonusApplicationType','AttackType','SpecialResistanceType']:
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
        self.assertEqual(len(result['raw_recipes']['views']['122114']),4)
        self.assertEqual(sum(r['Probability'] for r in result['raw_recipes']['outputs']['122114']),1000000)
        self.assertEqual(result['recipe_admission']['122114'],{'reason':'missing_or_ambiguous_catalog_identity','first_blocking_item_class_id':185094})


if __name__ == '__main__':
    unittest.main()
