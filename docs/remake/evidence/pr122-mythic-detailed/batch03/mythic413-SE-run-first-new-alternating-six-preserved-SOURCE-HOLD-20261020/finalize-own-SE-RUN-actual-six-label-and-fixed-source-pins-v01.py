from pathlib import Path
import json,hashlib,copy
B=Path(__file__).parent;D=B/'actual-own-SE-RUN-six-native-v01'
def pin(p):return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
prior=D/'own-SE-RUN-six-actual-native-source-contract-v01.json';c=json.loads(prior.read_text());assert c['direction']=='SE'and len(c['frames'])==6
# The shared code's status string retained E. Correct that one text label in
# a new metadata file, retaining every actual new SE PNG, source, pose and pin.
c.update(status='ACTUAL_NEW_OWN_SE_RUN_SIX_SOURCE_PENDING_INDEPENDENT_NATIVE_FEET_GRIP_LOOP_AND_GAME_QC',prior_actual_SE_source_contract=pin(prior),metadata_direction_label_only_corrected=True,actual_all6_PNG_node_UV_C_root_clock_floor_unchanged=True)
cp=D/'own-SE-RUN-six-actual-native-source-contract-v02.json';cp.write_text(json.dumps(c,indent=2)+'\n')
old=D/'actual-RUN-six-engineering-control-and-PNG-binding-v01.json';r=json.loads(old.read_text());r.update(contract=pin(cp),prior_actual_native_engineering_receipt=pin(old),same_exact_six_PNG_and_108_original_native_rasters=True,only_status_text_corrected=True)
rp=D/'actual-SE-RUN-six-engineering-control-and-PNG-binding-v02.json';rp.write_text(json.dumps(r,indent=2)+'\n')
ap=D/'SE-RUN-final-exact-six-source-code-and-label-pin-allowlist-v02.json';files=[p for p in D.rglob('*')if p.is_file()and p!=ap]+[Path(__file__),B/'author-own-SE-RUN-six-native-v01.py',B/'verify-own-new-RUN-source-controls-and-actual-PNG-v01.py',B/'prepare-private-common-six-source-preview-v01.py'];ap.write_text(json.dumps(dict(status='IMMUTABLE_FINAL_SE_NEW_ACTUAL_SIX_NATIVE_SOURCE_ALLOWLIST_PENDING_INDEPENDENT_QC',contract=pin(cp),engineering=pin(rp),actual_frames=[{k:f[k]for k in['path','bytes','sha256']}for f in c['frames']],files=[pin(p)for p in files],prior_actual_source_versions_preserved=True,actor_approvals_added=0),indent=2)+'\n')
print(json.dumps(dict(contract=pin(cp),engineering=pin(rp),allowlist=pin(ap),actual_source_or_art_changed=False,actual_new_SE_poses=6)))
