"""An existing calf pose may fill a support phase without altering current art."""
import json,unittest
from pathlib import Path
from PIL import Image,ImageChops
ROOT=Path(__file__).resolve().parents[1];D=ROOT/'assets/actors/eight_direction/native_production/girtas_267/r011'
class NorthIntermediate(unittest.TestCase):
 def test_mask_preservation_and_original_sequence(self):
  s=json.loads((D/'inbetween_patch.json').read_text());old=Image.open(ROOT/s['original_sheet']).convert('RGBA');new=Image.open(ROOT/s['edited_sheet']).convert('RGBA');self.assertEqual(old.tobytes(),new.crop((0,0,*old.size)).tobytes());f=s['old_frames'][3];x,y,w,h=f['region'];base=old.crop((x,y,x+w,y+h));f=s['new_frames'][4];x,y,w,h=f['region'];mid=new.crop((x,y,x+w,y+h));mask=Image.open(ROOT/s['mask']).convert('L');self.assertEqual(Image.composite(mid,base,ImageChops.invert(mask)).tobytes(),base.tobytes());self.assertNotEqual(mid.tobytes(),base.tobytes());self.assertEqual([f['duration']for f in s['new_frames']],[1,1,1,.5,.5,1,1]);self.assertEqual(sum(f['duration']for f in s['new_frames']),6)
 def test_only_north_support_duration_and_atlas_added(self):
  s=json.loads((D/'inbetween_patch.json').read_text());expected=(ROOT/s['base_frames']).read_text().replace('load_steps=339','load_steps=340').replace(s['original_sheet'],s['edited_sheet']);f=s['new_frames'][4];block='[sub_resource type="AtlasTexture" id="track_10_mid"]\natlas = ExtResource("11")\nregion = Rect2('+', '.join(map(str,f['region']))+')\nmargin = Rect2('+', '.join(map(str,f['margin']))+')\nfilter_clip = true\n\n';expected=expected.replace('[resource]\n',block+'[resource]\n').replace('{"duration": 1.0, "texture": SubResource("track_10_3")},','{"duration": 0.5, "texture": SubResource("track_10_3")},\n{"duration": 0.5, "texture": SubResource("track_10_mid")},');self.assertEqual(expected,(D/'SpriteFrames.tres').read_text())
if __name__=='__main__':unittest.main()
