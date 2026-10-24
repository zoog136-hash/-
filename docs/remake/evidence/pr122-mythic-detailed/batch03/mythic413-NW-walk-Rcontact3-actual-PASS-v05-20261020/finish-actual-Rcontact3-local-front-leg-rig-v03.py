"""Actual opposite contact; one fixed source3 heel, unchanged global rig root."""
from pathlib import Path
import hashlib,json,numpy as np
from PIL import Image,ImageDraw,ImageChops
from scipy.ndimage import map_coordinates
P=Path(__file__).parent;S=Path('/workspace/scratch/mythic413-NW-walk-contact0-author-20261020-v01/thunder_female-NW-walk-contact0-v01-service.png');R=P/'thunder_female-NW-walk-Rcontact3-local-hip-v01-service.png'
base=Image.open(S).convert('RGBA');r=Image.open(R).convert('RGBA');W,H=base.size
heel=np.array([581.5,964.]);target=np.array([594.13,914.32]);delta=target-heel
y,x=np.indices((H,W),dtype=float);v=np.clip((y-730.)/95.,0.,1.);v=v*v*(3-2*v);cut=np.interp(y.ravel(),[0,730,800,860,950,1254],[625,625,628,635,650,680]).reshape(H,W);u=np.clip((cut-x)/5.+.5,0.,1.);w=v*u
coords=np.array([y-delta[1]*w,x-delta[0]*w]);aa=np.asarray(r).astype(float)/255.;alpha=aa[:,:,3];premul=aa[:,:,:3]*alpha[:,:,None];wa=map_coordinates(alpha,coords,order=1,mode='constant',cval=0.);rgb=np.stack([map_coordinates(premul[:,:,i],coords,order=1,mode='constant',cval=0.)for i in range(3)],2);rgb=np.divide(rgb,wa[:,:,None],out=np.zeros_like(rgb),where=wa[:,:,None]>1e-7);rig=Image.fromarray(np.uint8(np.clip(np.dstack([rgb,wa])*255+.5,0,255)),'RGBA')
def poly(q):
 m=Image.new('L',(W,H));ImageDraw.Draw(m).polygon(q,fill=255);return m
region=poly([(505,714),(730,714),(790,925),(892,1190),(725,1215),(660,1080),(575,990),(450,980),(440,850),(480,760)])
protect=Image.open('/workspace/scratch/mythic413-NW-walk-LOAD1-author-20261020-v01/actual-LOAD1-rig-original-protection-v03.png').convert('L');d=ImageDraw.Draw(protect);d.rectangle((0,0,W-1,713),fill=255);region=ImageChops.subtract(region,protect)
out=Image.composite(rig,base,region);ba=np.asarray(base);oa=np.asarray(out).copy();skin=lambda z:(z[:,:,0]>145)&(z[:,:,1]>90)&(z[:,:,2]>55)&(z[:,:,0]>z[:,:,1]*1.08)&(z[:,:,1]>z[:,:,2]*1.05)&(z[:,:,3]>240);m=skin(ba)&skin(oa)&(x>535)&(x<710)&(y>=714)&(y<734);mix=np.clip((734-y)/20.,0,1)
for c in range(3):oa[:,:,c][m]=np.rint(oa[:,:,c][m]*(1-mix[m])+ba[:,:,c][m]*mix[m]).astype(np.uint8)
out=Image.fromarray(oa);f=P/'thunder_female-NW-walk-Rcontact3-finished-local-rig-v03.png';assert not f.exists();out.save(f);region.save(P/'Rcontact3-final-actual-edit-region-v03.png');protect.save(P/'Rcontact3-final-original-protection-v03.png');change=np.any(ba!=oa,axis=2)
proof={'status':'ACTUAL_RCONTACT3_FINISHED_SOURCE_PENDING_INDEPENDENT_QC','source_body':str(S),'source_body_sha256':hashlib.sha256(S.read_bytes()).hexdigest(),'fresh_leg_art':str(R),'fresh_leg_art_sha256':hashlib.sha256(R.read_bytes()).hexdigest(),'output':str(f),'output_sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'physical_canvas_fixed':2048,'rig_root_in_unpadded_frame':[641,1058.3],'storage_translation':[0,0],'actual_source_R_heel':[581.5,964],'actual_target_R_heel':target.tolist(),'front_knee_and_complete_shoe_local_translation':delta.tolist(),'local_thigh_articulation':'Smoothly blends from fixed hip at native730 to moved knee at825; calf/shoe are rigidly carried together, no perpose root shift','LEFT_departure':'Complete fresh actual trailing nearLEFT leg remainsAIR aftertoeoff; no forcedground point','body_bob':[0,0],'LEFT_arm':'Actual natural forward original arm opposite nearLEFTtrailingleg','outside_edit_changed_RGBA_pixels':int((change&~(np.asarray(region)>0)).sum()),'protected_original_RGBA_changed_pixels':int((change&(np.asarray(protect)>0)).sum()),'upperbody_y_lt714_changed_RGBA_pixels':int(change[:714].sum()),'actual_two_foot_lane_definition':'Initial Rcontact3 target selected from fixed original guide lateralfootplacement relativeLcontact0 (+80.13,-29.68) after unit2; freezes right lane for3→4→5, not perposeheel tuning','approval_added':0}
(P/'Rcontact3-finished-local-rig-proof-v03.json').write_text(json.dumps(proof,indent=2)+'\n')
for n,img in [('Rcontact3-finished-v03-whole-private.jpg',out),('Rcontact3-finished-v03-legs-private.jpg',out.crop((450,630,940,1215)))]:
 bg=Image.new('RGB',img.size,(80,80,80));bg.paste(img,mask=img.getchannel('A'));bg.thumbnail((750,750));bg.save(P/n,quality=85,optimize=True);assert(P/n).stat().st_size<150000
print(json.dumps({k:proof[k]for k in ['output_sha256','actual_target_R_heel','outside_edit_changed_RGBA_pixels','protected_original_RGBA_changed_pixels']}))
