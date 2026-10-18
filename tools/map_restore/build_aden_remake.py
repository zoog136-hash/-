#!/usr/bin/env python3
"""Build the full A3 mainland for the EXISTING aden_world / RemakePlayableField.

Original topology is immutable. TWILIGHT services/rosters are preserved, but their
new placements are explicitly provisional, NOT original NPC/boss coordinates.
Output is a separate private pack; the installed Oman pack is never overwritten.
Run export_current_layouts.gd on the target checkout before building this pack.
"""
from __future__ import annotations
import argparse
from collections import deque
from copy import deepcopy
import hashlib
import json
import math
from pathlib import Path
import shutil
import struct
import tempfile
import zipfile
import zlib
import numpy as np
from formats import move_masks

ARCHIVE_SHA = '2d25c6d5408aaf29443167c4c82c30b32d1a83b16039d988471ba0c832eb7d20'
CACHE_SHA = '22318c179f64c213b0c5da6801eae9e6288d3550e656ccc25d85426c8d1e35de'
GRID_SHA = 'c22aa61ed083a3680230c659202503d7afaef30cb41b86d4655e9f843c81a7c4'
ORIGIN = (32448, 32064)
DIMENSIONS = (2048, 1536)
PACK_ROOT = 'res://data/map_remake/private/aden'
REVISION = 2026101503
# These are observed getback coordinates in the exact A3 SQL. The association
# with differently authored TWILIGHT districts is an ADAPTATION, not a claim
# that the legacy geometry or NPC coordinates are original. In particular the
# existing gludio label is NOT silently equated with the source label Gludin.
ANCHORS = (
    ('gludio', (32628, 32807), '글루딘'),
    ('kent', (33049, 32780), '켄트'),
    ('giran', (33429, 32814), '기란'),
    ('aden', (33962, 33254), '아덴'),
    ('heine', (33604, 33237), '하이네'),
    ('oren', (34053, 32284), '오렌'),
    ('silver_knight', (33082, 33389), '은기사'),
    ('fire_village', (32745, 32445), '화전마을'),
    ('elf_village', (33051, 32343), '요정 숲'),
)
DIRECTIONS = ((0,-1),(1,-1),(1,0),(1,1),(0,1),(-1,1),(-1,0),(-1,-1))
SPATIAL = {'polygon','patrol_region','encounter_region','spawn_coordinates',
           'exclusions','source_cells','source_seed','rect','layout_revision'}


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_sha(path: Path) -> str:
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def write(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True,
                               separators=(',', ':'))+'\n', encoding='utf-8')


def read_grid(archive: Path) -> np.ndarray:
    if file_sha(archive) != ARCHIVE_SHA:
        raise ValueError('Wrong source archive; do not mix editions')
    with zipfile.ZipFile(archive) as z:
        raw = z.read('data/mapcache/4.map')  # ZipFile also checks this entry CRC.
    if sha(raw) != CACHE_SHA or len(raw) != 20 + math.prod(DIMENSIONS):
        raise ValueError('Mainland cache digest/size mismatch')
    if struct.unpack('>5i', raw[:20]) != (4, *ORIGIN, *DIMENSIONS):
        raise ValueError('Wrong source identity/origin/dimensions')
    w, h = DIMENSIONS
    grid = np.frombuffer(raw[20:], dtype=np.uint8).reshape(w, h).T.copy()
    if sha(grid.tobytes()) != GRID_SHA:
        raise ValueError('X-major to row-major conversion failed')
    return grid


def pixel(cell: tuple[int,int] | np.ndarray) -> np.ndarray:
    c = np.asarray(cell)
    return np.stack((24*(c[...,0]+c[...,1]+1),
                     12*(c[...,1]-c[...,0]+DIMENSIONS[0])), axis=-1)


def grid_point(point: np.ndarray | list[float]) -> np.ndarray:
    x, y = np.asarray(point, dtype=float)
    total, difference = x/24-1, y/12-DIMENSIONS[0]
    return np.array([(total-difference)/2, (total+difference)/2])


def reachable(masks: np.ndarray, start: tuple[int,int], allowed=None) -> np.ndarray:
    """Exact cardinal-edge BFS; no diagonal corner cutting or raster dilation."""
    h, w = masks.shape
    x, y = map(int, start)
    if not (0 <= x < w and 0 <= y < h) or not masks[y,x]:
        raise ValueError('Entry is not on an original walkable cell')
    valid = None if allowed is None else np.asarray(allowed, dtype=bool).ravel()
    if valid is not None and not valid[y*w+x]:
        raise ValueError('Seed lies outside its allowed region')
    seen = np.zeros(w*h, dtype=bool)
    seen[y*w+x] = True
    queue = deque([y*w+x]); raw = masks.ravel()
    while queue:
        i = queue.popleft(); bits = int(raw[i])
        for bit, step in ((1,-w),(4,1),(16,w),(64,-1)):
            if not bits & bit:
                continue
            if step == 1 and i % w == w-1: continue
            if step == -1 and i % w == 0: continue
            j = i+step
            # The verified masks have no outgoing border edges. Keep a bounds
            # guard anyway; corrupted/synthetic input must not wrap arrays.
            if 0 <= j < len(seen) and not seen[j] and (valid is None or valid[j]):
                seen[j] = True; queue.append(j)
    return seen.reshape(h,w)


def nearest(opened: np.ndarray, reference) -> tuple[int,int]:
    ys, xs = np.nonzero(opened)
    if not len(xs):
        raise ValueError('No eligible source landing; refusing an invented cell')
    x, y = reference
    # Distance in the actual 48x24 isometric world, not an unrelated square map.
    dx, dy = xs-x, ys-y
    i = int(np.argmin((24*(dx+dy))**2+(12*(dy-dx))**2))
    return int(xs[i]), int(ys[i])


class PlacementAdapter:
    def __init__(self, layout: dict, grid: np.ndarray, masks: np.ndarray):
        self.layout, self.grid, self.masks = layout, grid, masks
        self.observed_entry = np.array(ANCHORS[0][1])-ORIGIN
        self.entry = nearest((masks != 0) & ((grid & 48) == 16), self.observed_entry)
        self.connected = reachable(masks, self.entry)
        self.free = self.connected.copy()
        self.safe = self.connected & ((grid & 48) == 16)
        regions = {r['id']:r for r in layout['regions']}
        self.anchors = [(np.asarray(regions[k]['center'], float),
                         np.asarray(source, float)-ORIGIN, k, label)
                        for k,source,label in ANCHORS if k in regions]
        if len(self.anchors) < 3:
            raise ValueError('Missing existing district anchors; export current layouts')
        self.audit: list[dict] = []
        self.reservations: list[dict] = []
        self.reserve(self.entry, 150)

    def reference(self, point) -> np.ndarray:
        """Provisional local district transform; never alters any source byte."""
        point = np.asarray(point, dtype=float)
        old, cell, _key, _label = min(self.anchors,
            key=lambda row: float(np.sum((point-row[0])**2)))
        dx, dy = point-old
        # Preserve local pixel distances in the same 48x24 coordinate basis.
        return cell + np.array([dx/48-dy/24, dx/48+dy/24])

    def reserve(self, cell, radius: float) -> None:
        center = pixel(cell)
        self.reservations.append({'center':center.tolist(),'radius':radius})
        # Bounded local operation: do not allocate a 3-million-cell coordinate
        # mesh for every NPC/portal reservation.
        x,y = map(int,cell); reach = int(math.ceil(radius/12))+2
        x0,x1=max(0,x-reach),min(self.grid.shape[1],x+reach+1)
        y0,y1=max(0,y-reach),min(self.grid.shape[0],y+reach+1)
        yy,xx=np.mgrid[y0:y1,x0:x1]
        d=pixel(np.stack((xx,yy),axis=-1))-center
        self.free[y0:y1,x0:x1] &= np.sum(d*d,axis=-1)>=radius*radius

    def landing(self, old: dict, reference, safe: bool, kind: str) -> dict:
        allowed=self.free & (self.safe if safe else self.connected)
        cell=nearest(allowed,reference)
        result=deepcopy(old)
        result['position']=pixel(cell).tolist()
        result['source_cell']=list(cell)
        result['placement_status']='TWILIGHT_ADAPTED_NOT_ORIGINAL_COORDINATES'
        self.audit.append({'kind':kind,'id':old['id'],'old_position':old['position'],
            'reference_source':(np.asarray(reference)+ORIGIN).tolist(),
            'source_cell':list(cell),'position':result['position'],
            'snap_pixels':float(np.linalg.norm(pixel(cell)-pixel(reference)))})
        self.reserve(cell, max(72.,float(old.get('radius',0))+40.))
        return result

    def build(self) -> dict:
        npcs=[]
        for old in self.layout['npc_spawn']:
            npcs.append(self.landing(old,self.reference(old['position']),True,'npc'))
        gludin=np.asarray(self.entry)
        giran=nearest(self.safe,np.array([33429,32814])-ORIGIN)
        portals=[]
        for old in self.layout['portal']:
            reference=self.reference(old['position'])
            if old['id']=='oman_gate':
                # Exact source dungeon observations: 4:(34256,33450..33452)
                # lead to 101. A nearest landing, when needed, is audited.
                reference=np.array([34256,33450])-ORIGIN
            new=self.landing(old,reference,old['id']!='oman_gate','portal')
            if new.get('target_map')=='aden_world':
                target=giran if old['id']=='town_waystone' else gludin
                new['target_position']=pixel(target).tolist()
            elif new.get('target_map')=='oman_01':
                new.pop('target_position',None)  # Existing Oman entry handling.
            portals.append(new)
        eligible=self.connected & self.free & ((self.grid&48)!=16)
        regions=[]
        for old in self.layout['monster_spawn']:
            rect=np.asarray(old['rect'],float)
            reference=self.reference(rect[:2]+rect[2:]*.5)
            seed=nearest(eligible,reference)
            minimum=max(12,4*int(old['max_count']))
            # Retain the original pixel extent/radius/cap. When an extent
            # cannot fit enough cells, fail rather than expanding a boss room.
            radius=float(old.get('spawn_radius',0))
            half=rect[2:]*.5
            chosen=None
            # Candidates near the requested location are evaluated in a
            # deterministic order. No whole-map quadratic density calculation.
            for dx,dy in ((0,0),(4,0),(-4,0),(0,4),(0,-4),(8,8),(-8,-8)):
                trial=nearest(eligible,(seed[0]+dx,seed[1]+dy))
                center=pixel(trial)
                corners=[grid_point(center+np.array([sx*half[0],sy*half[1]]))
                         for sx,sy in ((-1,-1),(1,-1),(1,1),(-1,1))]
                lower=np.floor(np.min(corners,axis=0)).astype(int)-1
                upper=np.ceil(np.max(corners,axis=0)).astype(int)+2
                x0,y0=np.maximum(lower,0); x1,y1=np.minimum(upper,DIMENSIONS)
                yy,xx=np.mgrid[y0:y1,x0:x1]
                points=pixel(np.stack((xx,yy),axis=-1))
                inside=np.all(np.abs(points-center)<=half,axis=-1)
                if radius>0: inside &= np.sum((points-center)**2,axis=-1)<=radius*radius
                inside &= eligible[y0:y1,x0:x1]
                local=self.masks[y0:y1,x0:x1].copy()
                # Clear sub-window outgoing edges before a local BFS.
                local[0]&=254;local[-1]&=239;local[:,0]&=191;local[:,-1]&=251
                selected=reachable(local,(trial[0]-x0,trial[1]-y0),inside)
                ly,lx=np.nonzero(selected)
                if len(lx)>=minimum:
                    cells=np.sort((ly+y0)*DIMENSIONS[0]+(lx+x0)).astype(int)
                    chosen=(trial,center,cells);break
            if chosen is None:
                raise ValueError('Insufficient connected cells within existing extent: '+old['id'])
            trial,center,cells=chosen
            new={k:deepcopy(v) for k,v in old.items() if k not in SPATIAL}
            new.update({'rect':[*map(float,center-half),*map(float,rect[2:])],
                'source_seed':list(trial),'source_cells':cells.tolist(),
                'placement_status':'TWILIGHT_ADAPTED_NOT_ORIGINAL_SPAWNS',
                'coordinate_evidence':'A3_STATIC_TOPOLOGY_WITH_PROVISIONAL_TWILIGHT_DISTRICT_ADAPTATION'})
            regions.append(new)
            self.audit.append({'kind':'spawn','id':old['id'],'old_rect':old['rect'],
                'source_seed':list(trial),'source_cells':len(cells),
                'old_cap':old['max_count'],'new_cap':new['max_count'],
                'reference_source':(reference+ORIGIN).tolist(),
                'snap_pixels':float(np.linalg.norm(center-pixel(reference)))})
        return {'npc_spawn':npcs,'monster_spawn':regions,'portal':portals,
            'entry_exclusion':{'center':pixel(self.entry).tolist(),'radius':150},
            'placement_status':'PROVISIONAL_TWILIGHT_NOT_ORIGINAL_SPAWNS'}


def verify(pack: Path, layouts: Path) -> dict:
    index=json.loads((pack/'index.json').read_text(encoding='utf-8'))
    if index.get('schema')!=1 or index.get('source_archive_sha256')!=ARCHIVE_SHA:
        raise ValueError('Invalid index')
    entry=index['maps']['aden_world']; path=pack/'definitions/aden_world.json'
    if entry.get('path')!=PACK_ROOT+'/definitions/aden_world.json' or file_sha(path)!=entry['sha256']:
        raise ValueError('Definition checksum/path mismatch')
    definition=json.loads(path.read_text(encoding='utf-8'))
    for k,v in {'map_id':'aden_world','source_map_id':4,'origin':list(ORIGIN),
                'dimensions':list(DIMENSIONS),'source_sha256':GRID_SHA,
                'pack_root':PACK_ROOT,'source_archive_sha256':ARCHIVE_SHA}.items():
        if definition.get(k)!=v: raise ValueError('Definition identity mismatch: '+k)
    grid=np.zeros(DIMENSIONS[::-1],np.uint8); masks=np.zeros_like(grid); seen=set()
    for cx,cy,w,h,shard,offset,size,digest in definition['navigation']['chunks']:
        if not (0<=cx<32 and 0<=cy<24) or (cx,cy) in seen or (w,h)!=(64,64):
            raise ValueError('Invalid/duplicate chunk')
        seen.add((cx,cy))
        with (pack/f'navigation-{shard:02}.bin').open('rb') as f:
            f.seek(offset);raw=zlib.decompress(f.read(size))
        if len(raw)!=w*h*2 or sha(raw)!=digest: raise ValueError('Navigation chunk corruption')
        grid[cy*64:cy*64+h,cx*64:cx*64+w]=np.frombuffer(raw[:w*h],np.uint8).reshape(h,w)
        masks[cy*64:cy*64+h,cx*64:cx*64+w]=np.frombuffer(raw[w*h:],np.uint8).reshape(h,w)
    if len(seen)!=768 or sha(grid.tobytes())!=GRID_SHA or not np.array_equal(masks,move_masks(grid)):
        raise ValueError('Incomplete/modified source grid or movement edges')
    exported=json.loads(layouts.read_text(encoding='utf-8'));old=exported['aden_world'];g=definition['remake_gameplay']
    if index.get('effective_layouts_sha256')!=file_sha(layouts): raise ValueError('Stale gameplay export')
    for key in ('npc_spawn','portal','monster_spawn'):
        if [r['id'] for r in old[key]] != [r['id'] for r in g[key]]:
            raise ValueError('Gameplay IDs/order changed: '+key)
        for before,after in zip(old[key],g[key]):
            ignored=SPATIAL|{'position','target_position','source_cell','placement_status','coordinate_evidence'}
            for k in before.keys()-ignored:
                if before[k]!=after.get(k): raise ValueError('Gameplay setting changed: '+before['id']+'/'+k)
    source=np.array(definition['spawn_source'])-ORIGIN
    connected=reachable(masks,tuple(source));checks=768+math.prod(DIMENSIONS)
    for key in ('npc_spawn','portal'):
        for r in g[key]:
            x,y=r['source_cell']
            if not (isinstance(x,int) and isinstance(y,int) and 0<=x<DIMENSIONS[0] and 0<=y<DIMENSIONS[1]):
                raise ValueError('Landing cell out of bounds')
            if not connected[y,x] or not np.array_equal(pixel((x,y)),r['position']):
                raise ValueError('Unreachable or mismatched landing: '+r['id'])
            if r.get('target_map')=='aden_world':
                x,y=np.rint(grid_point(r['target_position'])).astype(int)
                if not (0<=x<DIMENSIONS[0] and 0<=y<DIMENSIONS[1]) or not connected[y,x]:
                    raise ValueError('Unreachable internal portal target')
            checks+=1
    for r in g['monster_spawn']:
        cells=np.asarray(r['source_cells'],dtype=int)
        if len(cells)<max(12,4*int(r['max_count'])) or np.any(np.diff(cells)<=0):
            raise ValueError('Invalid spawn cells: '+r['id'])
        if np.any((cells<0)|(cells>=grid.size)): raise ValueError('Spawn out of bounds')
        if not np.all(connected.ravel()[cells]) or np.any((grid.ravel()[cells]&48)==16):
            raise ValueError('Blocked/unreachable/safe spawn cell')
        points=pixel(np.stack((cells%DIMENSIONS[0],cells//DIMENSIONS[0]),axis=-1))
        for reservation in [g['entry_exclusion'], *[{'center':v['position'],'radius':64} for v in g['npc_spawn']+g['portal']]]:
            if np.any(np.sum((points-reservation['center'])**2,axis=-1)<reservation['radius']**2):
                raise ValueError('Spawn overlaps reserved service/entry zone')
        checks+=len(cells)
    return {'status':'PASS_DATA_ONLY','dimensions':list(DIMENSIONS),'grid_sha256':GRID_SHA,
        'verified_cells':grid.size,'verified_chunks':len(seen),'checks':checks,
        'entry_connected_cells':int(connected.sum()),'npc_count':len(g['npc_spawn']),
        'portal_count':len(g['portal']),'spawn_region_count':len(g['monster_spawn']),
        'godot_runtime':'NOT_RUN','visual_fidelity':'UNVERIFIED','original_art':'NOT_LINKED'}


def build(archive: Path, layouts: Path, out: Path) -> dict:
    if out.exists(): raise FileExistsError('Use a NEW output directory; existing/Oman packs are never overwritten')
    exported=json.loads(layouts.read_text(encoding='utf-8'))
    if 'aden_world' not in exported: raise ValueError('Export current effective layouts first')
    layout=exported['aden_world'];grid=read_grid(archive);masks=move_masks(grid)
    adapter=PlacementAdapter(layout,grid,masks);gameplay=adapter.build()
    out.parent.mkdir(parents=True,exist_ok=True)
    temporary=Path(tempfile.mkdtemp(prefix='.aden-build-',dir=out.parent))
    try:
        refs=[];known={}
        with (temporary/'navigation-00.bin').open('wb') as f:
            for y in range(0,grid.shape[0],64):
                for x in range(0,grid.shape[1],64):
                    raw=grid[y:y+64,x:x+64].tobytes()+masks[y:y+64,x:x+64].tobytes();digest=sha(raw)
                    if digest not in known:
                        compressed=zlib.compress(raw,9);known[digest]=[0,f.tell(),len(compressed),digest];f.write(compressed)
                    refs.append([x//64,y//64,64,64,*known[digest]])
        definition={'schema':2,'map_id':'aden_world','map_name':layout['map_name'],
            'source_map_id':4,'origin':list(ORIGIN),'dimensions':list(DIMENSIONS),
            'source_sha256':GRID_SHA,'source_archive_sha256':ARCHIVE_SHA,
            'navigation':{'profile':'A3_STATIC_EDGES','chunks':refs},
            'corner_policy':'no_corner_cut','pack_root':PACK_ROOT,
            'coordinate_mapping':{'basis_x':[24,-12],'basis_y':[24,12],'translation':[0,24576]},
            'spawn_source':(np.asarray(adapter.entry)+ORIGIN).tolist(),
            'playable':True,'layout_revision':REVISION,'legacy_layout_revision':layout['layout_revision'],
            'rules':{},'npc_spawns':[],'monster_spawns':[],'portals':[],'getback':[],'doors':[],
            'terrain_chunks':[],'remake_gameplay':gameplay,'render_profile':'aden_mainland',
            'edition_status':'A3_PC_TOPOLOGY_CURRENT_M_UNVERIFIED','art_status':'TWILIGHT_AUTHORED_NOT_ORIGINAL'}
        p=temporary/'definitions/aden_world.json';write(p,definition)
        index={'schema':1,'source_archive_sha256':ARCHIVE_SHA,'effective_layouts_sha256':file_sha(layouts),
            'maps':{'aden_world':{'path':PACK_ROOT+'/definitions/aden_world.json',
                                 'sha256':file_sha(p),'grid_sha256':GRID_SHA}}}
        write(temporary/'index.json',index)
        report=verify(temporary,layouts)
        report.update({'source':'a3.zip!data/mapcache/4.map','cache_sha256':CACHE_SHA,
            'source_archive_sha256':ARCHIVE_SHA,'effective_layouts_sha256':file_sha(layouts),
            'navigation_bytes':(temporary/'navigation-00.bin').stat().st_size,
            'placements':adapter.audit,'anchor_policy':'Source getback locations used only as provisional TWILIGHT adaptation anchors',
            'source_entry_observed':[32628,32807],'s32_rendering':'NOT_IMPLEMENTED',
            'source_doors':'NOT_IMPORTED','main_modified':False})
        write(temporary/'build_report.json',report)
        temporary.rename(out)
        return report
    except Exception:
        shutil.rmtree(temporary,ignore_errors=True)
        raise


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--a3',type=Path);p.add_argument('--layouts',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True);p.add_argument('--verify',action='store_true')
    a=p.parse_args()
    if not a.verify and a.a3 is None: p.error('--a3 is required to build')
    result=verify(a.output,a.layouts) if a.verify else build(a.a3,a.layouts,a.output)
    print(json.dumps({k:v for k,v in result.items() if k!='placements'},ensure_ascii=False,indent=2))
