#!/usr/bin/env python3
"""Index actual connected sprites; generated sheets are not perfectly regular.
Original PNGs stay byte-identical. Integer ID lookup masks isolate atlas sprites
in the renderer without cutting roots or sampling neighboring objects.
"""
import argparse,json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

def index(root):
 meta={}
 for name,total,columns in [('structures',16,4),('nature',16,4),('landmarks',4,2)]:
  im=Image.open(root/(name+'.png'));alpha=np.asarray(im.getchannel('A'))
  labels,count=ndi.label(alpha>20);sizes=np.bincount(labels.ravel());sizes[0]=0
  selected=list(np.argsort(sizes)[-total:]);boxes=ndi.find_objects(labels)
  if len(selected)!=total or min(int(sizes[i]) for i in selected)<1000:
   raise ValueError(name+': expected separate substantial sprites; inspect atlas')
  selected.sort(key=lambda ident:(boxes[ident-1][0].start+boxes[ident-1][0].stop)/2)
  ordered=[]
  for row in range(total//columns):
   group=selected[row*columns:(row+1)*columns];group.sort(key=lambda ident:(boxes[ident-1][1].start+boxes[ident-1][1].stop)/2);ordered.extend(group)
  ids=np.zeros(alpha.shape,dtype='uint8');entries=[]
  for slot,ident in enumerate(ordered):
   sl=boxes[ident-1];y0,y1=sl[0].start,sl[0].stop;x0,x1=sl[1].start,sl[1].stop
   entries.append({'rect':[x0,y0,x1-x0,y1-y0],'foot':[(x1-x0)/2,y1-y0-4]});ids[labels==ident]=slot+1
  Image.fromarray(ids,'L').save(root/(name+'_ids.png'));meta[name]=entries
 (root/'sprites.json').write_text(json.dumps(meta,separators=(',',':'))+'\n')
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('art',type=Path);index(p.parse_args().art)
