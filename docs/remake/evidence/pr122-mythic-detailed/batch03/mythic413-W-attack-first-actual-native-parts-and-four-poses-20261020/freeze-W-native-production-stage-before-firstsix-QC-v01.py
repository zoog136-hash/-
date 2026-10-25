from pathlib import Path
import json,hashlib
B=Path(__file__).parent;O=B/'frozen-W-production-inputs-drafts-and-code-stage-v01';O.mkdir(exist_ok=False)
def pin(p):p=Path(p);b=p.read_bytes();return dict(path=str(p),bytes=len(b),sha256=hashlib.sha256(b).hexdigest())
files=set()
def walk(j):
 if isinstance(j,dict):
  if 'path'in j and 'sha256'in j:
   p=Path(j['path']);assert p.is_file();q=pin(p);assert q['sha256']==j['sha256'];files.add(p)
  for v in j.values():walk(v)
 elif isinstance(j,list):
  for v in j:walk(v)
for rel in ['native-W-source-parts-v01/W-exact-native-RIGHT-fullstaff-near-LEFT-upper-real-cloth-source-parts-v01.json','native-W-source-parts-v03-exact-rims-bow/W-exact-native-complete-RIGHT-staff-LEFT-upper-and-true-bow-parts-v03.json']:
 p=B/rel;files.add(p);walk(json.loads(p.read_text()))
for glob in ['prepare-own-W-native-RIGHT-complete-staff-and-near-LEFT-upper-v01.py','finish-W-exact-staff-arm-rims-near-upper-and-true-bow-owner-v0[23].py','author-own-W-ATTACK6-native-*.py','actual-W-ATTACK6-native-profile-rig-v01/*.png']:
 files.update(B.glob(glob))
fail=O/'W-production-draft-failures-and-native-owner-corrections-v01.json';fail.write_text(json.dumps(dict(status='ACTUAL_PRODUCTION_HISTORY_NOT_APPROVAL',draft_v01='Four lossless native PNGs produced; body inverse 20 iterations exceeded 1e-4 at FOLLOW .00216147, so no false PASS and no final contract. Negative load/windup staff angles crossed fixed boot lock and were superseded; LEFT guard angles also revised for true clearance.',correction_v02='Preserved failed source code: component seed did not select actual 105pixel goldforearmrim and assert stopped before new parts outputs. Selected exact native component by size in v03, source reconstruction unchanged0.',production_v03='Full staff/hand/puff rigid together; all source pieces exactRGBA, approved genuine cloth only; field40 iterations, original1e-4 threshold unchanged.',new_source_or_actor_approvals=0),indent=2)+'\n');files.add(fail);files.add(Path(__file__))
rows=[pin(p)for p in sorted(files)];j=dict(schema='MYTHIC413_W_IMMUTABLE_NATIVE_PRODUCTION_STAGE_FROZEN_ALLOWLIST_V01',status='ACTUAL_SOURCE_INPUTS_PARTS_CODE_AND_DRAFTS_NOT_SOURCE_OR_ACTOR_APPROVAL',files=rows,total_files=len(rows),total_bytes=sum(q['bytes']for q in rows),current_actual_six_will_be_separate_additive_freeze=True,private_previews_live_logs_ledger_and_unrelated_resources_excluded=True,source_or_once_overwritten=False,actor_approvals_added=0);f=O/'W-actual-native-source-parts-code-and-four-draft-PNG-frozen-allowlist-v01.json';f.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps(dict(allowlist=pin(f),total_files=len(rows),total_bytes=j['total_bytes'])))
