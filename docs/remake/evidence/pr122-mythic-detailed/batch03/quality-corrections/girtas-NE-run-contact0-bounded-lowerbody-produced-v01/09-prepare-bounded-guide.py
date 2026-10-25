from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib
root=Path(__file__).parent
src=Path('/workspace/scratch/girtas-NE-run-LEFT-landing0-from-correct-farLEFT-walk-v03/girtas-NE-run-LEFT-landing0-from-correct-farLEFT-walk-v03.png')
im=Image.open(src).convert('RGBA')
poly=[(500,680),(650,680),(670,740),(692,790),(687,850),(690,900),(760,950),(790,990),(790,1170),(500,1170)]
mask=Image.new('L',im.size,0);ImageDraw.Draw(mask).polygon(poly,fill=255);mask.save(root/'exact-lowerbody-edit-mask.png')
guide=Image.new('RGBA',im.size,(34,39,43,255));guide.alpha_composite(im);d=ImageDraw.Draw(guide)
d.line(poly+[poly[0]],fill=(255,205,30,255),width=4)
# Sloped physical support interval, not a floor or exact hidden skeleton.
band=[(665,1004.6),(705,981.0),(705,929.0),(665,952.6)]
d.polygon(band,fill=(40,240,120,60));d.line(band+[band[0]],fill=(50,255,130,255),width=3)
d.ellipse((674,958,692,976),fill=(40,250,130,255),outline=(0,0,0,255),width=2)
d.line([(683,1143),(683,967)],fill=(255,100,50,255),width=5)
d.polygon([(683,958),(675,974),(691,974)],fill=(255,100,50,255))
d.text((36,30),'ONLY FAR-LEFT SUPPORT LEG BEND / KEEP UPPERBODY EXACT',(255,255,255,255))
d.text((36,58),'GREEN = new true heel support ~683,967; sloped physical band',(50,255,130,255))
d.text((36,86),'YELLOW = exact allowed local edit mask; preserve opposite RIGHT leg',(255,220,60,255))
d.text((36,114),'Bend real thigh/knee/shin; NOT boot translation / scale / root shift',(255,255,255,255))
guide.save(root/'same-owned-farLEFT-support-bend-target-guide.png')
# Small private review only.
g=guide.convert('RGB');g.thumbnail((720,720));g.save(root/'private-edit-mask-guide.jpg',quality=87)
obj={'schema':'pr122-bounded-edit-mask-proposal-v1','key':'transform:267','direction':'NE','role':'run','phase':0,'source_path':str(src),'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'source_canvas':[1254,1254],'fixed_runtime_canvas':1936,'edit_mask_polygon_native':poly,'strict_unchanged_outside_mask':True,'target_heel_nominal_native':[683,967],'target_heel_x_interval_native':[665,705],'target_heel_y_interval_at_x683':[942,994],'band_slope_dy_dx':-0.5903,'desired_core_height_world':[92,98],'load1_core_height_world':88.04,'existing_nearRIGHT_recovery_immutable':True,'status':'PENDING_INDEPENDENT_MASK_REVIEW_NO_GENERATION'}
for n in ['exact-lowerbody-edit-mask.png','same-owned-farLEFT-support-bend-target-guide.png']:
 p=root/n;obj[n]={'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
(root/'bounded-mask-proposal.json').write_text(json.dumps(obj,indent=2)+'\n')
print(json.dumps({'proposal':str(root/'bounded-mask-proposal.json'),'mask_sha256':obj['exact-lowerbody-edit-mask.png']['sha256'],'guide_bytes':(root/'private-edit-mask-guide.jpg').stat().st_size}))
