from pathlib import Path
import json,math,hashlib
import numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import label,binary_dilation
from scipy.spatial.transform import Rotation,Slerp
B=Path(__file__).parent;D=B/'actual-N-death-six-native-v05';D.mkdir();N=1536;P=128;CAM=.45;ROOTY=917.6920531878804;BONE=187.5
SRC=Path('/workspace/scratch/mythic413-N-walk-load-author-fresh-20261020-v01/actual-N-skin-joint-finish-v05/N-contact0-native-skin-joint-finished-v05.png');assert hashlib.sha256(SRC.read_bytes()).hexdigest()=='1bc3bfac78376f3d76669306d39c89bc54698f05c0f559b3833f15680910eb47';src=Image.open(SRC).convert('RGBA')
RUND=Path('/workspace/scratch/mythic413-N-run-author-fresh-20261020-v01/actual-six-native-articulation-v08')
HH=Path('/workspace/scratch/mythic413-N-walk-load-author-fresh-20261020-v01/N-native-rig-and-material-handoff-for-RUN-v01');h=json.loads((HH/'N-RUN-actual-native-rig-source-material-handoff-v01.json').read_text());sources={}
for e in h['files']:
 p=Path(e['path']);assert hashlib.sha256(p.read_bytes()).hexdigest()==e['sha256'];sources[p.name]=Image.open(p).convert('RGBA')
def blank():return Image.new('RGBA',(N,N))
def native(im):
 out=blank();out.paste(im,(P,P));return out
def selected(im,poly):
 m=Image.new('L',im.size);ImageDraw.Draw(m).polygon(poly,fill=255);a=np.array(im);a[:,:,3]=np.minimum(a[:,:,3],np.array(m));a[a[:,:,3]==0,:3]=0;return Image.fromarray(a)
def union(*ims):
 a=np.zeros((1254,1254,4),np.uint8)
 for im in ims:
  q=np.array(im);take=q[:,:,3]>a[:,:,3];a[take]=q[take]
 return Image.fromarray(a)
def proj(p):return np.array([p[0],ROOTY+CAM*p[1]-p[2]])
def rig_axes(pitch,roll=0):
 t=math.radians(pitch);r=math.radians(roll);return np.array([math.cos(r),0,math.sin(r)]),np.array([math.sin(r)*math.cos(t),math.sin(t),-math.cos(r)*math.cos(t)])
def affine_plane(im,source_anchor,world_anchor,U,V):
 M=np.array([[U[0],V[0]],[CAM*U[1]-U[2],CAM*V[1]-V[2]]]);assert abs(np.linalg.det(M))>.04;inv=np.linalg.inv(M);srca=np.array(source_anchor)+P;ta=proj(world_anchor)+P;cc=srca-inv@ta
 return im.transform((N,N),Image.Transform.AFFINE,(float(inv[0,0]),float(inv[0,1]),float(cc[0]),float(inv[1,0]),float(inv[1,1]),float(cc[1])),resample=Image.Resampling.BICUBIC)
def affine_bone(im,sa,sb,ta,tb,parity=1):
 sa=np.array(sa)+P;sb=np.array(sb)+P;ta=np.array(ta)+P;tb=np.array(tb)+P;sv=sb-sa;tv=tb-ta;sl=np.linalg.norm(sv);tl=np.linalg.norm(tv);sn=np.array([-sv[1],sv[0]])/sl;tn=np.array([-tv[1],tv[0]])/tl;M=np.outer(sv,tv)/(tl*tl)+parity*np.outer(sn,tn);cc=sa-M@ta
 return im.transform((N,N),Image.Transform.AFFINE,(float(M[0,0]),float(M[0,1]),float(cc[0]),float(M[1,0]),float(M[1,1]),float(cc[1])),resample=Image.Resampling.BICUBIC)
def exact_knee(hip,ankle,knee_x):
 r1=math.sqrt(BONE**2-(knee_x-hip[0])**2);r2=math.sqrt(BONE**2-(ankle[0]-knee_x)**2);aa=np.array(hip[1:]);bb=np.array(ankle[1:]);dv=bb-aa;dd=np.linalg.norm(dv);assert abs(r1-r2)<dd<r1+r2;u=dv/dd;along=(r1*r1-r2*r2+dd*dd)/(2*dd);h=math.sqrt(max(0,r1*r1-along*along));base=aa+u*along;n=np.array([-u[1],u[0]]);opts=[np.r_[knee_x,base+h*n],np.r_[knee_x,base-h*n]];res=min(opts,key=lambda p:p[2]);assert res[2]>=10
 return res,[abs(float(np.linalg.norm(res-hip))-BONE),abs(float(np.linalg.norm(ankle-res))-BONE)]
# Independent original native LEFT cuff interface supplied by the HIT artist.
lf=Path('/workspace/scratch/mythic413-N-hit-author-20261020-v01/N-HIT-moving-LEFT-forearm-actual-curved-cuff-white-sleeve-bracer-hand-material-v08.png');assert hashlib.sha256(lf.read_bytes()).hexdigest()=='9e81ea69efe5ca3e4d3c07e02535fbdbf10acc3e47915947b5122ad862798d7b'
leftfore=Image.open(lf).convert('RGBA');bluep=lf.with_name('N-HIT-fixed-original-curved-blue-uppercuff-matte-v08.png');assert hashlib.sha256(bluep.read_bytes()).hexdigest()=='d5fa8fc5b44c1f6b3dbcd6e51e82c8b5b3fe3d6be5867a49b3e53550bc0455a0';bm=np.array(Image.open(bluep));ba=np.array(src);ba[:,:,3]=np.minimum(ba[:,:,3],bm)
leftupper=union(selected(src,[(558,407),(594,417),(588,461),(569,504),(579,519),(554,527),(531,518),(527,493),(541,454)]),Image.fromarray(ba))
# Right coat is genuine blue/gold fabric, never a shaft or old boot patch.
rightcoatpoly=[(682,552),(709,561),(741,604),(770,642),(806,686),(840,733),(879,779),(876,789),(859,791),(836,782),(814,780),(789,789),(771,800),(749,782),(728,742),(710,697),(697,659),(683,633),(675,596)]
rightcoat=selected(src,rightcoatpoly);coatguard=np.array(rightcoat)[:,:,3]>0
rightupper=selected(src,[(698,402),(727,411),(746,434),(754,457),(775,464),(777,484),(767,505),(749,521),(729,508),(714,483),(705,450),(697,426)])
rightfore=selected(src,[(744,490),(763,488),(776,467),(790,450),(792,440),(812,441),(820,454),(820,477),(809,500),(801,517),(780,537),(762,547),(741,540),(728,526),(727,511)])
weaponupper=selected(src,[(789,138),(814,138),(821,219),(843,254),(867,275),(835,292),(820,311),(835,336),(850,358),(836,390),(821,414),(816,443),(790,450),(782,422),(769,405),(753,380),(749,353),(775,326),(784,307),(777,293),(735,278),(772,252),(785,217)])
weaponshaft=selected(src,[(792,436),(813,436),(813,668),(806,679),(798,669),(792,663)])
weaponlower=selected(src,[(789,788),(805,783),(814,791),(817,797),(828,806),(820,818),(814,831),(828,849),(831,868),(820,888),(826,908),(811,957),(807,978),(795,978),(781,941),(771,908),(774,886),(781,870),(770,850),(772,829),(776,819),(770,807),(782,797)])
# This exact actual native coat matte protects the occluding original hem.
for name in ['weaponshaft','weaponlower']:
 ar=np.array(locals()[name]);ar[coatguard]=0;locals()[name]=Image.fromarray(ar)
weaponvisible=union(weaponupper,weaponshaft,weaponlower)
# Newly painted continuous hidden shaft is actual native gold shaft material;
# restore only the genuine missing occluded middle, diameter unchanged.
weaponfull=Image.new('RGBA',src.size);shaftpatch=src.crop((793,548,813,641)).resize((20,374),Image.Resampling.BICUBIC);weaponfull.paste(shaftpatch,(793,434));weaponfull.alpha_composite(weaponupper);weaponfull.alpha_composite(weaponlower)
rightnode=weaponfull.copy();rightnode.alpha_composite(rightfore)
# Body starts from the exact approved RUN semantic source; source0 and WALK unchanged.
base=Image.open(RUND/'native-clean-body-RIGHTstaff.png').convert('RGBA').crop((P,P,P+1254,P+1254));arr=np.array(base);ra=np.maximum.reduce([np.array(rightupper)[:,:,3],np.array(rightfore)[:,:,3],np.array(weaponvisible)[:,:,3]]);arr[binary_dilation(ra>0,iterations=1)&~coatguard]=0;base=Image.fromarray(arr)
# Head/bun and the outside free ribbon have their own real neck articulation.
mainhead=selected(base,[(485,210),(735,210),(735,410),(485,410)])
# The real outside ribbon has a separate broad free silhouette, with a
# background gap before the LEFT shoulder. Move the ENTIRE native ribbon,
# not a narrow right-edge strip that can remain as a detached body fragment.
leftribbon=selected(src,[(440,390),(555,370),(610,340),(630,332),(651,346),(620,375),(594,393),(570,405),(552,419),(546,435),(534,451),(524,467),(520,484),(480,484),(460,458),(472,430),(494,408),(520,391)])
lu=np.array(leftupper);lu[np.array(leftribbon)[:,:,3]>0]=0;leftupper=Image.fromarray(lu)
head=union(mainhead,leftribbon);headalpha=np.array(head)[:,:,3];arr=np.array(base);rm=headalpha>0;rm[403:]=False;arr[rm]=0
# Outside ribbon is not backed by torso, remove its actual source contour.
arr[np.array(leftribbon)[:,:,3]>0]=0
# Keep the native neck/ribbon material overlap y403..410 for a closed hinge.
rcalpha=np.array(rightcoat)[:,:,3];rr=(rcalpha>0);rr[:636]=False;arr[rr]=0
# Only semantic torso+pleated hem remains in this region; diffuse background
# source alpha is not a body part and is preserved in the untouched raw input.
region=Image.new('L',src.size);ImageDraw.Draw(region).rectangle((500,350,754,671),fill=255);arr[:,:,3]=np.minimum(arr[:,:,3],np.array(region));arr[arr[:,:,3]==0,:3]=0;body=Image.fromarray(arr)
leftcoat=Image.open(RUND/'native-left-coat-tail.png').convert('RGBA').crop((P,P,P+1254,P+1254))
right=sources['complete-original-native-RIGHT-leg-and-stiletto-material.png'];thigh=Image.open(RUND/'native-thigh-material.png').convert('RGBA');calf=Image.open(RUND/'native-calf-material.png').convert('RGBA');kcap=Image.open(RUND/'native-rounded-knee-leather-material.png').convert('RGBA');feet={'front':native(sources['complete-original-native-LEFT-calf-ankle-and-full-shoe-material.png']),'back':native(sources['complete-original-native-RIGHT-calf-ankle-and-full-shoe-material.png'])}
materials={'head-bun-outside-ribbon':head,'body-native-bodice-pleated-skirt':body,'LEFT-complete-curved-forearm-hand':leftfore,'LEFT-upperarm-native-curved-cuff':leftupper,'RIGHT-upperarm':rightupper,'RIGHT-complete-forearm-grip-full-restored-staff':rightnode,'RIGHT-actual-original-visible-staff-semantic':weaponvisible,'RIGHT-actual-restored-full-shaft-and-both-ends':weaponfull,'LEFT-coat':leftcoat,'RIGHT-coat':rightcoat}
for name,im in materials.items():im.save(D/('native-'+name+'.png'))
def cloth_surface(im,source_root,rootworld,angle):
 # Actual cloth arc length: a free hanging strip meets one fixed floor, then
 # drapes along it. The original transverse UV and gold patterns are retained.
 t=math.radians(angle);co=math.cos(t);si=math.sin(t);ys=np.arange(1254,dtype=float);s=ys-source_root[1];floor=10.;hit=max(0.,(rootworld[2]-floor)/max(co,1e-6));z=np.where(s<=hit,rootworld[2]-co*s,floor);dep=np.where(s<=hit,rootworld[1]+si*s,rootworld[1]+si*hit+(s-hit));ty=ROOTY+CAM*dep-z+P;assert np.all(np.diff(ty)>0)
 # A rowwise inverse map samples real native RGBA and is transparent outside.
 tx=rootworld[0]-source_root[0]+P;mesh=[]
 for oy in range(N):
  sy=float(np.interp(oy,ty,ys,left=-100,right=1400));sy2=float(np.interp(oy+1,ty,ys,left=-100,right=1400));mesh.append(((0,oy,N,oy+1),(-tx,sy,-tx,sy2,N-tx,sy2,N-tx,sy)))
 return im.transform((N,N),Image.Transform.MESH,mesh,resample=Image.Resampling.BICUBIC)
def bone_elbow(shoulder,dx,desired_h,length,forward=True):
 dz=desired_h-shoulder[2];rem=length*length-dx*dx-dz*dz;assert rem>0;dd=math.sqrt(rem);return np.array([shoulder[0]+dx,shoulder[1]+(dd if forward else -dd),desired_h])
# Rigid arm/staff plane interpolation, not an image affine stretch. Both bases
# are orthonormal; all weapon geometry follows exactly the same 3D rotation.
Ua=np.array([1.,0,0]);Va=np.array([0.,2*CAM/(1+CAM*CAM),(CAM*CAM-1)/(1+CAM*CAM)]);Na=np.cross(Ua,Va);baseaxes=np.column_stack([Ua,Va,Na]);Rf=np.column_stack([np.array([0.,-1,0]),np.array([1.,0,0]),np.array([0.,0,1])])@baseaxes.T;Lf=np.column_stack([np.array([0.,1,0]),np.array([-1.,0,0]),np.array([0.,0,1])])@baseaxes.T
rs=Slerp([0,1],Rotation.from_matrix(np.array([np.eye(3),Rf])));ls=Slerp([0,1],Rotation.from_matrix(np.array([np.eye(3),Lf])))
states=[dict(name='STAGGER-loss-of-balance',hip=[663,180,385],pitch=0,headpitch=0,roll=-4,foot=0,heelD=180,heelH=0,arm=.02),dict(name='BUCKLE-hips-drop',hip=[658,120,300],pitch=20,headpitch=10,roll=-8,foot=0,heelD=180,heelH=0,arm=.17),dict(name='KNEES-contact-catch',hip=[652,0,215],pitch=48,headpitch=32,roll=-10,foot=0,heelD=180,heelH=0,arm=.42),dict(name='TORSO-forward-collapse',hip=[648,-100,205],pitch=73,headpitch=55,roll=-4,foot=-50,heelD=180,heelH=70,arm=.7),dict(name='PRONE-impact-settle',hip=[650,-140,35],pitch=88,headpitch=75,roll=0,foot=-80,heelD=310,heelH=90,arm=1.),dict(name='DEAD-terminal-held',hip=[650,-150,35],pitch=90,headpitch=88,roll=-2,foot=-90,heelD=307,heelH=90,arm=1.)]
rows=[]
for ph,st in enumerate(states):
 hip=np.array(st['hip'],float);U,V=rig_axes(st['pitch'],st['roll']);at=lambda x,y:hip+U*(x-663)+V*(y-620);parts={};joints={};theta=math.radians(st['foot']);profile='front'if ph<3 else'back';gcap=1/1.035 if profile=='front'else math.cos(-math.pi/6)-CAM*math.sin(-math.pi/6);Uf=np.array([1.,0,0]);Vf=np.array([0.,-math.sin(theta),-math.cos(theta)])/gcap
 for side,sx,kx,hx in [('L',619,600,607),('R',687,718,718)]:
  hp=at(sx,620);heel=np.array([hx,st['heelD'],st['heelH']],float);ankle=heel+np.array([0,90*math.sin(theta),90*math.cos(theta)]);kne,res=exact_knee(hp,ankle,(hp[0]+ankle[0])/2 if ph>=4 else kx);p0=proj(hp);p1=proj(kne);p2=proj(ankle);par=-1 if side=='L'else 1;leg=blank();leg.alpha_composite(affine_bone(thigh,[687,631],[679,787],p0,p1,par));leg.alpha_composite(affine_bone(calf,[679,787],[678,895],p1,p2,par/(.8 if profile=='front'else 1.)));ka=p2-p1;ka=ka/np.linalg.norm(ka);leg.alpha_composite(affine_bone(kcap,[679,787],[679,809],p1,p1+22*ka,par));sh=[616.5,850]if profile=='front'else[680,1032];mirror=side=='R'if profile=='front'else side=='L';fU=Uf*(-1 if mirror else 1);leg.alpha_composite(affine_plane(feet[profile],sh,heel,fU,Vf));parts[side]=leg;leg.save(D/f'N-death-phase{ph}-{side}-actual-leg-and-whole-boot.png');joints[side]=dict(hip=hp.tolist(),knee=kne.tolist(),ankle=ankle.tolist(),heel=heel.tolist(),bone_residuals=res,footprofile=profile,paired_part_mirror=mirror,foot_pitch=st['foot'])
 torso=affine_plane(native(body),[663,620],hip,U,V);neck=at(642,397);Uh,Vh=rig_axes(st['headpitch'],st['roll']);headposed=affine_plane(native(head),[642,397],neck,Uh,Vh)
 Rm=rs([st['arm']]).as_matrix()[0];Lm=ls([st['arm']]).as_matrix()[0];RU,RV=Rm@Ua,Rm@Va;LU,LV=Lm@Ua,Lm@Va
 sr=at(715,431);sl=at(574,433)
 if ph<2:
  er=at(748,520);el=at(556,523)
 else:
  # Actual upperarm bones retain their source lengths while elbows reach floor.
  er=bone_elbow(sr,33.,max(12.,sr[2]-85.),math.hypot(33,89));el=bone_elbow(sl,-18.,max(12.,sl[2]-86.),math.hypot(18,90))
 Rarm=blank();Rarm.alpha_composite(affine_bone(native(rightupper),[715,431],[748,520],proj(sr),proj(er)));Rarm.alpha_composite(affine_plane(native(rightnode),[748,520],er,RU,RV));Larm=blank();Larm.alpha_composite(affine_bone(native(leftupper),[574,433],[556,523],proj(sl),proj(el)));Larm.alpha_composite(affine_plane(native(leftfore),[556,523],el,LU,LV))
 lcroot=at(590,628);rcroot=at(701,628);cp=max(0.,st['pitch']-[0,10,16,20,15,2][ph]);lc=cloth_surface(leftcoat,[590,628],lcroot,cp);rc=cloth_surface(rightcoat,[701,628],rcroot,cp)
 out=blank();out.alpha_composite(parts['R']);out.alpha_composite(parts['L']);out.alpha_composite(lc);out.alpha_composite(rc);out.alpha_composite(Rarm);out.alpha_composite(torso);out.alpha_composite(headposed);out.alpha_composite(Larm)
 output=D/f'N-death-phase{ph}-actual-native-v05.png';out.save(output);a=np.array(out);labs,n=label(a[:,:,3]>100);areas=np.bincount(labs.ravel());strong=[int(z)for z in areas[1:]if z>=200];rows.append(dict(phase=ph,name=st['name'],path=str(output),sha256=hashlib.sha256(output.read_bytes()).hexdigest(),bytes=output.stat().st_size,bone_joints=joints,hip=hip.tolist(),torso_pitch=st['pitch'],head_pitch=st['headpitch'],torso_roll=st['roll'],spine_length_native=187.,RIGHTarm=dict(shoulder=sr.tolist(),elbow=er.tolist(),wrist=(er+RU*55+RV*(-40)).tolist(),rigid_U=RU.tolist(),rigid_V=RV.tolist()),LEFTarm=dict(shoulder=sl.tolist(),elbow=el.tolist(),wrist=(el+LU*(-69)+LV*79).tolist(),rigid_U=LU.tolist(),rigid_V=LV.tolist()),strong_components=strong,status='ACTUAL_NEW_DEATH_ART_PENDING_SOURCE_PHYSICAL_TERMINAL_AND_GAME_QC'))
contract=dict(status='ACTUAL_DEDICATED_N_DEATH_SIX_NATIVE_SOURCE_PENDING_QC',actor='transform:413',direction='N',motion='death',fixed_C=1920,bodyunit=1.875,logical_canvas=1024,storage_canvas=[N,N],storage_translation=[P,P],common_unpadded_root=[662.8125,917.6920531878804],frames=rows,source0=dict(path=str(SRC),sha256=hashlib.sha256(SRC.read_bytes()).hexdigest()),left_curved_cuff_material=dict(path=str(lf),sha256=hashlib.sha256(lf.read_bytes()).hexdigest()),bone_lengths=[BONE,BONE],spine_length=187.,native_forearm_capture_plane=dict(U=Ua.tolist(),V=Va.tolist(),unit_isometric=True,screen_capture_identity=True,all_weapon_pixels_same_rigid_node=True),frame_duration=.125,loop=False,terminal_pose_held=True,actual_process='Dedicated 3D articulated hips/knees/ankles, separate torso/head/cuff and rigid complete RIGHTstaff nodes; original actual gold shaft material restores the previously occluded shaft. Cloth has fixed-native-arclength floor drape. No whole PNG rotation substitute, no shared/walk relabel.',limits=['Original real native surface materials are projected by chosen constructive 2.5D rigs, not a unique hidden anatomy solution.','First production candidate needs independent actual continuity, alpha connectivity, floor guard and dead terminal review; no approval claimed.'],actor_approvals_added=0,game_clips_adopted=0)
(D/'actual-N-death-six-source-contract-v05.json').write_text(json.dumps(contract,indent=2,allow_nan=False)+'\n');board=Image.new('RGB',(1140,940),'#405265');dr=ImageDraw.Draw(board)
for i,r in enumerate(rows):
 im=Image.open(r['path']).convert('RGBA').crop((190,190,1390,1310));im.thumbnail((375,415));x=(i%3)*380;y=(i//3)*470;board.paste(im,(x,y+30),im);dr.text((x+4,y+8),str(i)+' '+r['name'],fill='white')
board.save(D/'private-N-death-new-six-source-board-v05.jpg',quality=84);assert(D/'private-N-death-new-six-source-board-v05.jpg').stat().st_size<150000;print(json.dumps(dict(poses=len(rows),strongcomponents=[len(r['strong_components'])for r in rows],contract=str(D/'actual-N-death-six-source-contract-v05.json'))))
