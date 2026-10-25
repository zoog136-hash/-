"""Exact request binding, including uniform transparent shipping translation.
Arguments: request requestSHA rawSHA rawbytes source_review shiftX shiftY.
"""
from pathlib import Path
import json,hashlib,sys
import numpy as np
from PIL import Image
B=Path(__file__).parent
def pin(p):
 p=Path(p);return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def check(s):
 p=Path(s['path']);assert pin(p)['sha256']==s['sha256'];return p
def save(name,q):
 p=B/name;assert not p.exists();p.write_text(json.dumps(q,indent=2,ensure_ascii=False)+'\n');return pin(p)
assert len(sys.argv)==8
rp=Path(sys.argv[1]);rqsha,rawsha,rawbytes=sys.argv[2:5];reviewp=Path(sys.argv[5]);shift=np.array([int(sys.argv[6]),int(sys.argv[7])]);rawbytes=int(rawbytes)
assert pin(rp)['sha256']==rqsha;q=json.loads(rp.read_text());review=json.loads(reviewp.read_text());assert review['source_visual_status']=='PASS' and review['key']==q['key']=='transform:413' and review['direction']==q['direction']=='SE' and review['role']==q['role']
cp=check(review['source_contract']);c=json.loads(cp.read_text());fixedC=review['C_fixed'];root=np.array(review['common_rig_root']);originalStorage=np.array(review['storage_translation']);shippingStorage=originalStorage+shift;storedroot=root+shippingStorage;integerroot=np.rint(storedroot).astype(int);roundDelta=integerroot-storedroot
pps=list(rp.parent.glob('*.packing.json'));assert len(pps)==1;pp=pps[0];pack=json.loads(pp.read_text());assert pin(pp)['sha256']==q['authored_packing_proof_sha256'];rawp=Path(pack['output']);assert pin(rawp)['sha256']==rawsha and pin(rawp)['bytes']==rawbytes;raw=np.array(Image.open(rawp).convert('RGBA'));tile=raw.shape[1]//2;assert raw.shape==(tile*3,tile*2,4) and tile in [1536,2304]
rows=[]
for i,(f,p) in enumerate(zip(c['frames'],pack['authored_poses'])):
 assert i==f['phase']==p['phase'];origp=Path(f['path']);assert pin(origp)['sha256']==f['sha256'];original=np.array(Image.open(origp).convert('RGBA'));h,w=original.shape[:2];expected=np.zeros((tile,tile,4),np.uint8)
 # The original full native source is translated by the SAME integer for
 # every pose. Any source area outside storage must be fullRGBA0, not merely
 # transparent alpha. Reverse reconstruction must be byteRGBA exact.
 sx0=max(0,-int(shift[0]));sy0=max(0,-int(shift[1]));sx1=min(w,tile-int(shift[0]));sy1=min(h,tile-int(shift[1]));assert sx1>sx0 and sy1>sy0
 dx0=sx0+int(shift[0]);dy0=sy0+int(shift[1]);dx1=sx1+int(shift[0]);dy1=sy1+int(shift[1]);expected[dy0:dy1,dx0:dx1]=original[sy0:sy1,sx0:sx1];restored=np.zeros_like(original);restored[sy0:sy1,sx0:sx1]=expected[dy0:dy1,dx0:dx1];assert np.array_equal(restored,original)
 x,y=p['atlas_origin'];actual=raw[y:y+tile,x:x+tile];assert np.array_equal(actual,expected);sourcep=Path(p['source']);assert pin(sourcep)['sha256']==p['source_sha256'];shipping=np.array(Image.open(sourcep).convert('RGBA'));assert np.array_equal(shipping,expected) and hashlib.sha256(shipping.tobytes()).hexdigest()==p['source_rgba_sha256']
 assert np.count_nonzero(original[:,:,3])==np.count_nonzero(actual[:,:,3]);assert p['physical_canvas']==fixedC and np.array_equal(p['storage_translation'],shippingStorage)
 assert np.allclose(p['atlas_root_anchor'],np.array([x,y])+storedroot,atol=1e-9,rtol=0) and np.array_equal(q['reviewed_runtime_layout']['source_anchors'][i],np.array([x,y])+integerroot)
 rx,ry,rw,rh=q['source_region_review']['regions'][i];ay,ax=np.where(actual[:,:,3]>0);assert np.all((ax+x>=rx)&(ax+x<rx+rw)&(ay+y>=ry)&(ay+y<ry+rh))
 rows.append(dict(phase=i,original_reviewed_source=pin(origp),original_source_RGBA_sha256=hashlib.sha256(original.tobytes()).hexdigest(),shipping_source=pin(sourcep),shipping_RGBA_sha256=p['source_rgba_sha256'],original_size=[w,h],shipping_tile=[tile,tile],uniform_storage_translation=shift.tolist(),original_storage=originalStorage.tolist(),shipping_storage=shippingStorage.tolist(),original_RGBA_reverse_reconstruction_mismatch=0,shipping_all_RGBA_mismatch=0,original_alpha_positive_count=int(np.count_nonzero(original[:,:,3])),shipping_alpha_positive_count=int(np.count_nonzero(actual[:,:,3])),world_coordinate_equivalence='Exact integer identity: (source+shift)-(originalStorage+shift)-root == source-originalStorage-root',physical_C=fixedC,source_anchor=q['reviewed_runtime_layout']['source_anchors'][i]))
assert len(rows)==6 and q['reviewed_runtime_layout']['authored_pose_canvas_sizes']==[fixedC]*6;assert np.allclose(q['common_root_rounding_delta'],roundDelta,atol=1e-9,rtol=0)
version=q['version'];binding=save(f'{version}-independent-exact-source-shipping-storage-binding-v01.json',dict(status='PASS_EXACT_SIX_REVIEWED_NATIVE_SOURCES_AND_UNIFORM_SHIPPING_STORAGE_WORLD_EQUIVALENCE',request=pin(rp),raw=pin(rawp),packing=pin(pp),source_review=pin(reviewp),source_contract=pin(cp),six_source_bindings=rows,physical_C=fixedC,common_unpadded_root=root.tolist(),original_storage=originalStorage.tolist(),shipping_storage=shippingStorage.tolist(),same_integer_translation_all6=shift.tolist(),uniform_root_rounding_delta=roundDelta.tolist(),source_resampled=False,root_C_profile_or_motion_controls_changed=False,new_image_views=0,actor_approvals_added=0))
receipt=save(f'{version}-independent-final-source-cycle-PASS-v01.json',dict(schema='PR122-independent-final-exact-request-source-cycle-review-v1',status='PASS_EXACT_FINAL_OWN_SE_SOURCE_CYCLE_AND_LOSSLESS_SHIPPING_STORAGE',source_visual_status='PASS',key=q['key'],direction=q['direction'],role=q['role'],version=version,request_sha256=rqsha,request_path=str(rp),raw_sha256=rawsha,raw_bytes=rawbytes,raw_path=str(rawp),source_contract=pin(cp),actual_source_cycle_review=pin(reviewp),exact_source_binding=binding,physical_canvas=fixedC,common_unpadded_root=root.tolist(),original_reviewed_storage=originalStorage.tolist(),storage_translation=shippingStorage.tolist(),uniform_extra_shipping_translation=shift.tolist(),uniform_integer_root_rounding_delta=roundDelta.tolist(),loop=False,cycle_seconds=review.get('cycle_seconds'),runtime_cycle_seconds=review.get('runtime_cycle_seconds'),resource_role_seconds=review.get('resource_role_seconds'),phase_seconds=review['phase_seconds'],intended_contact_frame=review.get('intended_contact_frame'),held_dead_terminal=review.get('held_dead_terminal',False),visual_findings=review['visual_findings'],visual_limitations=review['visual_limitations']+['Final packing uses one identical integer shipping translation for all6, exact reverseRGBA reconstruction, transparent padding only, and one common integer root quantization. Every original native world-space point is unchanged. No new source/image view or physical/body/profile fit was introduced.'],images_forwarded=0,new_image_views=0,actor_approvals_added=0))
allow=save(f'{version}-independent-exact-final-proof-allowlist-v01.json',dict(status='IMMUTABLE_INDEPENDENT_JSON_PY_ONLY_EXACT_PACK_ADDITIONS',files=[pin(Path(binding['path'])),pin(Path(receipt['path'])),pin(__file__)],count=3,images_included=False,live_ledgers_included=False,source_review=pin(reviewp),actor_approvals_added=0));print(json.dumps(dict(receipt=receipt,binding=binding,allowlist=allow,new_image_views=0)))
