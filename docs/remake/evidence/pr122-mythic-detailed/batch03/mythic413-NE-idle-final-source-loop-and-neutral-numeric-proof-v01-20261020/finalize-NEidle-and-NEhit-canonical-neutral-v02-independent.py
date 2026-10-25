from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image
from scipy.ndimage import label
B=Path('/workspace/scratch/mythic413-nw-n-walk-independent-qc-20261020')
A=Path('/workspace/scratch/mythic413-NE-idle-author-20261020-v01')
cp=A/'actual-NE-IDLE-six-native-v02/actual-NE-IDLE-six-source-contract-v02.json';fp=A/'NE-IDLE-v02-original-neutral-material-sole-staff-and-whole-six-floor-binding-v02.json'
hp=Path('/workspace/scratch/mythic413-NE-hit-author-20261020-v01/actual-NE-HIT6-own-native-settled-guard-v04/NE-HIT6-exact-original-neutral-boots-and-actual-six-material-floor-binding-v05.json')
def pin(p):
 p=Path(p);return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def check(q):
 assert pin(q['path'])['sha256']==q['sha256'];return Path(q['path'])
def save(n,x):
 p=B/n;assert not p.exists();p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n');return pin(p)
def arr(p):return np.array(Image.open(p).convert('RGBA'))
c=json.loads(cp.read_text());f=json.loads(fp.read_text());h=json.loads(hp.read_text())
assert pin(cp)['sha256']=='22c86b3f4802f4c9428180d653d7542f51ec2366af602c4d96c22ff572785307'
assert pin(fp)['sha256']=='f7562590cea4a246f8f67f3f5019c7c893e4c65da3eaadc38c87f50410967d19'
assert pin(hp)['sha256']=='917fba9cdcffb719db5c463531dcdcd324c8ffac3c9c1a7ef76e4290c1b30768'
assert check(h['neutral_once_capture_reference'])==fp
assert c['fixed_C']==f['native_C']==h['C']==2432 and c['bodyunit']==f['bodyunit']==h['bodyunit']==2.375
root=np.array(c['common_unpadded_root']);assert np.array_equal(root,f['common_unpadded_root']) and np.array_equal(root,h['common_unpadded_root'])
assert not c['profile_modified'] and c['storage_translation']==[128,128] and c['storage_canvas']==[1536,1536]
assert c['cycle_seconds']==1.2 and c['phase_seconds']==.2 and c['resource_fps']==5 and c['loop']
original=arr(check(f['original_source']));assert original.shape==(1254,1254,4)
run=json.loads(check(f['retained_NE_canonical_projection_and_RIGHT_HFA']).read_text());P=np.array([[10/9,0,0],[0,1,-1]])
assert np.max(abs(np.column_stack((f['shoe_capture_models'][0]['source_U'],f['shoe_capture_models'][0]['source_V']))-run['source_shoe_plane_lift']))<1e-12
assert not f['perpose_C_rootfit'] and not h['perpose_C_root_ground_or_foot_fit']
models=f['shoe_capture_models'];masks=[];source=[]
def bound(mask,sa,wa,U,V,g):
 y,x=np.where(mask);assert len(x)>0;U=np.array(U);V=np.array(V);wa=np.array(wa);sa=np.array(sa)
 assert np.max(abs(P@np.column_stack((U,V))-np.eye(2)))<1e-12
 assert np.max(abs(P@wa+root-sa))<1e-10
 return dict(alpha_positive_texel_count=len(x),centered_texel_quad_guard_min_Z=float(np.min(wa[2]+U[2]*(x-sa[0])+V[2]*(y-sa[1]))-.5*(abs(U[2])+abs(V[2]))-g))
for i,m in enumerate(models):
 assert h['shoe_capture_models'][i]['exact_original_foot_model']==m
 mask=np.array(Image.open(check(m['exact_native_alpha_support_mask'])))>0;assert mask.shape==original.shape[:2]
 material=arr(check(m['original_actual_material']));assert np.all(original[mask]==material[mask]) and np.all(original[mask,3]>0)
 masks.append(mask);H=np.array(m['visible_heel_native']);F=np.array(m['visible_forefoot_support_native']);A0=np.array(m['source_native_ankle']);wa=np.array(m['source_plane_anchor_world']);U=np.array(m['source_U']);V=np.array(m['source_V']);T=np.array(m['fixed_camera_ray_support_thickness_vector']);lift=lambda uv:wa+U*(uv[0]-H[0])+V*(uv[1]-H[1])
 assert np.max(abs(P@T))<1e-11 and T[2]>0
 assert np.max(abs(lift(H)-T-m['ground_heel_support_world']))<1e-10
 assert np.max(abs(lift(F)-T-m['ground_ball_support_world']))<1e-10
 assert abs((lift(A0)-lift(H))[2]-100)<1e-10
 assert max(abs((lift(H)-T)[2]),abs((lift(F)-T)[2]))<1e-10
 q=bound(mask,H,wa,U,V,2);assert abs(q['centered_texel_quad_guard_min_Z']-1)<1e-9
 source.append(dict(side=m['side'],mask=pin(m['exact_native_alpha_support_mask']['path']),material=pin(m['original_actual_material']['path']),**q,support_HF_groundZ=[float((lift(H)-T)[2]),float((lift(F)-T)[2])],camera_null_thickness_projection=(P@T).tolist(),ankle_relative_heel_height=float((lift(A0)-lift(H))[2])))
assert not np.any(masks[0]&masks[1]);rest=f['all_remaining_material_capture_plane'];assert rest==h['remaining_material_plane']
q=bound((original[:,:,3]>0)&~(masks[0]|masks[1]),rest['source_anchor'],rest['world_anchor'],rest['U'],rest['V'],8)
assert abs(q['centered_texel_quad_guard_min_Z']-114.77660070464844)<1e-9
source.append(dict(part='all_remaining_original_body_full_staff',**q))
for v in json.loads(check(c['input_manifest']).read_text())['files']:check(v)
def auditframes(frames,expected,kind):
 out=[]
 for i,s in enumerate(frames):
  if 'actual_source'in s:s=s['actual_source']
  check(s);a=arr(s['path']);assert a.shape==(1536,1536,4);native=a[128:1382,128:1382];outside=a.copy();outside[128:1382,128:1382]=0;assert not outside[:,:,3].any()
  shoes=[]
  for mask,m in zip(masks,models):
   assert np.array_equal(native[mask],original[mask]);q=bound(mask,m['visible_heel_native'],m['source_plane_anchor_world'],m['source_U'],m['source_V'],2);shoes.append(dict(side=m['side'],original_RGBA_mismatches=0,**q))
  maskrest=(native[:,:,3]>0)&~(masks[0]|masks[1]);q=bound(maskrest,rest['source_anchor'],rest['world_anchor'],rest['U'],rest['V'],8)
  assert q['centered_texel_quad_guard_min_Z']>0
  assert int((native[:,:,3]>0).sum())==sum(x['alpha_positive_texel_count']for x in shoes)+q['alpha_positive_texel_count']
  labs,n=label(a[:,:,3]>100);areas=np.bincount(labs.ravel())[1:];strong=[int(v)for v in areas if v>=200];assert len(strong)==1
  eq=expected[i];assert eq['phase']==i
  if kind=='idle':
   for u,v in zip(shoes,eq['shoes']):assert u['alpha_positive_texel_count']==v['all_alpha_gt0_texel_count'] and abs(u['centered_texel_quad_guard_min_Z']-v['native_texel_quad_plus_guard_min_Z'])<1e-9
   old=eq['all_remaining_body_hand_coat_ribbon_entire_staff_texels'];assert q['alpha_positive_texel_count']==old['all_alpha_gt0_texel_count']
  else:
   for u,v in zip(shoes,eq['shoes']):assert u['alpha_positive_texel_count']==v['actual_alpha_texel_quad_count'] and abs(u['centered_texel_quad_guard_min_Z']-v['all_centered_texel_quad_guarded_min_Z'])<1e-9
   old=eq['remaining_actual_head_torso_guard_legs_cloth_ribbon_fullstaff'];assert q['alpha_positive_texel_count']==old['alpha_texel_quad_count']
  out.append(dict(phase=i,source=pin(s['path']),rgba_sha256=hashlib.sha256(a.tobytes()).hexdigest(),unchanged_complete_boots=shoes,remaining_actual_all_painted_material=q,every_actual_alpha_positive_texel_assigned_exactly_once=True,strong_alpha100_4connected_components=strong,storage_translation=[128,128]))
 assert len(out)==6 and len({x['rgba_sha256']for x in out})==6;return out
rows=auditframes(c['frames'],f['phases'],'idle');hitrows=auditframes(h['frames'],h['frames'],'hit');check(h['exact_HIT_final_roster']);check(h['unchanged_original_native_identity'])
assert np.max(abs(np.array([x['inhalation']for x in c['frames']])-[0,.25,.75,1,.75,.25]))<1e-12
assert [x['LEFT_real_finger_proximal_degrees']for x in c['frames']]==[0,2,5,7,4,1]
assert [x['LEFT_real_finger_distal_degrees']for x in c['frames']]==[0,3,7,9,5,1.5]
limitations=['The declared fixed camera, source-capture surfaces and finite camera-null sole thickness construct one compatible neutral pose. They do not uniquely recover hidden anatomy, sole mesh, joint depths, or all leg bone lengths from one unchanged source.','Painted boot quads have at least1native guarded clearance; actual support H/F groundcontrols lie on Z0 through explicitly declared finite sole thickness, not measured hidden bitmap vertices. No per-pose root/scale/alpha-height fitting is used.','All remaining paint is bounded under one chosen positive-height capture plane. This finite material compatibility witness is separate from visible naturalness and actual game integration; it is not whole-actor physical completion.']
numeric=save('NEidle-f75625-NEhit-917fba-independent-canonical-neutral-material-floor-companion-v01.json',dict(status='PASS_FINITE_CANONICAL_NE_NEUTRAL_MATERIAL_AND_EXACT_SIX_SOURCE_BINDING',idle_contract=pin(cp),neutral_model=pin(fp),hit_model=pin(hp),canonical_prior_RIGHT_HFA=pin(f['retained_NE_canonical_projection_and_RIGHT_HFA']['path']),original=pin(f['original_source']['path']),P=P.tolist(),source_material_bounds=source,idle_actual_six=rows,hit_actual_six=hitrows,source_images_resampled=False,additional_private_image_views=0,limits=limitations,actor_approvals_added=0))
ledger=B/'private-image-ledger-through-NEidle-final-source-view80-frozen.json';assert pin(ledger)['sha256']=='cb6ede7d5b3b15368b3056d76afbde042082ffee4bb060ddb431e292b3624b5c'
cert=save('NEidle-v02-22c86b-independent-actual-source-loop-PASS-v01.json',dict(schema='PR122-independent-actual-NE-idle-six-source-loop-prepacking-v1',status='PASS_ACTUAL_NE_IDLE_SIX_LOCAL_BREATH_RELAX_AND_CONTINUOUS_LOOP_PREPACKING',source_visual_status='PASS',key='transform:413',direction='NE',role='idle',source_contract=pin(cp),all_six_independent_binding=rows,C_fixed=2432,bodyunit_fixed=2.375,common_rig_root=root.tolist(),storage_translation=[128,128],source_canvas=[1536,1536],loop=True,cycle_seconds=1.2,phase_seconds=.2,resource_fps=5,visual_findings=['Actual rear NE identity, bun/ribbons, gold-blue coat/white pleats, thigh-high boots and anatomical RIGHT near-hand gold-turquoise double-ended staff remain coherent and complete across all six.','Visible local bodice/corset expansion and shoulder lift ease into exhalation; real LEFT fingers curl and relax independently, with ribbon and splitcoat lag. This reads as quiet idle rather than whole-body translation or a movement clip.','The native LEFT cuff, hand and visible two-finger joints join continuously. Complete stationary boots/visible support, right grip and staff stay visually stable; no body/part pop or obvious seam appears in the source6 board or5-to0 wrap.','All six are distinct actual RGBA sources, each one strong connected body; original complete boot material is bitexact across all six. Fixed C2432, one root and common storage128 preserve the registered body density.'],visual_limitations=['Source review used one private bounded six-pose board plus native hand detail; no runtime animation was claimed or new screenshot generated.','Subtle idle motion is judged from authored phases and the visible5-to0 source wrap. Actual Godot clip/profile and game binding remain pending.']+limitations,finite_material_companion=numeric,immutable_private_image_ledger=pin(ledger),images_forwarded=0,actor_approvals_added=0))
print(json.dumps(dict(source_review=cert,numeric_companion=numeric,context_private_bytes=4385909,new_images=0)))
