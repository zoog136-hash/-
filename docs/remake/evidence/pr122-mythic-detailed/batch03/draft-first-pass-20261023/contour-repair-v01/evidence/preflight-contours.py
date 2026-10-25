import sys,json,hashlib,collections
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
r=Path('/workspace/twilight');s=Path('/workspace/scratch/pr122-contour-repair-20261023');sys.path.insert(0,str(r/'tools'))
import pr122_reviewed_source_regions as guard
rows=[x for x in json.loads((s/'contour-probe.json').read_text()) if x['status']=='DISJOINT_CORE_CONTOURS'];results=[]
for row in rows:
 result=dict(**row)
 try:
  p=r/row['source'];assert hashlib.sha256(p.read_bytes()).hexdigest()==row['source_sha256'];rgba=np.asarray(Image.open(p).convert('RGBA'));alpha=rgba[:,:,3];labels,_=ndimage.label(alpha>100);areas=np.bincount(labels.ravel());boxes=ndimage.find_objects(labels);seeds=[None]*6
  for label in np.flatnonzero(areas[1:]>=200)+1:
   ys,xs=boxes[label-1];slot=int((ys.start+ys.stop)/1024)*3+int((xs.start+xs.stop)/1024)
   if slot>=6 or seeds[slot] is not None:raise ValueError('Authored row-major phase order is ambiguous')
   sy,sx=np.argwhere(labels==label)[0];seeds[slot]=dict(region=[int(sx),int(sy),1,1],phase=slot,body_label=int(label),body_area=int(areas[label]),source_seed_RGBA=rgba[sy,sx].tolist())
  if any(x is None for x in seeds):raise ValueError('Missing physical source seed')
  # This is an analysis support plane, never an edited source image. Include
  # every nonzero-alpha texel, stronger than the usual alpha>16 foreground.
  support=alpha.copy();support[(alpha>0)&(alpha<=16)]=17
  assert np.array_equal(support>100,alpha>100)
  owners,proof=guard._foreground_owners(support,seeds)
  if np.any(owners[alpha>0]>=6):raise ValueError('Unowned original RGBA texel')
  materials={f'phase_{i}':np.where(((owners==i)&(alpha>0))[:,:,None],rgba,0).astype(np.uint8) for i in range(6)}
  ownership=guard.require_native_source_part_ownership(rgba,materials)
  result.update(status='EXACT_CONTOUR_OWNERSHIP_PASS',seeds=seeds,ownership_proof=proof,original_RGBA_ownership=ownership,owner_map_sha256=hashlib.sha256(owners.tobytes()).hexdigest(),analysis_support='Original alpha>100 body seeds unchanged; full nonzero-alpha support; detached margin >32; no pixel values modified')
 except (ValueError,AssertionError) as e:result.update(status='HOLD',cause=str(e))
 results.append(result)
(s/'exact-contour-preflight.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps({'checked':len(results),'strict_contour_pass':sum(x['status']=='EXACT_CONTOUR_OWNERSHIP_PASS' for x in results),'causes':dict(collections.Counter(x.get('cause','PASS') for x in results))}))
