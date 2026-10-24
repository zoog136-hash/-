"""Own SE dedicated idle6 from its new native original materials.
Only accepts the fixed shared SE body/source and numeric basis PASS receipts.
Actual corset breathing, relaxed two-node complete LEFT cuff/hand, neck and
cloth follow-through are separate continuous native nodes. No whole-body bob.
"""
from pathlib import Path
import json,hashlib,math,sys
import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates,distance_transform_edt,label
P=Path(__file__).parent
REG=Path('/workspace/scratch/mythic413-SE-hit-author-20261020-v01/SE-new-native-one-time-body-density-C2816-root-registration-v01.json')
PREP=P/'actual-SE-native-source-node-material-INPUT-v01/SE-original-native-materials-and-continuous-node-ownership-INPUT-v01.json'
H,QC,NUMERIC=map(Path,sys.argv[1:4]);hand=json.loads(H.read_text());reg=json.loads(REG.read_text());q=json.loads(QC.read_text());n=json.loads(NUMERIC.read_text());prep=json.loads(PREP.read_text())
assert str(q.get('status','')).startswith('PASS') and str(n.get('status','')).startswith('PASS')
assert 'a322b55c6ff5a0945cb5480512007c4efe2c335ab4a690bdd57bbca18226f076' in json.dumps(q)
assert '7c7ab9bed7adb561762c88a39facb00815b5ab2c23cec533d0adbcf7d757f1c6' in json.dumps(n)
N=1536;PAD=int(reg['production_storage_translation'][0]);assert reg['production_storage_translation']==[PAD,PAD]
C=float(reg['new_SE_fixed_C']);UNIT=float(reg['new_SE_fixed_bodyunit']);ROOT=reg['common_rig_root_in_unpadded_frame']
D=P/'actual-SE-IDLE6-native-breath-relax-v01';D.mkdir(exist_ok=False)
yy,xx=np.indices((N,N),dtype=float);nx=xx-PAD;ny=yy-PAD

def pin(p):p=Path(p);return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def load(p):
 o=Image.new('RGBA',(N,N));o.paste(Image.open(p).convert('RGBA'),(PAD,PAD));return o
sourcepath=Path(hand['source']['path']);assert pin(sourcepath)['sha256']==reg['source']['sha256'];source=load(sourcepath);original=np.array(source)
bodypath=Path(hand['body_inputs']['LEFT-forearm-only-old-erased-BODY-with-original-RIGHT-staff-arms-and-boots']['body']['path']);bodyinput=load(bodypath)
armkey='LEFT-far-complete-curved-cuff-forearm-free-hand';armpath=Path(hand['parts'][armkey]['path']);arm=load(armpath)
protectpath=Path(hand['fixed_original_RIGHTgear_conservative_native_support']['path']);rawprotect=np.array(Image.open(protectpath).convert('L'))>0;protectgear=np.zeros((N,N),bool);protectgear[PAD:PAD+rawprotect.shape[0],PAD:PAD+rawprotect.shape[1]]=rawprotect
protected=protectgear|(ny>=prep['native_fixed_lowerbody_start']);control=hand['actual_native_controls'];S=np.array(control['LEFT_far_visible_proximal_anchor'],float);E=np.array(control['LEFT_far_cuff_elbow'],float);W=np.array(control['LEFT_far_wrist'],float)
# The original upperarm/body near the genuine cuff anchor remains rigid so
# the new complete moving cuff overlaps its actual original joint naturally.
proximal_body_guard=(nx-S[0])**2+(ny-S[1])**2<=18**2
safe=np.clip(distance_transform_edt(~(protected|proximal_body_guard))/12,0,1)
Image.fromarray(np.uint8(protected)*255).save(D/'exact-original-RIGHTgear-and-complete-lowerbody-preservation-mask.png')
weights={}
for row in prep['parts']:
 weights[row['name']]=np.array(Image.open(row['native_node_weight16']['path'])).astype(float)/65535
neck=np.array(prep['actual_landmark_controls_from_basis']['neck']);waist=np.array(prep['actual_landmark_controls_from_basis']['waist']);hem=np.array(prep['actual_landmark_controls_from_basis']['hem'])

def smooth(t):t=np.clip(t,0,1);return t*t*(3-2*t)
def sampleweight(name,x,y):return map_coordinates(weights[name],[y,x],order=1,mode='constant',cval=0,prefilter=False)
def field(x,y,p):
 vol=sampleweight('original-corset-thorax-surface',x,y);axis=neck[0]+(waist[0]-neck[0])*(y-neck[1])/(waist[1]-neck[1]);dx=p['thorax_amplitude']*(x-axis)/78*vol;dy=-.4*p['thorax_amplitude']*vol
 hw=sampleweight('complete-head-bun-ribbon-neck-transition',x,y);ang=math.radians(p['neck_angle_deg']);ca=math.cos(ang);sa=math.sin(ang);hx=x-neck[0];hy=y-neck[1]
 dx+=((ca-1)*hx-sa*hy)*hw;dy+=(sa*hx+(ca-1)*hy)*hw
 cloth=sampleweight('original-upper-skirt-and-coat-lag',x,y);dx+=p['cloth_delta'][0]*cloth;dy+=p['cloth_delta'][1]*cloth
 guard=map_coordinates(safe,[y+PAD,x+PAD],order=1,mode='constant',cval=0,prefilter=False)
 return dx*guard,dy*guard

def sample_rgba(im,sx,sy):
 z=np.asarray(im).astype(float)/255.;a=z[:,:,3];w=map_coordinates(a,[sy,sx],order=1,mode='constant',cval=0,prefilter=False);rgb=np.stack([map_coordinates(z[:,:,k]*a,[sy,sx],order=1,mode='constant',cval=0,prefilter=False)for k in range(3)],2);rgb=np.divide(rgb,w[:,:,None],out=np.zeros_like(rgb),where=w[:,:,None]>1e-8);return Image.fromarray(np.uint8(np.clip(np.dstack([rgb,w])*255+.5,0,255)),'RGBA')
def boneA(a,b,c,d):
 a,b,c,d=map(lambda z:np.asarray(z,float),(a,b,c,d));u=(b-a)/np.linalg.norm(b-a);v=(d-c)/np.linalg.norm(d-c);a0=np.array([-u[1],u[0]]);a1=np.array([-v[1],v[0]])
 return np.column_stack([v*np.linalg.norm(d-c)/np.linalg.norm(b-a),a1])@np.column_stack([u,a0]).T
fdir=(W-E)/np.linalg.norm(W-E)
def arm_forward(x,y,p):
 es=np.array(p['LEFT_elbow']);ws=np.array(p['LEFT_wrist']);a=boneA(S,E,S,es);b=boneA(E,W,es,ws)
 ux=S[0]+a[0,0]*(x-S[0])+a[0,1]*(y-S[1]);uy=S[1]+a[1,0]*(x-S[0])+a[1,1]*(y-S[1]);fx=es[0]+b[0,0]*(x-E[0])+b[0,1]*(y-E[1]);fy=es[1]+b[1,0]*(x-E[0])+b[1,1]*(y-E[1]);t=smooth(((x-E[0])*fdir[0]+(y-E[1])*fdir[1]+16)/32)
 return ux*(1-t)+fx*t,uy*(1-t)+fy*t
frames=[]
for i in range(6):
 theta=2*math.pi*i/6;amp=3.3*(1-math.cos(theta));lag=math.sin(theta-math.pi/3)
 p=dict(thorax_amplitude=amp,neck_angle_deg=.45*math.sin(theta-math.pi/3),cloth_delta=[3.2*lag,1.5*math.sin(theta-math.pi/2)],LEFT_proximal_anchor=S.tolist(),LEFT_elbow=(E+np.array([-1+.3*amp+.7*math.sin(theta),3-.38*amp])).tolist(),LEFT_wrist=(W+np.array([-9+.55*amp+1.1*math.sin(theta),11-.6*amp+.8*math.sin(theta)])).tolist())
 sx=nx.copy();sy=ny.copy()
 for _ in range(8):dx,dy=field(sx,sy,p);sx=nx-dx;sy=ny-dy
 body=sample_rgba(bodyinput,sx+PAD,sy+PAD);ax=nx.copy();ay=ny.copy()
 for _ in range(10):qx,qy=arm_forward(ax,ay,p);ax=nx-(qx-ax);ay=ny-(qy-ay)
 node=sample_rgba(arm,ax+PAD,ay+PAD);body.alpha_composite(node);a=np.array(body);a[protected]=original[protected];body=Image.fromarray(a)
 f=D/f'thunder_female-SE-IDLE-{i}-actual-native-breath-relax-v01.png';body.save(f);node.save(D/f'phase{i}-actual-complete-LEFT-curved-cuff-hand-node.png');assert np.array_equal(a[protected],original[protected])
 cc,count=label(a[:,:,3]>=100);sz=np.bincount(cc.ravel());comps=[]
 for k in np.flatnonzero(sz>=200):
  if k:y,x=np.where(cc==k);comps.append(dict(pixels=int(sz[k]),bbox=[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]))
 assert len(comps)==1,(i,comps)
 px=np.array([650.,715.,765.]);py=np.full(3,430.);dx,dy=field(px,py,p)
 frames.append(dict(phase=i,**pin(f),pose_nodes=p,actual_intrinsic_chest_source_points=[dict(source=[float(x),430.],displacement=[float(a),float(b)])for x,a,b in zip(px,dx,dy)],original_RIGHTgear_and_complete_lowerbody_RGBA_changes=0,actual_LEFT_node=pin(D/f'phase{i}-actual-complete-LEFT-curved-cuff-hand-node.png'),body_components_alpha100_4conn_gte200=comps,quality='PENDING_INDEPENDENT_ACTUAL_SE_IDLE_SOURCE_AND_1P2SECOND_LOOP'))
assert len({r['sha256']for r in frames})==6
out=dict(status='ACTUAL_OWN_SE_IDLE6_DEDICATED_BREATH_RELAX_HEAD_CLOTH_PENDING_SOURCE_LOOP_QA',actor_id=413,direction='SE',action='idle',loop=True,loop_seconds=1.2,physical_canvas_fixed=C,body_unit_fixed=UNIT,logical_canvas=1024,common_rig_root_in_unpadded_frame=ROOT,storage_translation=reg['production_storage_translation'],storage_size=[N,N],shared_basis=pin(REG),shared_basis_independent_SOURCE_PASS=pin(QC),shared_basis_independent_numeric_PASS=pin(NUMERIC),base_native_source=pin(sourcepath),actual_material_handoff=pin(H),original_node_material_and_weight_INPUT=pin(PREP),actual_complete_LEFT_material=pin(armpath),LEFT_old_erased_body_input=pin(bodypath),original_RIGHTgear_mask=pin(protectpath),exact_storage_protection_mask=pin(D/'exact-original-RIGHTgear-and-complete-lowerbody-preservation-mask.png'),source_native_controls=dict(LEFT_proximal=S.tolist(),LEFT_cuff_interface_approx=E.tolist(),LEFT_wrist=W.tolist(),neck=neck.tolist(),waist=waist.tolist(),hem=hem.tolist()),scope='Own SE source materials, no E/N whole-image mirror or reuse. Original actual RGBA, dedicated continuous cuff two-node pose and intrinsic rib expansion/neck/cloth. All source-original feet and anatomical RIGHT gear are exact.',new_services=0,new_author_images=0,private_context_bytes_unchanged=5538937,source_resample_or_perpose_C_root_fitting=False,old_profiles_sources_and_approved_clips_modified=False,actor_approvals_added=0,frames=frames)
f=D/'SE-IDLE-six-actual-native-source-fixed-basis-and-loop-contract-v01.json';f.write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(dict(contract=pin(f),actual6=True,distinct6=True,all_strong_body_counts=[len(r['body_components_alpha100_4conn_gte200'])for r in frames],RIGHTgear_lowerbody_RGBA_changes=0)))
