from pathlib import Path
import hashlib,json
P=Path(__file__).parent;files=[]
def pin(p):p=Path(p);return dict(source=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
for stem in ['actual-E-IDLE6-native-breath-relax-v01','actual-E-IDLE6-native-breath-relax-v02']:
 files.extend(sorted((P/stem).iterdir()))
for name in ['author-E-IDLE6-dedicated-native-thorax-relaxed-arm-and-cloth-v01.py','author-E-IDLE6-dedicated-native-thorax-relaxed-arm-and-cloth-v02.py','actual-E-IDLE6-production-v01.log','actual-E-IDLE6-production-v02.log','freeze-E-IDLE-first-actual-six-and-original-cuff-ownership-failure-v01.py']:files.append(P/name)
inputs=[]
for h in [Path('/workspace/scratch/mythic413-E-attack-author-20261020-v01/common-own-E-native-arm-staff-materials-v01/E-own-native-complete-arm-staff-and-LEFT-only-body-readonly-handoff-v01.json'),Path('/workspace/scratch/mythic413-E-attack-author-20261020-v01/common-own-E-native-arm-staff-materials-v03r1/E-own-native-complete-arm-staff-and-LEFT-only-body-readonly-handoff-v03.json')]:
 inputs.append(h);d=json.loads(h.read_text());inputs.append(Path(d['source']['path']))
 for k in ['LEFT-far-upper-arm','LEFT-far-complete-curved-cuff-forearm-free-hand','RIGHT-near-upper-arm','RIGHT-near-complete-forearm-grip-hand','complete-rigid-RIGHT-near-staff']:inputs.append(Path(d['parts'][k]['path']))
 row=d['body_inputs']['complete-LEFT-arm-old-erased-BODY-with-original-RIGHT-staff-and-boots'];inputs.extend(Path(row[k]['path'])for k in ['body','complete_old_erasure_mask'])
inputs.extend([Path('/workspace/scratch/mythic413-E-hit-author-20261020-v01/E-new-native-one-time-body-density-C2816-root-registration-v01.json'),Path('/workspace/scratch/mythic413-E-base-independent-qc-20261020-v01/E-new-native-source-and-once-C2816-body-root-registration-PASS-v01.json')])
unique=[];aliases=[];seen={}
for p in files+inputs:
 assert p.is_file(),p
 r=pin(p)
 if r['sha256']in seen:aliases.append(dict(r,identical_bytes_already_listed_source=seen[r['sha256']]))
 else:unique.append(r);seen[r['sha256']]=str(p)
f=P/'E-IDLE-first-actual-six-all-native-inputs-renderers-and-cuff-ownership-failure-frozen-allowlist-v01.json';contract=P/'actual-E-IDLE6-native-breath-relax-v02/E-IDLE-six-actual-native-source-fixed-basis-and-loop-contract-v02.json'
z=dict(status='IMMUTABLE_ACTUAL_E_IDLE6_PENDING_INDEPENDENT_SOURCE_AND_VISIBLE_LOOP_QA',files=unique,exact_path_SHA_aliases=aliases,current_source_contract=pin(contract),shared_once_registration_independently_PASS=True,failed_v01_preserved='Actual LEFT cuff cap ownership omitted from old sharedBODY/movingarm; original322+602px and AA now restored to actualmovingmaterial in shared68366061; no original source pixels deleted.',shared_readonly_input_paths=[str(p)for p in inputs],current6_complete_RIGHT_near_arm_grip_staff_and_lowerlegs_RGBA_changes=0,current6_body_component_counts=[1]*6,new_services=0,new_author_images=0,private_context_bytes_unchanged=5538937,actor_approval_added=0,old_profiles_sources_and_approved_animations_modified=False)
f.write_text(json.dumps(z,indent=2)+'\n');print(json.dumps(dict(manifest=pin(f),new_unique_files=len(unique),new_unique_bytes=sum(x['bytes']for x in unique),aliases=len(aliases))))
