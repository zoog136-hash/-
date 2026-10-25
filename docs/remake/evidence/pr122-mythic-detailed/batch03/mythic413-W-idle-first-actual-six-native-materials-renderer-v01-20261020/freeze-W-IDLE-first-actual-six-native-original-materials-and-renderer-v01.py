from pathlib import Path
import json,hashlib,sys
P=Path(__file__).parent;files=[]
def pin(p):p=Path(p);return dict(source=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
for name in ['actual-W-native-source-node-material-INPUT-v01','actual-W-IDLE6-native-breath-relax-v01']:files.extend(sorted((P/name).iterdir()))
for name in ['prepare-W-original-native-materials-and-continuous-node-ownership-v01.py','author-W-IDLE6-own-native-breath-cuff-neck-and-cloth-v01.py','actual-W-original-material-preparation-v01.log','actual-W-IDLE6-native-production-v01.log','freeze-W-IDLE-first-actual-six-native-original-materials-and-renderer-v01.py']:files.append(P/name)
H=Path(sys.argv[1]);CFG=Path(sys.argv[2]);cfg=json.loads(CFG.read_text());files.append(CFG);h=json.loads(H.read_text());inputs=[H,Path(h['source']['path']),Path(h['once_body_registration']['path'])]
inputs.extend(Path(x['path'])for x in h['parts'].values());inputs.extend(Path(x['path'])for x in h['semantic_mattes'].values());inputs.extend(Path(x['path'])for x in h['body_inputs']['LEFT-forearm-only-old-erased-BODY-with-original-RIGHT-staff-arms-and-boots'].values());inputs.append(Path(h['fixed_original_RIGHTgear_conservative_native_support']['path']))
inputs.extend(map(Path,sys.argv[3:6]))
unique=[];aliases=[];seen={}
for p in files+inputs:
 assert p.is_file(),p
 r=pin(p)
 if r['sha256']in seen:aliases.append(dict(r,identical_bytes_already_listed_source=seen[r['sha256']]))
 else:unique.append(r);seen[r['sha256']]=str(p)
C=P/'actual-W-IDLE6-native-breath-relax-v01/W-IDLE-six-actual-native-source-fixed-basis-and-loop-contract-v01.json';out=P/'W-IDLE-first-actual-six-all-original-materials-shared-inputs-and-renderer-frozen-allowlist-v01.json';out.write_text(json.dumps(dict(status='IMMUTABLE_ACTUAL_NEW_W_IDLE6_PENDING_INDEPENDENT_SOURCE_AND_VISIBLE_LOOP_QA',files=unique,exact_path_SHA_aliases=aliases,current_exact_six_contract=pin(C),readonly_shared_inputs=[str(x)for x in inputs],stationary_scope=cfg['stationary_scope'],only_exact_current_once_basis_USED=True,other_sources_and_old_clips_unmodified=True,new_services=0,new_author_images=0,private_context_bytes_unchanged=5538937,old_profiles_sources_and_approved_clips_modified=False,all6_original_RIGHTgear_and_complete_lowerbody_RGBA_changes=0,actor_approvals_added=0),indent=2)+'\n');print(json.dumps(dict(manifest=pin(out),unique_files=len(unique),unique_bytes=sum(x['bytes']for x in unique),aliases=len(aliases))))
