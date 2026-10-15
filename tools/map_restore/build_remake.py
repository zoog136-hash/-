#!/usr/bin/env python3
"""Install reviewed A3 topology into the EXISTING TWILIGHT project.

No source artwork, actor/DB changes or guessed M coordinates. PC grid facts and
derived provisional gameplay placements are recorded separately. Reuses the
lossless PR81 parser and PR108's verified 101 identity, with bounded pack shards.
The private output is reproducible from the hash-verified Drive source archive.
"""
from __future__ import annotations
import argparse
from collections import deque
import json
from pathlib import Path
import struct
import sys
import zipfile
import numpy as np
from formats import move_masks, sha
from convert_world import Pack, compact

ROOT = Path(__file__).resolve().parents[2]
ARCHIVE_SHA = '2d25c6d5408aaf29443167c4c82c30b32d1a83b16039d988471ba0c832eb7d20'
DIRECTIONS = ((0,-1),(1,-1),(1,0),(1,1),(0,1),(-1,1),(-1,0),(-1,-1))
CATEGORIES = ['passability_grid','terrain_attributes','object_placement','tile_references',
              'npc_services','monster_regions','boss_regions','portals','images_animations','edition_unresolved']

def write(path: Path, data):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_bytes(compact(data)+b'\n')

def strict_masks(raw):
    """Keep original masks separately; runtime diagonals must clear both corners.
    Cardinal edges remain identical, so original L-shaped passages remain usable.
    """
    result=raw.copy(); h,w=raw.shape
    pad=np.pad(raw,1)
    def at(x,y): return pad[1+y:1+y+h,1+x:1+x+w]
    for heading in (1,3,5,7):
        dx,dy=DIRECTIONS[heading]; hx=2 if dx>0 else 6; hy=4 if dy>0 else 0
        clear=((raw&(1<<hx))!=0)&((raw&(1<<hy))!=0)&((at(dx,0)&(1<<hy))!=0)&((at(0,dy)&(1<<hx))!=0)
        result[~clear]&=np.uint8(255^(1<<heading))
    return result

def distances(masks, start):
    h,w=masks.shape; dist=np.full((h,w),-1,np.int32)
    queue=deque([start]);dist[start[1],start[0]]=0
    flat=masks.ravel(); d=dist.ravel()
    while queue:
        x,y=queue.popleft(); i=y*w+x; value=int(flat[i])
        for heading in (0,2,4,6):
            if not value&(1<<heading): continue
            dx,dy=DIRECTIONS[heading]; nx,ny=x+dx,y+dy; j=ny*w+nx
            if 0<=nx<w and 0<=ny<h and d[j]<0:
                d[j]=d[i]+1;queue.append((nx,ny))
    return dist

def nearest(opened, x, y):
    ys,xs=np.nonzero(opened)
    if not len(xs): raise ValueError('No reachable cell; do not invent an entrance')
    i=np.argmin((xs-x)**2+(ys-y)**2)
    return int(xs[i]),int(ys[i])

def pixel(cell,w):
    x,y=cell
    return [24*(x+y+1),12*(y-x+w)]

def source_catalog(archive, previous):
    expected={int(r['map_id']):r for r in previous['source_maps'] if r['navigation_rules']=='A3_STATIC_EDGES'}
    rows=[]; grids={}
    for name in sorted(archive.namelist()):
        if not name.startswith('data/mapcache/') or not name.endswith('.map'): continue
        data=archive.read(name)
        if len(data)<20: raise ValueError('Truncated mapcache '+name)
        mid,ox,oy,w,h=struct.unpack('>5i',data[:20])
        if not 0<w<=65536 or not 0<h<=65536 or len(data)!=20+w*h: raise ValueError('Invalid mapcache '+name)
        grid=np.frombuffer(data[20:],np.uint8).reshape(w,h).T.copy()
        digest=sha(grid.tobytes()); old=expected.get(mid)
        if old is None or old['row_major_sha256']!=digest or old['source_origin']!=[ox,oy] or old['dimensions']!=[w,h]:
            raise ValueError(f'A3 edition mismatch {mid}; review instead of substitution')
        rows.append({'source_map_id':mid,'source':f'a3.zip!{name}','cache_sha256':sha(data),
                     'grid_sha256':digest,'origin':[ox,oy],'dimensions':[w,h],
                     'name':old['source_name'],'edition':'A3_PC','lineagem_equivalence':'UNVERIFIED'})
        if mid in [4,*range(101,111),111,12862]: grids[mid]=(grid,[ox,oy],digest)
    if len(rows)!=1000: raise ValueError(f'Expected archived A3 1000, got {len(rows)}')
    return rows,grids

def select_entry(grid,masks,origin,refs):
    candidates=[]
    for row in refs:
        candidates.append((int(row['src_x'])-origin[0],int(row['src_y'])-origin[1]))
    observations=list(candidates)
    if not candidates: candidates=[(grid.shape[1]//2,grid.shape[0]//2)]
    # The source observation is kept even when blocked. The substitute is an
    # explicitly provisional TWILIGHT landing, never a corrected source fact.
    start=nearest(masks!=0,*candidates[0]); reachable=distances(masks,start)
    if np.count_nonzero(reachable>=0)<np.count_nonzero(masks)*0.5:
        sizes=[]
        seen=reachable>=0
        while np.any((masks!=0)&~seen):
            y,x=np.argwhere((masks!=0)&~seen)[0]; component=distances(masks,(int(x),int(y)))
            sizes.append((int(np.count_nonzero(component>=0)),(int(x),int(y)),component));seen|=component>=0
        sizes.append((int(np.count_nonzero(reachable>=0)),start,reachable))
        _,start,reachable=max(sizes,key=lambda v:v[0])
    return start,reachable,observations

def placements(legacy,grid,masks,origin,entry,reach):
    h,w=grid.shape; excluded=np.zeros_like(masks,dtype=bool)
    yy,xx=np.indices(grid.shape)
    def reserve(cell,radius):
        p=pixel(cell,w); excluded[:]|=((24*(xx+yy+1)-p[0])**2+(12*(yy-xx+w)-p[1])**2)<radius*radius
    reserve(entry,150)
    available=(reach>=0)&~excluded
    def choose(reference):
        cell=nearest(available&~excluded,*reference);reserve(cell,90);return cell
    far_index=int(reach.argmax()); far=(far_index%w,far_index//w)
    npc_rows=[]
    for old in legacy['npc_spawn']:
        cell=choose((entry[0]+4,entry[1]+4))
        record=dict(old);record['position']=pixel(cell,w);record['source_cell']=list(cell)
        record['placement_status']='provisional';record['service_source']='existing_TWILIGHT'
        npc_rows.append(record)
    portals=[]
    for old in legacy['portal']:
        reference=far if old['id'] in ['next','entry_waystone'] else (entry[0]+6,entry[1]-6)
        cell=choose(reference);record=dict(old);record['position']=pixel(cell,w);record['source_cell']=list(cell)
        record['radius']=24;record['placement_status']='provisional'
        if 'target_position' in record:
            if record['target_map']==legacy['map_id']:
                record['target_position']=pixel(far if old['id']=='advance_waystone' else entry,w)
            elif record['target_map'].startswith('oman_'):
                record.pop('target_position')
        portals.append(record)
    allowed=(reach>=0)&~excluded&((grid&48)!=16)
    # Topological farthest-point partition: deterministic, connected source
    # regions, explicitly provisional. No original spawn-coordinate claim.
    old_regions=legacy['monster_spawn']
    min_dist=np.full(grid.shape,2**30,np.int32); seeds=[]
    for index,old in enumerate(old_regions):
        if index==0: cell=nearest(allowed,*entry)
        else:
            score=np.where(allowed,min_dist,-1); idx=int(score.argmax());cell=(idx%w,idx//w)
        seeds.append(cell)
        dist=distances(masks,cell);dist[dist<0]=2**30;min_dist=np.minimum(min_dist,dist)
    owner=np.full(grid.shape,-1,np.int16); queue=deque()
    for i,(x,y) in enumerate(seeds):owner[y,x]=i;queue.append((x,y))
    while queue:
        x,y=queue.popleft()
        for heading in (0,2,4,6):
            if not int(masks[y,x])&(1<<heading): continue
            dx,dy=DIRECTIONS[heading];nx,ny=x+dx,y+dy
            if 0<=nx<w and 0<=ny<h and owner[ny,nx]<0:
                owner[ny,nx]=owner[y,x];queue.append((nx,ny))
    regions=[]
    for i,old in enumerate(old_regions):
        region_mask=(owner==i)&allowed
        radius=float(old.get('spawn_radius',0))
        center=pixel(seeds[i],w)
        seed=seeds[i]
        if radius>0:
            # Farthest-point seeds often lie at corridor ends. Place a dense
            # arena at the best existing open patch INSIDE its assigned zone,
            # retaining the radius/cap and every obstacle/reservation.
            cy,cx=np.nonzero(region_mask)
            px=24*(cx+cy+1);py=12*(cy-cx+w)
            counts=np.array([np.count_nonzero((px-x)**2+(py-y)**2<=radius*radius) for x,y in zip(px,py)])
            best=int(counts.argmax())
            seed=(int(cx[best]),int(cy[best]));center=pixel(seed,w)
            # Dense hotspots retain the actual existing TWILIGHT radius and
            # population cap. A whole Voronoi province is not a dense spawn.
            region_mask &= (24*(xx+yy+1)-center[0])**2+(12*(yy-xx+w)-center[1])**2 <= radius*radius
        cells=np.flatnonzero(region_mask).astype(int).tolist()
        if len(cells)<max(12,int(old['max_count'])*4): raise ValueError('Insufficient unreserved spawn cells '+old['id'])
        points=[pixel((c%w,c//w),w) for c in cells];xs=[p[0] for p in points];ys=[p[1] for p in points]
        record=dict(old)
        for key in ['polygon','patrol_region','encounter_region','spawn_coordinates']:record.pop(key,None)
        rectangle=[center[0]-radius,center[1]-radius,radius*2,radius*2] if radius>0 else [min(xs)-24,min(ys)-12,max(xs)-min(xs)+48,max(ys)-min(ys)+24]
        record.update({'rect':rectangle,
                       'source_cells':cells,'source_seed':list(seed),'spawn_radius':radius,
                       'placement_status':'provisional_topological_partition',
                       'coordinate_evidence':'A3_connected_cells_with_TWILIGHT_runtime_zones_not_original_spawns'})
        regions.append(record)
    return {'npc_spawn':npc_rows,'portal':portals,'monster_spawn':regions,
            'entry_exclusion':{'center':pixel(entry,w),'radius':150},
            'placement_status':'provisional','preserved_gameplay_fields':['id','monster_types','weights','mode','boss_id','max_count','respawn_time','roaming_radius','level','variants','spawn_conditions']}

def build(a3:Path,layouts_path:Path,out:Path):
    # Do not repeatedly unpack/recover the same verified 1000-map archive.
    # Existing incomplete/changed output is rejected, never silently replaced.
    if out.exists():
        from verify_remake import verify
        report=json.loads((out/'build_report.json').read_text())
        if report['effective_layouts_sha256']!=sha(layouts_path.read_bytes()):
            raise ValueError('Current gameplay changed; review migration and choose a new output')
        verify(out,layouts_path)
        print(json.dumps({'result':'REUSED_VERIFIED_PRIVATE_PACK','maps':10,'output':str(out)}))
        return
    if sha(a3.read_bytes())!=ARCHIVE_SHA: raise ValueError('Wrong A3 archive SHA; do not mix cleaned and exact parts')
    previous=json.loads((ROOT/'docs/map-recovery-20261011/MAP_SOURCE_MAPPING.json').read_text())
    layouts=json.loads(layouts_path.read_text())
    if len(layouts)!=25: raise ValueError('Export all 25 effective runtime layouts first')
    sys.path.insert(0,str(ROOT/'tools/l1j'));from extract_a3 import tables
    with zipfile.ZipFile(a3) as archive:
        if archive.testzip(): raise ValueError('A3 CRC failure')
        catalog,grids=source_catalog(archive,previous)
        db,_=tables(archive.read('db/l1remaster.sql').decode('utf-8-sig'),{'mapids','dungeon','spawnlist','spawnlist_npc','spawnlist_boss','spawnlist_door'})
    out.mkdir(parents=True);pack=Pack(out,'navigation'); index={};audits={}
    try:
        for mid in range(101,111):
            map_id=f'oman_{mid-100:02}';grid,origin,digest=grids[mid]; h,w=grid.shape
            raw_masks=move_masks(grid);masks=strict_masks(raw_masks)
            refs=[r for r in db['dungeon'] if int(r['src_mapid'])==mid]
            entry,reach,candidates=select_entry(grid,raw_masks,origin,refs)
            strict_reach=distances(masks,entry)
            if not np.array_equal(reach,strict_reach): raise ValueError('Cardinal connectivity changed')
            refs_chunks=[]
            for y in range(0,h,64):
                for x in range(0,w,64):
                    a=grid[y:y+64,x:x+64];m=raw_masks[y:y+64,x:x+64];ch,cw=a.shape
                    refs_chunks.append([x//64,y//64,cw,ch,*pack.add(a.tobytes()+m.tobytes())])
            gameplay=placements(layouts[map_id],grid,masks,origin,entry,reach)
            definition={'schema':2,'map_id':map_id,'source_map_id':mid,'map_name':layouts[map_id]['map_name'],
                'origin':origin,'dimensions':[w,h],'source_sha256':digest,'source_archive_sha256':ARCHIVE_SHA,
                'navigation':{'profile':'A3_STATIC_EDGES','chunks':refs_chunks},'corner_policy':'no_corner_cut',
                'coordinate_mapping':{'basis_x':[24,-12],'basis_y':[24,12],'translation':[0,12*w]},
                'pack_root':'res://data/map_remake/private','spawn_source':[entry[0]+origin[0],entry[1]+origin[1]],
                'playable':True,'layout_revision':2026101502,'rules':{},'npc_spawns':[],'monster_spawns':[],
                'portals':[],'getback':[],'doors':[r for r in db['spawnlist_door'] if int(r['mapid'])==mid],
                'terrain_chunks':[],'remake_gameplay':gameplay,'render_profile':'oman_stone',
                'edition_status':'A3_PC_TOPOLOGY_CURRENT_M_UNVERIFIED','art_status':'TWILIGHT_AUTHORED_NOT_ORIGINAL',
                'legacy_layout_revision':layouts[map_id].get('layout_revision',0)}
            write(out/'definitions'/f'{map_id}.json',definition)
            index[map_id]={'path':f'res://data/map_remake/private/definitions/{map_id}.json','sha256':sha((out/'definitions'/f'{map_id}.json').read_bytes()),'grid_sha256':digest}
            audits[map_id]={'source_id':mid,'origin':origin,'dimensions':[w,h],'grid_sha256':digest,
                'walkable_cells':int(np.count_nonzero(raw_masks)),'entry_connected_cells':int(np.count_nonzero(reach>=0)),
                'raw_edge_count':int(np.unpackbits(raw_masks).sum()),'corner_rejections':int(np.unpackbits(raw_masks^masks).sum()),
                'entry_source_observations':[[x+origin[0],y+origin[1]] for x,y in candidates],
                'provisional_entry':definition['spawn_source'],'calibration_landmarks_verified':0,
                'regions':[{'id':r['id'],'mode':r.get('mode'),'count':r['max_count'],'respawn_time':r['respawn_time'],
                            'cells':len(r['source_cells']),'placement_status':r['placement_status']} for r in gameplay['monster_spawn']],
                'npc_count':len(gameplay['npc_spawn']),'portal_count':len(gameplay['portal']),
                'original_spawn_rows':[r for r in db['spawnlist'] if int(r['mapid'])==mid],
                'original_npc_rows':[r for r in db['spawnlist_npc'] if int(r['mapid'])==mid],
                'code':'IMPLEMENTED','import':'NOT_RUN','gameplay':'NOT_RUN','visual_fidelity':'UNVERIFIED'}
        pack.close()
        write(out/'index.json',{'schema':1,'source_archive_sha256':ARCHIVE_SHA,'maps':index})
        write(out/'build_report.json',{'schema':1,'maps':audits,'source_catalog':catalog,'categories':CATEGORIES,
             'unmapped_current_maps':sorted(set(layouts)-set(index)),'source_catalog_count':len(catalog),
             'domination_candidate':12862,'excluded_oman_summit':111,'technical_complete':0,'faithful_complete':0,
             'effective_layouts_sha256':sha(layouts_path.read_bytes())})
    except Exception:
        pack.close()
        # A partial install must never become active. Preserve it for diagnosis.
        (out/'index.json').unlink(missing_ok=True)
        raise
    print(json.dumps({'converted':len(index),'catalogued':len(catalog),'output':str(out),'exact_M_complete':0}))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--a3',type=Path,required=True)
    p.add_argument('--layouts',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();build(a.a3,a.layouts,a.output)
