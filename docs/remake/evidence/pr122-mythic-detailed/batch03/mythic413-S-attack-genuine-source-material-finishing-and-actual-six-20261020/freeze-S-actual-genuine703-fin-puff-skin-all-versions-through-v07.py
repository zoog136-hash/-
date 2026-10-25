from pathlib import Path
import json,hashlib
B=Path(__file__).parent;P=B/'S-ATTACK-one-local-cape-real-ribbon-v03-v05-and-actual-six-v03-additive-frozen-allowlist-v02.json'
def pin(p):p=Path(p);b=p.read_bytes();return dict(path=str(p),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b))
def chain(p,seen=None):
 seen={}if seen is None else seen;j=json.loads(Path(p).read_text())
 for v in j.get('files',[]):seen[v['path']]=v
 if j.get('prior_frozen_allowlist'):chain(j['prior_frozen_allowlist']['path'],seen)
 return seen
prior=chain(P);bad=[p for p,v in prior.items()if pin(p)['sha256']!=v['sha256']];assert not bad
files={}
for p in B.rglob('*'):
 if p.is_file()and str(p)not in prior and not any(s in p.name.lower()for s in ['private','preview','frozen-allowlist'])and '__pycache__'not in str(p):files[str(p)]=pin(p)
QA=Path('/workspace/scratch/mythic413-S-death-author-20261020-v01/S-original-native-gold-V-cape-versus-rigid-jewel-fins-independent-owner-PASS-v01.json');files[str(QA)]=pin(QA)
j={'schema':'PR122-immutable-additive-real-production-v1','prior_frozen_allowlist':pin(P),'prior_files_verified_unchanged':len(prior),'files':list(files.values()),'file_count':len(files),'total_bytes':sum(v['bytes']for v in files.values()),'files_over10MiB':[v for v in files.values()if v['bytes']>10*1024*1024],'current_actual6_contract':pin(B/'actual-S-ATTACK6-own-native-articulated-rig-v07/S-ATTACK6-own-actual-native-front-six-rig-and-local-cape-HOLD-contract-v07.json'),'status':'SOURCE_HOLD_PENDING_FINAL_NATIVE_SKIN_AND_PUFF_QC_ALL_ORIGINALS_FAILURES_PRESERVED','original_source_or_C_root_unit_game_changed':False,'actual_author_image_cumulative_bytes':6017817,'new_image_service_view_returns_by_author':0,'actor_approvals_added':0};q=B/'S-ATTACK-genuine703-fin-puff-skin-material-v06-v10r1-and-actual-six-v04-v07-additive-frozen-allowlist-v03.json';q.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps({'freeze':pin(q),'files':j['file_count'],'bytes':j['total_bytes'],'over10MiB':len(j['files_over10MiB']),'prior_unchanged':len(prior)}))
