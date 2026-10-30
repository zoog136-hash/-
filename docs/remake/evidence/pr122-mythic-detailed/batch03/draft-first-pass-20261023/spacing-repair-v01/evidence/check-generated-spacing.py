import json,sys,hashlib
from pathlib import Path
import numpy as np
from PIL import Image
r=Path('/workspace/twilight');sys.path.insert(0,str(r/'tools'))
import assemble_pr122_reviewed_poses as asm
import pr122_reviewed_source_regions as regions
s=Path('/workspace/scratch/pr122-spacing-repair-20261023');result=[]
for item in json.loads((s/'boundary-source-results.json').read_text()):
 if not item.get('cause','').startswith('A pose rectangle includes another body'):continue
 row=dict(key=item['key'],direction=item['direction'],role=item['role'],source=item['source'],status='HOLD')
 try:
  p=r/item['source'];image=Image.open(p).convert('RGBA');g=asm._source_geometry(image);assert len(g['bodies'])==6;slots=[None]*6
  for label in g['bodies']:
   ys,xs=g['body_boxes'][label-1];slot=int((ys.start+ys.stop)/2/512)*3+int((xs.start+xs.stop)/2/512)
   if slot>=6 or slots[slot] is not None:raise ValueError('Authored phase order ambiguous')
   slots[slot]=dict(region=[xs.start,ys.start,xs.stop-xs.start,ys.stop-ys.start])
  owners,_=regions._foreground_owners(g['alpha'],slots);rects=[]
  for i in range(6):
   ys,xs=np.where((g['alpha']>16)&(owners==i));x,y,x1,y1=int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1;rect=[x,y,x1-x,y1-y];asm._reviewed_crop(image,g,dict(region=rect,rgba_sha256=asm._rgba_sha(image.crop((x,y,x1,y1)))));rects.append(rect)
  row.update(status='REVIEWED_CROP_PREFLIGHT_PASS',regions=rects)
 except (ValueError,AssertionError) as e:row['cause']=str(e)
 result.append(row)
(s/'generated-spacing-preflight.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
