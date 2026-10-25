from pathlib import Path
import hashlib,json
B=Path('/workspace/scratch/mythic413-NW-attack-author-20261020-v01');D=B/'actual-NW-ATTACK6-native-rig-v07'
Q=Path('/workspace/scratch/mythic413-nw-n-walk-independent-qc-20261020/NWattack-v07-5a4355-independent-actual-source-cycle-PASS-v01.json')
C=D/'NW-ATTACK6-actual-directional-rig-contract-v07.json';c=json.loads(C.read_text());q=json.loads(Q.read_text())
def pin(p):
 p=Path(p);raw=p.read_bytes();return {'path':str(p),'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw)}
def write(p,j):
 assert not p.exists(),str(p);p.write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n');return pin(p)
assert pin(C)==q['source_contract']
frames=[]
for f,z in zip(c['frames'],q['all_six_independent_binding']):
 assert pin(f['path'])==z['source'] and pin(f['path'])['sha256']==f['sha256']
 frames.append({**f,'source_status':'PASS_ACTUAL_SOURCE_AND_ONE_SHOT_STRIKE3_CYCLE'})
final={'schema':'PR122-author-native-six-pose-cycle-v1','actor':'413','rarity':'mythic','animation':'attack_NW','direction':'NW','loop':False,'fps':6/.42,'existing_role_seconds_preserved':.42,'intended_contact_frame':3,'frames':frames,'physical_C':2048,'bodyunit':2,'common_rig_root_in_unpadded_frame':[641,1058.3],'storage_translations_all_zero':True,'wholeframe_resample_or_perpose_C_or_alphaheightfit':False,'RIGHT_staff_not_full_actor_mirrored':True,'own_direction_actual_HEAD_TORSO_ARMS_LEGS_and_CLOTH_articulated':True,'same_actual_flat_sole_RGBA_all_six':True,'source_visual_status':'PASS','actual_six_source_and_visual_cycle_status':'PASS','independent_QC':pin(Q),'actual_rig_production_contract':pin(C),'all_six_unchanged_importer_strong_body_count':6,'actual_game_binding_status':'PENDING_ROOT_EXACT_PACK_AND_GAME_CONNECTION','actor_approvals_added':0,'source_limitations_preserved':q['visual_limitations']}
F=D/'actual-NW-attack-six-native-frames-SOURCE-CYCLE-PASS-contract-v08.json';fpin=write(F,final)
# Additive immutable allowlist, preserving v01..05 freeze and excluding private preview/live ledger.
paths=set()
for dn in ['actual-NW-ATTACK6-native-rig-v06','actual-NW-ATTACK6-native-rig-v07']:
 for p in (B/dn).rglob('*'):
  if p.is_file() and not any(w in p.name.lower() for w in ('private','preview','ledger')):paths.add(p)
for p in B.glob('*'):
 if p.is_file() and ('v06' in p.name or 'v07' in p.name or p.name.startswith(('trace-NW-ATTACK-phase1','freeze-NW-ATTACK6-source-cycle'))):
  if not any(w in p.name.lower() for w in ('private','preview','ledger','frozen-allowlist')):paths.add(p)
prior=B/'NW-ATTACK6-v01-v05-actual-production-pending-QC-immutable-full-frozen-allowlist-v01.json'
paths.update([Q,prior])
rows=[pin(p) for p in sorted(paths)]
M=B/'NW-ATTACK6-v06-v07-actual-SOURCE-CYCLE-PASS-additive-production-frozen-allowlist-v01.json'
m={'schema':'PR122-immutable-actual-production-allowlist-v1','status':'PASS_ACTUAL_NW_ATTACK6_SOURCE_AND_ONE_SHOT_CYCLE_PREPACKING','final_source_contract':fpin,'independent_QC':pin(Q),'prior_v01_v05_immutable_freeze':pin(prior),'old_variants_remain_HOLD_not_approvals':True,'original_assets_modified':False,'new_walk_production_or_Git_game_profile_CI_actions':0,'actor_approvals_added':0,'files':rows,'file_count':len(rows),'total_bytes':sum(r['bytes'] for r in rows)}
mpin=write(M,m)
print(json.dumps({'final_contract':fpin,'additive_freeze':mpin,'files':len(rows),'bytes':m['total_bytes']}))
