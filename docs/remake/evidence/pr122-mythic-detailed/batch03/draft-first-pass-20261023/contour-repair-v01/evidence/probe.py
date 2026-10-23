import json,sys,hashlib,collections
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
r=Path('/workspace/twilight');s=Path('/workspace/scratch/pr122-contour-repair-20261023');rows=json.loads((r/'docs/remake/evidence/pr122-mythic-detailed/batch03/draft-first-pass-20261023/spacing-repair-v01/remaining-errors.json').read_text())['source_holds'];results=[]
for row in rows:
 if not row.get('geometry_error','').startswith('A pose rectangle includes another body'):continue
 p=r/row['source'];a=np.asarray(Image.open(p).convert('RGBA'));alpha=a[:,:,3];strong,_=ndimage.label(alpha>100);areas=np.bincount(strong.ravel());bodies=set(int(i) for i in np.flatnonzero(areas>=200) if i);assert len(bodies)==6
 comp,count=ndimage.label(alpha>0,np.ones((3,3)));links={}
 for body in bodies:
  ids=np.unique(comp[strong==body]);assert len(ids)==1;links.setdefault(int(ids[0]),[]).append(body)
 rowout=dict(key=row['key'],direction=row['direction'],role=row['role'],source=row['source'],source_sha256=row['sha256'],nonzero_components=count,merged_body_groups=[len(x) for x in links.values()],status='PROBE')
 if any(len(x)>1 for x in links.values()):rowout.update(status='HOLD',cause='Nonzero-alpha component joins multiple poses; exact contour ownership is not unique')
 else:rowout.update(status='DISJOINT_CORE_CONTOURS',unseeded_components=count-len(links))
 results.append(rowout)
(s/'contour-probe.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps({'checked':len(results),'disjoint':sum(x['status']=='DISJOINT_CORE_CONTOURS' for x in results),'merged':sum(x['status']=='HOLD' for x in results)}))
