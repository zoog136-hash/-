from pathlib import Path
import json,hashlib,numpy as np
D=Path(__file__).parent;Q=D/'actual-NE-run-six-common-material-finish-v03';MP=D/'actual-NE-run-six-fixed-rig-v02/NE-run-six-actual-causal-rig-shoe-surface-and-source-contract-v02.json'
m=json.loads(MP.read_text());P=np.asarray(m['projection']);B=np.asarray(m['source_shoe_plane_lift']);H0=np.asarray(m['source_HFA_raw'][0]);PAD=np.asarray(m['storage_translation']);SRC=np.asarray(m['source_leg_raw']);v=SRC[2]-SRC[1]
def rec(p):
 b=p.read_bytes();return dict(path=str(p),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b))
frames=[];surface_frames=[]
for phase,f in enumerate(m['frames']):
 d=Q/f'phase{phase}-actual-common-finish-v03';p=d/f'thunder_female-NE-run-phase{phase}-actual-common-finish-v03.png';pp=d/'actual-common-material-finish-and-preservation-provenance-v03.json';j=json.loads(pp.read_text());assert j['unchanged_exact_frame_controls']==f['legs']
 assert j['protected_RGBA_mismatch']==0
 frames.append(dict(phase=phase,role=f['role'],source=rec(p),native_size=[1536,1536],C=2432,bodyunit=2.375,common_rig_root_unpadded=m['common_rig_root_unpadded'],storage_translation=m['storage_translation'],stored_common_rig_root=(np.asarray(m['common_rig_root_unpadded'])+PAD).tolist(),body_node_XYZ=f['body_node_XYZ'],body_node_raw=f['body_node_raw'],LEFT_free_arm_actual_source='Complete original cuff/elbow cap/forearm/hand; fixed proximal blue-elbow cap and genuinely articulated cloth/forearm counterphase',joint_controls_and_shoes=f['legs'],actual_material_finish_provenance=rec(pp),static_source_status='CONTACT0 independent common three-region source gate PASS; formal proof separate' if phase==0 else 'PENDING_INDEPENDENT_ACTUAL_SOURCE_GATE'))
 surfaces={}
 for side in ['R','L']:
  leg=f['legs'][side];A=np.asarray(leg['ankle']);K=np.asarray(leg['knee']);R=np.asarray(leg['rotation3D']);heel=np.asarray(leg['heel'])
  meshfile=d/(side+'-genuine-short-leather-tarsal-joint-actual-forward-mesh.json');mesh=json.loads(meshfile.read_text())
  cm=np.asarray(mesh['actual_proximal_calf_affine']['matrix']);co=np.asarray(mesh['actual_proximal_calf_affine']['offset_with_storage'])-PAD
  zc=(A[2]-K[2])*v/float(v@v);zo=A[2]-float(zc@SRC[2])
  C=np.array([.9*cm[0],cm[1]+zc,zc]);c=np.array([.9*(co[0]-H0[0]),co[1]-H0[1]+zo,zo])
  F=R@B;fo=heel-F@H0
  assert np.max(abs(P@C-cm))<1e-12 and np.max(abs(P@c+H0-co))<1e-10
  assert np.max(abs(P@F-np.asarray(leg['shoe_image_affine'])))<1e-12
  allZ=[];error=0.
  for cell in mesh['mesh']:
   for s,t in zip(cell['source'],cell['target']):
    s=np.asarray(s);z=np.clip((s[1]-944+18)/36,0,1);z=z*z*(3-2*z)
    xyz=(1-z)*(C@s+c)+z*(F@s+fo);allZ.append(float(xyz[2]));error=max(error,float(np.max(abs(P@xyz+H0+PAD-np.asarray(t)))))
  surfaces[side]=dict(actual_mesh=rec(meshfile),proximal_calf_surface_matrix=C.tolist(),proximal_calf_surface_offset=c.tolist(),distal_fixed_shoe_surface_matrix=F.tolist(),distal_fixed_shoe_surface_offset=fo.tolist(),blend='smoothstep(clip((source_y-944+18)/36,0,1)); actual forward triangles interpolate these shared 3D vertices',minimum_all_actual_active_mesh_vertex_Z=min(allZ),minimum_Z_with_8native_hidden_thickness=min(allZ)-8,maximum_actual_forward_vertex_projection_residual=error,foot_A_and_calf_A_are_same_exact_joint=True)
 surfaces['phase']=phase;surface_frames.append(surfaces)
sp=Q/'NE-run-common-finished-real-tarsal-joint-causal-surface-model-v03.json'
surface=dict(schema='MYTHIC413_NE_RUN_ACTUAL_COMMON_SOFT_TARSAL_SURFACE_MODEL_V03',status='AUTHOR_CONSTRUCTIVE_FINITE_MODEL_PENDING_INDEPENDENT_AUDIT',unchanged_original_rig=rec(MP),projection=P.tolist(),frames=surface_frames,model_scope='Explicit compatible 2.5D actual flexible leather joint surface using actual calf and rigid original boot affine charts; fixed bone joints shared, raster target vertices exactly projected. Not unique hidden anatomy reconstruction.',actual_RGBA_changed_by_model=False,actor_approvals_added=0)
with sp.open('x') as f:f.write(json.dumps(surface,indent=2)+'\n')
roster=dict(schema='MYTHIC413_NE_RUN_ACTUAL_COMMON_FINISHED_SIX_SOURCE_ROSTER_V03',frames=frames,exact_original_physical_rig=rec(MP),actual_soft_tarsal_surface_model=rec(sp),C=2432,bodyunit=2.375,common_rig_root_unpadded=m['common_rig_root_unpadded'],all_storage_translation=m['storage_translation'],clock=m['clock'],world_per_phase=16.8,whole_source_resized=False,perpose_C_rootfit=False,body_head_neck_identity_RIGHTstaff_preserved=True,full_source_cycle_and_runtime_gate_pending=True,actor_approvals_added=0,completed_detailed_actors_unchanged='2/31')
rp=Q/'NE-run-common-finished-six-actual-source-roster-v03.json'
with rp.open('x') as f:f.write(json.dumps(roster,indent=2)+'\n')
print(json.dumps(dict(roster=rec(rp),joint_surface=rec(sp),maximum_joint_projection_residual=max(surface_frames[p][s]['maximum_actual_forward_vertex_projection_residual'] for p in range(6) for s in ['R','L']),AIR2_5_joint_minima={str(p):[surface_frames[p][s]['minimum_Z_with_8native_hidden_thickness'] for s in ['R','L']] for p in [2,5]})))
