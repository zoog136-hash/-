import hashlib,unittest
import source_sparse_scope as scope
class SparseScopeTests(unittest.TestCase):
 def setUp(self):
  self.actor={'source_sprite_id':14325,'tracks':{'idle':{'source_sprite_id':14325,'source_action_id':3,'source_raw_body':'original','directions':[[{'physical_group':40}]]}}}
  self.rule={'actor_sprite_id':14325,'role':'idle','source_sprite_id':14325,'source_action_id':3,'source_raw_body_sha256':hashlib.sha256(b'original').hexdigest(),'physical_layer_id':14327,'chunk':40,'evidence':'source observation'}
  self.rules={'rules':[self.rule]};self.inventory={'14327':{'assets':[{'name':'Sprite/14327-48.sp2'}]}}
 def test_known_sparse_keeps_absence_distinct_from_empty(self):
  result=scope.classify(self.actor,14327,40,self.inventory,self.rules,'idle');self.assertEqual(result['classification'],'source_sparse_observed');self.assertFalse(result['explicit_empty']);self.assertEqual(result['required_draw'],'unverified')
 def test_changed_source_action_does_not_reuse_exception(self):
  self.actor['tracks']['idle']['source_raw_body']='changed';self.assertEqual(scope.classify(self.actor,14327,40,self.inventory,self.rules)['classification'],'sparse_chunk_not_located_unresolved')
 def test_entire_prefix_is_not_treated_as_sparse(self):
  self.assertEqual(scope.classify(self.actor,14327,40,{},self.rules)['classification'],'entire_layer_prefix_not_located')
 def test_indexed_but_untransferred_is_input_gap(self):
  self.inventory['14327']['assets'].append({'name':'Sprite/14327-40.sp2'});self.assertEqual(scope.classify(self.actor,14327,40,self.inventory,self.rules)['classification'],'indexed_file_not_materialized')
if __name__=='__main__':unittest.main()
