"""Actual NW idle: rib/corset expansion, relaxed arm, neck and cloth nodes.

Dedicated native actor materials; six cyclic articulated poses, no whole-PNG
translation or color change. The common physical root and flat shoes stay fixed.
"""
from pathlib import Path
import hashlib,json,math
import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates,label

P=Path(__file__).parent;O=P/'actual-NW-IDLE6-native-thorax-v02';O.mkdir(exist_ok=False)
W=H=1536;yy,xx=np.indices((H,W),dtype=float)
B=Path('/workspace/scratch/mythic413-NW-hit-author-20261020-v01/actual-braced-stance-v03')
S=B/'thunder_female-NW-HIT-braced-fixed-stance-candidate-v03.png'
M=Path('/workspace/scratch/mythic413-NW-attack-author-20261020-v01/actual-NW-ATTACK6-native-rig-v03')
def pin(p):return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def pad(im):
 o=Image.new('RGBA',(W,H));o.paste(im,(0,0));return o
source=pad(Image.open(S).convert('RGBA'))
lu=pad(Image.open(M/'actual-original-NW-LEFT-upper-arm-material.png').convert('RGBA'))
lf=pad(Image.open(M/'actual-original-NW-LEFT-forearm-hand-material.png').convert('RGBA'))
def smooth(t):t=np.clip(t,0,1);return t*t*(3-2*t)
def field(x,y,p):
 # Genuine transverse rib/corset expansion about the back structural center;
 # waist/hips remain fixed. This is a surface volume change, not a global bob.
 vx=np.sin(np.pi*np.clip((x-510)/230,0,1))**2*((x>510)&(x<740))
 vy=np.sin(np.pi*np.clip((y-425)/180,0,1))**2*((y>425)&(y<605))
 vol=vx*vy;dx=p['thorax_amplitude']*(x-630)/70*vol;dy=-.35*p['thorax_amplitude']*vol
 # Original complete head/bun/ribbon moves as a tiny delayed neck rotation.
 # No invented isolated hair material, no staff motion or body-scale fitting.
 angle=math.radians(p['neck_angle_deg']);ca=math.cos(angle);sa=math.sin(angle)
 hx=x-628.;hy=y-422.;headw=(1-smooth((y-400)/38))*smooth((x-500)/15)*(1-smooth((x-760)/30))*smooth((y-220)/20)
 dx+=((ca-1)*hx-sa*hy)*headw;dy+=(sa*hx+(ca-1)*hy)*headw
 # Native far coat material lags the breathing. This region excludes the
 # complete rigid gold/turquoise staff, its gripping hand, and all fixed feet.
 cx=np.clip((x-850)/230,0,1);cy=np.clip((y-620)/370,0,1)
 lag=np.sin(np.pi*cx)**2*np.sin(np.pi*cy)**2*((x>850)&(x<1080)&(y>620)&(y<990))
 dx+=p['cloth_delta'][0]*lag;dy+=p['cloth_delta'][1]*lag
 return dx,dy
def bone(part,a,b,c,d):
 a,b,c,d=map(lambda v:np.asarray(v,float),(a,b,c,d));v=b-a;z=d-c;u=v/np.linalg.norm(v);n=np.array([-u[1],u[0]]);q=z/np.linalg.norm(z);m=np.array([-q[1],q[0]])
 A=np.column_stack([q*np.linalg.norm(z)/np.linalg.norm(v),m])@np.column_stack([u,n]).T;t=c-A@a;inv=np.linalg.inv(A);k=-inv@t
 o=part.transform((W,H),Image.Transform.AFFINE,(inv[0,0],inv[0,1],k[0],inv[1,0],inv[1,1],k[1]),Image.Resampling.BICUBIC)
 return o,dict(source_joint_pair=[a.tolist(),b.tolist()],target_joint_pair=[c.tolist(),d.tolist()],matrix=A.tolist(),offset=t.tolist(),UV='Actual native semantic material only; no endpoint clamp')
base=np.asarray(source).astype(float)/255.;alpha=base[:,:,3];pm=base[:,:,:3]*alpha[:,:,None];frames=[]
for i in range(6):
 theta=2*math.pi*i/6;amplitude=2.5*(1-math.cos(theta));lag=math.sin(theta-math.pi/3)
 p=dict(thorax_amplitude=amplitude,neck_angle_deg=.6*math.sin(theta-math.pi/3),cloth_delta=[2.5*lag,1.2*math.sin(theta-math.pi/2)],LEFT_elbow=[570+.4*amplitude+.8*math.sin(theta),548-.5*amplitude],LEFT_wrist=[526+.5*amplitude+math.sin(theta),646-.7*amplitude+math.sin(theta)])
 sx=xx.copy();sy=yy.copy()
 for _ in range(9):dx,dy=field(sx,sy,p);sx=xx-dx;sy=yy-dy
 wa=map_coordinates(alpha,[sy,sx],order=1,mode='constant',cval=0,prefilter=False)
 rgb=np.stack([map_coordinates(pm[:,:,c],[sy,sx],order=1,mode='constant',cval=0,prefilter=False)for c in range(3)],2)
 rgb=np.divide(rgb,wa[:,:,None],out=np.zeros_like(rgb),where=wa[:,:,None]>1e-8)
 body=Image.fromarray(np.uint8(np.clip(np.dstack([rgb,wa])*255+.5,0,255)),'RGBA')
 dx,dy=field(np.array(589.),np.array(458.),p);shoulder=[589+float(dx),458+float(dy)]
 upper,ub=bone(lu,[589,458],[553,531],shoulder,p['LEFT_elbow']);fore,fb=bone(lf,[553,531],[491,625],p['LEFT_elbow'],p['LEFT_wrist'])
 body.alpha_composite(upper);body.alpha_composite(fore)
 f=O/f'thunder_female-NW-IDLE-{i}-native-breath-relax-v02.png';body.save(f)
 upper.save(O/f'phase{i}-actual-relaxed-LEFT-upper-node.png');fore.save(O/f'phase{i}-actual-relaxed-LEFT-forearm-glove-node.png')
 a=np.asarray(body);cc,n=label(a[:,:,3]>=100);sz=np.bincount(cc.ravel());components=[]
 for k in np.flatnonzero(sz>=200):
  if k:
   y,x=np.where(cc==k);components.append(dict(pixels=int(sz[k]),bbox=[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]))
 frames.append(dict(phase=i,**pin(f),pose_nodes=p,LEFT_upper=ub,LEFT_forearm=fb,body_components_alpha100_4conn_gte200=components,quality='PENDING_INDEPENDENT_ACTUAL_SOURCE_AND_IDLE_LOOP_QC'))
contract=dict(status='ACTUAL_NEW_NW_IDLE6_NATIVE_THORAX_AND_RELAX_PENDING_SOURCE_LOOP_QC',actor_id=413,direction='NW',action='idle',loop=True,loop_seconds=1.2,physical_canvas_fixed=2048,body_unit_fixed=2,logical_canvas=1024,common_rig_root_in_unpadded_frame=[641,1058.3],storage_translation=[0,0],storage_size=[1536,1536],base_native_source=pin(S),LEFT_upper_material=pin(M/'actual-original-NW-LEFT-upper-arm-material.png'),LEFT_forearm_material=pin(M/'actual-original-NW-LEFT-forearm-hand-material.png'),fixed_stance_contract=pin(B/'NW-HIT-actual-braced-stance-source-and-fixed-contract-v03.json'),production_method='Actual rib/corset transverse volume and spinal surface; dedicated relaxed LEFT arm bones; complete head/bun/ribbon on delayed neck node; native farcoat lag; fixed real feet/RIGHTstaff',original_assets_modified=False,new_services=0,new_author_image_receipts=0,actor_approval_added=0,frames=frames)
c=O/'NW-IDLE-six-actual-native-source-common-root-and-loop-contract-v02.json';c.write_text(json.dumps(contract,indent=2)+'\n')
print(json.dumps(dict(contract=pin(c),frames=6,alpha100_body_component_counts=[len(x['body_components_alpha100_4conn_gte200'])for x in frames],approval_added=0)))
