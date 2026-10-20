from pathlib import Path
import json,hashlib
B=Path(__file__).parent
def pin(p):p=Path(p);b=p.read_bytes();return dict(path=str(p),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b))
prior=B/'SE-ATTACK-actual-local-cape-v03-v07-final-six-v03-v04-all-intermediate-additive-frozen-allowlist-v02.json';j=json.loads(prior.read_text());allfiles={}
for d in ['actual-own-SE-ATTACK-native-final-nine-shaft-edge-AA-owner-v08','actual-SE-ATTACK6-native-articulated-rig-v05']:
 for p in (B/d).rglob('*'):
  if p.is_file() and 'private' not in p.name.lower():allfiles[str(p)]=pin(p)
for n in ['finish-SE-actual-nine-shaft-edge-AA-original-owner-v08.py','author-SE-ATTACK6-own-native-final-nine-shaft-edge-AA-owner-v05.py','verify-SE-final-nine-shaft-edge-v05-exact-native-and-six-transfer.py','SE-actual-v05-nine-edge-render-run.log','SE-final-nine-edge-proof-v05.log',Path(__file__).name]:
 p=B/n;allfiles[str(p)]=pin(p)
q={'schema':'PR122-immutable-actual-production-additive-allowlist-v1','prior_frozen_allowlist':pin(prior),'files':list(allfiles.values()),'file_count':len(allfiles),'total_bytes':sum(x['bytes']for x in allfiles.values()),'files_over_10MiB':[x for x in allfiles.values()if x['bytes']>10*1024*1024],'source_status':'ACTUAL_F7F9_CANDIDATE_PENDING_FORMAL_FINAL_SOURCE_GATE','new_image_calls_or_returns':0,'actual_author_image_ledger_bytes':6017817,'originals_modified':False,'actor_approvals_added':0};p=B/'SE-ATTACK-final-nine-shaft-edge-AA-v08-and-actual-six-v05-additive-frozen-allowlist-v03.json';p.write_text(json.dumps(q,indent=2)+'\n');print(json.dumps({'freeze':pin(p),'files':q['file_count'],'bytes':q['total_bytes'],'over10MiB':len(q['files_over_10MiB'])}))
