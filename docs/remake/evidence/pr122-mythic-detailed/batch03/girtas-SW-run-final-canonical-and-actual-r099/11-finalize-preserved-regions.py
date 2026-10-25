from pathlib import Path
import json,hashlib,sys,numpy as np
from PIL import Image
p=Path(__file__).parent;sys.path.insert(0,'/workspace/twilight/tools')
import import_original_based_motion as imp
from pr122_reviewed_source_regions import _foreground_owners,_digest
from assemble_pr122_reviewed_poses import finalize_preserved_pose_map
raw=p/'girtas-SW-run-v03six.png';before=hashlib.sha256(raw.read_bytes()).hexdigest();base=imp.analyze(raw,rows_count=6,reference_rows=[0,3],directions_axis='phase_grid2',canvas_size=2048,directions=['SW'])
(p/'geometry-base2048-six.json').write_text(json.dumps(base,indent=2)+'\n')
owners,pin=_foreground_owners(np.asarray(Image.open(raw).convert('RGBA'))[:,:,3],base['frames'])
r={'schema':'pr122-reviewed-source-regions-v1','status':'REVIEWED_SOURCE_REGIONS_PROPOSAL','source_sha256':before,'base_geometry_sha256':_digest(base),'direction':'SW','review_basis':'Six individually strict complete source PNGs, one exact1254-square pose per1536 cell, source SHA/RGBA pinned in pose-map; include original low-alpha fringes by outward metadata only. Independent full selected source proof d80966877c6ae1452dffd5e7ea2c0e200dd3f558f473f01f9170bf0d5c4a96c4. No resize/repack/alpha cleanup or original error deletion.','regions':[[141+(i%2)*1536,141+(i//2)*1536,1254,1254] for i in range(6)],'nearest_owner_sha256':pin['nearest_owner_sha256']}
f=p/'source-region-review.json';assert not f.exists();f.write_text(json.dumps(r,indent=2)+'\n')
proof=finalize_preserved_pose_map(p/'pose-map.json',raw,r,cell_size=1536)
assert hashlib.sha256(raw.read_bytes()).hexdigest()==before
print(json.dumps({'status':proof.get('status'),'raw_sha256':before,'raw_unchanged':True,'proof':str(raw.with_suffix('.assembly.json'))}))
