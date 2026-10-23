import copy,unittest
from active_findings_projection_v06 import selected_poses_with_aliases,bind_native_aliases
class NativeAliasBoundaryTests(unittest.TestCase):
 def fixture(self):
  original='assets/native/poses-1.png';sha='a'*64
  record={'key':'transform:176','source':'assets/new.png','source_sha256':'b'*64,'source_files':[{'path':'assets/native-preserved.png','sha256':sha,'source_kind':'preserved_native'}],'existing_pose_metadata':[{'original_pose_id':69,'source_path':original,'region':[1,2,3,4],'margin':[5,6,7,8],'rgba_sha256':'c'*64}],'source_pose_sequence':[{'phase':0,'source_kind':'reused','original_pose_id':69,'original_region':[1,2,3,4]}]+[{'phase':i} for i in range(1,6)],'automatic_checks':[{'index':i,'region':[1,2,3,4],'rgba_sha256':'c'*64} for i in range(6)]}
  return record,{original:sha}
 def test_one_SHA_identical_copy_binds_without_record_or_frame_mutation(self):
  r,k=self.fixture();old=copy.deepcopy(r);poses,notes=selected_poses_with_aliases(r,k)
  self.assertEqual(r,old);self.assertEqual(poses[0]['source'],'assets/native-preserved.png');self.assertEqual(poses[0]['region'],[1,2,3,4]);self.assertEqual(poses[0]['rgba_sha256'],'c'*64);self.assertEqual(len(notes),1)
 def test_SHA_mismatch_does_not_guess_by_filename(self):
  r,k=self.fixture();r['source_files'][0]['sha256']='d'*64
  with self.assertRaises(ValueError):bind_native_aliases(r,k)
 def test_two_identical_copies_remain_ambiguous(self):
  r,k=self.fixture();r['source_files'].append(dict(r['source_files'][0],path='assets/another-copy.png'))
  with self.assertRaises(ValueError):bind_native_aliases(r,k)
 def test_original_header_preserves_three_native_poses_instead_of_calling_them_new(self):
  r,k=self.fixture();r.pop('existing_pose_metadata');original=next(iter(k));r.update(reused_source_original_path=original,reused_source_sha256=k[original],original_reused_regions_margins_rgba_unchanged=True)
  r['source_pose_sequence']=[{'phase':i,'source_kind':'reused','original_pose_id':40+i,'original_region':[1,2,3,4],'original_margin':[5,6,7,8],'rgba_sha256':'c'*64} if i in [0,3,5] else {'phase':i,'source_kind':'new'} for i in range(6)]
  old=copy.deepcopy(r);poses,notes=selected_poses_with_aliases(r,k)
  self.assertEqual(sum(p['source_sha256']==k[original] for p in poses),3)
  self.assertEqual(r,old)
if __name__=='__main__':unittest.main()
