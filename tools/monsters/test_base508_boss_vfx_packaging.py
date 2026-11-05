"""Synthetic inventory contracts; these bytes are not original SP2 pixels."""
import copy,hashlib,json,tempfile,unittest
from pathlib import Path
from package_base508_monster_install import boss_vfx_files
class BossVfxPackagingTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
  self.packet={'path':'sp2/1-0.bin','sha256':self.write('boss_vfx/sp2/1-0.bin',b'synthetic numeric inventory fixture')}
  layer={**self.packet,'codec':'base508_sp2_v1'}
  self.model={'source_snapshot':'base508','source_sprite_id':1,'source_pixels_complete':False,'source_gaps':[{'layer_id':2}],'tracks':{'effect':{'source_sprite_id':1,'source_action_id':0,'directions':[[{'layers':[layer]}]]+[[]for _ in range(7)]}}}
  self.data={'kind':'base508_boss_literal_sp2_effects','source_snapshot':'base508','models':{'1':{'path':'effects/1.json'}},'source_files':{'Sprite/1-0.sp2':self.packet}}
  self.manifest={};self.refresh()
 def write(self,relative,data):
  p=self.root/relative;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data);return hashlib.sha256(data).hexdigest()
 def refresh(self):
  self.data['models']['1']['sha256']=self.write('boss_vfx/effects/1.json',json.dumps(self.model).encode())
  sha=self.write('boss_vfx/boss_vfx.json',json.dumps(self.data).encode());self.manifest={'boss_vfx':{'path':'boss_vfx/boss_vfx.json','sha256':sha}}
 def test_legacy_absence_is_noop(self):self.assertEqual(boss_vfx_files(self.root,{}),set())
 def test_partial_composition_inventory_is_allowed(self):self.assertEqual(boss_vfx_files(self.root,self.manifest),{'boss_vfx/boss_vfx.json','boss_vfx/effects/1.json','boss_vfx/sp2/1-0.bin'})
 def test_malformed_manifest_sha_rejected(self):
  self.manifest['boss_vfx']['sha256']='z'*64
  with self.assertRaises(ValueError):boss_vfx_files(self.root,self.manifest)
 def test_missing_packet_rejected(self):
  (self.root/'boss_vfx/sp2/1-0.bin').unlink()
  with self.assertRaises(ValueError):boss_vfx_files(self.root,self.manifest)
 def test_packet_hash_mismatch_rejected(self):
  self.write('boss_vfx/sp2/1-0.bin',b'changed')
  with self.assertRaises(ValueError):boss_vfx_files(self.root,self.manifest)
 def test_traversal_rejected(self):
  self.packet['path']='sp2/../../outside.bin';self.refresh()
  with self.assertRaises(ValueError):boss_vfx_files(self.root,self.manifest)
 def test_wrong_kind_rejected(self):
  self.data['kind']='other';self.refresh()
  with self.assertRaises(ValueError):boss_vfx_files(self.root,self.manifest)
 def test_wrong_source_sprite_rejected(self):
  self.model['source_sprite_id']=2;self.refresh()
  with self.assertRaises(ValueError):boss_vfx_files(self.root,self.manifest)
 def test_undeclared_layer_rejected(self):
  self.model['tracks']['effect']['directions'][0][0]['layers'][0]['path']='sp2/missing.bin';self.refresh()
  with self.assertRaises(ValueError):boss_vfx_files(self.root,self.manifest)
 def test_packet_symlink_outside_root_rejected(self):
  with tempfile.TemporaryDirectory()as other:
   p=Path(other)/'packet';p.write_bytes(b'synthetic numeric inventory fixture');target=self.root/'boss_vfx/sp2/1-0.bin';target.unlink();target.symlink_to(p)
   with self.assertRaises(ValueError):boss_vfx_files(self.root,self.manifest)
if __name__=='__main__':unittest.main()
