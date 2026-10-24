from pathlib import Path
import ast, hashlib, json, math
import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates
from scipy.spatial.transform import Rotation

B=Path(__file__).parent
D=B/'actual-N-IDLE-six-native-v03'
O=B/'N-IDLE-v03-editable-bound-parts-and-floor-v01'
O.mkdir()
N=1536;P=128;CAM=.45;ROOTY=917.6920531878804
rp=B/'author-N-IDLE-dedicated-native-breath-finger-cloth-six-v03.py'
cp=D/'actual-N-IDLE-six-source-contract-v03.json'
c=json.loads(cp.read_text())
# Extract only immutable pure authoring helpers; no author top-level/file mutation.
names={'blank','native','proj','plane','affine_bone','smooth01','breath_displacement','warp_surface','pbody'}
tree=ast.parse(rp.read_text())
defs=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in names]
assert {n.name for n in defs}==names
exec(compile(ast.Module(body=defs,type_ignores=[]),str(rp),'exec'))
manifest=Path(c['input_manifest']['path'])
assert hashlib.sha256(manifest.read_bytes()).hexdigest()==c['input_manifest']['sha256']
images={}
for f in json.loads(manifest.read_text())['files']:
 p=Path(f['path']);assert hashlib.sha256(p.read_bytes()).hexdigest()==f['sha256'];images[p.name]=Image.open(p).convert('RGBA')
def read(name):return Image.open(D/name).convert('RGBA')
def unpad(im):return im.crop((P,P,P+1254,P+1254)) if im.size==(N,N) else im
def audit(source,sa,wa,U,V,raster,guard):
 source=unpad(source);sa=np.array(sa);wa=np.array(wa);U=np.array(U);V=np.array(V)
 sy,sx=np.where(np.array(source)[:,:,3]>0)
 z=wa[2]+U[2]*(sx-sa[0])+V[2]*(sy-sa[1]);smin=float(z.min()-.5*(abs(U[2])+abs(V[2]))-guard)
 ry,rx=np.where(np.array(raster)[:,:,3]>0)
 M=np.array([[U[0],V[0]],[CAM*U[1]-U[2],CAM*V[1]-V[2]]]);ii=np.linalg.inv(M)
 grad=np.array([U[2],V[2]])@ii
 rz=wa[2]+grad@np.stack([rx-P-proj(wa)[0],ry-P-proj(wa)[1]])
 rmin=float(rz.min()-.5*(abs(grad[0])+abs(grad[1]))-guard)
 assert min(smin,rmin)>=-1e-8,(smin,rmin)
 return dict(all_source_alpha_gt0=len(sx),all_raster_alpha_gt0=len(rx),source_texel_quad_guard_min_Z=smin,raster_texel_quad_guard_min_Z=rmin,guard=guard,source_anchor=sa.tolist(),world_anchor=wa.tolist(),U=U.tolist(),V=V.tolist(),above_floor=True)
files=[]
def save(im,name):
 p=O/(name+'.png');im.save(p);files.append(dict(path=str(p),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()));return p
def bone_basis(sa,sb,A,B,parity):
 sa=np.array(sa);sb=np.array(sb);A=np.array(A);B=np.array(B);sv=sb-sa;sl=np.linalg.norm(sv);sn=np.array([-sv[1],sv[0]])/sl
 pv=proj(B)-proj(A);tn=np.array([-pv[1],pv[0]])/np.linalg.norm(pv);bv=B-A
 W=np.linalg.solve(np.array([[1.,0,0],[0,CAM,-1],bv/np.linalg.norm(bv)]),np.r_[tn/parity,0.])
 U=bv*sv[0]/sl**2+W*sn[0];V=bv*sv[1]/sl**2+W*sn[1]
 assert np.max(np.abs(np.array([[U[0],V[0]],[CAM*U[1]-U[2],CAM*V[1]-V[2]]])@sv-pv))<1e-8
 return U,V
HIP=np.array([663.,180.,385.]);U0=np.array([1.,0,0]);VV=np.array([0.,0,-1]);V0=np.array([0.,2*CAM/(1+CAM*CAM),(CAM*CAM-1)/(1+CAM*CAM)]);normal=np.cross(U0,V0)
sourceworld=lambda x,y:HIP+U0*(x-663)+VV*(y-620)
static=[];legs=blank();foot=read('native-original-complete-front-shoe-and-rounded-native-ankle.png')
theta=math.asin(-6.105/90);Vf=np.array([0,-math.sin(theta),-math.cos(theta)])/(1/1.035)
for side,q in c['exact_fixed_supported_leg_bones'].items():
 hip=np.array(q['hip']);knee=np.array(q['knee']);ankle=np.array(q['ankle']);heel=np.array(q['heel']);par=-1 if side=='L' else 1
 assert abs(np.linalg.norm(knee-hip)-187.5)<1e-9 and abs(np.linalg.norm(ankle-knee)-187.5)<1e-9
 assert abs(q['toe'][2])<1e-9
 leg=blank()
 for part,sa,sb,A,Z,parity in [('native-thigh-material.png',[687,631],[679,787],hip,knee,par),('native-calf-material.png',[679,787],[678,895],knee,ankle,par/.8),('native-rounded-knee-leather-material.png',[679,787],[679,809],knee,knee+22*(ankle-knee)/np.linalg.norm(proj(ankle)-proj(knee)),par)]:
  src=images[part];U,V=bone_basis(sa,sb,A,Z,parity);r=affine_bone(src,sa,sb,proj(A),proj(Z),parity);leg.alpha_composite(r);save(r,f'fixed-{side}-{Path(part).stem}-bound-raster');a=audit(src,sa,A,U,V,r,2.);a.update(side=side,part=part,finite_flexible_material_bone_surface=True);static.append(a)
 fU=U0*(-1 if side=='R' else 1);r=plane(native(foot),[616.5,850],heel,fU,Vf);leg.alpha_composite(r);save(r,f'fixed-{side}-actual-complete-frontshoe-bound-raster');a=audit(foot,[616.5,850],heel,fU,Vf,r,2.);a.update(side=side,part='complete-original-rounded-frontshoe',structural_heel=heel.tolist(),hidden_foretoe_rig_control=q['toe'],toe_is_measured_visible_bitmap_vertex=False,capture_g=1/1.035);static.append(a)
 expected=read(f'fixed-neutral-{side}-complete-native-supported-leg-and-stiletto.png');assert np.array_equal(np.array(leg),np.array(expected));legs.alpha_composite(leg)
fixedR=blank();Rshoulder=sourceworld(715,431);Relbow=sourceworld(748,520)
src=images['native-RIGHT-upperarm.png'];r=affine_bone(native(src),[715,431],[748,520],proj(Rshoulder),proj(Relbow));fixedR.alpha_composite(r);static.append(dict(part='RIGHT-upperarm',**audit(src,[715,431],Rshoulder,U0,VV,r,2.)))
src=images['native-RIGHT-complete-forearm-grip-full-restored-staff.png'];r=plane(native(src),[748,520],Relbow,U0,VV);fixedR.alpha_composite(r);save(r,'fixed-entire-RIGHT-grip-restored-shaft-both-staff-ends-bound-raster');static.append(dict(part='RIGHT-full-grip-staff',**audit(src,[748,520],Relbow,U0,VV,r,8.)))
assert np.array_equal(np.array(fixedR),np.array(read('fixed-RIGHTarm-grip-complete-original-gold-turquoise-staff.png')))
body=read('native-body-chest-bodice.png');head=read('native-main-head-bun.png');ribbon=read('native-free-outside-blue-ribbon.png');forepalm=read('native-LEFT-palm-and-forearm-with-finger-overlap.png');prox=read('native-LEFT-actual-proximal-fingers.png');dist=read('native-LEFT-actual-distal-fingers.png');jointskin=read('native-LEFT-actual-finger-joint-skin.png')
leftupper=images['native-LEFT-upperarm-native-curved-cuff.png'];rows=[];hip_rgba=[]
for f in c['frames']:
 ph=f['phase'];t=2*math.pi*ph/6;b=f['inhalation'];row=dict(phase=ph,seconds_range=f['seconds_range'],parts=[])
 parts=[];posed=warp_surface(body,lambda x,y:breath_displacement(x,y,b));r=plane(native(posed),[663,620],HIP,U0,VV);parts.append(r);save(r,f'phase{ph}-actual-local-breath-chest-bodice');row['parts'].append(dict(part='body-native-local-breath',**audit(posed,[663,620],HIP,U0,VV,r,2.)));hip_rgba.append(hashlib.sha256(np.array(posed)[585:].tobytes()).hexdigest())
 neck=sourceworld(*f['neck_native']);rot=Rotation.from_rotvec(normal*(-math.radians(f['head_node_angle']))).as_matrix();HU=rot@U0;HV=rot@V0
 r=plane(native(head),[642,397],neck,HU,HV);parts.append(r);save(r,f'phase{ph}-actual-independent-head-bun');row['parts'].append(dict(part='head',**audit(head,[642,397],neck,HU,HV,r,2.)))
 hdx,hdy=f['hair_delayed_tip'];hair=warp_surface(ribbon,lambda x,y:(hdx*smooth01((y-398)/86)**2,hdy*smooth01((y-398)/86)**2));r=plane(native(hair),[642,397],neck,HU,HV);parts.append(r);save(r,f'phase{ph}-actual-free-ribbon-lag');row['parts'].append(dict(part='ribbon',**audit(hair,[642,397],neck,HU,HV,r,2.)))
 q=f['LEFTarm'];A=np.array(q['shoulder']);E=np.array(q['elbow']);LU=np.array(q['forearm_rigid_U']);LV=np.array(q['forearm_rigid_V']);U,V=bone_basis([574,433],[556,523],A,E,1);upper=affine_bone(native(leftupper),[574,433],[556,523],proj(A),proj(E));row['parts'].append(dict(part='LEFT-upperarm',**audit(leftupper,[574,433],A,U,V,upper,2.)))
 curl1=q['proximal_finger_degrees'];curl2=q['distal_finger_degrees'];hand=forepalm.copy();hand.alpha_composite(prox.rotate(curl1,resample=Image.Resampling.BICUBIC,center=(484,632)));dd=dist.rotate(curl2,resample=Image.Resampling.BICUBIC,center=(494,632));dd=dd.rotate(curl1,resample=Image.Resampling.BICUBIC,center=(484,632));hand.alpha_composite(dd);hand.alpha_composite(jointskin.rotate(curl1,resample=Image.Resampling.BICUBIC,center=(484,632)));r=plane(native(hand),[556,523],E,LU,LV);upper.alpha_composite(r);assert np.array_equal(np.array(upper),np.array(read(f'N-idle-phase{ph}-actual-LEFT-cuff-hand-articulated-finger-parts.png')));row['parts'].append(dict(part='LEFT-real-fingers-curved-cuff-forearm',**audit(hand,[556,523],E,LU,LV,r,2.)))
 cloth=[]
 for name in ['LEFT','RIGHT']:
  src=images[f'native-{name}-coat.png'];meta=next(x for x in f['coat'] if x['side']==name);dx=meta['free_tip_dx'];dy=meta['free_tip_dy'];rooty=meta['pinned_root_y'];src=warp_surface(src,lambda x,y:(dx*smooth01((y-rooty)/302)**2,dy*smooth01((y-rooty)/302)**2));r=plane(native(src),[663,620],HIP,U0,VV);cloth.append(r);save(r,f'phase{ph}-actual-{name}-coat-continuous-native-UV');row['parts'].append(dict(part=name+'-coat',**audit(src,[663,620],HIP,U0,VV,r,2.)))
 out=blank();out.alpha_composite(legs);out.alpha_composite(fixedR)
 for r in cloth+parts+[upper]:out.alpha_composite(r)
 original=Image.open(f['path']).convert('RGBA');assert np.array_equal(np.array(out),np.array(original));row['exact_RGBA_recomposition_matches_final_source']=True;rows.append(row)
assert len(set(hip_rgba))==1
def stamp(p):return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
proof=dict(status='ACTUAL_V03_EXACT_NATIVE_RIG_SOURCE_RASTER_FLOOR_LOOP_BINDING_PENDING_INDEPENDENT_QC',contract=stamp(cp),renderer=stamp(rp),fixed_C=1920,bodyunit=1.875,common_unpadded_root=c['common_unpadded_root'],storage_translation=[P,P],source_scale_changes=0,one_constructive_compatible_model=True,model_limits=['Finite source surfaces and chosen native material planes do not uniquely recover hidden anatomy.','Occluded toe is an explicit rig control; a visible projected shoe pixel is not asserted to be the toe.','Native flexible leg leather is assigned to exact187.5 bones with an orthogonal source-normal surface; rigid complete counter/stiletto remains on the single frontshoe capture plane.','All source/raster alpha>0 texel quads and the declared guard are included; no threshold is relaxed.'],static_parts=static,phases=rows,pinned_hip_lower_bodice_RGBA_equal_all6=True,pinned_hip_lower_bodice_RGBA_sha256=hip_rgba[0],fixed_leg_RGBA_sha256=hashlib.sha256(np.array(legs).tobytes()).hexdigest(),fixed_RIGHT_grip_staff_RGBA_sha256=hashlib.sha256(np.array(fixedR).tobytes()).hexdigest(),clock=dict(cycle_seconds=1.2,phase_seconds=.2,resource_fps=5,loop=True,profile_modified=False),loop=dict(body_head_ribbon_cloth_analytic_periodic_at_phase6_equals0=True,actual_finger_keyframe_sequence_proximal=[0,2,5,7,4,1,0],actual_finger_keyframe_sequence_distal=[0,3,8,10,5,1.5,0],phase5_to0_is_required_actual_discrete_game_transition=True),editable_actual_bound_raster_parts=files,actor_approvals_added=0,game_clips_adopted=0)
target=B/'N-IDLE-v03-whole-actual-native-source-raster-floor-and-loop-binding-v01.json';assert not target.exists();target.write_text(json.dumps(proof,indent=2)+'\n');print(json.dumps(dict(proof=stamp(target),minimum_guarded_Z=min(x[k]for x in static+[p for r in rows for p in r['parts']]for k in ['source_texel_quad_guard_min_Z','raster_texel_quad_guard_min_Z']),parts=len(files),exact_RGBA_all6=True)))
