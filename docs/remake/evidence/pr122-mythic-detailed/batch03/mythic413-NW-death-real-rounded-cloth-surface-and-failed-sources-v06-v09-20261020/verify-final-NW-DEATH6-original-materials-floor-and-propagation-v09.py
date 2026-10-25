from pathlib import Path
import json,hashlib,numpy as np
P=Path(__file__).parent;D=P/'actual-NW-DEATH6-final-original-fabric-volume-v09';F=D/'NW-DEATH-final-six-exact-native-source-root-and-floor-contract-v09.json';d=json.load(open(F))
proof=json.load(open(D/'NW-DEATH-final-six-exact-original-fabric-operator-opaque-and-floor-proof-v09.json'));records=[]
assert d['common_unpadded_root']==[641.,1058.3]and d['physical_canvas_fixed']==2048
for row,p in zip(d['frames'],proof['records']):
 assert hashlib.sha256(Path(row['path']).read_bytes()).hexdigest()==row['sha256']
 assert p['original_opaque_alpha_ge240_RGBA_changes']==0
 parts=[]
 for s in row['actual_material_surfaces']:
  if s['actual_source_texel_min_Z']is None:continue
  if s.get('kind')=='CONTINUOUS_ORIGINAL_RGBA_3D_UV_MESH':
   minimum=s['raster_support_guard_min_Z'];rule='Whole3pxpadded native UV mesh domain; every emitted triangle Z>=vertexmin; semantic UV transparent outside'
  elif s.get('kind')=='ORIGINAL_RGBA_ELLIPSOID_CLOTH_CROSS_SECTION':
   minimum=s['raster_support_guard_min_Z'];rule='Observed35pxcross-section geometricbound including .75native coverage; exactoriginalopaque sourceart restored'
  else:
   minimum=s['actual_source_texel_min_Z']-2.5*(abs(s['U'][2])+abs(s['V'][2]));rule='Every actual nonzero material texel plus2.5sourcepixel PILbicubic support'
  assert minimum>=0,(row['phase'],s['name'],minimum)
  parts.append(dict(part=s['name'],minimum_raster_guard_Z=minimum,rule=rule))
 R=row['RIGHT_arm'];u=np.array(R['rigid_U']);v=np.array(R['rigid_V']);err=max(abs(np.linalg.norm(u)-1),abs(np.linalg.norm(v)-1),abs(u@v));assert err<1e-9
 boneerr=max(abs(z-200)for q in row['leg_world_joints'].values()for z in q['bone_lengths']);assert boneerr<1e-9
 records.append(dict(phase=row['phase'],source_sha256=row['sha256'],actual_material_floor_parts=parts,min_guard_Z=min(s['minimum_raster_guard_Z']for s in parts),RIGHTfore_and_full_staff_rigid_basis_error=err,leg_length_error=boneerr,existing_opaque_RGBA_changes=0,changed_bbox=p['changed_bbox'],strong_bodies=len(row['strong_components_alpha100_4conn_gte200'])))
assert d['frames'][2]['sha256']=='60a489704e824c786ad982e3b016dc195b83dc718f8f957f7fbed76df5ca1897'
f=D/'NW-DEATH-final-six-full-actual-material-raster-floor-and-rigid-pins-proof-v09.json';assert not f.exists()
f.write_text(json.dumps(dict(status='SCOPED_EXACT_SIX_MATERIAL_FLOOR_AND_VALIDATED_OPERATOR_CHECK_PENDING_FINAL_ACTUAL_QC',source_contract_sha256=hashlib.sha256(F.read_bytes()).hexdigest(),fixed_C=2048,body_unit=2,root=[641,1058.3],storage_translation=[128,128],phase2_exact_validated_source_reproduced=True,all_existing_opaque_RGBA_preserved=True,records=records,actor_approval_added=0),indent=2)+'\n')
print(json.dumps(dict(proof=str(f),sha256=hashlib.sha256(f.read_bytes()).hexdigest(),minimum_floor_guard=min(s['min_guard_Z']for s in records),all_strong_bodies=[s['strong_bodies']for s in records],original_opaque_changes=0)))
