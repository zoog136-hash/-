"""Image0 finite rebind only; no repeat once-body or dense-Jacobian audit."""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
B=Path(__file__).parent;A=Path('/workspace/scratch/mythic413-W-hit-author-20261020-v01')
def pin(p):
 p=Path(p);return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def check(s):
 p=Path(s['path']);assert pin(p)['sha256']==s['sha256'];return p
def load(s):return json.loads(check(s).read_text())
def rgba(s):return np.array(Image.open(check(s)).convert('RGBA'))
MP=A/'W-original-neutral-fixed-cab100-planes-rebound-to-real-cloth-IDLE-HIT-twelve-v03.json';assert pin(MP)['sha256']=='88a71306989b6850116d4248545b241cb37feca71c7a145ae616ec5fb5f38037';m=json.loads(MP.read_text());oldm=load(m['original_once_floor_no_refit_reference']);receipt=A/'W-IDLE-HIT-twelve-real-cloth-source-replacement-original-operator-and-fixed-material-receipt-v03.json';assert pin(receipt)['sha256']=='f19ec3b04505fee621783ec73e6bb5742e6a11a2e9fc647c1649ea9df64ae0c5';r=json.loads(receipt.read_text());hit=load(r['new_HIT']);oldhit=load(r['old_HIT']);idle=load(r['new_IDLE']);oldidle=load(r['old_IDLE']);assert m['actual_HIT_source_contract']==r['new_HIT'] and m['actual_IDLE_source_contract']==r['new_IDLE']
priorfloor=B/'W-hit-cab100-independent-once-neutral-source-and-actual-six-floor-companion-v01.json';priorflow=B/'W-hit-v02-f89948-independent-actual-flow-shared-attachments-fixed-material-companion-v01.json';pf=json.loads(priorfloor.read_text());pv=json.loads(priorflow.read_text());assert r['old_HIT']==pv['source_contract'] and pf['model']==pin(check(m['original_once_floor_no_refit_reference']))
for k in ['original_source','once_body_registration','C','bodyunit','common_unpadded_root','storage_translation','projection_matrix','projection_origin','source_material_capture_models','remaining_material_capture_plane']:assert m[k]==oldm[k]
P=np.array(m['projection_matrix']);origin=np.array(m['projection_origin']);src=rgba(m['original_source']);models=m['source_material_capture_models'];masks=[np.array(Image.open(check(z['exact_source_alpha_support'])))>0 for z in models];assert not np.any(masks[0]&masks[1]);Rmask=np.array(Image.open(check(hit['fixed_original_RIGHTgear_conservative_native_support'])))>0
Y,X=np.indices((1254,1254));legs=(Y>=1000)|((Y>=640)&(X>=470)&(X<=692))|((Y>=720)&(X>=470)&(X<=850))
def bound(mask,sa,wa,U,V,g):
 y,x=np.where(mask);U=np.array(U);V=np.array(V);sa=np.array(sa);wa=np.array(wa);assert len(x)>0 and np.allclose(P@np.column_stack([U,V]),np.eye(2),rtol=0,atol=1e-12) and np.allclose(origin+P@wa,sa,rtol=0,atol=1e-10)
 return dict(actual_alpha_gt0_texel_quad_count=len(x),guard_native=g,guarded_min_Z=float((wa[2]+(x-sa[0])*U[2]+(y-sa[1])*V[2]).min()-.5*(abs(U[2])+abs(V[2]))-g))
for k in ['original_node_material_and_weight_INPUT','explicit_actual_native_motion_controls','exact_storage_protection_mask','original_RIGHTgear_mask']:
 assert idle[k]['sha256']==oldidle[k]['sha256'];check(idle[k])
assert idle['exact_storage_protection_mask']['sha256']=='137f6af59641a497d52329625631856247243e73c80840dc756032a54fb0d60e'
weights=load(idle['original_node_material_and_weight_INPUT']);assert len(weights['parts'])==5
for z in weights['parts']:
 check(z['actual_original_RGBA_material']);check(z['native_node_weight16'])
assert weights['explicit_native_motion_controls']['sha256']==idle['explicit_actual_native_motion_controls']['sha256'];fullprotect=np.array(Image.open(check(idle['exact_storage_protection_mask'])))>0
for role,c,oc,sourcekey in [('hit',hit,oldhit,'source'),('idle',idle,oldidle,None)]:
 keys=['C','bodyunit','common_rig_root_unpadded','storage_translation','native_size','role_seconds','phase_seconds'] if role=='hit' else ['physical_canvas_fixed','body_unit_fixed','logical_canvas','common_rig_root_in_unpadded_frame','storage_translation','storage_size','loop','loop_seconds','source_native_controls']
 for k in keys:assert c[k]==oc[k]
rows=[];transferred_fields=[]
def bone_map(a,b,c,d):
 a,b,c,d=map(lambda p:np.asarray(p,float),(a,b,c,d));u=(b-a)/np.linalg.norm(b-a);v=(d-c)/np.linalg.norm(d-c);M=np.outer((d-c)/np.linalg.norm(b-a),u)+np.outer([-v[1],v[0]],[-u[1],u[0]]);return M,c-M@a
def posed_vertices(points,source_knots,target_knots,storage):
 sp=np.asarray(source_knots,float);tp=np.asarray(target_knots,float)+storage;M0,O0=bone_map(sp[0],sp[1],tp[0],tp[1]);M1,O1=bone_map(sp[1],sp[2],tp[1],tp[2]);t=(sp[1]-sp[0])/np.linalg.norm(sp[1]-sp[0])+(sp[2]-sp[1])/np.linalg.norm(sp[2]-sp[1]);t/=np.linalg.norm(t);g=np.clip(((points-sp[1])@t+18)/36,0,1);g=g*g*(3-2*g);return (points@M0.T+O0)*(1-g[...,None])+(points@M1.T+O1)*g[...,None]
for role,c,oc,materialrows in [('hit',hit,oldhit,m['actual_HIT_frames']),('idle',idle,oldidle,m['actual_IDLE_frames'])]:
 for i,(f,of,declared) in enumerate(zip(c['frames'],oc['frames'],materialrows)):
  assert f['phase']==of['phase']==declared['phase']==i
  if role=='hit':
   s=f['source'];assert s==declared['actual_source']
   for k in ['head_torso_velocity_parameter_native','head_local_angular_velocity_parameter_degrees','LEFT_actual_source_knots','LEFT_actual_guard_knots_unpadded','LEFT_guard_target_angle','LEFT_guard_projected_length','cloth_lag_native','ribbon_lag_native','body_flow_definition']:assert f[k]==of[k]
   check(f['actual_body_forward_flow']);assert f['actual_body_forward_flow']['sha256']==of['actual_body_forward_flow']['sha256'];mesh=load(f['actual_LEFT_guard_forward_mesh']);oldmesh=load(of['actual_LEFT_guard_forward_mesh'])
   for k in ['source_knots','target_knots_unpadded','storage_translation','mesh_spacing_native','method']:assert mesh[k]==oldmesh[k]
   material=rgba(f['source_complete_LEFT_native_material']);owned=material[:,:,3]>0;assert np.array_equal(material[owned],src[owned]);points=np.array([q['source']for q in mesh['mesh']]);targets=np.array([q['target']for q in mesh['mesh']]);expected=posed_vertices(points,mesh['source_knots'],mesh['target_knots_unpadded'],np.array(mesh['storage_translation']));vertex_error=float(abs(expected-targets).max());assert vertex_error<1e-10
   oldcells={tuple(np.array(z['source']).ravel()):z['target']for z in oldmesh['mesh']};common=added=0
   for z in mesh['mesh']:
    key=tuple(np.array(z['source']).ravel())
    if key in oldcells:assert np.array_equal(z['target'],oldcells[key]);common+=1
    else:added+=1
   transferred_fields.append(dict(phase=i,old_float32_field=of['actual_body_forward_flow'],current_float32_field=f['actual_body_forward_flow'],field_SHA_identical=True,actual_attachment_knots_and_operator_unchanged=True,current_mesh_vertex_independent_two_bone_smoothstep_residual=vertex_error,shared_original_mesh_cells_exact=common,new_original_material_coverage_mesh_cells=added,original_complete_LEFT_material=f['source_complete_LEFT_native_material'],original_visible_LEFT_RGBA_mismatch=0,control_changes=0,prior_independent_field_witness=pv['rows'][i]))
  else:
   s=dict(path=f['path'],sha256=f['sha256'],bytes=f['bytes']);assert s==declared['actual_source'];assert f['pose_nodes']==of['pose_nodes'] and f['actual_intrinsic_chest_source_points']==of['actual_intrinsic_chest_source_points'];check(f['actual_LEFT_node']);assert idle['actual_complete_LEFT_material']['sha256']==hit['frames'][i]['source_complete_LEFT_native_material']['sha256']
  a=rgba(s);assert a.shape==(1536,1536,4);native=a[128:1382,128:1382];outside=a.copy();outside[128:1382,128:1382]=0;assert not outside[:,:,3].any();assert np.array_equal(native[Rmask],src[Rmask])
  if role=='hit':assert np.array_equal(native[legs],src[legs])
  else:
   if fullprotect.shape==(1254,1254):assert np.array_equal(native[fullprotect],src[fullprotect])
   else:
    assert fullprotect.shape==(1536,1536);reference=np.zeros_like(a);reference[128:1382,128:1382]=src;assert np.array_equal(a[fullprotect],reference[fullprotect])
  feet=[]
  for mm,z,old in zip(masks,models,declared['sole_capture_patches']):
   assert np.array_equal(native[mm],src[mm]);q=bound(mm,z['observed_painted_heel_native'],z['source_plane_anchor_world'],z['source_U'],z['source_V'],2);assert q['actual_alpha_gt0_texel_quad_count']==old['actual_alpha_gt0_texel_quad_count'] and abs(q['guarded_min_Z']-old['guarded_min_Z'])<1e-9 and q['guarded_min_Z']>0;feet.append(dict(side=z['side'],original_RGBA_mismatch=0,**q))
  rest=m['remaining_material_capture_plane'];rm=(native[:,:,3]>0)&~(masks[0]|masks[1]);q=bound(rm,rest['source_anchor'],rest['world_anchor'],rest['U'],rest['V'],8);old=declared['all_remaining_actual_material_including_entire_staff'];assert q['actual_alpha_gt0_texel_quad_count']==old['actual_alpha_gt0_texel_quad_count'] and abs(q['guarded_min_Z']-old['guarded_min_Z'])<1e-9 and q['guarded_min_Z']>0;assert sum(z['actual_alpha_gt0_texel_quad_count']for z in feet)+q['actual_alpha_gt0_texel_quad_count']==np.count_nonzero(native[:,:,3]);rows.append(dict(role=role,phase=i,actual_source=s,original_sole_lowerboot_RGBA=feet,all_remaining_actual_RGBA_texel_quads_including_fullstaff=q,every_actual_alpha_positive_texel_assigned_exactly_once=True,original_RIGHTgear_RGBA_mismatch=0,original_complete_lowerbody_protection_RGBA_mismatch=0))
assert len(rows)==12 and len({z['actual_source']['sha256']for z in rows})==12
p=B/'W-final-real-cloth-v03-independent-twelve-source-floor-and-unchanged-operator-rebind-v01.json';assert not p.exists();p.write_text(json.dumps(dict(status='PASS_FINITE_EXACT_CURRENT_W_REAL_CLOTH_TWELVE_SOURCE_FIXED_PLANE_AND_OPERATOR_REBIND',current_HIT=r['new_HIT'],current_IDLE=r['new_IDLE'],current_model=pin(MP),producer_preservation_receipt=pin(receipt),prior_once_floor_witness=pin(priorfloor),prior_field_witness=pin(priorflow),same_fixed_once_source_planes_root_C_bodyunit_storage_sole_heights=True,new_actual_source_bounds=rows,HIT_exact_same_float32_fields_and_controls=transferred_fields,IDLE_same_five_original_RGBA_materials_and_weight16_and_CFG=idle['original_node_material_and_weight_INPUT'],IDLE_same_CFG=idle['explicit_actual_native_motion_controls'],IDLE_exact_same_storage_protection_mask=idle['exact_storage_protection_mask'],IDLE_six_pose_nodes_and_intrinsic_displacements_unchanged=True,IDLE_complete_LEFT_material_updated_without_pose_node_changes=True,limits=['This is a metadata/numeric rebind to the exact new twelve rasters, not a new once-body registration, dense-Jacobian audit or actual source/cycle/game approval.','The former independent HIT local Jacobian and sampled inverse witness is transferred only because actual float32 NPZ hashes and per-pose controls are identical. The completed original LEFT material adds mesh coverage; all shared mesh targets remain exact and every current mesh vertex independently follows the same two-bone smoothstep operator. No global3D or injectivity claim is added.','All24 actual original sole/lowerboot capture patches and every remaining current painted texel quad are directly checked under the same explicit stationary compatible capture model. Movement, RUN and uniquely recovered hidden anatomy remain outside scope.','Fresh actual SOURCE quality and loop/reaction judgement for the real cloth repair are separate; no new images were viewed by this rebind.'],images_viewed=0,source_PNG_modified=False,once_body_or_full_Jacobian_reexecuted=False,game_tests_run=0,actor_approvals_added=0),indent=2)+'\n');allow=B/'W-final-real-cloth-v03-independent-numeric-rebind-allowlist-v01.json';assert not allow.exists();allow.write_text(json.dumps(dict(status='IMMUTABLE_METADATA_ONLY_W_FINAL_NUMERIC_REBIND',files=[pin(p),pin(Path(__file__))],images_included=False,actor_approvals_added=0),indent=2)+'\n');print(json.dumps(dict(proof=pin(p),allowlist=pin(allow),sole_min=min(z['guarded_min_Z']for r in rows for z in r['original_sole_lowerboot_RGBA']),rest_min=min(r['all_remaining_actual_RGBA_texel_quads_including_fullstaff']['guarded_min_Z']for r in rows))))
