import unittest
from base508_variants import split_variants,unplaced_members

class VariantTests(unittest.TestCase):
 def test_s32_wins_same_coordinate_without_dropping_legacy(self):
  seg={'member':'Map/13146/7fff7fff.seg'};s32={'member':'Map/13146/7fff7fff.s32'};other={'member':'Map/13146/80008000.s32'}
  primary,variants=split_variants([seg,other,s32]);self.assertEqual(primary,[s32,other]);self.assertEqual(variants,[seg])
 def test_group_identity_is_not_merged_by_basename(self):
  a={'member':'Map/1/7fff8000.s32'};b={'member':'Map/2/7fff8000.seg'};primary,variants=split_variants([a,b]);self.assertEqual(len(primary),2);self.assertEqual(variants,[])
 def test_legacy_only_geometry_is_retained_for_explicit_review(self):
  seg={'member':'Map/unreferenced/7fff8000.seg'};self.assertEqual(split_variants([seg]),([seg],[]))
 def test_noncanonical_filename_is_preserved_as_unplaced_not_guessed(self):
  extra={'member':'Map/Aden/800f7ff3e.s32'};normal={'member':'Map/Aden/800f7ff3.s32'}
  self.assertEqual(split_variants([extra,normal]),([normal],[]));self.assertEqual(unplaced_members([extra,normal]),[extra])
if __name__=='__main__':unittest.main()
