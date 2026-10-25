from pathlib import Path
from PIL import Image,ImageDraw
from scipy.ndimage import label,binary_dilation,map_coordinates
import numpy as np,math,json,hashlib
B=Path(__file__).parent;O=B/'actual-NW-ATTACK6-native-rig-v04';O.mkdir(exist_ok=False)
S=Path('/workspace/scratch/mythic413-NW-walk-contact0-author-20261020-v01/left-backswing-native-edit-v02/thunder_female-NW-walk-contact0-LEFTbackswing-bounded-v02.png');R=Path('/workspace/scratch/mythic413-NW-walk-contact0-author-20261020-v01/thunder_female-NW-walk-contact0-v01-service.png');F=Path('/workspace/scratch/mythic413-NW-walk-Rload4-author-20261020-v03/thunder_female-NW-walk-Rload4-finished-native-body-v04.png')
source=Image.open(S).convert('RGBA');raw=Image.open(R).convert('RGBA');flat=Image.open(F).convert('RGBA');W=H=1536;NATIVE=1254
# Storage adds transparent right/bottom only; native density/root never changes.
def pad(im):o=Image.new('RGBA',(W,H));o.paste(im,(0,0));return o
s=pad(raw);z=np.array(s);yy,xx=np.indices((H,W));near=binary_dilation(z[:,:,3]>16,iterations=2);z[(z[:,:,3]<=16)&~near]=0;s=Image.fromarray(z);parts={};masks={}
def poly(q):m=Image.new('L',(W,H));ImageDraw.Draw(m).polygon(q,fill=255);return np.array(m)>0
def isolate(im,m):a=np.array(im).copy();a[~m]=0;return Image.fromarray(a)
def savepart(n,im,m):parts[n]=im;masks[n]=m;im.save(O/f'actual-original-NW-{n}-material.png');Image.fromarray(m.astype('uint8')*255).save(O/f'actual-original-NW-{n}-semantic-matte.png')
def aff(im,A,t):v=np.linalg.inv(A);q=-v@np.asarray(t);return im.transform((W,H),Image.Transform.AFFINE,tuple(v[0])+(q[0],)+tuple(v[1])+(q[1],),Image.Resampling.BICUBIC)
def bone(im,a,b,c,d):
 a,b,c,d=map(lambda v:np.array(v,float),(a,b,c,d));u=(b-a)/np.linalg.norm(b-a);v=(d-c)/np.linalg.norm(d-c);M=np.column_stack((v*np.linalg.norm(d-c)/np.linalg.norm(b-a),[-v[1],v[0]]))@np.column_stack((u,[-u[1],u[0]])).T;off=c-M@a;return aff(im,M,off),M,off
RU=poly([(681,465),(705,459),(722,466),(736,479),(741,499),(739,519),(730,547),(710,544),(691,531),(678,516),(670,495)])
RF=poly([(786,415),(815,408),(840,418),(844,439),(838,462),(824,489),(811,516),(790,545),(768,564),(747,561),(731,548),(726,530),(733,508),(743,486),(765,463),(780,443)])
LU=poly([(573,439),(613,449),(628,478),(611,519),(590,551),(572,560),(549,544),(534,517),(538,477),(549,448)])
LF=poly([(543,509),(575,523),(586,547),(571,577),(550,603),(526,627),(514,653),(511,681),(501,707),(446,711),(442,680),(459,639),(474,602),(495,574),(513,537),(526,519)])
# Gold/blue coat is a separate actual foreground; no old calf is called cloth.
coat=poly([(685,615),(779,647),(836,683),(906,744),(981,793),(1074,839),(1062,872),(994,866),(963,931),(895,891),(845,846),(790,797),(747,744),(713,693)])
LL=poly([(540,707),(626,707),(614,767),(591,818),(576,852),(552,893),(546,919),(532,959),(502,959),(497,929),(473,920),(447,891),(465,867),(495,855),(508,822),(511,786),(522,745)])&~coat
RL=poly([(627,711),(710,711),(742,783),(772,882),(808,1006),(843,1123),(820,1152),(768,1153),(744,1091),(694,988),(656,913),(624,840)])&~coat
for n,m in [('RIGHT-upper-arm',RU),('RIGHT-forearm-hand',RF),('LEFT-upper-arm',LU),('LEFT-forearm-hand',LF),('LEFT-leg',LL),('RIGHT-leg',RL)]:savepart(n,isolate(s,m),m)
# Actual full original ornamented pole, isolated from the native NW view.
# One straight hidden metal continuation is reconstructed from the observed
# native shaft radial profile; no decoration, tip, or equipment is invented.
axis=883.5-.151*yy;half=np.interp(yy.ravel(),[0,30,65,110,155,185,210,250,280,320,360,420,678,783,800,825,845,870,890,920,945],[2,9,23,38,51,30,27,25,15,11,8,8,8,13,19,21,20,21,23,12,0]).reshape(H,W)
protect=np.zeros((H,W),bool);pm=np.array(Image.open('/workspace/scratch/mythic413-NW-walk-terminal2-author-20261020-v02/terminal2-original-rigid-staff-mask-v01.png'))>0;protect[:NATIVE,:NATIVE]=pm
wm=((xx>=775)&(xx<=950)&(yy<350))|((np.abs(xx-axis)<=14)&(yy>=350)&(yy<678))
# Native lower ornament alpha/color contour; rejects adjacent dark leg/coat.
rgb=z[:,:,:3].astype(float);metal=((rgb[:,:,0]>80)&(rgb[:,:,0]>rgb[:,:,1]*1.03)&(rgb[:,:,1]>rgb[:,:,2]*1.25))|((rgb[:,:,2]>rgb[:,:,0]*1.4)&(rgb[:,:,1]>rgb[:,:,0]*1.3))
for y in range(783,935):
 cx=883.5-.151*y;span=18 if y<816 else 27;xs=np.where(metal[y]&(z[y,:,3]>100)&(np.abs(np.arange(W)-cx)<=span))[0]
 if len(xs):wm[y,max(0,int(xs.min())-6):min(W,int(xs.max())+7)]=True
wm&=~RF
weapon=isolate(s,wm);wa=np.array(weapon);profile=[]
for u in range(-8,9):
 vals=[]
 for y in range(535,581):
  x=round(883.5-.151*y)+u
  if z[y,x,3]>100:vals.append(z[y,x,:3])
 profile.append(np.median(vals,axis=0)if vals else[130,75,8])
# In front of the actual hand these shaft pixels are occluded by its intact art.
for y in range(360,790):
 cx=883.5-.151*y
 for x in range(math.floor(cx-7),math.ceil(cx+7)+1):
  u=x-cx
  if abs(u)>7.5:continue
  k=int(np.clip(round(u)+8,0,16))
  if wa[y,x,3]==0:wa[y,x,:3]=profile[k];wa[y,x,3]=252 if abs(u)<6.5 else int(252*(7.5-abs(u)))
weapon=Image.fromarray(wa);savepart('complete-rigid-RIGHT-staff',weapon,wa[:,:,3]>0)
# Complete original LEFT support shoe, exact native color and silhouette.
leftflatpath=Path('/workspace/scratch/mythic413-NW-walk-LOAD1-author-20261020-v01/thunder_female-NW-walk-LOAD1-rigged-retouched-v04.png')
leftflat=pad(Image.open(leftflatpath).convert('RGBA'));lfm=poly([(600,944),(653,938),(680,967),(686,1009),(671,1037),(636,1051),(610,1055),(584,1041),(575,1017),(577,987),(594,966)])
lfz=np.array(leftflat);lcc,ln=label(lfm&(lfz[:,:,3]>8));lss=np.bincount(lcc.ravel());lss[0]=0;lcore=lcc==lss.argmax();lfm=binary_dilation(lcore,iterations=2)&lfm&(lfz[:,:,3]>0);Lfootraw=isolate(leftflat,lfm);Lfoot=Image.new('RGBA',(W,H));Lfoot.paste(Lfootraw,(-111,-100))
# Reuse own actual anatomical RIGHT flat shoe from approved NW source4, never
# mirror LEFT gear. One initial attack stance placement stays fixed for all6.
dx4=705.4843188022421-712.;dy4=1014.538886922018-1075.;rfq=np.array([(694,968),(730,966),(750,1018),(746,1078),(725,1091),(680,1094),(645,1073),(636,1045),(653,1010),(679,998)],float)+[dx4,dy4];rfm=poly(rfq.tolist());fz=np.array(pad(flat));cc,n=label(rfm&(fz[:,:,3]>8));sizes=np.bincount(cc.ravel());sizes[0]=0;core=cc==sizes.argmax();rfm=binary_dilation(core,iterations=2)&rfm&(fz[:,:,3]>0);Rfootraw=isolate(pad(flat),rfm);Rfoot=Image.new('RGBA',(W,H));Rfoot.paste(Rfootraw,(-1,100));Lfoot.save(O/'actual-complete-LEFT-fixed-attack-stance-shoe.png');Rfoot.save(O/'actual-complete-RIGHT-flat-fixed-attack-stance-shoe.png')
# Core uses the preserved clean garment visible in original forward-LEFT art;
# newer backward-arm art occludes this same real garment and is not repainted.
completelegs=(yy>=713)&(xx<870)&~coat
completeweapon=((xx>=775)&(yy<350))|(protect&(yy>=783))|((np.abs(xx-axis)<=17)&(yy>=350)&(yy<678))
olderase=LU|LF|RU|RF|LL|RL|completelegs|completeweapon
# Complete old LEFT outer hand/AA erasure; outside this native arm region and
# selected actual limbs/equipment source costume is preserved byte-for-byte.
olderase|=poly([(570,438),(615,448),(631,478),(613,524),(593,555),(575,591),(543,622),(518,650),(511,684),(503,710),(443,713),(440,677),(457,635),(472,599),(493,571),(510,534),(525,497),(536,467),(548,445)])
# Source weapon pixels hidden by native arms/coat are already native arms/coat,
# so remove only observed pole outside those actual costume foregrounds.
leftonly=LU|LF|poly([(570,438),(615,448),(631,478),(613,524),(593,555),(575,591),(543,622),(518,650),(511,684),(503,710),(443,713),(440,677),(457,635),(472,599),(493,571),(510,534),(525,497),(536,467),(548,445)]);isolate(s,~leftonly).save(O/'actual-NW-clean-original-garment-LEFT-oldarm-erased-body-staff-legs-INPUT.png')
body=isolate(s,~olderase);body.save(O/'actual-native-head-torso-skirt-coat-old-arms-legs-staff-removed-INPUT.png');Image.fromarray(olderase.astype('uint8')*255).save(O/'complete-original-old-limb-and-visible-staff-erasure-mask.png')
# Actual original joints and complete existing gear; all 6 new action rigs are
# bespoke for NW, anatomical RIGHT far staff / LEFT near free. Not N mirroring.
S_R=np.array([704.,485.]);E_R=np.array([736.,520.]);W_R=np.array([805.,449.]);G=np.array([819.,432.]);S_L=np.array([589.,458.]);E_L=np.array([553.,531.]);W_L=np.array([491.,625.]);PIV=np.array([641.,706.]);root=[641.,1058.3]
phases=[dict(name='READY',ang=0.,delta=[0,0],re=[736,520],rw=[805,449],le=[565,531],lw=[525,600],staff=0.,lk=[563,808],rk=[685,850],cloth=0),dict(name='WINDUP',ang=3.,delta=[6,7],re=[779,540],rw=[843,472],le=[575,536],lw=[553,608],staff=20.,lk=[570,817],rk=[697,855],cloth=-7),dict(name='COIL',ang=6.,delta=[8,13],re=[791,546],rw=[860,469],le=[590,547],lw=[570,613],staff=32.,lk=[579,825],rk=[697,865],cloth=-13),dict(name='STRIKE3',ang=-6.,delta=[-17,-9],re=[608,437],rw=[522,420],le=[612,510],lw=[692,558],staff=-70.,lk=[548,797],rk=[670,842],cloth=7),dict(name='FOLLOW',ang=-8.,delta=[-24,-3],re=[600,461],rw=[520,460],le=[618,516],lw=[702,571],staff=-88.,lk=[547,805],rk=[665,850],cloth=16),dict(name='RECOVER',ang=0.,delta=[0,0],re=[735,520],rw=[804,450],le=[567,532],lw=[530,600],staff=-3.,lk=[560,810],rk=[680,852],cloth=4)]
# Opaque geometric ankle connector uses native actual calf/foot material.
import ast
ns=dict(Image=Image,np=np,W=W,H=H);tree=ast.parse(Path('/workspace/scratch/mythic413-N-walk-load-author-fresh-20261020-v01/author-actual-N-LOAD1-rig-v03.py').read_text());exec(compile(ast.Module([n for n in tree.body if isinstance(n,ast.FunctionDef)and n.name=='attach_complete_native_foot'],[]),'actual-complete-native-shoe-join','exec'),ns);attach=ns['attach_complete_native_foot']
records=[]
for i,p in enumerate(phases):
 t=math.radians(p['ang']);M=np.array([[math.cos(t),-math.sin(t)],[math.sin(t),math.cos(t)]]);delta=np.array(p['delta']);off=PIV+delta-M@PIV
 def point(v):return M@np.array(v)+off
 # Native gold/blue cloak reacts at its own garment attachment. Premultiplied
 # sampling preserves material edges; whole-body density is never normalized.
 az=np.array(body).astype(float)/255.;alpha=az[:,:,3];w=np.clip((yy-650)/280,0,1)*np.clip((xx-750)/250,0,1);sx=xx-p['cloth']*w;sy=yy-p['cloth']*.18*w;al=map_coordinates(alpha,[sy,sx],order=1,mode='constant',cval=0);rgb=np.stack([map_coordinates(az[:,:,c]*alpha,[sy,sx],order=1,mode='constant',cval=0)for c in range(3)],2);rgb=np.divide(rgb,al[:,:,None],out=np.zeros_like(rgb),where=al[:,:,None]>1e-8);clothbody=Image.fromarray(np.uint8(np.clip(np.dstack((rgb,al))*255+.5,0,255)));corebody=aff(clothbody,M,off)
 ru,_,_=bone(parts['RIGHT-upper-arm'],S_R,E_R,point(S_R),p['re']);rf,FM,Foff=bone(parts['RIGHT-forearm-hand'],E_R,W_R,p['re'],p['rw']);grip=FM@G+Foff;st=math.radians(p['staff']);SM=np.array([[math.cos(st),-math.sin(st)],[math.sin(st),math.cos(st)]]);staff=aff(weapon,SM,grip-SM@G)
 lu,_,_=bone(parts['LEFT-upper-arm'],S_L,E_L,point(S_L),p['le']);lf,_,_=bone(parts['LEFT-forearm-hand'],E_L,W_L,p['le'],p['lw'])
 limbs=Image.new('RGBA',(W,H))
 for side,hip,knee,ankle,k,foot,start,end in [('LEFT',[612,706],[563,808],[521,890],p['lk'],Lfoot,846,869),('RIGHT',[670,706],[700,871],[785,1071],p['rk'],Rfoot,1012,1037)]:
  part=parts[side+'-leg'];a=np.array(part);th=a.copy();th[np.indices((H,W))[0]>knee[1]+12]=0;ca=a.copy();ca[np.indices((H,W))[0]<knee[1]-12]=0;thigh,_,_=bone(Image.fromarray(th),hip,knee,point(hip),k);targetankle=[520.,872.] if side=='LEFT'else[697.4843188022421,1040.538886922018];calf,_,_=bone(Image.fromarray(ca),knee,ankle,k,targetankle);leg=Image.new('RGBA',(W,H));leg.alpha_composite(thigh);leg.alpha_composite(calf);leg=attach(leg,foot,start,end);limbs.alpha_composite(leg)
 # Far RIGHT chain and complete staff are genuinely occluded by the NW body;
 # near LEFT chain stays the foreground. Grip computed from same arm affine.
 out=Image.new('RGBA',(W,H));out.alpha_composite(staff);out.alpha_composite(ru);out.alpha_composite(rf);out.alpha_composite(limbs);out.alpha_composite(corebody);out.alpha_composite(lu);out.alpha_composite(lf)
 q=O/f'thunder_female-NW-attack-{i}-{p["name"]}-actual-native-rig-v04.png';out.save(q)
 for n,im in [('RIGHTstaff',staff),('RIGHTupper',ru),('RIGHTfore',rf),('LEFTupper',lu),('LEFTfore',lf),('legs',limbs)]:im.save(O/f'phase{i}-actual-{n}-node.png')
 a=np.array(out);cc,n=label(a[:,:,3]>100);sizes=np.bincount(cc.ravel());big=sorted([int(x)for x in sizes[1:]if x>=200],reverse=True);records.append({'phase':i,'name':p['name'],'path':str(q),'sha256':hashlib.sha256(q.read_bytes()).hexdigest(),'native_size':[W,H],'original_native_canvas':[1254,1254],'transparent_extension_right_bottom_only':[282,282],'physical_C':2048,'bodyunit':2,'common_rig_root_in_unpadded_frame':root,'storage_translation':[0,0],'actual_rig_nodes':p,'RIGHT_exact_same_affine_grip_target':grip.tolist(),'RIGHT_staff_rigid_rotation_matrix':SM.tolist(),'RIGHT_weapon_top_original':[880,20],'RIGHT_weapon_top_target':(SM@(np.array([880.,20.])-G)+grip).tolist(),'RIGHT_staff_orthogonality_error':float(abs(SM.T@SM-np.eye(2)).max()),'strong_alpha100_components_ge200':big,'status':'ACTUAL_NEW_NW_ATTACK_SOURCE_PENDING_INDEPENDENT_QC'})
contract={'status':'ACTUAL_NW_ATTACK6_NEW_NATIVE_DIRECTIONAL_RIG_PENDING_INDEPENDENT_SOURCE_CONTACT3_AND_CYCLE_QC','source_selected_NW_body':str(S),'source_selected_sha256':hashlib.sha256(S.read_bytes()).hexdigest(),'clean_garment_and_LEFT_forearm_donor_original':str(R),'clean_donor_sha256':hashlib.sha256(R.read_bytes()).hexdigest(),'own_RIGHT_flat_shoe_donor':str(F),'own_RIGHT_flat_shoe_donor_sha256':hashlib.sha256(F.read_bytes()).hexdigest(),'C':2048,'bodyunit':2,'common_rig_root':root,'fixed_attack_twofoot_stance_goldheels':{'LEFT':[514.3543188022422,944.2188869220179],'RIGHT':[704.4843188022421,1114.538886922018]},'same_camera_and_bodyunit_as_existing_NW_sources':True,'wholeactor_N_or_NE_mirror_or_perpose_C_rootfit_alphaheightfit':False,'new_walk_production':False,'initial_only_RIGHT_flat_shoe_native_translation_from_source4':[-1,100],'initial_only_LEFT_flat_shoe_native_translation_from_source1':[-111,-100],'own_LEFT_flat_shoe_donor':str(leftflatpath),'actual_common_root_heading_groundline_slope':.9,'unseen_straight_gold_shaft_continuation':'actual native visible shaft radialprofile source rows535..580, hidden hand418..497 and coat672..789 only; same original pole and two ornament ends','RIGHTfarstaff_LEFTnearfree':True,'one_shot':True,'intended_contact_frame':3,'role_seconds_preserved':.42,'fps':6/.42,'frames':records,'actor_approval_added':0};(O/'NW-ATTACK6-actual-directional-rig-contract-v04.json').write_text(json.dumps(contract,indent=2)+'\n')
board=Image.new('RGBA',(3*430,2*430),(195,202,210,255))
for f in records:
 im=Image.open(f['path']).convert('RGBA');im.thumbnail((430,430));board.alpha_composite(im,((f['phase']%3)*430,(f['phase']//3)*430))
p=O/'private-NW-ATTACK6-actual-board-v04.jpg';board.convert('RGB').save(p,quality=86,optimize=True);assert p.stat().st_size<150000;print(json.dumps({'actual_six':6,'contract':str(O/'NW-ATTACK6-actual-directional-rig-contract-v04.json'),'strong_body_components':[f['strong_alpha100_components_ge200']for f in records],'contact3_weapon_top_target':records[3]['RIGHT_weapon_top_target'],'preview_bytes':p.stat().st_size}))
