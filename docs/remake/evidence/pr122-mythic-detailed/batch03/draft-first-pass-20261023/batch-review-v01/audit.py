import sys,json,hashlib,collections,concurrent.futures,time
from pathlib import Path
import numpy as np
from PIL import Image
root=Path('/workspace/twilight');sys.path.insert(0,str(root/'tools'))
import import_original_based_motion as imp
out=Path('/workspace/scratch/pr122-batch-review-20261023')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def one(path):
 p=Path(path);meta=json.loads(p.with_suffix('.json').read_text());result=dict(source=str(p.relative_to(root)),key=meta['key'],direction=meta['direction'],role=meta['role'],errors=[],visual_quality='NOT_REVIEWED')
 result['sha256']=sha(p)
 if result['sha256']!=meta['source_sha256']:result['errors'].append('SOURCE_SHA_MISMATCH')
 a=np.asarray(Image.open(p).convert('RGBA'));result['size']=[a.shape[1],a.shape[0]]
 if a.shape!=(1024,1536,4):result['errors'].append('SOURCE_GRID_SIZE');return result
 edges=[];cellhashes=[]
 for i in range(6):
  cell=a[(i//3)*512:(i//3+1)*512,(i%3)*512:(i%3+1)*512];alpha=cell[:,:,3];n=sum(int(np.count_nonzero(e>100)) for e in (alpha[0],alpha[-1],alpha[:,0],alpha[:,-1]));edges.append(n);cellhashes.append(hashlib.sha256(cell.tobytes()).hexdigest())
 result['visible_cell_boundary_pixel_counts']=edges;result['cell_rgba_sha256']=cellhashes
 if any(edges):result['errors'].append('SOURCE_CELL_BOUNDARY_VISIBLE')
 if len(set(cellhashes))!=6:result['errors'].append('DUPLICATE_RGBA_PHASE')
 resource=root/str(meta['output_spriteframes']).removeprefix('res://');result['resource_present']=resource.is_file()
 if not resource.is_file():result['errors'].append('DRAFT_RESOURCE_MISSING')
 try:
  g=imp.analyze(p,rows_count=6,reference_rows=[0,3],directions_axis='phase_grid3',canvas_size=1024,directions=[meta['direction']]);imp.require_complete_pose_regions(p,g);result['strict_geometry']='PASS'
  (out/'geometry').mkdir(exist_ok=True);(out/'geometry'/p.with_suffix('.geometry.json').name).write_text(json.dumps(g,indent=2)+'\n')
 except Exception as e:result['strict_geometry']='HOLD';result['geometry_error']=str(e);result['errors'].append('STRICT_GEOMETRY')
 return result
if __name__=='__main__':
 paths=sorted((root/'docs/remake/evidence/pr122-mythic-detailed/batch03').glob('transform_*-draft-v01.png'));assert len(paths)==525
 with concurrent.futures.ProcessPoolExecutor(max_workers=4) as pool:
  with (out/'audit-results.jsonl').open('w') as stream:
   for result in pool.map(one,map(str,paths),chunksize=1):stream.write(json.dumps(result)+'\n');stream.flush()
 rows=[json.loads(x) for x in (out/'audit-results.jsonl').read_text().splitlines()]
 summary={'clips':len(rows),'poses':len(rows)*6,'strict_geometry_pass':sum(x['strict_geometry']=='PASS' for x in rows),'strict_geometry_hold':sum(x['strict_geometry']=='HOLD' for x in rows),'error_counts':dict(collections.Counter(e for x in rows for e in x['errors'])),'geometry_causes':dict(collections.Counter(x.get('geometry_error','PASS') for x in rows)),'visual_review':'NOT_RUN; no images previewed','final_approvals_added':0}
 (out/'audit-summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary))
