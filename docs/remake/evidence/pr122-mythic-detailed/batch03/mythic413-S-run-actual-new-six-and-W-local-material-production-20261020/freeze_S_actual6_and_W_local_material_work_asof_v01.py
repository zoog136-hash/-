from pathlib import Path
import json,hashlib
B=Path(__file__).parent
ledger=B/'image-ledger-v01.json';snapshot=B/'image-ledger-asof-S-RUN6-v08-and-W-local-service-20261020-v01.json';assert not snapshot.exists();snapshot.write_bytes(ledger.read_bytes())
files=set()
for p in B.rglob('*'):
 if not p.is_file()or '__pycache__'in p.parts or p.name.startswith('private-')or p==ledger or p.name=='RUN-production-current-progress-v01.json'or p.name.endswith('.pyc'):continue
 if p.name.startswith('S-RUN6-v08-and-W-local-materials-immutable-allowlist-'):continue
 files.add(p)
contracts=[Path('/workspace/scratch/mythic413-S-death-author-20261020-v01/actual-own-S-DEATH-ninety-native-posed-parts-v01/actual-original-native-inputs/own-S-DEATH-readonly-real-part-inputs-cape-CORE-explicitly-not-loaded-v01.json')]
for version in ['v03','v04','v07','v08']:contracts.append(Path(f'/workspace/scratch/mythic413-S-death-author-20261020-v01/actual-own-S-DEATH-complete-native-materials-{version}/own-S-DEATH-complete-native-materials-and-QA-cape-source-handoff-{version}.json'))
contracts.append(Path('/workspace/scratch/mythic413-W-hit-author-20261020-v01/W-final-once-body-real-cloth-complete-LEFT-original-boots-readonly-future-action-handoff-v01.json'))
for p in contracts:
 files.add(p);d=json.loads(p.read_text())
 for key in ['source','once_registration','canonical_sole_capture','source_cape_CORE','arm_staff_input','head_fullboot_input','actual_prepared_head_boot_inputs','original_once_neutral_floor_model']:
  r=d.get(key)
  if isinstance(r,dict)and 'path'in r and Path(r['path']).is_file():files.add(Path(r['path']))
 for group in ['materials','mattes']:
  for r in d.get(group,{}).values():
   if isinstance(r,dict)and'path'in r:files.add(Path(r['path']))
 sole=d.get('canonical_sole_capture')or d.get('original_once_neutral_floor_model')
 if sole:
  sp=Path(sole['path']);files.add(sp);sd=json.loads(sp.read_text())
  for m in sd['source_material_capture_models']:
   for key in ['exact_original_native_material','exact_source_alpha_support']:files.add(Path(m[key]['path']))
for name in ['S-shared-pure-boot-v07-calf-AA-and-exact-cloak-owner-PASS-v01.json','S-opposite-small-blue-triangle-genuine-LEFT-uppercuff-owner-PASS-v01.json']:
 files.add(Path('/workspace/scratch/mythic413-W-actual-quality-independent-20261020-v01')/name)
rows=[]
for p in sorted(files):
 assert p.is_file(),p;size=p.stat().st_size;assert size<=10*1024*1024,(p,size);data=p.read_bytes();rows.append(dict(path=str(p),bytes=size,sha256=hashlib.sha256(data).hexdigest()))
final=B/'S-RUN6-v08-and-W-local-materials-immutable-allowlist-asof-20261020-v01.json';assert not final.exists();j=dict(schema='PR122-IMMUTABLE-EXPLICIT-FILES-SOURCE-AND-ALL-FAILED-VERSIONS-v1',status='FROZEN_ACTUAL_NEW_S_RUN6_V08_SOURCE_PENDING_INDEPENDENT_GAIT_QC_AND_W_LOCAL_MATERIAL_CANDIDATES_NO_ACTOR_APPROVAL',files=rows,file_count=len(rows),total_bytes=sum(r['bytes']for r in rows),single_file_limit_bytes=10*1024*1024,excluded=['private previews','mutable live image ledger','live progress','Python bytecode'],image_ledger_asof_snapshot=str(snapshot),actual_image_cumulative_bytes_asof=json.loads(snapshot.read_text())['actual_cumulative_bytes'],final_S_actual6_contract='/workspace/scratch/mythic413-S-run-author-fresh-20261020-v01/actual-S-RUN6-native-full-actor-v04/S-RUN6-own-actual-new-native-full-actor-source-contract-v01.json',final_S_finite_clock_projection_floor_witness=str(B/'S-RUN6-actual-new-six-opposite-contact-clock-identity-projection-and-finite-floor-witness-v02.json'),W_single_successful_hidden_upperleg_raw='/workspace/scratch/mythic413-S-run-author-fresh-20261020-v01/W-original-native-boot-semantic-prep-v01/service-W-far-hidden-upperleg-raw-r001-untouched.png',W_distinct_calf_request_output_rejected_no_retry=True,game_clips_adopted=0,actor_approvals_added=0,tracked_files_changed_by_author=0);final.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps(dict(path=str(final),sha256=hashlib.sha256(final.read_bytes()).hexdigest(),file_count=j['file_count'],bytes=j['total_bytes'],allowlist_bytes=final.stat().st_size,max_file_bytes=max(r['bytes']for r in rows))))
