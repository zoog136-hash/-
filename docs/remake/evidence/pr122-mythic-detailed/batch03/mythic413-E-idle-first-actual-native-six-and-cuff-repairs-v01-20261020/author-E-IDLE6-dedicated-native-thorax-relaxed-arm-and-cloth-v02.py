"""Own E native idle: intrinsic corset breathing, relaxed actual LEFT arm,
complete head-neck lag and real skirt/coat follow-through. Feet and anatomical
RIGHT near arm/grip/full staff remain exact. No whole-actor bob or color edits.
"""
from pathlib import Path
import hashlib,json,math,sys
import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates,label,distance_transform_edt
P=Path(__file__).parent;D=P/'actual-E-IDLE6-native-breath-relax-v02';D.mkdir(exist_ok=False)
M=Path('/workspace/scratch/mythic413-E-attack-author-20261020-v01/common-own-E-native-arm-staff-materials-v01')
H=Path(sys.argv[1]);assert H.is_file(),H
REG=Path('/workspace/scratch/mythic413-E-hit-author-20261020-v01/E-new-native-one-time-body-density-C2816-root-registration-v01.json')
QC=Path('/workspace/scratch/mythic413-E-base-independent-qc-20261020-v01/E-new-native-source-and-once-C2816-body-root-registration-PASS-v01.json')
hand=json.loads(H.read_text());reg=json.loads(REG.read_text());assert hashlib.sha256(QC.read_bytes()).hexdigest()=='a33172b92818d8735ab1a8dfaf83f1b9efc9efa6f2e7d6aba5709396cb0d1598'
N=1536;PAD=int(reg['production_storage_translation'][0]);assert reg['production_storage_translation']==[PAD,PAD]
yy,xx=np.indices((N,N),dtype=float);nx=xx-PAD;ny=yy-PAD
ROOT=reg['common_rig_root_in_unpadded_frame'];assert reg['new_E_fixed_C']==2816
C=float(reg['new_E_fixed_C']);UNIT=float(reg['new_E_fixed_bodyunit'])

def pin(p):p=Path(p);return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def load(p):
 p=Path(p);a=Image.new('RGBA',(N,N));a.paste(Image.open(p).convert('RGBA'),(PAD,PAD));return a
sourcepath=Path(hand['source']['path']);source=load(sourcepath);original=np.array(source)
bodypath=Path(hand['body_inputs']['complete-LEFT-arm-old-erased-BODY-with-original-RIGHT-staff-and-boots']['body']['path']);bodyinput=load(bodypath)
lu=load(hand['parts']['LEFT-far-upper-arm']['path']);lf=load(hand['parts']['LEFT-far-complete-curved-cuff-forearm-free-hand']['path'])
a=np.array(lu);b=np.array(lf);take=b[:,:,3]>a[:,:,3];a[take]=b[take];arm=Image.fromarray(a);arm.save(D/'actual-original-complete-LEFT-arm-continuous-RGBA-input.png')
protectgear=np.zeros((N,N),bool)
for key in ['RIGHT-near-upper-arm','RIGHT-near-complete-forearm-grip-hand','complete-rigid-RIGHT-near-staff']:
 protectgear|=np.array(load(hand['parts'][key]['path']))[:,:,3]>0
protected=protectgear|(ny>=760)
safe=np.clip(distance_transform_edt(~protected)/12,0,1)
Image.fromarray(np.uint8(protected)*255).save(D/'exact-fixed-RIGHT-arm-grip-fullstaff-and-lowerlegs-protection-mask.png')

def smooth(t):t=np.clip(t,0,1);return t*t*(3-2*t)
def field(x,y,p):
 # Local transverse rib/corset surface expansion, anchored at its true waist.
 vx=np.sin(np.pi*np.clip((x-590)/220,0,1))**2*((x>590)&(x<810))
 vy=np.sin(np.pi*np.clip((y-330)/240,0,1))**2*((y>330)&(y<570))
 axis=685+(651-685)*(y-315)/234;vol=vx*vy
 dx=p['thorax_amplitude']*(x-axis)/75*vol;dy=-.4*p['thorax_amplitude']*vol
 angle=math.radians(p['neck_angle_deg']);ca=math.cos(angle);sa=math.sin(angle);hx=x-685;hy=y-315
 hw=(1-smooth((y-292)/50))*smooth((y-80)/24)*smooth((x-510)/35)*(1-smooth((x-805)/35))
 dx+=((ca-1)*hx-sa*hy)*hw;dy+=(sa*hx+(ca-1)*hy)*hw
 # Real upper skirt/coat texture above stationary legs, not a global body bob.
 cx=np.sin(np.pi*np.clip((x-740)/340,0,1))**2;cy=np.sin(np.pi*np.clip((y-575)/170,0,1))**2
 cloth=cx*cy*((x>740)&(x<1080)&(y>575)&(y<745))
 dx+=p['cloth_delta'][0]*cloth;dy+=p['cloth_delta'][1]*cloth
 guard=map_coordinates(safe,[y+PAD,x+PAD],order=1,mode='constant',cval=0,prefilter=False)
 return dx*guard,dy*guard

def sample_rgba(im,sx,sy):
 z=np.asarray(im).astype(float)/255.;al=z[:,:,3]
 wa=map_coordinates(al,[sy,sx],order=1,mode='constant',cval=0,prefilter=False)
 rgb=np.stack([map_coordinates(z[:,:,k]*al,[sy,sx],order=1,mode='constant',cval=0,prefilter=False)for k in range(3)],2)
 rgb=np.divide(rgb,wa[:,:,None],out=np.zeros_like(rgb),where=wa[:,:,None]>1e-8)
 return Image.fromarray(np.uint8(np.clip(np.dstack([rgb,wa])*255+.5,0,255)),'RGBA')

def boneA(a,b,c,d):
 a,b,c,d=map(lambda q:np.asarray(q,float),(a,b,c,d));u=(b-a)/np.linalg.norm(b-a);v=(d-c)/np.linalg.norm(d-c);n=np.array([-u[1],u[0]]);m=np.array([-v[1],v[0]])
 return np.column_stack([v*np.linalg.norm(d-c)/np.linalg.norm(b-a),m])@np.column_stack([u,n]).T
S=np.array([795.,471.]);E=np.array([808.,513.]);W=np.array([953.,596.]);fdir=(W-E)/np.linalg.norm(W-E)
def arm_forward(x,y,p):
 es=np.array(p['LEFT_elbow']);ws=np.array(p['LEFT_wrist']);A=boneA(S,E,S,es);B=boneA(E,W,es,ws)
 ux=S[0]+A[0,0]*(x-S[0])+A[0,1]*(y-S[1]);uy=S[1]+A[1,0]*(x-S[0])+A[1,1]*(y-S[1])
 fx=es[0]+B[0,0]*(x-E[0])+B[0,1]*(y-E[1]);fy=es[1]+B[1,0]*(x-E[0])+B[1,1]*(y-E[1])
 t=smooth(((x-E[0])*fdir[0]+(y-E[1])*fdir[1]+16)/32)
 return ux*(1-t)+fx*t,uy*(1-t)+fy*t
frames=[]
for i in range(6):
 theta=2*math.pi*i/6;amplitude=3.2*(1-math.cos(theta));lag=math.sin(theta-math.pi/3)
 p=dict(thorax_amplitude=amplitude,neck_angle_deg=.45*math.sin(theta-math.pi/3),cloth_delta=[3.1*lag,1.5*math.sin(theta-math.pi/2)],LEFT_shoulder=S.tolist(),LEFT_elbow=[805+.35*amplitude+.8*math.sin(theta),516-.45*amplitude],LEFT_wrist=[943+.6*amplitude+1.2*math.sin(theta),609-.65*amplitude+.9*math.sin(theta)])
 sx=nx.copy();sy=ny.copy()
 for _ in range(8):dx,dy=field(sx,sy,p);sx=nx-dx;sy=ny-dy
 body=sample_rgba(bodyinput,sx+PAD,sy+PAD)
 ax=nx.copy();ay=ny.copy()
 for _ in range(10):qx,qy=arm_forward(ax,ay,p);ax=nx-(qx-ax);ay=ny-(qy-ay)
 armnode=sample_rgba(arm,ax+PAD,ay+PAD);body.alpha_composite(armnode)
 final=np.array(body);final[protected]=original[protected];body=Image.fromarray(final)
 f=D/f'thunder_female-E-IDLE-{i}-actual-native-breath-relax-v02.png';body.save(f);armnode.save(D/f'phase{i}-actual-relaxed-continuous-LEFT-arm-node.png')
 cc,n=label(final[:,:,3]>=100);sizes=np.bincount(cc.ravel());comps=[]
 for k in np.flatnonzero(sizes>=200):
  if k:y,x=np.where(cc==k);comps.append(dict(pixels=int(sizes[k]),bbox=[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]))
 assert np.array_equal(final[protected],original[protected]);assert len(comps)==1,(i,comps)
 # True intrinsic rib deformation at fixed source coordinates; no root bob.
 dx,dy=field(np.array([630.,705.,745.]),np.array([445.,445.,445.]),p)
 frames.append(dict(phase=i,**pin(f),pose_nodes=p,actual_chest_surface_observations=[dict(source=[float(x),445.],displacement=[float(a),float(b)])for x,a,b in zip([630.,705.,745.],dx,dy)],complete_RIGHTstaff_neararm_and_lowerlegs_RGBA_changes=0,protected_original_pixels=int(protected.sum()),actual_continuous_LEFT_mesh=pin(D/f'phase{i}-actual-relaxed-continuous-LEFT-arm-node.png'),body_components_alpha100_4conn_gte200=comps,quality='PENDING_INDEPENDENT_ACTUAL_E_IDLE_SOURCE_AND_VISIBLE_LOOP'))
assert len({f['sha256']for f in frames})==6
contract=dict(status='ACTUAL_OWN_E_IDLE_SIX_NATIVE_JOINT_AND_BREATH_CANDIDATES_PENDING_INDEPENDENT_SOURCE_LOOP',actor_id=413,direction='E',action='idle',loop=True,loop_seconds=1.2,physical_canvas_fixed=C,body_unit_fixed=UNIT,logical_canvas=1024,common_rig_root_in_unpadded_frame=ROOT,storage_translation=[PAD,PAD],storage_size=[N,N],shared_basis=pin(REG),shared_basis_independent_SOURCE_PASS=pin(QC),base_native_source=pin(sourcepath),actual_material_handoff=pin(H),LEFT_erased_body_input=pin(bodypath),original_complete_LEFT_arm=pin(D/'actual-original-complete-LEFT-arm-continuous-RGBA-input.png'),source_native_controls=dict(LEFT_shoulder=S.tolist(),LEFT_cuff_interface_approx=E.tolist(),LEFT_wrist=W.tolist(),nape=[685,315],waist=[651,549],hem=[720,688]),protection_mask=pin(D/'exact-fixed-RIGHT-arm-grip-fullstaff-and-lowerlegs-protection-mask.png'),LEFT_material_operator='Continuous original complete RGBA arm: two bone plane with smooth32px original cuff UV transition; no straight source cutoff or endpoint clamp',method='True corset transverse volume, dedicated relaxed LEFT arm with natural changing elbow/wrist, complete head/bun/ribbon delayed neck node and upper coat lag; same fixed feet and RIGHT staff hand',new_services=0,new_author_images=0,private_image_context_bytes_unchanged=5538937,old_profiles_or_sources_modified=False,whole_actor_bob_or_color_change=False,actor_approval_added=0,frames=frames)
c=D/'E-IDLE-six-actual-native-source-fixed-basis-and-loop-contract-v02.json';c.write_text(json.dumps(contract,indent=2)+'\n');print(json.dumps(dict(contract=pin(c),frames=6,unique_source_RGBA6=True,complete_Rgear_and_lowerlegs_RGBA_changes=0,body_counts=[len(x['body_components_alpha100_4conn_gte200'])for x in frames])))
