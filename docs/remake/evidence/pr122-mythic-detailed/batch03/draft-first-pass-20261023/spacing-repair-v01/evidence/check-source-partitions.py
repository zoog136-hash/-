import sys,json,hashlib,collections,concurrent.futures
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
r=Path('/workspace/twilight');sys.path.insert(0,str(r/'tools'))
import assemble_pr122_reviewed_poses as assembler
import pr122_reviewed_source_regions as regions
s=Path('/workspace/scratch/pr122-spacing-repair-20261023')
rows=json.loads((r/'docs/remake/evidence/pr122-mythic-detailed/batch03/draft-first-pass-20261023/source-region-repair-v01/remaining-errors.json').read_text())['source_holds']
def one(row):
 result=dict(key=row['key'],direction=row['direction'],role=row['role'],source=row['source'],status='HOLD')
 try:
  p=r/row['source'];raw=p.read_bytes();assert hashlib.sha256(raw).hexdigest()==row['sha256'];image=Image.open(p).convert('RGBA');rgba=np.asarray(image);alpha=rgba[:,:,3]
  if any(np.any(edge>100) for edge in (alpha[0],alpha[-1],alpha[:,0],alpha[:,-1])):raise ValueError('Original strong pixels touch source outer boundary; padding cannot restore absent art')
  geom=assembler._source_geometry(image)
  if len(geom['bodies'])!=6:raise ValueError('Multiple large source components per phase require explicit authored part identities; cannot infer body/gear grouping')
  # Exact empty separators, not guessed nearest-part ownership or arbitrary
  # fixed grid edges. Every nonzero RGBA source pixel stays in one partition.
  xcuts=[0]
  for nominal in (512,1024):
   choices=[x for x in range(nominal-160,nominal+161) if not np.any(alpha[:,x])]
   if not choices:raise ValueError('No full transparent vertical separator around authored grid boundary')
   xcuts.append(min(choices,key=lambda x:abs(x-nominal)))
  xcuts.append(image.width)
  choices=[y for y in range(352,673) if not np.any(alpha[y,:])]
  if not choices:raise ValueError('No full transparent horizontal separator between authored phase rows')
  ycuts=[0,min(choices,key=lambda y:abs(y-512)),image.height];rects=[];frames=[];proofs=[];coverage=np.zeros(alpha.shape,np.uint8)
  for i in range(6):
   x0,x1=xcuts[i%3:i%3+2];y0,y1=ycuts[i//3:i//3+2];rect=[x0,y0,x1-x0,y1-y0];crop=image.crop((x0,y0,x1,y1));entry=dict(region=rect,rgba_sha256=assembler._rgba_sha(crop));assembler._reviewed_crop(image,geom,entry);rects.append(rect);frames.append(dict(region=rect));coverage[y0:y1,x0:x1]+=1
  assert np.all(coverage==1)
  owners,owner_proof=regions._foreground_owners(alpha,frames)
  for i,(x,y,w,h) in enumerate(rects):
   fg=alpha[y:y+h,x:x+w]>16
   if np.any(owners[y:y+h,x:x+w][fg]!=i):raise ValueError('Original detached-part ownership disagrees with transparent partition')
  result.update(status='PARTITION_PREFLIGHT_PASS',regions=rects,source_sha256=hashlib.sha256(raw).hexdigest(),source_nonzero_alpha_pixels=int(np.count_nonzero(alpha)),all_source_rgba_coverage=1,source_body_count=6,nearest_owner_sha256=owner_proof['nearest_owner_sha256'],rule='Exact zero-alpha separators + existing crop and topology ownership guards')
 except (ValueError,AssertionError) as e:result['cause']=str(e)
 return result
if __name__=='__main__':
 with concurrent.futures.ProcessPoolExecutor(max_workers=4) as pool:results=list(pool.map(one,rows,chunksize=1))
 (s/'partition-preflight.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n');print(json.dumps({'checked':len(results),'safe_partitions':sum(x['status']=='PARTITION_PREFLIGHT_PASS' for x in results),'hold_causes':dict(collections.Counter(x.get('cause','PASS') for x in results))}))
