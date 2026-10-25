from pathlib import Path
from PIL import Image,ImageDraw
from scipy.ndimage import binary_dilation,label
from scipy.interpolate import PchipInterpolator
import numpy as np,json,hashlib
B=Path(__file__).parent;D=B/'actual-own-S-ATTACK-native-full-shoulder-and-original-specific-owners-v02';D.mkdir(exist_ok=False);L=Path('/workspace/scratch/mythic413-S-hit-author-20261020-v01/common-own-S-native-LEFT-materials-v01/S-own-native-complete-LEFT-and-old-erased-BODY-readonly-handoff-v01.json');lj=json.loads(L.read_text());P=Path(lj['source']['path']);a=np.array(Image.open(P).convert('RGBA'));H,W=a.shape[:2];yy,xx=np.indices((H,W));REG=Path(lj['once_body_registration']['path']);reg=json.loads(REG.read_text());rgb=a[:,:,:3].astype(float)
def pin(p):
 p=Path(p);return {'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
def poly(q):
 m=Image.new('L',(W,H));ImageDraw.Draw(m).polygon(q,fill=255);return np.array(m)>0
RU=poly([(526,334),(551,322),(578,334),(591,355),(589,383),(576,411),(561,435),(547,460),(541,480),(529,495),(511,496),(495,483),(489,464),(495,442),(501,422),(487,416),(481,404),(489,391),(501,383),(514,365)])
RF=poly([(476,440),(499,443),(514,454),(523,471),(522,489),(509,506),(490,516),(473,518),(457,510),(441,500),(425,490),(410,479),(394,482),(374,479),(354,470),(347,450),(350,428),(363,418),(382,416),(397,421),(409,435),(429,447),(450,440)])
LU=poly([(697,332),(713,331),(728,338),(736,349),(741,369),(746,392),(751,410),(758,418),(769,430),(770,441),(765,449),(774,465),(779,479),(778,495),(785,506),(782,519),(769,529),(754,526),(740,514),(730,499),(723,486),(721,465),(721,449),(715,440),(711,427),(710,411),(706,396),(701,380),(696,367),(695,351)])
# Anatomical LEFT humerus has a different proximal anchor from the shared visible cuff anchor.
actual_LEFT_shoulder=[711,345]
left_ribbon_roi=poly([(724,315),(799,324),(817,420),(790,463),(773,457),(762,421),(748,389),(736,360)]);brightblue=(rgb[:,:,2]>100)&(rgb[:,:,2]>rgb[:,:,1]*1.8)&(rgb[:,:,2]>rgb[:,:,0]*2)&(a[:,:,3]>0);left_hair=left_ribbon_roi&binary_dilation(brightblue,iterations=1);LU&=~left_hair
LF=np.array(Image.open(lj['semantic_mattes']['LEFT-far-complete-curved-cuff-forearm-free-hand']['path']).convert('L'))>0
# Only the actual brightblue headstreamer behind the R shoulder is excluded.
hairshape=poly([(565,260),(595,280),(564,317),(523,358),(490,400),(481,423),(450,396),(430,405),(417,389),(443,347),(493,299),(532,270)]);blue=(rgb[:,:,2]>rgb[:,:,0]*1.25)&(rgb[:,:,2]>rgb[:,:,1]*1.1)&(a[:,:,3]>0);hair=hairshape&binary_dilation(blue,iterations=1);ribbon_connector=(xx>=514)&(xx<557)&(yy>=330)&(yy<390)&binary_dilation(brightblue,iterations=1);hair|=ribbon_connector;RU&=~hair;RF&=~hair
# Actual old black/gold cuff lower rim belongs to complete foregrip, not fixed CORE.
oldcuff=poly([(413,486),(431,487),(448,489),(459,496),(460,507),(450,517),(431,516),(415,506)]);RF|=oldcuff
# Original navy/gold puff cap below the real blue hair streamer belongs to upperarm.
navypuff=poly([(477,418),(494,420),(505,427),(501,442),(479,446),(467,438),(469,429)])&~binary_dilation(brightblue,iterations=1);RU|=navypuff
# Fit one original exposed shaft only; cloak does not enter this y interval.
gold=(rgb[:,:,0]>100)&(rgb[:,:,1]>55)&(rgb[:,:,0]>rgb[:,:,2]*1.5)&(a[:,:,3]>100);rows=[]
for y in range(520,651):
 xs=np.where(gold[y]&(np.arange(W)>=355)&(np.arange(W)<=400))[0]
 if len(xs):rows.append([y,(float(xs.min())+float(xs.max()))/2])
coef=np.polyfit(np.array(rows)[:,0],np.array(rows)[:,1],1);axis=coef[0]*yy+coef[1];band=abs(xx-axis)<17
# Complete true native upper ornament is an isolated alpha component.
ur=(xx>=300)&(xx<445)&(yy<412);cc,n=label(ur&(a[:,:,3]>16));sizes=np.bincount(cc.ravel());sizes[0]=0;idx=int(sizes.argmax());upper=binary_dilation(cc==idx,iterations=1)&ur&(a[:,:,3]>0)
left=[(364,780),(364,817),(359,824),(353,831),(360,836),(359,844),(350,851),(354,856),(360,860),(363,866),(357,873),(352,880),(348,887),(357,892),(358,899),(349,906),(343,915),(334,926),(342,930),(348,940),(356,950),(369,959),(362,967),(355,975),(349,985),(345,990)]
right=[(385,780),(386,817),(389,824),(398,831),(390,836),(390,844),(399,851),(397,856),(391,860),(388,866),(393,873),(396,880),(400,887),(394,892),(391,899),(398,906),(405,915),(412,926),(403,930),(396,940),(389,950),(380,959),(390,967),(396,975),(405,985),(406,990)]
lo=poly(left+right[::-1]);wm=upper|((abs(xx-axis)<14)&(yy>=405)&(yy<780))|lo;lower=(yy>=990)&(yy<1130)&(xx>=320)&(xx<420);wm[lower]=a[:,:,3][lower]>0
# Full original gripping hand, including its whole top/bottom/far fingertips.
fist=(xx>=346)&(xx<420)&(yy>=410)&(yy<486);metal=band&(((rgb[:,:,0]>70)&(rgb[:,:,1]>35)&(rgb[:,:,2]<rgb[:,:,1]*.54))|((rgb[:,:,0]>.95*rgb[:,:,1])&(rgb[:,:,0]<1.09*rgb[:,:,1])&(rgb[:,:,1]>85)&(rgb[:,:,2]<rgb[:,:,1]*.95)));skinhand=fist&~metal&(a[:,:,3]>0);RF|=skinhand;RF[fist&metal]=False;outside=((yy>=405)&(yy<410)|(yy>=486)&(yy<510))&band;RF[outside]=False;wm|=outside;wm[skinhand]=False;wm[fist&metal]=True
# Real same-shaft RGBA profile, including measured native alpha width.
profile=[]
for u in range(-17,18):
 v=np.array([a[y,int(round(coef[0]*y+coef[1]))+u]for y in range(520,651)]);al=int(round(float(np.median(v[:,3]))));v0=v[:,3]>16;col=np.median(v[v0,:3],axis=0)if v0.any()else np.zeros(3);profile.append([*np.rint(col).astype(int).tolist(),al])
wp=a.copy();wp[~wm]=0
for y in range(405,510):
 cx=float(coef[0]*y+coef[1])
 for x in range(int(cx-17),int(cx+18)):
  p=np.array(profile[int(np.clip(round(x-cx)+17,0,34))],dtype='uint8')
  if p[3]>0 and(skinhand[y,x]or a[y,x,3]==0 or wp[y,x,3]<16):wp[y,x]=p
parts={};mattes={}
for name,m in [('RIGHT-near-upper-arm',RU),('RIGHT-near-complete-forearm-grip-hand',RF),('LEFT-far-upper-arm',LU)]:
 q=a.copy();q[~m]=0;p=D/('original-actual-S-'+name+'-native-v02.png');Image.fromarray(q).save(p);mp=D/('original-actual-S-'+name+'-semantic-matte-v02.png');Image.fromarray(m.astype('uint8')*255).save(mp);parts[name]=pin(p);mattes[name]=pin(mp)
parts['LEFT-far-complete-curved-cuff-forearm-free-hand']=lj['parts']['LEFT-far-complete-curved-cuff-forearm-free-hand'];mattes['LEFT-far-complete-curved-cuff-forearm-free-hand']=lj['semantic_mattes']['LEFT-far-complete-curved-cuff-forearm-free-hand'];p=D/'original-actual-S-complete-rigid-RIGHT-staff-original-native-pole-v01.png';Image.fromarray(wp).save(p);parts['complete-rigid-RIGHT-near-staff']=pin(p);mp=D/'original-actual-S-complete-visible-RIGHT-staff-semantic-matte-v02.png';Image.fromarray(wm.astype('uint8')*255).save(mp);mattes['complete-rigid-RIGHT-near-staff']=pin(mp)
# Source isolation and complete old-erasure are distinct. A bounded AA margin
# captures original arm edges without deleting the protected original ribbon.
arm=RU|RF|LU|LF;erase=arm|(binary_dilation(arm,iterations=2)&~hair&~left_hair)|wm;
# At genuine proximal shoulder the exact original skin module overlaps body; do not cut a dilated empty moat.
shoulderjoin=(xx>=687)&(xx<748)&(yy>=321)&(yy<375);erase[shoulderjoin]=arm[shoulderjoin]|wm[shoulderjoin];
erase|=fist&(a[:,:,3]>0);local=(yy>=730)&(yy<995)&(xx>=330)&(xx<430);erase|=binary_dilation(wm,iterations=3)&local;core=a.copy();core[erase]=0;cp=D/'actual-S-complete-old-arms-staff-erased-CORE-original-legs-boots-local-cape-HOLD-v02.png';Image.fromarray(core).save(cp);ep=D/'actual-S-complete-old-arm-and-staff-erasure-AA-mask-v02.png';Image.fromarray(erase.astype('uint8')*255).save(ep)
controls={'LEFT_anatomical_shoulder':actual_LEFT_shoulder,'RIGHT_near_shoulder':[553,343],'RIGHT_near_cuff_elbow':[511,473],'RIGHT_near_wrist':[415,466],'RIGHT_original_grip':[380,446],**lj['actual_native_controls']};j={'schema':'PR122-own-S-native-complete-arms-staff-and-core-INPUT-v1','status':'OWN_S_REAL_PARTS_PENDING_ACTUAL_SOURCE_JOINT_QC_LOCAL_CLOTH_REQUIRED','source':pin(P),'once_registration':pin(REG),'C':reg['new_S_fixed_C'],'bodyunit':reg['new_S_fixed_bodyunit'],'common_rig_root_in_unpadded_frame':reg['common_rig_root_in_unpadded_frame'],'production_storage_translation':reg['production_storage_translation'],'native_size':[W,H],'actual_native_controls':controls,'parts':parts,'semantic_mattes':mattes,'fullCORE':pin(cp),'complete_old_erasure_mask':pin(ep),'shared_LEFT_material':pin(L),'staff_axis_once_from_original_visible_metal':coef.tolist(),'actual_native_exposed_shaft_RGBA_profile':profile,'actual_pink_hand_source_RGBA_difference':0,'hand_pole_ownership':'Native pink/glove fingers belong to foregrip; true gold/pale metal to rigid shaft; hidden shaft uses actual original RGBA/alpha profile.','complete_old_arm_erasure_distinct_from_isolation':True,'old_original_source_modified':False,'C_OR_root_fitted_OR_actor_resampled':False,'whole_actor_mirror':False,'understaff_cape_status':'HOLD_ACTUAL_NEW_LOCAL_S_CLOTH_REQUIRED','actor_approvals_added':0,'specific_actual_source_owner_updates':{'full_LEFT_anatomical_humerus':{'shoulder':actual_LEFT_shoulder,'distal_elbow':[772,521],'common_visible_proximal_anchor_not_anatomical':[752,490]},'old_Rgoldcuff_rim_to_foregrip_native_bbox':[413,486,461,518],'old_navy_puff_cap_to_Rupper_native_bbox':[467,418,506,447],'actual_brightblue_headribbon_preserved_on_CORE':True,'source_boots_C_root_changed':False}};q=D/'S-ATTACK-full-anatomical-LEFTupper-and-specific-original-owners-cape-HOLD-v02.json';q.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps({'material':pin(q),'parts':5,'fixed_C':j['C'],'fixed_root':j['common_rig_root_in_unpadded_frame'],'source_approval_added':0}))
