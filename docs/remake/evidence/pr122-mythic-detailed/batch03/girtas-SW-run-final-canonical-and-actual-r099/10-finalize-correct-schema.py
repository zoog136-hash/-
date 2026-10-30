from pathlib import Path
import json,hashlib,sys
p=Path(__file__).parent;sys.path.insert(0,'/workspace/twilight/tools')
from assemble_pr122_reviewed_poses import finalize_preserved_pose_map
j=json.loads((p/'source-region-review.json').read_text());j['schema']=1;f=p/'source-region-review.v02.json';assert not f.exists();f.write_text(json.dumps(j,indent=2)+'\n')
raw=p/'girtas-SW-run-v03six.png';before=hashlib.sha256(raw.read_bytes()).hexdigest();proof=finalize_preserved_pose_map(p/'pose-map.json',raw,j,cell_size=1536);assert hashlib.sha256(raw.read_bytes()).hexdigest()==before
print(json.dumps({'status':proof.get('status'),'raw_sha256':before,'raw_unchanged':True,'proof':str(raw.with_suffix('.assembly.json'))}))
