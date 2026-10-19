from pathlib import Path
import json,hashlib,sys
p=Path(__file__).parent;sys.path.insert(0,'/workspace/twilight/tools')
from assemble_pr122_reviewed_poses import finalize_preserved_pose_map
j=json.loads((p/'source-region-review.v02.json').read_text());b=json.loads((p/'geometry-base2048-six.json').read_text());r=[]
for old,full in zip(b['frames'],j['regions']):
 a=old['region'];x=min(a[0],full[0]);y=min(a[1],full[1]);right=max(a[0]+a[2],full[0]+full[2]);bottom=max(a[1]+a[3],full[1]+full[3]);r.append([x,y,right-x,bottom-y])
j['regions']=r;j['review_basis']+=' Retain original automatic transparent 1-2px top padding in phases0/1 as well: each review rectangle is exact union of original base rectangle and full selected1254source rectangle. No pixel change.'
f=p/'source-region-review.v03.json';assert not f.exists();f.write_text(json.dumps(j,indent=2)+'\n')
raw=p/'girtas-SW-run-v03six.png';before=hashlib.sha256(raw.read_bytes()).hexdigest();proof=finalize_preserved_pose_map(p/'pose-map.json',raw,j,cell_size=1536);assert hashlib.sha256(raw.read_bytes()).hexdigest()==before
print(json.dumps({'status':proof.get('status'),'raw_sha256':before,'raw_unchanged':True,'proof':str(raw.with_suffix('.assembly.json'))}))
