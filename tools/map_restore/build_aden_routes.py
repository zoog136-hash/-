#!/usr/bin/env python3
"""Derived mainland routing index. Reads verified masks, never changes them.
Each node is an exact cardinal-connected component INSIDE a 32-cell chunk.
Every graph link records an actual source edge, including its two end cells.
"""
import argparse,hashlib,json,zlib
from collections import deque
from pathlib import Path
import numpy as np
from build_aden_world_visuals import navigation,write,GRID_SHA

def build(root,output):
 if output.exists():raise ValueError('Route output already exists')
 _,masks,definition=navigation(root);h,w=masks.shape
 labels=np.zeros((h,w),dtype='<u4');node=0;centers=[]
 for cy in range(0,h,32):
  for cx in range(0,w,32):
   for ly in range(32):
    for lx in range(32):
     x,y=cx+lx,cy+ly
     if labels[y,x] or not masks[y,x]:continue
     node+=1;labels[y,x]=node;queue=deque([(x,y)])
     while queue:
      px,py=queue.popleft();bits=int(masks[py,px])
      for bit,dx,dy in [(1,0,-1),(4,1,0),(16,0,1),(64,-1,0)]:
       nx,ny=px+dx,py+dy
       if not bits&bit or not(cx<=nx<cx+32 and cy<=ny<cy+32) or labels[ny,nx]:continue
       labels[ny,nx]=node;queue.append((nx,ny))
     centers.append([cx+16,cy+16])
 links={}
 # All boundaries, both directions. No diagonal cut or synthetic bridge.
 for dx,dy,forward,back in [(1,0,4,64),(0,1,16,1)]:
  a=masks[:h-dy or None,:w-dx or None];b=masks[dy:,dx:]
  if np.any(((a&forward)!=0)!=((b&back)!=0)):raise ValueError('Directed cardinal source edges require a different index')
  ys,xs=np.nonzero((a&forward)!=0)
  for x,y in zip(xs,ys):
   nx,ny=int(x+dx),int(y+dy);first,second=int(labels[y,x]),int(labels[ny,nx])
   if first==second:continue
   key=(first,second)
   if key in links:continue
   af,bf=int(y*w+x),int(ny*w+nx)
   links[(first,second)]=[second,af,bf];links[(second,first)]=[first,bf,af]
 graph=[[] for _ in range(node+1)]
 for (first,_),row in links.items():graph[first].append(row)
 raw=labels.tobytes();output.mkdir(parents=True)
 blob=zlib.compress(raw,9);(output/'components.bin').write_bytes(blob)
 write(output/'graph.json',graph)
 report={'schema':1,'dimensions':[w,h],'chunk_size':32,'source_grid_sha256':GRID_SHA,
  'source_definition_sha256':hashlib.sha256((root/'data/map_remake/private/aden/definitions/aden_world.json').read_bytes()).hexdigest(),
  'components':node,'directed_links':len(links),'component_bytes':len(raw),
  'compressed_sha256':hashlib.sha256(blob).hexdigest(),'raw_sha256':hashlib.sha256(raw).hexdigest(),
  'graph_sha256':hashlib.sha256((output/'graph.json').read_bytes()).hexdigest(),
  'source_navigation_modified':False,'all_cardinal_reverse_edges':'PASS'}
 write(output/'manifest.json',report);print(report)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2]);p.add_argument('--output',type=Path,required=True);a=p.parse_args();build(a.root,a.output)
