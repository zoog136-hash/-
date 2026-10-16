#!/usr/bin/env python3
"""Source control-tower anchors, independently authored keep/palace visuals.
An anchor does not identify original building pixels or prove current M layout.
"""
import argparse,hashlib,json,zipfile
from pathlib import Path
import numpy as np
from build_aden_world_visuals import pixel,write,navigation

def build(output,archive):
 manifest=json.loads((output/'manifest.json').read_text())
 if 'source_landmarks' in manifest:raise ValueError('Landmarks already installed')
 source='src/l1j/server/server/model/L1CastleLocation.java'
 with zipfile.ZipFile(archive) as z:raw=z.read(source)
 records=[]
 for id,slot,x,y,width,box in [('windawood',49,175,1315,720,[165,1305,20,20]),('aden_palace',50,1642,1196,880,[1632,1186,20,20])]:
  p=[slot,*pixel(x,y),width,0,box,'fortified_structure',-1]
  key=f'{x//32}_{y//32}';path=output/'props'/f'{key}.json';rows=json.loads(path.read_text()) if path.exists() else [];rows.append(p);write(path,rows)
  manifest['chunk_props'][key]=len(rows);manifest['props']+=1;manifest['kinds']['fortified_structure']+=1
  records.append({'id':id,'source_cell':[x,y],'source_absolute':[x+32448,y+32064],
   'anchor':'A3_CASTLE_CONTROL_TOWER_POSITION_NOT_ORIGINAL_BUILDING_FOOTPRINT',
   'art_identity':'INDEPENDENT_INTERPRETATION_CURRENT_M_UNVERIFIED'})
 manifest['source_landmarks']={'source_archive_member':source,'member_sha256':hashlib.sha256(raw).hexdigest(),'records':records}
 write(output/'manifest.json',manifest)
 sites=json.loads((output/'inspection_sites.json').read_text())
 _,masks,_=navigation(Path(__file__).resolve().parents[2])
 for r in records:
  x,y=r['source_cell'];left,top=max(0,x-120),max(0,y-120)
  ys,xs=np.nonzero(masks[top:y+121,left:x+121]);xs+=left;ys+=top
  distance=(24*((xs-x)+(ys-y)))**2+(12*((ys-y)-(xs-x)))**2
  at=np.argmin(distance)
  sites.append({'id':r['id']+'-castle','cell':[int(xs[at]),int(ys[at])],
   'camera_anchor':[x,y],'zoom':.4 if r['id']=='aden_palace' else .65,
   'inspection_scope':'QA_CASTLE_VIEW_FROM_ORIGINAL_OPEN_APPROACH; INTERIOR_NOT_WALKABLE_NOT_CARVED'})
 write(output/'inspection_sites.json',sites)
 print(records)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--a3',type=Path,required=True);a=p.parse_args();build(a.output,a.a3)
