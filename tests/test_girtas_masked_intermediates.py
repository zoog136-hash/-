"""Preserve source art and cycle while inserting two real local leg poses."""
import unittest,json,hashlib,re
from pathlib import Path
from PIL import Image,ImageChops
ROOT=Path(__file__).resolve().parents[1]
D=ROOT/'assets/actors/eight_direction/native_production/girtas_267/r010'
class MaskedIntermediates(unittest.TestCase):
 def test_original_cells_and_nonedited_pixels(self):
  p=json.loads((D/'inbetween_patch.json').read_text())
  for direction,t in p['tracks'].items():
   with Image.open(ROOT/t['original_sheet']) as old,Image.open(ROOT/t['edited_sheet']) as new:
    old=old.convert('RGBA');new=new.convert('RGBA')
    self.assertEqual(old.tobytes(),new.crop((0,0,*old.size)).tobytes())
    f=t['old_frames'][0];x,y,w,h=f['region'];base=old.crop((x,y,x+w,y+h));f=t['new_frames'][1];x,y,w,h=f['region'];mid=new.crop((x,y,x+w,y+h));mask=Image.open(ROOT/t['mask']).convert('L')
    self.assertEqual(base.size,mid.size)
    self.assertEqual(Image.composite(mid,base,ImageChops.invert(mask)).tobytes(),base.tobytes(),'Outside hard mask must retain original body/equipment pixels')
    self.assertNotEqual(base.tobytes(),mid.tobytes(),'A real new leg pose, not a repeated frame')
    self.assertEqual(sum(f['duration'] for f in t['new_frames']),6)
    self.assertEqual([f['duration'] for f in t['new_frames']],[.5,.5,1,1,1,1,1])
 def test_unchanged_other_tracks_and_original_atlases(self):
  p=json.loads((D/'inbetween_patch.json').read_text());before=(ROOT/p['base_frames']).read_text();after=(D/'SpriteFrames.tres').read_text()
  # Every old atlas keeps its original geometry; only sheet paths change.
  blocks=lambda text:dict(re.findall(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\n(.*?)(?=\n\[)',text,re.S))
  a,b=blocks(before),blocks(after)
  self.assertEqual(set(b)-set(a),{'track_4_mid','track_46_mid'})
  for k,v in a.items():self.assertEqual(v,b[k])
  clips=lambda text:dict((name,block) for block,name in re.findall(r'(\{"frames":.*?"name": &"([^"]+)".*?\})',text,re.S))
  a,b=clips(before),clips(after)
  for k in a:
   if k not in ['run_0','run_4']:self.assertEqual(a[k],b[k],k)
if __name__=='__main__':unittest.main()
