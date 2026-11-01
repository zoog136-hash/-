"""Protect accepted poses/clocks while checking W stance trajectory; not visual approval."""
import hashlib
import json
from pathlib import Path
import unittest
from PIL import Image
import statistics
ROOT = Path(__file__).resolve().parents[1]
PATCH = ROOT / 'assets/actors/eight_direction/native_production/girtas_267/r007'
class WestSupportContact(unittest.TestCase):
    def test_preserved_poses_and_clocks(self):
        s = json.loads((PATCH/'support_contact_patch.json').read_text())
        base = ROOT/s['base_frames']
        self.assertEqual(hashlib.sha256(base.read_bytes()).hexdigest(), s['base_sha256'])
        expected = base.read_text().replace(s['original_sheet'], s['edited_sheet']).replace(
            'region = Rect2(1677, 141, 1254, 1254)\nmargin = Rect2(694, 562, 1434, 1434)',
            'region = Rect2(1677, 141, 1254, 1254)\nmargin = Rect2(694, 558, 1434, 1434)')
        self.assertEqual((PATCH/'SpriteFrames.tres').read_text(), expected)
        with Image.open(ROOT/s['original_sheet']) as old, Image.open(ROOT/s['edited_sheet']) as new:
            for box in [(0,0,1536,1536), (0,1536,3072,4608)]:
                self.assertEqual(old.crop(box).tobytes(), new.crop(box).tobytes())
        self.assertFalse(s['visual_approval'])
    def test_stance_boot_trajectory_and_ground(self):
        s = json.loads((PATCH/'support_contact_patch.json').read_text())
        f = s['new_phase1']; x,y,w,h = f['region']
        with Image.open(ROOT/s['edited_sheet']) as image:
            alpha=image.crop((x,y,x+w,y+h)).getchannel('A')
            # Boot-only ROI; excludes cape and lifted opposite foot.
            points=[(xx,yy) for yy in range(1000,1140) for xx in range(450,780) if alpha.getpixel((xx,yy))>16]
        sole_y=max(yy for xx,yy in points)
        sole_x=statistics.median(xx for xx,yy in points if yy>=sole_y-2)
        self.assertEqual(f['margin'][1]+sole_y,562+1108)
        local_x=(f['margin'][0]+sole_x-2688/2)*.197194510559*1024/2688
        advance=local_x-(-19.95608447)
        self.assertLess(abs(16.8-advance),1.2)
if __name__=='__main__': unittest.main()
