#!/usr/bin/env python3
"""Pure metadata fixtures; production PNG, claim and image APIs are not used."""
import copy, hashlib, importlib.util, json, unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
P=Path(__file__).with_name('prepare_quality_dependencies_v07.py');s=importlib.util.spec_from_file_location('v07',P);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class Contract(unittest.TestCase):
 def test_guard_only_exclusion_preserves_history_and_removes_request(self):
  jobs=[{'correction_candidate_id':x,'state':'READY','request':x+'.json','batch':309,'request_sha256':'a'} for x in ['qc063','qc098','qc110']];p={'jobs':jobs,'allowed_candidate_ids':['qc063','qc098','qc110']};writes={m.base.WORK/j['request']:{'unchanged':True} for j in jobs};before=list(p['allowed_candidate_ids']);p,w=m.exclude_guard_only(p,writes)
  self.assertEqual(p['allowed_candidate_ids'],before);self.assertEqual([j['state'] for j in p['jobs']],['GUARD_REBIND_ONLY_NO_NEW_IMAGE','GUARD_REBIND_ONLY_NO_NEW_IMAGE','READY']);self.assertEqual(list(w),[m.base.WORK/'qc110.json'])
 def test_guard_only_claim_never_reads_or_reserves(self):
  with patch.object(m.base,'raw_json',side_effect=AssertionError('No file reads')):
   self.assertEqual(m.claim(Path('/nonexistent'),'qc063',True)['status'],'WAIT')
 def test_primary71_claim_excluded_even_before_old_queue_settles(self):
  with patch.object(m.base,'raw_json',side_effect=AssertionError('No file reads')):
   self.assertEqual(m.claim(Path('/nonexistent'),'qc033',True)['reason'],'PRIMARY71_SEPARATE_QUEUE_NO_DUPLICATE_CALL')
 def parent(self,reg):
  revision={'record_sha256':'a'*64,'SpriteFrames_sha256':'b'*64};proof={'registration':{'path':'res://docs/fake.json','sha256':hashlib.sha256(json.dumps(reg).encode()).hexdigest()},'remote_receipt':{'path':'fake','sha256':'0'*64}};obj=object.__new__(m.Preparation);obj.artifact=lambda ref:({'status':'REMOTE_SAVED','remote_sha':'c'*40},'0'*64)
  return obj,revision,proof
 def test_virtual_canvas_parent_keeps_original_anchor(self):
  reg={'record_sha256':'a'*64,'SpriteFrames_sha256':'b'*64,'frames':[{'index':i,'anchor_in_texture':[271,279],'scale':[1,1],'baseline_center':[256,256]} for i in [0,5]]};obj,r,p=self.parent(reg);raw=json.dumps(reg).encode()
  with patch.object(m.base.Preparation,'accepted_parent',return_value=((r,{},[],p),None)),patch.object(m.base,'raw_json',return_value=(reg,p['registration']['sha256'])),patch.object(m.base.subprocess,'run',return_value=SimpleNamespace(returncode=0,stdout=raw)):
   accepted,reason=obj.accepted_parent({})
  self.assertIsNone(reason);inherit=accepted[3]['preserve_guard_registration'];self.assertEqual(inherit['frames'][0]['anchor_in_texture'],[271,279]);self.assertFalse(inherit['recenter_isolated_guard_virtual_canvas'])
 def test_parent_record_mismatch_stays_wait(self):
  reg={'record_sha256':'d'*64,'SpriteFrames_sha256':'b'*64,'frames':[]};obj,r,p=self.parent(reg)
  with patch.object(m.base.Preparation,'accepted_parent',return_value=((r,{},[],p),None)),patch.object(m.base,'raw_json',return_value=(reg,p['registration']['sha256'])):
   accepted,reason=obj.accepted_parent({})
  self.assertIsNone(accepted);self.assertEqual(reason,'WAIT_PARENT_REGISTRATION_RECORD_RESOURCE_SHA')
 def test_missing_parent_registration_never_materializes(self):
  obj=object.__new__(m.Preparation)
  with patch.object(m.base.Preparation,'accepted_parent',return_value=(({}, {}, [], {}),None)):
   accepted,reason=obj.accepted_parent({})
  self.assertIsNone(accepted);self.assertEqual(reason,'WAIT_EXACT_PARENT_REGISTRATION_METADATA')
if __name__=='__main__':unittest.main()
