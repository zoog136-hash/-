#!/usr/bin/env python3
"""Pure ownership-to-body-review fixtures, without any PNG reads."""
import copy,importlib.util,unittest
from pathlib import Path
s=importlib.util.spec_from_file_location('p',Path(__file__).with_name('prepare_isolated_parent_evidence_v04.py'));m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class Mapping(unittest.TestCase):
 def setUp(self):
  self.v={'record':'res://raw.json','record_sha256':'a'*64,'source':'raw.png','source_sha256':'b'*64};self.t={'findings':[{'code':'FOREIGN_POSE_FOREGROUND_INSIDE_FRAME'}]};self.r={'revision_parent':'res://raw.json','revision_parent_sha256':'a'*64,'source':'res://isolated.png','source_sha256':'c'*64,'automatic_checks':[{'index':i,'region':[i*10,0,10,10]} for i in range(6)]};self.p={'source':'raw.png','source_sha256':'b'*64,'output':'isolated.png','output_sha256':'c'*64,'resampled':False,'recolored':False,'original_source_mutations':0,'source_foreground_pixels':600,'source_visible_pixels':600,'visible_source_coverage':'EXACTLY_ONCE','integer_translation_verification':'PASS','poses':[{'original_phase':i,'region':[i*10,0,10,10],'translation':[3,4],'source_positions_sha256':'d'*64,'source_rgba_sha256':'e'*64} for i in range(6)]};self.index={'source_findings':[{'source':'raw.png','sha256':'b'*64,'findings':copy.deepcopy(self.t['findings'])}]}
 def validate(self):return m.validate_mapping(self.v,self.t,{},self.r,self.p,self.index)
 def test_integer_mapping_preserves_guard_owned_pixels_and_phases(self):
  x=self.validate();self.assertEqual([r['index'] for r in x],[0,5]);self.assertEqual(x[0]['source_rgba_sha256'],'e'*64)
 def test_fractional_translation_rejected(self):
  self.p['poses'][0]['translation'][0]=.5
  with self.assertRaises(ValueError):self.validate()
 def test_incomplete_coverage_rejected(self):
  self.p['visible_source_coverage']='UNKNOWN'
  with self.assertRaises(ValueError):self.validate()
 def test_different_camera_source_rejected(self):
  self.p['source_sha256']='f'*64
  with self.assertRaises(ValueError):self.validate()
 def test_ambiguous_ownership_does_not_release_parent(self):
  self.t['findings'].append({'code':'DETACHED_FOREGROUND_OWNER_AMBIGUOUS'})
  with self.assertRaises(ValueError):self.validate()
if __name__=='__main__':unittest.main()
