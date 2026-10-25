from pathlib import Path
import json,hashlib
P=Path(__file__).parent;files=[]
def pin(p):p=Path(p);return dict(source=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
for stem in ['actual-S-native-source-node-material-INPUT-v01','actual-S-IDLE6-native-breath-relax-v01']:files.extend(sorted((P/stem).iterdir()))
for name in ['prepare-S-original-native-materials-and-continuous-node-ownership-v01.py','author-S-IDLE6-own-native-breath-cuff-neck-and-cloth-v01.py','author-S-IDLE6-own-native-breath-cuff-neck-and-cloth-v02.py','actual-S-original-material-preparation-v01.log','actual-S-IDLE6-native-production-v01.log','freeze-S-IDLE-first-actual-six-native-original-materials-and-renderers-v01.py']:files.append(P/name)
files.extend([P/'prepare-S-original-native-materials-and-continuous-node-ownership-v02.py',P/'S-IDLE-code-preparation-and-pending-once-basis-reference-frozen-allowlist-v01.json'])
H=Path('/workspace/scratch/mythic413-S-hit-author-20261020-v01/common-own-S-native-LEFT-materials-v01/S-own-native-complete-LEFT-and-old-erased-BODY-readonly-handoff-v01.json');h=json.loads(H.read_text());inputs=[H,Path(h['source']['path']),Path(h['once_body_registration']['path'])]
inputs.extend(Path(x['path'])for x in h['parts'].values());inputs.extend(Path(x['path'])for x in h['semantic_mattes'].values());inputs.extend(Path(x['path'])for x in h['body_inputs']['LEFT-forearm-only-old-erased-BODY-with-original-RIGHT-staff-arms-and-boots'].values());inputs.append(Path(h['fixed_original_RIGHTgear_conservative_native_support']['path']))
inputs.extend([Path('/workspace/scratch/mythic413-S-base-independent-qc-20261020-v01/S-new-native-source-and-once-C2560-body-root-registration-PASS-v01.json'),Path('/workspace/scratch/mythic413-S-base-independent-qc-20261020-v01/S-c9a5-once-body-C2560-root-independent-numeric-companion-v01.json')])
unique=[];aliases=[];seen={}
for p in files+inputs:
 assert p.is_file(),p
 r=pin(p)
 if r['sha256']in seen:aliases.append(dict(r,identical_bytes_already_listed_source=seen[r['sha256']]))
 else:unique.append(r);seen[r['sha256']]=str(p)
C=P/'actual-S-IDLE6-native-breath-relax-v01/S-IDLE-six-actual-native-source-fixed-basis-and-loop-contract-v01.json';f=P/'S-IDLE-first-actual-six-all-original-materials-shared-inputs-and-renderers-frozen-allowlist-v01.json';f.write_text(json.dumps(dict(status='IMMUTABLE_ACTUAL_NEW_S_IDLE6_PENDING_INDEPENDENT_SOURCE_AND_VISIBLE_LOOP_QA',files=unique,exact_path_SHA_aliases=aliases,current_exact_six_contract=pin(C),readonly_shared_inputs=[str(x)for x in inputs],new_services=0,new_author_images=0,private_context_bytes_unchanged=5538937,old_profiles_sources_and_approved_clips_modified=False,all6_original_RIGHTgear_lowerbody_RGBA_changes=0,actor_approvals_added=0),indent=2)+'\n');print(json.dumps(dict(manifest=pin(f),unique_files=len(unique),unique_bytes=sum(x['bytes']for x in unique),aliases=len(aliases))))
