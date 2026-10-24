from pathlib import Path
import hashlib,json,math
from PIL import Image,ImageDraw
import numpy as np
from scipy.ndimage import label,binary_dilation

B=Path(__file__).parent
D=B/'actual-six-native-articulation-v02';D.mkdir()
H=Path('/workspace/scratch/mythic413-N-walk-load-author-fresh-20261020-v01/N-native-rig-and-material-handoff-for-RUN-v01/N-RUN-actual-native-rig-source-material-handoff-v01.json')
hb=H.read_bytes();assert hashlib.sha256(hb).hexdigest()=='257e6675357a63a8790b8a55732a1851f312a2c6a362bdd31d5a13bc62949763'
h=json.loads(hb);sources={}
for e in h['files']:
 p=Path(e['path']);b=p.read_bytes();assert hashlib.sha256(b).hexdigest()==e['sha256'];sources[p.name]=Image.open(p).convert('RGBA')
src=Image.open(h['source0']['path']).convert('RGBA');assert hashlib.sha256(Path(h['source0']['path']).read_bytes()).hexdigest()==h['source0']['sha256']
N=1536;P=128
def blank():return Image.new('RGBA',(N,N))
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
thigh=ypart(right,640,793)
calf=ypart(right,780,934)
feet={
 'front':native(sources['complete-original-native-LEFT-calf-ankle-and-full-shoe-material.png']),
 'back':native(sources['complete-original-native-RIGHT-calf-ankle-and-full-shoe-material.png'])}
forearm=native(sources['complete-original-native-LEFT-forearm-hand-bracer-ornament-material.png'])
upper=selected(src,[(558,419),(592,427),(582,470),(560,532),(528,532),(521,504),(542,455)])
upper=native(upper)
arm_alpha=np.maximum(np.array(upper)[:,:,3],np.array(forearm)[:,:,3])
body=native(sources['source0-native-body-coat-RIGHTstaff-with-complete-old-legs-removed-INPUT.png'])
ar=np.array(body);ar[binary_dilation(arm_alpha>0,iterations=1)]=0;body=Image.fromarray(ar)
tail=selected(sources['source0-native-body-coat-RIGHTstaff-with-complete-old-legs-removed-INPUT.png'],[(578,610),(616,632),(581,746),(521,895),(474,920),(392,821),(393,768),(454,717),(519,663)])
tail=native(tail);ta=np.array(tail)[:,:,3];ar=np.array(body);remove=(ta>0);remove[:630+P]=False;ar[remove]=0;body=Image.fromarray(ar)
for name,im in [('native-clean-body-RIGHTstaff',body),('native-freeLEFT-upperarm',upper),('native-freeLEFT-complete-forearm-hand-bracer',forearm),('native-left-coat-tail',tail),('native-thigh-material',thigh),('native-calf-material',calf)]:im.save(D/(name+'.png'))

states=[
 dict(phase=0,name='LEFT-contact',bob=[-10,-10],L=dict(k=[615,710],heel=[616.5,850],shoe='front',mirror=False),R=dict(k=[715,740],heel=[726,764],shoe='back',mirror=False),elbow=[550,520],wrist=[511,620],tail=-4),
 dict(phase=1,name='LEFT-load-footroll',bob=[-3,35],L=dict(k=[611,803],heel=[616.5,983],shoe='front',mirror=False,pitch=1.035),R=dict(k=[725,656],heel=[733,858],shoe='front',mirror=True),elbow=[537,514],wrist=[495,589],tail=6),
 dict(phase=2,name='RIGHT-drive-flight',bob=[12,-48],L=dict(k=[594,719],heel=[582,742],shoe='back',mirror=True),R=dict(k=[714,612],heel=[698,812],shoe='front',mirror=True),elbow=[536,487],wrist=[520,433],tail=10),
 dict(phase=3,name='RIGHT-contact',bob=[10,-10],L=dict(k=[610,740],heel=[599,764],shoe='back',mirror=True),R=dict(k=[711,710],heel=[708.5,850],shoe='front',mirror=True),elbow=[545,475],wrist=[560,420],tail=4),
 dict(phase=4,name='RIGHT-load-footroll',bob=[3,35],L=dict(k=[600,656],heel=[592,858],shoe='front',mirror=False),R=dict(k=[714,803],heel=[708.5,983],shoe='front',mirror=True,pitch=1.035),elbow=[539,489],wrist=[540,450],tail=-5),
 dict(phase=5,name='LEFT-drive-flight',bob=[-12,-48],L=dict(k=[611,612],heel=[627,812],shoe='front',mirror=False),R=dict(k=[731,719],heel=[744,742],shoe='back',mirror=False),elbow=[541,513],wrist=[511,555],tail=-9),
]
rows=[]
for st in states:
 phase=st['phase'];bx,by=st['bob'];limbs={};joints={}
 for side in ('L','R'):
  x=st[side];mirror=x['mirror'];heel=x['heel'];pitch=x.get('pitch',1.)
  sh=[616.5,850] if x['shoe']=='front' else [680,1032]
  sa=[625,792] if x['shoe']=='front' else [678,923]
  parity=-1 if mirror else 1
  ankle=[heel[0]+parity*(sa[0]-sh[0]),heel[1]+pitch*(sa[1]-sh[1])]
  hip=[(619 if side=='L' else 687)+bx,635+by]
  kne=x['k'];joints[side]=dict(hidden_hip_surface_control=hip,knee_control=kne,ankle_material_landmark=ankle,structural_heel=heel,complete_shoe_material=x['shoe'],paired_part_mirror=mirror,foot_planar_pitch_projection=pitch)
  # Paired native thigh pattern uses actual R donor, while each whole foot's
  # facing profile comes from the correct actual front/back shoe material.
  leg=blank();leg.alpha_composite(affine_bone(thigh,[687,646],[679,787],hip,kne,-1 if side=='L' else 1))
  leg.alpha_composite(affine_bone(calf,[679,787],[678,923],kne,ankle,-1 if side=='L' else 1))
  leg.alpha_composite(foot(feet[x['shoe']],sh,heel,mirror,pitch))
  limbs[side]=leg
  leg.save(D/f'N-run-phase{phase}-{side}-actual-leg-and-full-shoe.png')
 bodyphase=shift(body,bx,by)
 cape=tail.rotate(st['tail'],resample=Image.Resampling.BICUBIC,center=(590+P,628+P))
 cape=shift(cape,bx,by)
 arm=blank();shoulder=[574+bx,433+by];elbow=[st['elbow'][0]+bx,st['elbow'][1]+by];wrist=[st['wrist'][0]+bx,st['wrist'][1]+by]
 arm.alpha_composite(affine_bone(upper,[574,433],[543,517],shoulder,elbow))
 arm.alpha_composite(affine_bone(forearm,[543,517],[487,602],elbow,wrist))
 # Arm forward phases pass behind the torso; actual shoulder/cuff joins use
 # material overlap, never one-pixel alpha bridges.
 out=blank()
 if phase in (2,3,4):out.alpha_composite(arm)
 out.alpha_composite(limbs['R']);out.alpha_composite(limbs['L']);out.alpha_composite(cape);out.alpha_composite(bodyphase)
 if phase in (0,1,5):out.alpha_composite(arm)
 output=D/f'N-run-phase{phase}-actual-native-rig-v02.png';out.save(output)
 a=np.array(out);labs,n=label(a[:,:,3]>100);areas=np.bincount(labs.ravel());parts=[];from scipy.ndimage import find_objects
 boxes=find_objects(labs)
 for i,count in enumerate(areas[1:]):
  if count>=200:
   y,z=boxes[i];parts.append(dict(area=int(count),bbox=[z.start,y.start,z.stop,y.stop]))
 rows.append(dict(phase=phase,name=st['name'],path=str(output),sha256=hashlib.sha256(output.read_bytes()).hexdigest(),bytes=output.stat().st_size,physical_C=1920,common_rig_root_in_unpadded_frame=[662.8125,917.6920531878804],storage_translation=[P,P],body_node_bob=[bx,by],joint_controls=joints,freeLEFTarm=dict(shoulder=shoulder,elbow=elbow,wrist=wrist),left_coat_tail_degrees=st['tail'],strong_body_components=parts,status='ACTUAL_RUN_SOURCE_ART_PENDING_PRIVATE_AND_INDEPENDENT_QC'))
contract=dict(status='ACTUAL_DEDICATED_N_RUN_SIX_POSES_PENDING_QUALITY_PHYSICAL_CYCLE_AND_GAME',actor='transform:413',role='run',direction='N',frames=rows,fixed_physical_C=1920,bodyunit=1.875,common_rig_root=[662.8125,917.6920531878804],storage_translation=[P,P],native_output_canvas=[N,N],logical_canvas=1024,actual_player_phase_ground_step=[0,132.8727272728626],actual_run_speed=262.5,phase_seconds=.064,cycle_seconds=.384,source_handoff_sha256=hashlib.sha256(hb).hexdigest(),semantics='Actual dedicated articulated native materials and freeLEFTarm/cape/bodybob; no shared motion/color-only loop or fast WALK relabel',UV='No t-clamp; inverse map samples alpha-bounded semantic real material, each bone region preclipped with <=7px joint overlap. Complete hand and counter/stiletto are explicitly whole real material groups.',physical_limitations=['Hip/knee controls are a chosen constructive rig, not uniquely measured hidden 3D joints.','Toe occlusion/true sole support and AIR need independent finite model/art verification.','Projected part lengths alone are not fixed-bone or actual gait approval.'],actor_approvals_added=0,game_clips_adopted=0)
(D/'actual-N-run-six-source-contract-v02.json').write_text(json.dumps(contract,indent=2,allow_nan=False)+'\n')
board=Image.new('RGB',(960,1020),'#405265');draw=ImageDraw.Draw(board)
for i,r in enumerate(rows):
 im=Image.open(r['path']).convert('RGBA');im=im.crop((350,210,1050,1260));im.thumbnail((315,480));x=(i%3)*320;y=(i//3)*510;board.paste(im,(x,y+20),im);draw.text((x+8,y+5),str(i)+' '+r['name'],fill='white')
board.save(D/'private-six-actual-source-board-v02.jpg',quality=84);assert(D/'private-six-actual-source-board-v02.jpg').stat().st_size<150000
print(json.dumps(dict(status=contract['status'],poses=6,parts=[len(x['strong_body_components'])for x in rows],contract=str(D/'actual-N-run-six-source-contract-v02.json'))))
