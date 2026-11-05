"""Explicit IsSpawn0 metadata only; this does not instantiate original resources."""
import unittest
from build_base508_geographic_regions import applied_rows
class ProjectionTests(unittest.TestCase):
 def test_only_explicit_zero_is_removed_and_source_is_preserved(self):
  rows=[{'is_spawn_raw':0,'id':1},{'is_spawn_raw':1,'server_limit_set_id_raw':99,'id':2},{'is_spawn_raw':2,'id':3},{'id':4},{'is_spawn_raw':False,'id':5}]
  projected=applied_rows(rows)
  self.assertEqual([r['id']for r in projected],[2,3,4,5]);self.assertEqual(rows[0],{'is_spawn_raw':0,'id':1});self.assertIs(projected[0],rows[1])
if __name__=='__main__':unittest.main()
