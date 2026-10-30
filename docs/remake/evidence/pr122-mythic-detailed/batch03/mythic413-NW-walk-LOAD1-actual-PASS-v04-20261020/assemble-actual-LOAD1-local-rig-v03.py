"""Actual unique limb animation from freshly painted v02 legs; not whole-body motion."""
from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image,ImageDraw,ImageChops,ImageFilter
from scipy.ndimage import map_coordinates

P=Path(__file__).parent
S=Path('/workspace/scratch/mythic413-NW-walk-contact0-author-20261020-v01/left-backswing-native-edit-v02/thunder_female-NW-walk-contact0-LEFTbackswing-bounded-v02.png')
R=P/'thunder_female-NW-walk-LOAD1-local-v02-service.png'
assert hashlib.sha256(S.read_bytes()).hexdigest()=='0874d56a0adf0d76b5e91c565ec41d601d8bbb76457c64e703a89dba54cf0645'
assert hashlib.sha256(R.read_bytes()).hexdigest()=='8d0a200e4323dce5cfc04fc2bc6faa9b63996f86775706965f88bdb42ac69498'
a=Image.open(S).convert('RGBA');r=Image.open(R).convert('RGBA');W,H=a.size
assert r.size==(W,H)==(1254,1254)
heel_source=np.array([637.5,1074.]);heel_target=np.array([625.3543188022422,1044.2188869220179]);shift=heel_target-heel_source
y,x=np.indices((H,W),dtype=np.float64)
# Lower stance shin articulates smoothly about its already painted loading knee;
# complete newly painted shoe is rigidly carried by ankle, not resized.
v=np.clip((y-835.)/140.,0.,1.);v=v*v*(3-2*v)
cut=np.interp(y.ravel(),[0,700,800,850,900,950,990,1254],[625,625,620,620,640,670,686,690]).reshape(H,W)
u=np.clip((cut-x)/4.+.5,0.,1.)
w=v*u
coords=np.array([y-shift[1]*w,x-shift[0]*w])
ra=np.array(r).astype(np.float64)/255.;alpha=ra[:,:,3];premul=ra[:,:,:3]*alpha[:,:,None]
wa=map_coordinates(alpha,coords,order=1,mode='constant',cval=0.)
rgb=np.stack([map_coordinates(premul[:,:,i],coords,order=1,mode='constant',cval=0.) for i in range(3)],axis=2)
rgb=np.divide(rgb,wa[:,:,None],out=np.zeros_like(rgb),where=wa[:,:,None]>1e-7)
rig=Image.fromarray(np.uint8(np.clip(np.dstack([rgb,wa])*255.+.5,0,255)),'RGBA')
def poly(points):
 m=Image.new('L',(W,H));ImageDraw.Draw(m).polygon(points,fill=255);return m
new=poly([(515,706),(710,706),(719,767),(712,840),(735,917),(763,976),(786,1077),(700,1090),(676,1105),(573,1105),(548,1020),(529,900),(510,800)])
old=Image.open(P/'old-legs-erasure-mask.png').convert('L').filter(ImageFilter.MaxFilter(25))
old=ImageChops.lighter(old,poly([(520,706),(715,706),(749,835),(788,966),(850,1138),(711,1155),(692,1060),(650,975),(570,954),(440,938),(446,848),(495,786)]))
# Original skirt/hand/weapon/cape retain their actual RGBA. Editable new body
# begins under the real original skirt hem, not at the earlier artificial690 cut.
staff=Image.open(P/'original-RIGHTstaff-protection-mask.png').convert('L')
protect=staff.copy();d=ImageDraw.Draw(protect);d.rectangle((0,0,W-1,713),fill=255);d.polygon([(691,714),(736,714),(746,741),(710,748),(690,730)],fill=255)
d.polygon([(741,714),(880,750),(1130,890),(1130,1050),(820,1035),(754,940),(740,908)],fill=255)
old=ImageChops.subtract(old,protect);new=ImageChops.subtract(new,protect)
base=a.copy();base.paste((0,0,0,0),(0,0),old)
rig.putalpha(ImageChops.multiply(rig.getchannel('A'),new));base.alpha_composite(rig)
allowed=ImageChops.lighter(old,new);allowed.save(P/'actual-LOAD1-rig-edit-region-v03.png');protect.save(P/'actual-LOAD1-rig-original-protection-v03.png')
rig.save(P/'actual-LOAD1-new-painted-leg-layer-v03.png')
out=P/'thunder_female-NW-walk-LOAD1-rigged-v03.png';assert not out.exists();base.save(out)
aa=np.array(a);oo=np.array(base);change=np.any(aa!=oo,axis=2);mask=np.array(allowed)>0
proof={'status':'ACTUAL_UNIQUE_LOAD1_LIMB_RIG_PENDING_INDEPENDENT_QC','source0':str(S),'source0_SHA256':hashlib.sha256(S.read_bytes()).hexdigest(),'fresh_leg_source':str(R),'fresh_leg_source_SHA256':hashlib.sha256(R.read_bytes()).hexdigest(),'output':str(out),'output_SHA256':hashlib.sha256(out.read_bytes()).hexdigest(),'raw_size':[W,H],'fixed_C':2048,'fixed_body_unit_factor':2,'source_heel_stiletto_estimate':heel_source.tolist(),'target_heel_stiletto':heel_target.tolist(),'actual_local_stance_shoe_shift':shift.tolist(),'rig':'Freshly painted real two-leg pose; smooth local stance-shin articulation about knee with complete rigid boot carrying; far swinging leg retained; original upperbody/root not moved','final_local_part_interpolation':'Premultiplied-alpha bilinear solely newly painted lower stance leg; whole final/source0 never resized','changed_RGBA_pixels':int(change.sum()),'outside_edit_region_changed_RGBA_pixels':int((change&~mask).sum()),'protected_original_RGBA_changed_pixels':int((change&(np.array(protect)>0)).sum()),'upperbody_y_lt714_changed_RGBA_pixels':int(change[:714].sum()),'approval_added':0,'pairwise_required_plant_delta':[111.35431880224218,100.21888692201796]}
(P/'actual-LOAD1-limb-rig-provenance-proof-v03.json').write_text(json.dumps(proof,indent=2)+'\n')
for name,img in [('actual-LOAD1-rigged-v03-whole-private.jpg',base),('actual-LOAD1-rigged-v03-legs-private.jpg',base.crop((420,640,900,1180)))]:
 bg=Image.new('RGB',img.size,(80,80,80));bg.paste(img,mask=img.getchannel('A'));bg.thumbnail((750,750));bg.save(P/name,quality=85,optimize=True);assert(P/name).stat().st_size<150000
print(json.dumps({k:proof[k] for k in ['output_SHA256','changed_RGBA_pixels','outside_edit_region_changed_RGBA_pixels','protected_original_RGBA_changed_pixels','target_heel_stiletto']}))
