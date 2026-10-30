from pathlib import Path
from PIL import Image,ImageDraw
from scipy.ndimage import label,binary_dilation
import numpy as np,json,hashlib
B=Path(__file__).parent;D=B/'actual-final-native-semantic-joint-finish-v08';D.mkdir();srcp=B/'actual-N-skin-joint-finish-v05/N-contact0-native-skin-joint-finished-v05.png';src=Image.open(srcp).convert('RGBA');W,H=src.size
def shift(im,bob):
 out=Image.new(im.mode,im.size);out.paste(im,bob);return out
def strong(a):
 cc,n=label(a[:,:,3]>100);sizes=np.bincount(cc.ravel());return sorted([int(s)for s in sizes[1:]if s>=200],reverse=True)
p4=B/'actual-opposite3-load4-local-finish-v02/N-walk-phase4-actual-native-local-finish-v02.png';old4=np.array(Image.open(p4));cc,n=label(old4[:,:,3]>100);calfcore=cc==cc[810,740];assert calfcore.sum()==844;orig4=np.array(shift(src,(34,-12)));assert np.array_equal(old4[calfcore],orig4[calfcore]);calf4=binary_dilation(calfcore,iterations=3)&(orig4[:,:,3]>0);calf=shift(Image.fromarray(calf4.astype('uint8')*255),(-34,12));calf.save(D/'canonical-original-RIGHT-calf-outer-old-material-matte.png')
ornament=Image.open(B/'actual-terminal2-bracer-joint-finish-v07/actual-native-original-bracer-outer-gold-ornament.png').convert('RGBA');om=np.array(ornament)[:,:,3]>0
arm_poly=[(539,501),(563,511),(556,542),(531,575),(506,610),(500,629),(484,647),(467,647),(452,635),(456,616),(471,598),(498,570),(517,536),(523,513)];am=Image.new('L',src.size);ImageDraw.Draw(am).polygon(arm_poly,fill=255)
poses=[(1,(-7,-12),(487,602),B/'actual-N-skin-joint-finish-v05/N-LOAD1-native-skin-joint-finished-v05.png',None,[B/'actual-LOAD1-rig-v03/new-left-support-native-part-rig.png',B/'actual-LOAD1-rig-v03/new-right-passing-native-part-rig.png']),
(2,(7,-6),(507,577),B/'actual-terminal2-bracer-joint-finish-v07/N-walk-phase2-actual-native-bracer-joint-finished-v07.png',None,[B/'actual-terminal2-rig-v01/actual-left-terminal-leg-and-heel-rise.png',B/'actual-terminal2-rig-v01/actual-right-late-swing-leg.png']),
(3,(27,0),(515,568),B/'actual-opposite3-load4-local-finish-v02/N-walk-phase3-actual-native-local-finish-v02.png',B/'actual-opposite3-load4-rig-v01/actual-LEFT-counterphase-arm-phase3.png',[B/'actual-opposite3-load4-rig-v01/actual-bilateral-legs-phase3.png']),
(4,(34,-12),(504,582),p4,B/'actual-opposite3-load4-rig-v01/actual-LEFT-counterphase-arm-phase4.png',[B/'actual-opposite3-load4-rig-v01/actual-bilateral-legs-phase4.png']),
(5,(20,-6),(493,595),B/'actual-opposite-terminal5-rig-v01/N-walk-phase5-actual-native-part-rig-v01.png',B/'actual-opposite-terminal5-rig-v01/actual-terminal5-LEFT-counterphase-arm-node.png',[B/'actual-opposite-terminal5-rig-v01/actual-bilateral-terminal5-complete-leg-nodes.png'])]
results=[]
for phase,bob,wrist,inp,armp,legps in poses:
 before=np.array(Image.open(inp).convert('RGBA'));out=before.copy();orig=np.array(shift(src,bob));legmask=np.zeros((H,W),bool)
 for lp in legps:legmask|=np.array(Image.open(lp))[:,:,3]>0
 cm=np.array(shift(calf,bob))>0;matmatch=np.all(before==orig,2);erase=cm&(~legmask)&matmatch&(before[:,:,3]>0);out[erase]=0;allowed=erase.copy();orn_changed=0
 if phase>=3:
  oldorn=np.array(shift(Image.fromarray(om.astype('uint8')*255),bob))>0;newarm=np.array(Image.open(armp).convert('RGBA'));out[oldorn]=newarm[oldorn];allowed|=oldorn
  A=np.array([543.,517.]);C=A+np.array(bob);V=np.array([-56.,85.]);T=np.array(wrist)-A;u=V/np.linalg.norm(V);v=np.array([-u[1],u[0]]);ut=T/np.linalg.norm(T);vt=np.array([-ut[1],ut[0]]);M=np.column_stack((ut,vt))@np.diag([np.linalg.norm(T)/np.linalg.norm(V),1.])@np.column_stack((u,v)).T;off=C-M@A;inv=np.linalg.inv(M);io=-inv@off;no=ornament.transform(src.size,Image.Transform.AFFINE,tuple(inv[0])+(io[0],)+tuple(inv[1])+(io[1],),resample=Image.Resampling.BICUBIC);fr=Image.fromarray(out);fr.alpha_composite(no);out=np.array(fr);allowed|=np.array(no)[:,:,3]>0
  cap=(np.array(shift(am,bob))>0)&(np.indices(cm.shape)[0]<=518+bob[1])&(orig[:,:,3]>0);out[cap]=orig[cap];allowed|=cap;no.save(D/f'phase{phase}-same-rig-actual-bracer-gold-ornament.png');orn_changed=int((np.any(out!=before,2)&~erase).sum())
 change=np.any(out!=before,2);assert not(change&~allowed).any();assert np.array_equal(out[950:],before[950:]);sizes=strong(out);assert len(sizes)==1,(phase,sizes)
 if phase==1:
  assert not change.any(),'Accepted LOAD1 must be independently reviewed if this gate finds an actual residual'
  p=inp
 else:
  p=D/f'N-walk-phase{phase}-actual-native-semantic-joint-finished-v08.png';Image.fromarray(out).save(p);Image.fromarray(allowed.astype('uint8')*255).save(D/f'phase{phase}-old-calf-and-actual-bracer-joint-mask-v08.png')
 note={'phase':phase,'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'prior_path':str(inp),'prior_sha256':hashlib.sha256(inp.read_bytes()).hexdigest(),'native_size':[W,H],'C':1920,'common_rig_root_in_unpadded_frame':[662.8125,917.6920531878804],'body_node_bob':list(bob),'storage_translation':[0,0],'old_calf_RGBA_equal_original_master':True,'old_calf_removed_pixels':int(erase.sum()),'actual_new_limb_pixels_removed':0,'actual_blue_gold_coat_pixels_removed':0,'actual_bracer_ornament_rig_changed_pixels':orn_changed,'changed_RGBA_pixels':int(change.sum()),'all_other_RGBA_differences':0,'below_y950_RGBA_changed':0,'alpha_gt100_4connected_components_ge200':sizes,'actor_approval_added':0};results.append(note);(D/f'phase{phase}-semantic-joint-finish-proof-v08.json').write_text(json.dumps(note,indent=2)+'\n')
 if phase>=2:
  im=Image.fromarray(out);im.thumbnail((500,500));bg=Image.new('RGBA',im.size,(196,202,208,255));bg.alpha_composite(im);bg.convert('RGB').save(D/f'private-actual-phase{phase}-whole-v08.jpg',quality=91,optimize=True)
(D/'actual-native-semantic-joints-final-frame-contract-v08.json').write_text(json.dumps({'status':'ACTUAL_LOCAL_JOINT_AND_OLD_CALF_FINISH_PENDING_INDEPENDENT_QC','original_contact0_and_LOAD1_unchanged':True,'frames':results,'actor_approval_added':0},indent=2)+'\n');print(json.dumps([dict(phase=x['phase'],sha256=x['sha256'],calf_removed=x['old_calf_removed_pixels'],bracer_changed=x['actual_bracer_ornament_rig_changed_pixels'],strong=x['alpha_gt100_4connected_components_ge200'])for x in results]))
