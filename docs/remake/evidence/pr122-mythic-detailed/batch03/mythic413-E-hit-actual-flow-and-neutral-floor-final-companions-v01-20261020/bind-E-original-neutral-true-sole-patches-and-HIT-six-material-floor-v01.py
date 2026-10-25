from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image

D=Path(__file__).parent
R=D/'E-new-native-one-time-body-density-C2816-root-registration-v01.json'
C=D/'actual-E-HIT6-own-native-articulated-v03/E-HIT6-actual-own-native-body-head-LEFTguard-source-contract-v03.json'
O=D/'E-original-neutral-actual-sole-support-capture-parts-v01'
O.mkdir(exist_ok=False)
def rec(p):
 p=Path(p);b=p.read_bytes();return dict(path=str(p),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b))
r=json.loads(R.read_text());c=json.loads(C.read_text());sp=Path(r['source']['path']);s=np.asarray(Image.open(sp).convert('RGBA'))
assert rec(sp)==c['source_identity']==r['source']
root=np.asarray(r['common_rig_root_in_unpadded_frame']);pad=np.asarray(r['production_storage_translation']);px=10/9
H,W=s.shape[:2];yy,xx=np.indices((H,W));union=np.zeros((H,W),bool)
P=np.array([[px,0,0],[0,1,-1]],float)
def project(v):return root+P@v
def texel_check(a,m,heel,A,U,V,guard):
 y,x=np.where((a[:,:,3]>0)&m);z=A[2]+(x-heel[0])*U[2]+(y-heel[1])*V[2]
 minimum=float(z.min()-.5*(abs(U[2])+abs(V[2]))-guard)
 assert minimum>=0
 return dict(actual_alpha_gt0_texel_quad_count=len(x),all_centered_texel_quads_included=True,guard_native=guard,guarded_min_Z=minimum)
models=[]
for side,box,h,f,a in [('RIGHT-near-imageleft',[495,1040,655,1230],[522.,1201.5],[585.,1219.],[550.,1140.]),('LEFT-far-imageright',[820,1040,990,1230],[844.5,1197.],[929.,1201.],[885.,1135.])]:
 h=np.asarray(h);f=np.asarray(f);a=np.asarray(a);x0,y0,x1,y1=box
 # A native source-material capture assignment, not a cropped moving shoe.
 # These isolated boxes include the complete visible foot/counter/stiletto and
 # lower shaft. No source pixels are removed or transformed by this model.
 m=(xx>=x0)&(xx<x1)&(yy>=y0)&(yy<y1)&(s[:,:,3]>0)
 assert not np.any(m&union);union|=m
 g=np.linalg.solve(np.stack([f-h,a-h]),[0.,100.])
 U=np.array([1/px,g[0],g[0]]);V=np.array([0.,1+g[1],g[1]])
 assert np.max(np.abs(P@np.stack([U,V],axis=1)-np.eye(2)))<1e-12
 assert abs((U*(f[0]-h[0])+V*(f[1]-h[1]))[2])<1e-10
 assert abs((U*(a[0]-h[0])+V*(a[1]-h[1]))[2]-100)<1e-10
 y,x=np.where(m);local=(x-h[0])*U[2]+(y-h[1])*V[2];guard=2.
 paint=max(6.,guard+.5*(abs(U[2])+abs(V[2]))-float(local.min())+1.)
 A=np.array([(h[0]-root[0])/px,h[1]-root[1]+paint,paint])
 gh=np.array([(h[0]-root[0])/px,h[1]-root[1],0.]);gf=np.array([(f[0]-root[0])/px,f[1]-root[1],0.])
 assert np.max(np.abs(project(A)-h))<1e-10
 assert np.max(np.abs(project(gh)-h))<1e-10 and np.max(np.abs(project(gf)-f))<1e-10
 mp=O/f'{side}-original-native-sole-and-lowerboot-capture-support-mask.png';Image.fromarray(m.astype('uint8')*255).save(mp)
 ap=O/f'{side}-exact-original-native-sole-and-lowerboot-material.png';z=np.zeros_like(s);z[m]=s[m];Image.fromarray(z).save(ap)
 q=dict(side=side,observed_painted_heel_native=h.tolist(),heel_observation_uncertainty_native=2.,observed_painted_foreball_native=f.tolist(),foreball_observation_uncertainty_native=3.,ankle_proxy_native=a.tolist(),ankle_proxy_uncertainty_native=10.,chosen_ankle_relative_sole_height_native=100.,capture_assignment_box_native=box,exact_source_alpha_support=rec(mp),exact_original_native_material=rec(ap),source_plane_anchor_world=A.tolist(),source_U=U.tolist(),source_V=V.tolist(),once_visible_paint_sole_height_native=paint,physical_heel_support_world=gh.tolist(),physical_foreball_support_world=gf.tolist(),finite_paint_to_support_camera_null_vector=[0.,paint,paint],P_times_camera_null_vector=[0.,0.],source_material=texel_check(s,m,h,A,U,V,guard))
 models.append(q)
bodyA=np.array([0.,180.,180.]);bodyU=np.array([1/px,0,0]);bodyV=np.array([0.,0,-1.])
rows=[]
for f in c['frames']:
 p=Path(f['source']['path']);assert rec(p)==f['source'];full=np.asarray(Image.open(p).convert('RGBA'));a=full[128:128+H,128:128+W]
 assert np.count_nonzero(full[:,:,3])==np.count_nonzero(a[:,:,3])
 row=dict(phase=f['phase'],actual_source=f['source'],sole_capture_patches=[])
 for model in models:
  m=np.asarray(Image.open(model['exact_source_alpha_support']['path']))>0
  mismatch=int(np.any(a[m]!=s[m],axis=1).sum());assert mismatch==0
  q=texel_check(a,m,np.array(model['observed_painted_heel_native']),np.array(model['source_plane_anchor_world']),np.array(model['source_U']),np.array(model['source_V']),2.)
  q.update(side=model['side'],original_RGBA_mismatch=mismatch);row['sole_capture_patches'].append(q)
 remaining=(a[:,:,3]>0)&~union
 row['all_remaining_actual_material_including_entire_staff']=texel_check(a,remaining,root,bodyA,bodyU,bodyV,8.)
 assert sum(q['actual_alpha_gt0_texel_quad_count']for q in row['sole_capture_patches'])+row['all_remaining_actual_material_including_entire_staff']['actual_alpha_gt0_texel_quad_count']==int(np.count_nonzero(a[:,:,3]))
 row['every_actual_alpha_gt0_texel_assigned_exactly_once']=True;rows.append(row)
j=dict(schema='MYTHIC413_E_ORIGINAL_NEUTRAL_ONCE_CHOSEN_SOLE_AND_ACTUAL_HIT_MATERIAL_FLOOR_V01',status='FINITE_EXPLICIT_ONCE_MODEL_PENDING_INDEPENDENT_NUMERIC_AUDIT_NOT_UNIQUE_HIDDEN_ANATOMY',original_source=rec(sp),once_body_registration=rec(R),actual_HIT_source_contract=rec(C),C=r['new_E_fixed_C'],bodyunit=r['new_E_fixed_bodyunit'],common_unpadded_root=root.tolist(),storage_translation=pad.tolist(),projection_matrix=P.tolist(),projection_origin=root.tolist(),source_material_capture_models=models,remaining_material_capture_plane=dict(source_anchor=root.tolist(),world_anchor=bodyA.tolist(),U=bodyU.tolist(),V=bodyV.tolist(),native_guard=8.),actual_HIT_frames=rows,observed_support_semantics='Actual original gold stiletto heel ends and front black outsole foreball; not gold toe/counter ornaments or global lowest alpha. Markers were independently confirmed within stated observation uncertainty.',superseded_initial_locator_observations=dict(RIGHT_H=[522,1193],RIGHT_F=[586,1208],LEFT_H=[845,1188],LEFT_F=[934,1189],status='historical rejected locator proposals, never applied to source art'),scope_and_limits=['A finite compatible original static stance capture model, not uniquely recovered 3D bones, depth, or sole mesh. The ankle controls have explicit observation uncertainty and chosen100native capture height.','Painted support proxies are distinct from hidden ground support. Once-chosen finite camera-null sole thickness connects them without shifting, scaling, resampling or repainting any actual art.','All alpha>0 texel quads of both capture patches and every actual remaining six-frame material have finite positive bounds including guards. This does not replace actual source/joint/reaction or gameplay approval.','The capture boxes assign native material to planes; they are not newly extracted animation foot modules. Calf/true ankle/shoe motion semantics are not changed. Outside the two capture patches, including upper boot shafts, actual material uses a single fixed positive vertical capture plane. Occluded plane transitions can connect by same-projection finite ruled seams.','Physical ground controls are authoring controls in one stationary braced model shared unchanged by all six; no per-pose floor, foot, root, C or whole-alpha fit.'],source_changed=False,perpose_fit=False,actor_approvals_added=0)
out=D/'E-original-neutral-once-true-sole-and-HIT-six-material-floor-binding-v01.json';assert not out.exists();out.write_text(json.dumps(j,indent=2)+'\n')
print(json.dumps(dict(model=rec(out),source_changed=False,sole_paint_heights=[m['once_visible_paint_sole_height_native']for m in models],all_actual_source_RGBA_mismatches=0,all_remaining_material_min_Z=min(f['all_remaining_actual_material_including_entire_staff']['guarded_min_Z']for f in rows))))
