"""Preserve accepted animation data and bound authored north support trajectories."""
import hashlib,json,statistics,unittest
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
PATCH=ROOT/'assets/actors/eight_direction/native_production/girtas_267/r008'
class NorthContact(unittest.TestCase):
 def test_preserved_clips_and_unchanged_poses(self):
  s=json.loads((PATCH/'support_contact_patch.json').read_text());base=ROOT/s['base_frames'];self.assertEqual(hashlib.sha256(base.read_bytes()).hexdigest(),s['base_sha256']);expected=base.read_text().replace(s['original_sheet'],s['edited_sheet'])
  for key in s['calibration']:
   i=int(key);old,new=s['old_frames'][i],s['new_frames'][i]
   def text(f):return 'region = Rect2('+', '.join(map(str,f['region']))+')\nmargin = Rect2('+', '.join(map(str,f['margin']))+')'
   expected=expected.replace(text(old),text(new))
  self.assertEqual((PATCH/'SpriteFrames.tres').read_text(),expected)
  with Image.open(ROOT/s['original_sheet']) as old,Image.open(ROOT/s['edited_sheet']) as new:
   for i in range(6):
    if str(i) not in s['calibration']:
     x,y=(i%2)*1536,(i//2)*1536;box=(x,y,x+1536,y+1536);self.assertEqual(old.crop(box).tobytes(),new.crop(box).tobytes())
  self.assertFalse(s['visual_approval'])
 def test_boot_trajectory_not_cape_alpha(self):
  s=json.loads((PATCH/'support_contact_patch.json').read_text());feet={}
  for key,c in s['calibration'].items():
   f=s['new_frames'][int(key)];x,y,w,h=f['region'];can=f['canvas_size'][0]
   with Image.open(ROOT/s['edited_sheet']) as im:alpha=im.crop((x,y,x+w,y+h)).getchannel('A')
   x0,y0,x1,y1=c['boot_roi'];points=[(xx,yy) for yy in range(y0,y1) for xx in range(x0,x1) if alpha.getpixel((xx,yy))>16];sy=max(y for x,y in points);sx=statistics.median(x for x,y in points if y>=sy-2)
   self.assertLess(sy,h-5,'Support sole must not be clipped by frame edge')
   feet[key]=[(f['margin'][0]+sx-can/2)*.197194510559*1024/can,(f['margin'][1]+sy-can/2)*.219105011732*1024/can-28.045441501663]
  # Intended north stance moves toward image bottom as actor moves up.
  self.assertGreater(feet['1'][1]-feet['0'][1],14)
  self.assertLess(abs(feet['1'][0]-feet['0'][0]),1.5)
  if '4' in feet:
   self.assertGreater(feet['4'][1]-feet['3'][1],14)
   self.assertLess(abs(feet['4'][0]-feet['3'][0]),1.5)
  else:self.assertLess(feet['3'][1],-7)
if __name__=='__main__':unittest.main()
