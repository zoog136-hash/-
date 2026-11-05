"""Focused compiler safety contracts for new source status projections."""
import copy
import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools/equipment'))
from patch523_enhancement import compile_equipment

class StatusProjectionContracts(unittest.TestCase):
    def compile(self, name, unit=1, application=0, target=0, test=False):
        tables={'BonusType':[{'ID':1,'Name':name,'UnitID':unit}],
                'SpecialResistanceType':[{'ID':6,'Name':'Stun'},{'ID':8,'Name':'Fear'}]}
        item={'item_class':{'TestItem':test,'CategoryID':43,'GradeID':42},
              'catalog_record':{'slot':'badge'},'enchant_effects':[
                  {'ID':1,'EnchantLevel':7,'ItemEnchantBonusGroupID':1,'BonusID':1,'BlessCode':0},
                  {'ID':2,'EnchantLevel':6,'ItemEnchantBonusGroupID':1,'BonusID':2,'BlessCode':2}]}
        bonuses={'1':{'BonusTypeID':1,'Value':4,'BonusApplicationTypeID':application,'BonusApplicationTargetID':target},
                 '2':{'BonusTypeID':1,'Value':3,'BonusApplicationTypeID':application,'BonusApplicationTargetID':target}}
        before=copy.deepcopy((tables,item,bonuses))
        result=compile_equipment(tables,{'1':item},bonuses)
        self.assertEqual((tables,item,bonuses),before,'compiler must preserve raw inputs')
        return result.get('1',{})
    def test_blessing_alternatives_and_exact_units(self):
        for name,key in [('PiercePVPDamageReduction','source_pvp_flat_reduction_ignore'),('PVPSpellByLevelAdditionLevel','source_pvp_status_success_level')]:
            with self.subTest(name=name):
                result=self.compile(name)
                self.assertEqual(result['extra_options']['1']['7'][key],4)
                self.assertEqual(result['extra_options']['2']['6'][key],3)
                self.assertNotIn(key,result['extra_options']['2']['7'])
                self.assertEqual(result['unconnected_effect_row_ids'],[])
                self.assertEqual(self.compile(name,unit=3)['unconnected_effect_row_ids'],[1,2])
    def test_exact_fear_qualifier_not_stun_or_unknown(self):
        result=self.compile('PierceDamageReduction',application=2,target=8)
        self.assertEqual(result['extra_options']['1']['7']['source_fear_flat_reduction_ignore'],4)
        for app,target in [(2,6),(2,9),(1,8),(0,8)]:
            with self.subTest(application=app,target=target):
                self.assertEqual(self.compile('PierceDamageReduction',application=app,target=target)['unconnected_effect_row_ids'],[1,2])
        self.assertEqual(self.compile('PierceDamageReduction',unit=3,application=2,target=8)['unconnected_effect_row_ids'],[1,2])
    def test_no_test_item_or_unqualified_pvp_expansion(self):
        self.assertEqual(self.compile('PVPSpellByLevelAdditionLevel',test=True),{})
        self.assertEqual(self.compile('PiercePVPDamageReduction',application=10,target=8)['unconnected_effect_row_ids'],[1,2])

if __name__=='__main__':unittest.main()
