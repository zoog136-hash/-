#!/usr/bin/env python3
"""Quick deterministic geometry check before expensive Godot rendering."""
import json, collections, math
from pathlib import Path
p=Path(__file__).resolve().parent
layout=json.loads((p/'faith4_layout.json').read_text(encoding='utf-8'))
assert layout['id']=='faith_04'
assert len(layout['floor_rects'])==14
assert len(layout['pillars'])>=12 and len(layout['walls'])>=4 and len(layout['rails'])>=4
walls=[w['collision'] for w in layout['walls']+layout['rails']]
circles=[(x,y,43*s) for x,y,s in layout['pillars']]+[(x,y,42*s) for x,y,s in layout['statues']]

def walk(x,y):
 if not any(a<=x<=a+w and b<=y<=b+h for a,b,w,h in layout['floor_rects']):return False
 if any(a-36<=x<=a+w+36 and b-36<=y<=b+h+36 for a,b,w,h in walls):return False
 if any(math.hypot(x-a,y-b)<r+36 for a,b,r in circles):return False
 return True
stride=64; w,h=112,104
start=(int(1360//stride),int(5500//stride));end=(int(5550//stride),int(1470//stride))
assert walk((start[0]+.5)*stride,(start[1]+.5)*stride), 'entry unreachable'
assert walk((end[0]+.5)*stride,(end[1]+.5)*stride), 'chamber unreachable'
seen={start};queue=collections.deque([start]);reached=False
while queue:
 c=queue.popleft()
 if c==end:reached=True;break
 for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
  v=c[0]+dx,c[1]+dy
  if v in seen or not (0<=v[0]<w and 0<=v[1]<h):continue
  if not walk((v[0]+.5)*stride,(v[1]+.5)*stride):continue
  seen.add(v);queue.append(v)
assert reached,'map art has blocked entrance to upper chamber'
print('FAITH4_MAP_GRAPH_OK','walkable_visited',len(seen),'rooms',len(layout['floor_rects']),'walls',len(walls),'pillars',len(layout['pillars']))
