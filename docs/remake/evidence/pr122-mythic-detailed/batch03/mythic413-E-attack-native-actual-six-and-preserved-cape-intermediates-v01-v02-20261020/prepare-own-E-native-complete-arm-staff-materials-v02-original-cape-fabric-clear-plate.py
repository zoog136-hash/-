from pathlib import Path
from PIL import Image,ImageDraw
from scipy.ndimage import binary_dilation,label,map_coordinates
from scipy.interpolate import PchipInterpolator
import numpy as np,json,hashlib,math
B=Path(__file__).parent;D=B/'common-own-E-native-arm-staff-materials-v02';D.mkdir(exist_ok=False);P=Path('/workspace/scratch/mythic413-E-hit-author-20261020-v01/E-new-high-quality-native-background-AA-clean-v01.png');s=Image.open(P).convert('RGBA');a=np.array(s);H,W=a.shape[:2];yy,xx=np.indices((H,W))
def poly(q):m=Image.new('L',(W,H));ImageDraw.Draw(m).polygon(q,fill=255);return np.array(m)>0
def iso(m):q=a.copy();q[~m]=0;return Image.fromarray(q)
def pin(p):p=Path(p);r=p.read_bytes();return {'path':str(p),'sha256':hashlib.sha256(r).hexdigest(),'bytes':len(r)}
# Both actual native arms, anatomical RIGHT near/image-left held pole;
# LEFT far/image-right free hand. No geometric/body normalization is applied.
RU=poly([(591,345),(628,330),(652,341),(678,362),(676,388),(664,416),(649,439),(628,462),(611,485),(588,494),(560,490),(542,474),(538,454),(550,434),(569,416),(585,400)])
RF=poly([(545,447),(566,455),(578,474),(574,497),(559,520),(538,535),(516,544),(491,544),(464,535),(443,529),(422,531),(398,538),(369,538),(347,528),(343,504),(347,485),(362,475),(381,475),(402,480),(423,481),(448,481),(475,467),(500,458),(522,451)])
RF |= poly([(341,473),(435,473),(435,541),(341,541)])
LU=poly([(784,456),(803,455),(816,464),(823,484),(825,500),(818,517),(803,527),(786,521),(777,507),(771,484),(776,468)])
LF=poly([(792,494),(812,491),(829,505),(844,516),(866,532),(890,542),(917,556),(946,579),(973,588),(998,598),(1021,613),(1033,629),(1028,636),(1012,628),(1000,621),(1006,644),(998,654),(989,647),(984,632),(974,638),(973,646),(963,642),(960,626),(945,615),(927,615),(902,602),(880,594),(856,581),(831,571),(815,550),(801,532),(790,515)])
LF |= poly([(939,577),(1045,577),(1045,666),(939,666)])
# Saturated blue original hair streamers remain on the head/core. They are
# never cuff/arm material even where their original alpha overlaps the sleeve.
hair=poly([(633,280),(687,287),(645,328),(606,367),(570,403),(538,435),(523,452),(505,439),(496,442),(476,442),(507,409),(539,379),(585,335)])|poly([(638,414),(663,414),(664,466),(650,495),(643,481),(628,494),(625,454)])
RU &= ~hair;RF &= ~hair
# Native AA cap is actual same source material around each existing cuff/hand.
RU=binary_dilation(RU,iterations=2)&~hair;RF=binary_dilation(RF,iterations=2)&~hair;LU=binary_dilation(LU,iterations=2);LF=binary_dilation(LF,iterations=2)
# Visible actual shaft pixels inside the old hand bounding box belong to the
# rigid pole. Preserve true native flesh/blue glove; avoid moving a gold stub
# with the hand when the new pole swings independently around the same grip.
rod_axis=391.5+0*yy
pole_visible=(abs(xx-rod_axis)<19)&(yy>=465)&(yy<=555)&(a[:,:,0]>80)&(a[:,:,1]>40)&(a[:,:,2]<a[:,:,1]*.54)
RF &= ~pole_visible
parts={};mattes={}
for n,m in [('RIGHT-near-upper-arm',RU),('RIGHT-near-complete-forearm-grip-hand',RF),('LEFT-far-upper-arm',LU),('LEFT-far-complete-curved-cuff-forearm-free-hand',LF)]:
 p=D/f'original-actual-E-{n}-material.png';iso(m).save(p);mp=D/f'original-actual-E-{n}-semantic-matte.png';Image.fromarray(m.astype('uint8')*255).save(mp);parts[n]=pin(p);mattes[n]=pin(mp)
# Real complete pole contour registered from its own visible native metal.
rgb=a[:,:,:3].astype(float);gold=(rgb[:,:,0]>100)&(rgb[:,:,1]>55)&(rgb[:,:,0]>rgb[:,:,2]*1.5)&(a[:,:,3]>100);rows=[]
for y in range(600,801):
 xs=np.where(gold[y]&(np.arange(W)>=350)&(np.arange(W)<=430))[0]
 if len(xs):rows.append((y,(float(xs.min())+float(xs.max()))/2))
coef=np.polyfit([v[0]for v in rows],[v[1]for v in rows],1);axis=coef[0]*yy+coef[1]
half=np.interp(yy.ravel(),[0,18,80,145,182,205,236,266,300,340,375,410,445,467,480,550,870,897,922,947,972,994,1020,1046,1075,1125,1178,1190],[0,4,16,36,62,45,15,24,40,44,31,24,24,16,12,13,13,19,26,20,26,29,20,40,34,18,2,0]).reshape(H,W)
wm=(abs(xx-axis)<=half+2)&(yy<=1190)&~RF
# Native exposed lower ornament contour, distinct from the gold cape behind it.
lo_y=[830,870,890,900,915,925,940,950,960,975,994,1009]
lo_l=[382,382,380,375,370,374,377,371,378,380,364,374]
lo_r=[402,402,405,410,414,412,410,415,409,408,421,412]
for y in range(830,1010):
 wm[y]=False;x0=int(np.floor(np.interp(y,lo_y,lo_l)))-1;x1=int(np.ceil(np.interp(y,lo_y,lo_r)))+2;wm[y,x0:x1]=True
wm |= (yy>=1010)&(yy<=1190)&(xx>=335)&(xx<=445)
wm |= pole_visible
wm &= ~RF
wp=np.array(iso(wm));profile=[]
for u in range(-12,13):
 vals=[]
 for y in range(620,781):
  x=int(round(coef[0]*y+coef[1]))+u
  if a[y,x,3]>100:vals.append(a[y,x,:3])
 profile.append(np.median(vals,axis=0)if vals else[170,111,19])
# Only straight metal hidden inside the actual gripping hand is reconstructed
# from original visible shaft profile; both elaborate original tips stay native.
for y in range(475,543):
 cx=float(coef[0]*y+coef[1])
 for x in range(int(cx-12),int(cx+13)):
  if wp[y,x,3]==0 and abs(x-cx)<12:
   wp[y,x,:3]=profile[int(np.clip(round(x-cx)+12,0,24))];wp[y,x,3]=253 if abs(x-cx)<10.5 else int(253*(12-abs(x-cx))/1.5)
wp=Image.fromarray(wp);p=D/'original-actual-E-complete-rigid-RIGHT-near-staff-material.png';wp.save(p);parts['complete-rigid-RIGHT-near-staff']=pin(p);mattes['complete-rigid-RIGHT-near-staff']=pin(p)
files={}
for n,m in [('LEFT-forearm-only-old-erased-BODY-with-original-RIGHT-staff-arms-and-boots',LF),('complete-LEFT-arm-old-erased-BODY-with-original-RIGHT-staff-and-boots',LU|LF),('complete-both-arms-and-staff-old-erased-BODY-original-boots-INPUT-HOLD-understaff-coat',RU|RF|LU|LF|wm)]:
 p=D/f'actual-E-{n}.png';iso(~m).save(p);mp=D/f'complete-original-E-{n}-erasure-mask.png';Image.fromarray(m.astype('uint8')*255).save(mp);files[n]={'body':pin(p),'complete_old_erasure_mask':pin(mp),'outside_erasure_RGBA_changed':0}
# The original foreground pole occludes part of the real cape. Restore only
# that local revealed fabric from adjacent native sections at the same signed
# distance to its curved original gold hem, preserving all visible pixels.
edge=PchipInterpolator([270,310,340,370,400,430,451],[899,901,911,930,956,985,1008],extrapolate=True)
coat=poly([(448,750),(505,747),(498,880),(451,1009),(430,985),(400,956),(370,930),(340,911),(310,901),(271,899),(328,849),(385,799)])
restore=wm&coat&(yy>=780)&(yy<=1010)
xleft=xx-60.;xright=xx+58.;v=yy-edge(xx);yl=edge(xleft)+v;yr=edge(xright)+v
az=a.astype(float)/255.;aa=az[:,:,3]
def sample(sx,sy):
 al=map_coordinates(aa,[sy,sx],order=1,mode='constant',cval=0);rgb=np.stack([map_coordinates(az[:,:,k]*aa,[sy,sx],order=1,mode='constant',cval=0)for k in range(3)],2);return al,rgb
al,cl=sample(xleft,yl);ar,cr=sample(xright,yr)
# Ignore donor points outside the actual same cape panel or inside the pole.
validl=(xleft>=270)&(xleft<=451)&(yl<=edge(xleft)+2)&(yl>=750);validr=(xright>=270)&(xright<=451)&(yr<=edge(xright)+2)&(yr>=750);al*=validl;ar*=validr;cl*=validl[:,:,None];cr*=validr[:,:,None]
wl=(al>0).astype(float);wr=(ar>0).astype(float);ws=wl+wr;outa=np.divide(al+ar,ws,out=np.zeros_like(al),where=ws>0);outrgb=np.divide(cl+cr,(al+ar)[:,:,None],out=np.zeros_like(cl),where=(al+ar)[:,:,None]>1e-8);fabric=np.uint8(np.clip(np.dstack((outrgb,outa))*255+.5,0,255))
fullmask=RU|RF|LU|LF|wm;before=np.array(iso(~fullmask));after=before.copy();good=restore&(fabric[:,:,3]>0);after[good]=fabric[good]
cp=D/'actual-E-full-old-arms-staff-erased-body-with-original-legs-and-native-coat-fabric-restoration-INPUT-v02.png';Image.fromarray(after).save(cp);cm=D/'actual-E-revealed-original-coat-native-fabric-restoration-mask-v02.png';Image.fromarray(good.astype('uint8')*255).save(cm)
files['full-attack-CORE-with-native-fabric-restoration-INPUT']={'body':pin(cp),'restoration_mask':pin(cm),'native_fabric_pixels':int(good.sum()),'actual_own_fabric_mapping':'same native cape signed distance to original visible curved gold hem; adjacent original left/right sections only','outside_restore_mask_RGBA_changed':int(np.any(before[~good]!=after[~good],1).sum()),'source_visual_status':'INPUT_PENDING_INDEPENDENT_SOURCE_QC'}
REG=Path('/workspace/scratch/mythic413-E-hit-author-20261020-v01/E-new-native-one-time-body-density-C2816-root-registration-v01.json');reg=json.loads(REG.read_text())
# Each input remains original native1254 coordinates. Provisional physical
# registration belongs to the shared author/QC; no new fitting is attempted.
controls={'RIGHT_near_shoulder':[622,354],'RIGHT_near_cuff_elbow':[550,471],'RIGHT_near_wrist':[428,505],'RIGHT_original_grip':[386,506],'LEFT_far_visible_proximal_anchor':[795,471],'LEFT_far_cuff_elbow':[808,513],'LEFT_far_wrist':[953,596]}
j={'schema':'PR122-own-new-E-native-semantic-arm-staff-materials-v1','status':'ACTUAL_OWN_E_NATIVE_PART_INPUT_SHARED_BODY_REGISTERED_PENDING_PARTS_AND_REVEALED_FABRIC_VISUAL_QC','source':pin(P),'native_canvas':[1254,1254],'source_RGBA_resample_or_wholeactor_mirror':False,'shared_once_registration_loaded_exact_JSON':pin(REG),'C':reg['new_E_fixed_C'],'bodyunit':reg['new_E_fixed_bodyunit'],'common_rig_root_in_unpadded_frame':reg['common_rig_root_in_unpadded_frame'],'production_storage_translation':reg['production_storage_translation'],'actual_native_controls':controls,'parts':parts,'semantic_mattes':mattes,'body_inputs':files,'staff_axis_fit_once_from_native_visible_metal':coef.tolist(),'understaff_coat_caveat':'Full attack core now includes bounded original native cape fabric restoration pending visual QC; LEFT-only original bodies retain original pole/cape and are unchanged.','original_assets_modified':False,'actor_approvals_added':0};p=D/'E-own-native-complete-arm-staff-and-LEFT-only-body-readonly-handoff-v02.json';p.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps({'manifest':pin(p),'native_part_count':len(parts),'C_or_root_fitted_here':False}))
# Locally saved small private source board, never automatically returned.
board=Image.new('RGB',(1400,820),(72,72,75));dr=ImageDraw.Draw(board)
items=[('LEFT-only CORE',Image.open(files['LEFT-forearm-only-old-erased-BODY-with-original-RIGHT-staff-arms-and-boots']['body']['path']))]+[(n,Image.open(v['path']))for n,v in parts.items()]
for k,(n,im)in enumerate(items):
 q=im.copy();q.thumbnail((330,370));xy=((k%4)*350,(k//4)*410+25);board.paste(q,xy,q);dr.text(((k%4)*350+4,(k//4)*410+4),n[:42],fill='white')
board.save(D/'private-own-E-native-LEFT-body-and-complete-arm-staff-materials-v02.jpg',quality=85)

preview=Image.new('RGB',(1040,800),(72,72,75));dd=ImageDraw.Draw(preview)
for k,(name,img)in enumerate([('ORIGINAL POLE OCCLUSION',s),('ERASED BEFORE RESTORE',Image.fromarray(before)),('ACTUAL OWN FABRIC PLATE',Image.fromarray(after))]):
 roi=(260,770,510,1020);q=img.crop(roi).resize((500,500));xy=((k%2)*520,(k//2)*270+25);q=q.resize((500,250));preview.paste(q,xy,q);dd.text(((k%2)*520+3,(k//2)*270+3),name,fill='white')
preview.save(D/'private-E-native-cape-actual-revealed-fabric-restoration-before-after-v02.jpg',quality=88)
