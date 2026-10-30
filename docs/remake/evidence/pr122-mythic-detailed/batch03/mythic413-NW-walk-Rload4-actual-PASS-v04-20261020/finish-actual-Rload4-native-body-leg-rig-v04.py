"""Actual separate stance/swing limb rig, preserving complete shoes and foot yaw."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageChops
from scipy.ndimage import map_coordinates,distance_transform_edt
import numpy as np,hashlib,json,math
P=Path(__file__).parent;R=P/'thunder_female-NW-walk-Rload4-local-joint-v01-service.png';B=P/'DERIVED-Rload4-native1254-actual-costume-control.png'
r=Image.open(R).convert('RGBA');base=Image.open(B).convert('RGBA');W,H=r.size;raw=np.asarray(r);y,x=np.indices((H,W),dtype=float)
def poly(q):
 m=Image.new('L',(W,H));ImageDraw.Draw(m).polygon(q,fill=255);return m
air=poly([(525,710),(644,710),(639,786),(623,823),(654,857),(688,907),(698,954),(692,991),(660,1008),(602,1002),(574,972),(578,924),(611,903),(592,861),(556,839),(536,789)])
stance=poly([(630,716),(718,716),(730,830),(746,934),(754,1053),(735,1091),(690,1094),(644,1078),(630,1040),(662,1008),(668,946),(661,886),(641,830),(625,780)])
am=np.asarray(air)>0;sm=np.asarray(stance)>0;visible=sm&~am&(raw[:,:,3]>16)
center=np.interp(y.ravel(),[0,714,820,980,1254],[675,675,685,712,712]).reshape(H,W);half=np.interp(y.ravel(),[0,714,820,980,1254],[35,35,29,25,25]).reshape(H,W)
hidden=sm&am&(np.abs(x-center)<half)&(y>815)&(y<980)
# Reconstruct only the tiny occulted stance-calf edge from SAME actual calf material.
# No source sample outside semantic stance matte; no bone-end UV clamp.
valid=visible&(y>800)&(y<985);_,idx=distance_transform_edt(~valid,return_indices=True);part=raw.copy();part[:,:,3][~visible]=0;part[hidden]=raw[idx[0][hidden],idx[1][hidden]]
heel=np.array([712.,1075.]);target=np.array([705.4843188022421,1014.538886922018]);delta=target-heel
v=np.clip((y-820.)/150.,0.,1.);v=v*v*(3-2*v);coords=np.array([y-delta[1]*v,x-delta[0]*v]);pa=part.astype(float)/255.;alpha=pa[:,:,3];wa=map_coordinates(alpha,coords,order=1,mode='constant',cval=0.);rgb=np.stack([map_coordinates(pa[:,:,i]*alpha,coords,order=1,mode='constant',cval=0.)for i in range(3)],2);rgb=np.divide(rgb,wa[:,:,None],out=np.zeros_like(rgb),where=wa[:,:,None]>1e-7);moved=Image.fromarray(np.uint8(np.clip(np.dstack([rgb,wa])*255+.5,0,255)),'RGBA')
twolegs=r.copy();erase=Image.fromarray(np.uint8(sm&~am)*255);twolegs.paste((0,0,0,0),(0,0),erase);twolegs.alpha_composite(moved)
# Exact original swing limb stays in foreground with its complete original boot.
al=r.copy();al.putalpha(ImageChops.multiply(r.getchannel('A'),air));twolegs=Image.composite(r,twolegs,air)
region=poly([(505,718),(735,718),(785,890),(806,1120),(730,1150),(635,1120),(565,1015),(480,965),(475,815)])
cape=Image.open(P/'Rload4-original-cape-semantic-matte.png').convert('L');staff=Image.open(P/'Rload4-original-staff-semantic-matte.png').convert('L');protect=ImageChops.lighter(cape,staff);sh=Image.new('L',(W,H));sh.paste(protect,(0,4));ImageDraw.Draw(sh).rectangle((0,0,W-1,717),fill=255);region=ImageChops.subtract(region,sh);out=Image.composite(r,twolegs,sh); base=r  # New actual full pose keeps its naturally painted skirt/hips; same fixed C, no sourcebody seam
oa=np.asarray(out).copy();ba=np.asarray(base);skin=lambda z:(z[:,:,0]>145)&(z[:,:,1]>90)&(z[:,:,2]>55)&(z[:,:,0]>z[:,:,1]*1.08)&(z[:,:,1]>z[:,:,2]*1.05)&(z[:,:,3]>240);m=skin(ba)&skin(oa)&(x>530)&(x<720)&(y>=718)&(y<736);mix=np.clip((736-y)/18.,0,1)
for c in range(3):oa[:,:,c][m]=np.rint(oa[:,:,c][m]*(1-mix[m])+ba[:,:,c][m]*mix[m]).astype(np.uint8)
out=Image.fromarray(oa);f=P/'thunder_female-NW-walk-Rload4-finished-native-body-v04.png';assert not f.exists();out.save(f);moved.save(P/'Rload4-actual-stance-leg-layer-v04.png');air.save(P/'Rload4-actual-nearLEFT-swing-semantic-matte-v04.png');stance.save(P/'Rload4-actual-farRIGHT-stance-semantic-matte-v04.png');region.save(P/'Rload4-final-edit-region-v04.png');sh.save(P/'Rload4-final-body-equipment-protection-v04.png')
fore4=np.array([672.,1060.])+delta
# One physically possible fixed-foot-length yaw/heel-roll fit to the actual3/4 art.
E=math.radians(35.264389682754654);flat=np.array([-40.,15./math.sin(E),0.]);length=float(np.linalg.norm(flat));v3=np.array([565.-594.13,877.5-914.32]);rest=length**2-v3[0]**2;projection=-v3[1];perp=math.sqrt(max(0.,rest-projection**2));Y=projection*math.sin(E)+perp*math.cos(E);Z=projection*math.cos(E)-perp*math.sin(E)
change=np.any(ba!=oa,axis=2)
d={'status':'ACTUAL_RLOAD4_SOURCE_AND3_TO4_PAIR_PENDING_INDEPENDENT_QC','raw':str(R),'raw_sha256':hashlib.sha256(R.read_bytes()).hexdigest(),'selected_body':str(R),'selected_body_sha256':hashlib.sha256(R.read_bytes()).hexdigest(),'body_scope':'Actual newly painted Rload4 completebody; retained its natural skirt/hip join, needs independentbodyunit/identitycontinuity check at fixedC2048 (never recalibratedC)','output':str(f),'output_sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'physical_C_fixed':2048,'rig_root':[641,1058.3],'storage_translation':[0,0],'body_bob_and_rigid_staff':[0,4],'actual_Rheel_source':heel.tolist(),'actual_Rheel_target':target.tolist(),'actual_Rforefoot_source':[672,1060],'actual_Rforefoot_target':fore4.tolist(),'actual_complete_shoe_translation':delta.tolist(),'actual_3_to4_heel_delta':[111.35431880224218,100.21888692201796],'foot_ground_yaw':'Actualflatshoe axis[-40,-15]native, slope.375; bodyNWrootline.9 is not forced onto allsoleperimeter','finite_same_foot_length_native_units':length,'possible_phase3_forefoot3D_relative_heel':[float(v3[0]),Y,Z],'possible_phase4_forefoot3D_relative_heel':flat.tolist(),'foot_fit_scope':'Finite plausible shared foot-length/heel-roll/yaw fit to actual visible sole landmarks; not fullhidden3D reconstruction','occluded_Rcalf_material_retouch_pixels':int(hidden.sum()),'semantic_inpaint_source':'Nearest actualvisible sameRIGHTcalf only y800..985, never outside semantic limbmatte','changed_RGBA_pixels':int(change.sum()),'outside_edit_RGBA_changes':int((change&~(np.asarray(region)>0)).sum()),'protected_equipment_RGBA_changes':int((change&(np.asarray(sh)>0)).sum()),'approval_added':0}
(P/'Rload4-finished-native-body-proof-v04.json').write_text(json.dumps(d,indent=2)+'\n')
for n,img in [('Rload4-finished-v04-whole-private.jpg',out),('Rload4-finished-v04-legs-private.jpg',out.crop((460,640,920,1180)))]:
 bg=Image.new('RGB',img.size,(80,80,80));bg.paste(img,mask=img.getchannel('A'));bg.thumbnail((750,750));bg.save(P/n,quality=85,optimize=True);assert(P/n).stat().st_size<150000
print(json.dumps({k:d[k]for k in ['output_sha256','actual_Rheel_target','actual_Rforefoot_target','outside_edit_RGBA_changes','protected_equipment_RGBA_changes','occluded_Rcalf_material_retouch_pixels']}))
