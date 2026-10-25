from pathlib import Path
import hashlib,json
B=Path(__file__).parent
def pin(p):p=Path(p);b=p.read_bytes();return {'path':str(p),'sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b)}
files={}
for p in B.rglob('*'):
 if p.is_file() and not any(v in str(p.relative_to(B)).lower()for v in ['private','preview','__pycache__','frozen-allowlist']):files[str(p)]=pin(p)
def addrefs(o):
 if isinstance(o,dict):
  if isinstance(o.get('path'),str) and 'sha256'in o:
   p=Path(o['path'])
   if p.is_file() and 'private' not in p.name.lower():files[str(p)]=pin(p)
  for v in o.values():addrefs(v)
 elif isinstance(o,list):
  for v in o:addrefs(v)
for p in [B/'actual-own-S-ATTACK-native-full-shoulder-and-original-specific-owners-v02/S-ATTACK-full-anatomical-LEFTupper-and-specific-original-owners-cape-HOLD-v02.json',Path('/workspace/scratch/mythic413-S-hit-author-20261020-v01/common-own-S-native-LEFT-materials-v01/S-own-native-complete-LEFT-and-old-erased-BODY-readonly-handoff-v01.json')]:addrefs(json.loads(p.read_text()));files[str(p)]=pin(p)
for n in ['S-new-native-source-and-once-C2560-body-root-registration-PASS-v01.json','S-c9a5-once-body-C2560-root-independent-numeric-companion-v01.json']:
 p=Path('/workspace/scratch/mythic413-S-base-independent-qc-20261020-v01')/n;files[str(p)]=pin(p)
j={'schema':'PR122-immutable-real-production-preserve-all-intermediates-v1','status':'ACTUAL_OWN_S_ATTACK6_V01_V02_PENDING_LOCAL_CAPE_AND_HEADRIBBON_SOURCE_FINISH','files':list(files.values()),'file_count':len(files),'total_bytes':sum(x['bytes']for x in files.values()),'files_over_10MiB':[x for x in files.values()if x['bytes']>10*1024*1024],'source_approval_added':0,'actor_approval_added':0,'actual_author_image_ledger_bytes':6017817,'new_image_requests_or_receipts':0,'scope':'Actual v01/v02 six PNGs/nodes, complete own upper/forehand/staff parts, all masks, rigs/scripts/logs, failures/semantic traces, exact once-source/basis/commonLEFT and250localrequest. No private previews or liveledger.'};q=B/'S-ATTACK-actual-six-v01-v02-all-own-parts-rig-and-local-request-immutable-frozen-allowlist-v01.json';q.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps({'freeze':pin(q),'files':j['file_count'],'bytes':j['total_bytes'],'over10MiB':len(j['files_over_10MiB'])}))
