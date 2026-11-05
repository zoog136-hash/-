"""Full held native-profile classification plus malformed contract guards."""
import copy,json,sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools/equipment'))
from patch523_native_spells import compile_profile,compile_buff_profile
class NativeProfiles(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.input=json.loads(Path('/workspace/equipment523-logs/native-equipment-spell-profiles166_LOCAL_ONLY.json').read_text());cls.profiles=cls.input['spells']
 def test_complete166_source_partition(self):
  accepted={i:compile_profile(p) for i,p in self.profiles.items() if compile_profile(p)}
  self.assertEqual(len(self.profiles),166);self.assertEqual(len(accepted),26)
  self.assertEqual(sum(p['mode']=='fixed_ignore_mr_dr' for p in accepted.values()),2)
  self.assertNotIn('104632',accepted)
 def test_exact_fixed_damage_identity_and_dice(self):
  p=copy.deepcopy(self.profiles['69301']);before=copy.deepcopy(p);out=compile_profile(p)
  self.assertEqual(p,before);self.assertEqual(out['values']['SpellDamageBase'],80)
  self.assertEqual(out['values']['SpellDamageDiceNumber'],1);self.assertEqual(out['values']['SpellDamageDiceSpotCount'],1)
  self.assertNotEqual(out['values']['SpellDamageBase'],p['source_spell']['ID'])
 def test_cost_target_area_and_test_qualifiers_fail_closed(self):
  for key,value in [('MPCost',1),('SpellMaterialTypeID',1),('TargetKindID',10),('TargetAreaRadius',4),('TestSpell',True),('SpellCompositionNode',1),('CastingWeaponType',1),('ElementalTypeID',99)]:
   with self.subTest(field=key):
    p=copy.deepcopy(self.profiles['69301']);p['source_spell'][key]=value;self.assertIsNone(compile_profile(p))
 def test_unknown_effect_or_minimum_level_cannot_be_discarded(self):
  for path,value in [('name','BuffClassID'),('level',1),('unit',12),('target',8)]:
   p=copy.deepcopy(self.profiles['69301']);e=p['effects'][0]
   if path=='name':e['type']['Name']=value
   elif path=='level':e['link']['MinSpellLevel']=value
   elif path=='unit':e['type']['UnitID']=value
   else:e['bonus']['BonusApplicationTargetID']=value
   self.assertIsNone(compile_profile(p),path)
 def test_flags_are_an_entire_fixed_profile_not_a_guess(self):
  p=copy.deepcopy(self.profiles['69301']);p['effects']=[e for e in p['effects'] if e['type']['Name']!='IgnoreMagicResistance']
  self.assertIsNone(compile_profile(p))
  p=copy.deepcopy(self.profiles['69301']);p['effects'][0]['bonus']['Value']=-1;self.assertIsNone(compile_profile(p))
 def test_weapon_formula_and_buff_engine_are_not_faked_as_direct_damage(self):
  self.assertIsNone(compile_profile(self.profiles['31642']))
  self.assertTrue(any(not compile_profile(p) and any(e['type']['Name']=='BuffClassID' for e in p['effects']) for p in self.profiles.values()))
 def test_complete_buff_profile_partition(self):
  accepted={i:compile_buff_profile(p,self.input['buffs']) for i,p in self.profiles.items() if compile_buff_profile(p,self.input['buffs'])}
  self.assertEqual(len(accepted),75)
  self.assertFalse(set(accepted)&{i for i,p in self.profiles.items() if compile_profile(p)})
 def test_unknown_buff_attribute_cannot_be_silently_skipped(self):
  spell=next(p for p in self.profiles.values() if compile_buff_profile(p,self.input['buffs']))
  model=compile_buff_profile(spell,self.input['buffs']);buffs=copy.deepcopy(self.input['buffs']);buffs[str(model['buff']['source_buff']['ID'])]['effects'][0]['type']['Name']='UnknownNativeMeaning'
  self.assertIsNone(compile_buff_profile(spell,buffs))
 def test_buff_lifecycle_or_class_requirement_is_not_waived(self):
  spell=next(p for p in self.profiles.values() if compile_buff_profile(p,self.input['buffs']))
  model=compile_buff_profile(spell,self.input['buffs']);bid=str(model['buff']['source_buff']['ID'])
  for field,value in [('IsEraseOnAttack',True),('IsEraseOnTimeEnd',False),('MaxStackCount',1),('IsAbsoluteTimeBuff',True)]:
   buffs=copy.deepcopy(self.input['buffs']);buffs[bid]['source_buff'][field]=value
   self.assertIsNone(compile_buff_profile(spell,buffs),field)
  buffs=copy.deepcopy(self.input['buffs']);buffs[bid]['effects'][0]['link']['CharacterClass']=1
  self.assertIsNone(compile_buff_profile(spell,buffs))
 def test_pvp_only_target_is_not_remapped_to_npc(self):
  spell=copy.deepcopy(next(p for p in self.profiles.values() if compile_buff_profile(p,self.input['buffs'])));spell['source_spell']['TargetKindID']=52
  self.assertIsNone(compile_buff_profile(spell,self.input['buffs']))
if __name__=='__main__':unittest.main()
