from pathlib import Path
import json,hashlib
P=Path(__file__).parent
previous=P/'NW-DEATH-actual-final-six-validated-original-cloth-volume-and-all-intermediates-frozen-allowlist-v03.json'
def pin(p):return dict(source=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
known={}
def walk(p):
 d=json.loads(p.read_text())
 for key in ['files','exact_path_SHA_aliases']:
  for r in d.get(key,[]):
   if 'sha256'in r:known[r['sha256']]=r.get('source',r.get('path'))
 q=d.get('previous_frozen_manifest');q=q.get('source',q.get('path'))if isinstance(q,dict)else q
 if q:walk(Path(q))
walk(previous)
selected=[]
for stem in ['actual-NW-DEATH-single-phase0-rest-transverse-raw-v10','actual-NW-DEATH-single-phase0-rest-transverse-final-v10','NW-DEATH-exact-editable-source-semantic-map-v01']:
 selected.extend(sorted((P/stem).iterdir()))
for name in ['author-NW-DEATH-single-phase0-true-rest-transverse-v10.py','finish-NW-DEATH-single-phase0-true-rest-transverse-v10.py','pin-NW-DEATH-exact-editable-material-surfaces-v01.py','select-NW-DEATH-final-six-source-rest-fixed-v11.py','freeze-NW-DEATH-true-rest-plane-and-editable-source-map-v04.py','single-phase0-rest-transverse-production-v10.log','single-phase0-rest-transverse-final-v10.log','exact-editable-material-source-map-v01.log','NW-DEATH-final-six-actual-source-constant-root-and-native-registration-v11.json']:selected.append(P/name)
new=[];aliases=[]
for p in selected:
 assert p.is_file(),p
 r=pin(p)
 if r['sha256']in known:aliases.append(dict(r,identical_bytes_already_frozen_source=known[r['sha256']]))
 else:new.append(r);known[r['sha256']]=str(p)
out=P/'NW-DEATH-actual-final-rest-plane-all-inputs-and-exact-editable-material-map-frozen-allowlist-v04.json'
d=dict(status='IMMUTABLE_ACTUAL_FINAL_SIX_SOURCE_GATE_CLOSED_FORMAL_SOURCE_AND_FINITE_FLOOR_RECEIPTS_PENDING',files=new,exact_path_SHA_aliases=aliases,previous_frozen_manifest=pin(previous),final_exact_six_contract=pin(P/'NW-DEATH-final-six-actual-source-constant-root-and-native-registration-v11.json'),private_context_bytes_unchanged=5538937,new_services=0,new_author_images=0,actor_approval_added=0,source_modified_after_freeze=False)
out.write_text(json.dumps(d,indent=2)+'\n');print(json.dumps(dict(manifest=pin(out),unique_new_files=len(new),unique_new_bytes=sum(x['bytes']for x in new),aliases=len(aliases))))
