#!/usr/bin/env python3
"""Add source-contour fortifications and S32 entrance *visuals*, never portals.
Run after build_aden_world_visuals. No inferred wall is added to approved Giran.
"""
import argparse,json
from collections import Counter
from pathlib import Path
import numpy as np
from PIL import Image
from build_aden_world_visuals import navigation,pixel,giran,write

def finish(root,output,source_report,refresh_entrances=False):
 manifest=json.loads((output/'manifest.json').read_text())
 if 'source_structure_pass' in manifest and not refresh_entrances:raise ValueError('Already decorated; do not duplicate')
 previous={}
 if refresh_entrances:
  previous=json.loads((output/'source_structures.json').read_text())
  for key in manifest['chunk_props']:
   path=output/'props'/f'{key}.json';rows=json.loads(path.read_text());keep=[p for p in rows if p[6] not in ['s32_gate_visual','s32_entrance_visual']]
   manifest['props']-=len(rows)-len(keep);manifest['chunk_props'][key]=len(keep);write(path,keep)
  for kind in ['s32_gate_visual','s32_entrance_visual']:manifest['kinds'].pop(kind,None)
 report=json.loads(source_report.read_text());grid,masks,_=navigation(root)
 material=np.asarray(Image.open(output/'materials.png'))
 yy,xx=np.indices(grid.shape);town_distance=np.full(grid.shape,1e12)
 for town in manifest['towns']:
  x,y=town['cell'];town_distance=np.minimum(town_distance,(xx-x)**2+(yy-y)**2)
 paving=np.isin(material,[0,9,10])&(masks!=0)&(town_distance<230**2)
 added=[];runs=previous.get('wall_runs',[])
 def add(slot,x,y,width,kind):
  if giran(x,y):return
  added.append([slot,*pixel(x,y),width,0,[int(x),int(y),1,1],kind,-1])
 # Only long contiguous SOURCE edges in observed paved districts qualify.
 # There is no arbitrary terrain line, random castle outline or wall around
 # every unidentified forest blocker.
 for heading,(dx,dy) in enumerate([] if refresh_entrances else [(0,-1),(1,0),(0,1),(-1,0)]):
  shifted=np.roll(masks,(-dy,-dx),axis=(0,1))
  edge=paving&(shifted==0);edge[[0,-1],:]=False;edge[:,[0,-1]]=False
  rows=edge if dx==0 else edge.T
  for row,arr in enumerate(rows):
   changes=np.diff(np.pad(arr.astype('int8'),1));starts=np.where(changes==1)[0];ends=np.where(changes==-1)[0]
   for start,end in zip(starts,ends):
    if end-start<8:continue
    run={'heading':heading*2,'row':int(row),'from':int(start),'to':int(end),'identity':'INTERPRETED_CONSTRUCTED_EDGE_FROM_SOURCE_NOT_IDENTIFIED_ORIGINAL_WALL'}
    count=0
    for a in range(int(start)+1,int(end),3):
     x,y=(a,row-.5 if dy<0 else row+.5) if dx==0 else (row+.5 if dx>0 else row-.5,a)
     if giran(x,y):continue
     add(29 if dx==0 else 30,x,y,82,'source_paved_wall');count+=1
    if count:runs.append(run)
 # An S32 entry is evidence of a location, not evidence that the target scene
 # exists in TWILIGHT. Keep the three production portals and their services.
 entrances=[];used=[]
 for e in report['observed_s32_entrances']:
  target=e['target_source_map_id'];x,y=e['source_cell']
  if target<=4 or target>=1000 or giran(x,y):continue
  if any((x-a)**2+(y-b)**2<12**2 for a,b in used):continue
  if not(0<=x<2048 and 0<=y<1536):continue
  # Show the source record even when its exact trigger encoding/door state
  # remains unverified, but do not silently relocate or activate it.
  castles=[15,52,64,300]
  slot=48 if target==75 else 28 if target in castles else 31
  add(slot,x,y,340 if target==75 else 180 if target in castles else 155,'s32_gate_visual' if target in castles else 's32_entrance_visual')
  used.append((x,y));entrances.append(dict(e,visual_only=True,gameplay='NOT_IMPLEMENTED_TARGET_NOT_IN_THIS_SCOPE',identity='UNVERIFIED_S32_PORTAL_ENCODING'))
 for p in added:
  total=p[1]/24-1;diff=p[2]/12-2048;x=(total-diff)/2;y=(total+diff)/2
  key=f'{max(0,min(63,int(x//32)))}_{max(0,min(47,int(y//32)))}';path=output/'props'/f'{key}.json'
  rows=json.loads(path.read_text()) if path.exists() else [];rows.append(p);write(path,rows);manifest['chunk_props'][key]=len(rows)
 kinds=Counter(p[6] for p in added)
 for k,n in kinds.items():manifest['kinds'][k]=n
 manifest['props']+=len(added);manifest['source_structure_pass']={'wall_runs':len(runs),'wall_sprites':manifest['kinds'].get('source_paved_wall',0),'entrance_visuals':len(entrances),'active_new_portals':0}
 write(output/'source_structures.json',{'wall_runs':runs,'entrance_visuals':entrances,'status':'INTERPRETED_VISUALS_NOT_ORIGINAL_IDENTIFICATION'})
 write(output/'manifest.json',manifest);print(manifest['source_structure_pass'])

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2]);p.add_argument('--output',type=Path,required=True);p.add_argument('--source-report',type=Path,required=True);p.add_argument('--refresh-entrances',action='store_true');a=p.parse_args();finish(a.root,a.output,a.source_report,a.refresh_entrances)
