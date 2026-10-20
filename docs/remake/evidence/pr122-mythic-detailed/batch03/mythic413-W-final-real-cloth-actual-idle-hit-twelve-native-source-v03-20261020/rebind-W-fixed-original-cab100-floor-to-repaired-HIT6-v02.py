from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib,copy
D=Path(__file__).parent;OLD=D/'W-original-neutral-once-true-sole-and-HIT-six-material-floor-binding-v01.json';NEW=D/'actual-W-HIT6-own-native-articulated-v03/W-HIT6-actual-own-native-body-head-LEFTguard-source-contract-v01.json'
def rec(p):
 p=Path(p);b=p.read_bytes();return dict(path=str(p),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b))
assert rec(OLD)['sha256']=='cab100d5478e4e74169218becf472f2b55d07771efd40fd14ace05a899fd34f8';old=json.loads(OLD.read_text());c=json.loads(NEW.read_text());src=np.asarray(Image.open(old['original_source']['path']).convert('RGBA'));H,W=src.shape[:2];root=np.asarray(old['common_unpadded_root']);union=np.zeros((H,W),bool)
def check(a,m,h,A,U,V,guard):
 y,x=np.where((a[:,:,3]>0)&m);z=A[2]+(x-h[0])*U[2]+(y-h[1])*V[2];v=float(z.min()-.5*(abs(U[2])+abs(V[2]))-guard);assert v>=0;return dict(actual_alpha_gt0_texel_quad_count=len(x),all_centered_texel_quads_included=True,guard_native=guard,guarded_min_Z=v)
for model in old['source_material_capture_models']:union|=np.asarray(Image.open(model['exact_source_alpha_support']['path']))>0
rows=[];oldc=json.loads(Path(old['actual_HIT_source_contract']['path']).read_text())
for f,of in zip(c['frames'],oldc['frames']):
 assert f['actual_body_forward_flow']['sha256']==of['actual_body_forward_flow']['sha256']
 assert f['LEFT_actual_guard_knots_unpadded']==of['LEFT_actual_guard_knots_unpadded']
 a=np.asarray(Image.open(f['source']['path']).convert('RGBA'));native=a[128:128+H,128:128+W];assert np.count_nonzero(a[:,:,3])==np.count_nonzero(native[:,:,3]);r=dict(phase=f['phase'],actual_source=f['source'],actual_flow_identical_to_original_f89948=True,actual_guard_controls_identical=True,sole_capture_patches=[])
 for m in old['source_material_capture_models']:
  mask=np.asarray(Image.open(m['exact_source_alpha_support']['path']))>0;assert np.array_equal(native[mask],src[mask]);q=check(native,mask,np.array(m['observed_painted_heel_native']),np.array(m['source_plane_anchor_world']),np.array(m['source_U']),np.array(m['source_V']),2.);q.update(side=m['side'],original_RGBA_mismatch=0);r['sole_capture_patches'].append(q)
 plane=old['remaining_material_capture_plane'];r['all_remaining_actual_material_including_entire_staff']=check(native,(native[:,:,3]>0)&~union,root,np.array(plane['world_anchor']),np.array(plane['U']),np.array(plane['V']),8.);r['every_actual_alpha_gt0_texel_assigned_exactly_once']=sum(q['actual_alpha_gt0_texel_quad_count']for q in r['sole_capture_patches'])+r['all_remaining_actual_material_including_entire_staff']['actual_alpha_gt0_texel_quad_count']==int(np.count_nonzero(native[:,:,3]));assert r['every_actual_alpha_gt0_texel_assigned_exactly_once'];rows.append(r)
j=copy.deepcopy(old);j.update(schema='MYTHIC413_W_FIXED_ORIGINAL_CAB100_ONCE_PLANES_REBOUND_TO_REAL_CLOTH_REPAIRED_HIT6_V02',status='SAME_ONCE_MODEL_ACTUAL_REPAIRED_FRAMES_PENDING_INDEPENDENT_REBIND_AUDIT',actual_HIT_source_contract=rec(NEW),actual_HIT_frames=rows,original_once_floor_no_refit_reference=rec(OLD),once_source_planes_sole_heights_root_or_C_changed=False,actual_flow_and_guard_controls_changed=False,actor_approvals_added=0)
p=D/'W-original-neutral-fixed-cab100-planes-rebound-to-HIT-six-real-cloth-source-v02.json';assert not p.exists();p.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps(rec(p)))
