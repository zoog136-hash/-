from pathlib import Path
import json,hashlib,math
import numpy as np
from PIL import Image

B=Path(__file__).parent;D=B/'actual-NE-IDLE-six-native-v02';O=B/'NE-IDLE-original-neutral-chosen-material-floor-parts-v01';O.mkdir()
CAM=.45;ROOT=np.array([716.2291666666666,1054.2766007046484]);P=128
cp=D/'actual-NE-IDLE-six-source-contract-v02.json';c=json.loads(cp.read_text())
hp=Path('/workspace/scratch/mythic413-NE-walk-author-20261020-v01/NE-RUN-source-material-handoff-v01.json');h=json.loads(hp.read_text());sp=Path(h['basis_actual_identity_source0']['path']);source=np.array(Image.open(sp).convert('RGBA'))
def stamp(p):return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def project(v):return np.array([v[0],ROOT[1]+CAM*v[1]-v[2]])
def check(a,mask,sa,A,U,V,guard):
 y,x=np.where((a[:,:,3]>0)&mask);local=U[2]*(x-sa[0])+V[2]*(y-sa[1]);z=A[2]+local
 minimum=float(z.min()-.5*(abs(U[2])+abs(V[2]))-guard)
 assert minimum>=-1e-9
 return dict(all_alpha_gt0_texel_count=len(x),native_texel_quad_plus_guard_min_Z=minimum,guard_native=guard,all_texel_quads_included=True)
def choose_sole_plane(heel,ball,mask):
 heel=np.array(heel);ball=np.array(ball);e=(ball-heel)/np.linalg.norm(ball-heel);n=np.array([-e[1],e[0]])
 T=np.array([e[0],e[1]/CAM,0.])
 W=np.linalg.solve(np.array([[1.,0,0],[0,CAM,-1],T/np.linalg.norm(T)]),np.r_[n,0.])
 U=T*e[0]+W*n[0];V=T*e[1]+W*n[1]
 assert np.max(np.abs(np.array([[U[0],V[0]],[CAM*U[1]-U[2],CAM*V[1]-V[2]]])-np.eye(2)))<1e-10
 assert abs((U*(ball[0]-heel[0])+V*(ball[1]-heel[1]))[2])<1e-9
 y,x=np.where(mask);local=U[2]*(x-heel[0])+V[2]*(y-heel[1]);guard=2.
 # Select exactly once for this unchanged neutral material, never per pose.
 # Visible painted sole surface and its finite camera-ray thickness are distinct.
 H=max(6.,guard+.5*(abs(U[2])+abs(V[2]))-float(local.min())+1.)
 A=np.array([heel[0],(heel[1]-ROOT[1]+H)/CAM,H])
 heel_support=np.array([heel[0],(heel[1]-ROOT[1])/CAM,0.]);ball_support=np.array([ball[0],(ball[1]-ROOT[1])/CAM,0.])
 assert np.max(np.abs(project(A)-heel))<1e-9
 assert np.max(np.abs(project(heel_support)-heel))<1e-9 and np.max(np.abs(project(ball_support)-ball))<1e-9
 return dict(visible_heel_native=heel.tolist(),visible_forefoot_ball_native=ball.tolist(),source_plane_anchor_world=A.tolist(),source_U=U.tolist(),source_V=V.tolist(),visible_sole_paint_height_native=H,ground_heel_support_world=heel_support.tolist(),ground_ball_support_world=ball_support.tolist(),fixed_camera_ray_support_thickness_vector=(A-heel_support).tolist(),fixed_camera_ray_support_thickness_length=float(np.linalg.norm(A-heel_support)),ground_control_projection_residual=0.,sole_longitudinal_world_axis=T.tolist(),native_guard=guard,scope='A single compatible neutral source-plane capture plus finite occluded sole material thickness; not a unique recovered foot mesh or a per-pose footfit.')
mask_union=np.zeros(source.shape[:2],bool);soles=[];parts=[]
for side,key,heel,ball in [('R','RIGHT_leg_boot_native_material_staff_speck_removed',[799.5,1028],[841,1011]),('L','LEFT_leg_boot_native_material',[527.5,1187],[575,1183])]:
 e=h[key];p=Path(e['path']);assert hashlib.sha256(p.read_bytes()).hexdigest()==e['sha256'];a=np.array(Image.open(p).convert('RGBA'));mask=a[:,:,3]>0
 assert not np.any(mask&mask_union);assert np.array_equal(a[mask],source[mask]);mask_union|=mask
 model=choose_sole_plane(heel,ball,mask);model.update(side=side,original_actual_material=stamp(p),source=check(source,mask,np.array(heel),np.array(model['source_plane_anchor_world']),np.array(model['source_U']),np.array(model['source_V']),2.))
 m=O/f'original-neutral-{side}-complete-native-visible-boot-exact-alpha-mask.png';Image.fromarray((mask*255).astype('uint8')).save(m);model['exact_native_alpha_support_mask']=stamp(m);soles.append(model);parts.append(stamp(m))
remainder=(source[:,:,3]>0)&~mask_union
body_anchor=np.array([ROOT[0],180.,CAM*180.]);body_sa=ROOT.copy();body_U=np.array([1.,0,0]);body_V=np.array([0.,0,-1.])
body_source=check(source,remainder,body_sa,body_anchor,body_U,body_V,8.)
rows=[]
for f in c['frames']:
 a=np.array(Image.open(f['path']).convert('RGBA').crop((P,P,P+1254,P+1254)));row=dict(phase=f['phase'],shoes=[])
 for sole in soles:
  mask=np.array(Image.open(sole['exact_native_alpha_support_mask']['path']).convert('L'))>0
  assert np.array_equal(a[mask],source[mask]);q=check(a,mask,np.array(sole['visible_heel_native']),np.array(sole['source_plane_anchor_world']),np.array(sole['source_U']),np.array(sole['source_V']),2.);q.update(side=sole['side'],all_original_boot_RGBA_bitexact=True);row['shoes'].append(q)
 remainder=(a[:,:,3]>0)&~mask_union;row['all_remaining_body_hand_coat_ribbon_entire_staff_texels']=check(a,remainder,body_sa,body_anchor,body_U,body_V,8.)
 assert sum(q['all_alpha_gt0_texel_count']for q in row['shoes'])+row['all_remaining_body_hand_coat_ribbon_entire_staff_texels']['all_alpha_gt0_texel_count']==int(np.sum(a[:,:,3]>0));row['every_actual_alpha_gt0_texel_assigned_exactly_once']=True;row['storage_only_translation']=[P,P];rows.append(row)
proof=dict(status='EXPLICIT_ONCE_CHOSEN_ORIGINAL_NE_NEUTRAL_MATERIAL_SUPPORT_AND_SIX_ACTUAL_RASTER_FLOOR_BINDING_PENDING_INDEPENDENT_QC',contract=stamp(cp),original_source=stamp(sp),native_C=2432,bodyunit=2.375,common_unpadded_root=ROOT.tolist(),original_native_pose_or_density_changed=False,source_or_whole_actor_scaled=False,perpose_C_rootfit=False,projection='screen=(X,1054.2766007046484 + .45*D - Z), native units; fixed chosen 2.5D material model only',shoe_capture_models=soles,all_remaining_material_capture_plane=dict(source_anchor=body_sa.tolist(),world_anchor=body_anchor.tolist(),U=body_U.tolist(),V=body_V.tolist(),source_native_RGBA=body_source,guard_including_entire_original_staff=8.),phases=rows,actual_original_sole_points_scope=['RIGHT original semantic heel799.5,1028 and black outsole ball841,1011 from retained native source handoff.','LEFT original gold stiletto tip527.5,1187 from handoff; visible original forefoot black outsole ball575,1183 authored from native source surface.','The fixed finite sole paint-to-ground thickness is along the exact camera-null ray, so ground contacts retain the original projected native heel/ball. It is chosen once and shared unchanged by all6.'],limits=['This bounds a single compatible collection of source-capture material surfaces; hidden unique anatomy or bone lengths cannot be inferred from one unchanged 2D stance.','The two visible full-boot material capture planes and original body/staff plane are distinct. Occluded joins can be connected along finite same-projection camera-ray ruled seams between positive-height surfaces; no new painted material, root, scale or stance adjustment is asserted.','Actual boot geometry and all original RGBA remain bitexact. The finite hidden sole thickness model is declared, not presented as a measured bitmap vertex.','All alpha>0 original/raster texel quads and guards are counted. Sole support groundcontrols are explicit authoring controls, and no global alpha-height floor is assumed.'],loop=dict(cycle_seconds=1.2,phase_seconds=.2,resource_fps=5.,loop=True,profile_modified=False,original_static_gear_and_shoe_planes_unchanged_all6=True),parts=parts,actor_approvals_added=0,game_clips_adopted=0)
target=B/'NE-IDLE-v02-original-neutral-material-sole-staff-and-whole-six-floor-binding-v01.json';assert not target.exists();target.write_text(json.dumps(proof,indent=2)+'\n');minimum=min(q['native_texel_quad_plus_guard_min_Z']for r in rows for q in r['shoes']+[r['all_remaining_body_hand_coat_ribbon_entire_staff_texels']]);print(json.dumps(dict(proof=stamp(target),all6_every_actual_alpha_gt0_texel_assigned=True,minimum_guarded_Z=minimum,paint_sole_heights=[x['visible_sole_paint_height_native']for x in soles])))
