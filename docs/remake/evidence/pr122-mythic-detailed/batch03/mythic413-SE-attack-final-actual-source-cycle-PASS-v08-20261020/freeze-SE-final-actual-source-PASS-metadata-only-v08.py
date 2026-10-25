from pathlib import Path
import json,hashlib
B=Path(__file__).parent
P=B/'actual-SE-ATTACK6-native-articulated-rig-v05/SE-ATTACK6-actual-native-final-specific-owner-and-PASS-cape-candidate-contract-v07.json';j=json.loads(P.read_text())
def pin(p):p=Path(p);b=p.read_bytes();return dict(path=str(p),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b))
QA=Path('/workspace/scratch/mythic413-nw-n-walk-independent-qc-20261020/SEattack-v05-f7f9b8-independent-final-actual-source-one-shot-cycle-PASS-v01.json');q=json.loads(QA.read_text());assert pin(QA)['sha256']=='41fd83fc688327f780c1d8cd8540b88d8a14407ed8c2855dd877d379527289f3';assert pin(P)['sha256']=='f7f9b8475a5dce8995b4a12d52f772bac1aca777178239f2cd63b4400c17b43c'
j['status']='INDEPENDENT_ACTUAL_NATIVE_SOURCE_AND_ONE_SHOT_ATTACK6_CYCLE_PASS_PENDING_PARENT_EXACTPACK_AND_GAME';j['prior_actual_candidate_contract']=pin(P);j['independent_actual_source_one_shot_cycle_PASS']=pin(QA);j['final_actual_node_and_fixedsole_proof']=pin(P.parent/'SE-ATTACK6-final-nine-shaft-edge-owner-v05-exact-36node-sole-cape-transfer-proof-v01.json');j['metadata_only_repin_no_PNG_node_controls_C_root_storage_changes']=True;j['game_actor_or_detailed_approvals_added']=0
for f in j['frames']:f['status']='INDEPENDENT_ACTUAL_SOURCE_AND_ONE_SHOT_CYCLE_PASS_GAME_PENDING'
FP=P.parent/'SE-ATTACK6-final-actual-native-SOURCE-ONE-SHOT-PASS-contract-v08.json';FP.write_text(json.dumps(j,indent=2)+'\n');files={str(p):pin(p)for p in [FP,QA,Path(__file__)]}
def capture(o):
 if isinstance(o,dict):
  if 'path'in o and 'sha256'in o:
   p=Path(o['path'])
   if p.is_file() and ('independent' in p.name or 'independent' in str(p.parent)):files[str(p)]=pin(p)
  for v in o.values():capture(v)
 elif isinstance(o,list):
  for v in o:capture(v)
capture(q)
prior=B/'SE-ATTACK-final-nine-shaft-edge-AA-v08-and-actual-six-v05-additive-frozen-allowlist-v03.json';freeze={'schema':'PR122-additive-immutable-SOURCE-PASS-metadata-only-freeze-v1','prior_frozen_allowlist':pin(prior),'final_contract':pin(FP),'source_status':'INDEPENDENT_SOURCE_ONE_SHOT_PASS_GAME_PENDING','files':list(files.values()),'file_count':len(files),'total_bytes':sum(x['bytes']for x in files.values()),'all_source_PNGs_and_actual_nodes_unchanged':True,'author_actual_cumulative_image_bytes':6017817,'new_image_calls_returns':0,'actor_approvals_added':0};f=B/'SE-ATTACK-final-actual-SOURCE-PASS-contract-v08-and-independent-QC-additive-frozen-allowlist-v04.json';f.write_text(json.dumps(freeze,indent=2)+'\n');print(json.dumps({'contract':pin(FP),'freeze':pin(f),'files':len(files),'bytes':freeze['total_bytes']}))
