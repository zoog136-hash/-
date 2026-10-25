from pathlib import Path
from PIL import Image,ImageDraw
from scipy.ndimage import label,binary_dilation
import numpy as np,json,hashlib
B=Path(__file__).parent;D=B/'actual-own-SE-ATTACK-native-complete-materials-v01';D.mkdir(exist_ok=False);L=Path('/workspace/scratch/mythic413-SE-hit-author-20261020-v01/common-own-SE-native-LEFT-materials-v01/SE-own-native-complete-LEFT-and-old-erased-BODY-readonly-handoff-v01.json');lj=json.loads(L.read_text());P=Path(lj['source']['path']);a=np.array(Image.open(P).convert('RGBA'));H,W=a.shape[:2];yy,xx=np.indices((H,W));REG=Path(lj['once_body_registration']['path']);reg=json.loads(REG.read_text())
def pin(p):
 p=Path(p);return {'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
def poly(q):
 m=Image.new('L',(W,H));ImageDraw.Draw(m).polygon(q,fill=255);return np.array(m)>0
def iso(m):
 q=a.copy();q[~m]=0;return q
RU=poly([(606,328),(635,326),(661,341),(676,365),(675,394),(664,420),(647,444),(628,465),(608,488),(585,503),(564,508),(546,499),(538,484),(540,468),(550,451),(567,431),(576,418),(583,395),(590,363)])
RF=poly([(547,442),(568,449),(583,465),(584,484),(572,505),(552,519),(530,528),(508,531),(490,523),(469,516),(446,512),(431,507),(414,503),(399,506),(377,505),(355,497),(348,478),(352,458),(363,443),(381,441),(399,448),(417,464),(446,465),(467,458),(492,448),(520,441)])
RF|=poly([(347,438),(415,438),(426,462),(426,502),(412,511),(352,506),(345,491)])
LU=poly([(775,435),(794,438),(813,455),(826,477),(826,501),(814,520),(801,520),(785,510),(775,492),(766,465)])
LF=np.array(Image.open(lj['semantic_mattes']['LEFT-far-complete-curved-cuff-forearm-free-hand']['path']).convert('L'))>0
hairshape=poly([(615,240),(640,270),(614,300),(570,338),(523,375),(481,399),(436,412),(440,398),(483,361),(534,319),(575,278)])|poly([(623,390),(642,390),(634,455),(614,491),(600,511),(582,540),(545,559),(559,538),(580,502),(592,462)])
blue=(a[:,:,2]>a[:,:,0]*1.25)&(a[:,:,2]>a[:,:,1]*1.08)&(a[:,:,3]>0);hair=hairshape&binary_dilation(blue,iterations=1);RU&=~hair;RF&=~hair
# Native shaft linear centre is measured once on exposed original metal only.
gold=(a[:,:,0]>100)&(a[:,:,1]>55)&(a[:,:,0]>a[:,:,2]*1.5)&(a[:,:,3]>100);rows=[]
for y in range(560,741):
 xs=np.where(gold[y]&(np.arange(W)>=350)&(np.arange(W)<=440))[0]
 if len(xs):rows.append([y,(float(xs.min())+float(xs.max()))/2])
coef=np.polyfit(np.array(rows)[:,0],np.array(rows)[:,1],1);axis=coef[0]*yy+coef[1]
visiblepole=(abs(xx-axis)<14)&(yy>=425)&(yy<=525)&gold;RF&=~visiblepole
upperregion=(xx>=280)&(xx<450)&(yy<430);cc,n=label(upperregion&(a[:,:,3]>16));sizes=np.bincount(cc.ravel());sizes[0]=0;idx=int(sizes.argmax());upper=binary_dilation(cc==idx,iterations=1)&upperregion&(a[:,:,3]>0)
# Actual native lower gold/cyan ornament contour, independently traced on the
# SE source. Cape behind the object is not carried along with the rigid staff.
left=[(75,0),(77,30),(73,37),(74,45),(68,49),(77,54),(80,58),(78,62),(78,69),(75,75),(78,81),(71,87),(69,91),(79,96),(85,106),(75,113),(79,119),(68,126),(68,132),(75,136),(71,141),(65,148),(68,153),(65,158),(61,164),(59,174),(63,182),(62,188),(70,200),(71,208),(78,218),(82,227),(74,237),(64,245),(63,248),(70,258),(79,271),(77,286),(84,328),(96,370),(101,386)]
right=[(94,0),(95,30),(96,38),(103,44),(110,47),(99,53),(98,58),(101,65),(99,70),(104,75),(103,81),(101,87),(112,92),(106,98),(104,105),(105,110),(112,120),(111,126),(116,132),(112,137),(117,142),(112,148),(114,154),(113,162),(120,173),(125,182),(124,189),(120,200),(116,210),(111,218),(106,227),(116,235),(127,242),(128,248),(117,257),(113,271),(112,285),(110,328),(105,370),(101,386)]
lo=poly([(320+x,750+y)for x,y in left]+[(320+x,750+y)for x,y in reversed(right)])
wm=upper|((abs(xx-axis)<14)&(yy>=420)&(yy<750))|lo|visiblepole;wm&=~RF
weapon=iso(wm);profile=[]
for u in range(-13,14):
 vals=[a[y,int(round(coef[0]*y+coef[1]))+u,:3]for y in range(560,741)]
 profile.append(np.median(vals,axis=0))
# Reconstruct only straight metal hidden by the gripping native hand, from its
# exposed SE same-shaft profile. Elaborate actual tip art is never synthesized.
for y in range(435,515):
 cx=float(coef[0]*y+coef[1])
 for x in range(int(cx-13),int(cx+14)):
  if weapon[y,x,3]==0 and abs(x-cx)<13:
   weapon[y,x,:3]=profile[int(np.clip(round(x-cx)+13,0,26))];weapon[y,x,3]=255 if abs(x-cx)<11.5 else int(255*(13-abs(x-cx))/1.5)
parts={};mattes={}
for name,m in [('RIGHT-near-upper-arm',RU),('RIGHT-near-complete-forearm-grip-hand',RF),('LEFT-far-upper-arm',LU)]:
 p=D/f'original-actual-SE-{name}-native-v01.png';Image.fromarray(iso(m)).save(p);mp=D/f'original-actual-SE-{name}-semantic-matte-v01.png';Image.fromarray(m.astype('uint8')*255).save(mp);parts[name]=pin(p);mattes[name]=pin(mp)
parts['LEFT-far-complete-curved-cuff-forearm-free-hand']=lj['parts']['LEFT-far-complete-curved-cuff-forearm-free-hand'];mattes['LEFT-far-complete-curved-cuff-forearm-free-hand']=lj['semantic_mattes']['LEFT-far-complete-curved-cuff-forearm-free-hand']
wp=D/'original-actual-SE-complete-rigid-RIGHT-near-staff-native-v01.png';Image.fromarray(weapon).save(wp);parts['complete-rigid-RIGHT-near-staff']=pin(wp);mp=D/'original-actual-SE-complete-visible-RIGHT-staff-semantic-matte-v01.png';Image.fromarray(wm.astype('uint8')*255).save(mp);mattes['complete-rigid-RIGHT-near-staff']=pin(mp)
erase=RU|RF|LU|LF|wm;core=a.copy();core[erase]=0;cp=D/'actual-SE-complete-old-arms-and-staff-erased-body-fixed-original-boots-INPUT-HOLD-local-cape-v01.png';Image.fromarray(core).save(cp);ep=D/'actual-SE-complete-old-arms-and-staff-erasure-mask-v01.png';Image.fromarray(erase.astype('uint8')*255).save(ep)
controls={'RIGHT_near_shoulder':[620,343],'RIGHT_near_cuff_elbow':[552,459],'RIGHT_near_wrist':[417,482],'RIGHT_original_grip':[382,466],**lj['actual_native_controls']}
j={'schema':'PR122-own-SE-native-complete-arms-staff-and-core-INPUT-v1','status':'NATIVE_PARTS_INPUT_PENDING_ACTUAL_JOINT_SOURCE_QC_AND_OCCLUDED_CAPE_RETOUCH','source':pin(P),'once_registration':pin(REG),'C':reg['new_SE_fixed_C'],'bodyunit':reg['new_SE_fixed_bodyunit'],'common_rig_root_in_unpadded_frame':reg['common_rig_root_in_unpadded_frame'],'production_storage_translation':reg['production_storage_translation'],'native_size':[W,H],'actual_native_controls':controls,'parts':parts,'semantic_mattes':mattes,'fullCORE':pin(cp),'complete_old_erasure_mask':pin(ep),'shared_LEFT_material':pin(L),'staff_axis_once_from_original_visible_metal':coef.tolist(),'upper_pole_actual_component_alpha16_pixels':int((cc==idx).sum()),'old_original_source_modified':False,'C_OR_root_fitted_OR_actor_resampled':False,'actor_approvals_added':0,'understaff_cape_status':'HOLD_REAL_LOCAL_CLOTH_REQUIRED_BEFORE_FINAL_SOURCE_APPROVAL'};q=D/'SE-ATTACK-own-complete-native-materials-and-unfinished-cape-provenance-v01.json';q.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps({'input':pin(q),'parts':len(parts),'C':j['C'],'source_approval_added':0}))
