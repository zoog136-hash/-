from pathlib import Path
import hashlib,json,math
from PIL import Image,ImageDraw
import numpy as np
from scipy.ndimage import label,binary_dilation

B=Path(__file__).parent
D=B/'actual-six-native-articulation-v07';D.mkdir()
H=Path('/workspace/scratch/mythic413-N-walk-load-author-fresh-20261020-v01/N-native-rig-and-material-handoff-for-RUN-v01/N-RUN-actual-native-rig-source-material-handoff-v01.json')
hb=H.read_bytes();assert hashlib.sha256(hb).hexdigest()=='257e6675357a63a8790b8a55732a1851f312a2c6a362bdd31d5a13bc62949763'
h=json.loads(hb);sources={}
for e in h['files']:
 p=Path(e['path']);b=p.read_bytes();assert hashlib.sha256(b).hexdigest()==e['sha256'];sources[p.name]=Image.open(p).convert('RGBA')
src=Image.open(h['source0']['path']).convert('RGBA');assert hashlib.sha256(Path(h['source0']['path']).read_bytes()).hexdigest()==h['source0']['sha256']
N=1536;P=128
def blank():return Image.new('RGBA',(N,N))
def torso_point(pt,angle):
 c=math.cos(math.radians(angle));q=math.sin(math.radians(angle));x,y=pt[0]-663,pt[1]-635
 return [663+c*x+q*y,635-q*x+c*y]
def native(im):
 out=blank();out.paste(im,(P,P));return out
def shift(im,dx,dy):
 out=blank();out.paste(im,(int(dx),int(dy)));return out
def selected(im,poly):
 mask=Image.new('L',im.size);ImageDraw.Draw(mask).polygon(poly,fill=255)
 a=np.array(im);a[:,:,3]=np.minimum(a[:,:,3],np.array(mask));a[a[:,:,3]==0,:3]=0
 return Image.fromarray(a)
def ypart(im,a,b):
 ar=np.array(im);ar[:a]=0;ar[b:]=0;return native(Image.fromarray(ar))
def affine_bone(im,sa,sb,ta,tb,parity=1):
 # Exact inverse affine on a SEMANTIC source surface. No longitudinal clamp:
 # outside real alpha is transparent, so an endpoint cannot extrude UV material.
 sa=np.array(sa,float)+P;sb=np.array(sb,float)+P;ta=np.array(ta,float)+P;tb=np.array(tb,float)+P
 sv=sb-sa;tv=tb-ta;sl=np.linalg.norm(sv);tl=np.linalg.norm(tv);assert sl>1 and tl>1
 sn=np.array([-sv[1],sv[0]])/sl;tn=np.array([-tv[1],tv[0]])/tl
 M=np.outer(sv,tv)/(tl*tl)+parity*np.outer(sn,tn)
 c=sa-M@ta
 return im.transform((N,N),Image.Transform.AFFINE,(float(M[0,0]),float(M[0,1]),float(c[0]),float(M[1,0]),float(M[1,1]),float(c[1])),resample=Image.Resampling.BICUBIC)
def foot(im,sourceheel,targetheel,mirror=False,pitch_scale=1.):
 # One complete foot/counter/stiletto is a rigid planar material projection.
 # Pitch changes its projection around the SAME structural heel; no redesign.
 sx,sy=np.array(sourceheel,float)+P;tx,ty=np.array(targetheel,float)+P
 parity=-1 if mirror else 1
 return im.transform((N,N),Image.Transform.AFFINE,(parity,0,float(sx-parity*tx),0,1/pitch_scale,float(sy-ty/pitch_scale)),resample=Image.Resampling.BICUBIC)

right=sources['complete-original-native-RIGHT-leg-and-stiletto-material.png']
left=sources['complete-original-native-LEFT-leg-and-stiletto-material.png']
# Source endpoints stop at the actual knee. The rounded native leather joint
# is a separate real material cap, not extrapolated endpoint UV.
thigh=ypart(right,640,788)
calf=ypart(right,787,896)
km=Image.new('L',right.size);ImageDraw.Draw(km).ellipse((651,765,707,809),fill=255)
ka=np.array(right);ka[:,:,3]=np.minimum(ka[:,:,3],np.array(km));ka[ka[:,:,3]==0,:3]=0
knee_cap=native(Image.fromarray(ka))
feet={
 'front':native(sources['complete-original-native-LEFT-calf-ankle-and-full-shoe-material.png']),
 'back':native(sources['complete-original-native-RIGHT-calf-ankle-and-full-shoe-material.png'])}
# Complete native cuff/brace shell belongs to the moving free arm. The former
# handoff omitted the curved white/gold cuff x535..578, y520..574. Its genuine
# source contour is moved, and the straight blue/gold coat edge is untouched.
forearm=native(selected(src,[(532,500),(565,507),(578,523),(576,540),(564,564),(550,579),(524,588),(504,610),(501,633),(486,655),(467,650),(464,628),(478,599),(490,576),(505,552),(516,524)]))
forearm.save(D/'native-complete-freeLEFT-forearm-cuff-hand-material.png')
Image.fromarray(np.array(forearm)[:,:,3]).save(D/'native-complete-freeLEFT-forearm-cuff-hand-semantic-matte.png')
upper=selected(src,[(558,419),(592,427),(582,470),(560,532),(528,532),(521,504),(542,455)])
upper=native(upper)
arm_alpha=np.maximum(np.array(upper)[:,:,3],np.array(forearm)[:,:,3])
body=native(sources['source0-native-body-coat-RIGHTstaff-with-complete-old-legs-removed-INPUT.png'])
ar=np.array(body);ar[binary_dilation(arm_alpha>0,iterations=1)]=0
# Canonical source-only old calf residue, independently seen in Nrun0. This
# central region is between the two real coat panels; actual new limbs are separate.
oldrem=ar[790+P:1060+P,570+P:730+P,3].copy();assert int((oldrem>16).sum())==156
ar[790+P:1060+P,570+P:730+P]=0;body=Image.fromarray(ar)
tail=selected(body.crop((P,P,P+1254,P+1254)),[(574,596),(618,596),(608,641),(589,689),(561,760),(525,840),(488,930),(350,930),(350,596)])
# The source pleated skirt/gold hem occludes the coat root and stays with torso.
protect=Image.new('L',(1254,1254));ImageDraw.Draw(protect).polygon([(603,558),(690,558),(721,617),(725,647),(695,667),(638,665),(591,653),(578,638)],fill=255)
tar=np.array(tail);tar[np.array(protect)>0]=0;tail=Image.fromarray(tar)
tail=native(tail);ta=np.array(tail)[:,:,3];ar=np.array(body);remove=(ta>0);remove[:620+P]=False;ar[remove]=0;body=Image.fromarray(ar)
for name,im in [('native-clean-body-RIGHTstaff',body),('native-freeLEFT-upperarm',upper),('native-freeLEFT-complete-forearm-hand-bracer',forearm),('native-left-coat-tail',tail),('native-thigh-material',thigh),('native-calf-material',calf),('native-rounded-knee-leather-material',knee_cap)]:im.save(D/(name+'.png'))

states=[
 dict(phase=0,name='LEFT-contact',bob=[-10,-10],L=dict(k=[615,710],heel=[616.5,850],shoe='front',mirror=False),R=dict(k=[715,740],heel=[726,764],shoe='back',mirror=False),elbow=[550,520],wrist=[511,620],tail=-4),
 dict(phase=1,name='LEFT-load-footroll',bob=[-3,35],L=dict(k=[611,803],heel=[616.5,982.8727272728626],shoe='front',mirror=False,pitch=1.035),R=dict(k=[725,656],heel=[733,858],shoe='front',mirror=True),elbow=[537,514],wrist=[495,589],tail=6),
 dict(phase=2,name='RIGHT-drive-flight',bob=[12,-48],L=dict(k=[594,719],heel=[582,742],shoe='back',mirror=True),R=dict(k=[714,612],heel=[698,812],shoe='front',mirror=True),elbow=[536,487],wrist=[520,433],tail=10),
 dict(phase=3,name='RIGHT-contact',bob=[10,-10],L=dict(k=[610,740],heel=[599,764],shoe='back',mirror=True),R=dict(k=[711,710],heel=[708.5,850],shoe='front',mirror=True),elbow=[545,475],wrist=[560,420],tail=4),
 dict(phase=4,name='RIGHT-load-footroll',bob=[3,35],L=dict(k=[600,656],heel=[592,858],shoe='front',mirror=False),R=dict(k=[714,803],heel=[708.5,982.8727272728626],shoe='front',mirror=True,pitch=1.035),elbow=[539,489],wrist=[540,450],tail=-5),
 dict(phase=5,name='LEFT-drive-flight',bob=[-12,-48],L=dict(k=[611,612],heel=[627,812],shoe='front',mirror=False),R=dict(k=[731,719],heel=[744,742],shoe='back',mirror=False),elbow=[541,513],wrist=[511,555],tail=-9),
]

# One explicit constructive N camera/rig, chosen before fitting. All six poses
# consume these constants and exact closed-form knees. No inverse depth search,
# no old WALK knee controls, no varying body units or perpose foot registration.
CAM=.45;ROOTY=917.6920531878804;BONE=187.5;FOOT=90.;ANKLE_RISE=90.
CONTACT_PITCH=math.acos((1/1.035)/math.sqrt(1+CAM*CAM))-math.atan(CAM)
def exact_knee(hip,ankle,knee_x,kind):
 r1=math.sqrt(BONE*BONE-(knee_x-hip[0])**2)
 r2=math.sqrt(BONE*BONE-(ankle[0]-knee_x)**2)
 a=np.array(hip[1:],float);b=np.array(ankle[1:],float);dv=b-a;distance=np.linalg.norm(dv)
 assert abs(r1-r2)<distance<r1+r2
 unit=dv/distance;along=(r1*r1-r2*r2+distance*distance)/(2*distance)
 height=math.sqrt(max(0.,r1*r1-along*along));normal=np.array([-unit[1],unit[0]])
 choices=[a+along*unit+sign*height*normal for sign in (-1,1)]
 point=min(choices,key=lambda t:t[1] if kind=='back' else t[0])
 result=np.array([knee_x,*point],float)
 residuals=[abs(float(np.linalg.norm(result-np.array(hip)))-BONE),abs(float(np.linalg.norm(np.array(ankle)-result))-BONE)]
 assert max(residuals)<1.e-8
 return result.tolist(),residuals
def projected(v):return [float(v[0]),float(ROOTY+CAM*v[1]-v[2])]
rows=[];bone_models=[]
for st in states:
 phase=st['phase'];bx,by=st['bob'];lean=[1.75,.5,-1.25,-1.75,-.5,1.25][phase];limbs={};joints={}
 for side in ('L','R'):
  x=st[side];mirror=x['mirror'];heel=x['heel'];pitch=x.get('pitch',1.)
  sh=[616.5,850] if x['shoe']=='front' else [680,1032]
  sa=[625,792] if x['shoe']=='front' else [678,923]
  parity=-1 if mirror else 1
  hidden=torso_point([619 if side=='L' else 687,620],lean)
  hip=[hidden[0]+bx,hidden[1]+by]
  hipdepth=40. if phase in (1,4) else 0.
  hip3=[hip[0],hipdepth,ROOTY+CAM*hipdepth-hip[1]]
  support=(phase in (0,1) and side=='L') or (phase in (3,4) and side=='R')
  if support:
   heeldepth=(heel[1]-ROOTY)/CAM;heelheight=0.
  else:
   heeldepth=180. if x['shoe']=='back' else (20. if phase in (1,4) else -100.)
   heelheight=ROOTY+CAM*heeldepth-heel[1]
  angle=(-math.pi/6) if x['shoe']=='back' else (0. if pitch>1. else CONTACT_PITCH)
  heel3=[heel[0],heeldepth,heelheight]
  toe3=[heel[0],heeldepth-FOOT*math.cos(angle),heelheight+FOOT*math.sin(angle)]
  ankle3=[heel[0],heeldepth+ANKLE_RISE*math.sin(angle),heelheight+ANKLE_RISE*math.cos(angle)]
  ankle=projected(ankle3)
  knee3,res=exact_knee(hip3,ankle3,x['k'][0],x['shoe']);kne=projected(knee3)
  assert abs(projected(heel3)[1]-heel[1])<1e-8
  assert not support or (abs(heelheight)<1.e-8 and toe3[2]>=-1.e-8)
  assert support or min(heel3[2],toe3[2],ankle3[2])>0
  model=dict(phase=phase,side=side,hip=hip3,knee=knee3,ankle=ankle3,heel=heel3,toe=toe3,bone_length_residuals=res,foot_length_residual=abs(float(np.linalg.norm(np.array(toe3)-np.array(heel3)))-FOOT),sole_state='heel-contact' if support and pitch==1. else ('full-support' if support else 'AIR'),foot_pitch_degrees=math.degrees(angle))
  bone_models.append(model)
  joints[side]=dict(hidden_hip_chosen_rig_anchor=hip,knee_from_fixed_187p5_bones=kne,ankle_chosen_rig_anchor=ankle,structural_heel=heel,complete_shoe_material=x['shoe'],paired_part_mirror=mirror,foot_planar_pitch_projection=pitch,model=model)
  # Paired native thigh pattern uses actual R donor, while each whole foot's
  # facing profile comes from the correct actual front/back shoe material.
  leg=blank();leg.alpha_composite(affine_bone(thigh,[687,631],[679,787],hip,kne,-1 if side=='L' else 1))
  # The narrow front-facing tarsal leather fits under its complete source
  # shoe armor. This is the paired material's fixed transverse projection.
  leather_parity=(-1 if side=='L' else 1)/(0.8 if x['shoe']=='front' else 1.)
  leg.alpha_composite(affine_bone(calf,[679,787],[678,895],kne,ankle,leather_parity))
  kaxis=np.array(ankle)-np.array(kne);kaxis=kaxis/np.linalg.norm(kaxis)
  leg.alpha_composite(affine_bone(knee_cap,[679,787],[679,809],kne,(np.array(kne)+22*kaxis).tolist(),-1 if side=='L' else 1))
  leg.alpha_composite(foot(feet[x['shoe']],sh,heel,mirror,pitch))
  limbs[side]=leg
  leg.save(D/f'N-run-phase{phase}-{side}-actual-leg-and-full-shoe.png')
 bodyphase=shift(body.rotate(lean,resample=Image.Resampling.BICUBIC,center=(663+P,635+P)),bx,by)
 cape=tail.rotate(st['tail'],resample=Image.Resampling.BICUBIC,center=(590+P,628+P))
 cape=shift(cape.rotate(lean,resample=Image.Resampling.BICUBIC,center=(663+P,635+P)),bx,by)
 arm=blank();shoulder=[574,433];elbow=st['elbow'];wrist=st['wrist']
 arm.alpha_composite(affine_bone(upper,[574,433],[543,517],shoulder,elbow))
 arm.alpha_composite(affine_bone(forearm,[543,517],[487,602],elbow,wrist))
 arm=shift(arm.rotate(lean,resample=Image.Resampling.BICUBIC,center=(663+P,635+P)),bx,by)
 shoulder=[v+d for v,d in zip(torso_point(shoulder,lean),[bx,by])];elbow=[v+d for v,d in zip(torso_point(elbow,lean),[bx,by])];wrist=[v+d for v,d in zip(torso_point(wrist,lean),[bx,by])]
 # Arm forward phases pass behind the torso; actual shoulder/cuff joins use
 # material overlap, never one-pixel alpha bridges.
 out=blank()
 if phase in (2,3,4):out.alpha_composite(arm)
 out.alpha_composite(limbs['R']);out.alpha_composite(limbs['L']);out.alpha_composite(cape);out.alpha_composite(bodyphase)
 if phase in (0,1,5):out.alpha_composite(arm)
 output=D/f'N-run-phase{phase}-actual-native-rig-v07.png';out.save(output)
 a=np.array(out);labs,n=label(a[:,:,3]>100);areas=np.bincount(labs.ravel());parts=[];from scipy.ndimage import find_objects
 boxes=find_objects(labs)
 for i,count in enumerate(areas[1:]):
  if count>=200:
   y,z=boxes[i];parts.append(dict(area=int(count),bbox=[z.start,y.start,z.stop,y.stop]))
 rows.append(dict(phase=phase,name=st['name'],path=str(output),sha256=hashlib.sha256(output.read_bytes()).hexdigest(),bytes=output.stat().st_size,physical_C=1920,common_rig_root_in_unpadded_frame=[662.8125,917.6920531878804],storage_translation=[P,P],body_node_bob=[bx,by],body_rigid_torso_lean_degrees=lean,joint_controls=joints,freeLEFTarm=dict(shoulder=shoulder,elbow=elbow,wrist=wrist),left_coat_tail_degrees=st['tail'],strong_body_components=parts,status='ACTUAL_RUN_SOURCE_ART_PENDING_PRIVATE_AND_INDEPENDENT_QC'))
contract=dict(status='ACTUAL_DEDICATED_N_RUN_SIX_POSES_PENDING_QUALITY_PHYSICAL_CYCLE_AND_GAME',actor='transform:413',role='run',direction='N',frames=rows,fixed_physical_C=1920,bodyunit=1.875,common_rig_root=[662.8125,917.6920531878804],storage_translation=[P,P],native_output_canvas=[N,N],logical_canvas=1024,actual_player_phase_ground_step=[0,132.8727272728626],actual_old_calf_residue_removed_alpha16=int((oldrem>16).sum()),actual_run_speed=262.5,phase_seconds=.064,cycle_seconds=.384,source_handoff_sha256=hashlib.sha256(hb).hexdigest(),semantics='Actual dedicated articulated native materials and freeLEFTarm/cape/bodybob; no shared motion/color-only loop or fast WALK relabel',UV='No t-clamp; inverse map samples alpha-bounded semantic real material, each bone region preclipped at its actual knee endpoint with native rounded leather joint surface. Complete hand and counter/stiletto are explicitly whole real material groups.',physical_limitations=['One chosen camera/hip-depth/foot rig is constructively fixed, not a unique recovery of hidden source anatomy.','Original complete front/back shoe RGBA are actual source-view materials; back-shell planar pitch is used for the visible CONTACT to LOAD material change. Hidden toe controls are not measured bitmap pixels.','Full painted sole depth/occlusion and all6 real source quality/Player closure require independent review.'],actual_joint_finish='Complete original LEFT cuff/bracer/hand native contour moves with arm; old arm shell removed by its semantic matte. Rounded knee uses actual native black/gold leather, source endpoints stop at knee. Front tarsal leather transverse projection 0.8 under complete original shoe.',actor_approvals_added=0,game_clips_adopted=0)
contract['exact_support_phase_clock']=dict(native_heel_step=982.8727272728626-850.,native_player_ground_step=132.8727272728626,world_phase_step=16.8,world_speed=262.5,seconds=.064,residual_native=abs((982.8727272728626-850.)-132.8727272728626))
contract['constructive_fixed_bone_rig']=dict(camera_depth_factor=CAM,projection='x=X; y=ROOTY+.45*depth-height',bone_lengths_native=[BONE,BONE],foot_length_native=FOOT,heel_to_ankle_native=ANKLE_RISE,hips_depth_contact_flight=0,hips_depth_load=40,hidden_hip_source_y=620,back_foot_material_pitch_degrees=-30,front_contact_pitch_degrees=math.degrees(CONTACT_PITCH),models=bone_models,max_bone_length_residual=max(max(m['bone_length_residuals'])for m in bone_models),articulation_surface='Actual native thigh and continuous black/gold calf leather UV surface is articulated under complete original shoe/counter/stiletto RGBA; painted shaft points are not claimed uniquely measured anatomical joints.')
(D/'actual-N-run-six-source-contract-v07.json').write_text(json.dumps(contract,indent=2,allow_nan=False)+'\n')
board=Image.new('RGB',(960,1020),'#405265');draw=ImageDraw.Draw(board)
for i,r in enumerate(rows):
 im=Image.open(r['path']).convert('RGBA');im=im.crop((350,210,1050,1260));im.thumbnail((315,480));x=(i%3)*320;y=(i//3)*510;board.paste(im,(x,y+20),im);draw.text((x+8,y+5),str(i)+' '+r['name'],fill='white')
board.save(D/'private-six-actual-source-board-v07.jpg',quality=84);assert(D/'private-six-actual-source-board-v07.jpg').stat().st_size<150000
print(json.dumps(dict(status=contract['status'],poses=6,parts=[len(x['strong_body_components'])for x in rows],contract=str(D/'actual-N-run-six-source-contract-v07.json'))))
