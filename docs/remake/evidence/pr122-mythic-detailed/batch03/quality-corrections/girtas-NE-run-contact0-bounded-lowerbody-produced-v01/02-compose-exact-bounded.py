from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib,numpy as np
root=Path(__file__).parent
src=Path('/workspace/scratch/girtas-NE-run-LEFT-landing0-from-correct-farLEFT-walk-v03/girtas-NE-run-LEFT-landing0-from-correct-farLEFT-walk-v03.png')
gen=root/'generated-uncomposited-original.png';mp=root/'exact-lowerbody-edit-mask.png'
s=Image.open(src).convert('RGBA');g=Image.open(gen).convert('RGBA');mask=Image.open(mp).convert('L')
assert s.size==g.size==mask.size==(1254,1254)
out=Image.composite(g,s,mask);p=root/'girtas-NE-run-contact0-bounded-leg-repair-v01.png';out.save(p)
a=np.array(s);b=np.array(out);m=np.array(mask)>0;diff=np.any(a!=b,axis=2)
assert not diff[~m].any()
ys,xs=np.where(diff);visible=np.array(out.getchannel('A'))>16;vy,vx=np.where(visible)
o={'schema':'pr122-exact-bounded-lowerbody-edit-proof-v1','key':'transform:267','direction':'NE','role':'run','phase':0,'source_path':str(src),'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'generated_raw_path':str(gen),'generated_raw_sha256':hashlib.sha256(gen.read_bytes()).hexdigest(),'mask_path':str(mp),'mask_sha256':hashlib.sha256(mp.read_bytes()).hexdigest(),'output_path':str(p),'output_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'output_bytes':p.stat().st_size,'image_size':list(out.size),'rescale':False,'changed_pixels':int(diff.sum()),'outside_mask_changed_pixels':int(diff[~m].sum()),'outside_mask_rgba_sha256_before':hashlib.sha256(a[~m].tobytes()).hexdigest(),'outside_mask_rgba_sha256_after':hashlib.sha256(b[~m].tobytes()).hexdigest(),'changed_bbox_xywh':[int(xs.min()),int(ys.min()),int(xs.max()-xs.min()+1),int(ys.max()-ys.min()+1)],'visible_alpha16_bbox_xywh':[int(vx.min()),int(vy.min()),int(vx.max()-vx.min()+1),int(vy.max()-vy.min()+1)],'source_visual_status':'HOLD_PENDING_INDEPENDENT_ACTUAL_KNEE_OWNERSHIP_SOLE_AND_SEAM_REVIEW','fixed_runtime_canvas':1936,'actor_approval':False}
(root/'exact-bounded-preservation-proof.json').write_text(json.dumps(o,indent=2)+'\n')
# Private compact full source + actual lowerbody, no image tool output to parent.
bg=Image.new('RGB',out.size,(40,44,48));bg.paste(out,mask=out.getchannel('A'));bg.thumbnail((720,720));bg.save(root/'private-bounded-composite-full.jpg',quality=87)
cr=out.crop((480,660,930,1180));bg=Image.new('RGB',cr.size,(40,44,48));bg.paste(cr,mask=cr.getchannel('A'));d=ImageDraw.Draw(bg)
for y in range(700,1181,50):
 yy=y-660;d.line((0,yy,450,yy),fill=(75,85,90),width=1);d.text((3,yy+2),str(y),fill=(180,190,195))
for x in range(500,931,50):
 xx=x-480;d.line((xx,0,xx,520),fill=(75,85,90),width=1);d.text((xx+2,2),str(x),fill=(180,190,195))
bg.save(root/'private-bounded-lowerbody-grid.jpg',quality=90)
print(json.dumps({'output_sha256':o['output_sha256'],'bytes':o['output_bytes'],'outside_mask_changed_pixels':o['outside_mask_changed_pixels'],'changed_pixels':o['changed_pixels'],'bbox':o['visible_alpha16_bbox_xywh'],'private_full_bytes':(root/'private-bounded-composite-full.jpg').stat().st_size,'private_crop_bytes':(root/'private-bounded-lowerbody-grid.jpg').stat().st_size}))
