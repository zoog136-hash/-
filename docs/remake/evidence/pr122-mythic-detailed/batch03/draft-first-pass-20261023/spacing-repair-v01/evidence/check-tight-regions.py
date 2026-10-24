import sys,json,hashlib,collections
from pathlib import Path
import numpy as np
from PIL import Image
r=Path('/workspace/twilight');sys.path.insert(0,str(r/'tools'))
import assemble_pr122_reviewed_poses as assembler
import pr122_reviewed_source_regions as regions
s=Path('/workspace/scratch/pr122-spacing-repair-20261023');rows=json.loads((r/'docs/remake/evidence/pr122-mythic-detailed/batch03/draft-first-pass-20261023/source-region-repair-v01/remaining-errors.json').read_text())['source_holds'];results=[]
for row in rows:
 if not (row.get('geometry_error','').startswith('A pose rectangle includes another body') or row.get('geometry_error','').startswith('Each phase_grid3')):continue
 result=dict(key=row['key'],direction=row['direction'],role=row['role'],source=row['source'],status='HOLD')
 try:
  p=r/row['source'];image=Image.open(p).convert('RGBA');rgba=np.asarray(image);geom=assembler._source_geometry(image);assert len(geom['bodies'])==6
  slots=[None]*6
  for body in geom['bodies']:
   ys,xs=geom['body_boxes'][body-1];x0,y0,x1,y1=xs.start,ys.start,xs.stop,ys.stop;slot=int((y0+y1)/2/512)*3+int((x0+x1)/2/512)
   if slot>=6 or slots[slot] is not None:raise ValueError('Cannot establish the authored phase order without guessing')
   slots[slot]=dict(region=[x0,y0,x1-x0,y1-y0])
  if any(x is None for x in slots):raise ValueError('Incomplete authored phase order')
  owners,owner_proof=regions._foreground_owners(geom['alpha'],slots);rects=[];coverage=np.zeros(geom['alpha'].shape,np.uint8)
  for i,f in enumerate(slots):
   ys,xs=np.where((geom['alpha']>16)&(owners==i));left,top,right,bottom=int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1;rect=[left,top,right-left,bottom-top];crop=image.crop((left,top,right,bottom));assembler._reviewed_crop(image,geom,dict(region=rect,rgba_sha256=assembler._rgba_sha(crop)));rects.append(rect);coverage[top:bottom,left:right]+=1
  if np.any((geom['alpha']>0)&(coverage>1)):raise ValueError('Exact source RGBA ownership duplicates pixels across reviewed rectangles')
  if np.any((geom['alpha']>16)&(coverage!=1)):raise ValueError('Source foreground omitted or duplicated')
  residual=(geom['alpha']>0)&(coverage==0)
  result.update(status='REVIEWED_CROP_PREFLIGHT_PASS',regions=rects,source_sha256=hashlib.sha256(p.read_bytes()).hexdigest(),retained_foreground_pixels=int(np.count_nonzero(geom['alpha']>16)),low_alpha_residual_pixels=int(np.count_nonzero(residual)),low_alpha_residual_max=int(geom['alpha'][residual].max()) if np.any(residual) else 0,nearest_owner_sha256=owner_proof['nearest_owner_sha256'])
 except (ValueError,AssertionError) as e:result['cause']=str(e)
 results.append(result)
(s/'tight-region-preflight.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps({'checked':len(results),'candidates':sum(x['status']=='REVIEWED_CROP_PREFLIGHT_PASS' for x in results),'causes':dict(collections.Counter(x.get('cause','PASS') for x in results))}))
