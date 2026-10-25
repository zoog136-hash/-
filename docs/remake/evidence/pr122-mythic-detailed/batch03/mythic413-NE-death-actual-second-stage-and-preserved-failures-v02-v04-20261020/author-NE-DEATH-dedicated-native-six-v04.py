from pathlib import Path
import json,hashlib,math
import numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import label
from scipy.spatial.transform import Rotation,Slerp

B=Path(__file__).parent;D=B/'actual-NE-DEATH-six-native-v04';D.mkdir();N=2304;P=256;PX=10/9;ROOT=np.array([716.2291666666666,1054.2766007046484]);BONE=275.2625
SP=Path('/workspace/scratch/mythic413-NE-walk-author-20261020-v01/NE-contact0-actual-native-background-AA-clean-r002.png');assert hashlib.sha256(SP.read_bytes()).hexdigest()=='99ffa7da2332144f3d449e9e23881bbaa130ace3027e837518148b705d92c127'
M=Path('/workspace/scratch/mythic413-NE-run-author-20261020-v01/common-complete-NE-native-material-parts-v03')
BP=M/'original-actual-BODY-only-complete-old-thigh-and-arm-removed-native.png';LP=M/'original-actual-complete-RIGHT-thigh-and-calf-native.png';AP=M/'original-actual-complete-LEFT-cuff-elbow-cap-forearm-hand-native.png';FP=Path('/workspace/scratch/mythic413-NE-run-author-20261020-v01/contact0-actual-NE-run-v01/RIGHT-complete-shoe-native-RGBA.png');RP=Path('/workspace/scratch/mythic413-NE-run-author-20261020-v01/actual-NE-run-six-fixed-rig-v02/NE-run-six-actual-causal-rig-shoe-surface-and-source-contract-v02.json')
src=Image.open(SP).convert('RGBA');body=Image.open(BP).convert('RGBA');leg=Image.open(LP).convert('RGBA');leftfore=Image.open(AP).convert('RGBA');foot=Image.open(FP).convert('RGBA');rig=json.loads(RP.read_text());assert rig['fixed_femur_tibia_native']==BONE
def blank():return Image.new('RGBA',(N,N))
def native(im):
 q=blank();q.paste(im,(P,P));return q
def maskpoly(poly):
 q=Image.new('L',(1254,1254));ImageDraw.Draw(q).polygon(poly,fill=255);return q
def selected(im,mask):
 a=np.array(im);a[:,:,3]=np.minimum(a[:,:,3],np.array(mask));a[a[:,:,3]==0,:3]=0;return Image.fromarray(a)
def remove(im,mask):
 a=np.array(im);a[np.array(mask)>0]=0;return Image.fromarray(a)
def split_y(im,y0,y1):
 m=Image.new('L',(1254,1254));ImageDraw.Draw(m).rectangle((0,y0,1253,y1),fill=255);return selected(im,m)
headmask=maskpoly([(530,175),(807,175),(807,415),(748,431),(701,429),(661,410),(632,403),(612,388),(573,377),(550,363)])
ImageDraw.Draw(headmask).polygon([(609,336),(626,348),(606,376),(577,400),(544,419),(506,433),(478,448),(454,469),(443,487),(427,456),(427,438),(444,422),(484,409),(523,397),(558,376),(589,351)],fill=255)
ImageDraw.Draw(headmask).polygon([(613,346),(639,352),(642,374),(633,400),(624,431),(614,462),(599,487),(578,509),(548,522),(535,508),(546,490),(561,462),(577,435),(591,407),(600,378)],fill=255)
head=selected(body,headmask);body=remove(body,headmask)
rforemask=maskpoly([(798,558),(808,552),(828,557),(851,551),(878,541),(909,527),(929,514),(964,524),(970,552),(965,583),(938,595),(904,607),(875,632),(846,636),(826,629),(808,618),(796,601),(790,582)])
ImageDraw.Draw(rforemask).rectangle((865,0,1253,1253),fill=255)
rfore=selected(body,rforemask);body=remove(body,rforemask)
rum=maskpoly([(725,420),(754,409),(787,426),(807,449),(817,473),(829,493),(833,523),(819,548),(810,559),(793,563),(777,550),(764,529),(748,515),(732,489)])
rupper=selected(body,rum);body=remove(body,rum)
lum=maskpoly([(601,459),(627,467),(637,486),(626,507),(609,525),(590,539),(569,539),(549,528),(549,509),(569,491),(583,475)])
lupper=selected(body,lum);body=remove(body,lum)
leftcoatmask=maskpoly([(645,611),(670,625),(653,664),(614,707),(564,763),(536,826),(508,889),(490,898),(464,884),(432,925),(387,977),(359,992),(340,947),(326,889),(300,847),(267,819),(305,800),(363,779),(432,750),(502,715),(562,678),(611,638)])
rightcoatmask=maskpoly([(728,610),(760,632),(762,664),(750,716),(738,779),(725,842),(711,916),(697,992),(676,969),(650,956),(620,941),(580,928),(540,927),(562,900),(590,860),(622,806),(653,752),(675,700),(700,655)])
coats=[]
for name,m in [('LEFT',leftcoatmask),('RIGHT',rightcoatmask)]:coats.append((name,selected(body,m)));body=remove(body,m)
# Transfer every actual distal coat remainder, not only the first trace.
# Source<=805 proximal skin/garter remains an explicit pelvis cap; no boot
# color replacement or blue/gold trim is deleted.
yy0,xx0=np.mgrid[:1254,:1254];cap=(xx0>=610)&(xx0<=700)&(yy0<=805);tail=(yy0>=735)&~cap
for ci,(name,im) in enumerate(coats):
 take=tail&((xx0<615)if name=='LEFT'else(xx0>=615));mm=Image.fromarray((take*255).astype('uint8'));extra=selected(body,mm);im.alpha_composite(extra);coats[ci]=(name,im);body=remove(body,mm)
pelvis=split_y(body,628,1253);torso=split_y(body,0,642)
thigh=split_y(leg,0,824);calf=split_y(leg,804,1253)
# Actual canonical full counter/stiletto remains one rigid material; only its
# old source-crop top receives a rounded native leather alpha boundary.
fm=Image.new('L',(1254,1254));ImageDraw.Draw(fm).ellipse((784,923,841,966),fill=255);fa=np.array(foot);ma=np.array(fm);ma[944:]=255;fa[:,:,3]=np.minimum(fa[:,:,3],ma);fa[fa[:,:,3]==0,:3]=0;roundedfoot=Image.fromarray(fa)
km=Image.new('L',(1254,1254));ImageDraw.Draw(km).ellipse((768,800,812,836),fill=255);kcap=selected(leg,km)
parts={'pelvis-pleated-skirt-and-original-proximal-skin-cap':pelvis,'torso-native-bluegold-bodice':torso,'head-face-bun-and-original-hair':head,'LEFT-upperarm-native':lupper,'LEFT-complete-cuff-forearm-hand-native':leftfore,'RIGHT-upperarm-native':rupper,'RIGHT-complete-forearm-grip-staff-both-ends-native':rfore,'RIGHT-complete-native-thigh':thigh,'RIGHT-complete-native-calf':calf,'RIGHT-rounded-native-knee-leather':kcap,'RIGHT-complete-counter-stiletto-rounded-native-interface':roundedfoot}
for name,im in parts.items():im.save(D/('native-'+name+'.png'))
for name,im in coats:im.save(D/f'native-{name}-complete-bluegold-coattail.png')
for name,m in [('HEAD',headmask),('RIGHT-forearm-fullstaff',rforemask),('RIGHT-upperarm',rum),('LEFT-upperarm',lum),('LEFT-coat',leftcoatmask),('RIGHT-coat',rightcoatmask)]:m.save(D/f'actual-source-{name}-semantic-matte.png')
inputs=[SP,BP,LP,AP,FP,RP,Path('/workspace/scratch/mythic413-N-death-author-20261020-v01/author-N-death-dedicated-native-six-v09.py')]
manifest=B/'NE-DEATH-own-native-inputs-and-proven-method-frozen-v04.json';assert not manifest.exists();manifest.write_text(json.dumps(dict(status='FROZEN_OWN_NE_NATIVE_INPUTS_NEW_DEDICATED_DEATH_NOT_N_FLIP',files=[dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)for p in inputs]),indent=2)+'\n')
def proj(q):return np.array([ROOT[0]+PX*q[0],ROOT[1]+q[1]-q[2]])
def plane(im,sa,A,U,V):
 C=np.array([[PX*U[0],PX*V[0]],[U[1]-U[2],V[1]-V[2]]]);assert abs(np.linalg.det(C))>.015;iv=np.linalg.inv(C);cc=np.array(sa)+P-iv@(proj(A)+P)
 return native(im).transform((N,N),Image.Transform.AFFINE,(iv[0,0],iv[0,1],cc[0],iv[1,0],iv[1,1],cc[1]),resample=Image.Resampling.BICUBIC)
def bone(im,sa,sb,A,Z,parity=1):
 sa=np.array(sa)+P;sb=np.array(sb)+P;ta=proj(A)+P;tb=proj(Z)+P;sv=sb-sa;tv=tb-ta;sl=np.linalg.norm(sv);tl=np.linalg.norm(tv);sn=np.array([-sv[1],sv[0]])/sl;tn=np.array([-tv[1],tv[0]])/tl;C=np.outer(sv,tv)/(tl*tl)+parity*np.outer(sn,tn);cc=sa-C@ta
 return native(im).transform((N,N),Image.Transform.AFFINE,(C[0,0],C[0,1],cc[0],C[1,0],C[1,1],cc[1]),resample=Image.Resampling.BICUBIC)
def knee(H,A,side):
 v=A-H;ds=np.linalg.norm(v);assert 0<ds<2*BONE;u=v/ds;mid=(H+A)/2;h=math.sqrt(BONE*BONE-ds*ds/4);p=np.array([0.,0,-1.]);p-=np.dot(p,u)*u;p/=np.linalg.norm(p);zmin=mid[2]+h*p[2]
 if zmin<45:
  co=np.clip((45-mid[2])/(h*p[2]),-1,1);sideaxis=np.cross(u,p);p=co*p+(1 if side=='R'else -1)*math.sqrt(1-co*co)*sideaxis
 q=mid+h*p;assert abs(np.linalg.norm(q-H)-BONE)<1e-7 and abs(np.linalg.norm(q-A)-BONE)<1e-7;return q
def flatten(U,V,target_angle=63.43494882292201):
 e1=U/np.linalg.norm(U);q=V-np.dot(V,e1)*e1;e2=q/np.linalg.norm(q);e3=np.cross(e1,e2);t=math.radians(target_angle);f1=np.array([math.cos(t),math.sin(t),0.]);f2=np.array([-math.sin(t),math.cos(t),0.]);f3=np.cross(f1,f2);R=np.column_stack([f1,f2,f3])@np.column_stack([e1,e2,e3]).T;assert abs(np.linalg.det(R)-1)<1e-9;return R
U=np.array([.9,20/94,20/94]);V=np.array([0.,0,-1.]);Rf=flatten(U,V);slerp=Slerp([0,1],Rotation.from_matrix(np.array([np.eye(3),Rf])))
def rot_axis(axis,degrees):return Rotation.from_rotvec(axis/np.linalg.norm(axis)*math.radians(degrees)).as_matrix()
def cloth(im,sa,A,angle):
 t=math.radians(angle);co=math.cos(t);si=math.sin(t);ys=np.arange(1254,dtype=float);length=ys-sa[1];hit=max(0.,(A[2]-10)/max(co,1e-6));z=np.where(length<=hit,A[2]-co*length,10.);depth=np.where(length<=hit,A[1]+si*length,A[1]+si*hit+length-hit);ty=ROOT[1]+depth-z+P;assert np.all(np.diff(ty)>0);tx=proj(A)[0]-sa[0]+P;mesh=[]
 for yy in range(N):
  sy=float(np.interp(yy,ty,ys,left=-100,right=1400));sy2=float(np.interp(yy+1,ty,ys,left=-100,right=1400));mesh.append(((0,yy,N,yy+1),(-tx,sy,-tx,sy2,N-tx,sy2,N-tx,sy)))
 return im.transform((N,N),Image.Transform.MESH,mesh,resample=Image.Resampling.BICUBIC)
states=[dict(name='STAGGER-loss-of-balance',hip=[9.7,241.8517002361313,582.1283009407798],body=0.,pelvis=0.,head=0.,rightupper=0.,leftupper=0.,leftfore=0.,foot=0.,heels=[[74.94375,-16.2766007046484,10.],[-169.85625,142.7233992953516,10.]],cloth=0),dict(name='BUCKLE-hips-drop',hip=[4.7,220.,470.],body=.12,pelvis=.06,head=-4.,rightupper=-5.,leftupper=-7.,leftfore=4.,foot=0.,heels=[[74.94,-6.,10.],[-169.85,150.,10.]],cloth=15),dict(name='KNEES-catch-floor',hip=[20.,230.,260.],body=.38,pelvis=.28,head=5.,rightupper=-12.,leftupper=-12.,leftfore=-2.,foot=.15,heels=[[10.,100.,20.],[-110.,200.,10.]],cloth=45),dict(name='TORSO-collapse',hip=[60.,280.,170.],body=.76,pelvis=.62,head=9.,rightupper=-22.,leftupper=-13.,leftfore=-8.,foot=.5,heels=[[-60.,240.,25.],[-160.,300.,20.]],cloth=65),dict(name='PRONE-impact-settle',hip=[100.,310.,72.],body=1.,pelvis=.96,head=3.,rightupper=-29.,leftupper=-11.,leftfore=-14.,foot=.95,heels=[[-240.,390.,20.],[-340.,430.,20.]],cloth=80),dict(name='DEAD-terminal-held',hip=[105.,315.,60.],body=1.,pelvis=1.,head=0.,rightupper=-30.,leftupper=-10.,leftfore=-15.,foot=1.,heels=[[-330.,430.,20.],[-430.,475.,20.]],cloth=90)]
rows=[]
for ph,st in enumerate(states):
 H=np.array(st['hip']);Rb=slerp([st['body']]).as_matrix()[0];Rp=slerp([st['pelvis']]).as_matrix()[0];atpel=lambda x,y:H+Rp@(U*(x-727)+V*(y-714));waist=atpel(727,630);attorso=lambda x,y:waist+Rb@(U*(x-727)+V*(y-630));nodes={};leglayers=[];jointmeta={}
 for index,side in enumerate(['R','L']):
  heel=np.array(st['heels'][index]);fu=np.array(rig['source_shoe_plane_lift'])[:,0].copy();fv=np.array(rig['source_shoe_plane_lift'])[:,1].copy()
  if side=='L':fu[0]*=-1
  F=flatten(fu,fv);fr=Slerp([0,1],Rotation.from_matrix(np.array([np.eye(3),F])))([st['foot']]).as_matrix()[0];fU=fr@fu;fV=fr@fv;ankle=heel+fU*(811-799.5)+fV*(944-1028);hip=atpel(774 if side=='R'else 680,724 if side=='R'else 704);kn=knee(hip,ankle,side);par=1 if side=='R'else -1;lay=blank();lay.alpha_composite(bone(thigh,[774,724],[790,815],hip,kn,par));lay.alpha_composite(bone(calf,[790,815],[811,944],kn,ankle,par));ax=(ankle-kn)/np.linalg.norm(proj(ankle)-proj(kn));lay.alpha_composite(bone(kcap,[790,815],[790,833],kn,kn+18*ax,par));lay.alpha_composite(plane(roundedfoot,[799.5,1028],heel,fU,fV));leglayers.append(lay);jointmeta[side]=dict(hip=hip.tolist(),knee=kn.tolist(),ankle=ankle.tolist(),heel=heel.tolist(),thigh_length=float(np.linalg.norm(kn-hip)),shin_length=float(np.linalg.norm(ankle-kn)),source_foot_U=fU.tolist(),source_foot_V=fV.tolist(),foot_SO3=fr.tolist(),paired_boot_material_only=side=='L')
 pelvisr=plane(pelvis,[727,714],H,Rp@U,Rp@V);torsor=plane(torso,[727,630],waist,Rb@U,Rb@V);neck=attorso(710,421);headR=rot_axis(Rb@U,st['head'])@Rb;headr=plane(head,[710,421],neck,headR@U,headR@V)
 arms={}
 for side,upper,fore,shoulder0,elbow0,angle in [('R',rupper,rfore,[765,462],[807,556],st['rightupper']),('L',lupper,leftfore,[617,478],[569,535],st['leftupper'])]:
  shoulder=attorso(*shoulder0);upperR=rot_axis(Rb@U,angle)@Rb;dv=U*(elbow0[0]-shoulder0[0])+V*(elbow0[1]-shoulder0[1]);elbow=shoulder+upperR@dv;foreR=slerp([[0.,.15,.64,.9,1.,1.][ph]]).as_matrix()[0] if side=='R'else rot_axis(Rb@U,st['leftfore'])@Rb;lay=blank();lay.alpha_composite(plane(upper,shoulder0,shoulder,upperR@U,upperR@V));lay.alpha_composite(plane(fore,elbow0,elbow,foreR@U,foreR@V));arms[side]=lay;nodes[side]=dict(shoulder=shoulder.tolist(),elbow=elbow.tolist(),upperbone_length=float(np.linalg.norm(dv)),upperarm_source_U=(upperR@U).tolist(),upperarm_source_V=(upperR@V).tolist(),source_shoulder=shoulder0,forearm_source_U=(foreR@U).tolist(),forearm_source_V=(foreR@V).tolist(),source_elbow=elbow0,whole_grip_fullstaff_rigid=side=='R',dedicated_weapon_catch_progress=[0.,.15,.64,.9,1.,1.][ph] if side=='R'else None)
 out=blank()
 for name,im in coats:out.alpha_composite(cloth(im,[650 if name=='LEFT'else 730,630],atpel(650 if name=='LEFT'else 730,630),st['cloth']))
 for lay in leglayers:out.alpha_composite(lay)
 out.alpha_composite(pelvisr);out.alpha_composite(torsor);out.alpha_composite(headr);out.alpha_composite(arms['L']);out.alpha_composite(arms['R']);p=D/f'NE-death-phase{ph}-actual-native-v04.png';out.save(p);a=np.array(out);labs,n=label(a[:,:,3]>100);ar=np.bincount(labs.ravel());strong=[int(z)for z in ar[1:]if z>=200];yy,xx=np.where(a[:,:,3]>0);border=bool(xx.min()==0 or yy.min()==0 or xx.max()==N-1 or yy.max()==N-1)
 rows.append(dict(phase=ph,name=st['name'],path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size,seconds_range=[ph*.8/6,(ph+1)*.8/6],state=st,bones=jointmeta,pelvis_world=H.tolist(),pelvis_SO3=Rp.tolist(),torso_waist_world=waist.tolist(),torso_SO3=Rb.tolist(),head_neck_world=neck.tolist(),head_SO3=headR.tolist(),arms=nodes,strong_components=strong,storage_boundary_alpha_contact=border,alpha_bbox_stored=[int(xx.min()),int(yy.min()),int(xx.max()),int(yy.max())],source_status='ACTUAL_FIRST_DEDICATED_NE_DEATH_NATIVE_SOURCE_PENDING_JOINT_SEMANTIC_SOURCE_CYCLE_FLOOR_QC'))
contract=dict(status='ACTUAL_NEW_NE_DEATH_SIX_FIRST_NATIVE_SOURCE_PENDING_QUALITY_AND_PHYSICAL_QC',actor='transform:413',direction='NE',motion='death',fixed_C=2432,bodyunit=2.375,common_unpadded_root=ROOT.tolist(),source_native_canvas=[1254,1254],storage_canvas=[N,N],storage_translation=[P,P],logical_canvas=1024,profile_modified=False,runtime_death_seconds=.8,resource_role_seconds=.65,phase_seconds=.8/6,resource_fps=6/.65,loop=False,held_dead_terminal=True,frames=rows,input_manifest=dict(path=str(manifest),sha256=hashlib.sha256(manifest.read_bytes()).hexdigest()),source_capture_body_U=U.tolist(),source_capture_body_V=V.tolist(),native_body_anchor=[727,714],original_NE_femur_tibia=BONE,actual_motion='Separate trueSO3 pelvis/torso/head and upperarms; rigid complete RIGHTforearm grip entire staff with both ends; own NE canonical275.2625 fixedbone legs, true complete native calf/counter/stiletto materials, native rounded leather joints; pinned native arclength coattail drapes onto floor10; distinct collapse→prone→dead-held terminal. WholePNG rotation/mirror substitution absent.',limits=['First actual six require independent native material and complete source/collapse/held-terminal QC. No detailed actor approval or game adoption asserted.','Original NE LEFTproximal skin cap remains explicitly on pelvis pending source join evaluation; all input/failed versions are preserved.','This is one constructive native material/skeleton capture, not uniquely inferred hidden source anatomy.','Source staff/arm/coat semantic boundaries and fixedbone surfaces need actual native review and whole source/raster texelquad floor binding before final adoption.'],actor_approvals_added=0,game_clips_adopted=0)
p=D/'actual-NE-DEATH-six-source-contract-v04.json';p.write_text(json.dumps(contract,indent=2)+'\n');print(json.dumps(dict(contract=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),actual_poses=len(rows),strong_counts=[len(r['strong_components'])for r in rows],boundary_contacts=[r['storage_boundary_alpha_contact']for r in rows])))
