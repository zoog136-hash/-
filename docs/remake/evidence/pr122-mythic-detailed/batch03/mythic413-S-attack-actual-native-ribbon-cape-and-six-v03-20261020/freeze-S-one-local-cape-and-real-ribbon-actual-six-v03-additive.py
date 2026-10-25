from pathlib import Path
import json,hashlib
B=Path(__file__).parent;P=B/'S-ATTACK-actual-six-v01-v02-all-own-parts-rig-and-local-request-immutable-frozen-allowlist-v01.json';prior=json.loads(P.read_text())
def pin(p):p=Path(p);b=p.read_bytes();return dict(path=str(p),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b))
old={x['path']:x for x in prior['files']};files={};mutated=[]
for path,x in old.items():
 if pin(path)['sha256']!=x['sha256']:mutated.append(path)
assert not mutated
for p in B.rglob('*'):
 if p.is_file() and not any(t in p.name.lower()for t in ['private','preview','frozen-allowlist']) and '__pycache__'not in str(p) and str(p)not in old:files[str(p)]=pin(p)
G=Path('/workspace/scratch/mythic413-S-cape-private-local-production-fresh-20261020-v01');F=G/'S-private-local-production-freeze-v01.json';service=json.loads(F.read_text())
def addrefs(o):
 if isinstance(o,dict):
  if isinstance(o.get('path'),str)and 'sha256'in o:
   p=Path(o['path'])
   if p.is_file()and not any(t in p.name.lower()for t in ['private','preview','ledger'])and str(p)not in old:files[str(p)]=pin(p)
  for v in o.values():addrefs(v)
 elif isinstance(o,list):
  for v in o:addrefs(v)
addrefs(service);q=G/'S-cape-single-local-retouch-exact-use-contract-final-handoff-v01.json';files[str(q)]=pin(q)
j={'schema':'PR122-immutable-actual-production-additive-allowlist-v1','prior_frozen_allowlist':pin(P),'prior135files_changed':0,'files':list(files.values()),'file_count':len(files),'total_bytes':sum(x['bytes']for x in files.values()),'files_over_10MiB':[x for x in files.values()if x['bytes']>10*1024*1024],'status':'ACTUAL_OWN_S_ATTACK6_V03_REAL_RIBBON_PASSED_LOCAL_MATERIAL_PENDING_POSED_QA_AND_CAPE_GOLDHEM_NARROW_HOLD','source_actor_game_approval_added':0,'actual_author_cumulative_image_bytes':6017817,'new_image_views_services_or_returns_by_author':0,'mask_expanded':False,'original_source_bodyunit_C_root_perposefit_changed':False};q=B/'S-ATTACK-one-local-cape-real-ribbon-v03-v05-and-actual-six-v03-additive-frozen-allowlist-v02.json';q.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps({'freeze':pin(q),'files':j['file_count'],'bytes':j['total_bytes'],'over10MiB':len(j['files_over_10MiB'])}))
