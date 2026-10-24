"""Freshly painted terminal pose; actual sole pinned using local leg articulation."""
from pathlib import Path
import numpy as np,json,hashlib
from PIL import Image,ImageDraw,ImageChops,ImageFilter
from scipy.ndimage import map_coordinates
P=Path(__file__).parent
S=P/'thunder_female-NW-walk-terminal2-actual-rig-v02.png'
R=P/'thunder_female-NW-walk-terminal2-joint-retouch-v01-service.png'
assert hashlib.sha256(R.read_bytes()).hexdigest()=='7f2b497fb617d7db1205c2d4693df2cc1ae70c3130d21bc0140bb43d75c47ecb'
base=Image.open(S).convert('RGBA');r=Image.open(R).convert('RGBA');W,H=base.size
sole=np.array([700.,1143.]);target=np.array([706.3543188022422,1117.7188869220179]);delta=target-sole
y,x=np.indices((H,W),dtype=float);v=np.clip((y-900.)/140.,0.,1.);v=v*v*(3-2*v)
cut=np.interp(y.ravel(),[0,700,800,900,980,1030,1254],[640,640,630,660,675,680,680]).reshape(H,W);u=np.clip((x-cut)/5.+.5,0.,1.);w=u*v
coords=np.array([y-delta[1]*w,x-delta[0]*w]);aa=np.array(r).astype(float)/255.;alpha=aa[:,:,3];premul=aa[:,:,:3]*alpha[:,:,None];wa=map_coordinates(alpha,coords,order=1,mode='constant',cval=0.);rgb=np.stack([map_coordinates(premul[:,:,i],coords,order=1,mode='constant',cval=0.) for i in range(3)],2);rgb=np.divide(rgb,wa[:,:,None],out=np.zeros_like(rgb),where=wa[:,:,None]>1e-7);rig=Image.fromarray(np.uint8(np.clip(np.dstack([rgb,wa])*255+.5,0,255)),'RGBA')
def poly(q):
 m=Image.new('L',(W,H));ImageDraw.Draw(m).polygon(q,fill=255);return m
region=poly([(510,708),(730,708),(770,850),(805,1000),(810,1200),(675,1200),(640,1085),(560,1020),(520,940),(500,815)])
protect=Image.open(P/'terminal2-original-rigid-staff-mask-v01.png').convert('L');d=ImageDraw.Draw(protect);d.rectangle((0,0,W-1,707),fill=255);d.polygon([(746,708),(940,750),(1120,905),(1120,1060),(825,1020),(758,940)],fill=255)
region=ImageChops.subtract(region,protect)
out=Image.composite(rig,base,region)
# Subtle internal skin-material join only; original skirt remains exact.
ba=np.asarray(base);oa=np.asarray(out).copy();Y,X=np.indices((H,W));skin=lambda z:(z[:,:,0]>145)&(z[:,:,1]>90)&(z[:,:,2]>55)&(z[:,:,0]>z[:,:,1]*1.08)&(z[:,:,1]>z[:,:,2]*1.05)&(z[:,:,3]>240)
m=skin(ba)&skin(oa)&(X>535)&(X<710)&(Y>=708)&(Y<726);mix=np.clip((726-Y)/18.,0,1)
for c in range(3):oa[:,:,c][m]=np.rint(oa[:,:,c][m]*(1-mix[m])+ba[:,:,c][m]*mix[m]).astype(np.uint8)
out=Image.fromarray(oa);f=P/'thunder_female-NW-walk-terminal2-finished-local-rig-v03.png';assert not f.exists();out.save(f);region.save(P/'terminal2-final-actual-edit-region-v03.png');protect.save(P/'terminal2-final-original-protection-v03.png')
change=np.any(np.asarray(base)!=oa,axis=2)
proof={'status':'ACTUAL_TERMINAL2_FINISHED_SOURCE_AND_UNIT_PAIR_PENDING_INDEPENDENT_QC','source_rig':str(S),'source_rig_sha256':hashlib.sha256(S.read_bytes()).hexdigest(),'fresh_joint_leg_art':str(R),'fresh_joint_leg_art_sha256':hashlib.sha256(R.read_bytes()).hexdigest(),'output':str(f),'output_sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'physical_canvas_fixed':2048,'body_factor_fixed':2,'raw_canvas':[W,H],'body_root':'COMMON_SOURCE0_RIG_ROOT_NOT_CHANGED; source2 upperbody rises6px, actualclothlag3px, freeLEFTforward fromoriginalsource','actual_forefoot_source_independent':{'xy':[700,1143],'uncertainty':[3,2],'not':'pointed goldornament or lowestsolepixel'},'actual_forefoot_target':target.tolist(),'required_1_to_2_plant_delta':[111.35431880224218,100.21888692201796],'actual_local_shoe_translation':delta.tolist(),'heel_source':[741.5,1158.],'heel_final_estimate':(np.array([741.5,1158.])+delta).tolist(),'rig_method':'Fresh actual twoleg joint painting; local terminal nearLEFT shin flex about knee, complete rigid shoe translation; farRIGHT AIR unchanged; no wholefigure/root move','changed_RGBA_pixels':int(change.sum()),'outside_edit_changed_RGBA_pixels':int((change&~(np.array(region)>0)).sum()),'protected_original_RGBA_changed_pixels':int((change&(np.array(protect)>0)).sum()),'upperbody_y_lt708_changed_RGBA_pixels':int(change[:708].sum()),'internal_skinjoin_retouch_pixels':int(m.sum()),'approval_added':0}
(P/'terminal2-finished-local-rig-proof-v03.json').write_text(json.dumps(proof,indent=2)+'\n')
for n,img in [('terminal2-finished-v03-whole-private.jpg',out),('terminal2-finished-v03-legs-private.jpg',out.crop((460,640,920,1230)))]:
 bg=Image.new('RGB',img.size,(80,80,80));bg.paste(img,mask=img.getchannel('A'));bg.thumbnail((750,750));bg.save(P/n,quality=85,optimize=True);assert(P/n).stat().st_size<150000
print(json.dumps({k:proof[k] for k in ['output_sha256','outside_edit_changed_RGBA_pixels','protected_original_RGBA_changed_pixels','actual_forefoot_target','heel_final_estimate']}))
