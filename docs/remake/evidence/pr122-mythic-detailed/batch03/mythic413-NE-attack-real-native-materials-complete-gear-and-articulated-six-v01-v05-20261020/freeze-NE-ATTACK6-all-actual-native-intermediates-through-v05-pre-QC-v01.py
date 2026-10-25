from pathlib import Path
import json,hashlib
B=Path(__file__).parent

def pin(p):p=Path(p);r=p.read_bytes();return {'path':str(p),'sha256':hashlib.sha256(r).hexdigest(),'bytes':len(r)}
paths={p for p in B.rglob('*')if p.is_file()and p.suffix.lower()in('.py','.png','.json','.npy')and not any(w in p.name.lower()for w in('private','preview','ledger','frozen-allowlist'))}
external=[
'/workspace/scratch/mythic413-NE-walk-author-20261020-v01/NE-contact0-actual-native-background-AA-clean-r002.png',
'/workspace/scratch/mythic413-NE-walk-author-20261020-v01/NE-RUN-source-material-handoff-v01.json',
'/workspace/scratch/mythic413-NE-run-author-20261020-v01/common-complete-NE-native-material-parts-v03/original-actual-BODY-only-complete-old-thigh-and-arm-removed-native.png',
'/workspace/scratch/mythic413-NE-run-author-20261020-v01/common-complete-NE-native-material-parts-v03/original-actual-complete-LEFT-cuff-elbow-cap-forearm-hand-native.png',
'/workspace/scratch/mythic413-NE-run-author-20261020-v01/common-complete-NE-native-material-parts-v03/original-actual-complete-RIGHT-thigh-and-calf-native.png',
'/workspace/scratch/mythic413-NE-run-author-20261020-v01/common-complete-NE-native-material-parts-v03/actual-complete-thigh-arm-and-short-joint-native-source-provenance-v01.json',
'/workspace/scratch/mythic413-NE-walk-author-20261020-v01/actual-NE-LOAD1-semantic-speck-finish-v03/original-native-RIGHT-complete-shoe-and-leg-material-staff-speck-excluded.png',
'/workspace/scratch/mythic413-NE-walk-author-20261020-v01/actual-NE-LOAD1-rig-v02/original-native-complete-LEFT-visible-boot-material.png',
'/workspace/scratch/mythic413-NE-hit-author-20261020-v01/actual-NE-HIT6-own-native-articulated-v01/NE-HIT-original-native-two-boot-stationary-brace-once-registration-v01.json']
paths.update(map(Path,external));rows=[pin(p)for p in sorted(paths)]
C=B/'actual-NE-ATTACK6-native-rig-v05/NE-ATTACK6-exact-final-actual-native-source-provenance-contract-v06.json'
j={'schema':'PR122-immutable-full-actual-production-allowlist-v1','status':'ACTUAL_NE_ATTACK6_THROUGH_FINAL_V05_ALL_INTERMEDIATES_PRESERVED_PENDING_INDEPENDENT_SOURCE_QC','current_actual_six_contract':pin(C),'C':2432,'bodyunit':2.375,'common_rig_root':[716.2291666666666,1054.2766007046484],'storage_translation':[0,0],'native_canvas':[1536,1536],'whole_actor_mirror_or_existing_clips_modified':False,'prior_failed_or_HOLD_sources_remain_not_approvals':True,'actor_game_approvals_added':0,'file_count':len(rows),'total_bytes':sum(z['bytes']for z in rows),'files':rows}
p=B/'NE-ATTACK6-v01-v05-actual-native-inputs-parts-masks-renderers-full-immutable-frozen-allowlist-v01.json';assert not p.exists();p.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps({'freeze':pin(p),'files':len(rows),'bytes':j['total_bytes']}))
