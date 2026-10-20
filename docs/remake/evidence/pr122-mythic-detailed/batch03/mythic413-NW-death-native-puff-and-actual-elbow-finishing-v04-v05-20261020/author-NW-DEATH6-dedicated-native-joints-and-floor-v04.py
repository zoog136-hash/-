"""True NW six-phase death from its own native actor materials.

Separate pelvis, torso, head, two actual legs, arms, rigid RIGHT staff and
floor-draping cape. No N sprite flip, whole-figure rotation or C/root fitting.
The read-only N death handoff supplies the method, never the actor pixels.
"""
from pathlib import Path
import math,json,hashlib
import numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import label
from scipy.spatial.transform import Rotation,Slerp

P=Path(__file__).parent;D=P/'actual-NW-DEATH6-dedicated-native-v04';D.mkdir(exist_ok=False)
N=1536;PAD=128;ROOT=np.array([641.,1058.3]);CAM=.45;BONE=200.
M=Path('/workspace/scratch/mythic413-NW-attack-author-20261020-v01/actual-NW-ATTACK6-native-rig-v03')
BR=Path('/workspace/scratch/mythic413-NW-hit-author-20261020-v01/actual-braced-stance-v03')
R4=Path('/workspace/scratch/mythic413-NW-walk-Rload4-author-20261020-v03/Rload4-actual-stance-leg-layer-v04.png')
def pin(p):return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def blank():return Image.new('RGBA',(N,N))
def native(p):
 a=blank();a.paste(Image.open(p).convert('RGBA'),(0,0));return a
def cropalpha(a,mask):
 z=np.array(a).copy();z[:,:,3][~mask]=0;z[z[:,:,3]==0,:3]=0;return Image.fromarray(z)
yy,xx=np.indices((N,N),dtype=float)
def poly(q):
 a=Image.new('L',(N,N));ImageDraw.Draw(a).polygon(q,fill=255);return np.array(a)>0
def union(*ims):
 a=np.zeros((N,N,4),np.uint8)
 for im in ims:
  q=np.array(im);take=q[:,:,3]>a[:,:,3];a[take]=q[take]
 return Image.fromarray(a)
core=native(M/'actual-native-head-torso-skirt-coat-old-arms-legs-staff-removed-INPUT.png')
farcoatmask=poly([(744,605),(815,615),(949,671),(1057,815),(1073,939),(985,988),(894,955),(816,861),(770,779)])
farcoat=cropalpha(core,farcoatmask)
head=cropalpha(core,(yy<434)&(xx<810))
torso=cropalpha(core,(yy>=420)&(yy<=607)&~farcoatmask)
pelvis=cropalpha(core,(yy>=576)&(yy<734)&~farcoatmask)
lu=native(M/'actual-original-NW-LEFT-upper-arm-material.png');lf=native(M/'actual-original-NW-LEFT-forearm-hand-material.png')
ru=native(M/'actual-original-NW-RIGHT-upper-arm-material.png');rf=native(M/'actual-original-NW-RIGHT-forearm-hand-material.png')
staff=native(M/'actual-original-NW-complete-rigid-RIGHT-staff-material.png');rightnode=union(rf,staff)
lt=native(BR/'LEFT-thigh-material.png');rt=native(BR/'RIGHT-thigh-material.png')
leftboot=native(BR/'LEFT-continuous-calf-and-complete-flat-shoe-material.png')
rightboot=native(R4)
legdefs={
 'LEFT':dict(thigh=lt,boot=leftboot,hip=[612,706],thighknee=[563,808],knee=[579,850],ankle=[631,972],heel=[625.3543188022422,1044.2188869220179],initial_heel=[514.3543188022422,944.2188869220179],knee_x=554),
 'RIGHT':dict(thigh=rt,boot=rightboot,hip=[670,716],thighknee=[704,851],knee=[678.4843188022421,760.538886922018],ankle=[705,969],heel=[705.4843188022421,1014.538886922018],initial_heel=[704.4843188022421,1115.538886922018],knee_x=700)}
def boundbone(a,sa,sb,before=7,after=8):
 sa=np.array(sa,float);sb=np.array(sb,float);u=(sb-sa)/np.linalg.norm(sb-sa);t=(xx-sa[0])*u[0]+(yy-sa[1])*u[1]
 return cropalpha(a,(t>=-before)&(t<=np.linalg.norm(sb-sa)+after))
for side,z in legdefs.items():
 k=np.array(z['knee']);a=np.array(z['ankle']);ay=a[1]
 z['thigh']=boundbone(z['thigh'],z['hip'],z['thighknee'])
 z['calf']=boundbone(cropalpha(z['boot'],(yy>=k[1]-18)&(yy<=ay+8)),z['knee'],z['ankle'])
 # Every old calf-shaft texel above the real ankle belongs to calf, not rigid
 # foot. Preserve complete counter/stiletto on foot plus genuine overlap cap.
 z['foot']=cropalpha(z['boot'],yy>=ay-7)
 z['counter_foreground']=cropalpha(z['boot'],yy>=ay+16)
 z['kneecap']=cropalpha(z['boot'],((xx-k[0])/21)**2+((yy-k[1])/18)**2<=1)
 z['anklecap']=cropalpha(z['boot'],((xx-a[0])/20)**2+((yy-a[1])/22)**2<=1)
RIGHT_shoulderpad=cropalpha(ru,yy<=507)
ru=cropalpha(ru,yy>=493)
LEFT_shoulderpad=cropalpha(lu,yy<=487)
lu=cropalpha(lu,yy>=469)
ru=boundbone(ru,[704,485],[736,520],10,8);lu=boundbone(lu,[589,458],[553,531],10,8)
materials=dict(RIGHT_real_proximal_shoulderpad=RIGHT_shoulderpad,LEFT_real_proximal_shoulderpad=LEFT_shoulderpad,head_bun_original_ribbon=head,actual_torso_corset=torso,actual_pelvis_pleated_skirt=pelvis,actual_far_blue_gold_coat=farcoat,LEFT_upper=lu,LEFT_forearm_complete_glove=lf,RIGHT_upper=ru,RIGHT_forearm_full_rigid_staff=rightnode)
for side,z in legdefs.items():
 for key in ['thigh','calf','foot','counter_foreground','kneecap','anklecap']:materials[side+'_'+key]=z[key]
for name,a in materials.items():a.save(D/f'actual-original-NW-{name}-material.png')
def proj(p):return np.array([p[0],ROOT[1]+CAM*p[1]-p[2]])
def axes(pitch,roll,yaw):
 r=Rotation.from_euler('z',yaw,degrees=True)*Rotation.from_euler('y',roll,degrees=True)*Rotation.from_euler('x',pitch,degrees=True)
 return r.apply([1.,0,0]),r.apply([0.,0,-1.])
surface_records=[]
def plane(im,sa,ta,U,V,name):
 sa=np.array(sa,float);ta=np.array(ta,float);U=np.array(U,float);V=np.array(V,float)
 A=np.array([[U[0],V[0]],[CAM*U[1]-U[2],CAM*V[1]-V[2]]]);assert abs(np.linalg.det(A))>.004,(name,A)
 inv=np.linalg.inv(A);off=sa-inv@(proj(ta)+PAD)
 out=im.transform((N,N),Image.Transform.AFFINE,(inv[0,0],inv[0,1],off[0],inv[1,0],inv[1,1],off[1]),Image.Resampling.BICUBIC)
 z=np.array(im);y,x=np.where(z[:,:,3]>0);height=ta[2]+U[2]*(x-sa[0])+V[2]*(y-sa[1])
 surface_records.append(dict(name=name,source_anchor=sa.tolist(),world_anchor=ta.tolist(),U=U.tolist(),V=V.tolist(),source_alpha_nonzero_pixels=int(len(x)),actual_source_texel_min_Z=float(height.min())if len(x)else None,raster_support_guard_min_Z=float(height.min()-1.5*(abs(U[2])+abs(V[2])))if len(x)else None,projected_matrix=A.tolist()))
 return out
def bone(im,sa,sb,ta,tb,name):
 sa=np.array(sa,float);sb=np.array(sb,float);ta=np.array(ta,float);tb=np.array(tb,float);sv=sb-sa;sl=np.linalg.norm(sv);u=sv/sl;n=np.array([-u[1],u[0]]);T=(tb-ta)/sl
 along=tb-ta;cross=np.array([-along[1],along[0],0.]);cross/=np.linalg.norm(cross)
 U=T*u[0]+cross*n[0];V=T*u[1]+cross*n[1]
 return plane(im,sa,ta,U,V,name)
def knee_at_x(hip,ankle,xhint):
 r1=math.sqrt(BONE**2-(xhint-hip[0])**2);r2=math.sqrt(BONE**2-(ankle[0]-xhint)**2);a=hip[1:];b=ankle[1:];delta=b-a;dist=np.linalg.norm(delta);assert abs(r1-r2)<dist<r1+r2,(r1,r2,dist)
 u=delta/dist;t=(r1*r1-r2*r2+dist*dist)/(2*dist);h=math.sqrt(max(0,r1*r1-t*t));base=a+t*u;n=np.array([-u[1],u[0]])
 candidates=[np.r_[xhint,base+h*n],np.r_[xhint,base-h*n]];valid=[z for z in candidates if z[2]>=24]
 assert valid;return min(valid,key=lambda z:z[2])
def knee_on_floor(hip,ankle,side):
 kz=24.;r1=math.sqrt(BONE**2-(hip[2]-kz)**2);r2=math.sqrt(BONE**2-(ankle[2]-kz)**2);delta=ankle[:2]-hip[:2];dist=np.linalg.norm(delta);assert abs(r1-r2)<dist<r1+r2,(side,r1,r2,dist)
 u=delta/dist;t=(r1*r1-r2*r2+dist*dist)/(2*dist);h=math.sqrt(max(0,r1*r1-t*t));base=hip[:2]+u*t;n=np.array([-u[1],u[0]])
 zs=[np.r_[base+h*n,kz],np.r_[base-h*n,kz]];return min(zs,key=lambda z:z[0])if side=='LEFT'else max(zs,key=lambda z:z[0])
Ua=np.array([1.,0,0]);Va=np.array([0.,2*CAM/(1+CAM*CAM),(CAM*CAM-1)/(1+CAM*CAM)]);Na=np.cross(Ua,Va);baseaxes=np.column_stack([Ua,Va,Na])
yawfinal=-math.degrees(math.atan(.5));Ug,Vg=axes(90,0,yawfinal)
rightfinal=np.column_stack([Ug,Vg,np.cross(Ug,Vg)]);leftfinal=np.column_stack([Ug,-Vg,np.cross(Ug,-Vg)])
rs=Slerp([0,1],Rotation.from_matrix([np.eye(3),rightfinal@baseaxes.T]));ls=Slerp([0,1],Rotation.from_matrix([np.eye(3),leftfinal@baseaxes.T]))
states=[
 dict(name='STAGGER0',hip=[641,0,352.3],pelvis=0,torso=0,head=0,roll=-3,yaw=0,foot_pitch=0,arm=.015),
 dict(name='BUCKLE1',hip=[632,-20,280],pelvis=12,torso=22,head=12,roll=-6,yaw=-5,foot_pitch=0,arm=.16),
 dict(name='KNEES2',hip=[615,-60,190],pelvis=30,torso=48,head=32,roll=-9,yaw=-12,foot_pitch=0,arm=.42),
 dict(name='COLLAPSE3',hip=[594,-100,150],pelvis=58,torso=75,head=60,roll=-4,yaw=-20,foot_pitch=55,arm=.72),
 dict(name='IMPACT4',hip=[566,-145,35],pelvis=88,torso=88,head=82,roll=0,yaw=yawfinal,foot_pitch=85,arm=1.),
 dict(name='HELD_DEAD5',hip=[558,-150,30],pelvis=90,torso=90,head=90,roll=0,yaw=yawfinal,foot_pitch=90,arm=1.)]
def cloth(im,source_root,rootworld,pitch,yaw,name):
 U,V=axes(pitch,0,yaw);floor=10.;hit=max(0.,(rootworld[2]-floor)/max(-V[2],1e-8));cut=source_root[1]+hit
 upper=cropalpha(im,yy<=cut);lower=cropalpha(im,yy>cut);a=plane(upper,source_root,rootworld,U,V,name+'_hanging')
 if not lower.getchannel('A').getbbox():return a
 floorroot=rootworld+V*hit;floorroot[2]=floor;Vflat=np.array([V[0],V[1],0.]);Vflat/=np.linalg.norm(Vflat)
 a.alpha_composite(plane(lower,[source_root[0],cut],floorroot,U,Vflat,name+'_floor_drape'));return a
rows=[]
for phase,st in enumerate(states):
 surface_records=[];hip=np.array(st['hip'],float);Up,Vp=axes(st['pelvis'],st['roll'],st['yaw']);Ut,Vt=axes(st['torso'],st['roll'],st['yaw']);Uh,Vh=axes(st['head'],st['roll'],st['yaw'])
 pelvic_at=lambda p:hip+Up*(p[0]-641)+Vp*(p[1]-706)
 waist=pelvic_at([625,584]);torso_at=lambda p:waist+Ut*(p[0]-625)+Vt*(p[1]-584)
 neck=torso_at([628,422]);pels=plane(pelvis,[641,706],hip,Up,Vp,'pelvis_skirt');tors=plane(torso,[625,584],waist,Ut,Vt,'torso_corset');hd=plane(head,[628,422],neck,Uh,Vh,'head_bun_ribbon')
 legs={};joints={};footU,footV=axes(st['foot_pitch'],0,st['yaw'])
 for side,z in legdefs.items():
  hp=pelvic_at(z['hip']);sourceheel=np.array(z['heel']);sourceankle=np.array(z['ankle'])
  if phase<3:
   h=z['initial_heel'];heel=np.array([h[0],(h[1]-ROOT[1]+6.)/CAM,6.])
  elif phase==3:heel=np.array([600,80,30])if side=='LEFT'else np.array([780,190,35])
  elif phase==4:heel=np.array([680,110,24])if side=='LEFT'else np.array([805,190,24])
  else:heel=np.array([700,130,20])if side=='LEFT'else np.array([820,200,20])
  ankle=heel+footU*(sourceankle[0]-sourceheel[0])+footV*(sourceankle[1]-sourceheel[1])
  kne=knee_at_x(hp,ankle,z['knee_x'])if phase<2 else knee_on_floor(hp,ankle,side)
  leg=blank();leg.alpha_composite(plane(z['foot'],z['heel'],heel,footU,footV,side+'_complete_foot'))
  leg.alpha_composite(bone(z['thigh'],z['hip'],z['thighknee'],hp,kne,side+'_thigh'))
  leg.alpha_composite(bone(z['calf'],z['knee'],z['ankle'],kne,ankle,side+'_actual_calf_shaft'))
  leg.alpha_composite(bone(z['kneecap'],z['knee'],z['ankle'],kne,ankle,side+'_actual_kneecap'))
  leg.alpha_composite(bone(z['anklecap'],z['knee'],z['ankle'],kne,ankle,side+'_actual_anklecap'))
  leg.alpha_composite(plane(z['counter_foreground'],z['heel'],heel,footU,footV,side+'_counter_stiletto_foreground'));legs[side]=leg
  joints[side]=dict(hip=hp.tolist(),knee=kne.tolist(),ankle=ankle.tolist(),heel=heel.tolist(),bone_lengths=[float(np.linalg.norm(hp-kne)),float(np.linalg.norm(kne-ankle))],source_controls_are_approximate=True)
 RM=rs([st['arm']]).as_matrix()[0];LM=ls([st['arm']]).as_matrix()[0];RU,RV=RM@Ua,RM@Va;LU,LV=LM@Ua,LM@Va
 sr=torso_at([704,485]);sl=torso_at([589,458])
 if phase<2:er=torso_at([736,520]);el=torso_at([553,531])
 else:
  def elbow(s,dx,drop,length,forward):
   z=max(20.,s[2]-drop);rem=length*length-dx*dx-(z-s[2])**2;assert rem>0
   return s+np.array([dx,math.sqrt(rem)*(1 if forward else -1),z-s[2]])
  er=elbow(sr,20,32,math.hypot(32,35),True);el=elbow(sl,-25,65,math.hypot(36,73),False)
 rarm=plane(RIGHT_shoulderpad,[704,485],sr,Ut,Vt,'RIGHT_real_proximal_shoulderpad');rarm.alpha_composite(bone(ru,[704,485],[736,520],sr,er,'RIGHT_upper_arm'));rarm.alpha_composite(plane(rightnode,[736,520],er,RU,RV,'RIGHT_forearm_full_rigid_staff'))
 larm=plane(LEFT_shoulderpad,[589,458],sl,Ut,Vt,'LEFT_real_proximal_shoulderpad');larm.alpha_composite(bone(lu,[589,458],[553,531],sl,el,'LEFT_upper_arm'));larm.alpha_composite(plane(lf,[553,531],el,LU,LV,'LEFT_complete_forearm_glove'))
 coatroot=pelvic_at([775,650]);coat=cloth(farcoat,[775,650],coatroot,max(0,st['pelvis']-[0,8,15,20,20,20][phase]),st['yaw'],'far_blue_gold_coat')
 out=blank();out.alpha_composite(legs['RIGHT']);out.alpha_composite(legs['LEFT']);out.alpha_composite(coat);out.alpha_composite(rarm);out.alpha_composite(pels);out.alpha_composite(tors);out.alpha_composite(hd);out.alpha_composite(larm)
 f=D/f'thunder_female-NW-DEATH-{phase}-{st["name"]}-actual-native-v04.png';out.save(f)
 az=np.array(out);cc,n=label(az[:,:,3]>=100);sz=np.bincount(cc.ravel());comps=[]
 for k in np.flatnonzero(sz>=200):
  if k:
   y,x=np.where(cc==k);comps.append(dict(pixels=int(sz[k]),bbox=[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]))
 floor_mins=[z['raster_support_guard_min_Z']for z in surface_records if z['raster_support_guard_min_Z']is not None]
 rows.append(dict(phase=phase,name=st['name'],**pin(f),state=st,leg_world_joints=joints,RIGHT_arm=dict(shoulder=sr.tolist(),elbow=er.tolist(),grip=(er+RU*(819-736)+RV*(432-520)).tolist(),rigid_U=RU.tolist(),rigid_V=RV.tolist()),LEFT_arm=dict(shoulder=sl.tolist(),elbow=el.tolist()),actual_material_surfaces=surface_records,minimum_actual_surface_raster_guard_Z=min(floor_mins),strong_components_alpha100_4conn_gte200=comps,quality='PENDING_INDEPENDENT_ACTUAL_SOURCE_CYCLE_AND_FLOOR_QC'))
contract=dict(status='ACTUAL_NEW_NW_DEATH6_NATIVE_JOINTED_FALL_PENDING_INDEPENDENT_SOURCE_CYCLE_FLOOR_QC',actor_id=413,direction='NW',action='death',loop=False,physical_canvas_fixed=2048,body_unit_fixed=2,logical_canvas=1024,common_unpadded_root=ROOT.tolist(),storage_translation=[PAD,PAD],storage_canvas=[N,N],frame_duration=.8/6,runtime_death_duration=.8,resource_role_seconds=.65,resource_role_fps=6/.65,terminal_held=True,profile_or_fade_modified=False,new_services=0,new_author_images=0,actor_approval_added=0,method_source_readonly=pin(Path('/workspace/scratch/mythic413-N-death-author-20261020-v01/author-N-death-dedicated-native-six-v09.py')),material_inputs=[pin(M/'actual-native-head-torso-skirt-coat-old-arms-legs-staff-removed-INPUT.png'),pin(R4),pin(BR/'LEFT-continuous-calf-and-complete-flat-shoe-material.png')],camera_depth=.45,constant_true_leg_length_native_world=200,original_assets_modified=False,frames=rows)
c=D/'NW-DEATH-six-actual-native-source-common-root-and-floor-contract-v04.json';c.write_text(json.dumps(contract,indent=2)+'\n')
print(json.dumps(dict(contract=pin(c),frames=len(rows),components=[len(z['strong_components_alpha100_4conn_gte200'])for z in rows],floor_guard_minima=[round(z['minimum_actual_surface_raster_guard_Z'],4)for z in rows],actor_approval_added=0)))
