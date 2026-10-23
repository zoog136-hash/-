import unittest
from unittest.mock import patch
import active_findings_projection_v05 as current
class ScopeSelectionTests(unittest.TestCase):
 def test_new_scopes_cannot_bypass_exact_selected_source_check(self):
  for status in ['RESOLVED_STATIC_EQUIPMENT_ACTION','RESOLVED_EXPLICIT_GUARD_CAMERA_ONLY']:
   row={'resolution_status':status};r={'visual_findings':[row]}
   def project(result,*a):
    self.assertEqual(row['resolution_status'],'RESOLVED_STATIC_CAMERA')
    row['active_annotation']={'historical_resolution_status_preserved':'RESOLVED_STATIC_CAMERA','active_residual_status':'HISTORICAL_CAMERA_PROOF_NOT_SELECTED_REQUIRES_QA'}
    return result
   with patch.object(current.previous,'annotate',side_effect=project):current.annotate(r,{}, {},{},[])
   self.assertEqual(row['resolution_status'],status);self.assertEqual(row['active_annotation']['historical_resolution_status_preserved'],status)
   self.assertEqual(row['active_annotation']['active_residual_status'],'HISTORICAL_CAMERA_PROOF_NOT_SELECTED_REQUIRES_QA')
 def test_exception_restores_immutable_scope(self):
  row={'resolution_status':'RESOLVED_STATIC_EQUIPMENT_ACTION'}
  with patch.object(current.previous,'annotate',side_effect=ValueError('bad evidence')):
   with self.assertRaises(ValueError):current.annotate({'visual_findings':[row]}, {},{},{},[])
  self.assertEqual(row['resolution_status'],'RESOLVED_STATIC_EQUIPMENT_ACTION')
if __name__=='__main__':unittest.main()
