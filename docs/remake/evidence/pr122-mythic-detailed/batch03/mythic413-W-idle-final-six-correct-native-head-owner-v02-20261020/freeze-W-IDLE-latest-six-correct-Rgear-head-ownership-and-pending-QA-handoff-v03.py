from pathlib import Path
import json,hashlib
P=Path(__file__).parent
def pin(x):
 p=Path(x);return dict(source=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def put(p,d):
 assert not p.exists();p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');return pin(p)
C=P/'actual-W-IDLE6-native-breath-relax-v02/W-IDLE-six-actual-native-source-fixed-basis-and-loop-contract-v02.json';c=json.loads(C.read_text())
H=Path(c['actual_material_handoff']['path']);h=json.loads(H.read_text())
assert hashlib.sha256(H.read_bytes()).hexdigest()=='2207adf6113ec4f6728bb9a3f4696060fc7e3b867c24c51e358ae00a63a6a5b2'
first=P/'W-IDLE-first-actual-six-all-original-materials-shared-inputs-and-renderer-frozen-allowlist-v01.json'
frames=[]
for f in c['frames']:
 r=pin(f['path']);assert r['sha256']==f['sha256'];assert f['original_RIGHTgear_and_complete_lowerbody_RGBA_changes']==0
 frames.append(dict(phase=f['phase'],path=f['path'],sha256=r['sha256'],bytes=r['bytes']))
hand=put(P/'W-IDLE-latest-six-exact-native-fixed-basis-PENDING-independent-SOURCE-handoff-v01.json',dict(status='LATEST_ACTUAL_OWN_W_IDLE6_PENDING_FIRST_INDEPENDENT_ACTUAL_SOURCE_AND_VISIBLE_LOOP_QA',source_contract=pin(C),previous_immutable_production_freeze=pin(first),shared_complete_LEFT_and_original_BODY_and_corrected_Rgear_handoff=pin(H),shared_once_registration=c['shared_basis'],independent_stationary_basis_SOURCE=c['shared_basis_independent_SOURCE_PASS'],independent_once_numeric=c['shared_basis_independent_numeric_PASS'],physical_canvas=c['physical_canvas_fixed'],bodyunit=c['body_unit_fixed'],logical_canvas=1024,common_rig_root_in_unpadded_frame=c['common_rig_root_in_unpadded_frame'],storage_translation=c['storage_translation'],storage_canvas=c['storage_size'],frames=frames,loop=True,loop_seconds=1.2,actual_nodes='Original-native intrinsic corset breathing, complete LEFT curved cuff/hand exact visible-control-length relaxed articulation, head/neck, original bluebowtail and uppercoat lag',scope=c['stationary_scope'],source_HOLD='PENDING_FIRST_INDEPENDENT_QA',source_approval=False,actor_approvals_added=0,game='ROOT_ONLY_PENDING',original_RIGHTgear_and_complete_lowerbody_RGBA_changes=0,source_global_resize=False,perpose_C_or_root_fit=False,private_context_bytes_unchanged=5538937,new_author_images=0,new_services=0,superseded_v01_reason='Shared v02 conservative protection included actual nose/hair while missing some rightgrip support. Owner v03 corrected actual ownership; complete LEFT/BODY/sourceRGBA/C/root/rig otherwise identical. All v01 artifacts remain immutable.'))
files=list(C.parent.iterdir())+[P/'author-W-IDLE6-own-native-breath-cuff-neck-and-cloth-v03.py',P/'actual-W-IDLE6-native-production-v02-Rgear-head-ownership-corrected.log',H,Path(hand['source']),Path(__file__)]
files.extend(Path(x['path'])for x in h['parts'].values());files.extend(Path(x['path'])for x in h['semantic_mattes'].values());files.extend(Path(x['path'])for x in h['body_inputs']['LEFT-forearm-only-old-erased-BODY-with-original-RIGHT-staff-arms-and-boots'].values());files.append(Path(h['fixed_original_RIGHTgear_conservative_native_support']['path']))
previous=json.loads(first.read_text());seen={r['sha256']:r['source']for r in previous['files']};new=[];refs=[]
for f in files:
 r=pin(f)
 if r['sha256'] in seen:refs.append(dict(r,identical_bytes_in_previous_manifest_or_current_freeze=seen[r['sha256']]))
 else:new.append(r);seen[r['sha256']]=r['source']
out=put(P/'W-IDLE-latest-actual-six-correct-Rgear-head-ownership-and-pending-QA-handoff-frozen-allowlist-v02.json',dict(status='IMMUTABLE_LATEST_ACTUAL_W_IDLE6_PENDING_INDEPENDENT_SOURCE_AND_VISIBLE_1P2S_LOOP_QA',files=new,exact_SHA_path_references=refs,previous_frozen_manifest=pin(first),latest_source_contract=pin(C),latest_pending_QA_handoff=hand,all_earlier_source_and_code_and_unused_prototypes_preserved=True,new_services=0,new_author_images=0,private_context_bytes_unchanged=5538937,old_sources_and_approved_clips_modified=False,actor_approvals_added=0))
print(json.dumps(dict(handoff=hand,freeze=out,new_unique_files=len(new),new_unique_bytes=sum(x['bytes']for x in new),exact_previous_byte_references=len(refs))))
