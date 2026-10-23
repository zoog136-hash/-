#!/usr/bin/env python3
"""Pure final-report metadata fixtures; no production corpus is traversed."""
import copy,importlib.util,unittest
from pathlib import Path
s=importlib.util.spec_from_file_location('a',Path(__file__).with_name('additional_quality_evidence_v05.py'));m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class Exact(unittest.TestCase):
 def setUp(self):
  self.view={'frozen_review_sha256':m.core.FROZEN_SHA,'candidate':'qc100','actor':'114','direction':'NW','role':'attack','record_sha256':'a'*64,'source':'new.png','source_sha256':'b'*64,'SpriteFrames_sha256':'c'*64,'camera_result':'RESOLVED_STATIC','identity_result':'PRESERVED_STATIC','motion_role_result':'ARTICULATED_ORIGINAL_WEAPON_ATTACK_STATIC_SEQUENCE','remaining_issues':[]};self.record={'frozen_review_sha256':m.core.FROZEN_SHA,'correction_candidate_id':'qc100','key':'transform:114','direction':'NW','role':'attack','source':'new.png','source_sha256':'b'*64,'output_spriteframes_sha256':'c'*64,'previous_source':'old.png','previous_source_sha256':'d'*64};self.rev={'record_sha256':'a'*64,'SpriteFrames_sha256':'c'*64};self.issue={'affected_source':'old.png','source_sha256':'d'*64,'cause':'camera'}
 def test_exact_source_and_slot_pass(self):self.assertTrue(m.validate_unit(self.view,self.record,'a'*64,self.rev))
 def test_different_source_sha_rejected(self):
  self.view['source_sha256']='e'*64
  with self.assertRaises(ValueError):m.validate_unit(self.view,self.record,'a'*64,self.rev)
 def test_unrelated_old_issue_cannot_resolve(self):
  self.issue['source_sha256']='f'*64;self.assertIsNone(m.issue_resolution(self.view,self.record,self.issue))
 def test_camera_hold_cannot_resolve(self):
  self.view['camera_result']='HOLD';self.assertIsNone(m.issue_resolution(self.view,self.record,self.issue))
 def test_weapon_action_requires_actual_original_weapon_sequence(self):
  self.issue['cause']='identity_weapon_action';self.assertEqual(m.issue_resolution(self.view,self.record,self.issue),'STATIC_ORIGINAL_WEAPON_ACTION_ONLY');self.view['motion_role_result']='RUN_POSES_PRESENT';self.assertIsNone(m.issue_resolution(self.view,self.record,self.issue))
 def test_remaining_cause_blocks_only_that_cause(self):
  self.view['remaining_issues']=[{'cause':'identity_weapon_action'}];self.assertEqual(m.issue_resolution(self.view,self.record,self.issue),'STATIC_CAMERA_ONLY');self.issue['cause']='identity_weapon_action';self.assertIsNone(m.issue_resolution(self.view,self.record,self.issue))
if __name__=='__main__':unittest.main()
