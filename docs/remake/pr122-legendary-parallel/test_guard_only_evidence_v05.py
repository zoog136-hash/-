"""Pure negative/positive evidence fixtures. No production assets are loaded."""
import copy,unittest
from guard_only_evidence_v05 import validate_preservation
class GuardProofTests(unittest.TestCase):
 def fixture(self):
  slot=['transform:1','NW','hit'];frames=[{'index':i,'region':[i,0,1,1],'margin':[0,0,0,0],'rgba_sha256':str(i)*64} for i in range(6)]
  s={'slot':slot,'frozen_issue_id':'visual-x','parent_record_sha256':'p'*64,'middle_frames_preserve_exact':frames[1:5],'guard_frames_preserve_exact':[frames[0],frames[5]]}
  r={'key':slot[0],'direction':slot[1],'role':slot[2],'guard_only_selection_sha256':'s'*64,'frozen_guard_issue':'visual-x','middle_four_RGBA_bindings_preserved':True,'automatic_checks':copy.deepcopy(frames)}
  rev={'slot':slot,'inherited_guard_checks':[{'action_phase':i,'parent_record_sha256':'p'*64} for i in [0,5]]}
  v={'status':'PASS','frames_reached':6};parents=[{'slot':slot,'status':'PASS','compared_parent_guards':2,'errors':[]}]
  return s,r,'s'*64,rev,v,parents
 def test_exact_middle_and_both_parent_guards(self):self.assertTrue(validate_preservation(*self.fixture()))
 def test_wrong_middle_RGBA_rejected(self):
  a=list(self.fixture());a[1]['automatic_checks'][2]['rgba_sha256']='bad'
  with self.assertRaises(ValueError):validate_preservation(*a)
 def test_virtual_canvas_parent_not_confirmed_rejected(self):
  a=list(self.fixture());a[5][0]['status']='FAIL'
  with self.assertRaises(ValueError):validate_preservation(*a)
 def test_fiveframes_cannot_close_camera(self):
  a=list(self.fixture());a[4]['frames_reached']=5
  with self.assertRaises(ValueError):validate_preservation(*a)
 def test_unhealthy_wrong_parent_identity_rejected(self):
  a=list(self.fixture());a[3]['inherited_guard_checks'][1]['parent_record_sha256']='other'
  with self.assertRaises(ValueError):validate_preservation(*a)
if __name__=='__main__':unittest.main()
