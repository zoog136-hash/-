from pathlib import Path
import json,math,hashlib
import numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import map_coordinates,label
from scipy.spatial.transform import Rotation
B=Path(__file__).parent;D=B/'actual-N-IDLE-six-native-v02';D.mkdir();N=1536;P=128;CAM=.45;ROOTY=917.6920531878804
manifest=B/'N-IDLE-actual-native-used-inputs-frozen-v02.json';m=json.loads(manifest.read_text());images={}
for e in m['files']:
 p=Path(e['path']);assert hashlib.sha256(p.read_bytes()).hexdigest()==e['sha256'];images[p.name]=Image.open(p).convert('RGBA')
def blank():return Image.new('RGBA',(N,N))
def native(im):
 q=blank();q.paste(im,(P,P));return q
def proj(p):return np.array([p[0],ROOTY+CAM*p[1]-p[2]])
def selected(im,poly):
 mask=Image.new('L',im.size);ImageDraw.Draw(mask).polygon(poly,fill=255);a=np.array(im);a[:,:,3]=np.minimum(a[:,:,3],np.array(mask));a[a[:,:,3]==0,:3]=0;return Image.fromarray(a)
def plane(im,sa,wa,U,V):
 M=np.array([[U[0],V[0]],[CAM*U[1]-U[2],CAM*V[1]-V[2]]]);inv=np.linalg.inv(M);co=np.array(sa)+P-inv@(proj(wa)+P);return im.transform((N,N),Image.Transform.AFFINE,(inv[0,0],inv[0,1],co[0],inv[1,0],inv[1,1],co[1]),resample=Image.Resampling.BICUBIC)
def affine_bone(im,sa,sb,ta,tb,parity=1):
 sa=np.array(sa)+P;sb=np.array(sb)+P;ta=np.array(ta)+P;tb=np.array(tb)+P;sv=sb-sa;tv=tb-ta;sl=np.linalg.norm(sv);tl=np.linalg.norm(tv);sn=np.array([-sv[1],sv[0]])/sl;tn=np.array([-tv[1],tv[0]])/tl;M=np.outer(sv,tv)/(tl*tl)+parity*np.outer(sn,tn);co=sa-M@ta;return im.transform((N,N),Image.Transform.AFFINE,(M[0,0],M[0,1],co[0],M[1,0],M[1,1],co[1]),resample=Image.Resampling.BICUBIC)
def exact_knee(hip,ankle,kx):
 L=187.5;r1=math.sqrt(L*L-(kx-hip[0])**2);r2=math.sqrt(L*L-(ankle[0]-kx)**2);aa=hip[1:];bb=ankle[1:];dv=bb-aa;dd=np.linalg.norm(dv);assert dd<r1+r2;un=dv/dd;al=(r1*r1-r2*r2+dd*dd)/(2*dd);hh=math.sqrt(r1*r1-al*al);ba=aa+un*al;no=np.array([-un[1],un[0]]);opts=[np.r_[kx,ba+hh*no],np.r_[kx,ba-hh*no]];return min(opts,key=lambda q:q[1])
def smooth01(a):
 z=np.clip(a,0,1);return z*z*(3-2*z)
def breath_displacement(x,y,b):
 wy=np.exp(-((y-477)/75)**4)*smooth01((585-y)/25)*smooth01((y-400)/40);braced=1-smooth01((x-688)/27);dx=(x-663)/70*3.8*b*wy*braced;dy=-4.2*b*wy*braced;return dx,dy
def warp_surface(im,displace):
 a=np.array(im);height,width=a.shape[:2];ty,tx=np.mgrid[:height,:width].astype(float);sx=tx.copy();sy=ty.copy()
 for k in range(5):dx,dy=displace(sx,sy);sx=tx-dx;sy=ty-dy
 coords=np.array([sy,sx]);q=np.stack([map_coordinates(a[:,:,c],coords,order=1,mode='constant',cval=0,prefilter=False)for c in range(4)],axis=-1).astype(np.uint8);q[q[:,:,3]==0,:3]=0;return Image.fromarray(q)
def pbody(x,y,b):
 dx,dy=breath_displacement(np.array(float(x)),np.array(float(y)),b);return np.array([float(x+dx),float(y+dy)])
body=images['native-body-native-bodice-pleated-skirt.png'];fullhead=images['native-head-bun-outside-ribbon.png'];leftupper=images['native-LEFT-upperarm-native-curved-cuff.png'];fore=images['native-LEFT-complete-curved-forearm-hand.png'];rightupper=images['native-RIGHT-upperarm.png'];rightnode=images['native-RIGHT-complete-forearm-grip-full-restored-staff.png'];leftcoat=images['native-LEFT-coat.png'];rightcoat=images['native-RIGHT-coat.png'];thigh=images['native-thigh-material.png'];calf=images['native-calf-material.png'];kcap=images['native-rounded-knee-leather-material.png'];foot=images['complete-original-native-LEFT-calf-ankle-and-full-shoe-material.png']
# Free outside ribbon really exists left of the original shoulder. Its root
# overlaps six native rows; torso/hair source art remains intact elsewhere.
ribbon=selected(fullhead,[(440,396),(590,396),(570,405),(552,419),(546,435),(534,451),(524,467),(520,484),(480,484),(460,458),(472,430),(494,408),(520,396)])
ha=np.array(fullhead);rma=np.array(ribbon)[:,:,3]>0;rma[:402]=False;ha[rma]=0;head=Image.fromarray(ha)
# The actual native flesh fingers curl at two separate original material joints.
fingers=selected(fore,[(482,628),(492,626),(504,625),(507,629),(503,635),(496,641),(487,642),(482,637)]);fa=np.array(fore);mask=np.array(fingers)[:,:,3]>0;mask[:,:486]=False;fa[mask]=0;forepalm=Image.fromarray(fa)
fp=np.array(fingers);fp[:,496:]=0;prox=Image.fromarray(fp);fd=np.array(fingers);fd[:,:492]=0;dist=Image.fromarray(fd)
fm=Image.new('L',fore.size);ImageDraw.Draw(fm).ellipse((490,628,498,636),fill=255);ca=np.array(fingers);ca[:,:,3]=np.minimum(ca[:,:,3],np.array(fm));jointskin=Image.fromarray(ca)
for name,im in [('native-body-chest-bodice',body),('native-main-head-bun',head),('native-free-outside-blue-ribbon',ribbon),('native-LEFT-palm-and-forearm-with-finger-overlap',forepalm),('native-LEFT-actual-proximal-fingers',prox),('native-LEFT-actual-distal-fingers',dist),('native-LEFT-actual-finger-joint-skin',jointskin)]:im.save(D/(name+'.png'))
# Source foot730 contained an old horizontal calf crop. Reassign the shaft
# to the real knee→ankle surface; retain complete actual LEFTshoe armor/heel,
# and use its original rounded leather at the same physical ankle registration.
articulated_calf=native(images['native-original-back-boot-calf-shaft-reassigned-to-shin.png'])
back_ankle_source=1032-90*(math.cos(-math.pi/6)-CAM*math.sin(-math.pi/6))
front_ankle_source=850-90/1.035
ff=np.array(foot);ff[:756]=0;frontshoe=Image.fromarray(ff)
fg=np.array(foot);fg[:780]=0;frontforeground=Image.fromarray(fg)
am=Image.new('L',foot.size);ImageDraw.Draw(am).ellipse((601,front_ankle_source-22,649,front_ankle_source+22),fill=255);ac=np.array(foot);ac[:,:,3]=np.minimum(ac[:,:,3],np.array(am));ac[ac[:,:,3]==0,:3]=0;frontankle=Image.fromarray(ac)
for nn,ii in [('native-original-front-boot-input-preserved',foot),('native-complete-front-shoe-below-actual-ankle',frontshoe),('native-protected-original-front-counter-and-stiletto',frontforeground),('native-original-rounded-front-ankle-leather',frontankle)]:ii.save(D/(nn+'.png'))
HIP=np.array([663.,180.,385.]);U0=np.array([1.,0,0]);Vvertical=np.array([0.,0,-1]);V0=np.array([0.,2*CAM/(1+CAM*CAM),(CAM*CAM-1)/(1+CAM*CAM)]);normal=np.cross(U0,V0);sourceworld=lambda x,y:HIP+U0*(x-663)+Vvertical*(y-620)
# Neutral supported stance is a NEW fixed native rig, never a per-pose root fit.
legs=blank();legmeta={};theta=math.asin(-6.105/90.);Vf=np.array([0.,-math.sin(theta),-math.cos(theta)])/(1/1.035)
for side,sx,kx,hx in [('L',619,600,607),('R',687,718,718)]:
 hip=sourceworld(sx,620);heel=np.array([hx,180+6.105/CAM,6.105]);ankle=heel+np.array([0,90*math.sin(theta),90*math.cos(theta)]);kne=exact_knee(hip,ankle,kx);p0=proj(hip);p1=proj(kne);p2=proj(ankle);par=-1 if side=='L'else 1;leg=blank();fU=U0*(-1 if side=='R'else 1);leg.alpha_composite(plane(native(frontshoe),[616.5,850],heel,fU,Vf));leg.alpha_composite(affine_bone(thigh,[687,631],[679,787],p0,p1,par));leg.alpha_composite(affine_bone(articulated_calf,[679,787],[678,back_ankle_source],p1,p2,par/.8));ax=(p2-p1)/np.linalg.norm(p2-p1);leg.alpha_composite(affine_bone(kcap,[679,787],[679,809],p1,p1+22*ax,par));leg.alpha_composite(plane(native(frontankle),[616.5,850],heel,fU,Vf));leg.alpha_composite(plane(native(frontforeground),[616.5,850],heel,fU,Vf));leg.save(D/f'fixed-neutral-{side}-complete-native-supported-leg-and-stiletto.png');legs.alpha_composite(leg);legmeta[side]=dict(hip=hip.tolist(),knee=kne.tolist(),ankle=ankle.tolist(),heel=heel.tolist(),toe=(heel+np.array([0,-90*math.cos(theta),90*math.sin(theta)])).tolist(),bones=[float(np.linalg.norm(kne-hip)),float(np.linalg.norm(ankle-kne))])
# Braced RIGHT shoulder/hand and the complete native weapon are fixed in all6.
Rshoulder=sourceworld(715,431);Relbow=sourceworld(748,520);fixedR=blank();fixedR.alpha_composite(affine_bone(native(rightupper),[715,431],[748,520],proj(Rshoulder),proj(Relbow)));fixedR.alpha_composite(plane(native(rightnode),[748,520],Relbow,U0,Vvertical));fixedR.save(D/'fixed-RIGHTarm-grip-complete-original-gold-turquoise-staff.png');legs.save(D/'fixed-supported-neutral-both-legs.png')
rows=[]
for ph in range(6):
 t=2*math.pi*ph/6;b=.5-.5*math.cos(t);bodyposed=warp_surface(body,lambda x,y:breath_displacement(x,y,b));bodyr=plane(native(bodyposed),[663,620],HIP,U0,Vvertical)
 neckxy=pbody(642,397,b);neck=sourceworld(*neckxy);headphi=.6*(math.sin(t-.7)-math.sin(-.7));rot=Rotation.from_rotvec(normal*(-math.radians(headphi))).as_matrix();HU=rot@U0;HV=rot@V0;headr=plane(native(head),[642,397],neck,HU,HV)
 hdx=3.5*(math.sin(t-1.3)-math.sin(-1.3));hdy=1.2*(math.sin(t-.3)-math.sin(-.3));hair=warp_surface(ribbon,lambda x,y:(hdx*smooth01((y-398)/86)**2,hdy*smooth01((y-398)/86)**2));hairr=plane(native(hair),[642,397],neck,HU,HV)
 shouldersrc=pbody(574,433,b);shoulder=sourceworld(*shouldersrc);upperphi=1.1*math.sin(t);ru=Rotation.from_rotvec(np.array([0.,1.,0])*math.radians(upperphi)).as_matrix();elbow=shoulder+ru@np.array([-18.,0,-90.]);forephi=1.4*(math.sin(t-.5)-math.sin(-.5));rf=Rotation.from_rotvec(normal*(-math.radians(forephi))).as_matrix();LU=rf@U0;LV=rf@V0
 curl1=[0,2,5,7,4,1][ph];curl2=[0,3,8,10,5,1.5][ph];hand=forepalm.copy();hand.alpha_composite(prox.rotate(curl1,resample=Image.Resampling.BICUBIC,center=(484,632)));dd=dist.rotate(curl2,resample=Image.Resampling.BICUBIC,center=(494,632));dd=dd.rotate(curl1,resample=Image.Resampling.BICUBIC,center=(484,632));hand.alpha_composite(dd);hand.alpha_composite(jointskin.rotate(curl1,resample=Image.Resampling.BICUBIC,center=(484,632)))
 Larm=blank();Larm.alpha_composite(affine_bone(native(leftupper),[574,433],[556,523],proj(shoulder),proj(elbow)));Larm.alpha_composite(plane(native(hand),[556,523],elbow,LU,LV));Larm.save(D/f'N-idle-phase{ph}-actual-LEFT-cuff-hand-articulated-finger-parts.png')
 cloth=[];clothmeta=[]
 for name,im,rooty in [('LEFT',leftcoat,628),('RIGHT',rightcoat,628)]:
  dx=5*(math.sin(t-.8)-math.sin(-.8));dy=2.4*(math.sin(t-.2)-math.sin(-.2));cl=warp_surface(im,lambda x,y:(dx*smooth01((y-rooty)/302)**2,dy*smooth01((y-rooty)/302)**2));cloth.append(plane(native(cl),[663,620],HIP,U0,Vvertical));clothmeta.append(dict(side=name,free_tip_dx=dx,free_tip_dy=dy,pinned_root_y=rooty,actual_UV_bend_not_whole_panel_rotation=True))
 out=blank();out.alpha_composite(legs);out.alpha_composite(fixedR)
 for cl in cloth:out.alpha_composite(cl)
 out.alpha_composite(bodyr);out.alpha_composite(headr);out.alpha_composite(hairr);out.alpha_composite(Larm);p=D/f'N-idle-phase{ph}-actual-native-v02.png';out.save(p);a=np.array(out);labs,n=label(a[:,:,3]>100);ar=np.bincount(labs.ravel());strong=[int(z)for z in ar[1:]if z>=200];rows.append(dict(phase=ph,path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size,seconds_range=[ph*.2,(ph+1)*.2],inhalation=b,actual_chest_transverse_amplitude=3.8*b,actual_chest_lift_amplitude=4.2*b,left_shoulder_native=shouldersrc.tolist(),neck_native=neckxy.tolist(),head_node_angle=headphi,hair_delayed_tip=[hdx,hdy],LEFTarm=dict(shoulder=shoulder.tolist(),elbow=elbow.tolist(),wrist=(elbow+LU*(-69)+LV*79).tolist(),upperbone_length=float(np.linalg.norm(elbow-shoulder)),forearm_rigid_U=LU.tolist(),forearm_rigid_V=LV.tolist(),actual_native_finger_joints=[[484,632],[494,632]],proximal_finger_degrees=curl1,distal_finger_degrees=curl2),coat=clothmeta,strong_components=strong,status='ACTUAL_NEW_DEDICATED_IDLE_BREATH_FINGER_HAIR_CLOTH_SOURCE_PENDING_QC'))
contract=dict(status='ACTUAL_DEDICATED_N_IDLE_SIX_SOURCE_PENDING_SOURCE_LOOP_PHYSICAL_AND_GAME_QC',actor='transform:413',direction='N',motion='idle',fixed_C=1920,bodyunit=1.875,common_unpadded_root=[662.8125,917.6920531878804],storage_canvas=[N,N],storage_translation=[P,P],logical_canvas=1024,cycle_seconds=1.2,phase_seconds=.2,resource_fps=5.,loop=True,profile_modified=False,frames=rows,native_boot_finish=dict(reassigned_actual_calf_source_end=back_ankle_source,front_fixed_capture_ankle=front_ankle_source,original_complete_front_shoe_from_y=756,original_goldcounter_stiletto_foreground_from_y=780,actual_original_rounded_leather_overlap=True),fixed_RIGHT_source_plane=dict(U=U0.tolist(),V=Vvertical.tolist(),same_native_2D_projection=True),exact_fixed_supported_leg_bones=legmeta,RIGHTarm_staff_fixed_raster_sha256=hashlib.sha256((D/'fixed-RIGHTarm-grip-complete-original-gold-turquoise-staff.png').read_bytes()).hexdigest(),input_manifest=dict(path=str(manifest),sha256=hashlib.sha256(manifest.read_bytes()).hexdigest()),actual_motion='Pinned pelvis and both complete supported legs; true local chest expansion/scapular lift UV, separately articulated LEFTupperarm and curved forearm with two actual flesh finger joints, independent head/blue ribbon lag and pinned-root cloth UV bend; RIGHTgrip/fullstaff stays exactly fixed. No wholeactor bob, color relabel, sharedmotion or perpose C/root heightfit.',actual_chest_UV='smooth local native ribcage deformation centered y477, zero at y585+hips and at braced RIGHTshoulder x715; same source gold/blue detail deforms continuously, actual displaced native leftshoulder anchor drives arm bone.',limits=['One constructive native material/skeleton animation; independent highquality actual source and 5→0 loop/floor/gear validation required.','Visible source surfaces and native joint positions are explicit; hidden anatomy is not uniquely recovered.'],actor_approvals_added=0,game_clips_adopted=0)
(D/'actual-N-IDLE-six-source-contract-v02.json').write_text(json.dumps(contract,indent=2,allow_nan=False)+'\n');board=Image.new('RGB',(960,1020),'#405265');dr=ImageDraw.Draw(board)
for i,r in enumerate(rows):
 im=Image.open(r['path']).convert('RGBA').crop((350,210,1050,1260));im.thumbnail((315,480));x=(i%3)*320;y=(i//3)*510;board.paste(im,(x,y+20),im);dr.text((x+6,y+4),f'{i} breath {r["inhalation"]:.2f}',fill='white')
board.save(D/'private-N-IDLE-six-real-breath-finger-source-board-v02.jpg',quality=84);assert(D/'private-N-IDLE-six-real-breath-finger-source-board-v02.jpg').stat().st_size<150000;print(json.dumps(dict(poses=6,strongcomponents=[len(r['strong_components'])for r in rows],contract=str(D/'actual-N-IDLE-six-source-contract-v02.json'))))
