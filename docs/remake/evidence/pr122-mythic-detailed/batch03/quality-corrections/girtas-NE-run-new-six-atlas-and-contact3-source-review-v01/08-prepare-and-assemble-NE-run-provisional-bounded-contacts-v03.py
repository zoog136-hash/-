from pathlib import Path
import json,hashlib,sys,datetime
sys.path.insert(0,'/workspace/twilight/tools')
import assemble_pr122_reviewed_poses as assembler
B=Path('/workspace/scratch');P=B/'girtas-NE-run-reviewed-composite-v02';P.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
read=lambda p:json.loads(Path(p).read_text())
def pin(p):
 p=Path(p);return {'path':str(p),'sha256':sha(p),'bytes':p.stat().st_size}
old_manifest=B/'girtas-NE-run-production-v01/final-six-NE-run-source-cycle-v02.json';old=read(old_manifest)
zero=B/'girtas-NE-run-contact0-bounded-leg-repair-v01';three=B/'girtas-NE-run-contact3-lowerbody-repair-v01'
r0=zero/'girtas-NE-run-contact0-bounded-leg-repair-v02.png';r3=three/'girtas-NE-run-contact3-lowerbody-bounded-v04.png'
assert sha(r0)=='216ac0a0834189ab6d4ecd9aed07a76abc902ea6df15c121f6b994027514ad02'
assert sha(r3)=='63cb6e43432b3bcfb474fdf5d0f767b3f69bdd88e0922f9d299cc2e6659be47a'
q0=zero/'request.json';q3=three/'request.json';cp0=zero/'source-crop-alpha16-proof-v02.json';cp3=three/'source-crop-proof-v05-canonical-alias.json'
p0=zero/'exact-bounded-preservation-proof-v02.json';p3=three/'outside-semantic-ROI-exact-RGBA-proof-v04.json'
sr0=B/'girtas-final-actual-quality-v04/NE-run-contact0-bounded-v02-independent-source-PASS.json'
assert sha(sr0)=='f71977cb04e446a7176b92561b65024e58fa69d2d89776f77c636a97cdd049c8'
assert 'PASS' in read(sr0)['status'] and sha(r0) in json.dumps(read(sr0))
items=[]
for e in old['items']:
 n=e['phase']
 if n not in [0,3]:
  assert sha(e['raw_path'])==e['raw_sha256'];items.append(e);continue
 r,q,cp,p=(r0,q0,cp0,p0) if n==0 else (r3,q3,cp3,p3)
 item={'phase':n,'folder':str(r.parent),'raw_path':str(r),'raw_sha256':sha(r),'request_path':str(q),'request_sha256':sha(q),'source_crop_proof_path':str(cp),'source_crop_proof_sha256':sha(cp),'bounded_exact_RGBA_proof_path':str(p),'bounded_exact_RGBA_proof_sha256':sha(p),'actual_image_size':[1254,1254],'fixed_effective_C':1936 if n==0 else 1776,'raw_composite_resampled':False,'ancestor_original_source':pin(e['raw_path']),'earlier_source_identity_ownership_proof':pin(e['independent_source_review_path']),'source_review_status':'PASS_SOURCE_ONLY' if n==0 else 'HOLD_PENDING_FINAL_INDEPENDENT_SOURCE_REVIEW_CAPACITY_BLOCK','physical_status':'HOLD_PENDING_NEW_SIX_PROJECTED_ROOT_REVIEW','actor_approval':False,'new_approvals':0}
 if n==0:item.update(independent_source_review_path=str(sr0),independent_source_review_sha256=sha(sr0))
 else:
  gp=three/'geometry-base2048-v04.json';item.update(geometry_path=str(gp),geometry_sha256=sha(gp))
 items.append(item)
manifest={'status':'PROVISIONAL_SELECTED_SIX_NEW_CONTACT0_SOURCE_PASS_CONTACT3_AND_PHYSICAL_HOLD','key':'transform:267','direction':'NE','role':'run','items':items,'unchanged_original_phases':[1,2,4,5],'newly_authored_bounded_contact_repairs':[0,3],'fixed_poseCs':[1936,2240,1936,1776,2048,1936],'historical_previous_manifest':pin(old_manifest),'historical_18d_atlas_and_first_physical_HOLD_preserved':True,'source0_independent_PASS':pin(sr0),'source3_independent_status':'HOLD_PENDING_FINAL_SOURCE_VERDICT_CAPACITY_BLOCK','whole_six_source_cycle_status':'HOLD_PENDING_CURRENT_SELECTED_SIX_BRIDGE','physical_status':'HOLD_PENDING_INDEPENDENT_NEW_COMMON_WORLD_CYCLE_REVIEW','integration_ready':False,'actor_approval':False,'new_approvals':0,'imagegen_calls_this_assembly':0,'utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
mp=P/'selected-six-bounded-contacts-PROVISIONAL-v01.json';mp.write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n')
poses=[]
for e in items:
 n=e['phase'];cp=read(e['source_crop_proof_path']);assert sha(e['raw_path'])==e['raw_sha256'] and sha(e['request_path'])==e['request_sha256']
 basis=('Final contact3 semantic bounded composition retains exact outside-mask originalRGBA and strict single geometry; final independent SOURCE judgment is capacity-blocked and remains HOLD. No source/physical/actor PASS is claimed for this pose.' if n==3 else 'Individual source proof is pinned; this provisional assembly does not add final physical/runtime/actor approval.')
 pose={'path':e['raw_path'],'source_sha256':e['raw_sha256'],'region':cp['source_region'],'rgba_sha256':cp['source_region_RGBA_sha256'],'source_pose':0,'newly_authored':True,'intended_game_phase':n,'review_basis':basis,'source_request_path':e['request_path'],'source_request_sha256':e['request_sha256']}
 if 'independent_source_review_path' in e:pose.update(independent_source_review_path=e['independent_source_review_path'],independent_source_review_sha256=e['independent_source_review_sha256'])
 if n in [0,3]:pose.update(bounded_exact_RGBA_proof_path=e['bounded_exact_RGBA_proof_path'],bounded_exact_RGBA_proof_sha256=e['bounded_exact_RGBA_proof_sha256'])
 if n==1:
  ep=Path(e['raw_path']).parent/'actual-endpoint-composite-outside-ROI-proof.json';pose.update(actual_endpoint_source_proof=str(ep),actual_endpoint_source_proof_sha256=sha(ep),new_motion_poses_created_by_endpoint_step=0)
 poses.append(pose)
spec={'schema':'pr122-reviewed-pose-map-v1','key':'transform:267','direction':'NE','role':'run','poses':poses,'newly_authored_poses':6,'reused_game_animation_poses':0,'packing_cell_size':1536,'packing_basis':'ExactRGBA finished selected source pixels in spacious2x3 temporal cells. No actor/source resizing, mirroring, recoloring, cleanup or new image service. Provisional source3 and full six physical remain HOLD.','current_selection_manifest':str(mp),'current_selection_manifest_sha256':sha(mp),'source_pixels_unchanged_relative_finished_selected_sources':True,'whole_cycle_source_bridge':'HOLD_PENDING_CONTACT3_AND_SELECTED_SIX_INDEPENDENT_REVIEW','physical_status':'HOLD_PENDING_NEW_AUTHORED_ROOT_REVIEW','integration_ready':False,'actor_approval':False}
sp=P/'spec.json';sp.write_text(json.dumps(spec,indent=2,ensure_ascii=False)+'\n');raw=P/'girtas-NE-run-reviewed-composite-v02.png'
try:
 proof=assembler.assemble_pose_map(sp,raw,cell_size=1536)
 print(json.dumps({'status':'PROVISIONAL_EXACT_RGBA_SIX_GEOMETRY_PASS_SOURCE3_AND_PHYSICAL_HOLD','raw':str(raw),'raw_sha256':sha(raw),'assembly_proof':str(raw.with_suffix('.assembly.json')),'manifest':str(mp),'manifest_sha256':sha(mp),'integration_ready':False,'actor_approval':False,'new_approvals':0}))
except Exception as error:
 out={'status':'STOP_PRESERVED_NO_APPROVAL','error':str(error)[:1200],'raw_exists':raw.exists(),'raw_sha256':sha(raw) if raw.exists() else None,'spec':str(sp),'no_unchanged_repack_retry':True};(P/'assembly-STOP-preserved.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
