from pathlib import Path
from PIL import Image
import json,hashlib,sys
root=Path('/workspace/scratch');p=Path(__file__).parent;repo=Path('/workspace/twilight');sys.path.insert(0,str(repo/'tools'))
from assemble_pr122_reviewed_poses import assemble_pose_map
j=json.loads((p/'candidate-source-pins.pending.json').read_text());poses=[]
for s in j['sources']:
 f=Path(s['path']);assert hashlib.sha256(f.read_bytes()).hexdigest()==s['source_sha256'];phase=s['phase']
 poses.append({'path':str(f),'source_sha256':s['source_sha256'],'source_pose':0,'target_pose':phase,'region':[0,0,1254,1254],'rgba_sha256':s['rgba_sha256'],'newly_authored':True,'review_basis':'Fresh independent actual SW SOURCE PASS confirmed 2026-10-19 by /root/girtas_remaining_run_source_runtime_qc_v02: original0/1/2/repaired3/4/5 camera/model/gear/anatomical support and trueflight coherent; idle-only hilt HOLD withdrawn after actual current SWwalk0/SWattack3 confirms original prongs. Preserve original six; no service hilt edit selected. Formal final source proof pinned separately in result before integration.'})
spec={'schema':'pr122-reviewed-pose-map-v1','key':'transform:267','direction':'SW','role':'run','poses':poses,'physical_scale_review':'REQUIRED independent rigid skull/pauldron sizing and actual support/ground/AIR projection. No silhouette bbox normalization, no lowestAIRsole root, no standing near-far invariant.'}
sp=p/'pose-map.json';assert not sp.exists();sp.write_text(json.dumps(spec,ensure_ascii=False,indent=2)+'\n')
proof=assemble_pose_map(sp,p/'girtas-SW-run-v03six.png',cell_size=1536)
print(json.dumps({'status':proof.get('status'),'raw':str(p/'girtas-SW-run-v03six.png')}))
