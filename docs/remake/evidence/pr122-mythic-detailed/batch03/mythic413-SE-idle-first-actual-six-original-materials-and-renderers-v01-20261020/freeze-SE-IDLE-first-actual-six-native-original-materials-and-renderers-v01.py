from pathlib import Path
import json,hashlib
P=Path(__file__).parent;files=[]
def pin(p):p=Path(p);return dict(source=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
for stem in ['actual-SE-native-source-node-material-INPUT-v01','actual-SE-IDLE6-native-breath-relax-v01']:files.extend(sorted((P/stem).iterdir()))
for name in ['prepare-SE-original-native-materials-and-continuous-node-ownership-v01.py','author-SE-IDLE6-own-native-breath-cuff-neck-and-cloth-v01.py','author-SE-IDLE6-own-native-breath-cuff-neck-and-cloth-v02.py','actual-SE-original-material-preparation-v01.log','actual-SE-IDLE6-native-production-v01.log','freeze-SE-IDLE-first-actual-six-native-original-materials-and-renderers-v01.py']:files.append(P/name)
H=Path('/workspace/scratch/mythic413-SE-hit-author-20261020-v01/common-own-SE-native-LEFT-materials-v01/SE-own-native-complete-LEFT-and-old-erased-BODY-readonly-handoff-v01.json');h=json.loads(H.read_text());inputs=[H,Path(h['source']['path']),Path(h['once_body_registration']['path'])]
inputs.extend(Path(x['path'])for x in h['parts'].values());inputs.extend(Path(x['path'])for x in h['semantic_mattes'].values());inputs.extend(Path(x['path'])for x in h['body_inputs']['LEFT-forearm-only-old-erased-BODY-with-original-RIGHT-staff-arms-and-boots'].values());inputs.append(Path(h['fixed_original_RIGHTgear_conservative_native_support']['path']))
inputs.extend([Path('/workspace/scratch/mythic413-SE-base-independent-qc-20261020-v01/SE-new-native-source-and-once-C2816-body-root-registration-PASS-v01.json'),Path('/workspace/scratch/mythic413-nw-n-walk-independent-qc-20261020/SE7c7ab9-once-body-C2816-root-independent-numeric-companion-v01.json')])
producer=Path('/workspace/scratch/mythic413-SE-private-base-generation-fresh-20261020-v01');inputs.extend(producer.glob('*allowlist*.json'))
unique=[];aliases=[];seen={}
for p in files+inputs:
 assert p.is_file(),p
 r=pin(p)
 if r['sha256']in seen:aliases.append(dict(r,identical_bytes_already_listed_source=seen[r['sha256']]))
 else:unique.append(r);seen[r['sha256']]=str(p)
C=P/'actual-SE-IDLE6-native-breath-relax-v01/SE-IDLE-six-actual-native-source-fixed-basis-and-loop-contract-v01.json';f=P/'SE-IDLE-first-actual-six-all-original-materials-shared-inputs-and-renderers-frozen-allowlist-v01.json';f.write_text(json.dumps(dict(status='IMMUTABLE_ACTUAL_NEW_SE_IDLE6_PENDING_INDEPENDENT_SOURCE_AND_VISIBLE_LOOP_QA',files=unique,exact_path_SHA_aliases=aliases,current_exact_six_contract=pin(C),readonly_shared_inputs=[str(x)for x in inputs],new_services=0,new_author_images=0,private_context_bytes_unchanged=5538937,old_profiles_sources_and_approved_clips_modified=False,all6_original_RIGHTgear_lowerbody_RGBA_changes=0,actor_approvals_added=0),indent=2)+'\n');print(json.dumps(dict(manifest=pin(f),unique_files=len(unique),unique_bytes=sum(x['bytes']for x in unique),aliases=len(aliases))))
