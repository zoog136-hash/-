from pathlib import Path
from PIL import Image
from scipy.ndimage import map_coordinates,label
import numpy as np,json,hashlib,ast,math

D=Path(__file__).parent;O=D/'actual-E-HIT6-own-native-articulated-v03';O.mkdir(exist_ok=False)
REG=D/'E-new-native-one-time-body-density-C2816-root-registration-v01.json'
HAND=Path('/workspace/scratch/mythic413-E-attack-author-20261020-v01/common-own-E-native-arm-staff-materials-v03r1/E-own-native-complete-arm-staff-and-LEFT-only-body-readonly-handoff-v03.json')
QCP=Path('/workspace/scratch/mythic413-E-base-independent-qc-20261020-v01/E-new-native-source-and-once-C2816-body-root-registration-PASS-v01.json')
reg=json.loads(REG.read_text());hand=json.loads(HAND.read_text())
def rec(p):
 p=Path(p);b=p.read_bytes();return dict(path=str(p),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b))
S=Path(reg['source']['path']);assert rec(S)==reg['source']==hand['source']
A=Path(hand['parts']['LEFT-far-complete-curved-cuff-forearm-free-hand']['path'])
BP=Path(hand['body_inputs']['LEFT-forearm-only-old-erased-BODY-with-original-RIGHT-staff-arms-and-boots']['body']['path'])
for item in [hand['parts']['LEFT-far-complete-curved-cuff-forearm-free-hand'],hand['body_inputs']['LEFT-forearm-only-old-erased-BODY-with-original-RIGHT-staff-arms-and-boots']['body']]:assert rec(item['path'])==item
source=Image.open(S).convert('RGBA');src=np.array(source);arm=Image.open(A).convert('RGBA');base=np.array(Image.open(BP).convert('RGBA'));H,W=src.shape[:2]
C=reg['new_E_fixed_C'];UNIT=reg['new_E_fixed_bodyunit'];ROOT=reg['common_rig_root_in_unpadded_frame'];PAD=np.asarray(reg['production_storage_translation'],float);SIZE=1536;scale=UNIT/2.375
yy,xx=np.indices((H,W));fixedlegs=(yy>=1040)|((yy>=700)&(xx>=530)&(xx<=930))
rightprotect=np.zeros((H,W),bool)
for name in ['RIGHT-near-complete-forearm-grip-hand','complete-rigid-RIGHT-near-staff']:
 rightprotect|=np.asarray(Image.open(hand['parts'][name]['path']))[:,:,3]>0
Image.fromarray(fixedlegs.astype('uint8')*255).save(O/'original-E-two-leg-boot-fixed-native-conservative-region.png')
Image.fromarray(rightprotect.astype('uint8')*255).save(O/'original-E-complete-RIGHT-foregrip-hand-staff-exact-native-semantic-protection.png')

def smooth(t):
 t=np.clip(t,0,1);return t*t*(3-2*t)
phases=[
 dict(role='stable_guard',head=[0.,1.],angle=0.,guard_deg=23.,guard_length=167.,cloth=[0.,0.],ribbon=[0.,0.]),
 dict(role='impact_response',head=[-14.,15.],angle=-2.5,guard_deg=-25.,guard_length=164.,cloth=[4.,3.],ribbon=[2.,1.]),
 dict(role='maximum_recoil',head=[-29.,32.],angle=-5.2,guard_deg=-50.,guard_length=162.,cloth=[11.,5.],ribbon=[7.,2.]),
 dict(role='counterbalance',head=[-17.,13.],angle=-2.,guard_deg=-32.,guard_length=165.,cloth=[14.,2.],ribbon=[10.,1.]),
 dict(role='regaining_control',head=[-4.,3.],angle=.6,guard_deg=18.,guard_length=165.,cloth=[6.,-1.],ribbon=[4.,-1.]),
 dict(role='regained_guard_settled',head=[2.,-2.],angle=1.,guard_deg=28.,guard_length=158.,cloth=[-4.,2.],ribbon=[-2.,-1.]),
]
def field(x,y,p):
 # Direction-specific E anatomy: actual RIGHT weapon is left/near. Its whole
 # foregrip is fixed, while the chest and free far arm yield on the other side.
 thorax=smooth((688-y)/310)*smooth((x-590)/160)
 skull=smooth((350-y)/60)*smooth((x-480)/128)*smooth((y-20)/80)
 spine=(1-skull)*thorax+skull
 dx=p['head'][0]*scale*spine;dy=p['head'][1]*scale*spine
 cranial=smooth((365-y)/95)*smooth((x-480)/128)*smooth((y-20)/80)
 ang=math.radians(p['angle']);px=x-700;py=y-315
 dx+=((math.cos(ang)-1)*px-math.sin(ang)*py)*cranial
 dy+=(math.sin(ang)*px+(math.cos(ang)-1)*py)*cranial
 # Native cloak folds outside the fixed anatomical legs. These fields taper
 # before the shaft/foot regions; no original shoe or heel is deformed.
 left=np.sin(np.pi*np.clip((x-450)/80,0,1))**2*np.sin(np.pi*np.clip((y-650)/390,0,1))**2
 left*=((x>450)&(x<530)&(y>650)&(y<1040))
 right=np.sin(np.pi*np.clip((x-935)/65,0,1))**2*np.sin(np.pi*np.clip((y-690)/350,0,1))**2
 right*=((x>935)&(x<1000)&(y>690)&(y<1040))
 lag=left+.65*right;dx+=p['cloth'][0]*lag;dy+=p['cloth'][1]*lag
 ribbon=np.sin(np.pi*np.clip((x-460)/190,0,1))**2*np.sin(np.pi*np.clip((y-225)/205,0,1))**2
 ribbon*=((x>460)&(x<650)&(y>225)&(y<430))
 dx+=p['ribbon'][0]*ribbon;dy+=p['ribbon'][1]*ribbon
 return dx,dy
def make_flow(p):
 # Exponentiate a local stationary velocity. The resulting material map
 # stays invertible even where a direct large displacement would fold.
 vx,vy=field(xx.astype(float),yy.astype(float),p);fx=vx/256.;fy=vy/256.
 for _ in range(8):
  coords=[yy+fy,xx+fx]
  nx=fx+map_coordinates(fx,coords,order=1,mode='nearest',prefilter=False)
  ny=fy+map_coordinates(fy,coords,order=1,mode='nearest',prefilter=False)
  fx,fy=nx,ny
 # These exact float32 fields are both stored and used for the actual render.
 fx=fx.astype('float32').astype(float);fy=fy.astype('float32').astype(float)
 det=(1+np.gradient(fx,axis=1))*(1+np.gradient(fy,axis=0))-np.gradient(fx,axis=0)*np.gradient(fy,axis=1)
 assert det.min()>0.01,float(det.min())
 return fx,fy,dict(scaling_squaring_steps=8,initial_velocity_divisor=256,minimum_dense_Jacobian_determinant=float(det.min()),maximum_native_displacement=float(np.maximum(abs(fx),abs(fy)).max()),stored_precision='float32 exact render input')

def point_from_flow(p,fx,fy):
 coords=[[float(p[1])],[float(p[0])]]
 return p+np.array([map_coordinates(fx,coords,order=1,mode='nearest',prefilter=False)[0],map_coordinates(fy,coords,order=1,mode='nearest',prefilter=False)[0]])

def inverse(fx,fy):
 tx=xx.astype(float);ty=yy.astype(float);sx=tx.copy();sy=ty.copy()
 def value(x,y):
  c=[y,x];return map_coordinates(fx,c,order=1,mode='nearest',prefilter=False),map_coordinates(fy,c,order=1,mode='nearest',prefilter=False)
 for _ in range(18):
  dx,dy=value(sx,sy);rx=sx+dx-tx;ry=sy+dy-ty
  ex,ey=value(sx+.01,sy);hx,hy=value(sx,sy+.01)
  j00=1+(ex-dx)/.01;j10=(ey-dy)/.01;j01=(hx-dx)/.01;j11=1+(hy-dy)/.01;det=j00*j11-j01*j10
  stepx=(j11*rx-j01*ry)/det;stepy=(-j10*rx+j00*ry)/det
  damping=np.minimum(1.,8./np.maximum(np.maximum(abs(stepx),abs(stepy)),1e-9));sx-=damping*stepx;sy-=damping*stepy
 dx,dy=value(sx,sy);error=float(max(np.max(abs(sx+dx-tx)),np.max(abs(sy+dy-ty))))
 return sx,sy,error
def sample(a,sx,sy):
 pm=a.astype(float)/255;pm[:,:,:3]*=pm[:,:,3,None]
 v=np.stack([map_coordinates(pm[:,:,c],[sy,sx],order=1,mode='constant',cval=0,prefilter=False)for c in range(4)],axis=2);alpha=v[:,:,3]
 rgb=np.divide(v[:,:,:3],alpha[:,:,None],out=np.zeros_like(v[:,:,:3]),where=alpha[:,:,None]>1e-8)
 out=np.rint(np.dstack((rgb,alpha)).clip(0,1)*255).astype('uint8');identity=(abs(sx-xx)<1e-9)&(abs(sy-yy)<1e-9);out[identity]=a[identity];return out

RUN=Path('/workspace/scratch/mythic413-NE-run-author-20261020-v01');raster=RUN/'author-NE-run-contact0-actual-parts-v01.py';code=raster.read_text();tree=ast.parse(code)
nodes=[n for n in tree.body if isinstance(n,ast.FunctionDef)and n.name in {'bone_affine','forward_material'}]
ns=dict(np=np,Image=Image,json=json,hashlib=hashlib,SIZE=SIZE,PAD=PAD,W=W,H=H);exec(compile(ast.Module(nodes,[]),'actual-semantic-operator-definitions-only','exec'),ns);forward=ns['forward_material']
P0=np.asarray(hand['actual_native_controls']['LEFT_far_visible_proximal_anchor'],float);E0=np.asarray(hand['actual_native_controls']['LEFT_far_cuff_elbow'],float);W0=np.asarray(hand['actual_native_controls']['LEFT_far_wrist'],float)
frames=[]
for i,p in enumerate(phases):
 Q=O/f'phase{i}-actual-E-hit-{p["role"]}-v01';Q.mkdir(exist_ok=False);ns['Q']=Q
 flowx,flowy,flow_meta=make_flow(p);sx,sy,error=inverse(flowx,flowy);assert error<.0001,error
 assert np.max(abs(flowx[rightprotect]))<1e-9 and np.max(abs(flowy[rightprotect]))<1e-9
 flowfile=Q/'actual-E-native-body-causal-forward-material-flow-v03.npz';np.savez_compressed(flowfile,dX=flowx.astype('float32'),dY=flowy.astype('float32'))
 bodyrgba=sample(base,sx,sy);body=Image.new('RGBA',(SIZE,SIZE));body.alpha_composite(Image.fromarray(bodyrgba),tuple(PAD.astype(int)))
 pc=point_from_flow(P0,flowx,flowy);ec=point_from_flow(E0,flowx,flowy)
 theta=math.radians(p['guard_deg']);wc=ec+p['guard_length']*np.array([math.cos(theta),math.sin(theta)])
 moved=forward(arm,[P0,E0,W0],[pc,ec,wc],'LEFT-own-E-complete-curved-cuff-forearm-fingers-guard')
 out=moved.copy();out.alpha_composite(body);arr=np.array(out);nat=arr[128:128+H,128:128+W].copy()
 # Preserve true fixed native gear/stance at original coordinates, not by any
 # frame-dependent anchor, resizing or alpha-height adjustment.
 nat[fixedlegs|rightprotect]=src[fixedlegs|rightprotect];arr[128:128+H,128:128+W]=nat;out=Image.fromarray(arr)
 target=Q/f'thunder_female-E-hit-phase{i}-{p["role"]}-actual-native-v01.png';out.save(target);body.save(Q/'actual-E-head-thorax-clothing-ribbon-native-node-v01.png')
 c,n=label(arr[:,:,3]>100);sizes=np.bincount(c.ravel());big=sorted([int(s)for s in sizes[1:]if s>=200],reverse=True)
 f=dict(phase=i,role=p['role'],source=rec(target),native_size=[SIZE,SIZE],C=C,bodyunit=UNIT,common_rig_root_unpadded=ROOT,storage_translation=PAD.tolist(),stored_common_root=(np.asarray(ROOT)+PAD).tolist(),head_torso_velocity_parameter_native=(np.asarray(p['head'])*scale).tolist(),head_local_angular_velocity_parameter_degrees=p['angle'],LEFT_actual_source_knots=[P0.tolist(),E0.tolist(),W0.tolist()],LEFT_actual_guard_knots_unpadded=[pc.tolist(),ec.tolist(),wc.tolist()],LEFT_guard_target_angle=p['guard_deg'],LEFT_guard_projected_length=p['guard_length'],source_complete_LEFT_native_material=rec(A),actual_LEFT_guard_forward_mesh=rec(Q/'LEFT-own-E-complete-curved-cuff-forearm-fingers-guard-actual-forward-mesh.json'),cloth_lag_native=p['cloth'],ribbon_lag_native=p['ribbon'],body_inverse_maximum_residual=error,actual_body_forward_flow=rec(flowfile),body_flow_definition=flow_meta,fixed_original_complete_legs_boots_native_region_RGBA_changed=int(np.any(nat[fixedlegs]!=src[fixedlegs],axis=1).sum()),full_original_RIGHT_near_staff_and_foregrip_RGBA_changed=int(np.any(nat[rightprotect]!=src[rightprotect],axis=1).sum()),strong_alpha100_components_ge200=big,actor_approvals_added=0)
 (Q/'actual-E-HIT-phase-source-and-native-preservation-provenance-v01.json').write_text(json.dumps(f,indent=2)+'\n');frames.append(f);print(json.dumps(dict(phase=i,source=rec(target),inverse_residual=error,strong=big)),flush=True)
assert len({f['source']['sha256']for f in frames})==6,'Require six genuinely different authored phases'
contract=dict(schema='MYTHIC413_E_HIT_SIX_ACTUAL_OWN_NATIVE_SOURCE_V03',status='SIX_DISTINCT_ACTUAL_E_SOURCE_POSES_PENDING_INDEPENDENT_MOTION_SOURCE_GATE',direction='E',action='hit',source_identity=rec(S),once_body_registration=rec(REG),independent_base_source_body_gate=rec(QCP),shared_actual_LEFT_material_handoff=rec(HAND),actual_only_LEFT_erased_native_BODY=rec(BP),actual_semantic_rasterizer_definition=rec(raster),C=C,bodyunit=UNIT,common_rig_root_unpadded=ROOT,storage_translation=PAD.tolist(),native_size=[SIZE,SIZE],role_seconds=.22,phase_seconds=.22/6,frames=frames,six_distinct_source_SHA256=True,wholePNG_translate_rotate_recolor_or_mirror=False,original_E_approved_motion_reproduced=False,perpose_C_root_footfit_or_alphaheight_normalization=False,profile_or_Godot_hit_window_modified=False,source_cycle_or_game_approved=False,actor_approvals_added=0,completed_detailed_actors_unchanged=2)
cp=O/'E-HIT6-actual-own-native-body-head-LEFTguard-source-contract-v03.json';cp.write_text(json.dumps(contract,indent=2)+'\n');print(json.dumps(dict(contract=rec(cp),frames=len(frames))),flush=True)
board=Image.new('RGB',(1200,800),(125,125,125))
for f in frames:
 im=Image.open(f['source']['path']).convert('RGBA');im.thumbnail((400,390));cell=Image.new('RGBA',(400,400),(125,125,125,255));cell.alpha_composite(im,((400-im.width)//2,0));board.paste(cell.convert('RGB'),((f['phase']%3)*400,(f['phase']//3)*400))
pp=O/'private-E-HIT6-actual-six-body-head-guard-cloth-board-v01.jpg';board.save(pp,quality=77,optimize=True);assert pp.stat().st_size<150000
