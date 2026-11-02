"""Literal numeric SP2 bank references only; no artwork fixtures or file substitution."""
import unittest
import original_spr
from build_base508_full_model_pack import literal_reference_ids,supported_reference_issues
class LiteralLayerTests(unittest.TestCase):
 def source(self):
  d=original_spr.Declaration(1,None,'fixture.spr',1)
  d.references=[{'kind':'shadow','targets':[9],'raw':'9','count_valid':True}]
  m={'source_sprite_id':1,'original_members':['Sprite/9-0.sp2'],'reference_issues':[{'sprite_id':9,'issue':'missing_or_duplicate_declaration','count':0}]}
  return m,{1:[d]}
 def test_exact_referenced_physical_bank_does_not_need_independent_action_declaration(self):
  m,d=self.source();self.assertEqual(literal_reference_ids(m,d),{9});self.assertTrue(supported_reference_issues(m,d))
 def test_another_numeric_bank_cannot_replace_missing_layer(self):
  m,d=self.source();m['original_members']=['Sprite/8-0.sp2'];self.assertFalse(supported_reference_issues(m,d))
 def test_duplicate_or_count_mismatch_does_not_become_literal(self):
  m,d=self.source();m['reference_issues'][0]['count']=2;self.assertFalse(supported_reference_issues(m,d))
  m['reference_issues']=[{'sprite_id':9,'issue':'clothes_count_mismatch','count':0}];self.assertFalse(supported_reference_issues(m,d))
 def test_declared_layer_alias_is_never_overridden_by_literal_asset(self):
  m,d=self.source();d[9]=[original_spr.Declaration(9,8,'fixture.spr',2)]
  self.assertEqual(literal_reference_ids(m,d),set());self.assertFalse(supported_reference_issues(m,d))
if __name__=='__main__':unittest.main()
