from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,hashlib
from scipy.ndimage import binary_dilation,label
B=Path(__file__).parent;D=B/'own-native-directional-materials-v02';D.mkdir(exist_ok=False)
N=Path('/workspace/scratch/mythic413-NE-run-author-20261020-v01/common-complete-NE-native-material-parts-v03')
S=Path('/workspace/scratch/mythic413-NE-walk-author-20261020-v01/NE-contact0-actual-native-background-AA-clean-r002.png')
C=N/'original-actual-BODY-only-complete-old-thigh-and-arm-removed-native.png';L=N/'original-actual-complete-LEFT-cuff-elbow-cap-forearm-hand-native.png'
W=H=1536;native=1254

def pad(p):o=Image.new('RGBA',(W,H));o.paste(Image.open(p).convert('RGBA'),(0,0));return o
s=pad(S);base=pad(C);a=np.array(s);b=np.array(base);yy,xx=np.indices((H,W))
def poly(points):m=Image.new('L',(W,H));ImageDraw.Draw(m).polygon(points,fill=255);return np.array(m)>0
def isolate(im,mask):q=np.array(im).copy();q[~mask]=0;return Image.fromarray(q)
def pin(p):r=Path(p).read_bytes();return {'path':str(p),'sha256':hashlib.sha256(r).hexdigest(),'bytes':len(r)}
parts={};masks={}
def save(n,im,m):
 p=D/f'original-actual-NE-{n}-material.png';im.save(p);mp=D/f'original-actual-NE-{n}-semantic-matte.png';Image.fromarray(m.astype('uint8')*255).save(mp);parts[n]=pin(p);masks[n]=pin(mp)
# Own NE view, anatomical RIGHT near holding arm. Genuine shoulder/cuff caps
# overlap locally; fixed torso does not retain the old moving arm.
RU=poly([(733,410),(754,407),(774,419),(791,439),(807,463),(816,479),(833,493),(839,507),(836,529),(827,546),(812,562),(793,563),(771,551),(758,536),(752,518),(740,498),(733,477),(729,450)])
RF=poly([(795,537),(817,534),(835,538),(857,539),(881,530),(900,519),(920,507),(940,504),(958,507),(970,519),(969,542),(961,558),(946,569),(925,573),(908,577),(889,589),(870,601),(846,613),(826,614),(808,606),(795,593),(788,575),(785,555)])
LU=poly([(545,469),(578,466),(602,477),(620,493),(621,515),(608,537),(587,549),(563,543),(545,528),(534,508),(533,485)])
lf=pad(L);LF=np.array(lf)[:,:,3]>0
for n,m in [('RIGHT-upper-arm',RU),('RIGHT-forearm-hand',RF),('LEFT-upper-arm',LU)]:save(n,isolate(s,m),m)
save('LEFT-complete-cuff-forearm-hand',lf,LF)
# Isolate the original complete pole from the already boot-free actual BODY.
# Shaft centerline is registered once from visible native metal, not foot fit.
metal=(b[:,:,0]>100)&(b[:,:,1]>55)&(b[:,:,0]>b[:,:,2]*1.4)&(b[:,:,3]>100)
rows=[]
for y in range(640,801):
 xs=np.where(metal[y]&(xx[y]>=890)&(xx[y]<=980))[0]
 if len(xs):rows.append((y,(float(xs.min())+float(xs.max()))/2))
coef=np.polyfit([v[0] for v in rows],[v[1] for v in rows],1);axis=coef[0]*yy+coef[1]
wm=((xx>=895)&(xx<=1040)&(yy<510))|((abs(xx-axis)<17)&(yy>=510)&(yy<825))|((xx>=850)&(xx<=965)&(yy>=825)&(yy<=1125))
wm &= ~RF
weapon=np.array(isolate(base,wm));profile=[]
for u in range(-11,12):
 vals=[]
 for y in range(650,751):
  x=round(float(coef[0]*y+coef[1]))+u
  if b[y,x,3]>100:vals.append(b[y,x,:3])
 profile.append(np.median(vals,axis=0)if vals else[150,96,16])
# Only the straight metal hidden by the real hand is continued, then the
# complete original real hand is re-layered in front. Both ornament ends exact.
for y in range(500,577):
 cx=float(coef[0]*y+coef[1])
 for x in range(int(cx-11),int(cx+12)):
  u=x-cx
  if abs(u)>11:continue
  if weapon[y,x,3]==0:weapon[y,x,:3]=profile[int(np.clip(round(u)+11,0,22))];weapon[y,x,3]=253 if abs(u)<9.5 else int(max(0,253*(11-abs(u))/1.5))
weapon=Image.fromarray(weapon);save('complete-rigid-RIGHT-staff',weapon,np.array(weapon)[:,:,3]>0)
# Complete old visible source semantics, including actual fringe AA.
olderase=RU|RF|LU|LF|wm
olderase |= poly([(529,464),(581,457),(608,474),(626,493),(626,518),(610,545),(597,565),(575,592),(548,617),(524,644),(500,677),(480,699),(449,700),(432,682),(433,657),(446,630),(470,599),(496,563),(516,536),(526,505)])
core=isolate(base,~olderase);cp=D/'actual-native-NE-head-torso-coat-old-arms-staff-removed-INPUT.png';core.save(cp);em=D/'complete-original-old-LEFT-RIGHT-arms-and-visible-staff-erasure-mask.png';Image.fromarray(olderase.astype('uint8')*255).save(em)
controls={'RIGHT_shoulder':[752,447],'RIGHT_cuff_hinge':[807,552],'RIGHT_wrist':[903,552],'RIGHT_grip':[944,536],'LEFT_shoulder':[573,500],'LEFT_elbow':[559,550],'LEFT_wrist':[481,645],'torso_pelvis_pivot':[716.2291666666666,705]}
j={'schema':'PR122-own-native-NE-attack-semantic-material-input-v1','status':'ACTUAL_OWN_NE_NATIVE_MATERIAL_INPUT_PENDING_SOURCE_QC','source_inputs':[pin(S),pin(C),pin(L)],'C':2432,'bodyunit':2.375,'common_rig_root_in_unpadded_frame':[716.2291666666666,1054.2766007046484],'native_canvas':[1254,1254],'storage_canvas':[1536,1536],'storage_translation':[0,0],'whole_actor_mirror_or_source_resample':False,'RIGHT_near_staff_LEFT_far_free':True,'actual_native_controls':controls,'shaft_axis_once_from_actual_visible_native_metal_fit':coef.tolist(),'parts':parts,'mattes':masks,'body_core':pin(cp),'complete_old_erasure':pin(em),'actor_approvals_added':0}
p=D/'NE-ATTACK-native-own-material-input-and-controls-v02.json';p.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps({'manifest':pin(p),'source_core_alpha100_pixels':int((np.array(core)[:,:,3]>100).sum())}))
# Private workboard is saved locally. It is not returned until ledger booked.
items=[('core',core)]+[(n,Image.open(v['path']).convert('RGBA')) for n,v in parts.items()]
board=Image.new('RGB',(4*350,2*410),(72,72,75));draw=ImageDraw.Draw(board)
for k,(n,im) in enumerate(items):
 q=im.copy();q.thumbnail((330,370));xy=((k%4)*350+(350-q.width)//2,(k//4)*410+25);board.paste(q,xy,q);draw.text(((k%4)*350+5,(k//4)*410+5),n,fill='white')
board.save(D/'private-own-NE-attack-materials-core-and-complete-gear-v02.jpg',quality=84)
