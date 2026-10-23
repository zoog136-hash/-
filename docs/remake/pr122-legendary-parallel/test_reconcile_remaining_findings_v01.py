"""Evidence-boundary tests; no real source images or final reconciliation."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

import reconcile_remaining_findings_v01 as report

A='a'*64
B='b'*64
C='c'*64

class EvidenceBoundaryTests(unittest.TestCase):
 def setUp(self):
  self.issue={'issue_id':'visual-test-1','affected_source':'assets/test-source.png','source_sha256':A,'cause':'clipped_or_foreign_body','status':'ERROR_VISUAL'}
  self.proof={'source':'assets/test-source.png','source_sha256':A,'proof':'assets/test.proof.json','proof_sha256':B,'remote_commit':'d'*40,'scope':'LOSSLESS_OWNERSHIP_ONLY_NO_CAMERA_OR_ART_APPROVAL','phases':[1,2,3,4]}
  self.ownership={self.issue['affected_source']:self.proof}

 def test_ownership_never_closes_camera_or_identity(self):
  for cause in ('camera','identity_weapon_action','articulation'):
   issue=dict(self.issue,cause=cause)
   self.assertEqual(report.visual_resolution(issue,{},self.ownership)[0],'UNMODIFIED')

 def test_combined_visual_clipping_needs_exact_adjudication(self):
  self.assertEqual(report.visual_resolution(self.issue,{},self.ownership)[0],'HOLD_TECHNICAL_OWNERSHIP_COVERAGE')
  claim={'issue_id':self.issue['issue_id'],'source':self.issue['affected_source'],'source_sha256':A,'proof_sha256':B,'affected_phases':[3,4],'resolution_scope':'TECHNICAL_OWNERSHIP_ONLY'}
  self.assertEqual(report.visual_resolution(self.issue,{},self.ownership,{self.issue['issue_id']:claim})[0],'RESOLVED_TECHNICAL_OWNERSHIP')

 def test_wrong_proof_or_phase_cannot_close_a_visual_issue(self):
  base={'source':self.issue['affected_source'],'source_sha256':A,'proof_sha256':B,'affected_phases':[3],'resolution_scope':'TECHNICAL_OWNERSHIP_ONLY'}
  for field,value in [('source_sha256',C),('proof_sha256',C),('affected_phases',[0]),('affected_phases',[])]:
   claim=dict(base,**{field:value})
   self.assertEqual(report.visual_resolution(self.issue,{},self.ownership,{self.issue['issue_id']:claim})[0],'HOLD_TECHNICAL_OWNERSHIP_COVERAGE')

 def test_same_filename_different_source_sha_is_not_evidence(self):
  issue=dict(self.issue,source_sha256=C)
  self.assertEqual(report.visual_resolution(issue,{},self.ownership)[0],'UNMODIFIED')

 def test_only_json_can_be_opened(self):
  with self.assertRaisesRegex(ValueError,'Only JSON'):
   report.safe_json('/a/nonexistent/normal-source.png')

 def test_pending_remote_receipt_is_not_completed(self):
  e=report.Evidence('/tmp','d'*40)
  e.artifact=lambda _:({'status':'PENDING_REMOTE','remote_sha':'d'*40},A)
  with self.assertRaisesRegex(ValueError,'Pending/failed'):
   e.remote({'path':'pending.json','sha256':A})

 def test_translation_proof_rejects_resampling_or_source_drift(self):
  p={'source':'assets/test-source.png','source_sha256':A,'source_review_sha256':C,'baseline_sha':report.BASELINE,'resampled':False,'recolored':False,'newly_authored_poses':0,'output_sha256':B,'source_foreground_pixels':5,'poses':[{'original_phase':1,'foreground_pixels':2,'translation':[3,4],'source_positions_sha256':A,'source_rgba_sha256':B},{'original_phase':2,'foreground_pixels':3,'translation':[5,6],'source_positions_sha256':C,'source_rgba_sha256':A}]}
  known={'source':'assets/test-source.png','sha256':A}
  self.assertTrue(report.valid_translation_proof(p,known,C))
  for field,value in [('source_sha256',B),('resampled',True),('recolored',True),('newly_authored_poses',1),('source_foreground_pixels',6)]:
   bad=dict(p,**{field:value});self.assertFalse(report.valid_translation_proof(bad,known,C))

 def test_incomplete_root_gate_never_runs_reconciliation(self):
  with tempfile.TemporaryDirectory() as folder:
   gate=Path(folder)/'gate.json';gate.write_text(json.dumps({'all_possible_corrections_complete':False,'local_integration_checks_complete':True}))
   with self.assertRaisesRegex(ValueError,'no reconciliation executed'):
    report.finalize(gate)

 def test_completion_flags_without_runtime_receipt_do_not_finalize(self):
  with tempfile.TemporaryDirectory() as folder:
   gate=Path(folder)/'gate.json';gate.write_text(json.dumps({'all_possible_corrections_complete':True,'local_integration_checks_complete':True,'integration_receipts':[]}))
   with self.assertRaisesRegex(ValueError,'runtime/CI receipt'):
    report.finalize(gate)

 def test_targeted_quality_source_is_separate_and_unknown_source_does_not_abort_batch(self):
  source='assets/actors/eight_direction/legendary_parallel/transform_1/quality-v02/E-idle-source-v02.png';slot=['transform:1','E','idle'];proof_path='assets/revision.proof.json';record_path='assets/revision-record.json'
  known={'source':source,'sha256':A,'grid':[1,1],'authored_slot':slot,'findings':[{'code':'FOREIGN_POSE_FOREGROUND_INSIDE_FRAME','severity':'ERROR','phase':0}],'dependents':[{'slot':slot,'phase':0,'region':[0,0,10,10]}]}
  proof={'source':source,'source_sha256':A,'source_review_sha256':C,'baseline_sha':report.BASELINE,'grid':[1,1],'resampled':False,'recolored':False,'newly_authored_poses':0,'output':'assets/revision.png','output_sha256':B,'source_foreground_pixels':5,'poses':[{'original_phase':0,'foreground_pixels':5,'translation':[8,8],'source_positions_sha256':A,'source_rgba_sha256':B}]}
  record={'key':'transform:1','direction':'E','role':'idle','source':'assets/revision.png','source_sha256':B,'output_spriteframes_sha256':A,'isolation_proofs':[proof_path],'automatic_checks':[{'index':i,'rgba_sha256':A} for i in range(6)]}
  revision={'slot':slot,'record':record_path,'record_sha256':A,'SpriteFrames':'assets/revision.tres','SpriteFrames_sha256':A}
  manifest={'baseline_sha':report.BASELINE,'revisions':[revision],'source_outcomes':[{'source':'assets/unregistered.png','status':'INTEGER_TRANSLATION_PROOF_PASS','proof':'assets/unknown.proof.json'},{'source':source,'status':'INTEGER_TRANSLATION_PROOF_PASS','proof':proof_path}]}
  data={'target.json':({'baseline_sha':report.BASELINE,'frozen_review_sha256':report.FROZEN_SHA,'source_findings':[known]},C),'manifest.json':(manifest,A),'validation.json':({'records':[{'record':record_path,'status':'PASS','frames_reached':6}]},A),proof_path:(proof,B),record_path:(record,A)}
  class FakeEvidence:
   head='d'*40
   def __init__(self):self.rejected=[]
   def artifact(self,ref):return data[ref['path']]
   def json(self,path,expected=None):return data[report.path_text(path)]
   def committed_json(self,*args):return None
   def remote(self,ref):return {'status':'REMOTE_SAVED','batch':21,'batch_sources':1},A,self.head
  e=FakeEvidence();ref=lambda p:{'path':p,'sha256':A};gate={'targeted_technical_artifacts':[ref('target.json')],'ownership_batches':[{'manifest':ref('manifest.json'),'validations':[ref('validation.json')],'remote_receipt':ref('delivery.json')}]}
  accepted,batches,followups=report.ownership_evidence(e,gate,{'source_findings':[]},B)
  self.assertEqual(accepted[source]['origin'],'targeted_quality_followup');self.assertEqual(len(followups),1);self.assertEqual(batches[0]['proven_sources'],[source]);self.assertEqual(e.rejected[0]['kind'],'ownership_source')

if __name__=='__main__':unittest.main()
