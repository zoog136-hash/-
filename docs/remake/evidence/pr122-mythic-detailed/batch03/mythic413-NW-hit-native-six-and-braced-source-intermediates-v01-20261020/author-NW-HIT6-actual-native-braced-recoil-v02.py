"""Six new actor-specific NW HIT poses from native material, never whole-PNG bob.

Inputs are read-only dedicated original actor parts. Material extraction is
explicitly INPUT until the resulting six poses receive independent source QA.
"""
from pathlib import Path
import json, hashlib, argparse
import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates, label

P=Path(__file__).parent
args=argparse.ArgumentParser();args.add_argument('--materials',required=True);a=args.parse_args()
M=Path(a.materials);O=P/'actual-NW-HIT6-native-braced-recoil-v02';O.mkdir(exist_ok=False)
W=H=1536;yy,xx=np.indices((H,W),dtype=float)
def pin(p):return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def pad(im):
 o=Image.new('RGBA',(W,H));o.paste(im,(0,0));return o
def load(n):return pad(Image.open(M/n).convert('RGBA'))
basepath=P/'actual-braced-stance-v03/thunder_female-NW-HIT-braced-fixed-stance-candidate-v03.png'
core=pad(Image.open(basepath).convert('RGBA'))
leftupper=load('actual-original-NW-LEFT-upper-arm-material.png')
leftfore=load('actual-original-NW-LEFT-forearm-hand-material.png')
legpath=P/'actual-braced-stance-v03/NW-HIT-articulated-braced-legs-and-complete-shoes.png'
legs=pad(Image.open(legpath).convert('RGBA'))
def field(x,y,head,cloth):
 # Head is a rigid native node; actual spine bends to the fixed hip/stance.
 t=np.clip((706-y)/316,0,1);w=t*t*(3-2*t)
 r=np.clip((730-x)/80,0,1);r=r*r*(3-2*r)
 dx=head[0]*w*r;dy=head[1]*w*r
 cx=np.clip((x-850)/230,0,1);cy=np.clip((y-620)/370,0,1)
 lag=np.sin(np.pi*cx)**2*np.sin(np.pi*cy)**2*((x>850)&(x<1080)&(y>620)&(y<990))
 return dx+cloth[0]*lag,dy+cloth[1]*lag
def project(part,oldA,oldB,newA,newB):
 a,b,c,d=map(lambda z:np.asarray(z,float),(oldA,oldB,newA,newB));v=b-a;z=d-c
 u=v/np.linalg.norm(v);n=np.array([-u[1],u[0]]);q=z/np.linalg.norm(z);m=np.array([-q[1],q[0]])
 A=np.column_stack([q*np.linalg.norm(z)/np.linalg.norm(v),m])@np.column_stack([u,n]).T
 off=c-A@a;inv=np.linalg.inv(A);k=-inv@off
 out=part.transform((W,H),Image.Transform.AFFINE,(inv[0,0],inv[0,1],k[0],inv[1,0],inv[1,1],k[1]),Image.Resampling.BICUBIC)
 return out,dict(source_joints=[a.tolist(),b.tolist()],target_joints=[c.tolist(),d.tolist()],matrix=A.tolist(),offset=off.tolist(),outside_semantic_alpha='TRANSPARENT; no UV endpoint clamping')
poses=[
 dict(name='GUARD0',head=[0,0],cloth=[0,0],elbow=[610,535],wrist=[555,629]),
 dict(name='IMPACT1',head=[8,13],cloth=[3,3],elbow=[632,550],wrist=[563,570]),
 dict(name='RECOIL2',head=[24,30],cloth=[10,7],elbow=[648,559],wrist=[567,534]),
 dict(name='COUNTER3',head=[15,18],cloth=[12,5],elbow=[627,549],wrist=[551,564]),
 dict(name='RECOVER4',head=[5,4],cloth=[6,2],elbow=[613,538],wrist=[547,613]),
 dict(name='RESET5',head=[0,0],cloth=[-1,0],elbow=[611,535],wrist=[554,629])]
frames=[];base=np.asarray(core).astype(float)/255;alpha=base[:,:,3];pm=base[:,:,:3]*alpha[:,:,None]
for i,p in enumerate(poses):
 sx=xx.copy();sy=yy.copy()
 for _ in range(9):dx,dy=field(sx,sy,p['head'],p['cloth']);sx=xx-dx;sy=yy-dy
 wa=map_coordinates(alpha,[sy,sx],order=1,mode='constant',cval=0,prefilter=False)
 rgb=np.stack([map_coordinates(pm[:,:,c],[sy,sx],order=1,mode='constant',cval=0,prefilter=False)for c in range(3)],2)
 rgb=np.divide(rgb,wa[:,:,None],out=np.zeros_like(rgb),where=wa[:,:,None]>1e-8)
 body=Image.fromarray(np.uint8(np.clip(np.dstack([rgb,wa])*255+.5,0,255)),'RGBA')
 dx,dy=field(np.array(589.),np.array(458.),p['head'],p['cloth']);s=[589+float(dx),458+float(dy)]
 lu,lub=project(leftupper,[589,458],[553,531],s,p['elbow'])
 lf,lfb=project(leftfore,[553,531],[491,625],p['elbow'],p['wrist'])
 rub={'method':'Native continuous torso/rightupperarm field anchored to exact fixed RIGHTforearm/staff, no gear isolation/replacement'}
 out=body.copy();out.alpha_composite(lu);out.alpha_composite(lf)
 f=O/f'thunder_female-NW-HIT-{i}-{p["name"]}-actual-native-v02.png';out.save(f)
 lu.save(O/f'phase{i}-actual-LEFT-upper-arm-node.png');lf.save(O/f'phase{i}-actual-LEFT-forearm-glove-node.png')
 az=np.asarray(out);cc,n=label(az[:,:,3]>=100);sz=np.bincount(cc.ravel());large=[]
 for k in np.flatnonzero(sz>=200):
  if k:
   y,x=np.where(cc==k);large.append(dict(pixels=int(sz[k]),bbox=[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]))
 frames.append(dict(phase=i,name=p['name'],**pin(f),source_size=[1536,1536],storage_translation=[0,0],physical_canvas=2048,common_rig_root=[641,1058.3],actual_pose=p,LEFT_upper= lub,LEFT_forearm=lfb,RIGHT_upper=rub,body_components_alpha100_4conn_gte200=large,quality='PENDING_INDEPENDENT_ACTUAL_SOURCE_QC'))
contract=dict(status='ACTUAL_NEW_NW_HIT6_NATIVE_PART_RECOIL_PENDING_SOURCE_AND_ONE_SHOT_QC',actor_id=413,direction='NW',action='hit',loop=False,physical_canvas=2048,body_unit=2,logical_canvas=1024,common_rig_root_in_unpadded_frame=[641,1058.3],storage_translation=[0,0],storage_size=[1536,1536],fixed_stance_contract=pin(P/'actual-braced-stance-v03/NW-HIT-actual-braced-stance-source-and-fixed-contract-v03.json'),actual_parts_folder=str(M),input_materials_are_labeled_HOLD_until_result_QC=True,new_image_service_calls=0,new_author_image_receipts=0,originals_modified=False,actor_approval_added=0,frames=frames)
(O/'NW-HIT-six-actual-native-source-and-common-root-contract-v02.json').write_text(json.dumps(contract,indent=2)+'\n')
print(json.dumps(dict(frames=6,contract=pin(O/'NW-HIT-six-actual-native-source-and-common-root-contract-v02.json'),approval_added=0)))
