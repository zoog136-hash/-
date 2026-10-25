import json,sys,hashlib
from pathlib import Path
import numpy as np
from PIL import Image
r=Path('/workspace/twilight');sys.path.insert(0,str(r/'tools'))
import import_original_based_motion as imp
import pr122_reviewed_source_regions as regions
out=Path('/workspace/scratch/pr122-region-repair-20261023');rows=json.loads((r/'docs/remake/evidence/pr122-mythic-detailed/batch03/draft-first-pass-20261023/batch-review-v01/remaining-errors.json').read_text())['source_holds'];results=[]
for row in rows:
 if 'visible pixels outside pose regions' not in (row.get('geometry_error') or ''):continue
 try:
  p=r/row['source'];g=imp.analyze(p,rows_count=6,reference_rows=[0,3],directions_axis='phase_grid3',canvas_size=1024,directions=[row['direction']]);alpha=np.asarray(Image.open(p).convert('RGBA'))[:,:,3];owners,proof=regions._foreground_owners(alpha,g['frames']);rects=[]
  for i,f in enumerate(g['frames']):
   ys,xs=np.where((alpha>16)&(owners==i));x,y,w,h=f['region'];left=min(x,int(xs.min()));top=min(y,int(ys.min()));right=max(x+w,int(xs.max())+1);bottom=max(y+h,int(ys.max())+1);rects.append([left,top,right-left,bottom-top])
  # Independently check complete, exclusive rectangular ownership before
  # proposing any region change; topology/margin thresholds remain unchanged.
  assigned=np.full(alpha.shape,255,dtype=np.uint8)
  for i,(x,y,w,h) in enumerate(rects):
   if np.any(assigned[y:y+h,x:x+w]!=255):raise ValueError('Expanded rectangles overlap')
   assigned[y:y+h,x:x+w]=i
  if np.any(assigned[alpha>16]!=owners[alpha>16]):raise ValueError('Expanded rectangle contains foreign foreground or leaves pixels unowned')
  results.append(dict(source=row['source'],key=row['key'],direction=row['direction'],role=row['role'],status='TOPOLOGY_CANDIDATE',regions=rects,nearest_owner_sha256=proof['nearest_owner_sha256']))
 except ValueError as e:results.append(dict(source=row['source'],key=row['key'],direction=row['direction'],role=row['role'],status='HOLD',cause=str(e)))
(out/'fragment-preflight.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps({'checked':len(results),'candidates':sum(x['status']=='TOPOLOGY_CANDIDATE' for x in results)}))
