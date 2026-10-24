from pathlib import Path
import json,hashlib
P=Path(__file__).parent;files=[]
def pin(p):p=Path(p);return dict(source=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
for name in ['actual-SW-native-source-node-material-INPUT-v01','actual-SW-IDLE6-native-breath-relax-v01']:files.extend(sorted((P/name).iterdir()))
for name in ['prepare-SW-original-native-materials-and-continuous-node-ownership-v01.py','author-SW-IDLE6-own-native-breath-cuff-neck-and-cloth-v01.py','actual-SW-original-material-preparation-v01.log','actual-SW-IDLE6-native-production-v01.log','freeze-SW-IDLE-first-actual-six-native-original-materials-and-renderer-v01.py']:files.append(P/name)
H=Path('/workspace/scratch/mythic413-SW-hit-author-20261020-v01/common-own-SW-native-LEFT-materials-v02/SW-own-native-complete-LEFT-and-old-erased-BODY-readonly-handoff-v02.json');h=json.loads(H.read_text());inputs=[H,Path(h['source']['path']),Path(h['once_body_registration']['path'])]
inputs.extend(Path(x['path'])for x in h['parts'].values());inputs.extend(Path(x['path'])for x in h['semantic_mattes'].values());inputs.extend(Path(x['path'])for x in h['body_inputs']['LEFT-forearm-only-old-erased-BODY-with-original-RIGHT-staff-arms-and-boots'].values());inputs.append(Path(h['fixed_original_RIGHTgear_conservative_native_support']['path']))
inputs.extend([Path('/workspace/scratch/mythic413-SW-base-independent-qc-20261020-v01/SW-new-native-stationary-source-and-once-C2496-body-root-registration-PASS-v01.json'),Path('/workspace/scratch/mythic413-SW-base-independent-qc-20261020-v01/SW-5093a7-once-body-C2496-root-independent-numeric-companion-v01.json'),Path('/workspace/scratch/mythic413-SW-private-base-generation-continuing-20261020-v01/service-SW-fullbody-base-native-r001.png')])
unique=[];aliases=[];seen={}
for p in files+inputs:
 assert p.is_file(),p
 r=pin(p)
 if r['sha256']in seen:aliases.append(dict(r,identical_bytes_already_listed_source=seen[r['sha256']]))
 else:unique.append(r);seen[r['sha256']]=str(p)
C=P/'actual-SW-IDLE6-native-breath-relax-v01/SW-IDLE-six-actual-native-source-fixed-basis-and-loop-contract-v01.json';out=P/'SW-IDLE-first-actual-six-all-original-materials-shared-v02-inputs-and-renderer-frozen-allowlist-v01.json';out.write_text(json.dumps(dict(status='IMMUTABLE_ACTUAL_NEW_SW_IDLE6_PENDING_INDEPENDENT_SOURCE_AND_VISIBLE_LOOP_QA',files=unique,exact_path_SHA_aliases=aliases,current_exact_six_contract=pin(C),readonly_shared_inputs=[str(x)for x in inputs],stationary_scope='Shallow front-left SW/nearboot turnout preserved only as stationary idle; no walk/RUN/gait approval',only_current_v02_basis_USED_C2496=True,old_C2560_candidate_and_old_LEFT_v01_not_used_or_modified=True,new_services=0,new_author_images=0,private_context_bytes_unchanged=5538937,old_profiles_sources_and_approved_clips_modified=False,all6_original_RIGHTgear_and_complete_lowerbody_RGBA_changes=0,actor_approvals_added=0),indent=2)+'\n');print(json.dumps(dict(manifest=pin(out),unique_files=len(unique),unique_bytes=sum(x['bytes']for x in unique),aliases=len(aliases))))
